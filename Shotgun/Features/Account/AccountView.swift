import SwiftUI

/// Lightweight account screen: shows the current profile and signs out.
struct AccountView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let profile = appState.profile {
                    Section("You") {
                        LabeledContent("Name", value: profile.displayName)
                        LabeledContent("Venmo", value: profile.venmoHandle ?? "—")
                    }
                }
                // TODO: link to an edit-profile screen (reuse ProfileSetupView in edit mode).

                Section {
                    AsyncButton(role: .destructive) {
                        await appState.signOut()
                    } label: {
                        Text("Sign out")
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
