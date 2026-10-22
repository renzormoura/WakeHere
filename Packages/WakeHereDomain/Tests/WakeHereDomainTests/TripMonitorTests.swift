import XCTest
@testable import WakeHereDomain

final class TripMonitorTests: XCTestCase {
    private var delegate: SpyMonitorDelegate!
    private var currentTime = Date(timeIntervalSinceReferenceDate: 1000)

    private func makeMonitor(
        rule: any WakeUpRule,
        route: Route? = TestFactory.makeRoute()
    ) -> TripMonitor {
        let trip = TestFactory.makeTrip(rule: rule, route: route)
        let monitor = TripMonitor(trip: trip, configuration: .default)
        let spy = SpyMonitorDelegate()
        monitor.delegate = spy
        delegate = spy
        return monitor
    }

    private func tick(_ seconds: TimeInterval) -> Date {
        currentTime = currentTime.addingTimeInterval(seconds)
        return currentTime
    }

    private let cruiseSpeed = MetersPerSecond(3335.8 / 300)

    // MARK: - Início

    func testStartTransitionsToTrackingOnlyOnce() {
        let monitor = makeMonitor(rule: TimeBeforeArrivalRule(threshold: .minutes(1)))
        monitor.start(at: currentTime)
        monitor.start(at: currentTime)

        XCTAssertEqual(monitor.phase, .tracking)
        XCTAssertEqual(delegate.phases, [.tracking])
        XCTAssertNotNil(monitor.trip.startedAt)
    }

    func testProcessingBeforeStartReturnsNil() {
        let monitor = makeMonitor(rule: TimeBeforeArrivalRule(threshold: .minutes(1)))
        let snapshot = monitor.process(
            location: TestFactory.startCoordinate,
            speed: cruiseSpeed,
            timestamp: currentTime
        )
        XCTAssertNil(snapshot)
    }

    // MARK: - Ciclo warning → ringing

    func testApproachingEntersWarningThenTriggersAlarm() {
        let monitor = makeMonitor(rule: TimeBeforeArrivalRule(threshold: .minutes(1)))
        monitor.start(at: currentTime)

        // Início: ETA ≈ 300 s → tracking.
        monitor.process(location: TestFactory.coordinate(atFraction: 0), speed: cruiseSpeed, timestamp: tick(10))
        XCTAssertEqual(monitor.phase, .tracking)

        // 50% da rota: ETA ≈ 150 s ≤ 60 + 120 de aviso → warning.
        monitor.process(location: TestFactory.coordinate(atFraction: 0.5), speed: cruiseSpeed, timestamp: tick(10))
        XCTAssertEqual(monitor.phase, .warning)

        // 85% da rota: ETA ≈ 45 s ≤ 60 → ringing.
        monitor.process(location: TestFactory.coordinate(atFraction: 0.85), speed: cruiseSpeed, timestamp: tick(10))
        XCTAssertEqual(monitor.phase, .ringing)
        XCTAssertEqual(delegate.alarmTriggers, 1)
        XCTAssertEqual(delegate.phases, [.tracking, .warning, .ringing])
        XCTAssertEqual(delegate.snapshots.count, 3)
    }

    func testWarningRecoversToTrackingWhenMovingAway() {
        let monitor = makeMonitor(rule: TimeBeforeArrivalRule(threshold: .minutes(1)))
        monitor.start(at: currentTime)

        monitor.process(location: TestFactory.coordinate(atFraction: 0.5), speed: cruiseSpeed, timestamp: tick(10))
        XCTAssertEqual(monitor.phase, .warning)

        monitor.process(location: TestFactory.coordinate(atFraction: 0), speed: cruiseSpeed, timestamp: tick(10))
        XCTAssertEqual(monitor.phase, .tracking)
        XCTAssertEqual(delegate.phases, [.tracking, .warning, .tracking])
    }

    // MARK: - Reroute

    func testOffRouteRequestsRerouteRespectingMinimumInterval() {
        let monitor = makeMonitor(rule: TimeBeforeArrivalRule(threshold: .minutes(1)))
        monitor.start(at: currentTime)

        let offRoute = Coordinate(latitude: -23.4500, longitude: -46.6300)

        monitor.process(location: offRoute, speed: cruiseSpeed, timestamp: tick(10))
        XCTAssertEqual(delegate.rerouteRequests, 1)

        let snapshot = try! XCTUnwrap(monitor.trip.lastSnapshot)
        XCTAssertFalse(snapshot.isOnRoute)
        XCTAssertEqual(
            snapshot.remainingMeters.value,
            offRoute.distance(to: TestFactory.endCoordinate).value,
            accuracy: 1
        )

        // Imediato de novo → respeita o intervalo mínimo (120 s).
        monitor.process(location: offRoute, speed: cruiseSpeed, timestamp: tick(10))
        XCTAssertEqual(delegate.rerouteRequests, 1)

        // Após o intervalo → novo pedido.
        monitor.process(location: offRoute, speed: cruiseSpeed, timestamp: tick(200))
        XCTAssertEqual(delegate.rerouteRequests, 2)
    }

