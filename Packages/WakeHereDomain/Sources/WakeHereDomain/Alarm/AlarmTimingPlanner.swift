import Foundation

/// Agenda o alarme **antes** do disparo da regra: uma notificação local
/// calculada para tocar no momento em que a regra dispararia (com um
/// pré-alerta), funcionando mesmo com o app em segundo plano.
public final class AlarmTimingPlanner {
    private let clock: Clock
    /// Quanto antes do gatilho real a notificação deve tocar.
    public var preAlert: Seconds

    public init(clock: Clock, preAlert: Seconds = Seconds(10)) {
        self.clock = clock
        self.preAlert = preAlert
    }

    /// Calcula quando agendar a notificação para esta medição.
    ///
    /// O horário do alarme não é um tempo de chegada pré-fixado: ele é derivado
    /// do **ETA dinâmico** do snapshot (que, quando há rota, é refinado pelo
    /// reroute periódico com tráfego ao vivo — ADR-0006). A cada update de GPS
    /// e a cada reroute, o ``TripSessionController`` reagenda a notificação com
    /// o ETA mais recente. O usuário nunca define um "horário fixo de chegada"
    /// — o app calcula quando avisar com base no que está acontecendo na rua agora.
    ///
    /// `nil` = nada a agendar (indeterminável ou disparo iminente/já passado).
    public func schedule(
        snapshot: TripSnapshot,
        rule: any WakeUpRule
    ) -> AlarmSchedule? {
        guard let until = rule.secondsUntilTriggering(snapshot: snapshot) else {
            return nil
        }
        let secondsUntilNotification = until.value - preAlert.value
        guard secondsUntilNotification > 1 else { return nil }

        let fireDate = snapshot.timestamp.addingTimeInterval(secondsUntilNotification)
        let now = clock.now
        guard fireDate.timeIntervalSince(now) > 1 else { return nil }

        return AlarmSchedule(
            fireDate: fireDate,
            secondsFromNow: Seconds(fireDate.timeIntervalSince(now))
        )
    }

    /// Texto da notificação pré-alarme, baseado no ETA dinâmico para o destino.
    /// Mostra ao usuário (na notificação) que o aviso é calculado em tempo real.
    public func preAlertBody(
        destinationName: String,
        snapshot: TripSnapshot,
        rule: any WakeUpRule
    ) -> String {
        let eta = rule.liveETASummary(snapshot)
        return "Estimamos \(eta) para \(destinationName). Prepare-se!"
    }
}

/// Quando e daqui a quanto tempo o alarme programado toca.
public struct AlarmSchedule: Equatable, Sendable {
    public let fireDate: Date
    public let secondsFromNow: Seconds

    public init(fireDate: Date, secondsFromNow: Seconds) {
        self.fireDate = fireDate
        self.secondsFromNow = secondsFromNow
    }
}
