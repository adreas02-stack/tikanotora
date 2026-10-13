import Foundation
import SwiftUI
import UIKit

// ✏️ Οι κατηγορίες/υποκατηγορίες προστίθενται, μετονομάζονται, χρωματίζονται
// και αναδιατάσσονται μέσα από την καρτέλα «Κατηγορίες» της εφαρμογής.

struct Category: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var name: String
    var icon: String          // όνομα SF Symbol
    var colorHex: String = "007AFF"
    var subcategories: [String]

    var color: Color { Color(hex: colorHex) }
}

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: h).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// Hex χωρίς #, π.χ. "FF9500".
    func toHex() -> String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

/// Κρατάει τις κατηγορίες/υποκατηγορίες στο κινητό — ο χρήστης μπορεί να
/// προσθέτει/μετονομάζει/χρωματίζει/αναδιατάσσει/σβήνει μέσα από την εφαρμογή.
@MainActor
final class CategoryStore: ObservableObject {
    static let shared = CategoryStore()

    @Published private(set) var categories: [Category] = []

    private let fileURL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("categories.json")

    private static let defaults: [Category] = [
        Category(name: "Δουλειά", icon: "briefcase.fill", colorHex: "FF9500",
                 subcategories: ["Κλείσιμο ταμείου", "Δουλειά ταμείου", "Δουλειά σέρβις", "Τίποτα"]),
        Category(name: "Σπίτι", icon: "house.fill", colorHex: "34C759",
                 subcategories: ["Μαγείρεμα", "Ποιοτικός χρόνος με την κοπέλα", "Πλύσιμο πιάτων"])
    ]

    init() { load() }

    var pairs: [(category: String, sub: String)] {
        categories.flatMap { c in c.subcategories.map { (category: c.name, sub: $0) } }
    }

    func color(for name: String) -> Color {
        categories.first { $0.name == name }?.color ?? .gray
    }

    func addCategory(name: String, icon: String = "tag.fill", colorHex: String = "8E8E93") {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        categories.append(Category(name: trimmed, icon: icon, colorHex: colorHex, subcategories: []))
        save()
    }

    func updateCategory(_ id: UUID, name: String, colorHex: String) {
        guard let i = categories.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        categories[i].name = trimmed
        categories[i].colorHex = colorHex
        save()
    }

    func deleteCategory(_ id: UUID) {
        categories.removeAll { $0.id == id }
        save()
    }

    func moveCategory(fromOffsets: IndexSet, toOffset: Int) {
        categories.move(fromOffsets: fromOffsets, toOffset: toOffset)
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

    func moveSubcategory(in categoryID: UUID, fromOffsets: IndexSet, toOffset: Int) {
        guard let i = categories.firstIndex(where: { $0.id == categoryID }) else { return }
        categories[i].subcategories.move(fromOffsets: fromOffsets, toOffset: toOffset)
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
