import Foundation

/// Fotografia de um instante da viagem: é a **entrada** das regras de despertar.
public struct TripSnapshot: Codable, Hashable, Sendable {
    /// Posição atual do usuário (GPS).
    public let coordinate: Coordinate
    /// Velocidade instantânea.
    public let speed: MetersPerSecond
    /// Quando esta medição foi feita.
    public let timestamp: Date
    /// Distância restante efetiva (pela rota se estiver nela; senão geodésica).
    public let remainingMeters: Meters
    /// ETA restante calculado pelo `TravelEstimator`.
    public let estimatedRemainingSeconds: Seconds
    /// Desvio perpendicular em relação à rota planejada.
    public let deviationFromRoute: Meters
    /// Se o usuário está (tolerantemente) sobre a rota.
    public let isOnRoute: Bool
    /// Ponto da rota mais próximo do usuário (quando há rota).
    public let snappedCoordinate: Coordinate?

    public init(
        coordinate: Coordinate,
        speed: MetersPerSecond,
        timestamp: Date,
        remainingMeters: Meters,
        estimatedRemainingSeconds: Seconds,
        deviationFromRoute: Meters,
        isOnRoute: Bool,
        snappedCoordinate: Coordinate?
    ) {
        self.coordinate = coordinate
        self.speed = speed
        self.timestamp = timestamp
        self.remainingMeters = remainingMeters
        self.estimatedRemainingSeconds = estimatedRemainingSeconds
        self.deviationFromRoute = deviationFromRoute
        self.isOnRoute = isOnRoute
        self.snappedCoordinate = snappedCoordinate
    }

    /// Hora estimada de chegada com base no ETA dinâmico.
    public var estimatedArrival: Date {
        timestamp.addingTimeInterval(estimatedRemainingSeconds.value)
    }

    /// Indica se o ETA é dinâmico (baseado em rota com tráfego ao vivo) ou
    /// apenas na velocidade GPS observada.
    ///
    /// Quando há rota, o ETA pode ser refinado pelo reroute periódico com
    /// `MKDirections` (tráfego ao vivo Apple Maps). Sem rota ou sem rede,
    /// o ETA vem apenas do `TravelEstimator` (EMA de velocidade GPS).
    public var isDynamicETA: Bool {
        // O ETA é considerado dinâmico quando há rota: nesse caso o
        // TripSessionController periodicamente re-planeja com tráfego ao vivo
        // e o estimador é reinicializado com o novo expectedTravelTime.
        // Sem rota, o ETA é puramente geodésico + EMA GPS (menos dinâmico).
        !isOnRoute == false
    }
}
