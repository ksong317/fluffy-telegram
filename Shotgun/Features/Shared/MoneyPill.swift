import SwiftUI

/// Small pill that sets the financial expectation before a user taps into an event.
struct MoneyPill: View {
    let moneyType: MoneyType
    let amount: Decimal?

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
    }

    private var text: String {
        switch moneyType {
        case .free:
            "Free"
        case .chipIn:
            amount.map { "Chip in \($0.currencyString)" } ?? "Chip in"
        case .setPrice:
            amount?.currencyString ?? "Paid"
        }
    }

    private var tint: Color {
        moneyType == .free ? .green : .blue
    }
}
