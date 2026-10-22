import Foundation
import WakeHereDomain

/// Formatação PT-BR compartilhada pela interface.
enum Formatting {
    /// "2 h 05 min" / "12 min" / "45 s"
    static func duration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

        if hours > 0 {
            return minutes > 0 ? "\(hours) h \(minutes) min" : "\(hours) h"
        }
        if minutes > 0 {
            return "\(minutes) min"
        }
        return "\(secs) s"
    }

    /// Distância no sistema preferido pelo usuário.
    static func distance(_ meters: Double, unit: DistanceUnit) -> String {
        if unit == .imperial {
            let miles = meters / 1609.344
            if miles >= 0.1 {
                return String(format: "%.1f mi", miles)
            }
            return "\(Int(meters.rounded())) m"
        }
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(Int(meters.rounded())) m"
    }

    /// Hora do dia ("14:35").
    static func clockTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Data + hora ("2 de out. de 2026 às 14:35").
    static func dateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Rótulo da fase (PT-BR).
    static func phaseLabel(_ phase: TripPhase) -> String {
        switch phase {
        case .planned:
            return "Planejada"
        case .tracking:
            return "A caminho"
        case .warning:
            return "Quase lá"
        case .ringing:
            return "Alarme"
        case .snoozed:
            return "Adiada"
        case .arrived:
            return "Chegou"
        case .cancelled:
            return "Cancelada"
        }
    }

    static func phaseSymbol(_ phase: TripPhase) -> String {
        switch phase {
        case .planned:
            return "calendar"
        case .tracking:
            return "figure.walk"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .ringing:
            return "bell.and.waves.left.and.right.fill"
        case .snoozed:
            return "clock.badge.exclamationmark"
        case .arrived:
            return "checkmark.circle.fill"
        case .cancelled:
            return "xmark.circle"
        }
    }
}
