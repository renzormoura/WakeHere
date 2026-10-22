import CoreLocation
import AcordeAquiDomain

extension Coordinate {
    /// Converte para o tipo do CoreLocation/MapKit.
    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Cria a partir de uma coordenada do CoreLocation.
    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}
