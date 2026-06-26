import Foundation

/// Toggles the app into **offline demo mode**: no auth, no Supabase, just
/// seeded sample data served from an in-memory store.
///
/// This exists so the app can be explored without a working backend (the phone
/// OTP needs Twilio and Sign in with Apple needs a paid Apple team). Flip this
/// to `false` to restore the real authenticated flow — the services fall back to
/// their Supabase implementations automatically.
enum DemoMode {
    static let isEnabled = true
}

/// Stable identities and the seed graph for demo mode. Fixed UUIDs keep things
/// deterministic across launches.
enum DemoData {
    // MARK: People

    static let me = Profile(
        id: id(1),
        displayName: "You",
        photoURL: nil,
        venmoHandle: "@you-demo",
        createdAt: daysAgo(40)
    )

    static let alex = Profile(id: id(2), displayName: "Alex Rivera", photoURL: nil, venmoHandle: "@alex-rivera", createdAt: daysAgo(30))
    static let priya = Profile(id: id(3), displayName: "Priya Patel", photoURL: nil, venmoHandle: "@priya-p", createdAt: daysAgo(28))
    static let marcus = Profile(id: id(4), displayName: "Marcus Lee", photoURL: nil, venmoHandle: "@marcus-lee", createdAt: daysAgo(25))
    static let sam = Profile(id: id(5), displayName: "Sam Kim", photoURL: nil, venmoHandle: "@sam-k", createdAt: daysAgo(20))
    static let jordan = Profile(id: id(6), displayName: "Jordan Wells", photoURL: nil, venmoHandle: "@jordan-w", createdAt: daysAgo(15))
    static let dana = Profile(id: id(7), displayName: "Dana Quinn", photoURL: nil, venmoHandle: "@dana-q", createdAt: daysAgo(10))
    static let chris = Profile(id: id(8), displayName: "Chris Morales", photoURL: nil, venmoHandle: "@chris-m", createdAt: daysAgo(8))

    static var allProfiles: [Profile] { [me, alex, priya, marcus, sam, jordan, dana, chris] }

    // MARK: Events (host, timing, money)

    /// Target run — hosted by **you**, so it shows under Activity → "Hosted by you".
    static let eTarget = event(10, host: me.id, title: "Target run", place: "Target on 4th", startsIn: 20 * 60, capacity: 3, money: .free)
    /// Costco — a friend's free run for the feed.
    static let eCostco = event(11, host: alex.id, title: "Costco haul", place: "Costco, Almaden", startsIn: 30 * 60, capacity: 4, money: .free)
    /// Trader Joe's — paid (set price); **you** are a participant → Activity "You joined".
    static let eTraderJoes = event(12, host: priya.id, title: "Trader Joe's", place: "TJ's on Coleman", startsIn: 45 * 60, capacity: 2, money: .setPrice, amount: 12)
    /// Airport ride — chip-in, no one joined yet (shows the empty participant state).
    static let eAirport = event(13, host: marcus.id, title: "Airport ride (SJC)", place: "Pickup at the dorms", startsIn: 2 * 60 * 60, capacity: 3, money: .chipIn, amount: 15)

    static var allEvents: [Event] { [eTarget, eCostco, eTraderJoes, eAirport] }

    // MARK: Participants

    static var participants: [EventParticipant] {
        [
            // Costco: Priya + Marcus rode along.
            participant(20, event: eCostco.id, user: priya.id, note: "grab oat milk?"),
            participant(21, event: eCostco.id, user: marcus.id, note: nil),
            // Trader Joe's (paid): you joined (unpaid), Sam joined (paid).
            participant(22, event: eTraderJoes.id, user: me.id, note: "need eggs", paid: false),
            participant(23, event: eTraderJoes.id, user: sam.id, note: nil, paid: true),
            // Target (yours): Alex joined.
            participant(24, event: eTarget.id, user: alex.id, note: "need a phone charger"),
        ]
    }

