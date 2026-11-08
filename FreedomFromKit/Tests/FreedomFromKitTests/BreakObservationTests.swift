import Testing

@testable import FreedomFromKit

@Suite("A break is read off what happened, never off the authorization status")
struct BreakObservationTests {
    private func seen(
        reinstalled: Bool = false, refused: Bool = false, lost: Bool = false
    ) -> BreakObservation {
        BreakObservation(
            reinstalled: reinstalled, enforcementRefusedAsUnauthorized: refused,
            approvalLostInProcess: lost)
    }

    @Test("an ordinary reconciliation is silent")
    func nothingHappenedIsNotABreak() {
        #expect(seen().isEvidenceOfABreak == false)
    }

    @Test("a refused registration is a break")
    func refusedRegistrationIsABreak() {
        // Hardware check X1 watched this arrive six seconds after a real
        // revoke: DeviceActivity declining to start monitoring because the app
        // is no longer authorized.
        #expect(seen(refused: true).isEvidenceOfABreak)
    }

    @Test("a reinstall is a break on its own")
    func reinstallStandsAlone() {
        #expect(seen(reinstalled: true).isEvidenceOfABreak)
    }

    @Test("both at once is still one break")
    func bothTogether() {
        // A reinstall on a revoked device produces the pair, and `markBroken`
        // records once and never re-marks (ADR 0005) — so what matters here is
        // that neither signal cancels the other.
        #expect(seen(reinstalled: true, refused: true).isEvidenceOfABreak)
    }

    @Test("an approval lost inside one process is a break")
    func lostApprovalIsABreak() {
        // On the iPhone on 4 September a real revoke was followed by a
        // registration the system accepted, so the refusal never came (#60).
        // This is the signal that revoke did produce.
        #expect(seen(lost: true).isEvidenceOfABreak)
    }
}

@Suite("Only an approval this process already read can be lost")
struct AuthorizationTrailTests {
    /// Feeds readings in order and returns which of them reported a loss.
    private func losses(_ approved: [Bool]) -> [Bool] {
        var trail = AuthorizationTrail()
        return approved.map { trail.observe(approved: $0) }
    }

    @Test("a cold launch reads unauthorized and loses nothing")
    func coldLaunchIsSilent() {
        // The regression guard for #54: every cold launch reads `Not
        // Determined` on a process too young to have loaded the value, then
        // the re-request reads `.approved`. Nothing was held, so nothing is lost.
        #expect(losses([false, true]) == [false, false])
    }

    @Test("the clean run's launches and foregrounds lose nothing")
    func cleanRunIsSilent() {
        // The shape of every process in c1-c9 and c8-rewalk: `Not Determined`
        // at launch, `.approved` from then on.
        #expect(losses([false, true, true, true]) == [false, false, false, false])
    }

    @Test("a revoke after an approval is reported on the reading that shows it")
    func revokeAfterApprovalIsALoss() {
        // story-revoke-20260904, pid 28899: `.approved` at 19:27:21, then
        // `Not Determined` on the foreground at 19:32:42 after the revoke.
        #expect(losses([false, true, false]) == [false, false, true])
    }

    @Test("one loss is reported once, however long it lasts")
    func lossIsReportedOnce() {
        // A declined re-prompt reads `Not Determined` again on the same wake,
        // and so does every later foreground until a grant.
        #expect(losses([true, false, false, false]) == [false, true, false, false])
    }

    @Test("a re-grant makes a second revoke reportable")
    func regrantThenRevokeAgain() {
        #expect(losses([true, false, true, false]) == [false, true, false, true])
    }
}
