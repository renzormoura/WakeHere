import MapKit
import AcordeAquiDomain

/// **Adapter** — implementa `PlaceSearching` com MKLocalSearch.
final class MapKitPlaceSearcher: PlaceSearching {
    func searchPlaces(matching query: String) async throws -> [Destination] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed

        let search = MKLocalSearch(request: request)
        let response: MKLocalSearch.Response
        do {
            response = try await search.start()
        } catch {
            throw RoutePlanningError.searchFailed
        }

        return response.mapItems.compactMap { item in
            guard let name = item.name, !name.isEmpty else { return nil }
            let placemark = item.placemark
            var addressParts: [String] = []
            if let street = placemark.thoroughfare {
                addressParts.append(street)
            }
            if let city = placemark.locality {
                addressParts.append(city)
            }
            return Destination(
                name: name,
                subtitle: addressParts.isEmpty ? nil : addressParts.joined(separator: ", "),
                coordinate: Coordinate(placemark.coordinate)
            )
        }
    }
}
