import SwiftUI

/// Top-of-Overview summary: real bank balance, money assigned into
/// categories, and what's left to spend freely.
struct BalanceSummaryCard: View {
    let availableDollars: Double?
    let assignedDollars: Double
    let safeToSpendDollars: Double?
    let isLoading: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            HStack(spacing: 0) {
                BalanceTile(title: "Available", amount: availableDollars, isLoading: isLoading)
                Rectangle()
                    .fill(Theme.Colors.divider)
                    .frame(width: 1, height: 34)
                BalanceTile(title: "Assigned", amount: assignedDollars, isLoading: isLoading)
            }

            Rectangle()
                .fill(Theme.Colors.divider)
                .frame(height: 1)

            SafeToSpendRow(amount: safeToSpendDollars, isLoading: isLoading)
        }
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(Theme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .strokeBorder(Theme.Colors.divider, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
        )
    }
}

private struct BalanceTile: View {
    let title: String
    let amount: Double?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)

            Group {
                if let amount {
                    Text(amount, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .contentTransition(.numericText())
                } else {
                    Text("– – –")
                        .redacted(reason: isLoading ? .placeholder : [])
                }
            }
            .font(.title3.weight(.semibold))
            .fontDesign(.rounded)
            .foregroundStyle(Theme.Colors.textPrimary)
            .animation(.smooth(duration: 0.5), value: amount)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.sm)
    }
}

private struct SafeToSpendRow: View {
    let amount: Double?
    let isLoading: Bool

    private var isNegative: Bool { (amount ?? 0) < 0 }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: isNegative ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(isNegative ? Theme.Colors.negative : Theme.Colors.accentBright)
                .symbolEffect(.bounce, value: amount)

            VStack(alignment: .leading, spacing: 2) {
                Text("Safe to Spend")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)

                if let amount {
                    Text(amount, format: .currency(code: "USD"))
                        .contentTransition(.numericText())
                        .font(.title2.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(isNegative ? Theme.Colors.negative : Theme.Colors.textPrimary)
                        .animation(.smooth(duration: 0.5), value: amount)
                } else {
                    Text("– – –")
                        .font(.title2.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .redacted(reason: isLoading ? .placeholder : [])
                }
            }

            Spacer()
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        BalanceSummaryCard(availableDollars: 2140.37, assignedDollars: 2450, safeToSpendDollars: 1850.87, isLoading: false)
        BalanceSummaryCard(availableDollars: 250, assignedDollars: 2450, safeToSpendDollars: -39.5, isLoading: false)
        BalanceSummaryCard(availableDollars: nil, assignedDollars: 2450, safeToSpendDollars: nil, isLoading: true)
    }
    .padding()
    .frame(maxHeight: .infinity)
    .background(Theme.Colors.canvas)
}