    // MARK: Friend graph

    static var friendships: [Friendship] {
        [
            friendship(30, requester: me.id, addressee: alex.id, status: .accepted),
            friendship(31, requester: priya.id, addressee: me.id, status: .accepted),
            friendship(32, requester: me.id, addressee: marcus.id, status: .accepted),
            // Incoming pending request → shows in Friends → "Requests".
            friendship(33, requester: sam.id, addressee: me.id, status: .pending),
            // Outgoing pending request → shows in "Sent requests".
            friendship(34, requester: me.id, addressee: jordan.id, status: .pending),
        ]
    }

    /// Priya is marked a close friend.
    static var closeFriendIDs: Set<UUID> { [priya.id] }

    // MARK: - Builders

    private static func id(_ n: Int) -> UUID {
        // e.g. 00000000-0000-0000-0000-000000000001
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
    }

    private static func daysAgo(_ days: Int) -> Date {
        Date().addingTimeInterval(-Double(days) * 86_400)
    }

    private static func event(
        _ n: Int,
        host: UUID,
        title: String,
        place: String,
        startsIn seconds: TimeInterval,
        capacity: Int,
        money: MoneyType,
        amount: Decimal? = nil,
        audience: EventAudience = .friends
    ) -> Event {
        let starts = Date().addingTimeInterval(seconds)
        return Event(
            id: id(n),
            hostID: host,
            title: title,
            placeText: place,
            startsAt: starts,
            closesAt: starts.addingTimeInterval(60 * 60),
            capacity: capacity,
            audience: audience,
            moneyType: money,
            amount: money.requiresAmount ? amount : nil,
            note: nil,
            status: .open,
            createdAt: Date().addingTimeInterval(-30 * 60)
        )
    }

    private static func participant(_ n: Int, event: UUID, user: UUID, note: String?, paid: Bool = false) -> EventParticipant {
        EventParticipant(id: id(n), eventID: event, userID: user, note: note, paid: paid, joinedAt: Date().addingTimeInterval(-10 * 60))
    }

    private static func friendship(_ n: Int, requester: UUID, addressee: UUID, status: FriendshipStatus) -> Friendship {
        Friendship(id: id(n), requesterID: requester, addresseeID: addressee, status: status, createdAt: daysAgo(5))
    }
}

