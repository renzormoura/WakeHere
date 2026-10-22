import Foundation

/// Fases possíveis de uma viagem (**State pattern**).
public enum TripPhase: String, Codable, CaseIterable, Sendable {
    /// Criada, ainda não iniciada.
    case planned
    /// Acompanhando normalmente.
    case tracking
    /// Perto do ponto de despertar (aviso visual).
    case warning
    /// Alarme tocando.
    case ringing
    /// Alarme adiado pelo usuário.
    case snoozed
    /// Chegou ao destino.
    case arrived
    /// Cancelada pelo usuário.
    case cancelled

    /// Se a fase mantém o monitoramento ativo.
    public var isActive: Bool {
        switch self {
        case .tracking, .warning, .ringing, .snoozed:
            return true
        case .planned, .arrived, .cancelled:
            return false
        }
    }

    /// Se a viagem já terminou (estado final).
    public var isTerminal: Bool {
        self == .arrived || self == .cancelled
    }
}
