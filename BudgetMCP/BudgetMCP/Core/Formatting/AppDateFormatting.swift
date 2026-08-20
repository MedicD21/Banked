import Foundation
import SwiftUI

/// Shared parsing/formatting for the two date shapes the API sends: full
/// ISO 8601 timestamps (ledger entries, sync status) and plain `yyyy-MM-dd`
/// dates (category due dates).
enum AppDateFormatting {
    // Read-only after creation, so safe to share across isolation domains despite
    // the underlying formatters not being Sendable.
    nonisolated(unsafe) private static let isoWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) private static let isoStandard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    nonisolated(unsafe) private static let plainDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    static func date(fromISOTimestamp string: String) -> Date? {
        isoWithFractionalSeconds.date(from: string) ?? isoStandard.date(from: string)
    }

    static func date(fromPlainDate string: String) -> Date? {
        plainDate.date(from: string)
    }

    static func plainDateString(from date: Date) -> String {
        plainDate.string(from: date)
    }
}

extension Text {
    /// Renders an ISO 8601 timestamp string using the given `Date.FormatStyle`,
    /// falling back to the raw string if it can't be parsed.
    init(isoTimestamp: String, format: Date.FormatStyle) {
        if let date = AppDateFormatting.date(fromISOTimestamp: isoTimestamp) {
            self.init(date, format: format)
        } else {
            self.init(isoTimestamp)
        }
    }
}
