import Foundation

/// Rota planejada do início até o destino.
/// `polyline` é a sequência de vértices usada pelo snap-to-route.
public struct Route: Codable, Hashable, Sendable {
    public var polyline: [Coordinate]
    public var totalDistance: Meters
    public var expectedDuration: Seconds
    public var destination: Coordinate

    public init(
        polyline: [Coordinate],
        totalDistance: Meters,
        expectedDuration: Seconds,
        destination: Coordinate
    ) {
        self.polyline = polyline
        self.totalDistance = totalDistance
        self.expectedDuration = expectedDuration
        self.destination = destination
    }
}
