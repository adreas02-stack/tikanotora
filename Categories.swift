import Foundation

// ✏️ Οι κατηγορίες/υποκατηγορίες τώρα προστίθενται μέσα από την ίδια την εφαρμογή
// (καρτέλα «Κατηγορίες») — δεν χρειάζεται πια να αλλάζεις αυτό το αρχείο με το χέρι.

struct Category: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var name: String
    var icon: String          // όνομα SF Symbol
    var subcategories: [String]
}

/// Κρατάει τις κατηγορίες/υποκατηγορίες στο κινητό — ο χρήστης μπορεί
/// να προσθέτει/σβήνει κατηγορίες και υποκατηγορίες μέσα από την εφαρμογή.
@MainActor
final class CategoryStore: ObservableObject {
    static let shared = CategoryStore()

    @Published private(set) var categories: [Category] = []

    private let fileURL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("categories.json")

    private static let defaults: [Category] = [
        Category(name: "Δουλειά", icon: "briefcase.fill",
                 subcategories: ["Κλείσιμο ταμείου", "Δουλειά ταμείου", "Δουλειά σέρβις", "Τίποτα"]),
        Category(name: "Σπίτι", icon: "house.fill",
                 subcategories: ["Μαγείρεμα", "Ποιοτικός χρόνος με την κοπέλα", "Πλύσιμο πιάτων"])
    ]

    init() { load() }

    /// Όλα τα ζευγάρια (κατηγορία, υποκατηγορία).
    var pairs: [(category: String, sub: String)] {
        categories.flatMap { c in c.subcategories.map { (category: c.name, sub: $0) } }
    }

    func addCategory(name: String, icon: String = "tag.fill") {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        categories.append(Category(name: trimmed, icon: icon, subcategories: []))
        save()
    }

    func renameCategory(_ id: UUID, to newName: String) {
        guard let i = categories.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        categories[i].name = trimmed
        save()
    }

    func deleteCategory(_ id: UUID) {
        categories.removeAll { $0.id == id }
        save()
    }

    func addSubcategory(_ sub: String, to categoryID: UUID) {
        guard let i = categories.firstIndex(where: { $0.id == categoryID }) else { return }
        let trimmed = sub.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !categories[i].subcategories.contains(trimmed) else { return }
        categories[i].subcategories.append(trimmed)
        save()
    }

    func deleteSubcategory(_ sub: String, from categoryID: UUID) {
        guard let i = categories.firstIndex(where: { $0.id == categoryID }) else { return }
        categories[i].subcategories.removeAll { $0 == sub }
        save()
    }

    private func load() {
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([Category].self, from: data),
           !saved.isEmpty {
            categories = saved
        } else {
            categories = Self.defaults
            save()
        }
    }

    private func save() {
        try? JSONEncoder().encode(categories).write(to: fileURL, options: .atomic)
    }
}
