import Foundation

/// An opaque, app-minted key for one selection token.
///
/// The kit never interprets it. The app mints it as the base64 of the encoded
/// token, so a token that churns yields a different handle — which is exactly
/// how "no longer resolves" is detected (ADR 0002, ADR 0005).
public struct TargetHandle: Hashable, Codable, Sendable {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }
}

/// A canonical host. Only `WebDomain.canonicalize` may construct one, so
/// displayed, stored, and applied are always the same string (ADR 0006).
public struct WebDomain: Hashable, Codable, Sendable {
    public let host: String

    /// Non-public on purpose: canonicalization is the only way in.
    init(canonical host: String) {
        self.host = host
    }
}

/// What a commitment lasts, as a length rather than a date.
///
/// A remembered length is re-anchored to now on restore, never restored as a
/// stored date, because a stored date can have passed since (ADR 0008).
public enum CommitmentLength: Equatable, Codable, Sendable {
    case preset(Preset)
    case custom(seconds: TimeInterval)

    public enum Preset: String, Codable, CaseIterable, Sendable {
        case fifteenMinutes, oneHour, threeHours, twelveHours
        case oneDay, threeDays, sevenDays, thirtyDays
    }
}

/// What you would commit to if you held right now: the targets and the length,
/// as last left on screen. Persists between commitments and survives the app
/// being deleted; only you and a clean slate edit it (ADR 0008).
public struct Draft: Equatable, Codable, Sendable {
    /// The encoded `FamilyActivitySelection`. Opaque to the kit.
    public var encodedSelection: Data?
    /// So the root renders a count without decoding anything.
    public var namedTargetCount: Int
    public var domains: [WebDomain]
    public var length: CommitmentLength?

    public init(
        encodedSelection: Data? = nil,
        namedTargetCount: Int = 0,
        domains: [WebDomain] = [],
        length: CommitmentLength? = nil
    ) {
        self.encodedSelection = encodedSelection
        self.namedTargetCount = namedTargetCount
        self.domains = domains
        self.length = length
    }

    public static let empty = Draft()

    public var isEmpty: Bool {
        namedTargetCount == 0 && domains.isEmpty
    }
}

/// A block of a chosen set of targets, running until a fixed deadline, which
/// the app will not lift early.
public struct Commitment: Equatable, Codable, Sendable {
    public let id: UUID
    public let startedAt: Date
    /// Absolute wall-clock, and authoritative. Nothing shortens it (ADR 0002).
    public let deadline: Date
    public let encodedSelection: Data?
    /// Captured at commit. Compared against what currently resolves to get
    /// coverage; the difference is what degrades a commitment.
    public let namedHandles: [TargetHandle]
    public let domains: [WebDomain]
    /// Permanent for the life of the commitment even if coverage returns: the
    /// mark records how it ran (ADR 0005).
    public internal(set) var isDegraded: Bool
    /// Recorded once on first observation and never re-marked. A break marks a
    /// running commitment; it does not end one (ADR 0005).
    public internal(set) var isBroken: Bool

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        deadline: Date,
        encodedSelection: Data?,
        namedHandles: [TargetHandle],
        domains: [WebDomain],
        isDegraded: Bool = false,
        isBroken: Bool = false
    ) {
        self.id = id
        self.startedAt = startedAt
        self.deadline = deadline
        self.encodedSelection = encodedSelection
        self.namedHandles = namedHandles
        self.domains = domains
        self.isDegraded = isDegraded
        self.isBroken = isBroken
    }
}

/// The history's vocabulary, fixed at three values (ADR 0005). Broken and
/// degraded can both be true of one commitment; the row reads broken.
public enum Outcome: String, Codable, Sendable {
    case completed
    case completedDegraded
    case broken
}

/// One row of the commitment history. Apps are a count because iOS never lets
/// the app name them; domains are words because they were typed (ADR 0006).
public struct ClosedCommitment: Equatable, Codable, Sendable {
    public let startedAt: Date
    public let deadline: Date
    public let namedTargetCount: Int
    public let domains: [WebDomain]
    public let outcome: Outcome

    public init(
        startedAt: Date,
        deadline: Date,
        namedTargetCount: Int,
        domains: [WebDomain],
        outcome: Outcome
    ) {
        self.startedAt = startedAt
        self.deadline = deadline
        self.namedTargetCount = namedTargetCount
        self.domains = domains
        self.outcome = outcome
    }
}

/// The targets a commitment is enforcing right now, against the targets it
/// names. This is the substitute for every message the app refuses to show,
/// which makes its accuracy load-bearing rather than cosmetic (ADR 0005).
public struct Coverage: Equatable, Sendable {
    public let resolved: Int
    public let named: Int

    public init(resolved: Int, named: Int) {
        self.resolved = resolved
        self.named = named
    }

    public var isComplete: Bool { resolved >= named }
}

/// One `DeviceActivity` window. Every window the walk-forward step produces is
/// exactly seven days long (ADR 0004, sharpened by the v1 build spec).
public struct MonitoringWindow: Equatable, Sendable {
    public enum Kind: String, Sendable {
        /// Toward the deadline: wake me again later to re-register.
        case walk
        /// Starts at the deadline and runs a further seven days. The release
        /// trigger, and a week-wide net rather than one a few minutes wide.
        case final
    }

    public let start: Date
    public let end: Date
    public let kind: Kind

    public init(start: Date, end: Date, kind: Kind) {
        self.start = start
        self.end = end
        self.kind = kind
    }
}
