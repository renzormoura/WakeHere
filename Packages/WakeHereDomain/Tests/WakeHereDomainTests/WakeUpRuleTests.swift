import XCTest
@testable import WakeHereDomain

final class WakeUpRuleTests: XCTestCase {
    // MARK: - TimeBeforeArrivalRule

    func testTimeRuleTriggersAtExactThreshold() {
        let rule = TimeBeforeArrivalRule(threshold: .minutes(10))
        let snapshot = TestFactory.makeSnapshot(eta: Seconds(600))
        XCTAssertEqual(rule.evaluate(with: snapshot), .triggered)
    }

    func testTimeRuleStaysPendingJustAboveThreshold() {
        let rule = TimeBeforeArrivalRule(threshold: .minutes(10))
        let snapshot = TestFactory.makeSnapshot(eta: Seconds(601))
        XCTAssertEqual(rule.evaluate(with: snapshot), .pending)
    }

    func testTimeRuleSafetyMarginWidensTheTrigger() {
        let rule = TimeBeforeArrivalRule(
            threshold: .minutes(10),
            safetyMargin: .minutes(1)
        )
        // 10 min 50 s de ETA: dentro do limiar + margem de 1 min.
        let snapshot = TestFactory.makeSnapshot(eta: Seconds(650))
        XCTAssertEqual(rule.evaluate(with: snapshot), .triggered)
    }

    func testTimeRuleApproachingUsesWarningLead() {
        let rule = TimeBeforeArrivalRule(
            threshold: .minutes(10),
            warningLead: .minutes(2)
        )
        XCTAssertTrue(rule.isApproaching(TestFactory.makeSnapshot(eta: Seconds(720))))
        XCTAssertFalse(rule.isApproaching(TestFactory.makeSnapshot(eta: Seconds(721))))
    }

    func testTimeRuleSecondsUntilTriggering() {
        let rule = TimeBeforeArrivalRule(threshold: .minutes(10))
        let seconds = rule.secondsUntilTriggering(
            snapshot: TestFactory.makeSnapshot(eta: Seconds(900))
        )
        XCTAssertEqual(seconds?.value ?? -1, 300, accuracy: 0.001)
    }

    func testTimeRuleSecondsUntilTriggeringClampsToZeroWhenOverdue() {
        let rule = TimeBeforeArrivalRule(threshold: .minutes(10))
        let seconds = rule.secondsUntilTriggering(
            snapshot: TestFactory.makeSnapshot(eta: Seconds(100))
        )
        XCTAssertEqual(seconds?.value, 0)
    }

    func testTimeRuleSummary() {
        XCTAssertEqual(
            TimeBeforeArrivalRule(threshold: .minutes(10)).summary,
            "Acordar 10 min antes de chegar"
        )
        XCTAssertEqual(
            TimeBeforeArrivalRule(threshold: .minutes(90)).summary,
            "Acordar 1 h 30 min antes de chegar"
        )
        XCTAssertEqual(
            TimeBeforeArrivalRule(threshold: .minutes(120)).summary,
            "Acordar 2 h antes de chegar"
        )
    }

    // MARK: - DistanceBeforeArrivalRule

    func testDistanceRuleTriggersWithinThreshold() {
        let rule = DistanceBeforeArrivalRule(threshold: Meters(1000))
        // Velocidade 10 m/s × 3 s de reação = 30 m de folga → gatilho em 1030 m.
        let snapshot = TestFactory.makeSnapshot(remaining: Meters(1030), speed: MetersPerSecond(10))
        XCTAssertEqual(rule.evaluate(with: snapshot), .triggered)
    }

    func testDistanceRuleStaysPendingOutsideThreshold() {
        let rule = DistanceBeforeArrivalRule(threshold: Meters(1000))
        let snapshot = TestFactory.makeSnapshot(remaining: Meters(1031), speed: MetersPerSecond(10))
        XCTAssertEqual(rule.evaluate(with: snapshot), .pending)
    }

    func testDistanceRuleReactionBufferGrowsWithSpeed() {
        let rule = DistanceBeforeArrivalRule(threshold: Meters(1000))
        // Em alta velocidade (30 m/s) o buffer é 90 m: dispara em 1090 m.
        let fast = TestFactory.makeSnapshot(remaining: Meters(1090), speed: MetersPerSecond(30))
        XCTAssertEqual(rule.evaluate(with: fast), .triggered)

        let slow = TestFactory.makeSnapshot(remaining: Meters(1090), speed: MetersPerSecond(1))
        XCTAssertEqual(rule.evaluate(with: slow), .pending)
    }

    func testDistanceRuleApproachingUsesWarningLead() {
        let rule = DistanceBeforeArrivalRule(
            threshold: Meters(1000),
            warningLead: Meters(500)
        )
        // Gatilho em 1030; aviso em 1530.
        XCTAssertTrue(rule.isApproaching(TestFactory.makeSnapshot(remaining: Meters(1500))))
        XCTAssertFalse(rule.isApproaching(TestFactory.makeSnapshot(remaining: Meters(1540))))
    }

    func testDistanceRuleSecondsUntilTriggering() {
        let rule = DistanceBeforeArrivalRule(threshold: Meters(1000))
        // restante 2000 m, ETA 200 s → velocidade efetiva 10 m/s.
        // até o gatilho: (2000 − 1030) / 10 = 97 s.
        let snapshot = TestFactory.makeSnapshot(
            remaining: Meters(2000),
            eta: Seconds(200),
            speed: MetersPerSecond(10)
        )
        let seconds = rule.secondsUntilTriggering(snapshot: snapshot)
        XCTAssertEqual(seconds?.value ?? -1, 97, accuracy: 0.001)
    }

    func testDistanceRuleSecondsUntilTriggeringIsNilWithoutSpeed() {
        let rule = DistanceBeforeArrivalRule(threshold: Meters(1000))
        let snapshot = TestFactory.makeSnapshot(
            remaining: Meters(10000),
            eta: Seconds(0),
            speed: MetersPerSecond(0)
        )
        XCTAssertNil(rule.secondsUntilTriggering(snapshot: snapshot))
    }

    func testDistanceRuleSummary() {
        XCTAssertEqual(
            DistanceBeforeArrivalRule(threshold: Meters(1500)).summary,
            "Acordar a 1.5 km do ponto"
        )
        XCTAssertEqual(
            DistanceBeforeArrivalRule(threshold: Meters(300)).summary,
            "Acordar a 300 m do ponto"
        )
    }
}
