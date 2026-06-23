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
    }

    var isActive: Bool {
        status == .open && closesAt > Date()
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
