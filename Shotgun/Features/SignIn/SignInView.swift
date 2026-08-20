import SwiftUI

/// Email + password sign-in and sign-up.
///
/// Chosen over one-time codes because Supabase gates email-template editing
/// behind custom SMTP, and the built-in sender is rate limited project-wide and
/// lands in spam — so no email-based flow is usable until a real SMTP provider
/// is configured. Swapping to OTP later means replacing this screen and the
/// methods on `AuthProviding`; nothing above that layer changes.
struct SignInView: View {
    @Environment(AppState.self) private var appState
    @State private var model = SignInViewModel()
    @FocusState private var focus: Field?

    private enum Field { case email, password }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("Shotgun")
                    .font(.largeTitle.bold())
                Text("Rides and runs with your friends.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                TextField("you@example.com", text: $model.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focus = .password }
                    .padding()
                    .background(.quaternary, in: .rect(cornerRadius: 12))

                SecureField("Password", text: $model.password)
                    // `.password` on sign-in lets the keychain autofill; on
                    // sign-up `.newPassword` is what prompts iOS to offer to
                    // generate and save a strong one.
                    .textContentType(model.mode == .signUp ? .newPassword : .password)
                    .focused($focus, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { Task { await submit() } }
                    .padding()
                    .background(.quaternary, in: .rect(cornerRadius: 12))

                if let hint = model.passwordHint {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                AsyncButton {
                    await submit()
                } label: {
                    Text(model.mode.title).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!model.canSubmit)

                Button(model.mode.toggleTitle) { model.toggleMode() }
                    .font(.footnote)
            }

            if let message = model.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .animation(.default, value: model.mode)
        .onAppear { focus = .email }
    }

    private func submit() async {
        if let userID = await model.submit() {
            await appState.didSignIn(userID: userID)
        }
    }
}
