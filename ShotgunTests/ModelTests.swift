import Foundation
import Testing
@testable import Shotgun

struct ModelTests {
    /// Verifies snake_case column names map to the camelCase Swift properties.
    @Test func decodesEventFromSnakeCaseJSON() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "host_id": "22222222-2222-2222-2222-222222222222",
          "title": "Trader Joe's run",
          "place_text": "Trader Joe's on 5th",
          "starts_at": "2026-06-22T18:00:00Z",
          "closes_at": "2026-06-22T19:00:00Z",
          "capacity": 5,
          "audience": "close_friends",
          "money_type": "chip_in",
          "amount": 10.5,
          "note": "text me your order",
          "status": "open",
          "created_at": "2026-06-22T17:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let event = try decoder.decode(Event.self, from: json)
        #expect(event.title == "Trader Joe's run")
        #expect(event.placeText == "Trader Joe's on 5th")
        #expect(event.capacity == 5)
        #expect(event.audience == .closeFriends)
        #expect(event.moneyType == .chipIn)
        #expect(event.amount == Decimal(string: "10.5"))
        #expect(event.status == .open)
    }

    @Test func friendshipResolvesOtherUser() {
        let me = UUID()
        let them = UUID()
        let friendship = Friendship(
            id: UUID(),
            requesterID: me,
            addresseeID: them,
            status: .pending,
            createdAt: .now
        )
        #expect(friendship.otherUserID(relativeTo: me) == them)
        #expect(friendship.isOutgoingRequest(for: me))
        #expect(!friendship.isIncomingRequest(for: me))
    }

    @Test func moneyTypeAmountRequirement() {
        #expect(MoneyType.free.requiresAmount == false)
        #expect(MoneyType.chipIn.requiresAmount)
        #expect(MoneyType.setPrice.requiresAmount)
    }
}
