import Foundation
import Observation

@MainActor
@Observable
final class ProfileSetupViewModel {
    var displayName = ""
    var venmoHandle = ""
    var errorMessage: String?

    private let profiles = ProfileService()

    var canSave: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Pre-fill from any existing (stub) profile.
    func load(from profile: Profile?) {
        guard let profile else { return }
        displayName = profile.displayName
        venmoHandle = profile.venmoHandle ?? ""
    }

    /// Save the profile. Returns true on success so the caller can refresh routing.
    func save(userID: UUID) async -> Bool {
        errorMessage = nil
        let trimmedVenmo = venmoHandle.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = ProfileUpsert(
            id: userID,
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            venmoHandle: trimmedVenmo.isEmpty ? nil : trimmedVenmo,
            photoURL: nil // TODO: wire up photo upload to the `avatars` bucket
        )
        do {
            try await profiles.upsert(payload)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
