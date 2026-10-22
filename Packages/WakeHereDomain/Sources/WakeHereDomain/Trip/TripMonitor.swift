import Foundation

/// Orquestra uma viagem ativa: encaixa o GPS na rota, calcula o ETA, decide
/// fases (State) e aciona o alarme pelas regras (**Strategy**), notificando
/// observadores (**Observer**).
///
/// É puro domínio: não conhece CoreLocation, MapKit nem notificações — apenas
/// recebe coordenadas e devolve eventos via `TripMonitorDelegate`.
public final class TripMonitor {
    public let trip: Trip
    public let configuration: MonitorConfiguration
    public weak var delegate: TripMonitorDelegate?

    private let machine: TripStateMachine
    private let estimator: TravelEstimator
    private var lastRerouteRequest: Date?
    private var snoozeDeadline: Date?
    /// Chegada confirmada por evento externo (geofence).
    private var arrivalConfirmed = false
    /// O usuário já parou o alarme da regra: só a chegada volta a tocar.
    private var ruleAlarmDismissed = false

    public init(trip: Trip, configuration: MonitorConfiguration = .default) {
        self.trip = trip
        self.configuration = configuration
        self.machine = TripStateMachine(initialPhase: trip.phase)

        if let route = trip.route {
            self.estimator = TravelEstimator(route: route)
        } else {
            self.estimator = TravelEstimator(initialSpeed: configuration.defaultCruisingSpeed)
        }
    }

    public var phase: TripPhase { machine.phase }

    // MARK: - Comandos

    /// Inicia o acompanhamento (planned → tracking).
    public func start(at date: Date = Date()) {
        guard machine.phase == .planned else { return }
        trip.startedAt = trip.startedAt ?? date
        transition(to: .tracking)
    }

    /// Processa uma medição de localização. Retorna o snapshot (ou `nil` se a
    /// viagem não está ativa).
    ///
    /// O ETA retornado é **dinâmico**: ele é recalculado a cada update a partir
    /// da posição atual e, quando há rota, refinado pelo reroute periódico com
    /// tráfego ao vivo (ADR-0006). Por isso o alarme não depende de um tempo
    /// de chegada pré-fixado: o ``TripSnapshot/estimatedArrival`` e o disparo
    /// da regra são sempre derivados do ETA mais recente.
    @discardableResult
    public func process(
        location: Coordinate,
        speed: MetersPerSecond,
        timestamp: Date
    ) -> TripSnapshot? {
        guard machine.phase.isActive else { return nil }

        var snapped: Coordinate?
        var deviation = Meters.zero
        var remaining: Meters
        var isOnRoute = false

        if let route = trip.route, route.polyline.count >= 2 {
            let snap = RouteGeometry.snap(location, along: route.polyline)
            snapped = snap.snapped
            deviation = snap.distanceFromRoute
            isOnRoute = deviation <= configuration.deviationTolerance
            remaining = isOnRoute
                ? snap.remainingToEnd
                : location.distance(to: trip.destination.coordinate)
        } else {
            // Sem rota: modo raio (distância em linha reta até o destino).
            remaining = location.distance(to: trip.destination.coordinate)
        }

        estimator.registerSample(speed: speed)
        let eta = estimator.estimatedTime(toCover: remaining)

        let snapshot = TripSnapshot(
            coordinate: location,
            speed: speed,
            timestamp: timestamp,
            remainingMeters: remaining,
            estimatedRemainingSeconds: eta,
            deviationFromRoute: deviation,
            isOnRoute: isOnRoute,
            snappedCoordinate: snapped
        )
        trip.lastSnapshot = snapshot
        delegate?.tripMonitor(self, didUpdateSnapshot: snapshot)

        requestRerouteIfNeeded(isOnRoute: isOnRoute, timestamp: timestamp)

        // 1) Chegou ao destino → sempre toca (quem dormiu até aqui precisa acordar).
        if remaining <= configuration.arrivalRadius {
            if machine.phase != .ringing, machine.phase != .arrived {
                triggerAlarm()
            }
            return snapshot
        }

        // 2) Snooze vencido → toca de novo.
        if machine.phase == .snoozed, let deadline = snoozeDeadline, timestamp >= deadline {
            snoozeDeadline = nil
            transition(to: .ringing)
            delegate?.tripMonitorDidTriggerAlarm(self)
            return snapshot
        }

        // 3) Regra de despertar (só fora de ringing/snoozed).
        guard machine.phase == .tracking || machine.phase == .warning else {
            return snapshot
        }
        // Alarme da regra já parado: sem isso a regra, ainda satisfeita,
        // tocaria de novo no próximo update de GPS.
        guard !ruleAlarmDismissed else { return snapshot }

        if trip.rule.evaluate(with: snapshot) == .triggered {
            triggerAlarm()
        } else if trip.rule.isApproaching(snapshot) {
            if machine.phase == .tracking {
                transition(to: .warning)
            }
        } else if machine.phase == .warning {
            transition(to: .tracking)
        }

        return snapshot
    }

    /// O alarme parou: volta a acompanhar, ou finaliza se já chegou.
    public func stopAlarm(at date: Date = Date()) {
        guard machine.phase == .ringing else { return }
        let arrived = arrivalConfirmed || (trip.lastSnapshot.map {
            $0.remainingMeters <= configuration.arrivalRadius
        } ?? false)
        if arrived {
            trip.finishedAt = date
            transition(to: .arrived)
        } else {
            ruleAlarmDismissed = true
            transition(to: .tracking)
        }
    }

    /// Adia o alarme até `deadline`.
    public func snooze(until deadline: Date) {
        guard machine.phase == .ringing else { return }
        snoozeDeadline = deadline
        transition(to: .snoozed)
    }

    /// Cancela a viagem (estado final).
    public func cancel(at date: Date = Date()) {
        guard machine.phase != .arrived, machine.phase != .cancelled else { return }
        trip.finishedAt = date
        transition(to: .cancelled)
    }

    /// Forçado por evento externo (ex.: geofence disparou): toca o alarme e
    /// marca a chegada como confirmada.
    public func forceArrival(at date: Date = Date()) {
        guard machine.phase.isActive, machine.phase != .ringing else { return }
        arrivalConfirmed = true
        trip.finishedAt = date
        triggerAlarm()
    }

    /// Nova rota (reroute concluído pelo adaptador de mapas).
    public func updateRoute(_ route: Route) {
        trip.route = route
        // O tempo esperado da nova rota carrega o trânsito atual: recalibra o ETA.
        estimator.recalibrate(with: route)
        lastRerouteRequest = nil
    }

    // MARK: - Internos

    private func triggerAlarm() {
        snoozeDeadline = nil
        if machine.phase != .ringing {
            transition(to: .ringing)
        }
        delegate?.tripMonitorDidTriggerAlarm(self)
    }

    private func requestRerouteIfNeeded(isOnRoute: Bool, timestamp: Date) {
        guard trip.route != nil, !isOnRoute else { return }
        if let last = lastRerouteRequest,
           timestamp.timeIntervalSince(last) < configuration.rerouteMinInterval.value {
            return
        }
        lastRerouteRequest = timestamp
        delegate?.tripMonitorDidRequestReroute(self)
    }

    private func transition(to next: TripPhase) {
        guard machine.transition(to: next) else { return }
        trip.phase = machine.phase
        delegate?.tripMonitor(self, didChangePhase: machine.phase)
    }
}
