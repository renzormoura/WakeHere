import XCTest
@testable import WakeHereDomain

final class TripCodableTests: XCTestCase {
    func testRoundTripPreservesEverything() throws {
        let original = TestFactory.makeTrip(
            rule: DistanceBeforeArrivalRule(threshold: Meters(1200)),
            route: TestFactory.makeRoute()
        )
        original.phase = .tracking
        original.startedAt = Date(timeIntervalSinceReferenceDate: 100)
        original.lastSnapshot = TestFactory.makeSnapshot(remaining: Meters(2000))

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Trip.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.destination.name, original.destination.name)
        XCTAssertEqual(decoded.destination.coordinate, original.destination.coordinate)
        XCTAssertEqual(decoded.phase, .tracking)
        XCTAssertEqual(decoded.createdAt, original.createdAt)
        XCTAssertEqual(decoded.startedAt, original.startedAt)
        XCTAssertNil(decoded.finishedAt)
        XCTAssertEqual(decoded.lastSnapshot, original.lastSnapshot)
        XCTAssertEqual(decoded.route?.totalDistance, original.route?.totalDistance)

        // Regra preservada com o tipo concreto (Strategy polimórfica).
        let rule = try XCTUnwrap(decoded.rule as? DistanceBeforeArrivalRule)
        XCTAssertEqual(rule.threshold, Meters(1200))
    }

    func testRoundTripWithTimeRule() throws {
        let original = TestFactory.makeTrip(
            rule: TimeBeforeArrivalRule(threshold: .minutes(20), safetyMargin: .minutes(5)),
            route: nil
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Trip.self, from: data)

        XCTAssertNil(decoded.route)
        let rule = try XCTUnwrap(decoded.rule as? TimeBeforeArrivalRule)
        XCTAssertEqual(rule.threshold, .minutes(20))
        XCTAssertEqual(rule.safetyMargin, .minutes(5))
    }

    func testDecodingCorruptedRuleDiscriminatorFails() throws {
        let original = TestFactory.makeTrip(rule: TimeBeforeArrivalRule(threshold: .minutes(10)))
        let data = try JSONEncoder().encode(original)
        var json = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        json["encodedRule"] = [
            "discriminator": "unknownRule",
            // Codable serializa Data em base64 no JSON.
            "payload": Data("{}".utf8).base64EncodedString()
        ]
        let tampered = try JSONSerialization.data(withJSONObject: json)

        XCTAssertThrowsError(try JSONDecoder().decode(Trip.self, from: tampered))
    }
}
