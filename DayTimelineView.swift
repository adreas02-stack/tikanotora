import SwiftUI

/// Οπτικό χρονοδιάγραμμα μιας μέρας: μία γραμμή, ένα χρωματιστό κομμάτι ανά
/// προγραμματισμένο 15λεπτο. Τα κενά (χωρίς απάντηση) φαίνονται γκρι.
struct DayTimelineView: View {
    let day: Date
    let entries: [LogEntry]
    @EnvironmentObject var categoryStore: CategoryStore

    private var startHour: Int { Settings.startHour }
    private var endHour: Int { Settings.endHour }

    private var slots: [(time: Date, entry: LogEntry?)] {
        let cal = Calendar.current
        let base = cal.startOfDay(for: day)
        var result: [(Date, LogEntry?)] = []
        var minutes = startHour * 60
        let end = min(endHour * 60, 23 * 60 + 45)
        while minutes <= end {
            guard let slot = cal.date(byAdding: .minute, value: minutes, to: base) else { break }
            let match = entries.first { abs($0.date.timeIntervalSince(slot)) < 60 }
            result.append((slot, match))
            minutes += 15
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 2) {
                ForEach(slots.indices, id: \.self) { i in
                    let slot = slots[i]
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: slot.entry))
                        .frame(height: 28)
                }
            }
            HStack {
                Text("\(startHour):00")
                Spacer()
                Text("\(endHour):00")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func color(for entry: LogEntry?) -> Color {
        guard let entry, !entry.isGap else { return Color.secondary.opacity(0.15) }
        return categoryStore.color(for: entry.category)
    }
}
