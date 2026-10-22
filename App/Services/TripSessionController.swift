import Foundation
import UIKit
import AcordeAquiDomain

/// **Facade** — API única da viagem ativa para a interface.
///
/// Liga o `TripMonitor` (domínio) aos adaptadores do sistema: localização,
/// notificações, som e persistência. Publica o estado para as ViewModels
/// (Observer + Combine).
///
/// ### Reroute periódico com tráfego ao vivo (ADR-0006 revisado)
/// A cada `periodicRerouteInterval` segundos (padrão: 3 min), enquanto a
/// viagem está ativa, o controller re-planeja a rota usando `MKDirections`
/// a partir da posição GPS atual. O `expectedTravelTime` retornado pelo
/// MapKit já inclui dados de tráfego ao vivo dos servidores Apple — o mesmo
/// dado que o Apple Maps exibe. Isso atualiza o `TravelEstimator` com um ETA
/// mais preciso e aciona re-agendamento da notificação via `AlarmTimingPlanner`.
///
/// O reroute periódico:
/// - Só ocorre quando a viagem está em fase ativa (tracking / warning / snoozed)
/// - É cancelado se a viagem termina (arrived / cancelled)
/// - Usa a mesma flag `isFetchingRoute` para evitar chamadas simultâneas
/// - Cai silenciosamente em caso de erro de rede (mantém o ETA anterior)
final class TripSessionController: ObservableObject, Identifiable {
    var id: UUID { trip.id }

    let trip: Trip
    @Published private(set) var snapshot: TripSnapshot?
    @Published private(set) var phase: TripPhase
    @Published var isAlarmVisible = false

    private let monitor: TripMonitor
    private let planner: AlarmTimingPlanner
    private let alarms: AlarmScheduling
    private let tripRepository: TripRepository
    private let routeProvider: RoutePlanning
    private let locationManager: LocationTracking
    private let soundPlayer: AlarmSoundPlayer
    private let configuration: MonitorConfiguration
    private let settings: AppSettings

    // MARK: - Reroute periódico

    /// Intervalo entre re-planejamentos de rota (segundos). 180 s = 3 min.
    private let periodicRerouteInterval: TimeInterval = 180
    private var isFetchingRoute = false
    private var lastPeriodicReroute: Date?
    private var periodicRerouteTask: Task<Void, Never>?

    // MARK: - Notificação

    private var lastScheduledFireDate: Date?

    // MARK: - Init

    init(
        trip: Trip,
        configuration: MonitorConfiguration,
        planner: AlarmTimingPlanner,
        alarms: AlarmScheduling,
        tripRepository: TripRepository,
        routeProvider: RoutePlanning,
        locationManager: LocationTracking,
        soundPlayer: AlarmSoundPlayer,
        settings: AppSettings
    ) {
        self.trip = trip
        self.configuration = configuration
        self.planner = planner
        self.alarms = alarms
        self.tripRepository = tripRepository
        self.routeProvider = routeProvider
        self.locationManager = locationManager
        self.soundPlayer = soundPlayer
        self.settings = settings
        self.phase = trip.phase
        self.monitor = TripMonitor(trip: trip, configuration: configuration)
        self.monitor.delegate = self
    }

    // MARK: - Ciclo de vida

    /// Começa a acompanhar a viagem (permissões + GPS + geofence + reroute periódico).
    func begin() {
        Task {
            await alarms.requestAuthorization()
        }

        // Trilha 3: localização contínua em background.
        locationManager.startUpdates { [weak self] coordinate, speed, timestamp in
            DispatchQueue.main.async {
                self?.handleUpdate(coordinate: coordinate, speed: speed, timestamp: timestamp)
            }
        }

        // Trilha 2: geofence do destino (funciona com o app morto).
        locationManager.monitorDestination(
            at: trip.destination.coordinate,
            radius: configuration.arrivalRadius
        ) { [weak self] in
            DispatchQueue.main.async {
                self?.handleDestinationGeofence()
            }
        }

        monitor.start()
        startPeriodicReroute()
        save()
    }

    // MARK: - Comandos da UI

    /// Alarme parado pelo usuário: volta a acompanhar (ou conclui a viagem).
    func stopAlarm() {
        isAlarmVisible = false
        soundPlayer.stop()
        monitor.stopAlarm()
    }

    /// Adia o alarme (padrão: 3 min) com trava de segurança agendada.
    func snooze(minutes: Int = 3) {
        isAlarmVisible = false
        soundPlayer.stop()

        let deadline = Date().addingTimeInterval(TimeInterval(minutes * 60))
        monitor.snooze(until: deadline)
        lastScheduledFireDate = nil

        // Mesmo que o app morra durante o snooze, a notificação toca no prazo.
        alarms.scheduleAlarm(
            at: deadline,
            title: "AcordeAqui",
            body: "Snooze encerrado — confira se o ponto já está chegando!"
        )
    }

    /// Encerra a viagem.
    func cancelTrip() {
        stopPeriodicReroute()
        isAlarmVisible = false
        soundPlayer.stop()
        alarms.cancelScheduledAlarm()
        monitor.cancel()
    }

    // MARK: - Reroute periódico com tráfego ao vivo

