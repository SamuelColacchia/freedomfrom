import CryptoKit
import Foundation

/// The one code that ends a single running commitment before its deadline
/// (ADR 0012).
///
/// Global rather than per commitment: whoever holds it can unlock any of them,
/// one at a time. It is stored as a salted SHA-256 digest and never as the
/// code, so the record never carries something that reads back as the code.
///
/// CryptoKit is the kit's one import beyond Foundation. ADR 0009 keeps Screen
/// Time types out because they are unavailable on macOS; CryptoKit is not, so
/// the headless test loop is unaffected.
public struct UnlockCode: Equatable, Codable, Sendable {
    /// Shorter than this is refused at the boundary where a code is typed.
    public static let minimumLength = 4

    public let salt: Data
    public let digest: Data

    public init(salt: Data, digest: Data) {
        self.salt = salt
        self.digest = digest
    }

    /// Hashes a typed code under a fresh random salt. `nil` when it is too
    /// short to be a code at all.
    public static func make(_ code: String) -> UnlockCode? {
        guard code.count >= minimumLength else { return nil }
        let salt = Data(SymmetricKey(size: .bits128).withUnsafeBytes { Array($0) })
        return UnlockCode(salt: salt, digest: hash(code, salt: salt))
    }

    /// Whether a typed code is this one. The comparison does not stop at the
    /// first differing byte.
    public func matches(_ code: String) -> Bool {
        let candidate = Self.hash(code, salt: salt)
        guard candidate.count == digest.count else { return false }
        return zip(candidate, digest).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
    }

    private static func hash(_ code: String, salt: Data) -> Data {
        Data(SHA256.hash(data: salt + Data(code.utf8)))
    }
}
