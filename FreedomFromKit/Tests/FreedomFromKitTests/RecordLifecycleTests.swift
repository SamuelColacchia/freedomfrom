import Foundation
import Testing

@testable import FreedomFromKit

private let epoch = Date(timeIntervalSince1970: 1_800_000_000)

private func commitment(
    deadline: Date = epoch.addingTimeInterval(86_400),
    handles: [TargetHandle] = [TargetHandle("a")],
    domains: [WebDomain] = [],
    isDegraded: Bool = false,
    isBroken: Bool = false
) -> Commitment {
    Commitment(
        startedAt: epoch,
        deadline: deadline,
        encodedSelection: nil,
        namedHandles: handles,
        domains: domains,
        isDegraded: isDegraded,
        isBroken: isBroken
    )
}

@Suite("The draft is yours, and only you and a clean slate edit it")
struct DraftTests {
    private let draft = Draft(
        domains: [WebDomain.canonicalize("example.com")!],
        length: .preset(.sevenDays)
    )

    @Test("committing consumes nothing")
    func commitConsumesNothing() {
        var record = Record(draft: draft)
        record.begin(commitment())
        #expect(record.draft == draft)
    }

    @Test("it survives between commitments")
    func survivesBetweenCommitments() {
        var record = Record(draft: draft)
        record.begin(commitment())
        record.release(at: epoch.addingTimeInterval(86_400))

        #expect(record.active == nil)
        #expect(record.draft == draft)
    }

    @Test("an edit abandoned before the hold survives, because nothing prunes it")
    func abandonedEditSurvives() {
        var record = Record(draft: draft)
        record.draft.domains = WebDomain.add("later.com", to: record.draft.domains)

        // Nothing between here and the next launch touches it: no commit, no
        // release, and no reconciliation reaches the draft.
        record.begin(commitment())
        record.apply(Coverage(resolved: 0, named: 1))
        record.release(at: epoch.addingTimeInterval(86_400))

        #expect(record.draft.domains.map(\.host) == ["example.com", "later.com"])
    }

    @Test("a clean slate takes the draft and the history and leaves first run alone")
    func cleanSlate() {
        var record = Record(draft: draft, hasSeenFirstRun: true)
        record.begin(commitment())
        record.release(at: epoch.addingTimeInterval(86_400))

        record.cleanSlate()

        #expect(record.draft == .empty)
        #expect(record.history.isEmpty)
        #expect(record.hasSeenFirstRun)
    }
}

@Suite("A commitment closes into one of three words")
struct OutcomeTests {
    @Test("clean gives completed")
    func completed() {
        #expect(Outcome(isBroken: false, isDegraded: false) == .completed)
    }

    @Test("degraded gives completed-degraded")
    func degraded() {
        #expect(Outcome(isBroken: false, isDegraded: true) == .completedDegraded)
    }

    @Test("broken wins over degraded")
    func brokenWins() {
        #expect(Outcome(isBroken: true, isDegraded: false) == .broken)
        #expect(Outcome(isBroken: true, isDegraded: true) == .broken)
    }

    @Test("an unwitnessed commitment reads completed")
    func unwitnessed() {
        // Nothing ran to observe it, so the app holds no evidence otherwise and
        // must not invent any (ADR 0005).
        var record = Record()
        record.begin(commitment())
        record.release(at: epoch.addingTimeInterval(365 * 86_400))

        #expect(record.history.first?.outcome == .completed)
    }

    @Test("the closed row carries a count for apps and words for domains")
    func closedRowShape() throws {
        var record = Record()
        let domains = [WebDomain.canonicalize("example.com")!]
        record.begin(
            commitment(handles: [TargetHandle("a"), TargetHandle("b")], domains: domains))
        record.release(at: epoch.addingTimeInterval(86_400))

        let row = try #require(record.history.first)
        #expect(row.namedTargetCount == 2)
        #expect(row.domains == domains)
        #expect(row.startedAt == epoch)
        #expect(row.deadline == epoch.addingTimeInterval(86_400))
    }