/// In-memory backing store for demo mode. Seeded from `DemoData` and mutated by
/// the services so actions (join, create, accept, …) feel live within a session.
/// Nothing persists across launches.
actor DemoStore {
    static let shared = DemoStore()

    private var profiles: [Profile]
    private var events: [Event]
    private var participants: [EventParticipant]
    private var friendships: [Friendship]
    private var closeFriendIDs: Set<UUID>

    /// The "logged-in" user in demo mode.
    nonisolated var meID: UUID { DemoData.me.id }

    private init() {
        profiles = DemoData.allProfiles
        events = DemoData.allEvents
        participants = DemoData.participants
        friendships = DemoData.friendships
        closeFriendIDs = DemoData.closeFriendIDs
    }

    // MARK: Events

    func feed() -> [Event] {
        let now = Date()
        return events
            .filter { $0.status == .open && $0.closesAt > now }
            .sorted { $0.startsAt < $1.startsAt }
    }

    func event(id: UUID) -> Event? { events.first { $0.id == id } }

    func events(ids: [UUID]) -> [Event] {
        let wanted = Set(ids)
        return events.filter { wanted.contains($0.id) }.sorted { $0.startsAt > $1.startsAt }
    }

    func participants(eventID: UUID) -> [EventParticipant] {
        participants.filter { $0.eventID == eventID }.sorted { $0.joinedAt < $1.joinedAt }
    }

    func create(_ new: NewEvent) -> Event {
        let event = Event(
            id: UUID(),
            hostID: new.hostID,
            title: new.title,
            placeText: new.placeText,
            startsAt: new.startsAt,
            closesAt: new.closesAt,
            capacity: new.capacity,
            audience: new.audience,
            moneyType: new.moneyType,
            amount: new.amount,
            note: new.note,
            status: .open,
            createdAt: Date()
        )
        events.insert(event, at: 0)
        return event
    }

    func setStatus(_ status: EventStatus, eventID: UUID) {
        guard let i = events.firstIndex(where: { $0.id == eventID }) else { return }
        events[i].status = status
    }

    func join(eventID: UUID, note: String?) {
        guard !participants.contains(where: { $0.eventID == eventID && $0.userID == meID }) else { return }
        participants.append(
            EventParticipant(id: UUID(), eventID: eventID, userID: meID, note: note, paid: false, joinedAt: Date())
        )
        // Mirror the RPC's auto-close when the last seat fills.
        if let event = event(id: eventID), participants(eventID: eventID).count >= event.capacity {
            setStatus(.closed, eventID: eventID)
        }
    }

    func leave(eventID: UUID) {
        participants.removeAll { $0.eventID == eventID && $0.userID == meID }
    }

    func setPaid(_ paid: Bool, participantID: UUID) {
        guard let i = participants.firstIndex(where: { $0.id == participantID }) else { return }
        participants[i].paid = paid
    }

    func hosted(by hostID: UUID) -> [Event] {
        events.filter { $0.hostID == hostID }.sorted { $0.createdAt > $1.createdAt }
    }

    func joinedEventIDs(by userID: UUID) -> [UUID] {
        participants
            .filter { $0.userID == userID }
            .sorted { $0.joinedAt > $1.joinedAt }
            .map(\.eventID)
    }

    // MARK: Friends

    func allFriendships() -> [Friendship] {
        friendships.sorted { $0.createdAt > $1.createdAt }
    }

    func sendRequest(from me: UUID, to other: UUID) {
        guard !friendships.contains(where: {
            ($0.requesterID == me && $0.addresseeID == other) || ($0.requesterID == other && $0.addresseeID == me)
        }) else { return }
        friendships.append(Friendship(id: UUID(), requesterID: me, addresseeID: other, status: .pending, createdAt: Date()))
    }

    func accept(friendshipID: UUID) {
        guard let i = friendships.firstIndex(where: { $0.id == friendshipID }) else { return }
        friendships[i].status = .accepted
    }

    func remove(friendshipID: UUID) {
        friendships.removeAll { $0.id == friendshipID }
    }

    func closeFriends() -> Set<UUID> { closeFriendIDs }

    func markClose(friend: UUID) { closeFriendIDs.insert(friend) }

    func unmarkClose(friend: UUID) { closeFriendIDs.remove(friend) }

    // MARK: Profiles

    func profile(id: UUID) -> Profile? { profiles.first { $0.id == id } }

    func profiles(ids: [UUID]) -> [Profile] {
        let wanted = Set(ids)
        return profiles.filter { wanted.contains($0.id) }
    }

    func search(query: String, excluding meID: UUID) -> [Profile] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return profiles.filter { profile in
            guard profile.id != meID else { return false }
            let matchesName = profile.displayName.localizedCaseInsensitiveContains(trimmed)
            let matchesVenmo = profile.venmoHandle?.localizedCaseInsensitiveContains(trimmed) ?? false
            return matchesName || matchesVenmo
        }
    }

    func upsert(_ payload: ProfileUpsert) -> Profile {
        if let i = profiles.firstIndex(where: { $0.id == payload.id }) {
            profiles[i].displayName = payload.displayName
            profiles[i].venmoHandle = payload.venmoHandle
            profiles[i].photoURL = payload.photoURL
            return profiles[i]
        }
        let created = Profile(
            id: payload.id,
            displayName: payload.displayName,
            photoURL: payload.photoURL,
            venmoHandle: payload.venmoHandle,
            createdAt: Date()
        )
        profiles.append(created)
        return created
    }
}
