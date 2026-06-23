import AuthenticationServices
import Foundation
import Observation

@MainActor
@Observable
final class AuthViewModel {
    enum Step {
        case phoneEntry
        case codeEntry
    }

    var step: Step = .phoneEntry
    var phone = ""
    var code = ""
    var errorMessage: String?

    private let auth = AuthService()

    /// Naive E.164 check: leading "+" and 8–15 digits.
    var canSendCode: Bool {
        let digits = phone.filter(\.isNumber)
        return phone.hasPrefix("+") && (8...15).contains(digits.count)
    }

    var canVerify: Bool {
        code.filter(\.isNumber).count >= 4
    }

    func sendCode() async {
        errorMessage = nil
        do {
            try await auth.sendOTP(toPhone: phone)
            step = .codeEntry
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func verify() async {
        errorMessage = nil
        do {
            try await auth.verifyOTP(phone: phone, code: code)
            // AppState's authStateChanges stream picks up the new session.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetToPhone() {
        code = ""
        step = .phoneEntry
    }

    // MARK: Sign in with Apple

    func handleApple(result: Result<ASAuthorization, Error>, rawNonce: String?) async {
        errorMessage = nil
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = rawNonce
            else {
                errorMessage = "Apple sign-in failed."
                return
            }
            do {
                try await auth.signInWithApple(idToken: idToken, nonce: nonce)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
