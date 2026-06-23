import Foundation
import Observation

@MainActor
@Observable
final class CreateEventViewModel {
    var title = ""
    var placeText = ""
    var startsAt = Date()
    var closesAt = Date().addingTimeInterval(60 * 60) // default: closes in an hour
    var capacity = 3
    var audience: EventAudience = .closeFriends       // safe default (spec §5.3)
    var moneyType: MoneyType = .free
    var amountText = ""
    var note = ""
    var errorMessage: String?

    private let eventsService = EventsService()

    var amount: Decimal? {
        Decimal(string: amountText.trimmingCharacters(in: .whitespaces))
    }

    var canCreate: Bool {
        guard
            !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !placeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            capacity > 0,
            closesAt > startsAt
        else { return false }

        if moneyType.requiresAmount {
            guard let amount, amount > 0 else { return false }
        }
        return true
    }

    func create(hostID: UUID) async -> Bool {
        errorMessage = nil
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = NewEvent(
            hostID: hostID,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            placeText: placeText.trimmingCharacters(in: .whitespacesAndNewlines),
            startsAt: startsAt,
            closesAt: closesAt,
            capacity: capacity,
            audience: audience,
            moneyType: moneyType,
            amount: moneyType.requiresAmount ? amount : nil,
            note: trimmedNote.isEmpty ? nil : trimmedNote
        )
        do {
            try await eventsService.create(payload)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
