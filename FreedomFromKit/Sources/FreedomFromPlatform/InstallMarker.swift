import Foundation

/// A file in the app's own sandbox, and therefore the one thing here that does
/// **not** survive the app being deleted.
///
/// That asymmetry is the whole point. The Keychain record outlives deletion, so
/// a launch that finds a commitment still running cannot tell a normal launch
/// from a reinstall — every launch finds one. This marker supplies the missing
/// half: record present, marker absent, therefore the app was deleted mid
/// commitment and the commitment is broken (ADR 0005).
///
/// It holds nothing. Its existence is the entire signal, which is why a read
/// failure and an absent file are deliberately the same answer: both mean "no
/// evidence this install placed it", and marking a break wrongly costs a row in
/// the history, where missing one costs the record its honesty.
public struct InstallMarker: Sendable {
    private let name: String

    public init(name: String = "install") {
        self.name = name
    }

    private var url: URL? {
        try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ).appendingPathComponent(name)
    }

    public var isPresent: Bool {
        guard let url else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Reports whether the marker is there afterwards, which is the only thing
    /// the caller can do anything with.
    ///
    /// It used to swallow both failures — an unresolvable directory and a
    /// failed write — and return nothing, so a marker that never persisted was
    /// indistinguishable from one that did. That is not a theoretical shape: an
    /// archive shows `marked broken` on a launch three seconds after one that
    /// had already called this, and nothing recorded which half went wrong.
    @discardableResult
    public func place() -> Bool {
        guard let url else { return false }
        if FileManager.default.fileExists(atPath: url.path) { return true }
        do {
            try Data().write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
