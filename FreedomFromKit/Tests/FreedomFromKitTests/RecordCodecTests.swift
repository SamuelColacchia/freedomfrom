import Foundation
import Testing

@testable import FreedomFromKit

@Suite("The record round-trips through its codec")
struct RecordCodecTests {
    private let started = Date(timeIntervalSince1970: 1_800_000_000)

    private func fullRecord() -> Record {
        let commitment = Commitment(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            startedAt: started,
            deadline: started.addingTimeInterval(900),
            encodedSelection: Data([0x01, 0x02, 0x03]),
            namedHandles: [TargetHandle("a"), TargetHandle("b")],
            domains: [WebDomain(canonical: "example.com")],
            isDegraded: true,
            isBroken: false
        )
        return Record(
            active: commitment,
            history: [
                ClosedCommitment(
                    startedAt: started.addingTimeInterval(-86_400),
                    deadline: started,
                    namedTargetCount: 3,
                    domains: [WebDomain(canonical: "news.example.com")],
                    outcome: .broken
                )
            ],
            draft: Draft(
                encodedSelection: Data([0x09]),
                namedTargetCount: 2,
                domains: [WebDomain(canonical: "www.example.com")],
                length: .preset(.thirtyDays)
            ),
            hasSeenFirstRun: true,
            endedScreenPending: false
        )
    }

    @Test("an empty record survives the trip")
    func emptyRoundTrips() throws {
        let decoded = try RecordCodec.decode(RecordCodec.encode(.empty))
        #expect(decoded == Record.empty)
    }

    @Test("a fully populated record survives the trip")
    func fullRoundTrips() throws {
        let original = fullRecord()
        let decoded = try RecordCodec.decode(RecordCodec.encode(original))
        #expect(decoded == original)
    }

    @Test("the deadline survives to the second, because it is authoritative")
    func deadlineSurvives() throws {
        let original = fullRecord()
        let decoded = try RecordCodec.decode(RecordCodec.encode(original))
        #expect(decoded.active?.deadline == original.active?.deadline)
    }

    @Test("encoding is stable, so an unchanged record produces unchanged bytes")
    func encodingIsStable() throws {
        let record = fullRecord()
        #expect(try RecordCodec.encode(record) == RecordCodec.encode(record))
    }

    @Test("a custom length round-trips as a length and not as a date")
    func customLengthRoundTrips() throws {
        var record = Record.empty
        record.draft.length = .custom(seconds: 60 * 60 * 24 * 100)
        let decoded = try RecordCodec.decode(RecordCodec.encode(record))
        #expect(decoded.draft.length == .custom(seconds: 60 * 60 * 24 * 100))
    }
}

@Suite("A clean slate erases everything you authored, and only that")
struct CleanSlateTests {
    @Test("it takes the history and the draft together")
    func takesHistoryAndDraft() {
        var record = Record(
            history: [
                ClosedCommitment(
                    startedAt: .init(timeIntervalSince1970: 0),
                    deadline: .init(timeIntervalSince1970: 900),
                    namedTargetCount: 1,
                    domains: [],
                    outcome: .completed
                )
            ],
            draft: Draft(namedTargetCount: 4),
            hasSeenFirstRun: true
        )

        record.cleanSlate()

        #expect(record.history.isEmpty)
        #expect(record.draft == .empty)
    }

    @Test("first run does not come back")
    func firstRunStaysSeen() {
        var record = Record(draft: Draft(namedTargetCount: 4), hasSeenFirstRun: true)
        record.cleanSlate()
        #expect(record.hasSeenFirstRun)
    }

    @Test("it lifts nothing: a running commitment is untouched")
    func leavesTheCommitmentAlone() {
        let commitment = Commitment(
            startedAt: .init(timeIntervalSince1970: 0),
            deadline: .init(timeIntervalSince1970: 900),
            encodedSelection: nil,
            namedHandles: [],
            domains: []
        )
        var record = Record(active: commitment, draft: Draft(namedTargetCount: 2))

        record.cleanSlate()

        #expect(record.active == commitment)
    }
}
