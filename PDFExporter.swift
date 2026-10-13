import Foundation
import UIKit

/// Φτιάχνει PDF με όλες τις καταγραφές (χωρίς τα κενά), ομαδοποιημένες ανά
/// μέρα, μαζί με τυχόν σημειώσεις. Χρησιμοποιεί τη γραμματοσειρά του
/// συστήματος, που δείχνει κανονικά τους ελληνικούς χαρακτήρες.
enum PDFExporter {
    static func export(_ entries: [LogEntry]) -> URL? {
        let pageWidth: CGFloat = 595.2   // A4 σε points
        let pageHeight: CGFloat = 841.8
        let margin: CGFloat = 36
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let titleFont = UIFont.boldSystemFont(ofSize: 18)
        let headerFont = UIFont.boldSystemFont(ofSize: 13)
        let bodyFont = UIFont.systemFont(ofSize: 11)
        let noteFont = UIFont.italicSystemFont(ofSize: 10)

        let sorted = entries.filter { !$0.isGap }.sorted { $0.date < $1.date }
        let groups = Dictionary(grouping: sorted) { Calendar.current.startOfDay(for: $0.date) }
        let days = groups.keys.sorted()

        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "el_GR")
        dayFormatter.dateFormat = "EEEE d MMMM yyyy"

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "el_GR")
        timeFormatter.dateFormat = "HH:mm"

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TiKanoTora-\(Int(Date().timeIntervalSince1970)).pdf")

        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()
                var y: CGFloat = margin
                ("Τι κάνω τώρα — Αναφορά" as NSString)
                    .draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: titleFont])
                y += 32

                if days.isEmpty {
                    ("Δεν υπάρχουν ακόμα καταγραφές." as NSString)
                        .draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: bodyFont])
                }

                for day in days {
                    if y > pageHeight - margin - 60 {
                        context.beginPage()
                        y = margin
                    }
                    (dayFormatter.string(from: day) as NSString)
                        .draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: headerFont])
                    y += 20

                    for e in groups[day] ?? [] {
                        if y > pageHeight - margin - 30 {
                            context.beginPage()
                            y = margin
                        }
                        let line = "\(timeFormatter.string(from: e.date))   \(e.category) · \(e.subcategory)"
                        (line as NSString)
                            .draw(at: CGPoint(x: margin + 8, y: y), withAttributes: [.font: bodyFont])
                        y += 16

                        if let note = e.note, !note.isEmpty {
                            ("— \(note)" as NSString)
                                .draw(at: CGPoint(x: margin + 20, y: y), withAttributes: [.font: noteFont])
                            y += 14
                        }
                    }
                    y += 10
                }
            }
            return url
        } catch {
            return nil
        }
    }
}
