import Foundation

/// Everything freedomfrom persists, in one value.
///
/// There is one Keychain record and no second store and no mirror, so there is
/// never a question of which copy is right (ADR 0002). It outlives app
/// deletion, which is what makes a break detectable at all.
public struct Record: Equatable, Codable, Sendable {
    public var active: Commitment?
    public var history: [ClosedCommitment]
    public var draft: Draft

    /// Not part of "everything you authored": a clean slate erases the history
    /// and the draft, and first run still shows once, ever (ADR 0008).
    public var hasSeenFirstRun: Bool

    /// The release can land while the app is closed, so "Ended." is drawn on
    /// the first launch after it and never again (ADR 0007). Whichever
    /// reconciliation point released sets this.
    public var endedScreenPending: Bool

    public init(
        active: Commitment? = nil,
        history: [ClosedCommitment] = [],
        draft: Draft = .empty,
        hasSeenFirstRun: Bool = false,
        endedScreenPending: Bool = false
    ) {
        self.active = active
        self.history = history
        self.draft = draft
        self.hasSeenFirstRun = hasSeenFirstRun
        self.endedScreenPending = endedScreenPending
    }

    public static let empty = Record()

    /// Erases everything you authored, and only that (ADR 0008).
    public mutating func cleanSlate() {
        history = []
        draft = .empty
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
