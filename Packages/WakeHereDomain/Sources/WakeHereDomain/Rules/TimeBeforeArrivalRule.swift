import Foundation

/// **Strategy** — despertar *X tempo* antes de chegar.
///
/// Dispara quando o ETA restante fica menor ou igual ao limiar (+ margem).
public final class TimeBeforeArrivalRule: WakeUpRule {
    public static let discriminator = "timeBeforeArrival"

    /// Tempo restante a partir do qual o alarme toca.
    public let threshold: Seconds
    /// Folga extra adicionada ao limiar (ex.: imprevistos de trânsito).
    public let safetyMargin: Seconds
    /// Quanto antes do gatilho a fase de "atenção" começa.
    public let warningLead: Seconds

    public init(
        threshold: Seconds,
        safetyMargin: Seconds = .zero,
        warningLead: Seconds = Seconds(120)
    ) {
        self.threshold = threshold
        self.safetyMargin = safetyMargin
        self.warningLead = warningLead
    }

    public var summary: String {
        let minutes = Int((threshold.value / 60).rounded())
        if minutes >= 60 {
            let hoursPart = minutes / 60
            let rest = minutes % 60
            if rest == 0 {
                return "Acordar \(hoursPart) h antes de chegar"
            }
            return "Acordar \(hoursPart) h \(rest) min antes de chegar"
        }
        return "Acordar \(minutes) min antes de chegar"
    }

    public func evaluate(with snapshot: TripSnapshot) -> RuleVerdict {
        let triggerPoint = threshold.value + safetyMargin.value
        return snapshot.estimatedRemainingSeconds.value <= triggerPoint ? .triggered : .pending
    }

    public func isApproaching(_ snapshot: TripSnapshot) -> Bool {
        let triggerPoint = threshold.value + safetyMargin.value
        return snapshot.estimatedRemainingSeconds.value <= triggerPoint + warningLead.value
    }

    public func secondsUntilTriggering(snapshot: TripSnapshot) -> Seconds? {
        let triggerPoint = threshold.value + safetyMargin.value
        return Seconds(max(0, snapshot.estimatedRemainingSeconds.value - triggerPoint))
    }

    public func liveETASummary(_ snapshot: TripSnapshot) -> String {
        let minutes = Int((snapshot.estimatedRemainingSeconds.value / 60).rounded())
        if minutes >= 60 {
            let hoursPart = minutes / 60
            let rest = minutes % 60
            if rest == 0 {
                return "ETA: \(hoursPart) h"
            }
            return "ETA: \(hoursPart) h \(rest) min"
        }
        return "ETA: \(minutes) min"
    }
}
