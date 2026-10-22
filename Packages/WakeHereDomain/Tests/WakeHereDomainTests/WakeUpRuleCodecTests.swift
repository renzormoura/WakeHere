import XCTest
@testable import WakeHereDomain

final class WakeUpRuleCodecTests: XCTestCase {
    func testRoundTripPreservesTimeRule() throws {
        let original = TimeBeforeArrivalRule(
            threshold: .minutes(15),
            safetyMargin: .minutes(2),
            warningLead: .minutes(3)
        )
        let encoded = try WakeUpRuleCodec.encode(original)
        let decoded = try WakeUpRuleCodec.decode(encoded)

        XCTAssertEqual(encoded.discriminator, TimeBeforeArrivalRule.discriminator)
        let timeRule = try XCTUnwrap(decoded as? TimeBeforeArrivalRule)
        XCTAssertEqual(timeRule.threshold, original.threshold)
        XCTAssertEqual(timeRule.safetyMargin, original.safetyMargin)
        XCTAssertEqual(timeRule.warningLead, original.warningLead)
    }

    func testRoundTripPreservesDistanceRule() throws {
        let original = DistanceBeforeArrivalRule(
            threshold: Meters(2500),
            reactionTime: Seconds(5),
            warningLead: Meters(800)
        )
        let encoded = try WakeUpRuleCodec.encode(original)
        let decoded = try WakeUpRuleCodec.decode(encoded)

        XCTAssertEqual(encoded.discriminator, DistanceBeforeArrivalRule.discriminator)
        let distanceRule = try XCTUnwrap(decoded as? DistanceBeforeArrivalRule)
        XCTAssertEqual(distanceRule.threshold, original.threshold)
        XCTAssertEqual(distanceRule.reactionTime, original.reactionTime)
        XCTAssertEqual(distanceRule.warningLead, original.warningLead)
    }

    func testDecodeUnknownDiscriminatorThrows() {
        let fake = EncodedWakeUpRule(
            discriminator: "futureRule",
            payload: Data("{}".utf8)
        )
        XCTAssertThrowsError(try WakeUpRuleCodec.decode(fake)) { error in
            XCTAssertEqual(
                error as? WakeUpRuleCodecError,
                WakeUpRuleCodecError.unknownDiscriminator("futureRule")
            )
        }
    }
}
