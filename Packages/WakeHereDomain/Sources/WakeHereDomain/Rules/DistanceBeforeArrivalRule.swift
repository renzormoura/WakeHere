import Foundation

/// **Strategy** — despertar *Y metros/km* antes do ponto.
///
/// Dispara quando a distância restante (pela rota, ou geodésica se não houver
/// rota) fica menor ou igual ao limiar + folga de reação (velocidade × tempo).
public final class DistanceBeforeArrivalRule: WakeUpRule {
    public static let discriminator = "distanceBeforeArrival"

    /// Distância a partir da qual o alarme toca.
    public let threshold: Meters
    /// Tempo de reação humano: folga extra = velocidade × reactionTime.
    public let reactionTime: Seconds
    /// Quanto antes do gatilho a fase de "atenção" começa.
    public let warningLead: Meters

    public init(
        threshold: Meters,
        reactionTime: Seconds = Seconds(3),
        warningLead: Meters = Meters(500)
    ) {
        self.threshold = threshold
        self.reactionTime = reactionTime
        self.warningLead = warningLead
    }

    public var summary: String {
        if threshold.value >= 1000 {
            let km = (threshold.kilometers * 10).rounded() / 10
            return "Acordar a \(km) km do ponto"
        }
        return "Acordar a \(Int(threshold.value.rounded())) m do ponto"
    }

    /// Folga dinâmica: em alta velocidade o alarme toca mais cedo.
    private func reactionBuffer(for snapshot: TripSnapshot) -> Meters {
        Meters(max(0, snapshot.speed.value) * reactionTime.value)
    }

    public func evaluate(with snapshot: TripSnapshot) -> RuleVerdict {
        let triggerPoint = threshold + reactionBuffer(for: snapshot)
        return snapshot.remainingMeters <= triggerPoint ? .triggered : .pending
    }

    public func isApproaching(_ snapshot: TripSnapshot) -> Bool {
        let triggerPoint = threshold + reactionBuffer(for: snapshot) + warningLead
        return snapshot.remainingMeters <= triggerPoint
    }

    public func secondsUntilTriggering(snapshot: TripSnapshot) -> Seconds? {
        let triggerPoint = threshold + reactionBuffer(for: snapshot)
        let distanceToTrigger = snapshot.remainingMeters - triggerPoint
        guard distanceToTrigger.value > 0 else { return Seconds(0) }

        // Velocidade efetiva implícita no snapshot: restante / ETA.
        guard snapshot.estimatedRemainingSeconds.value > 0 else { return nil }
        let effectiveSpeed = snapshot.remainingMeters.value / snapshot.estimatedRemainingSeconds.value
        guard effectiveSpeed > 0.01 else { return nil }
        return Seconds(distanceToTrigger.value / effectiveSpeed)
    }

    public func liveETASummary(_ snapshot: TripSnapshot) -> String {
        let seconds = Int(snapshot.estimatedRemainingSeconds.value.rounded())
        if seconds >= 3600 {
            let h = seconds / 3600
            let m = (seconds % 3600) / 60
            if m == 0 {
                return "ETA: \(h) h"
            }
            return "ETA: \(h) h \(m) min"
        }
        if seconds >= 60 {
            let m = seconds / 60
            let s = seconds % 60
            if s == 0 {
                return "ETA: \(m) min"
            }
            return "ETA: \(m) min \(s) s"
        }
        return "ETA: \(seconds) s"
    }
}
