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
        /// The last running commitment went, and everything was lifted.
        case released(Record)
        /// At least one commitment still runs. Coverage is per commitment.
        case running(Record, [UUID: Coverage])
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

    /// `brokenObserved` carries what only the app can see into the same
    /// read-modify-write as the reconciliation, rather than a second one that
    /// could interleave. That is an absent install marker, or an approval its
    /// process had read and has now lost (`AuthorizationTrail`).
    ///
    /// It used to carry a single `authorizationStatus` reading. That is gone:
    /// the framework has not loaded that value on a young process, so it marked
    /// a running commitment broken on every cold launch (#54). A revoke reaches
    /// the record two ways now: as a loss the app watched happen, or through
    /// `reArm`, from a registration the system refused.
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
            log.recordRead(
                found: stored != nil, hasActiveCommitment: !(stored?.commitments.isEmpty ?? true))
        } catch {
            log.recordUnreadable(status: Self.osStatus(error))
            return .unreadable
        }

        let original = stored ?? .empty
        var record = original
        if brokenObserved, record.markBroken() { log.marked(.broken) }

        guard !record.commitments.isEmpty else {
            persist(record, ifChangedFrom: original)
            return .idle(record)
        }
        record.commitments.forEach { log.deadline($0.deadline) }

        for released in record.releaseDue(at: now) {
            log.released(lateBy: Reconciliation.lateness(deadline: released.deadline, now: now))
        }

        return settle(&record, from: original)
    }

    /// Ends one commitment early with the unlock code, in the same
    /// read-modify-write as the enforcement that follows, so the record and
    /// the store cannot disagree about which commitments run (ADR 0012).
    ///
    /// `nil` when the code is wrong or the commitment is already gone, and
    /// nothing has changed.
    func unlock(_ id: UUID, code: String) -> State? {
        let original: Record
        do {
            guard let stored = try store.read() else { return nil }
            original = stored
        } catch {
            log.recordUnreadable(status: Self.osStatus(error))
            return nil
        }

        var record = original
        guard record.unlock(id, code: code) else { return nil }
        log.unlocked()
        return settle(&record, from: original)
    }

    /// Lifts everything when nothing runs any more, or reapplies what still
    /// does, then persists.
    private func settle(_ record: inout Record, from original: Record) -> State {
        guard !record.commitments.isEmpty else {
            Enforcement.releaseEverything()
            log.storeMutation("release", landed: true)
            persist(record, ifChangedFrom: original)
            return .released(record)
        }

        let coverage = reArm(in: &record)
        persist(record, ifChangedFrom: original)
        return .running(record, coverage)
    }

    /// Recompute each commitment's coverage, apply the union of what resolves,
    /// mark degraded only the commitments that lost something, and register
    /// the window toward the nearest deadline.
    private func reArm(in record: inout Record) -> [UUID: Coverage] {
        var coverages: [UUID: Coverage] = [:]
        var selections: [FamilyActivitySelection] = []
        for commitment in record.commitments {
            let selection = TargetHandles.decode(commitment.encodedSelection)
            let resolved = selection.map(TargetHandles.mint) ?? []
            let coverage = Reconciliation.coverage(named: commitment.namedHandles, resolved: resolved)
            log.coverage(coverage)
            if record.apply(coverage, to: commitment.id) { log.marked(.degraded) }
            coverages[commitment.id] = coverage
            if let selection { selections.append(selection) }
        }

        // Before the store, and holding the *furthest* deadline: `ShieldConfig`
        // releases everything once the mirror has passed, so a mirror naming an
        // earlier commitment would lift a later one early. A mirror that cannot
        // be written is removed rather than left stale, for the same reason.
        do {
            try DeadlineMirror().write(record.latestDeadline ?? Date())
            log.storeMutation("deadline mirror", landed: true)
        } catch {
            DeadlineMirror().remove()
            log.storeMutation("deadline mirror", landed: false)
        }

        Enforcement.apply(selections: selections, domains: record.heldDomains)
        log.storeMutation("enforcement", landed: true)

        if let earliest = record.earliestDeadline,
            let window = Reconciliation.nextWindow(deadline: earliest, now: Date())
        {
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
                    return coverages
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
        return coverages
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
