import Foundation

/// How long is left, in the two places it is drawn.
///
/// Both live here rather than in the app because two processes draw a
/// countdown — the app and `ShieldConfig` — and they must not drift into
/// disagreeing about the same instant. Digits only, so neither needs a locale.
public enum Countdown {
    /// The countdown screen, which ticks: `3d 04:15:09`, or `04:15:09` inside a
    /// day. Never negative — a release can arrive late, and the screen showing
    /// it should read as spent rather than as owed.
    public static func ticking(until deadline: Date, from now: Date) -> String {
        let (days, hours, minutes, seconds) = parts(until: deadline, from: now)
        let clock = "\(pad(hours)):\(pad(minutes)):\(pad(seconds))"
        return days > 0 ? "\(days)d \(clock)" : clock
    }

    /// The shield, which is drawn once and meant to be closed: `3d 4h`, `4h
    /// 15m`, `9m`. A shield that ticks by the second is something to watch.
    public static func coarse(until deadline: Date, from now: Date) -> String {
        let (days, hours, minutes, _) = parts(until: deadline, from: now)
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private static func parts(
        until deadline: Date, from now: Date
    ) -> (days: Int, hours: Int, minutes: Int, seconds: Int) {
        let total = Int(max(0, deadline.timeIntervalSince(now)))
        return (total / 86_400, (total % 86_400) / 3_600, (total % 3_600) / 60, total % 60)
    }

    private static func pad(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
