import SwiftUI

/// Καρτέλα «Στατιστικά» — γράφημα αράχνη (πού πάει ο χρόνος) + εξαγωγή σε PDF.
struct StatsView: View {
    @EnvironmentObject var store: LogStore
    @EnvironmentObject var categoryStore: CategoryStore
    @State private var pdfURL: URL?

    private var lastWeekEntries: [LogEntry] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return store.entries.filter { $0.date >= weekAgo }
    }

    private var radarPoints: [RadarDataPoint] {
        categoryStore.categories.map { cat in
            let minutes = lastWeekEntries.filter { $0.category == cat.name }.count * 15
            return RadarDataPoint(label: cat.name, value: Double(minutes))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Πού πάει ο χρόνος μου (τελευταίες 7 μέρες)") {
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
