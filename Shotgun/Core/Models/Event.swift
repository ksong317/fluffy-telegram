import Foundation

/// A "happening" a host posts for friends to join. Maps to `public.events`.
struct Event: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let hostID: UUID
    var title: String
    var placeText: String
    var startsAt: Date
    var closesAt: Date
    var capacity: Int
    var audience: EventAudience
    var moneyType: MoneyType
    var amount: Decimal?
    var note: String?
    var status: EventStatus
    var createdAt: Date

    /// How many people have joined. Only present when the row came from the
    /// `events_with_counts` view (the feed); nil when read straight from
    /// `events`, where the column doesn't exist. Optional so both decode.
    var participantCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case hostID = "host_id"
        case title
        case placeText = "place_text"
        case startsAt = "starts_at"
        case closesAt = "closes_at"
        case capacity
        case audience
        case moneyType = "money_type"
        case amount
        case note
        case status
        case createdAt = "created_at"
        case participantCount = "participant_count"
    }

    var isActive: Bool {
        status == .open && closesAt > Date()
    }

    /// Seats still open, or nil when the count wasn't fetched. Callers should
    /// fall back to showing capacity rather than guessing zero.
    var spotsRemaining: Int? {
        participantCount.map { max(0, capacity - $0) }
    }
}

/// Payload for creating an event. `host_id` is set from the current session.
struct NewEvent: Encodable, Sendable {
    let hostID: UUID
    let title: String
    let placeText: String
    let startsAt: Date
    let closesAt: Date
    let capacity: Int
    let audience: EventAudience
    let moneyType: MoneyType
    let amount: Decimal?
    let note: String?

    enum CodingKeys: String, CodingKey {
        case hostID = "host_id"
        case title
        case placeText = "place_text"
        case startsAt = "starts_at"
        case closesAt = "closes_at"
        case capacity
        case audience
        case moneyType = "money_type"
        case amount
        case note
    }
}
