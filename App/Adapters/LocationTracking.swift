import Foundation
import Combine
import CoreLocation
import WakeHereDomain

/// Porta de localização usada pela sessão da viagem (implementação: CoreLocation).
protocol LocationTracking: AnyObject {
    var lastKnownCoordinate: Coordinate? { get }
    var authorizationStatus: CLAuthorizationStatus { get }

    func requestWhenInUseAuthorization()
    func requestAlwaysAuthorization()
    func startUpdates(onUpdate: @escaping (Coordinate, MetersPerSecond, Date) -> Void)
    func stopUpdates()
    func monitorDestination(
        at coordinate: Coordinate,
        radius: Meters,
        onEntry: @escaping () -> Void
    )
    func stopMonitoringDestination()
}

/// **Adapter** — embrulha `CLLocationManager` para o domínio.
///
/// Responsável também pela geofence do destino (tripla trava do alarme):
/// dispara mesmo se o iOS matar o app.
final class CoreLocationTracker: NSObject, LocationTracking {
    private let manager = CLLocationManager()

    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var lastKnownCoordinate: Coordinate?

    private var onUpdate: ((Coordinate, MetersPerSecond, Date) -> Void)?
    private var onDestinationEntry: (() -> Void)?
    private var wantsUpdates = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .automobileNavigation
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
        authorizationStatus = manager.authorizationStatus
    }

    var isAuthorizedForBackground: Bool {
        authorizationStatus == .authorizedAlways
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    func startUpdates(onUpdate: @escaping (Coordinate, MetersPerSecond, Date) -> Void) {
        self.onUpdate = onUpdate
        wantsUpdates = true
        manager.distanceFilter = 10
        // Requer UIBackgroundModes = location (presente no Info.plist).
        manager.allowsBackgroundLocationUpdates = true
        activateIfAuthorized()
    }

    func stopUpdates() {
        wantsUpdates = false
        onUpdate = nil
        manager.stopUpdatingLocation()
        stopMonitoringDestination()
    }

    func monitorDestination(
        at coordinate: Coordinate,
        radius: Meters,
        onEntry: @escaping () -> Void
    ) {
        guard authorizationStatus == .authorizedAlways else { return }
        onDestinationEntry = onEntry
        let region = CLCircularRegion(
            center: coordinate.clLocationCoordinate,
            radius: max(radius.value, 100),
            identifier: "destination"
        )
        region.notifyOnEntry = true
        region.notifyOnExit = false
        manager.startMonitoring(for: region)
        // Dispara imediatamente se o usuário já estiver dentro do raio.
        manager.requestState(for: region)
    }

    func stopMonitoringDestination() {
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
        onDestinationEntry = nil
    }

    private func activateIfAuthorized() {
        guard wantsUpdates else { return }
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        default:
            break
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension CoreLocationTracker: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }
        activateIfAuthorized()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coordinate = Coordinate(location.coordinate)
        lastKnownCoordinate = coordinate

        // CLLocation.speed < 0 significa "indisponível".
        let speed = MetersPerSecond(max(0, location.speed))
        onUpdate?(coordinate, speed, location.timestamp)
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region.identifier == "destination" else { return }
        onDestinationEntry?()
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        // Silencioso: a geofence é uma trava de segurança extra, não obrigatória.
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Silencioso: updates falham eventualmente; o monitor tenta de novo.
    }
}
