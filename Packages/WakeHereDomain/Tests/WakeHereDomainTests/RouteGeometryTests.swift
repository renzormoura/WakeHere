import XCTest
@testable import WakeHereDomain

final class RouteGeometryTests: XCTestCase {
    // Reta horizontal (mesma latitude) de ~1 km.
    private let west = Coordinate(latitude: -23.5500, longitude: -46.6300)
    private let east = Coordinate(latitude: -23.5500, longitude: -46.6200)

    private var straightPolyline: [Coordinate] { [west, east] }

    func testTotalLength() {
        let length = RouteGeometry.totalLength(of: straightPolyline)
        // 0.01° de longitude a -23,55° ≈ 1.020 m
        XCTAssertEqual(length.value, 1020, accuracy: 30)
    }

    func testTotalLengthOfSinglePointIsZero() {
        XCTAssertEqual(RouteGeometry.totalLength(of: [west]).value, 0)
        XCTAssertEqual(RouteGeometry.totalLength(of: []).value, 0)
    }

    func testSnapOfPointOnTheLineHasZeroDeviation() {
        let midpoint = Coordinate(latitude: -23.5500, longitude: -46.6250)
        let result = RouteGeometry.snap(midpoint, along: straightPolyline)

        XCTAssertEqual(result.distanceFromRoute.value, 0, accuracy: 2)
        XCTAssertEqual(result.remainingToEnd.value, 510, accuracy: 15)
    }

    func testSnapBeyondTheEndClampsToDestination() {
        let beyond = Coordinate(latitude: -23.5500, longitude: -46.6150)
        let result = RouteGeometry.snap(beyond, along: straightPolyline)

        XCTAssertEqual(result.snapped, east)
        XCTAssertEqual(result.remainingToEnd.value, 0, accuracy: 1)
        // Passou ~510 m do fim.
        XCTAssertEqual(result.distanceFromRoute.value, 510, accuracy: 20)
    }

    func testSnapBeforeTheStartClampsToOrigin() {
        let before = Coordinate(latitude: -23.5500, longitude: -46.6350)
        let result = RouteGeometry.snap(before, along: straightPolyline)

        XCTAssertEqual(result.snapped, west)
        XCTAssertEqual(result.remainingToEnd.value, RouteGeometry.totalLength(of: straightPolyline).value, accuracy: 5)
    }

    func testSnapWithPerpendicularOffsetMeasuresDeviation() {
        // ~111 m acima do ponto médio.
        let offset = Coordinate(latitude: -23.5490, longitude: -46.6250)
        let result = RouteGeometry.snap(offset, along: straightPolyline)

        XCTAssertEqual(result.distanceFromRoute.value, 111, accuracy: 8)
        XCTAssertEqual(result.remainingToEnd.value, 510, accuracy: 20)
    }

    func testSnapOnPolylineWithSeveralSegments() {
        let polyline = [
            Coordinate(latitude: -23.5500, longitude: -46.6300),
            Coordinate(latitude: -23.5600, longitude: -46.6300),
            Coordinate(latitude: -23.5600, longitude: -46.6200)
        ]
        // Ponto no meio do segundo segmento (horizontal).
        let point = Coordinate(latitude: -23.5600, longitude: -46.6250)
        let result = RouteGeometry.snap(point, along: polyline)

        XCTAssertEqual(result.distanceFromRoute.value, 0, accuracy: 2)
        let secondSegment = polyline[1].distance(to: polyline[2])
        XCTAssertEqual(result.remainingToEnd.value, secondSegment.value / 2, accuracy: 15)
    }

    func testSnapWithSinglePointPolyline() {
        let result = RouteGeometry.snap(TestFactory.endCoordinate, along: [west])
        XCTAssertEqual(result.snapped, west)
        XCTAssertEqual(result.remainingToEnd.value, 0)
    }

    func testSnapWithEmptyPolylineReturnsInputPoint() {
        let point = TestFactory.startCoordinate
        let result = RouteGeometry.snap(point, along: [])
        XCTAssertEqual(result.snapped, point)
        XCTAssertEqual(result.remainingToEnd.value, 0)
    }

    func testRemainingLengthFromIndex() {
        let polyline = straightPolyline
        XCTAssertEqual(
            RouteGeometry.remainingLength(from: polyline, to: 0).value,
            RouteGeometry.totalLength(of: polyline).value,
            accuracy: 0.1
        )
        XCTAssertEqual(RouteGeometry.remainingLength(from: polyline, to: 1).value, 0)
        XCTAssertEqual(RouteGeometry.remainingLength(from: polyline, to: 5).value, 0)
    }
}
