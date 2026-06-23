import SwiftUI

/// Top-level router. Swaps flows based on `AppState.phase`.
struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        switch appState.phase {
        case .loading:
            ProgressView("Loading…")
        case .signedOut:
            AuthView()
        case .needsProfile:
            ProfileSetupView()
        case .ready:
            MainTabView()
        }
    }
}
