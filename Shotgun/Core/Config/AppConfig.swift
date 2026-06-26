import Foundation

/// Strongly-typed access to build-time configuration that is injected into
/// `Info.plist` from `Config/Secrets.xcconfig`.
///
/// If these crash on launch, you forgot to fill in `Config/Secrets.xcconfig`
/// and run `make generate`.
enum AppConfig {
    static let supabaseURL: URL = {
        // Demo mode never hits the network, so a placeholder keeps the app
        // runnable without configured secrets.
        if DemoMode.isEnabled { return URL(string: "https://demo.invalid")! }
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: raw),
            url.host != nil
        else {
            fatalError("SUPABASE_URL missing or invalid. Set it in Config/Secrets.xcconfig and run `make generate`.")
        }
        return url
    }()

    static let supabaseAnonKey: String = {
        if DemoMode.isEnabled { return "demo-anon-key" }
        guard
            let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            !key.isEmpty,
            key != "YOUR-SUPABASE-ANON-KEY"
        else {
            fatalError("SUPABASE_ANON_KEY missing. Set it in Config/Secrets.xcconfig and run `make generate`.")
        }
        return key
    }()
}
