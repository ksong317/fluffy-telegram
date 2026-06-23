import Foundation
import Observation
import Supabase

/// Root app state: owns the auth session and decides which top-level flow to show.
/// Injected into the environment and observed by `RootView`.
@MainActor
@Observable
final class AppState {
    enum Phase: Equatable {
        case loading        // checking for a restored session
        case signedOut      // no session — show auth
        case needsProfile   // signed in, profile incomplete — show setup
        case ready          // signed in with a complete profile — show main app
    }

    private(set) var phase: Phase = .loading
    private(set) var currentUserID: UUID?
    private(set) var profile: Profile?

    private let auth = AuthService()
    private let profiles = ProfileService()

    /// Begin observing auth state. Call once from the app's root `.task`.
    func start() async {
        for await change in auth.authStateChanges {
            await handle(session: change.session)
        }
    }

    private func handle(session: Session?) async {
        guard let session else {
            currentUserID = nil
            profile = nil
            phase = .signedOut
            return
        }
        currentUserID = session.user.id
        await refreshProfile()
    }

    /// Re-fetch the current user's profile and recompute the phase. Call after
    /// completing profile setup.
    func refreshProfile() async {
        guard let uid = currentUserID else { return }
        do {
            let fetched = try await profiles.fetch(id: uid)
            profile = fetched
            phase = (fetched?.isComplete ?? false) ? .ready : .needsProfile
        } catch {
            // Network/permission hiccup — fall back to setup rather than locking out.
            phase = .needsProfile
        }
    }

    func signOut() async {
        try? await auth.signOut()
    }
}
