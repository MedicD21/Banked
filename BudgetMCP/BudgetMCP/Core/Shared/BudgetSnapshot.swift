import Foundation

/// Small cache of the Overview's headline numbers, written by the app after
/// every load and read by the Home Screen widget extension (which has no
/// network access of its own). Lives in the shared App Group container.
struct BudgetSnapshot: Codable, Sendable {
    let availableDollars: Double?
    let assignedDollars: Double
    let safeToSpendDollars: Double?
    let updatedAt: Date

    init(availableDollars: Double?, assignedDollars: Double, safeToSpendDollars: Double?, updatedAt: Date = Date()) {
        self.availableDollars = availableDollars
        self.assignedDollars = assignedDollars
        self.safeToSpendDollars = safeToSpendDollars
        self.updatedAt = updatedAt
    }
}

enum BudgetSnapshotStore {
    static let appGroupID = "group.com.dustinschaaf.BudgetMCP"
    private static let key = "latestBudgetSnapshot"

    static func save(_ snapshot: BudgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> BudgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(BudgetSnapshot.self, from: data)
    }
}
