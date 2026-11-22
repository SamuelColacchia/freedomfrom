import Foundation
import Testing

@testable import FreedomFromKit

private let epoch = Date(timeIntervalSince1970: 1_800_000_000)

private func commitment(
    hours: Double,
    handles: [TargetHandle] = [TargetHandle("a")],
    domains: [String] = []
) -> Commitment {
    Commitment(
        startedAt: epoch,
        deadline: epoch.addingTimeInterval(hours * 3_600),
        encodedSelection: nil,
        namedHandles: handles,
        domains: domains.compactMap(WebDomain.canonicalize)
    )
}

@Suite("Commitments run side by side and end apart")
struct ConcurrentCommitmentsTests {
    @Test("a release takes only the commitments whose deadline has passed")
    func releaseTakesOnlyTheDue() {
        let short = commitment(hours: 1)
        let long = commitment(hours: 5)
        var record = Record()
        record.begin(short)
        record.begin(long)

        let released = record.releaseDue(at: epoch.addingTimeInterval(2 * 3_600))

        #expect(released.map(\.id) == [short.id])
        #expect(record.commitments.map(\.id) == [long.id])
        #expect(record.history.count == 1)
        #expect(record.endedScreenPending)
    }

    @Test("nothing due releases nothing and leaves Ended alone")
    func nothingDue() {
        var record = Record()
        record.begin(commitment(hours: 1))

        let released = record.releaseDue(at: epoch)

        #expect(released.isEmpty)
        #expect(record.endedScreenPending == false)
    }

    @Test("the watchdog walks toward the nearest deadline, the shield waits for the furthest")
    func earliestAndLatest() {
        var record = Record()
        record.begin(commitment(hours: 5))
        record.begin(commitment(hours: 1))

        #expect(record.earliestDeadline == epoch.addingTimeInterval(3_600))
        #expect(record.latestDeadline == epoch.addingTimeInterval(5 * 3_600))
    }

    @Test("a break reaches every running commitment, once")
    func breakReachesAll() {
        var record = Record()
        record.begin(commitment(hours: 1))
        record.begin(commitment(hours: 2))

        let result1 = record.markBroken()

        #expect(result1)
        let result2 = record.markBroken()
        #expect(result2 == false)
        #expect(record.commitments.allSatisfy { $0.isBroken })
    }

    @Test("a lost target degrades only the commitment it was measured on")
    func degradeIsPerCommitment() {
        let a = commitment(hours: 1, handles: [TargetHandle("x"), TargetHandle("y")])
        let b = commitment(hours: 2)
        var record = Record()
        record.begin(a)
        record.begin(b)

        let result3 = record.apply(Coverage(resolved: 1, named: 2), to: a.id)

        #expect(result3)

        #expect(record.commitments.first { $0.id == a.id }?.isDegraded == true)
        #expect(record.commitments.first { $0.id == b.id }?.isDegraded == false)
    }

    @Test("a domain named by two commitments counts once against the budget")
    func budgetCountsUniqueDomains() {
        var record = Record()
        let fortyNine = (1...49).map { "site\($0).example.com" }
        record.begin(commitment(hours: 1, domains: fortyNine))
        record.begin(commitment(hours: 2, domains: ["site1.example.com"]))

        #expect(record.heldDomains.count == 49)
        #expect(record.exceedsDomainBudget(adding: WebDomain.canonicalize("site2.example.com").map { [$0] } ?? []) == false)
        #expect(record.exceedsDomainBudget(adding: (50...51).compactMap { WebDomain.canonicalize("site\($0).example.com") }))
    }
}

@Suite("One code unlocks one commitment early")
struct UnlockTests {
    private func running(_ commitments: Commitment..., code: String = "2468") -> Record {
        var record = Record()
        record.setUnlockCode(code)
        commitments.forEach { record.begin($0) }
        return record
    }

