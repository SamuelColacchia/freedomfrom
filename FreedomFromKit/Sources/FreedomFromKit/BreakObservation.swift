import Foundation

/// What a reconciliation saw, and whether it is evidence that a commitment was
/// broken.
///
/// Every signal here is **something that happened**, not a value that was read,
/// and that is the whole design. It was arrived at the long way round.
///
/// The app used to mark a break from `authorizationStatus`, a cached value the
/// framework has not loaded yet on a young process: every cold launch read it
/// as unauthorized and marked a running commitment broken, permanently, whether
/// or not anything was revoked (#54). Hardware check C8 caught the consequence,
/// a commitment that ran its full term filing as broken after being opened once.
///
/// The obvious repair is to read the status only when it can be trusted, and
/// there is no sound way to know when that is. `.approved` never appears
/// falsely, but its absence means either "revoked" or "not loaded yet", and
/// hardware check X1a ruled out separating them by value: a real revoke also
/// reads `Not Determined` rather than `.denied`. What is left is a proxy for
/// process age, and a proxy that guesses wrong invents a break.
///
/// So none of the signals below is a single status read. A missing install
/// marker is a file that is not there. A refused registration is
/// `DeviceActivity` declining to start monitoring *because* authorization is
/// gone — the system acting on the state rather than reporting it, which is the
/// line X1 watched arrive six seconds after a revoke:
/// `window registration failed reason=unauthorized`.
///
/// That refusal turned out not to be dependable. On the iPhone on 4 September,
/// iOS 26.6.1, a real revoke was followed by a registration the system
/// *accepted*, and nothing was marked (#60). The third signal is a change
/// rather than a value: a process that has already read `.approved` and then
/// reads anything else. A young process cannot produce it, because it has not
/// read `.approved` yet. It is what both real revokes on record produced, and
/// no other app process in the committed evidence did. See
/// `AuthorizationTrail`.
public struct BreakObservation: Equatable, Sendable {
    /// The install marker was absent beside a running commitment: the app was
    /// deleted and put back while it ran (ADR 0005).
    public let reinstalled: Bool

    /// `DeviceActivity` refused to register the commitment's window because the
    /// app is not authorized.
    ///
    /// It arrives on the first reconciliation after a revoke, before the app
    /// re-requests anything — which is what ADR 0005 means by observing a
    /// revoke on the next launch and marking it once, with coverage re-armed
    /// afterwards if it is granted. A mark taken after the prompt could not
    /// tell a re-grant from an app that was authorized all along.
    public let enforcementRefusedAsUnauthorized: Bool

    /// This process read `.approved` earlier, and has now read something else.
    ///
    /// It misses a revoke made while the app was not running, because the next
    /// launch starts with no approval to lose. That gap is deliberate: a missed
    /// break is the cheaper of the two errors (see `isEvidenceOfABreak`).
    public let approvalLostInProcess: Bool

    public init(
        reinstalled: Bool,
        enforcementRefusedAsUnauthorized: Bool,
        approvalLostInProcess: Bool = false
    ) {
        self.reinstalled = reinstalled
        self.enforcementRefusedAsUnauthorized = enforcementRefusedAsUnauthorized
        self.approvalLostInProcess = approvalLostInProcess
    }

    /// A break marks a running commitment; it does not end one (ADR 0005), so
    /// the cost of being wrong is asymmetric and lands on the person who kept
    /// theirs: a missed break costs a row its accuracy, an invented one tells
    /// somebody who did not break their commitment that they did.
    public var isEvidenceOfABreak: Bool {
        reinstalled || enforcementRefusedAsUnauthorized || approvalLostInProcess
    }
}

/// The authorization readings one process has made, kept so that a loss can be
/// told apart from a value that has not loaded yet.
///
/// A cold launch reads `Not Determined` whether or not anything was revoked
/// (#54), and a settled read after a revoke reads the same string (X1a), so no
/// single reading can carry a break. What carries one is the change: this
/// process has already read `.approved`, so the framework had loaded the value,
/// and now reads something else.
///
/// It reports a loss once, on the reading that shows it, and then needs a new
/// `.approved` before it can report another. A prompt that is declined, or a
/// later foreground that still reads `Not Determined`, does not report the same
/// loss again.
public struct AuthorizationTrail: Sendable {
    private var holdsApproval = false

    public init() {}

    /// Records one reading, and returns whether it is the loss of an approval
    /// this process had already read.
    public mutating func observe(approved: Bool) -> Bool {
        defer { holdsApproval = approved }
        return holdsApproval && !approved
    }
}
