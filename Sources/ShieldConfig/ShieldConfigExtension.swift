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
    private let store = KeychainRecordStore()

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        log.woke("shielding application")
        return shield(for: activeCommitment())
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        log.woke("shielding application in category")
        return shield(for: activeCommitment())
    }

    // MARK: - The record

    private func activeCommitment() -> Commitment? {
        do {
            let record = try store.read()
            log.recordRead(found: record != nil, hasActiveCommitment: record?.active != nil)
            guard var record, let active = record.active else { return nil }
            log.deadline(active.deadline)

            guard Date() >= active.deadline else { return active }

            // The deadline passed while nothing was watching. Release here
            // rather than wait for a launch: this is the moment of harm.
            Enforcement.releaseEverything()
            log.storeMutation("release", landed: true)
            log.released(lateBy: Date().timeIntervalSince(active.deadline))
            record.active = nil
            record.endedScreenPending = true
            try store.write(record)
            log.recordWritten()
            return nil
        } catch {
            log.recordUnreadable(status: Self.osStatus(error))
            return nil
        }
    }

    // MARK: - The shield

    /// A countdown in the dark: no app name, no explanation, no button, no
    /// scolding. A shield that explains itself is a shield that negotiates, and
    /// this is the screen seen most often (ADR 0003).
    private func shield(for commitment: Commitment?) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: .black,
            icon: nil,
            title: commitment.map {
                ShieldConfiguration.Label(
                    text: Self.remaining(until: $0.deadline),
                    color: .white
                )
            },
            subtitle: nil,
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

    private static func osStatus(_ error: Error) -> Int32 {
        if case KeychainRecordStore.Failure.keychain(let status) = error { return status }
        return -1
    }
}
