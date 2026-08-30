import Foundation
import Testing

@testable import FreedomFromKit

/// Displayed, stored, and applied are always the same string (ADR 0006), which
/// is why only canonicalization may construct a `WebDomain`.
@Suite("A typed string becomes a canonical host, or nothing")
struct CanonicalizationTests {
    @Test("everything but the host is stripped")
    func stripsEverythingButTheHost() {
        let typed = "  HTTPS://user:pass@WWW.Example.COM.:8443/path/here?q=1#frag  "
        #expect(WebDomain.canonicalize(typed)?.host == "www.example.com")
    }

    @Test("the scheme goes")
    func scheme() {
        #expect(WebDomain.canonicalize("https://example.com")?.host == "example.com")
        #expect(WebDomain.canonicalize("http://example.com")?.host == "example.com")
    }

    @Test("userinfo goes")
    func userinfo() {
        #expect(WebDomain.canonicalize("user@example.com")?.host == "example.com")
        #expect(WebDomain.canonicalize("user:pass@example.com")?.host == "example.com")
    }

    @Test("path, query and fragment go")
    func pathQueryFragment() {
        #expect(WebDomain.canonicalize("example.com/a/b")?.host == "example.com")
        #expect(WebDomain.canonicalize("example.com?q=1")?.host == "example.com")
        #expect(WebDomain.canonicalize("example.com#top")?.host == "example.com")
    }

    @Test("the port goes")
    func port() {
        #expect(WebDomain.canonicalize("example.com:8080")?.host == "example.com")
    }

    @Test("a trailing dot goes")
    func trailingDot() {
        #expect(WebDomain.canonicalize("example.com.")?.host == "example.com")
    }

    @Test("it is lowercased and trimmed")
    func lowercasedAndTrimmed() {
        #expect(WebDomain.canonicalize("  EXAMPLE.CoM \n")?.host == "example.com")
    }

    @Test("www is preserved exactly as typed, on both sides")
    func wwwIsPreserved() {
        // Stripping or adding it would guess at matching rules Apple has not
        // documented, so neither is done.
        #expect(WebDomain.canonicalize("www.example.com")?.host == "www.example.com")
        #expect(WebDomain.canonicalize("example.com")?.host == "example.com")
    }

    @Test("an entry with no dot is refused")
    func noDot() {
        #expect(WebDomain.canonicalize("example") == nil)
        #expect(WebDomain.canonicalize("localhost") == nil)
    }

    @Test("an entry with internal whitespace is refused")
    func internalWhitespace() {
        #expect(WebDomain.canonicalize("exa mple.com") == nil)
    }

    @Test("an entry that canonicalizes to empty is refused")
    func canonicalizesToEmpty() {
        #expect(WebDomain.canonicalize("") == nil)
        #expect(WebDomain.canonicalize("   ") == nil)
        #expect(WebDomain.canonicalize("https://") == nil)
        #expect(WebDomain.canonicalize(".") == nil)
        #expect(WebDomain.canonicalize("/path/only") == nil)
    }
}

@Suite("The domain list dedupes, and stops at fifty")
struct DomainListTests {
    private func list(_ hosts: [String]) -> [WebDomain] {
        hosts.reduce(into: [WebDomain]()) { $0 = WebDomain.add($1, to: $0) }
    }

    @Test("a valid entry is appended")
    func appends() {
        #expect(list(["example.com", "other.com"]).map(\.host) == ["example.com", "other.com"])
    }

    @Test("a refused entry leaves the list alone")
    func refusedLeavesItAlone() {
        let existing = list(["example.com"])
        #expect(WebDomain.add("nodot", to: existing) == existing)
        #expect(WebDomain.add("   ", to: existing) == existing)
    }

    @Test("duplicates collapse after canonicalization, not before")
    func dedupesAfterCanonicalization() {
        let hosts = list(["example.com", "HTTPS://Example.com/path", "example.com."]).map(\.host)
        #expect(hosts == ["example.com"])
    }

    @Test("www.example.com and example.com are two different domains")
    func wwwIsNotADuplicate() {
        #expect(list(["example.com", "www.example.com"]).count == 2)
    }

    @Test("the fifty-first is refused, and nothing is said")
    func theCeiling() {
        let fifty = list((1...50).map { "site\($0).com" })
        #expect(fifty.count == 50)

        let after = WebDomain.add("site51.com", to: fifty)
        #expect(after == fifty)
    }
}
