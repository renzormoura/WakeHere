import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

/// Resultado do encaixe (snap) de um ponto na polyline da rota.
public struct SnapResult: Equatable, Sendable {
    /// Ponto mais próximo sobre a rota.
    public let snapped: Coordinate
    /// Distância do usuário até a rota (desvio).
    public let distanceFromRoute: Meters
    /// Distância restante, pela rota, do ponto encaixado até o fim.
    public let remainingToEnd: Meters

    public init(snapped: Coordinate, distanceFromRoute: Meters, remainingToEnd: Meters) {
        self.snapped = snapped
        self.distanceFromRoute = distanceFromRoute
        self.remainingToEnd = remainingToEnd
    }
}

/// **Geométrica de rota** — coração do cálculo de "quanto falta".
///
/// Funções puras (testáveis sem GPS): projeção ponto-segmento numa projeção
/// local equiretangular (precisa para distâncias urbanas) + haversine para
/// distâncias globais.
public enum RouteGeometry {
    /// Comprimento total da polyline.
    public static func totalLength(of polyline: [Coordinate]) -> Meters {
        guard polyline.count > 1 else { return .zero }
        var total = Meters.zero
        for index in 0..<(polyline.count - 1) {
            total = total + polyline[index].distance(to: polyline[index + 1])
        }
        return total
    }

    /// Distância do vértice `index` até o fim da polyline.
    public static func remainingLength(from polyline: [Coordinate], to index: Int) -> Meters {
        guard index < polyline.count - 1 else { return .zero }
        var total = Meters.zero
        for i in index..<(polyline.count - 1) {
            total = total + polyline[i].distance(to: polyline[i + 1])
        }
        return total
    }

    /// Encaixa `point` na polyline mais próxima e calcula o que resta até o fim.
    public static func snap(_ point: Coordinate, along polyline: [Coordinate]) -> SnapResult {
        guard polyline.count >= 2 else {
            if let only = polyline.first {
                return SnapResult(
                    snapped: only,
                    distanceFromRoute: point.distance(to: only),
                    remainingToEnd: .zero
                )
            }
            return SnapResult(snapped: point, distanceFromRoute: .zero, remainingToEnd: .zero)
        }

        // Projeção local: metros por grau no ponto de referência.
        let latitudeRadians = point.latitude * .pi / 180
        let metersPerDegreeLatitude = 111_194.93
        let metersPerDegreeLongitude = 111_319.49 * max(cos(latitudeRadians), 1e-6)

        func localXY(_ coordinate: Coordinate) -> (x: Double, y: Double) {
            let x = (coordinate.longitude - point.longitude) * metersPerDegreeLongitude
            let y = (coordinate.latitude - point.latitude) * metersPerDegreeLatitude
            return (x, y)
        }

        var bestDistance = Double.greatestFiniteMagnitude
        var bestSnapped = polyline[0]
        var bestIndex = 0
        var bestFraction = 0.0

        for index in 0..<(polyline.count - 1) {
            let a = localXY(polyline[index])
            let b = localXY(polyline[index + 1])

            let abx = b.x - a.x
            let aby = b.y - a.y
            let lengthSquared = abx * abx + aby * aby

            var t = 0.0
            if lengthSquared > 1e-12 {
                // Projeta a origem (o point) no segmento a→b.
                t = (-a.x * abx + -a.y * aby) / lengthSquared
                t = min(1, max(0, t))
            }

            let px = a.x + t * abx
            let py = a.y + t * aby
            let distance = (px * px + py * py).squareRoot()

            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
                bestFraction = t
                bestSnapped = Coordinate(
                    latitude: point.latitude + py / metersPerDegreeLatitude,
                    longitude: point.longitude + px / metersPerDegreeLongitude
                )
            }
        }

        let segmentLength = polyline[bestIndex].distance(to: polyline[bestIndex + 1])
        let remainingInSegment = segmentLength * (1 - bestFraction)
        let tail = remainingLength(from: polyline, to: bestIndex + 1)
        let remaining = remainingInSegment + tail
        let deviation = point.distance(to: bestSnapped)

        return SnapResult(
            snapped: bestSnapped,
            distanceFromRoute: deviation,
            remainingToEnd: remaining
        )
    }
}