    func testUpdateRouteResetsRerouteThrottle() {
        let monitor = makeMonitor(rule: TimeBeforeArrivalRule(threshold: .minutes(1)))
        monitor.start(at: currentTime)

        let offRoute = Coordinate(latitude: -23.4500, longitude: -46.6300)
        monitor.process(location: offRoute, speed: cruiseSpeed, timestamp: tick(10))
        XCTAssertEqual(delegate.rerouteRequests, 1)

        let newRoute = Route(
            polyline: [TestFactory.coordinate(atFraction: 0.9), TestFactory.endCoordinate],
            totalDistance: Meters(350),
            expectedDuration: Seconds(30),
            destination: TestFactory.endCoordinate
        )
        monitor.updateRoute(newRoute)
        XCTAssertEqual(monitor.trip.route, newRoute)

        monitor.process(location: offRoute, speed: cruiseSpeed, timestamp: tick(10))
        XCTAssertEqual(delegate.rerouteRequests, 2)
    }

    // MARK: - Alarme, snooze e chegada

    func testStopAlarmBeforeArrivalReturnsToTracking() {
        let monitor = makeMonitor(rule: TimeBeforeArrivalRule(threshold: .minutes(1)))
        monitor.start(at: currentTime)
        monitor.process(location: TestFactory.coordinate(atFraction: 0.85), speed: cruiseSpeed, timestamp: tick(10))
        XCTAssertEqual(monitor.phase, .ringing)

        monitor.stopAlarm(at: currentTime)
        XCTAssertEqual(monitor.phase, .tracking)
    }

    func testSnoozeDefersAlarmAndReTriggersAtDeadline() {
        let monitor = makeMonitor(rule: TimeBeforeArrivalRule(threshold: .minutes(1)))
        monitor.start(at: currentTime)
        monitor.process(location: TestFactory.coordinate(atFraction: 0.85), speed: cruiseSpeed, timestamp: tick(10))
        XCTAssertEqual(delegate.alarmTriggers, 1)

        let deadline = currentTime.addingTimeInterval(180)
        monitor.snooze(until: deadline)
        XCTAssertEqual(monitor.phase, .snoozed)

        // Antes do prazo → nada toca.
        monitor.process(location: TestFactory.coordinate(atFraction: 0.9), speed: cruiseSpeed, timestamp: tick(60))
        XCTAssertEqual(delegate.alarmTriggers, 1)
        XCTAssertEqual(monitor.phase, .snoozed)

        // No prazo → toca de novo.
        monitor.process(location: TestFactory.coordinate(atFraction: 0.9), speed: cruiseSpeed, timestamp: tick(120))
        XCTAssertEqual(delegate.alarmTriggers, 2)
        XCTAssertEqual(monitor.phase, .ringing)
    }

    func testArrivalTriggersAlarmEvenWithPendingRule() {
        // Regra de 1 s: jamais dispararia sozinha antes da chegada.
        let monitor = makeMonitor(rule: TimeBeforeArrivalRule(threshold: Seconds(1)))
        monitor.start(at: currentTime)
        monitor.process(location: TestFactory.coordinate(atFraction: 0), speed: cruiseSpeed, timestamp: tick(10))

        // ~33 m do destino (raio de chegada = 40 m).
        monitor.process(location: TestFactory.coordinate(atFraction: 0.99), speed: cruiseSpeed, timestamp: tick(10))
        XCTAssertEqual(monitor.phase, .ringing)
        XCTAssertEqual(delegate.alarmTriggers, 1)

        // Parar o alarme aqui = viagem concluída.
        monitor.stopAlarm(at: currentTime)
        XCTAssertEqual(monitor.phase, .arrived)
        XCTAssertNotNil(monitor.trip.finishedAt)

        // Viagem terminada: processar mais não faz nada.
        let snapshot = monitor.process(
            location: TestFactory.endCoordinate,
            speed: cruiseSpeed,
            timestamp: tick(10)
        )
        XCTAssertNil(snapshot)
    }

    // MARK: - Cancelamento

    func testCancelFinishesTripAndStopsProcessing() {
        let monitor = makeMonitor(rule: TimeBeforeArrivalRule(threshold: .minutes(1)))
        monitor.start(at: currentTime)
        monitor.cancel(at: currentTime)

        XCTAssertEqual(monitor.phase, .cancelled)
        XCTAssertNotNil(monitor.trip.finishedAt)
        XCTAssertEqual(delegate.phases, [.tracking, .cancelled])

        let snapshot = monitor.process(
            location: TestFactory.startCoordinate,
            speed: cruiseSpeed,
            timestamp: tick(10)
        )
        XCTAssertNil(snapshot)

        // Cancelar de novo é inofensivo.
        monitor.cancel(at: currentTime)
        XCTAssertEqual(monitor.phase, .cancelled)
        XCTAssertEqual(delegate.phases, [.tracking, .cancelled])
    }

    // MARK: - Geofence (chegada forçada)

