import AuthenticationServices
import SwiftUI

struct AuthView: View {
    @State private var viewModel = AuthViewModel()
    @State private var appleNonce: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                Text("Shotgun")
                    .font(.largeTitle.bold())
                Text("Call shotgun on what your friends are already doing.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            switch viewModel.step {
            case .phoneEntry:
                phoneEntry
            case .codeEntry:
                codeEntry
            }

            if viewModel.step == .phoneEntry {
                appleDivider
                appleButton
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
    }

    private var phoneEntry: some View {
        VStack(spacing: 12) {
            TextField("Phone (e.g. +15551234567)", text: $viewModel.phone)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
                .textFieldStyle(.roundedBorder)

            AsyncButton {
                await viewModel.sendCode()
            } label: {
                Text("Send code").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSendCode)
        }
    }

    private var codeEntry: some View {
        VStack(spacing: 12) {
            Text("Enter the code we texted \(viewModel.phone)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            TextField("6-digit code", text: $viewModel.code)
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)

            AsyncButton {
                await viewModel.verify()
            } label: {
                Text("Verify").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canVerify)

            Button("Use a different number") { viewModel.resetToPhone() }
                .font(.footnote)
        }
    }

    private var appleDivider: some View {
        HStack {
            VStack { Divider() }
            Text("or").font(.footnote).foregroundStyle(.secondary)
            VStack { Divider() }
        }
    }

    private var appleButton: some View {
        SignInWithAppleButton(.signIn) { request in
            let nonce = AppleNonce.random()
            appleNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleNonce.sha256(nonce)
        } onCompletion: { result in
            Task { await viewModel.handleApple(result: result, rawNonce: appleNonce) }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 48)
    }
}
