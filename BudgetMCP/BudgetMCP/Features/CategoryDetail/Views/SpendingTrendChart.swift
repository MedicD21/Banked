import SwiftUI
import Charts

/// Daily net activity for a category — expenses below the axis, credits above.
struct SpendingTrendChart: View {
    let entries: [LedgerEntry]

    private struct DailyTotal: Identifiable {
        let day: Date
        let amount: Double
        var id: Date { day }
    }

    private var dailyTotals: [DailyTotal] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry -> Date in
            let date = AppDateFormatting.date(fromISOTimestamp: entry.createdAt) ?? Date()
            return calendar.startOfDay(for: date)
        }
        return grouped.map { DailyTotal(day: $0.key, amount: $0.value.reduce(0) { $0 + $1.amountDollars }) }
            .sorted { $0.day < $1.day }
    }

    var body: some View {
        Chart(dailyTotals) { entry in
            BarMark(
                x: .value("Day", entry.day, unit: .day),
                y: .value("Amount", entry.amount)
            )
            .foregroundStyle(entry.amount < 0 ? Theme.Colors.negative : Theme.Colors.positive)
            .cornerRadius(3)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: max(1, dailyTotals.count / 4))) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(Theme.Colors.divider)
                AxisValueLabel()
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .frame(height: 140)
        .padding(.vertical, Theme.Spacing.sm)
    }
}

#Preview {
    SpendingTrendChart(entries: [
        LedgerEntry(id: "1", entryType: "allocation", amountDollars: 500, memo: nil, plaidTransactionId: nil, createdAt: "2026-08-01T00:00:00Z"),
        LedgerEntry(id: "2", entryType: "expense", amountDollars: -42.10, memo: nil, plaidTransactionId: nil, createdAt: "2026-08-05T00:00:00Z"),
        LedgerEntry(id: "3", entryType: "expense", amountDollars: -18.35, memo: nil, plaidTransactionId: nil, createdAt: "2026-08-09T00:00:00Z"),
        LedgerEntry(id: "4", entryType: "expense", amountDollars: -64.20, memo: nil, plaidTransactionId: nil, createdAt: "2026-08-14T00:00:00Z")
    ])
    .padding()
    .background(Theme.Colors.canvas)
}
