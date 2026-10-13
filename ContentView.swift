import SwiftUI

struct ContentView: View {
    @EnvironmentObject var quickLog: QuickLog

    var body: some View {
        TabView {
            LogNowView()
                .tabItem { Label("Τώρα", systemImage: "hand.tap.fill") }
            TodayView()
                .tabItem { Label("Σήμερα", systemImage: "chart.bar.fill") }
            StatsView()
                .tabItem { Label("Στατιστικά", systemImage: "chart.line.uptrend.xyaxis") }
            CategoriesManagementView()
                .tabItem { Label("Κατηγορίες", systemImage: "tag.fill") }
            SettingsView()
                .tabItem { Label("Ρυθμίσεις", systemImage: "gearshape.fill") }
        }
        .sheet(isPresented: $quickLog.isPresented) {
            QuickLogSheet()
                .onDisappear { quickLog.pendingCategoryID = nil }
        }
    }
}

// MARK: - Καταγραφή με το χέρι (κατηγορία -> υποκατηγορία)

struct LogNowView: View {
    @EnvironmentObject var store: LogStore
    @EnvironmentObject var categoryStore: CategoryStore
    @State private var lastLogged: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(categoryStore.categories) { cat in
                    NavigationLink {
                        SubcategoryPickerView(category: cat) { sub in
                            Task {
                                await store.add(category: cat.name, subcategory: sub)
                                lastLogged = "\(cat.name) · \(sub)"
                            }
                        }
                    } label: {
                        Label {
                            Text(cat.name)
                        } icon: {
                            Image(systemName: cat.icon)
                                .foregroundStyle(cat.color)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Τι κάνω τώρα")
            .alert("Καταγράφηκε ✅",
                   isPresented: Binding(get: { lastLogged != nil },
                                        set: { if !$0 { lastLogged = nil } })) {
                Button("OK") {}
            } message: {
                Text(lastLogged ?? "")
            }
        }
    }
}

/// Λίστα με τις υποκατηγορίες μιας κατηγορίας — εμφανίζεται όταν πατάς την κατηγορία.
struct SubcategoryPickerView: View {
    let category: Category
    let onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var customText = ""
    @State private var showCustom = false

    var body: some View {
        List {
            if category.subcategories.isEmpty {
                Text("Δεν έχει υποκατηγορίες ακόμα. Πρόσθεσε στην καρτέλα «Κατηγορίες».")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(category.subcategories, id: \.self) { sub in
                    Button {
                        onPick(sub)
                        dismiss()
                    } label: {
                        Text(sub)
                            .font(.title3)
                            .padding(.vertical, 6)
                    }
                }
            }

            Section {
                if showCustom {
                    HStack {
                        TextField("Τι έκανες;", text: $customText)
                        Button("OK") {
                            let t = customText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !t.isEmpty else { return }
                            onPick(t)
                            dismiss()
                        }
                    }
                } else {
                    Button("✏️ Κάτι άλλο...") { showCustom = true }
                }
            }
        }
        .navigationTitle(category.name)
    }
}

// MARK: - Σήμερα (πλοήγηση σε ημέρες, χρονοδιάγραμμα, πρόοδος, επεξεργάσιμο ιστορικό)

struct TodayView: View {
    @EnvironmentObject var store: LogStore
    @EnvironmentObject var categoryStore: CategoryStore
    @State private var selectedDay = Date()
    @State private var editingID: UUID?
    @State private var showingNewEntry = false

    private var dayEntries: [LogEntry] {
        store.entries(on: selectedDay)
    }

    private var answeredEntries: [LogEntry] { dayEntries.filter { !$0.isGap } }
    private var gapCount: Int { dayEntries.filter(\.isGap).count }

    private var totals: [(name: String, minutes: Int)] {
        Dictionary(grouping: answeredEntries) { "\($0.category) · \($0.subcategory)" }
            .map { (name: $0.key, minutes: $0.value.count * 15) }
            .sorted { $0.minutes > $1.minutes }
    }

    private var progress: Double {
        let total = dayEntries.count
        guard total > 0 else { return 0 }
        return Double(answeredEntries.count) / Double(total)
    }

    private func format(_ m: Int) -> String {
        m >= 60 ? "\(m / 60)ω \(m % 60)'" : "\(m)'"
    }

