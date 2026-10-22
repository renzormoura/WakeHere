import Foundation

/// Ponto onde o usuário quer ser acordado (pin no mapa, busca ou parada final).
public struct Destination: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var subtitle: String?
    public var coordinate: Coordinate

    public init(id: UUID = UUID(), name: String, subtitle: String? = nil, coordinate: Coordinate) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.coordinate = coordinate
    }
}
