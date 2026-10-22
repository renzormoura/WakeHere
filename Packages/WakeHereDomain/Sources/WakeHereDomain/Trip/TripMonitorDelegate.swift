import Foundation

/// **Observer** — o que o `TripMonitor` notifica aos observadores.
///
/// Todos os métodos têm implementação vazia padrão: o observador implementa
/// apenas o que precisa.
public protocol TripMonitorDelegate: AnyObject {
    /// Nova medição processada (UI atualiza contadores).
    func tripMonitor(_ monitor: TripMonitor, didUpdateSnapshot snapshot: TripSnapshot)
    /// Mudança de fase (State).
    func tripMonitor(_ monitor: TripMonitor, didChangePhase phase: TripPhase)
    /// Usuário saiu da rota: é preciso re-planejar.
    func tripMonitorDidRequestReroute(_ monitor: TripMonitor)
    /// Hora de acordar!
    func tripMonitorDidTriggerAlarm(_ monitor: TripMonitor)
}

public extension TripMonitorDelegate {
    func tripMonitor(_ monitor: TripMonitor, didUpdateSnapshot snapshot: TripSnapshot) {}
    func tripMonitor(_ monitor: TripMonitor, didChangePhase phase: TripPhase) {}
    func tripMonitorDidRequestReroute(_ monitor: TripMonitor) {}
    func tripMonitorDidTriggerAlarm(_ monitor: TripMonitor) {}
}
