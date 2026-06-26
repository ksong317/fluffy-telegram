import Foundation
import Supabase

/// Events ("happenings"): the feed, create, detail, join/leave, lifecycle.
struct EventsService: Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.client) {
        self.client = client
    }

    // MARK: Feed & detail

    /// Active events the user is allowed to see, soonest first. RLS enforces
    /// the audience rules; we just filter to open, not-yet-closed events.
    func fetchFeed() async throws -> [Event] {
        if DemoMode.isEnabled { return await DemoStore.shared.feed() }
        return try await client
            .from("events")
            .select()
            .eq("status", value: EventStatus.open.rawValue)
            .gt("closes_at", value: ISO8601DateFormatter.supabase.string(from: Date()))
            .order("starts_at", ascending: true)
            .execute()
            .value
    }

    func fetchEvent(id: UUID) async throws -> Event? {
        if DemoMode.isEnabled { return await DemoStore.shared.event(id: id) }
        let rows: [Event] = try await client
            .from("events")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func fetchEvents(ids: [UUID]) async throws -> [Event] {
        guard !ids.isEmpty else { return [] }
        if DemoMode.isEnabled { return await DemoStore.shared.events(ids: ids) }
        return try await client
            .from("events")
            .select()
            .in("id", values: ids.map(\.uuidString))
            .order("starts_at", ascending: false)
            .execute()
            .value
    }

    func fetchParticipants(eventID: UUID) async throws -> [EventParticipant] {
        if DemoMode.isEnabled { return await DemoStore.shared.participants(eventID: eventID) }
        return try await client
            .from("event_participants")
            .select()
            .eq("event_id", value: eventID.uuidString)
            .order("joined_at", ascending: true)
            .execute()
            .value
    }

    // MARK: Create / lifecycle

    @discardableResult
    func create(_ event: NewEvent) async throws -> Event {
        if DemoMode.isEnabled { return await DemoStore.shared.create(event) }
        return try await client
            .from("events")
            .insert(event)
            .select()
            .single()
            .execute()
            .value
    }

    func setStatus(_ status: EventStatus, eventID: UUID) async throws {
        if DemoMode.isEnabled { return await DemoStore.shared.setStatus(status, eventID: eventID) }
        try await client
            .from("events")
            .update(["status": status.rawValue])
            .eq("id", value: eventID.uuidString)
            .execute()
    }

    // MARK: Join / leave (transactional RPCs)

    private struct JoinParams: Encodable, Sendable {
        let p_event_id: UUID
        let p_note: String?
    }

    private struct LeaveParams: Encodable, Sendable {
        let p_event_id: UUID
    }

    /// Join via the `join_event` RPC, which enforces capacity under a row lock.
    /// Throws if the event is full / closed / not visible (see the RPC's RAISEs).
    func join(eventID: UUID, note: String?) async throws {
        if DemoMode.isEnabled { return await DemoStore.shared.join(eventID: eventID, note: note) }
        try await client
            .rpc("join_event", params: JoinParams(p_event_id: eventID, p_note: note))
            .execute()
    }

    func leave(eventID: UUID) async throws {
        if DemoMode.isEnabled { return await DemoStore.shared.leave(eventID: eventID) }
        try await client
            .rpc("leave_event", params: LeaveParams(p_event_id: eventID))
            .execute()
    }

    // MARK: Paid flag

    func setPaid(_ paid: Bool, participantID: UUID) async throws {
        if DemoMode.isEnabled { return await DemoStore.shared.setPaid(paid, participantID: participantID) }
        try await client
            .from("event_participants")
            .update(["paid": paid])
            .eq("id", value: participantID.uuidString)
            .execute()
    }

    // MARK: Activity / history

    /// Events the current user hosts (any status), newest first.
    func fetchHosted(by hostID: UUID) async throws -> [Event] {
        if DemoMode.isEnabled { return await DemoStore.shared.hosted(by: hostID) }
        return try await client
            .from("events")
            .select()
            .eq("host_id", value: hostID.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Event ids the current user has joined (resolve to events as needed).
    func fetchJoinedEventIDs(by userID: UUID) async throws -> [UUID] {
        if DemoMode.isEnabled { return await DemoStore.shared.joinedEventIDs(by: userID) }
        let rows: [EventParticipant] = try await client
            .from("event_participants")
            .select()
            .eq("user_id", value: userID.uuidString)
            .order("joined_at", ascending: false)
            .execute()
            .value
        return rows.map(\.eventID)
    }
}
