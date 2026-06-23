import Foundation
import Testing
@testable import Shotgun

struct VenmoLinkTests {
    @Test func buildsPrefilledAppURL() throws {
        let url = try #require(
            VenmoLink.appURL(handle: "@jane", amount: Decimal(string: "12.5"), note: "TJ run")
        )
        let string = url.absoluteString
        #expect(string.hasPrefix("venmo://paycharge"))
        #expect(string.contains("txn=pay"))
        #expect(string.contains("recipients=jane")) // leading @ stripped
        #expect(string.contains("amount=12.5"))
    }

    @Test func omitsAmountWhenNil() throws {
        let url = try #require(VenmoLink.appURL(handle: "jane", amount: nil, note: nil))
        #expect(!url.absoluteString.contains("amount="))
    }

    @Test func buildsWebFallback() throws {
        let url = try #require(VenmoLink.webURL(handle: "@jane"))
        #expect(url.absoluteString == "https://venmo.com/u/jane")
    }
}
