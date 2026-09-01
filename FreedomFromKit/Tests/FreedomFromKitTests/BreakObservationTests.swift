import Testing

@testable import FreedomFromKit

@Suite("A break is only read off a status that has settled")
struct BreakObservationTests {
    private func seen(
        reinstalled: Bool = false,
        unauthorized: Bool = false,
        settled: Bool = true
    ) -> BreakObservation {
        BreakObservation(
            reinstalled: reinstalled, unauthorized: unauthorized, statusHasSettled: settled)
    }

    @Test("a cold launch reading unauthorized is not evidence of anything")
    func coldLaunchIsNotEvidence() {
        // This is the whole bug. The status has not loaded on a process that
        // young, so it reads unauthorized for a commitment nobody touched —
        // and the app marked one broken every time it was opened.
        #expect(seen(unauthorized: true, settled: false).isEvidenceOfABreak == false)
    }

    @Test("a settled read of unauthorized is a break")
    func settledUnauthorizedIsABreak() {
        // Hardware check X1: a foreground six seconds after a real revoke, on
        // a process alive five minutes, read unauthorized and meant it.
        #expect(seen(unauthorized: true, settled: true).isEvidenceOfABreak)
    }

    @Test("an authorized read is never a break, settled or not")
    func authorizedIsNeverABreak() {
        #expect(seen(unauthorized: false, settled: true).isEvidenceOfABreak == false)
        #expect(seen(unauthorized: false, settled: false).isEvidenceOfABreak == false)
    }

    @Test("a reinstall is a break whatever the status was doing")
    func reinstallStandsAlone() {
        // The marker file is absent beside a running commitment, which no
        // amount of daemon latency explains (ADR 0005). It does not need the
        // status to have settled, and it does not need it to be unauthorized.
        #expect(seen(reinstalled: true, unauthorized: false, settled: false).isEvidenceOfABreak)
        #expect(seen(reinstalled: true, unauthorized: true, settled: false).isEvidenceOfABreak)
        #expect(seen(reinstalled: true, unauthorized: false, settled: true).isEvidenceOfABreak)
    }

    @Test("an ordinary launch of a kept commitment is silent")
    func theCaseThatWasBroken() {
        // C8 came back inconclusive because of this one: a commitment ran its
        // full term and filed as broken, having been looked at once.
        let openingTheApp = seen(reinstalled: false, unauthorized: true, settled: false)
        #expect(openingTheApp.isEvidenceOfABreak == false)
    }
}
