import Foundation

extension ISO8601DateFormatter {
    /// Formatter matching how Postgres timestamptz values are serialized, used
    /// when passing dates as filter values in PostgREST queries.
    /// Safe to share: configured once, then only read (Foundation formatters are
    /// thread-safe for formatting).
    nonisolated(unsafe) static let supabase: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

extension Date {
    /// Short, human "time left" string for the feed, e.g. "leaves in 18 min".
    /// Past dates read as "closed".
    var timeLeftDescription: String {
        let interval = timeIntervalSinceNow
        guard interval > 0 else { return "closed" }

        let minutes = Int(interval / 60)
        if minutes < 1 { return "leaves in <1 min" }
        if minutes < 60 { return "leaves in \(minutes) min" }

        let hours = minutes / 60
        let remaining = minutes % 60
        if hours < 24 {
            return remaining == 0 ? "leaves in \(hours)h" : "leaves in \(hours)h \(remaining)m"
        }
        let days = hours / 24
        return "leaves in \(days)d"
    }
}

extension Decimal {
    /// Plain string for amounts (e.g. Venmo deep link / display): "12.5".
    var plainString: String {
        NSDecimalNumber(decimal: self).stringValue
    }

    /// Currency-formatted for display: "$12.50".
    var currencyString: String {
        let number = NSDecimalNumber(decimal: self)
        return Self.currencyFormatter.string(from: number) ?? "$\(number.stringValue)"
    }

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        return formatter
    }()
}