    @Test("the right code ends that commitment alone, and files it unlocked")
    func unlockEndsOne() {
        let a = commitment(hours: 1)
        let b = commitment(hours: 2)
        var record = running(a, b)

        let result4 = record.unlock(a.id, code: "2468")

        #expect(result4)

        #expect(record.commitments.map(\.id) == [b.id])
        #expect(record.history.map(\.outcome) == [.unlocked])
        #expect(record.endedScreenPending == false)
    }

    @Test("a wrong code changes nothing")
    func wrongCode() {
        let a = commitment(hours: 1)
        var record = running(a)
        let before = record

        let result5 = record.unlock(a.id, code: "1357")

        #expect(result5 == false)
        #expect(record == before)
    }

    @Test("with no code set, nothing unlocks")
    func noCode() {
        let a = commitment(hours: 1)
        var record = Record()
        record.begin(a)

        let result6 = record.unlock(a.id, code: "")

        #expect(result6 == false)
        #expect(record.commitments.count == 1)
    }

    @Test("the code is stored as a digest, not as itself")
    func storedHashed() throws {
        var record = Record()
        record.setUnlockCode("2468")

        let bytes = try RecordCodec.encode(record)
        #expect(String(decoding: bytes, as: UTF8.self).contains("2468") == false)
        #expect(try RecordCodec.decode(bytes).unlockCode?.matches("2468") == true)
    }

    @Test("a code shorter than four characters is refused")
    func tooShort() {
        var record = Record()
        let result7 = record.setUnlockCode("123")
        #expect(result7 == false)
        #expect(record.unlockCode == nil)
    }

    @Test("the code cannot change or go while anything runs")
    func frozenWhileRunning() {
        var record = running(commitment(hours: 1))

        let result8 = record.setUnlockCode("9999", current: "2468")

        #expect(result8 == false)
        let result9 = record.removeUnlockCode(current: "2468")
        #expect(result9 == false)
        #expect(record.unlockCode?.matches("2468") == true)
    }

    @Test("changing or removing it needs the current code")
    func changeNeedsCurrent() {
        var record = Record()
        record.setUnlockCode("2468")

        let result10 = record.setUnlockCode("9999")

        #expect(result10 == false)
        let result11 = record.setUnlockCode("9999", current: "0000")
        #expect(result11 == false)
        let result12 = record.removeUnlockCode(current: "0000")
        #expect(result12 == false)

        let result13 = record.setUnlockCode("9999", current: "2468")

        #expect(result13)
        #expect(record.unlockCode?.matches("9999") == true)
        let result14 = record.removeUnlockCode(current: "9999")
        #expect(result14)
        #expect(record.unlockCode == nil)
    }

    @Test("a clean slate leaves the code alone")
    func cleanSlateKeepsCode() {
        var record = Record()
        record.setUnlockCode("2468")
        record.cleanSlate()
        #expect(record.unlockCode != nil)
    }
}

@Suite("A record written before concurrency opens as one running commitment")
struct MigrationTests {
    @Test("the single active commitment becomes the only running one, marks and all")
    func legacyActiveMigrates() throws {
        var legacy = commitment(hours: 3, domains: ["example.com"])
        legacy.isBroken = true
        legacy.isDegraded = true
        let current = Record(
            commitments: [legacy],
            draft: Draft(domains: [WebDomain(canonical: "draft.example.com")]),
            hasSeenFirstRun: true
        )

        let decoded = try RecordCodec.decode(asLegacy(try RecordCodec.encode(current)))

        #expect(decoded == current)
    }

    @Test("a legacy record with nothing running opens with nothing running")
    func legacyIdle() throws {
        let current = Record(hasSeenFirstRun: true)
        let decoded = try RecordCodec.decode(asLegacy(try RecordCodec.encode(current)))
        #expect(decoded.commitments.isEmpty)
    }

    /// Rewrites `commitments` into the single optional `active` key an older
    /// build wrote, so the bytes under test are the ones it actually produced.
    private func asLegacy(_ data: Data) throws -> Data {
        var record = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let commitments = try #require(record.removeValue(forKey: "commitments") as? [Any])
        if let only = commitments.first { record["active"] = only }
        return try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
    }
}