    private var dayLabel: String {
        if Calendar.current.isDateInToday(selectedDay) { return "Σήμερα" }
        if Calendar.current.isDateInYesterday(selectedDay) { return "Χθες" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "el_GR")
        f.dateFormat = "EEEE d MMMM"
        return f.string(from: selectedDay)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Button {
                            selectedDay = Calendar.current.date(byAdding: .day, value: -1, to: selectedDay) ?? selectedDay
                        } label: { Image(systemName: "chevron.left") }

                        Spacer()
                        VStack {
                            Text(dayLabel).font(.headline)
                            DatePicker("", selection: $selectedDay, displayedComponents: .date)
                                .labelsHidden()
                        }
                        Spacer()

                        Button {
                            selectedDay = Calendar.current.date(byAdding: .day, value: 1, to: selectedDay) ?? selectedDay
                        } label: { Image(systemName: "chevron.right") }
                        .disabled(Calendar.current.isDateInToday(selectedDay))
                    }

                    if !dayEntries.isEmpty {
                        DayTimelineView(day: selectedDay, entries: dayEntries)
                        ProgressView(value: progress) {
                            Text(gapCount > 0
                                 ? "\(answeredEntries.count)/\(dayEntries.count) απαντημένα — \(gapCount) κενά"
                                 : "Όλα απαντημένα ✅")
                                .font(.caption)
                        }
                    }
                }

                if dayEntries.isEmpty {
                    Text("Καμία καταγραφή αυτή τη μέρα.")
                        .foregroundStyle(.secondary)
                } else {
                    if !totals.isEmpty {
                        Section("Σύνολα") {
                            ForEach(totals, id: \.name) { row in
                                HStack {
                                    Text(row.name)
                                    Spacer()
                                    Text(format(row.minutes)).bold()
                                }
                            }
                        }
                    }
                    Section("Ιστορικό") {
                        ForEach(dayEntries) { e in
                            Button {
                                editingID = e.id
                            } label: {
                                HStack {
                                    Text(e.date, format: .dateTime.hour().minute())
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                    if e.isGap {
                                        Text("— κενό, πάτα για να συμπληρώσεις")
                                            .foregroundStyle(.secondary)
                                            .italic()
                                    } else {
                                        Circle()
                                            .fill(categoryStore.color(for: e.category))
                                            .frame(width: 8, height: 8)
                                        VStack(alignment: .leading) {
                                            Text("\(e.category) · \(e.subcategory)")
                                            if let note = e.note, !note.isEmpty {
                                                Text(note)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            offsets.map { dayEntries[$0].id }.forEach(store.delete)
                        }
                    }
                }
            }
            .navigationTitle("Σήμερα")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: Binding(get: {
                editingID.flatMap { id in dayEntries.first { $0.id == id } }
            }, set: { _ in editingID = nil })) { entry in
                EditEntryView(existingID: entry.id,
                             date: entry.date,
                             category: entry.category,
                             subcategory: entry.subcategory,
                             note: entry.note ?? "")
            }
            .sheet(isPresented: $showingNewEntry) {
                EditEntryView(date: selectedDay)
            }
        }
    }
}

// MARK: - Ρυθμίσεις

struct SettingsView: View {
    @AppStorage("enabled") private var enabled = true
    @AppStorage("startHour") private var startHour = 10
    @AppStorage("endHour") private var endHour = 23

    var body: some View {
        NavigationStack {
            Form {
                Section("Ειδοποιήσεις κάθε 15 λεπτά") {
                    Toggle("Ενεργές", isOn: $enabled)
                    Stepper("Από: \(startHour):00", value: $startHour, in: 0...23)
                    Stepper("Έως: \(endHour):00", value: $endHour, in: 0...23)
                    Button("Δοκιμαστική ειδοποίηση (σε 5'')") {
                        NotificationManager.shared.sendTest()
                    }
                }

                Section {
                    Button("😴 Σταμάτα τις ειδοποιήσεις για 25′ (power nap)") {
                        NotificationManager.shared.snooze()
                    }
                } header: {
                    Text("Λειτουργία ύπνου")
                } footer: {
                    Text("Σταματάει τις ειδοποιήσεις για 25 λεπτά και μετά ξαναρχίζουν κανονικά.")
                }
            }
            .navigationTitle("Ρυθμίσεις")
            .onChange(of: enabled) { _ in NotificationManager.shared.schedule() }
            .onChange(of: startHour) { _ in NotificationManager.shared.schedule() }
            .onChange(of: endHour) { _ in NotificationManager.shared.schedule() }
        }
    }
}
