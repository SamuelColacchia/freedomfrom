import Foundation

/// Everything freedomfrom persists, in one value.
///
/// There is one Keychain record and no second store and no mirror, so there is
/// never a question of which copy is right (ADR 0002). It outlives app
/// deletion, which is what makes a break detectable at all.
public struct Record: Equatable, Sendable {
    /// Every commitment still running, each with its own targets and deadline.
    /// They never merge: a target stays held while any of them names it
    /// (ADR 0012, from the decision in #73).
    public var commitments: [Commitment]
    public var history: [ClosedCommitment]
    public var draft: Draft

    /// Not part of "everything you authored": a clean slate erases the history
    /// and the draft, and first run still shows once, ever (ADR 0008).
    public var hasSeenFirstRun: Bool

    /// The release can land while the app is closed, so "Ended." is drawn on
    /// the first launch after it and never again (ADR 0007). Whichever
    /// reconciliation point released sets this.
    public var endedScreenPending: Bool

    /// The one code that unlocks a single commitment early, or `nil` when
    /// none is set and nothing can be unlocked before its deadline (ADR 0012).
    /// Untouched by a clean slate, and changed only while nothing runs.
    public internal(set) var unlockCode: UnlockCode?

    public init(
        commitments: [Commitment] = [],
        history: [ClosedCommitment] = [],
        draft: Draft = .empty,
        hasSeenFirstRun: Bool = false,
        endedScreenPending: Bool = false,
        unlockCode: UnlockCode? = nil
    ) {
        self.commitments = commitments
        self.history = history
        self.draft = draft
        self.hasSeenFirstRun = hasSeenFirstRun
        self.endedScreenPending = endedScreenPending
        self.unlockCode = unlockCode
    }

    public static let empty = Record()

    /// Erases everything you authored, and only that (ADR 0008).
    public mutating func cleanSlate() {
        history = []
        draft = .empty
    }
}

extension Record: Codable {
    private enum CodingKeys: String, CodingKey {
        case commitments, history, draft, hasSeenFirstRun, endedScreenPending, unlockCode
        /// The single running commitment every build before ADR 0012 wrote.
        /// Read so an update neither releases nor extends it, never written.
        case active
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let commitments = try container.decodeIfPresent([Commitment].self, forKey: .commitments) {
            self.commitments = commitments
        } else {
            commitments = try container.decodeIfPresent(Commitment.self, forKey: .active).map { [$0] } ?? []
        }
        history = try container.decode([ClosedCommitment].self, forKey: .history)
        draft = try container.decode(Draft.self, forKey: .draft)
        hasSeenFirstRun = try container.decode(Bool.self, forKey: .hasSeenFirstRun)
        endedScreenPending = try container.decode(Bool.self, forKey: .endedScreenPending)
        unlockCode = try container.decodeIfPresent(UnlockCode.self, forKey: .unlockCode)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(commitments, forKey: .commitments)
        try container.encode(history, forKey: .history)
        try container.encode(draft, forKey: .draft)
        try container.encode(hasSeenFirstRun, forKey: .hasSeenFirstRun)
        try container.encode(endedScreenPending, forKey: .endedScreenPending)
        try container.encodeIfPresent(unlockCode, forKey: .unlockCode)
    }
}

/// The record's wire format. Deliberately a value the kit owns rather than
/// something each target rolls: three processes read this and a drift between
/// them is an extension reconciling against a stale deadline.
public enum RecordCodec {
    public static func encode(_ record: Record) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // Stable output, so an unchanged record produces unchanged bytes.
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(record)
    }

    public static func decode(_ data: Data) throws -> Record {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Record.self, from: data)
    }
}
