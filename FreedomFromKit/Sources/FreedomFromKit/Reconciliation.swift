import Foundation

/// What each of the three reconciliation points runs.
///
/// The app on every launch and foreground, `Monitor` at a window boundary, and
/// `ShieldConfig` every time a shielded target is opened all do the same four
/// things: compare now against the stored absolute deadline, work out how late
/// a release is, recompute coverage, and re-register the window from wherever
/// the deadline now sits (ADR 0004). Gathering them here is what keeps the
/// three from drifting apart.
public enum Reconciliation {
    public static let window: TimeInterval = 7 * 86_400

    /// The deadline is authoritative and nothing shortens it, so this is the
    /// entire release condition.
    public static func shouldRelease(deadline: Date, now: Date) -> Bool {
        now >= deadline
    }

    /// How late a release is, measured from the deadline rather than from
    /// whatever woke us — the final window runs a week past the deadline, so
    /// the two are not the same number.
    public static func lateness(deadline: Date, now: Date) -> TimeInterval {
        max(0, now.timeIntervalSince(deadline))
    }

    /// The one window to register next, or `nil` when the deadline has passed
    /// and the answer is a release rather than a registration.
    ///
    /// Every window is exactly seven days long, and the final one *starts* at
    /// the deadline: `intervalDidStart` fires on first device use inside the
    /// interval, so a window that started earlier and ended at the deadline
    /// would be a net only as wide as its final minutes (ADR 0004).
    public static func nextWindow(deadline: Date, now: Date) -> MonitoringWindow? {
        guard !shouldRelease(deadline: deadline, now: now) else { return nil }

        if deadline.timeIntervalSince(now) > window {
            return MonitoringWindow(start: now, end: now.addingTimeInterval(window), kind: .walk)
        }
        return MonitoringWindow(
            start: deadline, end: deadline.addingTimeInterval(window), kind: .final)
    }

    /// Set intersection over handles. A handle that resolves but was never
    /// named cannot inflate coverage, and a named one that no longer resolves
    /// shrinks it — which is the only signal that anything has churned.
    public static func coverage(named: [TargetHandle], resolved: [TargetHandle]) -> Coverage {
        let live = Set(resolved)
        return Coverage(
            resolved: Set(named).intersection(live).count,
            named: Set(named).count
        )
    }
}
