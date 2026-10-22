import Foundation
import XCTest
@testable import AcordeAquiDomain

// MARK: - Fábricas de objetos de teste

enum TestFactory {
    /// Rota reta de ~3 km de latitude (A → B), duração planejada de 300 s.
    static let startCoordinate = Coordinate(latitude: -23.5500, longitude: -46.6300)
    static let endCoordinate = Coordinate(latitude: -23.5800, longitude: -46.6300)

    static func makeRoute() -> Route {
        let polyline = [startCoordinate, endCoordinate]
        return Route(
            polyline: polyline,
            totalDistance: RouteGeometry.totalLength(of: polyline),
            expectedDuration: Seconds(300),
            destination: endCoordinate
        )
    }

    static func makeDestination() -> Destination {
        Destination(name: "Terminal Centro", subtitle: "Av. Principal", coordinate: endCoordinate)
    }

    /// Ponto interpolado na rota: f = 0 no início, f = 1 no destino.
    static func coordinate(atFraction f: Double) -> Coordinate {
        Coordinate(
            latitude: startCoordinate.latitude + (endCoordinate.latitude - startCoordinate.latitude) * f,
            longitude: startCoordinate.longitude
        )
    }

    static func makeSnapshot(
        remaining: Meters = Meters(1000),
        eta: Seconds = Seconds(100),
        speed: MetersPerSecond = MetersPerSecond(10),
        timestamp: Date = Date(timeIntervalSinceReferenceDate: 0)
    ) -> TripSnapshot {
        TripSnapshot(
            coordinate: startCoordinate,
            speed: speed,
            timestamp: timestamp,
            remainingMeters: remaining,
            estimatedRemainingSeconds: eta,
            deviationFromRoute: .zero,
            isOnRoute: true,
            snappedCoordinate: startCoordinate
        )
    }

    static func makeTrip(
        rule: any WakeUpRule,
        route: Route? = TestFactory.makeRoute()
    ) -> Trip {
        Trip(
            destination: makeDestination(),
            rule: rule,
            route: route,
            phase: .planned,
            createdAt: Date(timeIntervalSinceReferenceDate: 0)
        )
    }
}

// MARK: - Dupla

final class MockClock: Clock {
    var now: Date

    init(now: Date = Date(timeIntervalSinceReferenceDate: 0)) {
        self.now = now
    }
}

// MARK: - Spy de observador (Observer pattern)

final class SpyMonitorDelegate: TripMonitorDelegate {
    private(set) var snapshots: [TripSnapshot] = []
    private(set) var phases: [TripPhase] = []
    private(set) var rerouteRequests = 0
    private(set) var alarmTriggers = 0

    func tripMonitor(_ monitor: TripMonitor, didUpdateSnapshot snapshot: TripSnapshot) {
        snapshots.append(snapshot)
    }

    func tripMonitor(_ monitor: TripMonitor, didChangePhase phase: TripPhase) {
        phases.append(phase)
    }

    func tripMonitorDidRequestReroute(_ monitor: TripMonitor) {
        rerouteRequests += 1
    }

    func tripMonitorDidTriggerAlarm(_ monitor: TripMonitor) {
        alarmTriggers += 1
    }
}
