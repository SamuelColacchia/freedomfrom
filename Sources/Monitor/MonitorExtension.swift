import DeviceActivity
import Foundation
import FreedomFromKit
import FreedomFromPlatform

/// Wakes at a window boundary and reconciles against the stored deadline.
///
/// It never trusts the callback to mean anything by itself. Apple documents
/// these as firing when the device is *next in use*, so the only authority is
/// the absolute deadline in the record (ADR 0002, ADR 0004). Everything it does
/// is the same reconciliation the app runs at launch — including re-registering
/// the next window, which is what walks a year-long commitment forward a week
/// at a time.
class MonitorExtension: DeviceActivityMonitor {
    private let reconciler = Reconciler(log: Log(.monitor))

    /// The release trigger. The final window *starts* at the deadline and runs
    /// a further seven days, so this fires on the first device use in the week
    /// after expiry rather than in a net a few minutes wide.
    override func intervalDidStart(for activity: DeviceActivityName) {
        reconciler.log.woke("intervalDidStart")
        reconciler.run()
    }

    /// A walk window ending is the wake that re-registers the next one.
    override func intervalDidEnd(for activity: DeviceActivityName) {
        reconciler.log.woke("intervalDidEnd")
        reconciler.run()
    }
}
