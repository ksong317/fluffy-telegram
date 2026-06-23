import Foundation

/// Someone who has joined an event. Maps to `public.event_participants`.
struct EventParticipant: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let eventID: UUID
    let userID: UUID
    var note: String?
    var paid: Bool
    var joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case eventID = "event_id"
        case userID = "user_id"
        case note
        case paid
        case joinedAt = "joined_at"
    }
}
