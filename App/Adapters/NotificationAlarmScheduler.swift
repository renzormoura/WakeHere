import Foundation
import UserNotifications
import AcordeAquiDomain

/// **Adapter** — notificações locais (camada 1 da tripla trava).
///
/// Agenda a notificação *time-sensitive* calculada pelo `AlarmTimingPlanner`:
/// toca mesmo com o iPhone bloqueado e o app em segundo plano.
final class NotificationAlarmScheduler: NSObject, AlarmScheduling {
    private let center = UNUserNotificationCenter.current()
    private let pendingIdentifier = "com.acordeaqui.alarm.pending"
    private let immediateIdentifier = "com.acordeaqui.alarm.immediate"
    private let snoozeIdentifier = "com.acordeaqui.alarm.snooze"

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

    func scheduleAlarm(at fireDate: Date, title: String, body: String) {
        let interval = fireDate.timeIntervalSinceNow
        guard interval > 1 else { return }

        let request = UNNotificationRequest(
            identifier: pendingIdentifier,
            content: makeContent(title: title, body: body),
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
        // Substitui o agendamento anterior (o ETA é recalculado continuamente).
        center.removePendingNotificationRequests(withIdentifiers: [pendingIdentifier])
        center.add(request)
    }

    func cancelScheduledAlarm() {
        center.removePendingNotificationRequests(withIdentifiers: [
            pendingIdentifier,
            snoozeIdentifier
        ])
    }

    func announceNow(title: String, body: String) {
        let request = UNNotificationRequest(
            identifier: immediateIdentifier,
            content: makeContent(title: title, body: body),
            trigger: nil // entrega imediata
        )
        center.add(request)
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
