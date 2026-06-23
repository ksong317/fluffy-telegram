import SwiftUI

struct ProfileSetupView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ProfileSetupViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Your name") {
                    TextField("Display name", text: $viewModel.displayName)
                        .textContentType(.name)
                }

                Section {
                    TextField("Venmo handle (e.g. @jane)", text: $viewModel.venmoHandle)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Venmo")
                } footer: {
                    Text("Needed when you host or join a paid event. You can add it later.")
                }

                // TODO: profile photo picker -> upload to `avatars` bucket.

                if let error = viewModel.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
            }
            .navigationTitle("Set up profile")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    AsyncButton {
                        guard let uid = appState.currentUserID else { return }
                        if await viewModel.save(userID: uid) {
                            await appState.refreshProfile()
                        }
                    } label: {
                        Text("Save")
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .task { viewModel.load(from: appState.profile) }
        }
    }
}
