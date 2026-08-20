import SwiftUI

/// Small pill showing a category's due-date urgency ("Due today", "Due in 3d", "Overdue 2d").
struct DueDateBadge: View {
    let status: BudgetCategory.DueStatus

    private var text: String {
        switch status {
        case .dueToday: return "Due Today"
        case .upcoming(let daysLeft): return "Due in \(daysLeft)d"
        case .overdue(let daysPast): return "Overdue \(daysPast)d"
        }
    }

    private var color: Color {
        switch status {
        case .overdue: return Theme.Colors.negative
        case .dueToday: return Theme.Colors.warning
        case .upcoming(let daysLeft): return daysLeft <= 3 ? Theme.Colors.warning : Theme.Colors.textSecondary
        }
    }

    var body: some View {
        Label(text, systemImage: "calendar")
            .labelStyle(.compact)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 3)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }
}

private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon.font(.caption2)
            configuration.title
        }
    }
}

private extension LabelStyle where Self == CompactLabelStyle {
    static var compact: CompactLabelStyle { CompactLabelStyle() }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        DueDateBadge(status: .upcoming(daysLeft: 8))
        DueDateBadge(status: .upcoming(daysLeft: 2))
        DueDateBadge(status: .dueToday)
        DueDateBadge(status: .overdue(daysPast: 3))
    }
    .padding()
    .background(Theme.Colors.canvas)
}
