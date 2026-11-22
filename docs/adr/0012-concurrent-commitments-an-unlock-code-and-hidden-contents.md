# Concurrent commitments, an unlock code, and hidden contents

freedomfrom now runs **any number of commitments at once**, each with its own targets and deadline, and each can be **ended early on its own** with one app-owned **unlock code**. What a commitment blocks is **hidden until Face ID or the device passcode passes**; its countdown never is.

This reverses part of ADR 0001. That ADR refused an in-app escape hatch on the grounds that Settings → Screen Time → revoke already is one. The owner asked for a separate early exit per commitment, gated by a code like a Screen Time passcode. The app cannot use the real Screen Time passcode: **there is no public API to set, verify or detect it** (ADR 0001), and the one place iOS asks for it, the revoke, ends every commitment at once. So the code is the app's own. It is global: one code unlocks any single commitment.

## Decisions

| | |
|---|---|
| Concurrency | `Record.commitments` replaces `Record.active`. Commitments never merge, and a target stays held while any of them names it (#73) |
| Migration | A record written before this holds `active`. It decodes as a single running commitment, keeping its deadline and its marks, and is never written back under the old key |
| Enforcement | **One store holding the union** of every running commitment. Ending one reapplies the rest. A store per commitment was rejected because nothing on hardware has shown how iOS composes stores, and the 50-domain ceiling (#80) counts across all of them anyway |
| Watchdog | **One activity, walked toward the nearest deadline.** When it releases, the next reconciliation registers toward the next nearest. That uses 1 of the 20 activities iOS allows |
| `ShieldConfig` mirror | Holds the **furthest** deadline. It releases everything once the mirror has passed, so a nearer deadline there would lift a later commitment early. A mirror that fails to write is removed rather than left stale. The cost is that a shield can overstate how long a target from a shorter commitment stays held |
| Domain budget | A commitment whose domains would take the unique total past 50 is refused before the hold. Past that limit, iOS silently filters nothing (#80) |
| Unlock code | A salted SHA-256 digest in the Keychain record. At least four characters. It can be set, changed or removed **only while nothing runs**, and changing or removing it needs the current code. A clean slate leaves it alone. With no code set, nothing ends before its deadline |
| Settings | The code lives on a Settings screen, reachable from Targets and from the running list. While anything runs it shows whether a code is set, and nothing on it can be edited |
| Unlock | Removes that commitment, files it with a fourth outcome, `unlocked`, and reapplies the rest in the same read-modify-write. No "Ended." screen follows |
| Breaks and degradation | An observed break marks every running commitment, since an authorization loss reaches all of them. A lost target degrades only the commitment it was measured on |
| Hidden contents | Targets, domains, counts and coverage are hidden on the running list and in the history until LocalAuthentication's `.deviceOwnerAuthentication` passes. Revealing lasts until the app backgrounds. A device with no passcode reveals, because nothing locks the phone itself |

## Consequences

- **The honest claim weakens.** Whoever holds the unlock code can end any commitment early. If the owner holds it, the commitments restrain nothing that a moment's typing can't undo. The copy says to give it to someone trusted, and it does not pretend otherwise.
- **The draft is not hidden.** It is what you would commit to next, and it shows on Targets as before.
- **New hardware checks:** two overlapping commitments releasing one at a time, with the second still shielding; an unlock lifting only its own targets; the mirror's furthest deadline holding a shield past a shorter commitment's release; Face ID prompting on a device.
- **Not built here:** adding targets to or extending a running commitment, and naming commitments (#73). The decisions in #73 still stand for whenever that work happens.
