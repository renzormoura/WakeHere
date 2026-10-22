import Foundation

/// Configuração do monitor da viagem.
public struct MonitorConfiguration: Codable, Hashable, Sendable {
    /// Desvio máximo (m) para considerar o usuário "sobre a rota".
    public var deviationTolerance: Meters
    /// Intervalo mínimo entre pedidos de re-planejamento (reroute).
    public var rerouteMinInterval: Seconds
    /// Raio (m) a partir do qual considera "chegou" e toca o alarme.
    public var arrivalRadius: Meters
    /// Velocidade de cruzeiro assumida quando não há rota.
    public var defaultCruisingSpeed: MetersPerSecond

    public init(
        deviationTolerance: Meters = Meters(150),
        rerouteMinInterval: Seconds = Seconds(120),
        arrivalRadius: Meters = Meters(40),
        defaultCruisingSpeed: MetersPerSecond = MetersPerSecond(11)
    ) {
        self.deviationTolerance = deviationTolerance
        self.rerouteMinInterval = rerouteMinInterval
        self.arrivalRadius = arrivalRadius
        self.defaultCruisingSpeed = defaultCruisingSpeed
    }

    public static let `default` = MonitorConfiguration()
}
