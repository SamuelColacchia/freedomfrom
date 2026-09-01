import Foundation

/// What a launch or a foreground saw, and whether it is evidence that a
/// commitment was broken.
///
/// This exists because the app got the question wrong for a while and nothing
/// could catch it. `AppModel` read `AuthorizationCenter.shared.authorizationStatus`
/// and passed `!approved` straight into the reconciliation, and
/// `AuthorizationCenter` has no seam — so the one decision that can call a kept
/// commitment broken was made in the one place no test could reach.
///
/// **A cold launch cannot be believed.** The status has not loaded yet when the
/// process is that young, and it reads `.notDetermined` whether or not anything
/// was revoked. Hardware check C8 caught the consequence: a commitment that ran
/// its full term filed as broken, because the app had been launched once while
/// it ran. Every launch in that archive read `Not Determined` and every
/// foreground read `Approved`, minutes apart, with nothing revoked.
///
/// **And the value cannot disambiguate it either**, which is what hardware
/// check X1a settled: a real revoke also leaves the status reading
/// `Not Determined`, not `.denied`. So there is no constant to test for. The
/// only thing separating the two is whether the read was taken on a process
/// that had been alive long enough to have one.
public struct BreakObservation: Equatable, Sendable {
    /// The install marker was absent beside a running commitment: the app was
    /// deleted and put back while it ran. Unambiguous, and nothing about
    /// timing changes it (ADR 0005).
    public let reinstalled: Bool

    /// What the status said, as a yes or no rather than a case, because which
    /// case it was carries no information — see X1a.
    public let unauthorized: Bool

    /// Whether that reading is worth anything. False on a cold launch, true on
    /// a foreground and true again after a completed `requestAuthorization`,
    /// which forces the round-trip that resolves it.
    public let statusHasSettled: Bool

    public init(reinstalled: Bool, unauthorized: Bool, statusHasSettled: Bool) {
        self.reinstalled = reinstalled
        self.unauthorized = unauthorized
        self.statusHasSettled = statusHasSettled
    }

    /// A break marks a running commitment; it does not end one (ADR 0005). So
    /// the cost of being wrong is asymmetric and lands entirely on the person
    /// who kept their commitment: a missed break loses a row's accuracy, and a
    /// invented one tells somebody who did not break their commitment that
    /// they did. Where the evidence is ambiguous this answers no.
    public var isEvidenceOfABreak: Bool {
        if reinstalled { return true }
        return unauthorized && statusHasSettled
    }
}
