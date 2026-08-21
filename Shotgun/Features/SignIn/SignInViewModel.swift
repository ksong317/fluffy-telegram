import Foundation
import Observation

@MainActor
@Observable
final class SignInViewModel {
    enum Mode: Equatable {
        case signIn
        case signUp

        var title: String { self == .signIn ? "Sign in" : "Create account" }
        var toggleTitle: String {
            self == .signIn ? "No account? Create one" : "Already have an account? Sign in"
        }
        var toggled: Mode { self == .signIn ? .signUp : .signIn }
    }

    var mode: Mode = .signIn
    var email = ""
    var password = ""
    var errorMessage: String?

    private let auth: any AuthProviding

    init(auth: any AuthProviding = AuthProviderFactory.make()) {
        self.auth = auth
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Deliberately permissive — the server is the real validator, and an
    /// over-strict regex here just rejects valid addresses (plus-tags, new TLDs,
    /// unicode domains). This only catches obvious typos before a round trip.
    private var emailLooksValid: Bool {
        let value = trimmedEmail
        guard value.count >= 5 else { return false }
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && parts.allSatisfy { !$0.isEmpty } && parts[1].contains(".")
    }

    /// Supabase rejects anything under 6 characters, so mirroring that here
    /// turns a round trip and a raw server error into inline feedback.
    static let minimumPasswordLength = 6

    var canSubmit: Bool {
        emailLooksValid && password.count >= Self.minimumPasswordLength
    }

    /// Shown under the password field while signing up, so the length rule is
    /// visible before the button enables rather than after a rejection.
    var passwordHint: String? {
        guard mode == .signUp else { return nil }
        return "At least \(Self.minimumPasswordLength) characters."
    }

    func toggleMode() {
        mode = mode.toggled
        errorMessage = nil
    }

    /// Returns the user id on success so the caller can update `AppState`.
    func submit() async -> UUID? {
        guard canSubmit else { return nil }
        errorMessage = nil
        do {
            switch mode {
            case .signIn:
                return try await auth.signIn(email: trimmedEmail.lowercased(), password: password)
            case .signUp:
                return try await auth.signUp(email: trimmedEmail.lowercased(), password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
