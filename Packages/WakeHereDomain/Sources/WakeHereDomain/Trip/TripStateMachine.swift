import Foundation

/// **State pattern** — máquina de estados da viagem.
///
/// Valida transições ilegais (ex.: `planned → ringing` é proibido) e mantém o
/// `TripPhase` consistente. Transições inválidas são ignoradas (retornam `false`).
public final class TripStateMachine {
    public private(set) var phase: TripPhase

    public init(initialPhase: TripPhase = .planned) {
        self.phase = initialPhase
    }

    /// Tabela de transições permitidas.
    public static let allowedTransitions: [TripPhase: Set<TripPhase>] = [
        .planned: [.tracking, .cancelled],
        .tracking: [.warning, .ringing, .arrived, .cancelled],
        .warning: [.tracking, .ringing, .arrived, .cancelled],
        .ringing: [.tracking, .snoozed, .arrived, .cancelled],
        .snoozed: [.tracking, .warning, .ringing, .arrived, .cancelled],
        .arrived: [],
        .cancelled: []
    ]

    public func canTransition(to next: TripPhase) -> Bool {
        guard next != phase else { return false }
        return TripStateMachine.allowedTransitions[phase, default: []].contains(next)
    }

    @discardableResult
    public func transition(to next: TripPhase) -> Bool {
        guard canTransition(to: next) else { return false }
        phase = next
        return true
    }
}
