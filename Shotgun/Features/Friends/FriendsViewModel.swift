import Foundation
import Observation

@MainActor
@Observable
final class FriendsViewModel {
    var friends: [Profile] = []
    var incoming: [(friendship: Friendship, profile: Profile)] = []
    var outgoing: [(friendship: Friendship, profile: Profile)] = []
    var closeFriendIDs: Set<UUID> = []

    var searchText = ""
    var searchResults: [Profile] = []

    var isLoading = false
    var errorMessage: String?

    private var friendshipByOtherID: [UUID: Friendship] = [:]
    private let friendsService = FriendsService()
    private let profilesService = ProfileService()

    func isClose(_ id: UUID) -> Bool { closeFriendIDs.contains(id) }

    /// True if there's already any relationship (friend or pending) with this id.
    func hasRelationship(with id: UUID) -> Bool { friendshipByOtherID[id] != nil }

    func load(me: UUID) async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            let friendships = try await friendsService.fetchFriendships()
            closeFriendIDs = try await friendsService.fetchCloseFriendIDs()

            let otherIDs = friendships.map { $0.otherUserID(relativeTo: me) }
            let profiles = try await profilesService.fetch(ids: otherIDs)
            let byID = Dictionary(profiles.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

            var accepted: [Profile] = []
            var inc: [(Friendship, Profile)] = []
            var out: [(Friendship, Profile)] = []
            friendshipByOtherID = [:]

            for friendship in friendships {
                let otherID = friendship.otherUserID(relativeTo: me)
                friendshipByOtherID[otherID] = friendship
                guard let profile = byID[otherID] else { continue }
                switch friendship.status {
                case .accepted:
                    accepted.append(profile)
                case .pending:
                    if friendship.isIncomingRequest(for: me) {
                        inc.append((friendship, profile))
                    } else {
                        out.append((friendship, profile))
                    }
                }
            }

            friends = accepted.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            incoming = inc.map { (friendship: $0.0, profile: $0.1) }
            outgoing = out.map { (friendship: $0.0, profile: $0.1) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func search(me: UUID) async {
        errorMessage = nil
        do {
            searchResults = try await profilesService.search(query: searchText, excluding: me)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendRequest(me: UUID, to other: UUID) async {
        await run { try await self.friendsService.sendRequest(from: me, to: other) }
        await load(me: me)
    }

    func accept(_ friendship: Friendship, me: UUID) async {
        await run { try await self.friendsService.accept(friendshipID: friendship.id) }
        await load(me: me)
    }

    func remove(otherID: UUID, me: UUID) async {
        guard let friendship = friendshipByOtherID[otherID] else { return }
        await run { try await self.friendsService.remove(friendshipID: friendship.id) }
        await load(me: me)
    }

    func toggleClose(friend: UUID, me: UUID) async {
        let makeClose = !isClose(friend)
        await run {
            if makeClose {
                try await self.friendsService.markClose(owner: me, friend: friend)
            } else {
                try await self.friendsService.unmarkClose(owner: me, friend: friend)
            }
        }
        await load(me: me)
    }

    private func run(_ operation: () async throws -> Void) async {
        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
