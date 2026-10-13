import SwiftUI

/// Δημιουργία ή επεξεργασία μιας καταγραφής — ώρα, κατηγορία, υποκατηγορία
/// (με δυνατότητα ελεύθερου κειμένου) και προαιρετικό σημείωμα.
/// Χρησιμοποιείται για: επεξεργασία καταγραφής, συμπλήρωση «κενού» 15λεπτου,
/// και χειροκίνητη καταγραφή για παλιότερη ώρα.
struct EditEntryView: View {
    @EnvironmentObject var store: LogStore
    @EnvironmentObject var categoryStore: CategoryStore
    @Environment(\.dismiss) private var dismiss

    /// nil == νέα χειροκίνητη καταγραφή.
    let existingID: UUID?

    @State private var date: Date
    @State private var categoryName: String
    @State private var subcategory: String
    @State private var note: String
    @State private var customSub = ""

    init(existingID: UUID? = nil,
         date: Date = .now,
         category: String = "",
         subcategory: String = "",
         note: String = "") {
        self.existingID = existingID
        _date = State(initialValue: date)
        _categoryName = State(initialValue: category)
        _subcategory = State(initialValue: subcategory)
        _note = State(initialValue: note)
    }

    private var selectedCategory: Category? {
        categoryStore.categories.first { $0.name == categoryName }
    }

    private var finalSubcategory: String {
        subcategory == "__custom__" ? customSub.trimmingCharacters(in: .whitespacesAndNewlines) : subcategory
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Πότε") {
                    DatePicker("Ώρα", selection: $date)
                        .datePickerStyle(.compact)
                }

                Section("Κατηγορία") {
                    Picker("Κατηγορία", selection: $categoryName) {
                        Text("— Καμία —").tag("")
                        ForEach(categoryStore.categories) { cat in
                            Label(cat.name, systemImage: cat.icon).tag(cat.name)
                        }
                    }
                    .onChange(of: categoryName) { _ in subcategory = "" }
                }

                if let cat = selectedCategory {
                    Section("Υποκατηγορία") {
                        Picker("Υποκατηγορία", selection: $subcategory) {
                            Text("—").tag("")
                            ForEach(cat.subcategories, id: \.self) { sub in
                                Text(sub).tag(sub)
                            }
                            Text("✏️ Κάτι άλλο...").tag("__custom__")
                        }
                        if subcategory == "__custom__" {
                            TextField("Γράψε τι έκανες", text: $customSub)
                        }
                    }
                }

                Section("Σημείωση (προαιρετικό)") {
                    TextField("π.χ. κάτι έξτρα που θέλεις να θυμάσαι", text: $note, axis: .vertical)
                }

                if existingID != nil {
                    Section {
                        Button("Διαγραφή καταγραφής", role: .destructive) {
                            if let id = existingID { store.delete(id) }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(existingID == nil ? "Νέα καταγραφή" : "Επεξεργασία")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Άκυρο") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Αποθήκευση") { saveAndDismiss() }
                        .disabled(categoryName.isEmpty || finalSubcategory.isEmpty)
                }
            }
        }
    }

    private func saveAndDismiss() {
        let sub = finalSubcategory
        let noteValue = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
        if let id = existingID {
            store.update(id, category: categoryName, subcategory: sub, date: date, note: noteValue)
        } else {
            Task { await store.add(category: categoryName, subcategory: sub, date: date, note: noteValue) }
        }
        dismiss()
    }
}
