import Foundation
import AcordeAquiDomain
import AcordeAquiData

/// **Composition Root** — único lugar que conhece as implementações concretas.
///
/// Todas as dependências são injetadas por construtor (DIP); não há singletons.
@MainActor
final class CompositionRoot: ObservableObject {
    let tripRepository: TripRepository
    let settingsRepository: SettingsRepository
    let clock: Clock
    let routeProvider: RoutePlanning
    let placeSearcher: PlaceSearching
    let alarmScheduler: AlarmScheduling
    let tripFactory: TripFactory
    let locationManager: CoreLocationTracker
    let soundPlayer: AlarmSoundPlayer
    let planViewModel: TripPlanViewModel

    /// Sessão ativa — quando != nil, a tela de acompanhamento cobre o app.
    @Published var session: TripSessionController?

    init() {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("AcordeAqui", isDirectory: true)
        let fallbackDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AcordeAqui-fallback", isDirectory: true)

        tripRepository = CompositionRoot.resolve(
            default: { try JsonTripRepository(directory: directory) },
            fallback: { try JsonTripRepository(directory: fallbackDirectory) }
        )
        settingsRepository = CompositionRoot.resolve(
            default: { try JsonSettingsRepository(directory: directory) },
            fallback: { try JsonSettingsRepository(directory: fallbackDirectory) }
        )

        clock = SystemClock()
        routeProvider = MapKitRouteProvider()
        placeSearcher = MapKitPlaceSearcher()
        alarmScheduler = NotificationAlarmScheduler()
        tripFactory = TripFactory()
        locationManager = CoreLocationTracker()
        soundPlayer = AlarmSoundPlayer()
        planViewModel = TripPlanViewModel(searcher: placeSearcher)
    }

    /// Tenta o diretório padrão; se falhar, usa o temporário.
    private static func resolve<T>(
        default make: () throws -> T,
        fallback: () throws -> T
    ) -> T {
        if let value = try? make() { return value }
        if let value = try? fallback() { return value }
        fatalError("Não foi possível criar o repositório")
    }

    /// Configurações atuais (best-effort).
    var currentSettings: AppSettings {
        (try? settingsRepository.load()) ?? .default
    }

    // MARK: - Comandos da UI

    /// Planeja a rota inicial (com tráfego via MKDirections) e inicia a sessão.
    /// O reroute periódico a cada 3 min fica a cargo do TripSessionController.
    func startTrip(destination: Destination, rule: any WakeUpRule) async {
        var route: Route?
        if let origin = locationManager.lastKnownCoordinate {
            route = try? await routeProvider.planRoute(from: origin, to: destination)
        }

        let trip = tripFactory.makeTrip(
            destination: destination,
            rule: rule,
            route: route,
            now: clock.now
        )

        let newSession = TripSessionController(
            trip: trip,
            configuration: .default,
            planner: AlarmTimingPlanner(clock: clock),
            alarms: alarmScheduler,
            tripRepository: tripRepository,
            routeProvider: routeProvider,
            locationManager: locationManager,
            soundPlayer: soundPlayer,
            settings: currentSettings
        )
        session = newSession
        newSession.begin()
    }
}