    @Test("a release leaves the Ended screen pending")
    func endedIsPending() {
        var record = Record()
        record.begin(commitment())
        record.release(at: epoch.addingTimeInterval(86_400))
        #expect(record.endedScreenPending)
    }
}

@Suite("A break marks a running commitment; it does not end one")
struct BreakTests {
    @Test("it is recorded once, and never re-marked")
    func recordedOnce() {
        var record = Record()
        record.begin(commitment())

        let first = record.markBroken()
        let second = record.markBroken()

        #expect(first)
        #expect(second == false)
        #expect(record.active?.isBroken == true)
    }

    @Test("it does not shorten the deadline")
    func deadlineStands() {
        var record = Record()
        record.begin(commitment())
        record.markBroken()

        #expect(record.active?.deadline == epoch.addingTimeInterval(86_400))
        #expect(record.active != nil)
    }

    @Test("a broken commitment files as broken")
    func filesAsBroken() {
        var record = Record()
        record.begin(commitment())
        record.markBroken()
        record.release(at: epoch.addingTimeInterval(86_400))

        #expect(record.history.first?.outcome == .broken)
    }

    @Test("with nothing running there is nothing to mark")
    func nothingRunning() {
        var record = Record()
        let marked = record.markBroken()
        #expect(marked == false)
    }
}

@Suite("A lost target degrades coverage, never duration")
struct DegradationTests {
    @Test("full coverage leaves no mark")
    func fullCoverageIsClean() {
        var record = Record()
        record.begin(commitment(handles: [TargetHandle("a"), TargetHandle("b")]))

        let degraded = record.apply(Coverage(resolved: 2, named: 2))

        #expect(degraded == false)
        #expect(record.active?.isDegraded == false)
    }

    @Test("a missing handle marks degraded and leaves the deadline alone")
    func lostHandleDegrades() {
        var record = Record()
        record.begin(commitment(handles: [TargetHandle("a"), TargetHandle("b")]))

        let degraded = record.apply(Coverage(resolved: 1, named: 2))

        #expect(degraded)
        #expect(record.active?.isDegraded == true)
        #expect(record.active?.deadline == epoch.addingTimeInterval(86_400))
    }

    @Test("the mark is recorded once")
    func markedOnce() {
        var record = Record()
        record.begin(commitment(handles: [TargetHandle("a"), TargetHandle("b")]))

        let first = record.apply(Coverage(resolved: 1, named: 2))
        let second = record.apply(Coverage(resolved: 1, named: 2))

        #expect(first)
        #expect(second == false)
    }

    @Test("a degraded commitment whose handles all resolve again stays degraded")
    func degradedNeverClears() {
        var record = Record()
        record.begin(commitment(handles: [TargetHandle("a"), TargetHandle("b")]))
        record.apply(Coverage(resolved: 1, named: 2))

        record.apply(Coverage(resolved: 2, named: 2))

        #expect(record.active?.isDegraded == true)
    }

    @Test("a web-only commitment has full coverage and can never degrade")
    func webOnlyNeverDegrades() {
        var record = Record()
        record.begin(
            commitment(handles: [], domains: [WebDomain.canonicalize("example.com")!]))

        let degraded = record.apply(Coverage(resolved: 0, named: 0))

        #expect(degraded == false)
        #expect(record.active?.isDegraded == false)
    }

    @Test("degraded and broken can both be true, and the row reads broken")
    func bothMarks() {
        var record = Record()
        record.begin(commitment(handles: [TargetHandle("a"), TargetHandle("b")]))
        record.apply(Coverage(resolved: 1, named: 2))
        record.markBroken()
        record.release(at: epoch.addingTimeInterval(86_400))

        #expect(record.history.first?.outcome == .broken)
    }
}
