import Foundation

extension CommitmentLength {
    public enum LengthError: Error, Equatable {
        case tooShort
        case tooLong
    }

    /// A commitment lasts 15 minutes to one year (ADR 0004). Both bounds are
    /// legal; only what falls outside them is refused.
    public static let minimumSeconds: TimeInterval = 15 * 60
    public static let maximumSeconds: TimeInterval = 365 * 86_400

    /// Refuses rather than silently corrects, because this answers the date
    /// picker and a custom entry, where a silent correction would put a
    /// different commitment in front of the hold than the one chosen.
    public static func clamp(_ seconds: TimeInterval) -> Result<TimeInterval, LengthError> {
        if seconds < minimumSeconds { return .failure(.tooShort) }
        if seconds > maximumSeconds { return .failure(.tooLong) }
        return .success(seconds)
    }

    /// How long this length runs, measured from a given instant.
    ///
    /// The instant is load-bearing for the multi-day presets, which are
    /// calendar days rather than multiples of 86,400: across a clock change,
    /// "30 days" has to mean the same time of day thirty days later, or the
    /// duration and the deadline sentence stop being the same fact. The
    /// sub-day presets are elapsed time, which is what §6 of the build spec
    /// names them — "24 hours", not "1 day".
    public func duration(from now: Date, calendar: Calendar = .current) -> TimeInterval {
        switch self {
        case .preset(let preset):
            if let days = preset.calendarDays {
                let then = calendar.date(byAdding: .day, value: days, to: now)
                return then?.timeIntervalSince(now) ?? preset.nominalSeconds
            }
            return preset.nominalSeconds
        case .custom(let seconds):
            return min(max(seconds, Self.minimumSeconds), Self.maximumSeconds)
        }
    }

    /// Now plus the duration. A remembered length is re-anchored here rather
    /// than restored as a stored date, so a draft left a month ago still
    /// resolves to a deadline in the future (ADR 0008).
    public func deadline(from now: Date, calendar: Calendar = .current) -> Date {
        now.addingTimeInterval(duration(from: now, calendar: calendar))
    }

    /// About 1.5s at fifteen minutes and about 5s at thirty days and above,
    /// interpolated linearly in `log(duration)` and clamped at both ends: the
    /// gesture costs what the commitment costs (ADR 0004).
    ///
    /// Deliberately blind to `now`. An hour of calendar slack either way cannot
    /// move a log-interpolated hold by a perceptible amount, and a hold whose
    /// length depended on the date would be a hold you could not learn.
    public var holdDuration: TimeInterval {
        let shortest = Self.minimumSeconds
        let longest: TimeInterval = 30 * 86_400
        let seconds = min(max(nominalSeconds, shortest), longest)

        let position =
            (log(seconds) - log(shortest)) / (log(longest) - log(shortest))
        return 1.5 + position * (5.0 - 1.5)
    }

    /// The length as a plain number of seconds, ignoring the calendar. Only the
    /// hold curve uses this; anything that becomes a deadline goes through
    /// `duration(from:)`.
    var nominalSeconds: TimeInterval {
        switch self {
        case .preset(let preset): preset.nominalSeconds
        case .custom(let seconds): min(max(seconds, Self.minimumSeconds), Self.maximumSeconds)
        }
    }
}

extension CommitmentLength.Preset {
    var nominalSeconds: TimeInterval {
        switch self {
        case .fifteenMinutes: 15 * 60
        case .oneHour: 3_600
        case .threeHours: 3 * 3_600
        case .twelveHours: 12 * 3_600
        case .oneDay: 86_400
        case .threeDays: 3 * 86_400
        case .sevenDays: 7 * 86_400
        case .thirtyDays: 30 * 86_400
        }
    }

    /// Non-nil for the presets a person reads as dates rather than as elapsed
    /// time, which are the ones that must survive a clock change intact.
    var calendarDays: Int? {
        switch self {
        case .fifteenMinutes, .oneHour, .threeHours, .twelveHours, .oneDay: nil
        case .threeDays: 3
        case .sevenDays: 7
        case .thirtyDays: 30
        }
    }
}