    func testForceArrivalTriggersAlarmAndConfirmsArrival() {
        // Regra de 1 min: em 50% da rota (ETA ≈ 150 s) ainda está pendente,
        // mas já em fase de atenção (warningLead de 120 s).
        let monitor = makeMonitor(rule: TimeBeforeArrivalRule(threshold: .minutes(1)))
        monitor.start(at: currentTime)
        monitor.process(
            location: TestFactory.coordinate(atFraction: 0.5),
            speed: cruiseSpeed,
            timestamp: tick(10)
        )
        XCTAssertEqual(monitor.phase, .warning)

        // Geofence do destino dispara (app pode ter sido morto pelo iOS).
        monitor.forceArrival(at: currentTime)
        XCTAssertEqual(monitor.phase, .ringing)
        XCTAssertEqual(delegate.alarmTriggers, 1)

        // Parar o alarme conclui a viagem (chegada confirmada,
        // mesmo que o último snapshot esteja longe do raio).
        monitor.stopAlarm(at: currentTime)
        XCTAssertEqual(monitor.phase, .arrived)
    }

    func testForceArrivalIsIgnoredWhenInactive() {
        let monitor = makeMonitor(rule: TimeBeforeArrivalRule(threshold: .minutes(1)))
        // Ainda em planned → geofence não faz nada.
        monitor.forceArrival(at: currentTime)
        XCTAssertEqual(monitor.phase, .planned)
        XCTAssertEqual(delegate.alarmTriggers, 0)
    }

    // MARK: - ETA dinâmico / chegada estimada

    func testSnapshotEstimatedArrivalReflectsDynamicETA() {
        let monitor = makeMonitor(rule: TimeBeforeArrivalRule(threshold: .minutes(1)))
        monitor.start(at: currentTime)

        let snapshot = try! XCTUnwrap(
            monitor.process(
                location: TestFactory.coordinate(atFraction: 0.5),
                speed: cruiseSpeed,
                timestamp: tick(10)
            )
        )

        // Chegada estimada = timestamp + ETA dinâmico (não um horário fixo).
        XCTAssertEqual(
            snapshot.estimatedArrival.timeIntervalSince(snapshot.timestamp),
            snapshot.estimatedRemainingSeconds.value,
            accuracy: 1.0
        )
        // Com rota, consideramos ETA dinâmico (refinado por reroute periódico).
        XCTAssertTrue(snapshot.isDynamicETA)
    }

    func testWithoutRouteReportsETAFromGPSOnly() {
        let rule = DistanceBeforeArrivalRule(threshold: Meters(1000))
        let monitor = makeMonitor(rule: rule, route: nil)
        monitor.start(at: currentTime)

        let here = Coordinate(latitude: -23.5750, longitude: -46.6300)
        let snapshot = try! XCTUnwrap(
            monitor.process(location: here, speed: MetersPerSecond(10), timestamp: tick(10))
        )

        // Sem rota, o ETA é geodésico + EMA GPS — ainda dinâmico no sentido de
        // ser recalcado a cada update, mas não com tráfego ao vivo de rota.
        XCTAssertEqual(
            snapshot.estimatedArrival.timeIntervalSince(snapshot.timestamp),
            snapshot.estimatedRemainingSeconds.value,
            accuracy: 1.0
        )
    }

    // MARK: - Sem rota (modo raio)

    func testWithoutRouteUsesGeodesicDistanceAndNeverRequestsReroute() {
        let rule = DistanceBeforeArrivalRule(threshold: Meters(1000))
        let monitor = makeMonitor(rule: rule, route: nil)
        monitor.start(at: currentTime)

        // ~556 m antes do destino.
        let here = Coordinate(latitude: -23.5750, longitude: -46.6300)
        let snapshot = try! XCTUnwrap(
            monitor.process(location: here, speed: MetersPerSecond(10), timestamp: tick(10))
        )

        XCTAssertFalse(snapshot.isOnRoute)
        XCTAssertEqual(
            snapshot.remainingMeters.value,
            here.distance(to: TestFactory.endCoordinate).value,
            accuracy: 1
        )
        // 556 m ≤ 1000 + folga → alarme.
        XCTAssertEqual(monitor.phase, .ringing)
        XCTAssertEqual(delegate.rerouteRequests, 0)
    }

    func testSnapshotReportsRemainingAlongRoute() {
        let monitor = makeMonitor(rule: TimeBeforeArrivalRule(threshold: .minutes(1)))
        monitor.start(at: currentTime)

        let snapshot = try! XCTUnwrap(
            monitor.process(
                location: TestFactory.coordinate(atFraction: 0.5),
                speed: cruiseSpeed,
                timestamp: tick(10)
            )
        )
        XCTAssertTrue(snapshot.isOnRoute)
        XCTAssertEqual(snapshot.deviationFromRoute.value, 0, accuracy: 2)
        // Metade da rota restante (rota ≈ 3336 m).
        XCTAssertEqual(snapshot.remainingMeters.value, 1668, accuracy: 20)
        XCTAssertEqual(snapshot.estimatedRemainingSeconds.value, 150, accuracy: 3)
        // estimatedArrival = timestamp + ETA (com folga para arredondamento).
        XCTAssertEqual(
            snapshot.estimatedArrival.timeIntervalSince(snapshot.timestamp),
            150,
            accuracy: 1.0
        )
    }
}
