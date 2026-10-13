import Foundation

struct LogEntry: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var category: String       // "" σημαίνει κενό (δεν απάντησες στην ειδοποίηση)
    var subcategory: String
    var note: String? = nil

    var isGap: Bool { category.isEmpty }
}

/// Κρατάει όλες τις καταγραφές τοπικά στο κινητό (αρχείο JSON).
/// Όταν περνάει μια προγραμματισμένη ώρα χωρίς απάντηση, μπαίνει «κενή»
/// καταγραφή (backfillGaps) που μπορείς να συμπληρώσεις αργότερα.
@MainActor
final class LogStore: ObservableObject {
    static let shared = LogStore()

    @Published private(set) var entries: [LogEntry] = []

    private let fileURL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("log.json")
    private let lastBackfillKey = "lastBackfillDate"

    init() { load() }

    @discardableResult
    func add(category: String, subcategory: String, date: Date = .now, note: String? = nil) async -> LogEntry {
        let entry = LogEntry(date: date, category: category, subcategory: subcategory, note: note)
        entries.append(entry)
        save()
        return entry
    }

    func update(_ id: UUID, category: String, subcategory: String, date: Date, note: String?) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].category = category
        entries[i].subcategory = subcategory
        entries[i].date = date
        entries[i].note = note
        save()
    }

    func delete(_ id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    func entries(on day: Date) -> [LogEntry] {
        entries.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
            .sorted { $0.date < $1.date }
    }

    func entries(from start: Date, to end: Date) -> [LogEntry] {
        entries.filter { $0.date >= start && $0.date <= end }
    }

    /// Γεμίζει με «κενές» καταγραφές κάθε προγραμματισμένο 15λεπτο που πέρασε
    /// χωρίς απάντηση, από την τελευταία φορά που άνοιξε η εφαρμογή μέχρι τώρα.
    func backfillGaps() {
        let now = Date()
        let cal = Calendar.current
        let last = UserDefaults.standard.object(forKey: lastBackfillKey) as? Date ?? now

        guard Settings.enabled, last < now else {
            UserDefaults.standard.set(now, forKey: lastBackfillKey)
            return
        }

        var day = cal.startOfDay(for: last)
        let today = cal.startOfDay(for: now)
        var newGaps: [LogEntry] = []
        var guardCount = 0

        while day <= today, guardCount < 400 {
            guardCount += 1
            var minutes = Settings.startHour * 60
            let end = min(Settings.endHour * 60, 23 * 60 + 45)
            while minutes <= end {
                if let slot = cal.date(byAdding: .minute, value: minutes, to: day),
                   slot > last, slot <= now,
                   !entries.contains(where: { abs($0.date.timeIntervalSince(slot)) < 60 }) {
                    newGaps.append(LogEntry(date: slot, category: "", subcategory: ""))
                }
                minutes += 15
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        if !newGaps.isEmpty {
            entries.append(contentsOf: newGaps)
            save()
        }
        UserDefaults.standard.set(now, forKey: lastBackfillKey)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode([LogEntry].self, from: data) else { return }
        entries = saved
    }

    private func save() {
        try? JSONEncoder().encode(entries).write(to: fileURL, options: .atomic)
    }
}
