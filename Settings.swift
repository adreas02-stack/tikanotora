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

    static var formURL: String {
        get { d.string(forKey: "formURL") ?? "" }
        set { d.set(newValue, forKey: "formURL") }
    }
    static var entryCategory: String {
        get { d.string(forKey: "entryCategory") ?? "" }
        set { d.set(newValue, forKey: "entryCategory") }
    }
    static var entrySub: String {
        get { d.string(forKey: "entrySub") ?? "" }
        set { d.set(newValue, forKey: "entrySub") }
    }
    static var entryTime: String {
        get { d.string(forKey: "entryTime") ?? "" }
        set { d.set(newValue, forKey: "entryTime") }
    }

    static var isFormConfigured: Bool {
        !formURL.isEmpty && !entryCategory.isEmpty && !entrySub.isEmpty && !entryTime.isEmpty
    }

    /// Παίρνει τον «προσυμπληρωμένο σύνδεσμο» του Google Form και βγάζει μόνη της
    /// τη διεύθυνση αποστολής και τα entry IDs (με τη σειρά: Κατηγορία, Υποκατηγορία, Ώρα).
    static func configure(fromPrefilled link: String) -> Bool {
        let clean = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var comps = URLComponents(string: clean),
              comps.path.hasSuffix("/viewform") else { return false }
        let ids = (comps.queryItems ?? []).map(\.name).filter { $0.hasPrefix("entry.") }
        guard ids.count >= 3 else { return false }

        comps.path = String(comps.path.dropLast("viewform".count)) + "formResponse"
        comps.query = nil
        guard let url = comps.url else { return false }

        formURL = url.absoluteString
        entryCategory = ids[0]
        entrySub = ids[1]
        entryTime = ids[2]
        return true
    }
}
