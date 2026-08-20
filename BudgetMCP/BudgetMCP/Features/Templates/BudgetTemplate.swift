import Foundation

/// A canned set of categories to quick-start a new budget.
struct BudgetTemplate: Identifiable {
    struct CategorySeed {
        let name: String
        let allocatedDollars: Double
        let period: BudgetPeriod
        let groupName: String?
        var rollover: Bool = false
    }

    let id = UUID()
    let name: String
    let subtitle: String
    let systemImage: String
    let categories: [CategorySeed]

    static let all: [BudgetTemplate] = [
        BudgetTemplate(
            name: "Starter Budget",
            subtitle: "The essentials most people track first",
            systemImage: "sparkles",
            categories: [
                CategorySeed(name: "Groceries", allocatedDollars: 400, period: .monthly, groupName: "Everyday"),
                CategorySeed(name: "Dining Out", allocatedDollars: 100, period: .monthly, groupName: "Everyday"),
                CategorySeed(name: "Transportation", allocatedDollars: 150, period: .monthly, groupName: "Everyday"),
                CategorySeed(name: "Fun Money", allocatedDollars: 75, period: .monthly, groupName: "Everyday")
            ]
        ),
        BudgetTemplate(
            name: "Bill Tracker",
            subtitle: "Recurring bills with due dates, ready to assign",
            systemImage: "calendar.badge.clock",
            categories: [
                CategorySeed(name: "Rent", allocatedDollars: 1500, period: .monthly, groupName: "Bills"),
                CategorySeed(name: "Utilities", allocatedDollars: 150, period: .monthly, groupName: "Bills"),
                CategorySeed(name: "Subscriptions", allocatedDollars: 40, period: .monthly, groupName: "Bills"),
                CategorySeed(name: "Phone", allocatedDollars: 60, period: .monthly, groupName: "Bills")
            ]
        ),
        BudgetTemplate(
            name: "Savings Goals",
            subtitle: "Set-and-forget buckets that build up over time",
            systemImage: "banknote",
            categories: [
                CategorySeed(name: "Emergency Fund", allocatedDollars: 200, period: .monthly, groupName: "Savings", rollover: true),
                CategorySeed(name: "Vacation", allocatedDollars: 100, period: .monthly, groupName: "Savings", rollover: true)
            ]
        )
    ]
}
