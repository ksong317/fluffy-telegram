import Foundation
import Supabase

/// Reads and writes `public.profiles`.
struct ProfileService: Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.client) {
        self.client = client
    }

    /// Fetch a single profile, or nil if it doesn't exist yet.
    func fetch(id: UUID) async throws -> Profile? {
        if DemoMode.isEnabled { return await DemoStore.shared.profile(id: id) }
        let rows: [Profile] = try await client
            .from("profiles")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    /// Create or update the current user's profile (profile-setup screen).
    @discardableResult
    func upsert(_ payload: ProfileUpsert) async throws -> Profile {
        if DemoMode.isEnabled { return await DemoStore.shared.upsert(payload) }
        return try await client
            .from("profiles")
            .upsert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    /// Search profiles by display name or Venmo handle (for adding friends).
    func search(query: String, excluding meID: UUID) async throws -> [Profile] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        if DemoMode.isEnabled { return await DemoStore.shared.search(query: trimmed, excluding: meID) }

        let rows: [Profile] = try await client
            .from("profiles")
            .select()
            .or("display_name.ilike.%\(trimmed)%,venmo_handle.ilike.%\(trimmed)%")
            .neq("id", value: meID.uuidString)
            .limit(20)
            .execute()
            .value
        return rows
    }

    /// Fetch several profiles by id, e.g. to resolve a friend/participant list.
    func fetch(ids: [UUID]) async throws -> [Profile] {
        guard !ids.isEmpty else { return [] }
        if DemoMode.isEnabled { return await DemoStore.shared.profiles(ids: ids) }
        let rows: [Profile] = try await client
            .from("profiles")
            .select()
            .in("id", values: ids.map(\.uuidString))
            .execute()
            .value
        return rows
    }
}
