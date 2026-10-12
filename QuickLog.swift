import Foundation
import SwiftUI

/// Μοιράζεται ανάμεσα στην ειδοποίηση και στην εφαρμογή: όταν πατάς ένα
/// κουμπί κατηγορίας πάνω στην ειδοποίηση, ανοίγει η εφαρμογή σε αυτό το
/// «γρήγορο» σεντόνι ώστε να διαλέξεις αμέσως την υποκατηγορία — 2 πατήματα,
/// χωρίς χαμό.
@MainActor
final class QuickLog: ObservableObject {
    static let shared = QuickLog()

    @Published var isPresented = false
    @Published var pendingCategoryID: UUID?

    /// categoryID == nil -> ξεκίνα δείχνοντας όλες τις κατηγορίες.
    /// categoryID != nil -> πήγαινε κατευθείαν στις υποκατηγορίες αυτής.
    func start(categoryID: UUID?) {
        pendingCategoryID = categoryID
        isPresented = true
    }
}

struct QuickLogSheet: View {
    @EnvironmentObject var quickLog: QuickLog
    @EnvironmentObject var categoryStore: CategoryStore
    @EnvironmentObject var store: LogStore
    @Environment(\.dismiss) private var dismiss

    @State private var chosenCategory: Category?

    private var currentCategory: Category? {
        if let chosenCategory { return chosenCategory }
        if let id = quickLog.pendingCategoryID {
            return categoryStore.categories.first { $0.id == id }
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            Group {
                if let cat = currentCategory {
                    List {
                        if cat.subcategories.isEmpty {
                            Text("Δεν έχει υποκατηγορίες ακόμα.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(cat.subcategories, id: \.self) { sub in
                                Button {
                                    log(category: cat.name, sub: sub)
                                } label: {
                                    Text(sub)
                                        .font(.title3)
                                        .padding(.vertical, 8)
                                }
                            }
                        }
                    }
                    .navigationTitle(cat.name)
                    .toolbar {
                        if quickLog.pendingCategoryID == nil {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Πίσω") { chosenCategory = nil }
                            }
                        }
                    }
                } else {
                    List {
                        ForEach(categoryStore.categories) { cat in
                            Button {
                                chosenCategory = cat
                            } label: {
                                Label(cat.name, systemImage: cat.icon)
                                    .font(.title3)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .navigationTitle("Τι κάνεις τώρα;")
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if currentCategory == nil {
                        Button("Άκυρο") { dismiss() }
                    }
                }
            }
        }
    }

    private func log(category: String, sub: String) {
        Task {
            await store.add(category: category, subcategory: sub)
            chosenCategory = nil
            quickLog.pendingCategoryID = nil
            dismiss()
        }
    }
}
