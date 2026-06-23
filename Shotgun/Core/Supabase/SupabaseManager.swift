import Foundation
import Supabase

/// Process-wide Supabase client. `SupabaseClient` is thread-safe (`Sendable`),
/// so a single shared instance is the intended usage.
enum SupabaseManager {
    static let client = SupabaseClient(
        supabaseURL: AppConfig.supabaseURL,
        supabaseKey: AppConfig.supabaseAnonKey
    )
}
