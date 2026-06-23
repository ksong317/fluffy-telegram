import Foundation
import Observation

@MainActor
@Observable
final class FeedViewModel {
    var events: [Event] = []
    var hosts: [UUID: Profile] = [:]
    var isLoading = false
    var errorMessage: String?

    private let eventsService = EventsService()
    private let profiles = ProfileService()

    func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            let fetched = try await eventsService.fetchFeed()
            events = fetched

            let hostIDs = Array(Set(fetched.map(\.hostID)))
            let hostProfiles = try await profiles.fetch(ids: hostIDs)
            hosts = Dictionary(hostProfiles.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func hostName(for event: Event) -> String {
        hosts[event.hostID]?.displayName ?? "Someone"
    }
}
