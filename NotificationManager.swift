import Foundation
import UserNotifications

/// Προγραμματίζει τις ειδοποιήσεις κάθε 15 λεπτά.
/// Η ειδοποίηση δείχνει τις κατηγορίες σαν κουμπιά· πατώντας μια κατηγορία
/// ανοίγει η εφαρμογή σε μια γρήγορη λίστα με τις υποκατηγορίες της, ώστε
/// η καταγραφή να είναι 2 πατήματα χωρίς χαμό.
@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    static let categoryID = "TI_KANO_TORA"
    static let snoozeActionID = "snooze25"
    static let resumeID = "resume-after-snooze"

    func setup() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        rebuildCategories()
    }

    /// Ξαναφτιάχνει τα κουμπιά της ειδοποίησης (μία κατηγορία = ένα κουμπί + «Ύπνος 25′»).
    /// Κάλεσέ το ξανά κάθε φορά που προστίθεται/σβήνεται κατηγορία.
    func rebuildCategories() {
        var actions = CategoryStore.shared.categories.map { cat in
            UNNotificationAction(identifier: "cat.\(cat.id.uuidString)",
                                 title: cat.name,
                                 options: [.foreground])
        }
        actions.append(UNNotificationAction(identifier: Self.snoozeActionID,
                                            title: "😴 Ύπνος 25′",
                                            options: []))
        let category = UNNotificationCategory(identifier: Self.categoryID,
                                              actions: actions,
                                              intentIdentifiers: [],
                                              options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func requestAndSchedule() async {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
        if granted { schedule() }
    }

    private func makeContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Τι κάνεις τώρα;"
        content.body = "Πάτα παρατεταμένα για να διαλέξεις κατηγορία"
        content.sound = .default
        content.categoryIdentifier = Self.categoryID
        return content
    }

    /// 10:00, 10:15 … 23:00 — επαναλαμβανόμενες κάθε μέρα.
    func schedule() {
        if let until = Settings.snoozeUntil, until > Date() { return } // είμαστε σε λειτουργία ύπνου

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

    /// Σταματά τις ειδοποιήσεις για Χ λεπτά — λειτουργία ύπνου / power nap.
    func snooze(minutes: Double = 25) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        Settings.snoozeUntil = Date().addingTimeInterval(minutes * 60)

        let content = UNMutableNotificationContent()
        content.title = "Τέλος ύπνου 😴"
        content.body = "Ξαναρχίζουν οι ειδοποιήσεις — πάτα για καταγραφή."
        content.sound = .default
        content.categoryIdentifier = Self.categoryID
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: minutes * 60, repeats: false)
        center.add(UNNotificationRequest(identifier: Self.resumeID, content: content, trigger: trigger))
    }

    /// Αν έχει λήξει η λειτουργία ύπνου, ξαναφτιάχνει το κανονικό πρόγραμμα.
    func resumeIfSnoozeExpired() {
        if let until = Settings.snoozeUntil, Date() >= until {
            Settings.snoozeUntil = nil
            schedule()
        }
    }

    // MARK: - Delegate

    /// Πάτησες κουμπί στην ειδοποίηση (στο iPhone ή στο ρολόι).
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        resumeIfSnoozeExpired()
        let id = response.actionIdentifier

        if id == Self.snoozeActionID {
            snooze()
            return
        }
        if id == UNNotificationDefaultActionIdentifier {
            QuickLog.shared.start(categoryID: nil)
            return
        }
        if id.hasPrefix("cat."), let uuid = UUID(uuidString: String(id.dropFirst(4))) {
            QuickLog.shared.start(categoryID: uuid)
            return
        }
    }

    /// Δείξε την ειδοποίηση ακόμα κι αν η εφαρμογή είναι ανοιχτή.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        resumeIfSnoozeExpired()
        return [.banner, .list, .sound]
    }
}
