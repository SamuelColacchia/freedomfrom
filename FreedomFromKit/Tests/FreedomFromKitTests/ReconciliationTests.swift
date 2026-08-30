import Foundation
import Testing

@testable import FreedomFromKit

/// Three things reconcile, and each compares now against the stored absolute
/// deadline (ADR 0004). This is what all three of them run.
@Suite("A commitment ends late, never early")
struct ReleaseTests {
    private let deadline = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("it holds before the deadline")
    func holdsBefore() {
        #expect(Reconciliation.shouldRelease(deadline: deadline, now: deadline - 1) == false)
        #expect(Reconciliation.shouldRelease(deadline: deadline, now: deadline - 86_400) == false)
    }

    @Test("it releases at the deadline")
    func releasesAt() {
        #expect(Reconciliation.shouldRelease(deadline: deadline, now: deadline))
    }

    @Test("a deadline already past releases at the next launch")
    func releasesLate() {
        #expect(Reconciliation.shouldRelease(deadline: deadline, now: deadline + 30 * 86_400))
    }

    @Test("lateness is measured from the deadline, not from the window that woke us")
    func latenessFromTheDeadline() {
        // The final window starts at the deadline and runs a week, so whatever
        // woke us can be up to seven days after the thing we are late against.
        let woken = deadline + 6 * 86_400
        #expect(Reconciliation.lateness(deadline: deadline, now: woken) == 6 * 86_400)
    }

    @Test("a release that is not late reports no lateness rather than a negative one")
    func neverNegative() {
        #expect(Reconciliation.lateness(deadline: deadline, now: deadline) == 0)
        #expect(Reconciliation.lateness(deadline: deadline, now: deadline - 60) == 0)
    }
}

@Suite("The walk-forward step registers one seven-day window at a time")
struct NextWindowTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let week: TimeInterval = 7 * 86_400

    @Test("a deadline more than seven days out yields a walk window of seven days from now")
    func walkWindow() throws {
        let deadline = now.addingTimeInterval(30 * 86_400)
        let window = try #require(Reconciliation.nextWindow(deadline: deadline, now: now))

        #expect(window.kind == .walk)
        #expect(window.start == now)
        #expect(window.end == now.addingTimeInterval(week))
    }

    @Test("a deadline seven days or less out yields the final window, starting at the deadline")
    func finalWindow() throws {
        let deadline = now.addingTimeInterval(3 * 86_400)
        let window = try #require(Reconciliation.nextWindow(deadline: deadline, now: now))

        // Starting *at* the deadline is the whole point: intervalDidStart fires
        // on first device use inside the interval, so this is a week-wide net
        // for the release rather than one as wide as its final minutes.
        #expect(window.kind == .final)
        #expect(window.start == deadline)
        #expect(window.end == deadline.addingTimeInterval(week))
    }

    @Test("exactly seven days out is already the final window")
    func theBoundaryIsFinal() throws {
        let deadline = now.addingTimeInterval(week)
        let window = try #require(Reconciliation.nextWindow(deadline: deadline, now: now))

        #expect(window.kind == .final)
        #expect(window.start == deadline)
    }

    @Test("a passed deadline yields nothing, because the answer is a release")
    func passedDeadline() {
        #expect(Reconciliation.nextWindow(deadline: now, now: now) == nil)
        #expect(Reconciliation.nextWindow(deadline: now, now: now.addingTimeInterval(1)) == nil)
    }

    @Test("no window is ever longer or shorter than seven days")
    func everyWindowIsAWeek() {
        let offsets: [TimeInterval] = [
            60, 3_600, 86_400, week - 1, week, week + 1, 30 * 86_400, 365 * 86_400,
        ]

        for offset in offsets {
            let window = Reconciliation.nextWindow(
                deadline: now.addingTimeInterval(offset), now: now)
            #expect(window?.end.timeIntervalSince(window!.start) == week)
        }
    }

    @Test("re-registering with the same inputs yields the same window")
    func idempotent() {
        let deadline = now.addingTimeInterval(30 * 86_400)
        #expect(
            Reconciliation.nextWindow(deadline: deadline, now: now)
                == Reconciliation.nextWindow(deadline: deadline, now: now))
    }
}

@Suite("Coverage is the targets reached, against the targets named")
struct CoverageTests {
    private let a = TargetHandle("a")
    private let b = TargetHandle("b")
    private let c = TargetHandle("c")

    @Test("every handle resolving is full coverage")
    func fullCoverage() {
        let coverage = Reconciliation.coverage(named: [a, b, c], resolved: [a, b, c])
        #expect(coverage == Coverage(resolved: 3, named: 3))
        #expect(coverage.isComplete)
    }

    @Test("a handle that no longer resolves shrinks coverage")
    func lostHandle() {
        let coverage = Reconciliation.coverage(named: [a, b, c], resolved: [a, c])
        #expect(coverage == Coverage(resolved: 2, named: 3))
        #expect(coverage.isComplete == false)
    }

    @Test("a handle that resolves but was never named does not inflate coverage")
    func strangerHandle() {
        // Set intersection, not a count: the picker can come back holding
        // something the commitment never named.
        let coverage = Reconciliation.coverage(named: [a, b], resolved: [a, b, c])
        #expect(coverage == Coverage(resolved: 2, named: 2))
    }

    @Test("a commitment with only web domains has full coverage and can never lose it")
    func webOnly() {
        let coverage = Reconciliation.coverage(named: [], resolved: [])
        #expect(coverage == Coverage(resolved: 0, named: 0))
        #expect(coverage.isComplete)
    }
}
