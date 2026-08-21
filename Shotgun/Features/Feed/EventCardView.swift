import SwiftUI

/// One event row in the feed. Time-left leads; the money pill sets expectations.
struct EventCardView: View {
    let event: Event
    let hostName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(event.title)
                    .font(.headline)
                Spacer()
                MoneyPill(moneyType: event.moneyType, amount: event.amount)
            }

            Label(event.placeText, systemImage: "mappin.and.ellipse")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Label(event.startsAt.timeLeftDescription, systemImage: "clock")
                Label(spotsText, systemImage: "person.2")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text("Hosted by \(hostName)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    /// Prefers seats actually left. Falls back to capacity when the count is
    /// missing (demo mode, or a row read straight from `events`) — an
    /// unqualified "3 spots" is vague, but claiming "0 left" would be a lie.
    private var spotsText: String {
        guard let remaining = event.spotsRemaining else {
            return "\(event.capacity) spots"
        }
        return remaining == 0 ? "Full" : "\(remaining) of \(event.capacity) left"
    }
}
