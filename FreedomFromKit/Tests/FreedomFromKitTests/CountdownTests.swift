import Foundation
import Testing

@testable import FreedomFromKit

@Suite("The countdown reads the same in both places it is drawn")
struct CountdownTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func ticking(_ seconds: TimeInterval) -> String {
        Countdown.ticking(until: now.addingTimeInterval(seconds), from: now)
    }

    private func coarse(_ seconds: TimeInterval) -> String {
        Countdown.coarse(until: now.addingTimeInterval(seconds), from: now)
    }

    @Test("inside a day the ticking form is a clock")
    func withinADay() {
        #expect(ticking(4 * 3_600 + 15 * 60 + 9) == "04:15:09")
        #expect(ticking(59) == "00:00:59")
    }

    @Test("beyond a day it gains a day count")
    func beyondADay() {
        #expect(ticking(3 * 86_400 + 4 * 3_600 + 15 * 60 + 9) == "3d 04:15:09")
    }

    @Test("the coarse form drops to the two largest units it has")
    func coarseUnits() {
        #expect(coarse(3 * 86_400 + 4 * 3_600) == "3d 4h")
        #expect(coarse(4 * 3_600 + 15 * 60) == "4h 15m")
        #expect(coarse(9 * 60 + 59) == "9m")
    }

    @Test("a passed deadline reads as spent, not as owed")
    func neverNegative() {
        // A release arrives late rather than early, so this is a state both
        // surfaces can genuinely be in.
        #expect(ticking(-3_600) == "00:00:00")
        #expect(coarse(-3_600) == "0m")
    }
}
