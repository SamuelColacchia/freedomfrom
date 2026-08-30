import Foundation
import Testing

@testable import FreedomFromKit

/// A commitment lasts 15 minutes to one year, and what is remembered is a
/// length rather than a date (ADR 0004, ADR 0008).
@Suite("A length is clamped to [15 minutes, 365 days]")
struct ClampTests {
    @Test("under fifteen minutes is refused")
    func underTheFloor() {
        #expect(CommitmentLength.clamp(14 * 60) == .failure(.tooShort))
        #expect(CommitmentLength.clamp(0) == .failure(.tooShort))
        #expect(CommitmentLength.clamp(-1) == .failure(.tooShort))
    }

    @Test("over 365 days is refused")
    func overTheCeiling() {
        #expect(CommitmentLength.clamp(366 * 86_400) == .failure(.tooLong))
    }

    @Test("both bounds are themselves legal")
    func boundsAreInclusive() {
        #expect(CommitmentLength.clamp(15 * 60) == .success(15 * 60))
        #expect(CommitmentLength.clamp(365 * 86_400) == .success(365 * 86_400))
    }
}

@Suite("A length resolves to a duration, and only ever from a given now")
struct DurationTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("the sub-day presets are elapsed time")
    func subDayPresets() {
        #expect(CommitmentLength.preset(.fifteenMinutes).duration(from: now) == 900)
        #expect(CommitmentLength.preset(.oneHour).duration(from: now) == 3_600)
        #expect(CommitmentLength.preset(.threeHours).duration(from: now) == 10_800)
        #expect(CommitmentLength.preset(.twelveHours).duration(from: now) == 43_200)
        #expect(CommitmentLength.preset(.oneDay).duration(from: now) == 86_400)
    }

    @Test("the multi-day presets are calendar days, so a deadline keeps its time of day")
    func multiDayPresetsAreCalendarDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!

        // Saturday 2026-10-24, 12:00 BST. British Summer Time ends at 02:00 on
        // Sunday the 25th, so the three calendar days that follow contain one
        // day of 25 hours — and "three days" still lands at noon.
        let beforeTheClocksChange = Date(timeIntervalSince1970: 1_792_839_600)
        let seconds = CommitmentLength.preset(.threeDays)
            .duration(from: beforeTheClocksChange, calendar: calendar)

        #expect(seconds == 3 * 86_400 + 3_600)
    }

    @Test("a custom length is its own seconds, clamped")
    func customLength() {
        #expect(CommitmentLength.custom(seconds: 7_200).duration(from: now) == 7_200)
        #expect(CommitmentLength.custom(seconds: 60).duration(from: now) == 15 * 60)
        #expect(CommitmentLength.custom(seconds: 400 * 86_400).duration(from: now) == 365 * 86_400)
    }

    @Test("a remembered length is re-anchored to now, never restored as a stored date")
    func reAnchors() {
        let length = CommitmentLength.preset(.sevenDays)
        let aWeekLater = now.addingTimeInterval(7 * 86_400)

        #expect(length.deadline(from: now) == now.addingTimeInterval(7 * 86_400))
        #expect(length.deadline(from: aWeekLater) == aWeekLater.addingTimeInterval(7 * 86_400))
    }

    @Test("a custom length that would resolve to a past deadline still re-anchors forward")
    func customReAnchorsForward() {
        // The draft was left holding an hour, a month ago. Restoring it is
        // restoring an hour from now, not an instant that has been and gone.
        let length = CommitmentLength.custom(seconds: 3_600)
        let muchLater = now.addingTimeInterval(30 * 86_400)

        #expect(length.deadline(from: muchLater) > muchLater)
        #expect(length.deadline(from: muchLater) == muchLater.addingTimeInterval(3_600))
    }
}

@Suite("The hold costs what the commitment costs")
struct HoldDurationTests {
    @Test("fifteen minutes gives the short anchor")
    func shortAnchor() {
        #expect(CommitmentLength.preset(.fifteenMinutes).holdDuration == 1.5)
    }

    @Test("thirty days and a year both give the long anchor")
    func longAnchor() {
        #expect(CommitmentLength.preset(.thirtyDays).holdDuration == 5.0)
        #expect(CommitmentLength.custom(seconds: 365 * 86_400).holdDuration == 5.0)
    }

    @Test("the curve between them is monotonic")
    func monotonic() {
        let lengths: [CommitmentLength] = [
            .preset(.fifteenMinutes), .preset(.oneHour), .preset(.threeHours),
            .preset(.twelveHours), .preset(.oneDay), .preset(.threeDays),
            .preset(.sevenDays), .preset(.thirtyDays),
        ]
        let holds = lengths.map(\.holdDuration)

        for (shorter, longer) in zip(holds, holds.dropFirst()) {
            #expect(shorter < longer)
        }
    }

    @Test("every hold sits inside its two anchors")
    func clampedAtBothEnds() {
        for hold in CommitmentLength.Preset.allCases.map({ CommitmentLength.preset($0).holdDuration }) {
            #expect(hold >= 1.5)
            #expect(hold <= 5.0)
        }
    }
}
