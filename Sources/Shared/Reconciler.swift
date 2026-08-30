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
struct Reconciler {
    enum State {
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

    /// `marking` runs on the record between reading it and acting on it. That
    /// is where the app observes a break — a revoked authorization or a
    /// reinstall — so the mark lands in the same read-modify-write as the
    /// reconciliation rather than in a second one that could interleave.
    func run(now: Date = Date(), marking: (inout Record) -> Void = { _ in }) -> State {
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
        marking(&record)

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
            do {
                try Enforcement.register(window)
                log.windowRegistered(window)
            } catch {
                log.windowRegistrationFailed(String(describing: error))
            }
        }
        return coverage
    }

    func write(_ record: Record) {
        do {
            try store.write(record)
            log.recordWritten()
        } catch {
            log.recordWriteFailed(status: Self.osStatus(error))
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
