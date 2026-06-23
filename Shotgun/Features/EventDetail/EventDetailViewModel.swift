import Foundation
import Observation

@MainActor
@Observable
final class EventDetailViewModel {
    private(set) var event: Event
    var participants: [EventParticipant] = []
    var profilesByID: [UUID: Profile] = [:]
    var joinNote = ""
    var isLoading = false
    var errorMessage: String?

    private let eventsService = EventsService()
    private let profilesService = ProfileService()

    init(event: Event) {
        self.event = event
    }

    var hostProfile: Profile? { profilesByID[event.hostID] }
    var spotsRemaining: Int { max(0, event.capacity - participants.count) }
    var isFull: Bool { participants.count >= event.capacity }

    func isHost(_ userID: UUID?) -> Bool { userID == event.hostID }

    func myParticipation(_ userID: UUID?) -> EventParticipant? {
        guard let userID else { return nil }
        return participants.first { $0.userID == userID }
    }

    func displayName(for userID: UUID) -> String {
        profilesByID[userID]?.displayName ?? "Someone"
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            // Refresh the event (status/capacity may have changed) and participants.
            if let fresh = try await eventsService.fetchEvent(id: event.id) {
                event = fresh
            }
            participants = try await eventsService.fetchParticipants(eventID: event.id)

            var ids = Set(participants.map(\.userID))
            ids.insert(event.hostID)
            let profiles = try await profilesService.fetch(ids: Array(ids))
            profilesByID = Dictionary(profiles.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func join() async {
        errorMessage = nil
        do {
            let note = joinNote.trimmingCharacters(in: .whitespacesAndNewlines)
            try await eventsService.join(eventID: event.id, note: note.isEmpty ? nil : note)
            joinNote = ""
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func leave() async {
        errorMessage = nil
        do {
            try await eventsService.leave(eventID: event.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setPaid(_ paid: Bool, participantID: UUID) async {
        errorMessage = nil
        do {
            try await eventsService.setPaid(paid, participantID: participantID)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func close() async {
        await setStatus(.closed)
    }

    func cancel() async {
        await setStatus(.cancelled)
    }

    private func setStatus(_ status: EventStatus) async {
        errorMessage = nil
        do {
            try await eventsService.setStatus(status, eventID: event.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
