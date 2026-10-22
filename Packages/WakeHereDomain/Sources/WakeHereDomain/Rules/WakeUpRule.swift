import Foundation

/// Resultado da avaliação de uma regra de despertar.
public enum RuleVerdict: Equatable, Sendable {
    case pending
    case triggered
}

/// **Strategy** — contrato para as regras de despertar.
///
/// `TimeBeforeArrivalRule` e `DistanceBeforeArrivalRule` são estratégias
/// intercambiáveis; o `TripMonitor` não conhece nenhuma delas concretamente.
public protocol WakeUpRule: AnyObject, Codable, Sendable {
    /// Discriminador usado pela persistência polimórfica (ver `WakeUpRuleCodec`).
    static var discriminator: String { get }

    /// Resumo legível para a interface (PT-BR).
    var summary: String { get }

    /// Avalia se o alarme deve tocar agora.
    func evaluate(with snapshot: TripSnapshot) -> RuleVerdict

    /// True quando a regra está próxima de disparar (fase de "atenção").
    func isApproaching(_ snapshot: TripSnapshot) -> Bool

    /// Estimativa de segundos até a regra disparar (`nil` = indeterminável).
    ///
    /// O valor é calculado a partir do ETA dinâmico do snapshot, não de um
    /// tempo de chegada pré-fixado: isso é o que torna o alarme **dinâmico**,
    /// respondendo a tráfego, desvios e imprevistos a cada update de GPS e a
    /// cada reroute periódico com tráfego ao vivo (ADR-0006).
    func secondsUntilTriggering(snapshot: TripSnapshot) -> Seconds? }

public extension WakeUpRule {
    func isApproaching(_ snapshot: TripSnapshot) -> Bool {
        false
    }

    func secondsUntilTriggering(snapshot: TripSnapshot) -> Seconds? {
        nil
    }

    /// Texto legível do ETA dinâmico no momento da avaliação.
    /// Usado pela UI para mostrar ao usuário que o alarme é baseado no ETA
    /// em tempo real (como um Maps/Waze), não em um horário pré-definido.
    func liveETASummary(_ snapshot: TripSnapshot) -> String {
        "ETA indisponível"
    }
}
