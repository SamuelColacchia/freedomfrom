import DeviceActivity
import Foundation
import FreedomFromKit
import FreedomFromPlatform

/// Wakes at a window boundary and reconciles against the stored deadline.
///
/// It never trusts the callback to mean anything by itself. Apple documents
/// these as firing when the device is *next in use*, so the only authority is
/// the absolute deadline in the record (ADR 0002, ADR 0004).
class MonitorExtension: DeviceActivityMonitor {
    private let log = Log(.monitor)
    private let store = KeychainRecordStore()

    /// The release trigger. The final window *starts* at the deadline and runs
    /// a further seven days, so this fires on the first device use in the week
    /// after expiry rather than in a net a few minutes wide.
    override func intervalDidStart(for activity: DeviceActivityName) {
        log.woke("intervalDidStart")
        reconcile()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        log.woke("intervalDidEnd")
        reconcile()
    }

    private func reconcile() {
        let record: Record?
        do {
            record = try store.read()
            log.recordRead(found: record != nil, hasActiveCommitment: record?.active != nil)
        } catch {
            // An extension that cannot read the record touches nothing,
            // registers nothing, and exits (ADR 0005). Blind re-registration
            // cannot tell "before first unlock" from "the access group does not
            // work at all", so it would loop forever learning nothing.
            log.recordUnreadable(status: Self.osStatus(error))
            return
        }

        guard var record, let active = record.active else { return }
        log.deadline(active.deadline)

        guard Date() >= active.deadline else {
            // Nothing to do: the shield holds itself. Re-registering the walk
            // window is work item 6, once the walk-forward step exists.
            return
        }

        Enforcement.releaseEverything()
        log.storeMutation("release", landed: true)
        log.released(lateBy: Date().timeIntervalSince(active.deadline))

        record.active = nil
        record.endedScreenPending = true
        do {
            try store.write(record)
            log.recordWritten()
        } catch {
            log.recordWriteFailed(status: Self.osStatus(error))
        }
    }

    private static func osStatus(_ error: Error) -> Int32 {
        if case KeychainRecordStore.Failure.keychain(let status) = error { return status }
        return -1
    }
}
