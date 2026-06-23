import Foundation

/// A user's public profile. Maps to `public.profiles`.
struct Profile: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var displayName: String
    var photoURL: String?
    var venmoHandle: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case photoURL = "photo_url"
        case venmoHandle = "venmo_handle"
        case createdAt = "created_at"
    }

    /// The minimum needed to enter the app: a display name. Venmo is encouraged
    /// (required for paid events) but not gated on at onboarding.
    var isComplete: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Payload for creating/updating a profile (profile-setup screen). Sent as an
/// upsert so it works whether or not the trigger-created stub row exists.
struct ProfileUpsert: Encodable, Sendable {
    let id: UUID
    let displayName: String
    let venmoHandle: String?
    let photoURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case venmoHandle = "venmo_handle"
        case photoURL = "photo_url"
    }
}
