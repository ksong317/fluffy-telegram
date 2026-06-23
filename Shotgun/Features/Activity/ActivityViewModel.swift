import Foundation
import Observation

@MainActor
@Observable
final class ActivityViewModel {
    var hosted: [Event] = []
    var joined: [Event] = []
    var isLoading = false
    var errorMessage: String?

    private let eventsService = EventsService()

    func load(me: UUID) async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            hosted = try await eventsService.fetchHosted(by: me)
            let joinedIDs = try await eventsService.fetchJoinedEventIDs(by: me)
            joined = try await eventsService.fetchEvents(ids: joinedIDs)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
