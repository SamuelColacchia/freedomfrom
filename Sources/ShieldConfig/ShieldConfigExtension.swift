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
/// someone opens a target, this process is already running and checks. It is
/// also the only process that can recognise freedomfrom's own token, because
/// `localizedDisplayName` and `bundleIdentifier` are documented as nil outside
/// a shield-configuration extension (ADR 0005).
class ShieldConfigExtension: ShieldConfigurationDataSource {
    private let log = Log(.shieldconfig)

    /// The app's own bundle identifier, written out rather than derived: this
    /// process is `…freedomfrom.shieldconfig`, so `Bundle.main` here names the
    /// extension and not the thing that must not shield itself.
    private static let ownBundleIdentifier = "com.samuelcolacchia.freedomfrom"

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        log.woke("shielding application")
        dropSelfShield(application)
        return shield()
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        log.woke("shielding application in category")
        dropSelfShield(application)
        return shield()
    }

    // MARK: - The self-shield

    /// One mis-tap in the picker must not lock someone out of their own
    /// countdown for a year. The host app cannot do this — it cannot reliably
    /// tell which token is itself — so it happens here, the first time the
    /// shielded app is opened, and the shield is not drawn again.
    private func dropSelfShield(_ application: Application) {
        guard application.bundleIdentifier == Self.ownBundleIdentifier,
            let token = application.token
        else { return }

        let store = Enforcement.store
        store.shield.applications = (store.shield.applications ?? []).subtracting([token])
        log.storeMutation("self-shield dropped", landed: true)
    }

    // MARK: - The deadline

    /// Reads the mirror, not the Keychain.
    ///
    /// Hardware check S1 came back red for this process alone: `SecItem`
    /// returns `errSecNotAvailable` for both reads and writes here, under the
    /// same access-group entitlement the app and the Monitor use successfully.
    /// So the deadline arrives through the shared container instead.
    ///
    /// The consequence worth knowing: a release taken here clears enforcement
    /// and the mirror, but it cannot close the commitment in the Keychain
    /// record. The app on next launch and the Monitor at its next wake both
    /// reconcile that against the same absolute deadline, so the record closes
    /// late rather than wrongly.
    private func remaining() -> String? {
        let mirror = DeadlineMirror()
        guard mirror.containerIsReachable else {
            log.recordUnreadable(status: -1)
            return nil
        }
        guard let deadline = mirror.read() else {
            log.recordRead(found: false, hasActiveCommitment: false)
            return nil
        }

        log.recordRead(found: true, hasActiveCommitment: true)
        log.deadline(deadline)

        let now = Date()
        guard !Reconciliation.shouldRelease(deadline: deadline, now: now) else {
            // The deadline passed while nothing was watching. Release here
            // rather than wait for a launch: this is the moment of harm.
            Enforcement.releaseEverything()
            log.storeMutation("release", landed: true)
            log.released(lateBy: Reconciliation.lateness(deadline: deadline, now: now))
            return nil
        }

        return Countdown.coarse(until: deadline, from: now)
    }

    // MARK: - The shield

    /// A countdown in the dark: no app name, no explanation, no button, no
    /// scolding. A shield that explains itself is a shield that negotiates, and
    /// this is the screen seen most often (ADR 0003).
    ///
    /// Both labels are always set, never left nil. iOS substitutes its own copy
    /// for every field left nil, which would make a shield that failed to read
    /// the deadline and one that never ran the same screen. Without a deadline
    /// this falls back to a dark shield carrying the app's name and no
    /// countdown (ADR 0005).
    private func shield() -> ShieldConfiguration {
        let countdown = remaining()

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: .black,
            icon: nil,
            title: ShieldConfiguration.Label(text: countdown ?? "freedomfrom", color: .white),
            subtitle: ShieldConfiguration.Label(
                text: countdown == nil ? "" : "freedomfrom", color: .gray),
            primaryButtonLabel: nil,
            secondaryButtonLabel: nil
        )
    }
}
