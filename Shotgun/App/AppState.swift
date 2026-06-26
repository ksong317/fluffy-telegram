import Foundation
import Observation

/// Root app state: owns the current user + profile and decides which top-level
/// flow to show. Injected into the environment and observed by `RootView`.
///
/// Sign-in (phone OTP + Sign in with Apple) has been removed; the app runs in
/// offline demo mode (`DemoMode`) and boots straight in as the demo user. To
/// reintroduce authentication, restore a session-driven service plus a
/// `.signedOut` phase that routes to a sign-in screen.
@MainActor
@Observable
final class AppState {
    enum Phase: Equatable {
        case loading        // booting
        case needsProfile   // signed in, profile incomplete — show setup
        case ready          // signed in with a complete profile — show main app
    }

    private(set) var phase: Phase = .loading
    private(set) var currentUserID: UUID?
    private(set) var profile: Profile?

    private let profiles = ProfileService()

    /// Boot the app. Call once from the app's root `.task`.
    func start() async {
        currentUserID = DemoData.me.id
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
}
