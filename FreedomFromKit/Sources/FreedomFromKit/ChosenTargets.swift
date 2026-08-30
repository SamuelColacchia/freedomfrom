import Foundation

/// What a target set is made of, with apps and categories held apart.
///
/// The system picker returns a whole category as **one** token with
/// `applicationTokens` left empty, so a count that flattens the two reports a
/// category as `1 app` — fewer, and the wrong noun, for a set that shields more.
/// That lands in the sentence ADR 0003 rests all of informed consent on, so the
/// two kinds stay separate all the way to the screen.
///
/// The app cannot do better than naming the kind: `ActivityCategoryToken` is
/// opaque and nothing in Screen Time enumerates a category's members, so how
/// many apps a category covers is not knowable here.
public struct ChosenTargets: Equatable, Sendable {
    public let apps: Int
    public let categories: Int

    public init(apps: Int = 0, categories: Int = 0) {
        self.apps = apps
        self.categories = categories
    }

    /// Every token the picker minted, of either kind — which is what the store
    /// is told to shield, and so what coverage counts. The arithmetic was never
    /// the wrong part.
    public var picked: Int { apps + categories }

    public var isEmpty: Bool { picked == 0 }

    public var words: String { words(alsoDomains: 0) }

    /// `2 apps, 1 category and 2 websites` — every kind that has any named, and
    /// no kind that does not. Empty when nothing is chosen, because a screen
    /// that has nothing to say says nothing (ADR 0003).
    public func words(alsoDomains domains: Int) -> String {
        let parts = [
            Self.count(apps, "app"),
            Self.count(categories, "category", plural: "categories"),
            Self.count(domains, "website"),
        ].compactMap { $0 }

        guard let last = parts.last else { return "" }
        guard parts.count > 1 else { return last }
        return parts.dropLast().joined(separator: ", ") + " and " + last
    }

    private static func count(_ n: Int, _ noun: String, plural: String? = nil) -> String? {
        guard n > 0 else { return nil }
        return "\(n) \(n == 1 ? noun : plural ?? noun + "s")"
    }
}
