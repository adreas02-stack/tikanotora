import SwiftUI
import Charts

/// Καρτέλα «Στατιστικά» — επιλογή περιόδου, γράφημα αράχνη, σύγκριση
/// εβδομάδων, μέσος όρος ανά ημέρα εβδομάδας, εξαγωγή σε PDF.
struct StatsView: View {
    @EnvironmentObject var store: LogStore
    @EnvironmentObject var categoryStore: CategoryStore
    @State private var pdfURL: URL?
    @State private var period: Period = .days7

    enum Period: String, CaseIterable, Identifiable {
        case days7 = "7 μέρες"
        case days30 = "30 μέρες"
        case days90 = "90 μέρες"
        var id: String { rawValue }
        var days: Int {
            switch self {
            case .days7: return 7
            case .days30: return 30
            case .days90: return 90
            }
        }
    }

    private var periodEntries: [LogEntry] {
        let start = Calendar.current.date(byAdding: .day, value: -period.days, to: Date()) ?? Date()
        return store.entries.filter { $0.date >= start && !$0.isGap }
    }

    private var radarPoints: [RadarDataPoint] {
        categoryStore.categories.map { cat in
            let minutes = periodEntries.filter { $0.category == cat.name }.count * 15
            return RadarDataPoint(label: cat.name, value: Double(minutes))
        }
    }

    private struct WeekTotal: Identifiable {
        let id = UUID()
        let week: String
        let category: String
        let minutes: Int
    }

    private var weekComparison: [WeekTotal] {
        let cal = Calendar.current
        let now = Date()
        guard let twoWeeksAgo = cal.date(byAdding: .day, value: -14, to: now),
              let oneWeekAgo = cal.date(byAdding: .day, value: -7, to: now) else { return [] }

        let lastWeek = store.entries.filter { !$0.isGap && $0.date >= twoWeeksAgo && $0.date < oneWeekAgo }
        let thisWeek = store.entries.filter { !$0.isGap && $0.date >= oneWeekAgo && $0.date <= now }

        var rows: [WeekTotal] = []
        for cat in categoryStore.categories {
            let lastMin = lastWeek.filter { $0.category == cat.name }.count * 15
            let thisMin = thisWeek.filter { $0.category == cat.name }.count * 15
            rows.append(WeekTotal(week: "Προηγούμενη", category: cat.name, minutes: lastMin))
            rows.append(WeekTotal(week: "Αυτή", category: cat.name, minutes: thisMin))
        }
        return rows
    }

    private struct WeekdayTotal: Identifiable {
        let id = UUID()
        let weekday: String
        let minutes: Int
    }

    private var weekdayAverages: [WeekdayTotal] {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "el_GR")
        formatter.dateFormat = "EEE"

        let grouped = Dictionary(grouping: periodEntries) { cal.component(.weekday, from: $0.date) }
        let daysSeen = Dictionary(grouping: periodEntries) { cal.startOfDay(for: $0.date) }.keys
        var countPerWeekday: [Int: Int] = [:]
        for d in daysSeen { countPerWeekday[cal.component(.weekday, from: d), default: 0] += 1 }

        return (1...7).compactMap { wd in
            guard let sample = grouped[wd]?.first else { return nil }
            let totalMinutes = (grouped[wd]?.count ?? 0) * 15
            let days = max(countPerWeekday[wd] ?? 1, 1)
            return WeekdayTotal(weekday: formatter.string(from: sample.date), minutes: totalMinutes / days)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Περίοδος", selection: $period) {
                        ForEach(Period.allCases) { p in Text(p.rawValue).tag(p) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Πού πάει ο χρόνος μου (\(period.rawValue))") {
                    if radarPoints.count >= 3 {
                        RadarChartView(points: radarPoints,
                                      maxValue: radarPoints.map(\.value).max() ?? 1)
                            .frame(height: 260)
                            .padding(.vertical, 8)
                    } else {
                        Text("Χρειάζονται τουλάχιστον 3 κατηγορίες για να φανεί το γράφημα.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Αυτή η εβδομάδα vs προηγούμενη") {
                    if weekComparison.contains(where: { $0.minutes > 0 }) {
                        Chart(weekComparison) { row in
                            BarMark(
                                x: .value("Κατηγορία", row.category),
                                y: .value("Λεπτά", row.minutes)
                            )
                            .foregroundStyle(by: .value("Εβδομάδα", row.week))
                            .position(by: .value("Εβδομάδα", row.week))
                        }
                        .frame(height: 200)
                    } else {
                        Text("Δεν υπάρχουν ακόμα αρκετές καταγραφές για σύγκριση.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Μέσος όρος ανά ημέρα της εβδομάδας") {
                    if weekdayAverages.isEmpty {
                        Text("Δεν υπάρχουν ακόμα καταγραφές.")
                            .foregroundStyle(.secondary)
                    } else {
                        Chart(weekdayAverages) { row in
                            BarMark(
                                x: .value("Ημέρα", row.weekday),
                                y: .value("Λεπτά", row.minutes)
                            )
                        }
                        .frame(height: 180)
                    }
                }

                Section {
                    Button {
                        pdfURL = PDFExporter.export(store.entries)
                    } label: {
                        Label("Δημιούργησε PDF με όλες τις καταγραφές", systemImage: "doc.richtext")
                    }
                    if let pdfURL {
                        ShareLink(item: pdfURL) {
                            Label("Μοιράσου / Αποθήκευσε το PDF", systemImage: "square.and.arrow.up")
                        }
                    }
                } header: {
                    Text("Αναφορά")
                } footer: {
                    Text("Το PDF βγαίνει με ελληνικούς χαρακτήρες και μπορείς να το στείλεις ή να το αποθηκεύσεις.")
                }
            }
            .navigationTitle("Στατιστικά")
        }
    }
}
