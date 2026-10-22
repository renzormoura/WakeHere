import Foundation

/// Porta (**DIP**) para o serviço de alarme do sistema.
/// Implementação concreta fica na camada de App (UserNotifications).
public protocol AlarmScheduling: AnyObject {
    /// Pede permissão para notificações (incluindo nível time-sensitive).
    func requestAuthorization() async -> Bool
    /// Agenda uma notificação para `fireDate` (toca com o app em segundo plano).
    func scheduleAlarm(at fireDate: Date, title: String, body: String)
    /// Cancela notificação pendente.
    func cancelScheduledAlarm()
    /// Dispara imediatamente (momento do gatilho).
    func announceNow(title: String, body: String)
}
