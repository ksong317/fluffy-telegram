import Foundation

/// Who can see an event. Mirrors the `event_audience` Postgres enum.
enum EventAudience: String, Codable, Sendable, CaseIterable, Identifiable {
    case closeFriends = "close_friends"
    case friends

    var id: String { rawValue }

    var label: String {
        switch self {
        case .closeFriends: "Close Friends"
        case .friends: "All Friends"
        }
    }
}

/// The money model for an event. Mirrors the `money_type` Postgres enum.
enum MoneyType: String, Codable, Sendable, CaseIterable, Identifiable {
    case free
    case chipIn = "chip_in"
    case setPrice = "set_price"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .free: "Free"
        case .chipIn: "Chip in"
        case .setPrice: "Set price"
        }
    }

    /// Whether this money type requires an amount to be entered.
    var requiresAmount: Bool { self != .free }
}

/// Event lifecycle. Mirrors the `event_status` Postgres enum.
enum EventStatus: String, Codable, Sendable {
    case open
    case closed
    case cancelled
}

/// Friend request state. Mirrors the `friendship_status` Postgres enum.
enum FriendshipStatus: String, Codable, Sendable {
    case pending
    case accepted
}
