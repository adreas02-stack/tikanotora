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
                        Label(cat.name, systemImage: cat.icon)
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
        }
        .navigationTitle(category.name)
    }
}

// MARK: - Σημερινά στατιστικά

struct TodayView: View {
    @EnvironmentObject var store: LogStore

    private var today: [LogEntry] {
        store.entries
            .filter { Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
    }

    /// Κάθε καταγραφή = 15 λεπτά.
    private var totals: [(name: String, minutes: Int)] {
        Dictionary(grouping: today) { "\($0.category) · \($0.subcategory)" }
            .map { (name: $0.key, minutes: $0.value.count * 15) }
            .sorted { $0.minutes > $1.minutes }
    }

    private func format(_ m: Int) -> String {
        m >= 60 ? "\(m / 60)ω \(m % 60)'" : "\(m)'"
    }

    var body: some View {
        NavigationStack {
            List {
                if today.isEmpty {
                    Text("Καμία καταγραφή σήμερα ακόμα.")
                        .foregroundStyle(.secondary)
                } else {
                    Section("Σύνολα") {
                        ForEach(totals, id: \.name) { row in
                            HStack {
                                Text(row.name)
                                Spacer()
                                Text(format(row.minutes)).bold()
                            }
                        }
                    }
                    Section("Ιστορικό") {
                        ForEach(today) { e in
                            HStack {
                                Text(e.date, format: .dateTime.hour().minute())
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                Text("\(e.category) · \(e.subcategory)")
                                Spacer()
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { today[$0].id }.forEach(store.delete)
                        }
                    }
                }
            }
            .navigationTitle("Σήμερα")
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
