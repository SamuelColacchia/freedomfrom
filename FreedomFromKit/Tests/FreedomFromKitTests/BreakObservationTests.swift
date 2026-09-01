import Testing

@testable import FreedomFromKit

@Suite("A break is read off what happened, never off the authorization status")
struct BreakObservationTests {
    private func seen(reinstalled: Bool = false, refused: Bool = false) -> BreakObservation {
        BreakObservation(
            reinstalled: reinstalled, enforcementRefusedAsUnauthorized: refused)
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

    @Test("the authorization status is not a term in this")
    func statusIsNotAnInput() {
        // The regression guard for #54. Every cold launch reads the status as
        // unauthorized on a process too young to have loaded it, and a real
        // revoke reads exactly the same string (X1a) — so no reading of it can
        // be an input here. This asserts the shape of the type: two signals,
        // both of them things that happened.
        let openingTheApp = seen(reinstalled: false, refused: false)
        #expect(openingTheApp.isEvidenceOfABreak == false)

        let everySignal = BreakObservation(
            reinstalled: false, enforcementRefusedAsUnauthorized: false)
        #expect(everySignal == openingTheApp)
    }
}
