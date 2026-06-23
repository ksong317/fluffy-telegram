import Foundation

/// A mutual friendship (or pending request). Maps to `public.friendships`.
struct Friendship: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let requesterID: UUID
    let addresseeID: UUID
    var status: FriendshipStatus
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case requesterID = "requester_id"
        case addresseeID = "addressee_id"
        case status
        case createdAt = "created_at"
    }

    /// The id of the *other* person in this friendship, relative to `me`.
    func otherUserID(relativeTo me: UUID) -> UUID {
        requesterID == me ? addresseeID : requesterID
    }

    /// True when `me` received this request and hasn't responded yet.
    func isIncomingRequest(for me: UUID) -> Bool {
        status == .pending && addresseeID == me
    }

    /// True when `me` sent this request and it's still pending.
    func isOutgoingRequest(for me: UUID) -> Bool {
        status == .pending && requesterID == me
    }
}

/// Payload for sending a friend request.
struct NewFriendship: Encodable, Sendable {
    let requesterID: UUID
    let addresseeID: UUID

    enum CodingKeys: String, CodingKey {
        case requesterID = "requester_id"
        case addresseeID = "addressee_id"
    }
}

/// Payload for adding a close-friend label. Maps to `public.close_friends`.
struct CloseFriendLink: Codable, Sendable, Hashable {
    let ownerID: UUID
    let friendID: UUID

    enum CodingKeys: String, CodingKey {
        case ownerID = "owner_id"
        case friendID = "friend_id"
    }
}
