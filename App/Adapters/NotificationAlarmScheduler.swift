import Foundation
import UserNotifications
import WakeHereDomain

/// **Adapter** — notificações locais (camada 1 da tripla trava).
///
/// Agenda a notificação *time-sensitive* calculada pelo `AlarmTimingPlanner`:
/// toca mesmo com o iPhone bloqueado e o app em segundo plano.
final class NotificationAlarmScheduler: NSObject, AlarmScheduling {
    private let center = UNUserNotificationCenter.current()
    private let pendingIdentifier = "com.wakehere.alarm.pending"
    private let immediateIdentifier = "com.wakehere.alarm.immediate"
    private let snoozeIdentifier = "com.wakehere.alarm.snooze"

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(
                options: [.alert, .sound, .badge, .timeSensitive]
            )
        } catch {
            return false
        }
    }

    /// Quantas notificações extras seguem a primeira, e a cada quantos segundos.
    /// Um som de notificação toca ~30 s: a cadeia insiste por cerca de 6 minutos
    /// caso o app esteja morto e o usuário não acorde com a primeira.
    private let repeatCount = 12
    private let repeatInterval: TimeInterval = 30

    func scheduleAlarm(at fireDate: Date, title: String, body: String) {
        let interval = fireDate.timeIntervalSinceNow
        guard interval > 1 else { return }

        // Substitui o agendamento anterior (o ETA é recalculado continuamente).
        center.removePendingNotificationRequests(withIdentifiers: identifiers(for: pendingIdentifier))
        addChain(
            baseIdentifier: pendingIdentifier,
            firstDelay: interval,
            title: title,
            body: body
        )
    }

    func cancelScheduledAlarm() {
        let all = [pendingIdentifier, snoozeIdentifier, immediateIdentifier]
            .flatMap(identifiers(for:))
        center.removePendingNotificationRequests(withIdentifiers: all)
        center.removeDeliveredNotifications(withIdentifiers: all)
    }

    func announceNow(title: String, body: String) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers(for: immediateIdentifier))
        // Entrega imediata + cadeia de repetições.
        center.add(UNNotificationRequest(
            identifier: immediateIdentifier,
            content: makeContent(title: title, body: body),
            trigger: nil
        ))
        for step in 1...repeatCount {
            center.add(UNNotificationRequest(
                identifier: "\(immediateIdentifier).\(step)",
                content: makeContent(title: title, body: body),
                trigger: UNTimeIntervalNotificationTrigger(
                    timeInterval: repeatInterval * Double(step),
                    repeats: false
                )
            ))
        }
    }

    private func identifiers(for base: String) -> [String] {
        [base] + (1...repeatCount).map { "\(base).\($0)" }
    }

    private func addChain(baseIdentifier: String, firstDelay: TimeInterval, title: String, body: String) {
        for step in 0...repeatCount {
            let identifier = step == 0 ? baseIdentifier : "\(baseIdentifier).\(step)"
            center.add(UNNotificationRequest(
                identifier: identifier,
                content: makeContent(title: title, body: body),
                trigger: UNTimeIntervalNotificationTrigger(
                    timeInterval: firstDelay + repeatInterval * Double(step),
                    repeats: false
                )
            ))
        }
    }

    private func makeContent(title: String, body: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.interruptionLevel = .timeSensitive
        if Bundle.main.url(forResource: "AlarmTone", withExtension: "wav") != nil {
            content.sound = UNNotificationSound(named: UNNotificationSoundName("AlarmTone.wav"))
        } else {
            content.sound = UNNotificationSound.default
        }
        return content
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationAlarmScheduler: UNUserNotificationCenterDelegate {
    /// Mostra a notificação mesmo com o app aberto.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
