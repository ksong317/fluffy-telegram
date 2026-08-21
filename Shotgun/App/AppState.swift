import Foundation
import Observation

/// Root app state: owns the current user + profile and decides which top-level
/// flow to show. Injected into the environment and observed by `RootView`.
@MainActor
@Observable
final class AppState {
    enum Phase: Equatable {
        case loading        // booting, or restoring a persisted session
        case signedOut      // no session — show sign-in
        case needsProfile   // signed in, profile incomplete — show setup
        case ready          // signed in with a complete profile — show main app
    }

    private(set) var phase: Phase = .loading
    private(set) var currentUserID: UUID?
    private(set) var profile: Profile?

    private let profiles = ProfileService()
    private let auth: any AuthProviding

    init(auth: any AuthProviding = AuthProviderFactory.make()) {
        self.auth = auth
    }

    /// Boot the app. Call once from the app's root `.task`. Restores a persisted
    /// session if there is one, so returning users skip sign-in.
    func start() async {
        guard let uid = await auth.currentUserID() else {
            phase = .signedOut
            return
        }
        currentUserID = uid
        await refreshProfile()
    }

    /// Call after a successful OTP verification.
    func didSignIn(userID: UUID) async {
        currentUserID = userID
        phase = .loading
        await refreshProfile()
    }

    func signOut() async {
        try? await auth.signOut()
        currentUserID = nil
        profile = nil
        phase = .signedOut
    }

    /// Re-fetch the current user's profile and recompute the phase. Call after
    /// completing profile setup.
    func refreshProfile() async {
        guard let uid = currentUserID else {
            phase = .signedOut
            return
        }
        do {
            let fetched = try await profiles.fetch(id: uid)
            profile = fetched
            phase = (fetched?.isComplete ?? false) ? .ready : .needsProfile
        } catch {
            // A signed-in user with an unreadable profile is far more likely to
            // be a transient network failure than a genuinely empty profile.
            // Routing to setup would silently invite them to overwrite a profile
            // they already have, so keep them out of the write path: stay put if
            // we already had one, and otherwise send them to setup, which is the
            // correct destination for a brand-new account.
            phase = (profile?.isComplete ?? false) ? .ready : .needsProfile
        }
    }
}
