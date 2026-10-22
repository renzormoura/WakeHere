import MapKit
import AcordeAquiDomain

/// **Adapter** — implementa `RoutePlanning` com o MapKit (MKDirections).
final class MapKitRouteProvider: RoutePlanning {
    func planRoute(from origin: Coordinate, to destination: Destination) async throws -> Route {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin.clLocationCoordinate))
        request.destination = MKMapItem(
            placemark: MKPlacemark(coordinate: destination.coordinate.clLocationCoordinate)
        )
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)

        let response: MKDirections.Response
        do {
            response = try await directions.calculate()
        } catch let error as MKError {
            switch error.code {
            case .placemarkNotFound, .directionsNotFound:
                throw RoutePlanningError.noRouteFound
            default:
                throw RoutePlanningError.networkUnavailable
            }
        } catch {
            throw RoutePlanningError.networkUnavailable
        }

        guard let mkRoute = response.routes.first else {
            throw RoutePlanningError.noRouteFound
        }

        var coordinates = [CLLocationCoordinate2D](
            repeating: CLLocationCoordinate2D(),
            count: mkRoute.polyline.pointCount
        )
        coordinates.withUnsafeMutableBufferPointer { buffer in
            mkRoute.polyline.getCoordinates(
                buffer.baseAddress!,
                range: NSRange(location: 0, length: mkRoute.polyline.pointCount)
            )
        }

        let polyline = coordinates.map { Coordinate($0) }
        return Route(
            polyline: polyline.isEmpty ? [origin, destination.coordinate] : polyline,
            totalDistance: Meters(mkRoute.distance),
            expectedDuration: Seconds(mkRoute.expectedTravelTime),
            destination: destination.coordinate
        )
    }
}
