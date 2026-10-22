import Foundation

/// Estimador de velocidade média suavizada (EMA) para prever o ETA.
///
/// Recebe amostras de velocidade do GPS e responde "quanto tempo leva para
/// cobrir X metros". Inclui piso de segurança para evitar ETA infinito quando
/// o veículo está parado.
public final class TravelEstimator {
    public private(set) var averageSpeed: MetersPerSecond
    private let blendingFactor: Double

    public init(initialSpeed: MetersPerSecond, blendingFactor: Double = 0.25) {
        self.averageSpeed = MetersPerSecond(max(initialSpeed.value, 0.1))
        self.blendingFactor = min(max(blendingFactor, 0.01), 1.0)
    }

    /// Velocidade média inicial derivada de uma rota planejada.
    public convenience init(route: Route) {
        let average = route.expectedDuration.value > 0
            ? route.totalDistance.value / route.expectedDuration.value
            : 10
        self.init(initialSpeed: MetersPerSecond(average))
    }

    /// Registra uma amostra de velocidade (ignora valores inválidos).
    public func registerSample(speed: MetersPerSecond) {
        guard speed.value.isFinite, speed.value >= 0 else { return }
        let alpha = blendingFactor
        let updated = averageSpeed.value * (1 - alpha) + speed.value * alpha
        averageSpeed = MetersPerSecond(updated)
    }

    /// Tempo estimado para cobrir `distance` com a velocidade média atual.
    public func estimatedTime(toCover distance: Meters) -> Seconds {
        let safeSpeed = max(averageSpeed.value, 0.5)
        return Seconds(distance.value / safeSpeed)
    }
}
