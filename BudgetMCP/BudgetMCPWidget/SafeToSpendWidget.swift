import WidgetKit
import SwiftUI

struct SafeToSpendEntry: TimelineEntry {
    let date: Date
    let snapshot: BudgetSnapshot?
}

struct SafeToSpendProvider: TimelineProvider {
    func placeholder(in context: Context) -> SafeToSpendEntry {
        SafeToSpendEntry(
            date: Date(),
            snapshot: BudgetSnapshot(availableDollars: 2140.37, assignedDollars: 2450, safeToSpendDollars: 1850.87)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SafeToSpendEntry) -> Void) {
        completion(SafeToSpendEntry(date: Date(), snapshot: BudgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SafeToSpendEntry>) -> Void) {
        let entry = SafeToSpendEntry(date: Date(), snapshot: BudgetSnapshotStore.load())
        // The host app calls WidgetCenter.reloadAllTimelines() after every Overview
        // load, so the widget doesn't need its own polling schedule.
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct SafeToSpendWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SafeToSpendEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumLayout
            default:
                smallLayout
            }
        }
        .containerBackground(Theme.Colors.canvas, for: .widget)
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Safe to Spend", systemImage: "checkmark.seal.fill")
                .labelStyle(.iconOnly)
                .font(.caption)
                .foregroundStyle(Theme.Colors.accentBright)

            Spacer()

            Text("Safe to Spend")
                .font(.caption2)
                .foregroundStyle(Theme.Colors.textSecondary)

            amountText(entry.snapshot?.safeToSpendDollars)
                .font(.title2.bold())

            if let updatedAt = entry.snapshot?.updatedAt {
                Text(updatedAt, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
    }

    private var mediumLayout: some View {
        HStack(spacing: 0) {
            statColumn(title: "Available", amount: entry.snapshot?.availableDollars)
            Rectangle().fill(Theme.Colors.divider).frame(width: 1)
            statColumn(title: "Assigned", amount: entry.snapshot?.assignedDollars)
            Rectangle().fill(Theme.Colors.divider).frame(width: 1)
            statColumn(title: "Safe to Spend", amount: entry.snapshot?.safeToSpendDollars, emphasized: true)
        }
        .padding()
    }

    private func statColumn(title: String, amount: Double?, emphasized: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.Colors.textSecondary)
            amountText(amount)
                .font(emphasized ? .headline : .subheadline)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }

    private func amountText(_ amount: Double?) -> some View {
        Group {
            if let amount {
                Text(amount, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .foregroundStyle(amount < 0 ? Theme.Colors.negative : Theme.Colors.textPrimary)
            } else {
                Text("—")
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .fontDesign(.rounded)
    }
}

struct SafeToSpendWidget: Widget {
    let kind = "SafeToSpendWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SafeToSpendProvider()) { entry in
            SafeToSpendWidgetView(entry: entry)
        }
        .configurationDisplayName("Safe to Spend")
        .description("Your safe-to-spend balance, right on the Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    SafeToSpendWidget()
} timeline: {
    SafeToSpendEntry(date: .now, snapshot: BudgetSnapshot(availableDollars: 2140.37, assignedDollars: 2450, safeToSpendDollars: 1850.87))
}

#Preview(as: .systemMedium) {
    SafeToSpendWidget()
} timeline: {
    SafeToSpendEntry(date: .now, snapshot: BudgetSnapshot(availableDollars: 2140.37, assignedDollars: 2450, safeToSpendDollars: 1850.87))
}
