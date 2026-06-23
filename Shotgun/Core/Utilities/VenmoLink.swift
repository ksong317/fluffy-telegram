import Foundation

/// Builds Venmo handoff links. The app never moves money — it only opens Venmo
/// pre-filled, then records a "marked as paid" flag.
enum VenmoLink {
    /// Deep link that opens the Venmo app on the pay screen, pre-filled.
    /// Format: `venmo://paycharge?txn=pay&recipients=<handle>&amount=<n>&note=<text>`
    static func appURL(handle: String, amount: Decimal?, note: String?) -> URL? {
        var components = URLComponents()
        components.scheme = "venmo"
        components.host = "paycharge"

        var items = [
            URLQueryItem(name: "txn", value: "pay"),
            URLQueryItem(name: "recipients", value: normalize(handle))
        ]
        if let amount {
            items.append(URLQueryItem(name: "amount", value: amount.plainString))
        }
        if let note, !note.isEmpty {
            items.append(URLQueryItem(name: "note", value: note))
        }
        components.queryItems = items
        return components.url
    }

    /// Web fallback for when the Venmo app isn't installed.
    static func webURL(handle: String) -> URL? {
        URL(string: "https://venmo.com/u/\(normalize(handle))")
    }

    /// Strip a leading "@" so both "@jane" and "jane" work.
    private static func normalize(_ handle: String) -> String {
        var trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("@") { trimmed.removeFirst() }
        return trimmed
    }
}
