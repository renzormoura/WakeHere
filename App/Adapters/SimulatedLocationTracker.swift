import Foundation
import CoreLocation
import WakeHereDomain

/// **Adapter** de teste — percorre uma reta até o destino em velocidade constante,
/// sem GPS. Permite exercitar alarme, snooze e chegada sem sair de casa
/// (Ajustes → Modo simulação).
final class SimulatedLocationTracker: LocationTracking {
    private(set) var lastKnownCoordinate: Coordinate?
    var authorizationStatus: CLAuthorizationStatus { .authorizedAlways }

    private let start: Coordinate
    private let destination: Coordinate
    private let speed: Double
    private let totalDistance: Double
    private var travelled: Double = 0
    private var timer: Timer?

    /// - Parameters:
    ///   - speed: metros por segundo (25 m/s ≈ 90 km/h).
    init(start: Coordinate, destination: Coordinate, speed: Double = 25) {
        self.start = start
        self.destination = destination
        self.speed = speed
        self.totalDistance = start.distance(to: destination).value
        self.lastKnownCoordinate = start
    }

    /// Ponto de partida ~5 km ao sul do destino.
    static func defaultStart(for destination: Coordinate) -> Coordinate {
        Coordinate(latitude: destination.latitude - 0.045, longitude: destination.longitude)
    }

    func requestWhenInUseAuthorization() {}
    func requestAlwaysAuthorization() {}

    func startUpdates(onUpdate: @escaping (Coordinate, MetersPerSecond, Date) -> Void) {
        timer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.step(onUpdate)
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopUpdates() {
        timer?.invalidate()
        timer = nil
    }

    func monitorDestination(at coordinate: Coordinate, radius: Meters, onEntry: @escaping () -> Void) {
        // A chegada é detectada pelo próprio TripMonitor (distância ao destino).
    }

    func stopMonitoringDestination() {}

    private func step(_ onUpdate: (Coordinate, MetersPerSecond, Date) -> Void) {
        travelled = min(travelled + speed, totalDistance)
        let fraction = totalDistance > 0 ? travelled / totalDistance : 1
        let coordinate = Coordinate(
            latitude: start.latitude + (destination.latitude - start.latitude) * fraction,
            longitude: start.longitude + (destination.longitude - start.longitude) * fraction
        )
        lastKnownCoordinate = coordinate
        onUpdate(coordinate, MetersPerSecond(speed), Date())
        if fraction >= 1 { stopUpdates() }
    }
}
