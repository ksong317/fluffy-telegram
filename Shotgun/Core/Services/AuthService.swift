import Foundation
import Supabase

/// Errors surfaced to the sign-in UI.
enum AuthError: LocalizedError {
    /// `signUp` returned a user but no session, which means Supabase still wants
    /// to confirm the address by email. The app has no email delivery worth
    /// relying on yet (the built-in sender is rate limited to a handful per hour
    /// project-wide and lands in spam), so this is a misconfiguration rather
    /// than a state to build a UI around.
    case emailConfirmationRequired

    var errorDescription: String? {
        switch self {
        case .emailConfirmationRequired:
            return """
            This project still requires email confirmation. Turn off \
            Authentication → Sign In / Providers → Email → "Confirm email" \
            in the Supabase dashboard.
            """
        }
    }
}

/// Everything the app needs from an identity provider. `AppState` and the
/// sign-in screen talk to this rather than to `SupabaseClient.auth` directly,
/// which is what lets demo mode substitute a fake without the rest of the app
/// knowing, and what will let email OTP or phone OTP drop in later without
/// touching anything above this layer.
protocol AuthProviding: Sendable {
    /// The signed-in user's id, or nil when signed out. Read at launch to
    /// restore a persisted session.
    func currentUserID() async -> UUID?

    /// Create an account and return the new user's id.
    @discardableResult
    func signUp(email: String, password: String) async throws -> UUID

    /// Sign in to an existing account and return the user's id.
    @discardableResult
    func signIn(email: String, password: String) async throws -> UUID

    func signOut() async throws
}

// MARK: - Supabase

struct SupabaseAuthProvider: AuthProviding {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.client) {
        self.client = client
    }

    func currentUserID() async -> UUID? {
        // `session` refreshes an expired access token; `currentUser` would hand
        // back a stale identity after the refresh token itself has expired.
        try? await client.auth.session.user.id
    }

    @discardableResult
    func signUp(email: String, password: String) async throws -> UUID {
        let response = try await client.auth.signUp(email: email, password: password)
        switch response {
        case .session(let session):
            return session.user.id
        case .user:
            // Signed up, but no session: confirmation is still switched on.
            throw AuthError.emailConfirmationRequired
        }
    }

    @discardableResult
    func signIn(email: String, password: String) async throws -> UUID {
        try await client.auth.signIn(email: email, password: password).user.id
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }
}

// MARK: - Demo

/// Accepts anything and boots in as the seeded demo user.
struct DemoAuthProvider: AuthProviding {
    func currentUserID() async -> UUID? { DemoData.me.id }
    @discardableResult
    func signUp(email: String, password: String) async throws -> UUID { DemoData.me.id }
    @discardableResult
    func signIn(email: String, password: String) async throws -> UUID { DemoData.me.id }
    func signOut() async throws {}
}

// MARK: - Selection

enum AuthProviderFactory {
    static func make() -> any AuthProviding {
        DemoMode.isEnabled ? DemoAuthProvider() : SupabaseAuthProvider()
    }
}
