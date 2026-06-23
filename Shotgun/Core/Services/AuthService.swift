import Foundation
import Supabase

/// Authentication: phone OTP and Sign in with Apple, plus session observation.
struct AuthService: Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.client) {
        self.client = client
    }

    /// Emits on sign-in, sign-out, token refresh, and once on launch with the
    /// restored session (or nil). Drive app routing from this.
    var authStateChanges: AsyncStream<(event: AuthChangeEvent, session: Session?)> {
        client.auth.authStateChanges
    }

    var currentSession: Session? {
        get async { try? await client.auth.session }
    }

    // MARK: Phone OTP

    /// Send a one-time code to a phone number in E.164 format (e.g. "+15551234567").
    func sendOTP(toPhone phone: String) async throws {
        try await client.auth.signInWithOTP(phone: phone)
    }

    /// Verify the code the user received.
    func verifyOTP(phone: String, code: String) async throws {
        try await client.auth.verifyOTP(phone: phone, token: code, type: .sms)
    }

    // MARK: Sign in with Apple

    /// Exchange an Apple identity token (from `ASAuthorization`) for a session.
    /// `nonce` must be the raw nonce whose SHA256 was sent in the Apple request.
    func signInWithApple(idToken: String, nonce: String) async throws {
        try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
    }

    // MARK: Session

    func signOut() async throws {
        try await client.auth.signOut()
    }
}
