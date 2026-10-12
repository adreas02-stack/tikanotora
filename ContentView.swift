import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            LogNowView()
                .tabItem { Label("Τώρα", systemImage: "hand.tap.fill") }
            TodayView()
                .tabItem { Label("Σήμερα", systemImage: "chart.bar.fill") }
            SettingsView()
                .tabItem { Label("Ρυθμίσεις", systemImage: "gearshape.fill") }
        }
    }
}

// MARK: - Καταγραφή με το χέρι

struct LogNowView: View {
    @EnvironmentObject var store: LogStore
    @State private var lastLogged: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(Catalog.all) { cat in
                    Section {
                        ForEach(cat.subcategories, id: \.self) { sub in
                            Button(sub) {
                                Task {
                                    await store.add(category: cat.name, subcategory: sub)
                                    lastLogged = "\(cat.name) · \(sub)"
                                }
                            }
                        }
                    } header: {
                        Label(cat.name, systemImage: cat.icon)
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
                                if !e.synced {
                                    Image(systemName: "icloud.slash")
                                        .foregroundStyle(.orange)
                                }
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
    @EnvironmentObject var store: LogStore

    @AppStorage("enabled") private var enabled = true
    @AppStorage("startHour") private var startHour = 10
    @AppStorage("endHour") private var endHour = 23

    @State private var prefilledLink = ""
    @State private var formStatus = Settings.isFormConfigured ? "Συνδεδεμένο ✅" : "Δεν έχει συνδεθεί"

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
                    TextField("Επικόλλησε τον προσυμπληρωμένο σύνδεσμο", text: $prefilledLink, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Σύνδεση") {
                        formStatus = Settings.configure(fromPrefilled: prefilledLink)
                            ? "Συνδεδεμένο ✅"
                            : "Λάθος σύνδεσμος ❌ (χρειάζονται 3 ερωτήσεις)"
                        Task { await store.syncPending() }
                    }
                    Text(formStatus).foregroundStyle(.secondary)
                } header: {
                    Text("Google Sheet")
                }

                Section("Συγχρονισμός") {
                    Text("Σε αναμονή: \(store.unsyncedCount)")
                    Button("Στείλε τώρα") {
                        Task { await store.syncPending() }
                    }
                }
            }
            .navigationTitle("Ρυθμίσεις")
            .onChange(of: enabled) { NotificationManager.shared.schedule() }
            .onChange(of: startHour) { NotificationManager.shared.schedule() }
            .onChange(of: endHour) { NotificationManager.shared.schedule() }
        }
    }
}
