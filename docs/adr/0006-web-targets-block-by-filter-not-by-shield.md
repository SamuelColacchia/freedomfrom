# Web targets block by filter, not by shield

`ShieldSettings.webDomains` takes only picker-minted `WebDomainToken`s, so a hand-typed domain cannot produce a shield. v1 applies web targets through `ManagedSettingsStore.webContent.blockedByFilter = .specific(Set<WebDomain>)`, which does accept domains built from strings. **Typed domains stay; the shield they were assumed to produce does not.**

This supersedes the web-domain clause of ADR 0003. That clause's reason — a typed domain is the only part of a target set the app can read back to you — survives whole, and is exactly what selects the filter over the alternative.

## The decision

| | |
|---|---|
| Mechanism | `webContent.blockedByFilter = .specific(Set<WebDomain>)`, on ADR 0002's one named store, set to `.none` at release |
| What a blocked site shows | Apple's own page. No overlay, no countdown, nothing freedomfrom can style |
| Ceiling | 50 domains, enforced at input. The 51st cannot be added, and nothing is said about it |
| A domain is | A host, canonicalized: lowercased, with scheme, path, query, port, and trailing dot removed. `www` is kept exactly as typed |
| Collateral | Safari Private Browsing is off while a commitment with web targets runs, stated on the targets screen |
| The claim about browsers | None. The app names no browser until hardware names one |

## What this changes elsewhere

**A commitment exists if its enforcement applied, not if its shield did.** ADR 0005's precondition was written when every target was shielded; read literally it now refuses a website-only commitment, because nothing touches `shield`. What the rule was defending against was a countdown over nothing, and `blockedByFilter` is exactly as much enforcement as a shield is. So it generalizes: apps are held by a shield, web domains by the filter, and a commitment is written when what it named was applied. Everything ADR 0005 built on that rule is untouched.

**Web targets cannot degrade.** A typed string always resolves. ADR 0002's degrade-on-unresolvable-token rule and ADR 0005's coverage recomputation stay exactly as they are, but only app targets can ever trip them. A website-only commitment can be broken; it can never be degraded.

**`ShieldConfig` narrows to apps.** It stays in ADR 0002's three-target topology unchanged, because both of its other jobs — ADR 0004's reconciliation point, ADR 0005's self-shield fix — are app-only by nature. Two consequences follow. ADR 0003's countdown in the dark is never seen for a website. And a website-only commitment never wakes the extension, leaving two of ADR 0004's three reconciliation points, which changes nothing that matters: the release still arrives late rather than early.

**The targets screen gains one web-specific line, and first run does not.** ADR 0003 promoted the first-run collateral sentence to full weight because it states what *every* commitment does. Private Browsing and browser coverage are conditional on having typed a domain, so they belong where domains are typed. The Private Browsing half is documented and can be written now; the browser half stays empty until the hardware smoke test says which browsers a `.specific` filter actually covers. This is not an anomaly voice of the kind ADR 0005 forbids: it is a fact about what you are buying, known before you commit.

## Considered options

**Picker tokens on the shield (rejected).** `FamilyActivityPicker` mints `WebDomainToken`s that `shield.webDomains` accepts, which buys a styled overlay and one selection UI for both kinds of target. It was rejected on what it costs: the targets screen collapses to an opaque count, which deletes the only words in the app and the only thing the history can name. The overlay it buys is nearly empty by ADR 0003's own decision — a countdown in the dark — so the trade is words for styling. Tokens would also make web targets churnable, extending degradation to the half of the model that need never have it, and cold-site selection is UNVERIFIED with forum reports saying entries appear only after use.

**Both mechanisms (rejected).** Type for the filter, pick for the shield. Two representations of one concept, two failure modes, two code paths, and two visual treatments of being blocked, in a product whose whole design argument was one voice.

**Silent capping at 50, or ignoring the limit (rejected).** Capping writes a set the targets screen and the history both contradict, which is the coverage lie ADR 0005 spent its length avoiding. Ignoring bets the entire web half on undocumented overflow behaviour: Apple documents the ceiling but not what happens past it, and there is no read-back to notice the policy was dropped.

**Stripping or adding `www`, or expanding an entry into variants (rejected).** Both guess at matching rules Apple has not documented. Expanding also spends the 50-domain budget on guesses and puts entries on screen that nobody typed, which breaks the equality the filter path was chosen for: displayed, stored, and applied must be the same string. Removing scheme, path, query, port, case, and trailing dot guesses at nothing, because none of them are part of a host.

**Saying nothing about Private Browsing (rejected).** It is minor, and for this product arguably desirable. Rejected because it would have the app quietly change a Safari setting the user never asked about, which inverts ADR 0001's stance of naming exits rather than concealing them.

**Dropping web targets from v1 until hardware confirms coverage (not offered).** Nothing about the choice waits on hardware: both representations are expressible today, and the unverified parts are smoke-test items, not decision inputs. Web targets are half the blocking surface fixed during charting.

## Consequences

- **Two items join the hardware smoke checklist**, both of which the app is now forbidden to guess about: which browsers a `.specific` filter actually covers, and whether a bare domain covers its subdomains. Until they are answered the app blocks what it was told to block and claims nothing.
- **`FreedomFromKit` gains domain canonicalization and the 50-domain rule.** Both are pure string logic with no device dependency, so they join deadline reconciliation and coverage computation as things testable headless on the Mac — which matters while hardware access is still zero.
- **The commitment history can name web targets in words.** It is the only readable thing in a record otherwise made of counts, and it is now permanent rather than conditional on an unverified API.
- **Selecting nothing but websites is a first-class case.** ADR 0005's rule that the commit screen is unreachable with nothing selected is unchanged; what changed is that one typed domain is enough to reach it.
- **The 51st domain is a flow rule, not an error.** The targets screen already shows a count; the ceiling expresses itself as a count that stops growing, which needs no voice, in the same way an unreachable commit button needs none.
- **`CONTEXT.md` gains two terms** (filter, enforcement) and sharpens three (shield, coverage, release), because "shield" was doing the work of "whatever is holding a target" and can no longer.
