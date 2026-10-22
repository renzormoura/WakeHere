import XCTest
@testable import AcordeAquiDomain

final class AlarmTimingPlannerTests: XCTestCase {
    func testScheduleComputesFireDateFromEta() {
        let clock = MockClock(now: Date(timeIntervalSinceReferenceDate: 1000))
        let planner = AlarmTimingPlanner(clock: clock, preAlert: Seconds(10))
        let rule = TimeBeforeArrivalRule(threshold: .minutes(10))

        // ETA 15 min com gatilho em 10 min → dispara em 300 s;
        // notificação 10 s antes = 290 s.
        let snapshot = TestFactory.makeSnapshot(
            eta: Seconds(900),
            timestamp: clock.now
        )
        let schedule = planner.schedule(snapshot: snapshot, rule: rule)

        XCTAssertEqual(schedule?.secondsFromNow.value ?? -1, 290, accuracy: 0.001)
        XCTAssertEqual(
            schedule?.fireDate,
            clock.now.addingTimeInterval(290)
        )
    }

    func testScheduleReturnsNilWhenTriggerIsImminent() {
        let clock = MockClock(now: Date(timeIntervalSinceReferenceDate: 1000))
        let planner = AlarmTimingPlanner(clock: clock, preAlert: Seconds(10))
        let rule = TimeBeforeArrivalRule(threshold: .minutes(10))

        // ETA 15 s: já dentro do pré-alerta → nada a agendar.
        let snapshot = TestFactory.makeSnapshot(eta: Seconds(15), timestamp: clock.now)
        XCTAssertNil(planner.schedule(snapshot: snapshot, rule: rule))
    }

    func testScheduleReturnsNilWhenRuleCannotEstimate() {
        let clock = MockClock(now: Date(timeIntervalSinceReferenceDate: 1000))
        let planner = AlarmTimingPlanner(clock: clock)
        let rule = DistanceBeforeArrivalRule(threshold: Meters(1000))

        let snapshot = TestFactory.makeSnapshot(
            remaining: Meters(10000),
            eta: Seconds(0),
            speed: MetersPerSecond(0),
            timestamp: clock.now
        )
        XCTAssertNil(planner.schedule(snapshot: snapshot, rule: rule))
    }

    func testScheduleReturnsNilForStaleSnapshot() {
        let clock = MockClock(now: Date(timeIntervalSinceReferenceDate: 2000))
        let planner = AlarmTimingPlanner(clock: clock, preAlert: Seconds(10))
        let rule = TimeBeforeArrivalRule(threshold: .minutes(10))

        // Medição feita há 10 min: a notificação já "passou".
        let snapshot = TestFactory.makeSnapshot(
            eta: Seconds(300),
            timestamp: Date(timeIntervalSinceReferenceDate: 1000)
        )
        XCTAssertNil(planner.schedule(snapshot: snapshot, rule: rule))
    }
}
