import Foundation
import FreedomFromKit
import FreedomFromPlatform
import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Draws the countdown in the dark, and is load-bearing twice over.
///
/// It is the reconciliation point that fires at the moment of harm (ADR 0004):
/// a stale shield nobody touches has cost nobody anything, but the instant
/// someone opens a target, this process is already running with the same
/// keychain access group, so it checks. It is also the only process that can
/// recognise freedomfrom's own token, because `localizedDisplayName` is
/// documented as nil outside a shield-configuration extension (ADR 0005).
///
/// Whether it can mutate a `ManagedSettingsStore` inside its memory budget is
/// hardware check S2, and it is unverified. If it comes back red, ADR 0004's
/// third reconciliation point and ADR 0005's self-shield fix fall together.
class ShieldConfigExtension: ShieldConfigurationDataSource {
    private let log = Log(.shieldconfig)

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        log.woke("shielding application")
        return shield(for: state())
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        log.woke("shielding application in category")
        return shield(for: state())
    }

    /// What this process managed to find out, which the shield then states.
    ///
    /// The shield is the one surface this extension draws itself, so it can
    /// report its own condition without the circularity ADR 0009 rejected for
    /// app-mediated evidence: no shared channel is involved, and a failure to
    /// read the record cannot therefore be silent. Skeleton-only. v1's shield
    /// is a countdown and nothing else (ADR 0003).
    enum State {
        case running(Date)
        case noDeadline
        case noContainer
        case released
    }

    // MARK: - The deadline

    /// Reads the mirror, not the Keychain.
    ///
    /// S1 came back red for this process alone: `SecItem` returns
    /// `errSecNotAvailable` for both reads and writes here, under the same
    /// access-group entitlement the app and the Monitor use successfully. So
    /// the deadline arrives through the shared container instead.
    ///
    /// The consequence worth knowing: a release taken here clears enforcement
    /// and the mirror, but it cannot close the commitment in the Keychain
    /// record. The app on next launch and the Monitor at its next wake both
    /// reconcile that, and both compare against the same absolute deadline, so
    /// the record closes late rather than wrongly.
    private func state() -> State {
        let mirror = DeadlineMirror()
        guard mirror.containerIsReachable else {
            log.recordUnreadable(status: -1)
            return .noContainer
        }
        guard let deadline = mirror.read() else {
            log.recordRead(found: false, hasActiveCommitment: false)
            return .noDeadline
        }

        log.recordRead(found: true, hasActiveCommitment: true)
        log.deadline(deadline)
        guard Date() >= deadline else { return .running(deadline) }

        // The deadline passed while nothing was watching. Release here rather
        // than wait for a launch: this is the moment of harm.
        Enforcement.releaseEverything()
        log.storeMutation("release", landed: true)
        log.released(lateBy: Date().timeIntervalSince(deadline))
        return .released
    }

    // MARK: - The shield

    /// A countdown in the dark: no app name, no explanation, no button, no
    /// scolding. A shield that explains itself is a shield that negotiates, and
    /// this is the screen seen most often (ADR 0003).
    private func shield(for state: State) -> ShieldConfiguration {
        // A nil title is not blank: iOS substitutes its own copy for every
        // field left nil, which is why a failed read and an extension that
        // never ran look identical on screen. Every case here is stated.
        let text: String
        switch state {
        case .running(let deadline): text = Self.remaining(until: deadline)
        case .noDeadline: text = "no deadline"
        case .noContainer: text = "no container"
        case .released: text = "released"
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: .black,
            icon: nil,
            title: ShieldConfiguration.Label(text: text, color: .white),
            subtitle: ShieldConfiguration.Label(text: "freedomfrom", color: .gray),
            primaryButtonLabel: nil,
            secondaryButtonLabel: nil
        )
    }

    /// Coarse on purpose. A shield that ticks by the second is something to
    /// watch, and this one is meant to be closed.
    static func remaining(until deadline: Date) -> String {
        let seconds = Int(max(0, deadline.timeIntervalSinceNow))
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60

        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
