import SwiftUI

/// Καρτέλα «Κατηγορίες» — προσθήκη, μετονομασία, χρώμα, αναδιάταξη και
/// σβήσιμο κατηγοριών/υποκατηγοριών μέσα από την ίδια την εφαρμογή.
struct CategoriesManagementView: View {
    @EnvironmentObject var categoryStore: CategoryStore
    @State private var newCategoryName = ""
    @FocusState private var newCategoryFocused: Bool
    @State private var editingCategory: Category?

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

                Section("Οι κατηγορίες σου (σύρε για σειρά, σύρε αριστερά για επεξεργασία)") {
                    ForEach(categoryStore.categories) { cat in
                        NavigationLink {
                            SubcategoriesEditView(categoryID: cat.id)
                        } label: {
                            HStack {
                                Circle().fill(cat.color).frame(width: 12, height: 12)
                                VStack(alignment: .leading) {
                                    Label(cat.name, systemImage: cat.icon)
                                    Text("\(cat.subcategories.count) υποκατηγορίες")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                editingCategory = cat
                            } label: {
                                Label("Επεξεργασία", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                    .onDelete { offsets in
                        offsets.forEach { i in
                            categoryStore.deleteCategory(categoryStore.categories[i].id)
                        }
                        NotificationManager.shared.rebuildCategories()
                    }
                    .onMove { from, to in
                        categoryStore.moveCategory(fromOffsets: from, toOffset: to)
                    }
                }
            }
            .navigationTitle("Κατηγορίες")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Έτοιμο") { newCategoryFocused = false }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .sheet(item: $editingCategory) { cat in
                RenameCategorySheet(categoryID: cat.id)
            }
        }
    }
}

/// Αλλαγή ονόματος και χρώματος μιας κατηγορίας.
struct RenameCategorySheet: View {
    let categoryID: UUID
    @EnvironmentObject var categoryStore: CategoryStore
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var color: Color = .blue

    var body: some View {
        NavigationStack {
            Form {
                TextField("Όνομα", text: $name)
                ColorPicker("Χρώμα", selection: $color, supportsOpacity: false)
            }
            .navigationTitle("Επεξεργασία κατηγορίας")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Άκυρο") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Αποθήκευση") {
                        categoryStore.updateCategory(categoryID, name: name, colorHex: color.toHex())
                        NotificationManager.shared.rebuildCategories()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let cat = categoryStore.categories.first(where: { $0.id == categoryID }) {
                    name = cat.name
                    color = cat.color
                }
            }
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
            Section("Υπάρχουσες (σύρε για σειρά)") {
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
                    .onMove { from, to in
                        categoryStore.moveSubcategory(in: categoryID, fromOffsets: from, toOffset: to)
                    }
                }
            }
        }
        .navigationTitle(category?.name ?? "")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Έτοιμο") { focused = false }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
