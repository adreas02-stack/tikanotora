import Foundation

// ✏️ Εδώ αλλάζεις κατηγορίες και υποκατηγορίες.
// Πρόσθεσε / σβήσε γραμμές και ξανατρέξε την εφαρμογή από το Xcode.

struct Category: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String          // όνομα SF Symbol
    let subcategories: [String]
}

enum Catalog {
    static let all: [Category] = [
        Category(id: "work", name: "Δουλειά", icon: "briefcase.fill",
                 subcategories: ["Κλείσιμο ταμείου", "Δουλειά ταμείου", "Δουλειά σέρβις", "Τίποτα"]),
        Category(id: "home", name: "Σπίτι", icon: "house.fill",
                 subcategories: ["Μαγείρεμα", "Ποιοτικός χρόνος με την κοπέλα", "Πλύσιμο πιάτων"])
    ]

    /// Όλα τα ζευγάρια (κατηγορία, υποκατηγορία) — γίνονται κουμπιά στην ειδοποίηση.
    static var pairs: [(category: String, sub: String)] {
        all.flatMap { c in c.subcategories.map { (category: c.name, sub: $0) } }
    }
}
