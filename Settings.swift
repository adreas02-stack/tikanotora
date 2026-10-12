import Foundation

/// Ρυθμίσεις αποθηκευμένες στο κινητό (UserDefaults).
enum Settings {
    private static let d = UserDefaults.standard

    static var enabled: Bool {
        get { d.object(forKey: "enabled") as? Bool ?? true }
        set { d.set(newValue, forKey: "enabled") }
    }
    static var startHour: Int {
        get { d.object(forKey: "startHour") as? Int ?? 10 }
        set { d.set(newValue, forKey: "startHour") }
    }
    static var endHour: Int {
        get { d.object(forKey: "endHour") as? Int ?? 23 }
        set { d.set(newValue, forKey: "endHour") }
    }

    /// Μέχρι πότε είμαστε σε «λειτουργία ύπνου» (power nap) — nil όταν δεν είναι ενεργή.
    static var snoozeUntil: Date? {
        get { d.object(forKey: "snoozeUntil") as? Date }
        set { d.set(newValue, forKey: "snoozeUntil") }
    }
}
