import CryptoKit
import Foundation

/// Nonce helpers for Sign in with Apple. The raw nonce is sent to Supabase; its
/// SHA256 is sent to Apple. This binds the identity token to our request.
enum AppleNonce {
    static func random(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in UInt8.random(in: 0...255) }
            for random in randoms where remaining > 0 {
                if random < charset.count * (255 / charset.count) {
                    result.append(charset[Int(random) % charset.count])
                    remaining -= 1
                }
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}
