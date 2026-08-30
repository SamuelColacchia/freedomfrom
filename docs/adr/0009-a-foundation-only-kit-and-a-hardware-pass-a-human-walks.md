# A Foundation-only kit whose tests are the contract, and a hardware pass a human walks

Testing splits cleanly along the line the SDK draws. `FreedomFromKit` imports **no Apple framework at all** and its tests are written **before** the code, from a named list the build spec carries. Everything else is verified by a human walking **two commitments** on a paired phone, with unified logging as the evidence and a sysdiagnose as the record. Two checks can block a build, and they are proven by a **walking skeleton** before v1 is written; the rest cannot block anything and each fires a pre-bound amendment instead.

## The boundary is forced, not chosen

ADR 0002 asserted that `FreedomFromKit` would get "real tests that run headless on the Mac via `swift test`". A probe of the build host (macOS 26.6, Xcode 26.6, Swift 6.3.3) turned that from an aspiration into a constraint with a hard edge:

| Probe | Result |
|---|---|
| `swift test` on the host | Works. ~9s cold, XCTest and swift-testing both run |
| `import FamilyControls` / `ManagedSettings` / `DeviceActivity` for macOS | Compiles, exit 0 |
| `import ManagedSettingsUI` for macOS | `no such module` — native macOS SDK does not have it, only the Catalyst slice |
| Naming `FamilyActivitySelection` on macOS | `cannot find type in scope` — the symbol is **absent from the macOS module**, not merely unavailable |
| Naming `ApplicationToken`, `WebDomainToken`, `Token<T>`, `Application`, `ManagedSettingsStore`, `DeviceActivitySchedule`, `DeviceActivityName`, `DeviceActivityCenter`, `AuthorizationCenter`, `AuthorizationStatus` on macOS | Every one is declared but `@available(macOS, unavailable)`; any macOS-available declaration mentioning them fails to compile |
| The one exception | `FamilyControlsError` is `@available(iOS 15.0, macOS 13.0, *)` and compiles once the package declares `platforms: [.macOS(.v13)]` |
| iOS Simulator | An iOS 26.5 runtime **is** installed, 11 devices, every type above typechecks clean for `arm64-apple-ios26.0-simulator`, and the simulator platform sets `CODE_SIGNING_ALLOWED = NO` |
| Device builds | `iPhoneOS.sdk` sets `AD_HOC_CODE_SIGNING_ALLOWED = NO` with signing and entitlements required, so a device test bundle needs the real identity that is still being established |

So importing is free and using is impossible. The kit is **Foundation-only**, and what crosses its seam is opaque handles, counts, and dates. The app owns every conversion to and from a `FamilyActivitySelection`; coverage becomes a set difference and a flag, which is what ADR 0005 described in prose.

## The test contract

The build spec ships these as named cases, written before their implementations. They are transcription of rules five ADRs already fixed, not new design.

**Deadline reconciliation** (ADR 0002) — holds before the deadline; releases at it; releases on a deadline already past at launch, silently.

**Walk-forward step** (ADR 0004) — a deadline inside one legal window yields a window ending at it; a distant deadline yields a 7-day window; a passed deadline yields nothing; the **final window starts at the deadline** and runs a further seven days; no window longer than 7 days is ever produced.

**Clamps** (ADR 0002, ADR 0004) — a duration under 15 minutes is refused; over 365 days is refused; a remembered length is re-anchored to now rather than restored as a stored date.

**Coverage and degradation** (ADR 0002, ADR 0005) — all handles resolving gives full coverage and no mark; a missing handle shrinks coverage and marks degraded; a degraded commitment whose handles all resolve again **stays degraded**, because the mark records how it ran.

**Domain canonicalization and the 50 rule** (ADR 0006) — scheme, path, query, port, and trailing dot stripped; lowercased; `www` preserved exactly as typed; duplicates collapse after canonicalization; the 51st domain is refused and nothing is said.

**The draft** (ADR 0008) — survives between commitments; survives an edit abandoned before the hold; a clean slate erases the draft and the history together.

**Outcome vocabulary** (ADR 0005) — completed, completed-degraded, broken; broken and degraded can both be true of one commitment; broken is recorded once and never re-marked; an unwitnessed commitment reads completed.

## The hardware pass

Two checks change the *architecture* when red, so they run first, on a **walking skeleton**: the real three targets with their real bundle IDs and entitlements, doing nothing but authorizing, picking, storing, shielding, and letting the extensions read. It is v1's first work item and it is kept, not thrown away. Built and launched for the **Simulator first**, which needs no signing, so a failure there is a code failure rather than a signing one.

- **The Keychain access group readable from an extension.** Red re-adds the App Group ADR 0002 removed — a portal toggle and a line of YAML per target, no migration, because it holds nothing.
- **`ShieldConfig` mutating a `ManagedSettingsStore` inside its memory budget.** Red drops ADR 0004's third reconciliation point in favour of its deferred local notification, and drops ADR 0005's self-shield fix in favour of accepting a self-shield.

Everything else is observed during two real commitments, because three of the checks are destructive: revoking, deleting, and forcing token churn each mark a commitment broken, and a broken commitment contaminates every later observation of a clean one. So one clean 15-minute run proves the happy path including a real release, and one sacrificial run collects the breaks. Roughly 40 minutes, most of it waiting. The order inside the sacrificial run is forced: **revoke before deleting**, because if `denyAppRemoval` bites, the app cannot be deleted until authorization is gone.

