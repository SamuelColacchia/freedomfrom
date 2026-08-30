import DeviceActivity
import Foundation
import FreedomFromKit
import FreedomFromPlatform
import ManagedSettings

// Compiled into all three signed targets. It exists because these names are the
// one thing the app and both extensions must agree on exactly: a store the app
// writes and an extension cannot find is indistinguishable from an extension
// that never woke.

extension ManagedSettingsStore.Name {
    /// One named store holds the shield, the filter, and the restrictions. The
    /// framework shares it between the app and its extensions with no App Group
    /// and no container of any kind (ADR 0002).
    ///
    /// Computed rather than stored: neither this type nor `DeviceActivityName`
    /// is `Sendable`, so a `static let` is global mutable state under Swift 6.
    /// Minting a fresh value per use costs a string and keeps the name in one
    /// place, which is the only thing being shared here.
    static var freedomfrom: Self { Self("freedomfrom") }
}

extension DeviceActivityName {
    /// Exactly one activity is registered at any moment, under this name, and
    /// re-registration stops it first so it is idempotent (ADR 0004).
    static var commitment: Self { Self("commitment") }
}

enum Enforcement {
    static var store: ManagedSettingsStore { ManagedSettingsStore(named: .freedomfrom) }

    /// Lifts everything a commitment applied.
    ///
    /// The shield is what blocks; `DeviceActivity` only releases. So a schedule
    /// that never fires fails in the direction of the block staying up, and
    /// this is the only thing that takes it down (ADR 0004).
    static func releaseEverything() {
        // Before the store, because a mirror outliving its commitment would
        // have ShieldConfig draw a countdown for something already released.
        DeadlineMirror().clear()

        let store = store
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.webContent.blockedByFilter = nil
        store.application.denyAppRemoval = nil
        store.dateAndTime.requireAutomaticDateAndTime = nil
        DeviceActivityCenter().stopMonitoring([.commitment])
    }

    /// The seven-day window to register next, or `nil` when the deadline has
    /// passed and the answer is a release rather than a registration.
    ///
    /// Placeholder for the walking skeleton: a commitment here is always short,
    /// so this is always the final window. The walk-forward step and its tests
    /// are work item 3 of the build spec.
    static func skeletonWindow(deadline: Date) -> MonitoringWindow? {
        guard deadline > Date() else { return nil }
        return MonitoringWindow(
            start: deadline,
            end: deadline.addingTimeInterval(7 * 24 * 60 * 60),
            kind: .final
        )
    }

    static func schedule(for window: MonitoringWindow) -> DeviceActivitySchedule {
        let fields: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        return DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents(fields, from: window.start),
            intervalEnd: Calendar.current.dateComponents(fields, from: window.end),
            repeats: false
        )
    }
}
