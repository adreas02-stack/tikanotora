import SwiftUI

/// Καρτέλα «Κατηγορίες» — προσθήκη/σβήσιμο κατηγοριών και υποκατηγοριών
/// μέσα από την ίδια την εφαρμογή.
struct CategoriesManagementView: View {
    @EnvironmentObject var categoryStore: CategoryStore
    @State private var newCategoryName = ""
    @FocusState private var newCategoryFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section("Νέα κατηγορία") {
                    HStack {
                        TextField("π.χ. Αθλητισμός", text: $newCategoryName)
                            .focused($newCategoryFocused)
                        Button("Προσθήκη") {
                            categoryStore.addCategory(name: newCategoryName)
                            newCategoryName = ""
                            newCategoryFocused = false
                            NotificationManager.shared.rebuildCategories()
                        }
                        .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section("Οι κατηγορίες σου") {
                    ForEach(categoryStore.categories) { cat in
                        NavigationLink {
                            SubcategoriesEditView(categoryID: cat.id)
                        } label: {
                            VStack(alignment: .leading) {
                                Label(cat.name, systemImage: cat.icon)
                                Text("\(cat.subcategories.count) υποκατηγορίες")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        offsets.forEach { i in
                            categoryStore.deleteCategory(categoryStore.categories[i].id)
                        }
                        NotificationManager.shared.rebuildCategories()
                    }
                }
            }
            .navigationTitle("Κατηγορίες")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Έτοιμο") { newCategoryFocused = false }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

/// Επεξεργασία των υποκατηγοριών μιας κατηγορίας.
struct SubcategoriesEditView: View {
    let categoryID: UUID
    @EnvironmentObject var categoryStore: CategoryStore
    @State private var newSub = ""
    @FocusState private var focused: Bool

    private var category: Category? {
        categoryStore.categories.first { $0.id == categoryID }
    }

    var body: some View {
        List {
            Section("Νέα υποκατηγορία") {
                HStack {
                    TextField("π.χ. Τρέξιμο", text: $newSub)
                        .focused($focused)
                    Button("Προσθήκη") {
                        categoryStore.addSubcategory(newSub, to: categoryID)
                        newSub = ""
                        focused = false
                        NotificationManager.shared.rebuildCategories()
                    }
                    .disabled(newSub.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            Section("Υπάρχουσες") {
                let subs = category?.subcategories ?? []
                if subs.isEmpty {
                    Text("Καμία υποκατηγορία ακόμα.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(subs, id: \.self) { sub in
                        Text(sub)
                    }
                    .onDelete { offsets in
                        offsets.forEach { i in
                            categoryStore.deleteSubcategory(subs[i], from: categoryID)
                        }
                        NotificationManager.shared.rebuildCategories()
                    }
                }
            }
        }
        .navigationTitle(category?.name ?? "")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Έτοιμο") { focused = false }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