The checklist lives at [`docs/hardware-smoke-checklist.md`](../hardware-smoke-checklist.md), and each check names its amendment before it runs, so a red result triggers a decision instead of reopening one.

## What the app logs

`log stream --device` no longer exists on macOS 26.6 and `devicectl` has no log subcommand, so the record is `devicectl device sysdiagnose` followed by `log show --archive … --predicate 'subsystem == "com.samuelcolacchia.freedomfrom"'` on the Mac. Console.app remains a live view for whoever is sitting at the machine; it is a convenience, not the record.

That makes the logging contract load-bearing. Subsystem `com.samuelcolacchia.freedomfrom`, one category per process (`app`, `monitor`, `shieldconfig`), **permanent in release builds**, and:

- **Public**: whether the Keychain record was read, whether a store mutation landed, resolved-of-named coverage counts, the absolute deadline, which window was registered, release and how late it was, and every break or degrade mark.
- **Never logged at all**: target identities. No bundle identifiers, no tokens, no domain strings. Nothing on the checklist needs to know *which* app was shielded, only how many resolved, and dropping identities entirely is a cleaner rule than redacting them case by case.

Default `os_log` redaction would print `<private>` for every interpolated value, which is why the public half has to be deliberate: a coverage count of 2-of-3 **is** the observation, and a redacted line makes the run unfalsifiable. One category per process is what keeps "the monitor never woke" distinguishable from "the monitor woke and found nothing".

This does not give the app a voice. ADR 0005 forbids the app telling the user things go wrong, and ADR 0007 fixes its screens at seven. A log is neither.

## What gates a TestFlight invite

Not a green checklist — an all-green gate would deadlock on questions nobody can answer, like what Brave does with a `.specific` filter. The gate is that **both runs have happened and the app's claims have been reconciled against what they showed**. A red result changes what the app says, not whether it ships.

This matters most for one check. ADR 0003 rests all of informed consent on a single first-run sentence. If `denyAppRemoval` silently no-ops under `.individual`, that sentence claims a restriction that does not exist — a known unknown for the developer, and a false claim for a stranger.

## Considered options

**Tests as a safety net written after the code (rejected).** With no paired device, these tests are the only executable feedback in the entire project, and tests written afterwards get written to match the code. There is nothing else here that would catch that.

**The kit imports the frameworks and its tests run in the unsigned Simulator (rejected).** Tempting, because the Simulator is genuinely free: no signing, every type available today. But it buys the ability to *name* those types, not to *construct* them — `Token`'s only public initializer is `init(from decoder:)`, so a test cannot mint an `ApplicationToken` without a blob captured from a real device. The blocker is hardware, and the Simulator supplies none of it, at the cost of an `xcodebuild` loop instead of a nine-second one.

**A pure core plus a thin iOS layer tested in the Simulator (rejected).** Two suites and two runners for a layer that still cannot construct the one thing worth asserting about.

**An on-device XCTest bundle for the two mechanical checks (rejected).** A fourth signed target, dependent on the same identity chain that is not yet working, to assert two facts a log line already proves.

**A debug-build diagnostic screen (rejected).** The only option that damages the product: an eighth screen, in an app whose navigation ADR explicitly inventoried what it refused a settings surface for.

**App-mediated evidence, extensions writing to the Keychain for the app to report (rejected).** Circular. The Keychain access group is the thing under test, so its failure is silence — indistinguishable from an extension that never woke. The unified log separates those two because each process writes its own lines regardless.

**A throwaway tracer instead of a kept skeleton (rejected).** It would discard the `project.yml`, the entitlements, and the record codec, each of which took a ticket to decide.

**Seven independent probes instead of a spine (rejected).** Seven setups, seven waits, seven chances to mis-configure, to observe things a single real commitment surfaces at their natural moments.

**`log stream --device` (not available).** Removed in macOS 26.6. Recorded so nobody proposes it again.

## Consequences

- **The kit's API is fixed by the seam.** It speaks in handles, counts, and dates. Anything that must hold a `FamilyActivitySelection` lives in the app target and is therefore not headless-testable — a cost paid deliberately to keep the loop fast and the claim true.
- **The walking skeleton is work item one of the build spec**, and it is the first thing that exercises the whole headless build-sign-install chain, so it doubles as proof of the workflow and identity decisions.
- **The evidence channel is itself unverified.** Whether a sysdiagnose contains this subsystem's lines cannot be known until a device is paired, so it is the checklist's own first line, with Console.app as its fallback.
- **The app gains permanent logging** — the first thing it emits that is not a screen, and the only signal a TestFlight tester can ever return from a wordless app.
- **One check moves earlier than its bucket suggests.** Whether a `FamilyActivitySelection` decoded from the Keychain hands back to `FamilyActivityPicker` with its apps checked is observed on the skeleton, not in the runs. It cannot block a build, but its red result *deletes* a decided behaviour — ADR 0008's draft would keep only web domains and length — and the skeleton needs the picker anyway to have a token to shield.
- **One accumulated check is dropped as obsolete.** "Can a never-visited site be picked cold" came from the web-domain research, but ADR 0006 chose typed domains over picker tokens, so nothing in v1 picks a site.
- **`CONTEXT.md` gains nothing.** Structural gate, claim-filler, and walking skeleton are process vocabulary, and the glossary is a domain glossary.
