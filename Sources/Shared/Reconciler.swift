import DeviceActivity
import FamilyControls
import Foundation
import FreedomFromKit
import FreedomFromPlatform

/// One reconciliation, shared by the two processes that can read the record.
///
/// The app runs this on every launch and every foreground; `Monitor` runs it
/// whenever a window boundary wakes it. `ShieldConfig` is the third
/// reconciliation point and does not use this — it has no Keychain at all
/// (hardware check S1), so it reaches the deadline through the mirror and can
/// only release, never re-arm.
///
/// Everything it does compares now against the stored absolute deadline. A
/// commitment can end late, never early.
struct Reconciler: Sendable {
    enum State: Sendable {
        /// The record could not be read. Touch nothing, register nothing, exit
        /// (ADR 0005): blind re-registration cannot tell "before first unlock"
        /// from "the access group does not work at all".
        case unreadable
        case idle(Record)
        case released(Record)
        case running(Record, Coverage)
    }

    let log: Log
    private let store = KeychainRecordStore()

    init(log: Log) {
        self.log = log
    }

    /// The record, read and nothing else — no enforcement, no registration, and
    /// deliberately no log line.
    ///
    /// It exists for the one caller that must route a screen before it can
    /// afford the rest: a `SecItem` read is milliseconds, where applying the
    /// shield and registering a window are daemon round-trips. `run` does the
    /// authoritative read and logs it; this one must not, or every launch would
    /// report reading the record twice.
    func peek() -> Record? {
        try? store.read()
    }

    /// `brokenObserved` carries the one thing only a launch can see — an absent
    /// install marker — into the same read-modify-write as the reconciliation,
    /// rather than a second one that could interleave.
    ///
    /// It used to carry a revoked authorization too, read off
    /// `authorizationStatus` by the caller. That is gone: the framework has not
    /// loaded that value on a young process, so it marked a running commitment
    /// broken on every cold launch (#54). A revoke reaches the record through
    /// `reArm` now, from a registration the system refused.
    ///
    /// It is a flag rather than a closure so the mark and its log line stay
    /// here beside every other mark, and so this whole call can cross to a
    /// background thread without carrying the app's state with it.
    ///
    /// Discardable because the two callers want different things from it: the
    /// app renders the state it returns, and `Monitor` has nothing to render —
    /// it reconciles and exits, and the log line is its whole output.
    @discardableResult
    func run(now: Date = Date(), brokenObserved: Bool = false) -> State {
        let stored: Record?
        do {
            stored = try store.read()
            log.recordRead(found: stored != nil, hasActiveCommitment: stored?.active != nil)
        } catch {
            log.recordUnreadable(status: Self.osStatus(error))
            return .unreadable
        }

        let original = stored ?? .empty
        var record = original
        if brokenObserved, record.markBroken() { log.marked(.broken) }

        guard let active = record.active else {
            persist(record, ifChangedFrom: original)
            return .idle(record)
        }
        log.deadline(active.deadline)

        if Reconciliation.shouldRelease(deadline: active.deadline, now: now) {
            Enforcement.releaseEverything()
            log.storeMutation("release", landed: true)
            log.released(lateBy: Reconciliation.lateness(deadline: active.deadline, now: now))

            record.release(at: now)
            persist(record, ifChangedFrom: original)
            return .released(record)
        }

        let coverage = reArm(active, in: &record)
        persist(record, ifChangedFrom: original)
        return .running(record, coverage)
    }

    /// Recompute coverage, apply what resolves, mark degraded if anything does
    /// not, and re-register the window from wherever the deadline now sits.
    private func reArm(_ active: Commitment, in record: inout Record) -> Coverage {
        let selection = TargetHandles.decode(active.encodedSelection)
        let resolved = selection.map(TargetHandles.mint) ?? []
        let coverage = Reconciliation.coverage(named: active.namedHandles, resolved: resolved)
        log.coverage(coverage)

        if record.apply(coverage) { log.marked(.degraded) }

        Enforcement.apply(selection: selection, domains: active.domains)
        log.storeMutation("enforcement", landed: true)

        do {
            try DeadlineMirror().write(active.deadline)
            log.storeMutation("deadline mirror", landed: true)
        } catch {
            log.storeMutation("deadline mirror", landed: false)
        }

        if let window = Reconciliation.nextWindow(deadline: active.deadline, now: Date()) {
            // A window always exists while a commitment runs — `nextWindow`
            // returns nil only once the deadline has passed, and that path
            // released above — so this is asked on every reconciliation of a
            // live commitment, which is what makes it a usable signal.
            #if HARDWARE_PASS
                // Hardware check S2 asks whether `ShieldConfig` can mutate the
                // store when it is the process that discovers a passed deadline.
                // With the final window armed it never is: `Monitor` wakes on the
                // same boundary and released two seconds past it on the first
                // real run, before a person could open the target. Disarming that
                // one window leaves the extension as the only thing that can
                // release, which is the only way the gate is reachable at all.
                //
                // Walk windows stay, because they re-register rather than release.
                if window.kind == .final {
                    log.windowSuppressed("hardware-pass build, so S2 is not a race")
                    return coverage
                }
            #endif
            do {
                try Enforcement.register(window)
                log.windowRegistered(window)
            } catch {
                log.windowRegistrationFailed(String(describing: error))

                // The break signal, and the only one that is an act rather than
                // a cached reading. `DeviceActivity` refusing to start
                // monitoring *because* the app is not authorized is the system
                // behaving on a revoke, where `authorizationStatus` merely
                // reports a value it may not have loaded yet (#54, X1a).
                //
                // Matched on the case rather than on its description, because a
                // string that changes in an OS release would silently stop
                // marking breaks, and nothing would fail.
                let seen = BreakObservation(
                    reinstalled: false,
                    enforcementRefusedAsUnauthorized: Self.isUnauthorized(error)
                )
                if seen.isEvidenceOfABreak, record.markBroken() { log.marked(.broken) }
            }
        }
        return coverage
    }

    /// Whether `DeviceActivity` refused because authorization is gone, as
    /// opposed to any of the other ways registering a window can fail — too
    /// many activities, an unsatisfiable schedule — none of which say anything
    /// about a commitment being broken.
    private static func isUnauthorized(_ error: Error) -> Bool {
        guard let refusal = error as? DeviceActivityCenter.MonitoringError else { return false }
        if case .unauthorized = refusal { return true }
        return false
    }

    /// Reports whether the write landed, because one caller cannot continue
    /// without it: a commitment whose record did not persist would be a
    /// countdown over nothing after the next launch.
    @discardableResult
    func write(_ record: Record) -> Bool {
        do {
            try store.write(record)
            log.recordWritten()
            return true
        } catch {
            log.recordWriteFailed(status: Self.osStatus(error))
            return false
        }
    }

    private func persist(_ record: Record, ifChangedFrom original: Record) {
        guard record != original else { return }
        write(record)
    }

    static func osStatus(_ error: Error) -> Int32 {
        if case KeychainRecordStore.Failure.keychain(let status) = error { return status }
        return -1
    }
}
