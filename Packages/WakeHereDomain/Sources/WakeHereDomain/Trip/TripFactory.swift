import Foundation

/// Tipo de regra escolhida na tela de configuração.
public enum RuleKind: String, Codable, CaseIterable, Sendable {
    case time
    case distance
}

/// **Factory** — cria `Trip` e regras a partir da configuração do usuário.
public final class TripFactory {
    public init() {}

    public func makeTrip(
        destination: Destination,
        rule: any WakeUpRule,
        route: Route?,
        now: Date
    ) -> Trip {
        Trip(
            destination: destination,
            rule: rule,
            route: route,
            phase: .planned,
            createdAt: now
        )
    }

    public func makeRule(
        kind: RuleKind,
        minutes: Int,
        kilometers: Double,
        safetyMarginMinutes: Int,
        distanceUnit: DistanceUnit = .metric
    ) -> any WakeUpRule {
        switch kind {
        case .time:
            return TimeBeforeArrivalRule(
                threshold: .minutes(Double(max(1, minutes))),
                safetyMargin: .minutes(Double(max(0, safetyMarginMinutes)))
            )
        case .distance:
            let meters: Meters
            if distanceUnit == .imperial {
                meters = Meters(max(0.1, kilometers) * 1609.344)
            } else {
                meters = Meters(max(0.1, kilometers) * 1000)
            }
            return DistanceBeforeArrivalRule(threshold: meters)
        }
    }
}
