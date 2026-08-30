import FreedomFromKit
import Foundation
import os

/// The logging contract, expressed as an interface rather than as discipline.
///
/// A wordless app returns no other signal, so this is load-bearing rather than
/// debug scaffolding, and it is **permanent in release builds** (ADR 0009).
/// Two rules hold it up, and the reason there is no free-form `log(_:)` here is
/// that both would otherwise rest on every caller remembering them:
///
/// - **Structural facts are `%{public}`.** Default `os_log` redaction prints
///   `<private>` for every interpolated value, and a coverage count of 2-of-3
///   *is* the observation — a redacted line makes a hardware run unfalsifiable.
/// - **Target identities are never logged at all.** No bundle identifiers, no
///   tokens, no domain strings. Nothing on the hardware checklist needs to know
///   *which* app was shielded, only how many resolved.
public struct Log: Sendable {
    public static let subsystem = "com.samuelcolacchia.freedomfrom"

    /// One category per process, which is what keeps "the monitor never woke"
    /// distinguishable from "the monitor woke and found nothing".
    public enum Category: String, Sendable {
        case app
        case monitor
        case shieldconfig
    }

    private let logger: Logger

    public init(_ category: Category) {
        logger = Logger(subsystem: Self.subsystem, category: category.rawValue)
    }

    // MARK: - The record

    public func recordRead(found: Bool, hasActiveCommitment: Bool) {
        logger.info(
            "record read found=\(found, privacy: .public) active=\(hasActiveCommitment, privacy: .public)"
        )
    }

    public func recordUnreadable(status: Int32) {
        // An extension that cannot read the record touches nothing, registers
        // nothing, and exits (ADR 0005). This line is the only trace of that.
        logger.error("record unreadable status=\(status, privacy: .public)")
    }

    public func recordWritten() {
        logger.info("record written")
    }

    public func recordWriteFailed(status: Int32) {
        logger.error("record write failed status=\(status, privacy: .public)")
    }

    // MARK: - Enforcement

    /// Whether a `ManagedSettingsStore` mutation was attempted and returned.
    /// There is no read-back of effective state, so "landed" means the call
    /// completed, never that the setting governs the device (ADR 0005).
    public func storeMutation(_ what: String, landed: Bool) {
        logger.info("store mutation \(what, privacy: .public) landed=\(landed, privacy: .public)")
    }

    public func coverage(_ coverage: Coverage) {
        logger.info(
            "coverage resolved=\(coverage.resolved, privacy: .public) of named=\(coverage.named, privacy: .public)"
        )
    }

    public func deadline(_ deadline: Date) {
        logger.info("deadline \(Self.stamp(deadline), privacy: .public)")
    }

    public func marked(_ mark: Mark) {
        logger.notice("marked \(mark.rawValue, privacy: .public)")
    }

    public enum Mark: String, Sendable {
        case broken
        case degraded
    }

    // MARK: - The watchdog

    public func windowRegistered(_ window: MonitoringWindow) {
        logger.info(
            """
            window registered kind=\(window.kind.rawValue, privacy: .public) \
            start=\(Self.stamp(window.start), privacy: .public) \
            end=\(Self.stamp(window.end), privacy: .public)
            """
        )
    }

    public func windowRegistrationFailed(_ reason: String) {
        logger.error("window registration failed reason=\(reason, privacy: .public)")
    }

    /// A commitment can end late, never early. How late is the observation.
    public func released(lateBy seconds: TimeInterval) {
        logger.notice("released late_by_seconds=\(Int(seconds.rounded()), privacy: .public)")
    }

    // MARK: - Lifecycle

    public func woke(_ reason: String) {
        logger.info("woke reason=\(reason, privacy: .public)")
    }

    public func authorization(_ state: String) {
        logger.info("authorization state=\(state, privacy: .public)")
    }

    private static func stamp(_ date: Date) -> String {
        date.formatted(.iso8601)
    }
}