    /// Inicia o loop de reroute periódico. Roda a cada `periodicRerouteInterval`
    /// segundos enquanto a fase for ativa, usando `MKDirections` (tráfego Apple Maps).
    private func startPeriodicReroute() {
        periodicRerouteTask?.cancel()
        periodicRerouteTask = Task { [weak self] in
            guard let self else { return }

            // Aguarda o intervalo inicial antes do primeiro reroute periódico
            // (a rota inicial já foi calculada no CompositionRoot).
            try? await Task.sleep(nanoseconds: UInt64(self.periodicRerouteInterval * 1_000_000_000))

            while !Task.isCancelled {
                await MainActor.run {
                    guard self.phase.isActive, !self.isFetchingRoute else { return }
                    if let origin = self.locationManager.lastKnownCoordinate {
                        self.fetchRoute(from: origin, reason: .periodic)
                    }
                }
                try? await Task.sleep(nanoseconds: UInt64(self.periodicRerouteInterval * 1_000_000_000))
            }
        }
    }

    private func stopPeriodicReroute() {
        periodicRerouteTask?.cancel()
        periodicRerouteTask = nil
    }

    // MARK: - Entradas de localização

    private func handleUpdate(coordinate: Coordinate, speed: MetersPerSecond, timestamp: Date) {
        monitor.process(location: coordinate, speed: speed, timestamp: timestamp)

        // Sem rota ainda (ex.: GPS indisponível na largada) → tenta planejar.
        if trip.route == nil, !isFetchingRoute, let origin = locationManager.lastKnownCoordinate {
            fetchRoute(from: origin, reason: .initial)
        }
    }

    private func handleDestinationGeofence() {
        guard phase == .tracking || phase == .warning || phase == .snoozed else { return }
        monitor.forceArrival()
    }

    // MARK: - Planejamento de rota (inicial + periódico + reroute por desvio)

    private enum FetchReason { case initial, periodic, deviation }

    private func fetchRoute(from origin: Coordinate, reason: FetchReason) {
        isFetchingRoute = true
        let destination = trip.destination
        Task { [weak self] in
            let route = try? await self?.routeProvider.planRoute(from: origin, to: destination)
            await MainActor.run {
                guard let self else { return }
                self.isFetchingRoute = false
                if let route {
                    self.monitor.updateRoute(route)
                    // Após reroute periódico ou por desvio, força re-agendamento
                    // imediato da notificação com o novo ETA de tráfego.
                    if reason == .periodic || reason == .deviation {
                        self.lastScheduledFireDate = nil
                    }
                }
            }
        }
    }

    private func save() {
        try? tripRepository.save(trip)
    }

    // MARK: - Notificação pré-agendada (Trilha 1)

    /// Reagenda a notificação pré-alarme com base no **ETA dinâmico** mais recente.
    ///
    /// O horário do alarme nunca é fixo: ele é rederivado a cada update de GPS e
    /// a cada reroute periódico com tráfego ao vivo (ADR-0006). Se o ETA mudar
    /// (trânsito, desvio, parada no semáforo), o horário do aviso é ajustado.
    private func rescheduleNotificationIfNeeded(snapshot: TripSnapshot) {
        guard phase == .tracking || phase == .warning else { return }

        guard let schedule = planner.schedule(snapshot: snapshot, rule: trip.rule) else {
            if lastScheduledFireDate != nil {
                alarms.cancelScheduledAlarm()
                lastScheduledFireDate = nil
            }
            return
        }

        // Só reescreve se o horário mudou mais de 15 s (evita I/O a cada update de GPS).
        if let last = lastScheduledFireDate,
           abs(schedule.fireDate.timeIntervalSince(last)) < 15 {
            return
        }

        lastScheduledFireDate = schedule.fireDate
        alarms.scheduleAlarm(
            at: schedule.fireDate,
            title: "Prepare-se!",
            body: planner.preAlertBody(
                destinationName: trip.destination.name,
                snapshot: snapshot,
                rule: trip.rule
            )
        )
    }
}

// MARK: - TripMonitorDelegate (Observer)

extension TripSessionController: TripMonitorDelegate {
    func tripMonitor(_ monitor: TripMonitor, didUpdateSnapshot snapshot: TripSnapshot) {
        self.snapshot = snapshot
        rescheduleNotificationIfNeeded(snapshot: snapshot)
    }

    func tripMonitor(_ monitor: TripMonitor, didChangePhase phase: TripPhase) {
        self.phase = phase
        save()

        switch phase {
        case .arrived, .cancelled:
            stopPeriodicReroute()
            alarms.cancelScheduledAlarm()
            locationManager.stopUpdates()
            soundPlayer.stop()
            isAlarmVisible = false
        default:
            break
        }
    }

    func tripMonitorDidRequestReroute(_ monitor: TripMonitor) {
        // Desvio detectado pelo TripMonitor → reroute imediato por desvio.
        // O reroute periódico continua independente deste.
        guard !isFetchingRoute, let origin = locationManager.lastKnownCoordinate else { return }
        fetchRoute(from: origin, reason: .deviation)
    }

    func tripMonitorDidTriggerAlarm(_ monitor: TripMonitor) {
        stopPeriodicReroute()
        alarms.cancelScheduledAlarm()
        lastScheduledFireDate = nil
        alarms.announceNow(
            title: "Hora de descer!",
            body: "\(trip.destination.name) está logo ali."
        )
        isAlarmVisible = true

        if settings.soundEnabled {
            soundPlayer.start(volume: Float(settings.alarmVolume))
        }
        if settings.hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
