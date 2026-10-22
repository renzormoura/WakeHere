import XCTest
@testable import AcordeAquiDomain

final class TravelEstimatorTests: XCTestCase {
    func testInitialSpeedFromRoute() {
        let route = TestFactory.makeRoute()
        let estimator = TravelEstimator(route: route)

        let expected = route.totalDistance.value / route.expectedDuration.value
        XCTAssertEqual(estimator.averageSpeed.value, expected, accuracy: 0.01)
    }

    func testExponentialMovingAverageConvergesToSamples() {
        let estimator = TravelEstimator(initialSpeed: MetersPerSecond(10))
        for _ in 0..<40 {
            estimator.registerSample(speed: MetersPerSecond(20))
        }
        XCTAssertEqual(estimator.averageSpeed.value, 20, accuracy: 1.0)
    }

    func testNegativeSamplesAreIgnored() {
        let estimator = TravelEstimator(initialSpeed: MetersPerSecond(15))
        estimator.registerSample(speed: MetersPerSecond(-100))
        XCTAssertEqual(estimator.averageSpeed.value, 15, accuracy: 0.001)
    }

    func testEstimatedTimeUsesCurrentSpeed() {
        let estimator = TravelEstimator(initialSpeed: MetersPerSecond(10))
        let eta = estimator.estimatedTime(toCover: Meters(1000))
        XCTAssertEqual(eta.value, 100, accuracy: 0.01)
    }

    func testEstimatedTimeHasSafetyFloorWhenStopped() {
        let estimator = TravelEstimator(initialSpeed: MetersPerSecond(10))
        for _ in 0..<60 {
            estimator.registerSample(speed: MetersPerSecond(0))
        }
        // Piso de 0,5 m/s evita ETA infinito com o veículo parado.
        let eta = estimator.estimatedTime(toCover: Meters(100))
        XCTAssertEqual(eta.value, 200, accuracy: 1)
    }

    func testInvalidBlendFactorIsClamped() {
        let estimator = TravelEstimator(initialSpeed: MetersPerSecond(10), blendingFactor: 99)
        estimator.registerSample(speed: MetersPerSecond(30))
        // blending fator limitado a 1.0 → média vira a amostra.
        XCTAssertEqual(estimator.averageSpeed.value, 30, accuracy: 0.01)
    }
}
