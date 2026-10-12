import Foundation
import UserNotifications

/// Προγραμματίζει τις ειδοποιήσεις κάθε 15 λεπτά και πιάνει τα κουμπιά τους.
/// Τα κουμπιά δουλεύουν και από το Apple Watch, χωρίς να ανοίξει η εφαρμογή.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    static let categoryID = "TI_KANO_TORA"

    /// Καλείται στην εκκίνηση: ορίζει τα κουμπιά της ειδοποίησης.
    func setup() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let actions = Catalog.pairs.enumerated().map {
            UNNotificationAction(identifier: "log.\($0.offset)",
                                 title: "\($0.element.category) · \($0.element.sub)",
                                 options: [])
        }
        let category = UNNotificationCategory(identifier: Self.categoryID,
                                              actions: actions,
                                              intentIdentifiers: [],
                                              options: [])
        center.setNotificationCategories([category])
    }

    func requestAndSchedule() async {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
        if granted { schedule() }
    }

    private func makeContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Τι κάνεις τώρα;"
        content.body = "Πάτα παρατεταμένα για να διαλέξεις"
        content.sound = .default
        content.categoryIdentifier = Self.categoryID
        return content
    }

    /// 10:00, 10:15 … 23:00 — επαναλαμβανόμενες κάθε μέρα.
    /// (Το iOS επιτρέπει έως 64 προγραμματισμένες, εμείς χρειαζόμαστε 53.)
    func schedule() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard Settings.enabled else { return }

        var minutes = Settings.startHour * 60
        let end = min(Settings.endHour * 60, 23 * 60 + 45)
        var count = 0

        while minutes <= end && count < 64 {
            var dc = DateComponents()
            dc.hour = minutes / 60
            dc.minute = minutes % 60
            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
            center.add(UNNotificationRequest(identifier: "slot.\(minutes)",
                                             content: makeContent(),
                                             trigger: trigger))
            minutes += 15
            count += 1
        }
    }

    /// Δοκιμαστική ειδοποίηση σε 5 δευτερόλεπτα.
    func sendTest() {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "test.\(UUID())", content: makeContent(), trigger: trigger))
    }

    // MARK: - Delegate

    /// Πάτησες κουμπί στην ειδοποίηση (στο iPhone ή στο ρολόι).
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let id = response.actionIdentifier
        guard id.hasPrefix("log."),
              let index = Int(id.dropFirst(4)),
              Catalog.pairs.indices.contains(index) else { return }

        let pair = Catalog.pairs[index]
        await LogStore.shared.add(category: pair.category,
                                  subcategory: pair.sub,
                                  date: response.notification.date)
    }

    /// Δείξε την ειδοποίηση ακόμα κι αν η εφαρμογή είναι ανοιχτή.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
