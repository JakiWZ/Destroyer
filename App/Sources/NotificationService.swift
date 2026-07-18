import Foundation
import UserNotifications

/// Notifiche di sistema (es. minaccia rilevata dal monitoraggio in tempo reale).
enum NotificationService {

    /// Richiede il permesso una volta (silenzioso se già concesso/negato).
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func notifyThreat(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
