import Foundation
import FreedomFromKit

/// A derived copy of the running commitment's deadline, in a shared container,
/// for the one process that cannot reach the Keychain.
///
/// Hardware check S1 came back red for `ShieldConfig` alone: it carries the
/// same access-group entitlement as the app and the Monitor, and both `SecItem`
/// reads and writes return `errSecNotAvailable` (-25291). The Keychain is
/// unavailable to that sandbox entirely, so the shield could not learn the
/// deadline and had no countdown to draw.
///
/// **This is never authoritative.** The Keychain record is (ADR 0002), and it
/// stays the only thing that survives app deletion, which is what makes a
/// delete-break detectable. The mirror is written at commit, removed at
/// release, and treated as a cache that may be absent or stale — a stale one
/// costs a wrong number on a shield, never a wrong release.
///
/// A file rather than `UserDefaults`: ADR 0002 rejected an App Group mirror
/// because `UserDefaults` propagation is asynchronous and `synchronize()` is a
/// no-op, which makes a mirror a drift generator. An atomic file write does not
/// have that property, and a deadline has exactly one writer and is immutable
/// for the life of the commitment.
public struct DeadlineMirror: Sendable {
    public static let groupIdentifier = "group.com.samuelcolacchia.freedomfrom"

    public enum Failure: Error, Equatable {
        case noContainer
    }

    private let group: String

    public init(group: String = DeadlineMirror.groupIdentifier) {
        self.group = group
    }

    private var url: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: group)?
            .appendingPathComponent("deadline")
    }

    public func write(_ deadline: Date) throws {
        guard let url else { throw Failure.noContainer }
        let seconds = String(deadline.timeIntervalSince1970)
        try Data(seconds.utf8).write(to: url, options: .atomic)
    }

    public func read() -> Date? {
        guard let url,
            let data = try? Data(contentsOf: url),
            let seconds = TimeInterval(String(decoding: data, as: UTF8.self))
        else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    public func clear() {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Whether the container exists at all, which separates "no commitment is
    /// running" from "this process cannot see the shared container".
    public var containerIsReachable: Bool { url != nil }
}
