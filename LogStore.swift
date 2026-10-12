import Foundation

struct LogEntry: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var category: String
    var subcategory: String
    var synced = false
}

/// Κρατάει όλες τις καταγραφές στο κινητό και τις στέλνει στο Sheet.
/// Αν δεν υπάρχει ίντερνετ, μένουν στην ουρά και στέλνονται αργότερα.
@MainActor
final class LogStore: ObservableObject {
    static let shared = LogStore()

    @Published private(set) var entries: [LogEntry] = []
    private var syncing = false

    private let fileURL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("log.json")

    init() { load() }

    var unsyncedCount: Int { entries.filter { !$0.synced }.count }

    func add(category: String, subcategory: String, date: Date = .now) async {
        entries.append(LogEntry(date: date, category: category, subcategory: subcategory))
        save()
        await syncPending()
    }

    func delete(_ id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    func syncPending() async {
        guard !syncing else { return }
        syncing = true
        defer { syncing = false }

        for i in entries.indices where !entries[i].synced {
            if await FormUploader.send(entries[i]) {
                entries[i].synced = true
                save()
            }
        }
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
