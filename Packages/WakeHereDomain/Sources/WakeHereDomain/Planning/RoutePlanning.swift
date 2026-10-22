import Foundation

public enum RoutePlanningError: Error, Equatable {
    case noRouteFound
    case networkUnavailable
    case searchFailed
}

/// Porta (**DIP**) para planejamento de rotas. Implementação: MapKit.
public protocol RoutePlanning: AnyObject {
    func planRoute(from origin: Coordinate, to destination: Destination) async throws -> Route
}

/// Porta (**DIP**) para busca de lugares. Implementação: MKLocalSearch.
public protocol PlaceSearching: AnyObject {
    func searchPlaces(matching query: String) async throws -> [Destination]
}
