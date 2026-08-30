import Foundation

extension WebDomain {
    /// Fifty web targets, enforced at input. `.specific` takes a set and Apple
    /// documents no ceiling; this one is ours (ADR 0006).
    public static let ceiling = 50

    /// The only way to make a `WebDomain`.
    ///
    /// Trim, lowercase, and keep the host: scheme, userinfo, path, query,
    /// fragment, port and any trailing dot are removed. `www` is preserved
    /// exactly as typed, because stripping or adding it would guess at matching
    /// rules Apple has not documented.
    ///
    /// Returns `nil` for an entry that canonicalizes to empty, holds internal
    /// whitespace, or has no dot in it. A host with no dot cannot match
    /// anything, so accepting one would put a line on the targets screen that
    /// blocks nothing.
    public static func canonicalize(_ typed: String) -> WebDomain? {
        var host = Substring(typed.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())

        if let schemeEnd = host.range(of: "://") { host = host[schemeEnd.upperBound...] }
        if let userinfoEnd = host.lastIndex(of: "@") { host = host[host.index(after: userinfoEnd)...] }
        if let pathStart = host.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }) {
            host = host[..<pathStart]
        }
        if let portStart = host.firstIndex(of: ":") { host = host[..<portStart] }
        while host.hasSuffix(".") { host = host.dropLast() }

        guard !host.isEmpty,
            host.contains("."),
            !host.contains(where: \.isWhitespace)
        else { return nil }

        return WebDomain(canonical: String(host))
    }

    /// Canonicalize, dedupe, and refuse the fifty-first — each of them
    /// silently. A refusal here is a flow rule rather than an error, so the app
    /// has no voice for it (ADR 0003).
    public static func add(_ typed: String, to existing: [WebDomain]) -> [WebDomain] {
        guard let domain = canonicalize(typed),
            !existing.contains(domain),
            existing.count < ceiling
        else { return existing }

        return existing + [domain]
    }
}
