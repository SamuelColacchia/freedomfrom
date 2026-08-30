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

    /// The record outlives app deletion, so it also outlives the build that
    /// wrote it: a phone that drafted apps before hardware check S3 came back
    /// red still holds a draft carrying them. Opening it must not fail, and must
    /// not resurrect them — what survives is the words and the length (ADR 0008,
    /// as amended).
    @Test("a draft written before apps left it still opens, keeping the words and the length")
    func draftFromBeforeTheAmendmentOpens() throws {
        let original = Record(
            draft: Draft(
                domains: [WebDomain(canonical: "example.com")],
                length: .preset(.thirtyDays)
            ),
            hasSeenFirstRun: true
        )

        let decoded = try RecordCodec.decode(
            withLegacyDraftKeys(try RecordCodec.encode(original)))

        #expect(decoded == original)
    }

    /// Re-adds the two keys a draft used to carry, so the bytes under test are
    /// the ones an older build actually wrote rather than a hand-typed guess at
    /// them.
    private func withLegacyDraftKeys(_ data: Data) throws -> Data {
        var record = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any])
        var draft = try #require(record["draft"] as? [String: Any])

        draft["encodedSelection"] = Data([0x09]).base64EncodedString()
        draft["namedTargetCount"] = 2
        record["draft"] = draft

        return try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
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
            draft: Draft(domains: [WebDomain(canonical: "example.com")]),
            hasSeenFirstRun: true
        )

        record.cleanSlate()

        #expect(record.history.isEmpty)
        #expect(record.draft == .empty)
    }

    @Test("first run does not come back")
    func firstRunStaysSeen() {
        var record = Record(
            draft: Draft(domains: [WebDomain(canonical: "example.com")]), hasSeenFirstRun: true)
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
        var record = Record(
            active: commitment, draft: Draft(domains: [WebDomain(canonical: "example.com")]))

        record.cleanSlate()

        #expect(record.active == commitment)
    }
}
