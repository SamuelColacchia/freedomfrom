import DeviceActivity
import FamilyControls
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

    /// Applies what a commitment named: a shield for its apps and categories,
    /// the filter for its web domains.
    ///
    /// Called at commit and again at every reconciliation that does not
    /// release, with whatever currently resolves — so a target that has churned
    /// is dropped from what is applied and the rest stays held (ADR 0005).
    ///
    /// The restrictions ride along because they are always on for a
    /// commitment's duration, with no per-commitment toggle: a toggle would be
    /// a lever the user's future weak self pulls at commit time (ADR 0001).
    /// There is no read-back of effective state, so nothing here is checked.
    static func apply(selection: FamilyActivitySelection?, domains: [FreedomFromKit.WebDomain]) {
        let store = store
        let applications = selection?.applicationTokens ?? []
        let categories = selection?.categoryTokens ?? []

        store.shield.applications = applications.isEmpty ? nil : applications
        // A category the *user* picked in the system picker is honoured;
        // silently ignoring it would be the app editing the user's list. The
        // out-of-scope feature is the app-provided adult-content auto-filter,
        // and `FilterPolicy.auto` is never used here or anywhere.
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)

        store.webContent.blockedByFilter =
            domains.isEmpty
            ? nil : .specific(Set(domains.map { ManagedSettings.WebDomain(domain: $0.host) }))

        store.application.denyAppRemoval = true
        store.dateAndTime.requireAutomaticDateAndTime = true
    }

    /// Lifts everything a commitment applied.
    ///
    /// The shield is what blocks; `DeviceActivity` only releases. So a schedule
    /// that never fires fails in the direction of the block staying up, and
    /// this is the only thing that takes it down (ADR 0004).
    static func releaseEverything() {
        // Before the store, because a mirror outliving its commitment would
        // have ShieldConfig draw a countdown for something already released.
        DeadlineMirror().remove()

        let store = store
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        // `nil` rather than the spec's `.none`: `blockedByFilter` is an
        // optional whose wrapped type also has a `none` case, so `.none` here
        // resolves to `Optional.none` regardless. Unset is what release means —
        // managed-with-no-filtering would leave the setting ours.
        store.webContent.blockedByFilter = nil
        store.application.denyAppRemoval = nil
        store.dateAndTime.requireAutomaticDateAndTime = nil
        DeviceActivityCenter().stopMonitoring([.commitment])
    }

    /// Registers the one window that should be watching, stopping whatever was.
    ///
    /// Every reconciliation recomputes the window from the same absolute
    /// deadline, so re-registering an unchanged commitment writes back the
    /// window it already had.
    static func register(_ window: MonitoringWindow) throws {
        let fields: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents(fields, from: window.start),
            intervalEnd: Calendar.current.dateComponents(fields, from: window.end),
            repeats: false
        )
        let center = DeviceActivityCenter()
        center.stopMonitoring([.commitment])
        try center.startMonitoring(.commitment, during: schedule)
    }
}
