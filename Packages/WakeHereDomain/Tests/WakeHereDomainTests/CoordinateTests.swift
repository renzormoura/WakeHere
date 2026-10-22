import XCTest
@testable import WakeHereDomain

final class CoordinateTests: XCTestCase {
    func testDistanceToSelfIsZero() {
        let point = TestFactory.startCoordinate
        XCTAssertEqual(point.distance(to: point).value, 0, accuracy: 0.001)
    }

    func testDistanceIsSymmetric() {
        let a = TestFactory.startCoordinate
        let b = TestFactory.endCoordinate
        XCTAssertEqual(a.distance(to: b).value, b.distance(to: a).value, accuracy: 0.001)
    }

    func testDistanceOfOneThousandthOfADegreeOfLatitude() {
        let a = Coordinate(latitude: -23.000, longitude: -46.000)
        let b = Coordinate(latitude: -23.001, longitude: -46.000)
        // 0.001° de latitude ≈ 111,19 m
        XCTAssertEqual(a.distance(to: b).value, 111.2, accuracy: 2.0)
    }

    func testSaoPauloToRioIsApproximately360Kilometers() {
        let saoPaulo = Coordinate(latitude: -23.5505, longitude: -46.6333)
        let rio = Coordinate(latitude: -22.9068, longitude: -43.1729)
        let km = saoPaulo.distance(to: rio).kilometers
        XCTAssertGreaterThan(km, 340)
        XCTAssertLessThan(km, 380)
    }

    func testCodableRoundTrip() throws {
        let original = TestFactory.startCoordinate
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Coordinate.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
