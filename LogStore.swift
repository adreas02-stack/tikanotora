import Foundation

struct LogEntry: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var category: String
    var subcategory: String
}

/// Κρατάει όλες τις καταγραφές τοπικά στο κινητό (αρχείο JSON).
/// Χωρίς Google Sheet — όλα μένουν και αποθηκεύονται μόνο εδώ.
@MainActor
final class LogStore: ObservableObject {
    static let shared = LogStore()

    @Published private(set) var entries: [LogEntry] = []

    private let fileURL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("log.json")

    init() { load() }

    func add(category: String, subcategory: String, date: Date = .now) async {
        entries.append(LogEntry(date: date, category: category, subcategory: subcategory))
        save()
    }

    func delete(_ id: UUID) {
        entries.removeAll { $0.id == id }
        save()
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
