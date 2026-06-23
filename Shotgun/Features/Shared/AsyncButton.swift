import SwiftUI

/// A button whose action is async and which shows a spinner while it runs.
struct AsyncButton<Label: View>: View {
    var role: ButtonRole?
    var action: () async -> Void
    @ViewBuilder var label: () -> Label

    @State private var isRunning = false

    init(
        role: ButtonRole? = nil,
        action: @escaping () async -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.role = role
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(role: role) {
            isRunning = true
            Task {
                await action()
                isRunning = false
            }
        } label: {
            ZStack {
                label().opacity(isRunning ? 0 : 1)
                if isRunning { ProgressView() }
            }
        }
        .disabled(isRunning)
    }
}
