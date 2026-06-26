import Foundation
import Supabase

/// Friends graph: requests, acceptance, removal, and the close-friends label.
struct FriendsService: Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.client) {
        self.client = client
    }

    // MARK: Friendships

    /// All friendships involving the current user (accepted + pending).
    /// RLS already scopes this to rows where the user is requester or addressee.
    func fetchFriendships() async throws -> [Friendship] {
        if DemoMode.isEnabled { return await DemoStore.shared.allFriendships() }
        return try await client
            .from("friendships")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func sendRequest(from me: UUID, to other: UUID) async throws {
        if DemoMode.isEnabled { return await DemoStore.shared.sendRequest(from: me, to: other) }
        let payload = NewFriendship(requesterID: me, addresseeID: other)
        try await client.from("friendships").insert(payload).execute()
    }

    func accept(friendshipID: UUID) async throws {
        if DemoMode.isEnabled { return await DemoStore.shared.accept(friendshipID: friendshipID) }
        try await client
            .from("friendships")
            .update(["status": FriendshipStatus.accepted.rawValue])
            .eq("id", value: friendshipID.uuidString)
            .execute()
    }

    func remove(friendshipID: UUID) async throws {
        if DemoMode.isEnabled { return await DemoStore.shared.remove(friendshipID: friendshipID) }
        try await client
            .from("friendships")
            .delete()
            .eq("id", value: friendshipID.uuidString)
            .execute()
    }

    // MARK: Close friends

    /// The current user's close-friend ids.
    func fetchCloseFriendIDs() async throws -> Set<UUID> {
        if DemoMode.isEnabled { return await DemoStore.shared.closeFriends() }
        let links: [CloseFriendLink] = try await client
            .from("close_friends")
            .select()
            .execute()
            .value
        return Set(links.map(\.friendID))
    }

    func markClose(owner me: UUID, friend: UUID) async throws {
        if DemoMode.isEnabled { return await DemoStore.shared.markClose(friend: friend) }
        let link = CloseFriendLink(ownerID: me, friendID: friend)
        try await client
            .from("close_friends")
            .upsert(link)
            .execute()
    }

    func unmarkClose(owner me: UUID, friend: UUID) async throws {
        if DemoMode.isEnabled { return await DemoStore.shared.unmarkClose(friend: friend) }
        try await client
            .from("close_friends")
            .delete()
            .eq("owner_id", value: me.uuidString)
            .eq("friend_id", value: friend.uuidString)
            .execute()
    }
}
