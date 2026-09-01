import Foundation

/// What a reconciliation saw, and whether it is evidence that a commitment was
/// broken.
///
/// Both signals here are **things that happened**, not values that were read,
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
/// So neither signal below is a status read. A missing install marker is a file
/// that is not there. A refused registration is `DeviceActivity` declining to
/// start monitoring *because* authorization is gone — the system acting on the
/// state rather than reporting it, which is the line X1 watched arrive six
/// seconds after a revoke: `window registration failed reason=unauthorized`.
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

    public init(reinstalled: Bool, enforcementRefusedAsUnauthorized: Bool) {
        self.reinstalled = reinstalled
        self.enforcementRefusedAsUnauthorized = enforcementRefusedAsUnauthorized
    }

    /// A break marks a running commitment; it does not end one (ADR 0005), so
    /// the cost of being wrong is asymmetric and lands on the person who kept
    /// theirs: a missed break costs a row its accuracy, an invented one tells
    /// somebody who did not break their commitment that they did.
    public var isEvidenceOfABreak: Bool {
        reinstalled || enforcementRefusedAsUnauthorized
    }
}
