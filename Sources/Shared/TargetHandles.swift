import FamilyControls
import Foundation
import FreedomFromKit

/// The one place a `FamilyActivitySelection` becomes something the kit can hold.
///
/// The kit may not name a Screen Time type (ADR 0009), so every conversion in
/// the project happens here and what crosses the seam is handles, counts and
/// bytes. Compiled into all three signed targets because the app mints handles
/// at commit and `Monitor` re-mints them at every reconciliation.
enum TargetHandles {
    /// A handle per token, minted as the base64 of the token's encoding.
    ///
    /// A token that churns encodes differently and so yields a different
    /// handle, which is the only signal available that a target no longer
    /// resolves. Whether it fires at all is hardware check X4.
    static func mint(from selection: FamilyActivitySelection) -> [TargetHandle] {
        (handles(selection.applicationTokens) + handles(selection.categoryTokens))
            .sorted { $0.value < $1.value }
    }

    /// The same two sets, counted apart rather than summed.
    ///
    /// A whole category arrives as one token with `applicationTokens` empty, so
    /// the flattened count of `mint` reads as `1 app` on screen for a set that
    /// shields many. What is enforced is unchanged; only the noun was wrong.
    static func counts(from selection: FamilyActivitySelection) -> ChosenTargets {
        ChosenTargets(
            apps: handles(selection.applicationTokens).count,
            categories: handles(selection.categoryTokens).count
        )
    }

    private static func handles<Token: Encodable & Hashable>(
        _ tokens: Set<Token>
    ) -> [TargetHandle] {
        let encoder = JSONEncoder()
        return tokens.compactMap { token in
            (try? encoder.encode(token)).map { TargetHandle($0.base64EncodedString()) }
        }
    }

    static func encode(_ selection: FamilyActivitySelection) -> Data? {
        try? JSONEncoder().encode(selection)
    }

    /// `nil` when the stored bytes no longer decode at all, which reads
    /// downstream as coverage of zero rather than as an error: a commitment
    /// whose targets cannot be found is degraded, and its deadline stands.
    static func decode(_ data: Data?) -> FamilyActivitySelection? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }
}
