# freedomfrom v1 build spec

The destination of [the wayfinder map](https://github.com/SamuelColacchia/freedomfrom/issues/1). Every decision made on that map, folded into one document an `/implement` session can execute cold. Nothing here needs the map to be read first.

**How to read this against the ADRs.** The ten ADRs in [`docs/adr/`](./adr/) hold the *reasoning* — what was considered, what was rejected, and why. This spec holds the *instruction*. Where they disagree, the ADRs are the authority on intent and this document is the authority on what to build; three places where this spec had to sharpen an ADR beyond what it literally said are marked **Sharpened here** and say so out loud.

**The honest claim, which the app's own copy may never exceed:** freedomfrom resists casual bypass while authorized. It cannot prevent a determined bypass.

---

## Problem Statement

I want to stop opening certain apps and certain websites, and I cannot rely on myself to stop. Every mechanism I have tried is one I can undo the moment I want to undo it, which is exactly the moment I will want to. Apple's own Screen Time is built for a parent configuring a child's device: it assumes a second person holds the passcode. There is no second person here. I am both the person setting the restriction and the person it restrains.

What I need is something I can bind myself to in a moment of resolve, that holds through the moments when the resolve is gone, and that is honest with me about the fact that I could still get out if I truly wanted to — rather than pretending to a strength it does not have.

## Solution

freedomfrom is an iOS app for one person restraining themselves. You choose the apps and websites you want blocked, choose how long, and hold a button to commit. From that moment until the deadline, the apps are shielded, the websites are filtered, and the app offers you no way to lift it early.

It resists the three ways out with what it can apply itself: it blocks app deletion device-wide and forces automatic date and time for the commitment's duration. The one route it cannot close — revoking Family Controls authorization in Settings, fifteen seconds behind a Face ID scan — it names plainly in the app rather than hiding, and it writes down that you took it. What it offers when enforcement fails is not a stronger lock but an honest mirror.

The app says almost nothing. Seven screens, one statement and one action each. It does not argue with you, congratulate you, or scold you. The only ceremony is the hold, and a hold means this cannot be undone.

---

## User Stories

**Committing**

1. As someone trying to stop using an app, I want to choose which apps get blocked from the system picker, so that I do not have to type or remember bundle identifiers.
2. As someone trying to stop visiting a website, I want to type its domain by hand, so that I can block a site I have never visited and can read back exactly what I chose.
3. As someone assembling a target set, I want to see what I have chosen before committing, so that I am not committing blind.
4. As someone who has typed a domain wrong, I want to remove it before committing, so that a typo does not cost me a week of a site I meant to keep.
5. As someone choosing a duration, I want a short list of common lengths I can tap, so that choosing a month takes no more thought than choosing an hour but no less either.
6. As someone who wants a specific end date, I want to pick one from a calendar, so that "until the exam" is expressible.
7. As someone about to commit, I want the resulting deadline stated in words, so that "30 days" and "until 28 September" are the same fact and I have seen both.
8. As someone committing, I want the act to be a hold rather than a tap, so that I cannot do it by accident and the gesture matches the weight.
9. As someone committing to a year, I want the hold to be longer than the hold for fifteen minutes, so that the gesture costs what the commitment costs.
10. As someone who committed yesterday and wants the same again, I want my last targets and length still on screen, so that re-committing is two gestures and not a re-assembly.
11. As someone interrupted mid-setup, I want my half-built target list to survive, so that a phone call does not cost me fifteen typed domains.
12. As a first-time user, I want to be told before I commit that no app can be deleted on this phone while a commitment runs, so that the most surprising consequence is not a surprise.

**While a commitment runs**

13. As someone who opens a blocked app out of habit, I want a countdown rather than an explanation, so that there is nothing to argue with.
14. As someone who visits a blocked site, I want it blocked in the browser, so that the website half of my commitment is as real as the app half.
15. As someone who typed a domain, I want to be told that Safari's Private Browsing switches off while the commitment runs, so that a setting I did not ask about does not change silently.
16. As someone mid-commitment, I want to open the app and see exactly how long is left, so that I never have to guess.
17. As someone mid-commitment, I want the app to tell me how many of my targets are actually being enforced right now, so that I know whether I am as covered as I think.
18. As someone mid-commitment who wants out, I want the app to tell me plainly where the exit is and what it costs, so that I am not tricked into thinking there is no exit.
19. As someone who took the exit, I want it written down rather than announced, so that the record is honest and the app does not lecture me.
20. As someone who deleted the app mid-commitment and reinstalled it, I want it to pick up exactly where it was, so that delete-and-reinstall is not a free reset.
21. As someone who revoked authorization and changed my mind, I want the app to re-arm when I grant it again, so that a moment of weakness does not end a month of commitment.
22. As someone whose phone was off across the deadline, I want the commitment to lift as soon as the phone is next used, so that a flat battery does not extend a block indefinitely.
23. As someone who committed only to websites, I want that to work exactly as well as committing to apps, so that half the product is not second-class.
24. As someone who accidentally picked freedomfrom itself as a target, I want the app to remain usable, so that one mis-tap does not lock me out of my own countdown for a year.

**Afterwards**

25. As someone whose commitment just ended, I want to be told once that it ended, so that the release is acknowledged without being celebrated.
26. As someone reviewing my own behaviour, I want a list of past commitments and how each one ended, so that I have an honest record.
27. As someone reading that record, I want it to say in plain words whether a commitment was completed, completed with lost coverage, or broken, so that I do not have to decode a symbol.
28. As someone who wants none of this on my phone any more, I want one deliberate action that erases the history and my saved list together, so that deleting the app is not the only route and does not leave residue behind.
29. As someone erasing that record, I want the action to require the longest hold in the app, so that the biggest irreversible thing is not a one-tap footgun.

**Building it**

30. As the developer, I want to compile the app from my Linux machine without touching a Mac GUI, so that an agent can iterate all day unattended.
31. As the developer, I want a compile failure to come back as `file:line:col` with the message, so that fixing it needs no second lookup.
32. As the developer, I want the app's own log lines back from the simulator, so that I can verify behaviour months before a phone is cabled.
33. As the developer, I want the pure logic tested headlessly in seconds, so that the only executable feedback in the project is fast enough to use.
34. As the developer, I want to be told what still needs me physically present before a long build runs, so that I am not waiting on an archive to learn I needed a cable.
35. As the developer, I want a checklist of what only real hardware can answer, each with the amendment it triggers when red, so that a surprising result is a decision rather than a reopening.

---

## Implementation Decisions

### 1. The dev workflow

Decided by [ADR 0010](./adr/0010-the-mac-is-a-mirror-and-a-simulator.md); the commands are already in [`AGENTS.md`](../AGENTS.md) and [`scripts/mac`](../scripts/mac) exists. The implementer inherits this rather than building it.

- **This repo is the only source of truth.** Every verb rsyncs it destructively into `~/builds/freedomfrom/src` on the Mac. There is no `sync` verb, so a stale mirror is unreachable rather than merely unlikely. Nothing on the Mac is ever edited or committed from.
- **The daily loop is the iOS Simulator**, which ad-hoc signs — so no identity, no keychain, and no person. `scripts/mac build` is 1.7s warm on a one-file probe; three targets and a package will be slower cold, and warm incremental is the number that matters.
- **`scripts/mac test`** runs `swift test` on `FreedomFromKit` on the Mac, against Darwin Foundation. Not on Linux: the kit's subject matter is calendar arithmetic, which is exactly where the two Foundations diverge.
- **`scripts/mac run [secs]`** builds, launches on the simulator, and prints the app's own `os_log` lines by predicate. This is how the logging contract in §10 is verified before any device is cabled.
- **`scripts/mac device`** signs and installs on the phone, and needs a human: the phone must be cabled, and the login keychain must be unlocked inside a shared SSH `ControlMaster` session. It probes both in under a second and **prints** the unlock lines for a human to run in their own shell. Do not run them; do not ask for the password.
- **Never run `xcodebuild`, `xcodegen`, `swift test`, or `simctl` by hand.**
- **No CI.** Not an oversight; see the ADR.

Two facts inherited from [issue #13](https://github.com/SamuelColacchia/freedomfrom/issues/13):

- **Family Controls needs no Apple approval for development.** Proven by installing a signed app carrying `com.apple.developer.family-controls` on the iPhone. Distribution is a separate matter, tracked on [issue #10](https://github.com/SamuelColacchia/freedomfrom/issues/10), and off the critical path for building.
- **The entitlement cannot be attached through the App Store Connect API.** `FAMILY_CONTROLS` is absent from its `capabilityType` enum, so `-allowProvisioningUpdates` must do it. Registering a *device* to the team, conversely, must go through the ASC API, because Xcode will not do it headlessly.

### 2. Target topology and identifiers

Decided by [ADR 0002](./adr/0002-v1-target-topology-and-a-keychain-only-data-model.md). Team ID `6989TSP54U`, Individual enrolment, automatic signing.

| Target | Type / extension point | Bundle ID |
|---|---|---|
| `FreedomFrom` | application | `com.samuelcolacchia.freedomfrom` |
| `Monitor` | app-extension · `com.apple.deviceactivity.monitor-extension` | `com.samuelcolacchia.freedomfrom.monitor` |
| `ShieldConfig` | app-extension · `com.apple.ManagedSettingsUI.shield-configuration-service` | `com.samuelcolacchia.freedomfrom.shieldconfig` |
| `FreedomFromKit` | local SwiftPM package — no App ID, not signed | — |

- Every signed target carries exactly two entitlements: `com.apple.developer.family-controls`, and a keychain access group of `$(AppIdentifierPrefix)com.samuelcolacchia.freedomfrom`.
- Shared build settings: `IPHONEOS_DEPLOYMENT_TARGET 26.0`, `TARGETED_DEVICE_FAMILY "1,2"`, `CODE_SIGN_STYLE Automatic`, `DEVELOPMENT_TEAM 6989TSP54U`.
- Both extensions and the package build with `APPLICATION_EXTENSION_API_ONLY YES`; the extensions also set `SKIP_INSTALL YES`.
- **There is one App Group**, `group.com.samuelcolacchia.freedomfrom`, on all three targets. It holds the running commitment's deadline and nothing else. Hardware check S1 came back red for `ShieldConfig` alone — that process has no Keychain at all, `errSecNotAvailable` on both read and write under a correct entitlement — so the deadline reaches the shield through the shared container. See the amendment on [ADR 0002](./adr/0002-v1-target-topology-and-a-keychain-only-data-model.md). `-allowProvisioningUpdates` creates the group unattended; no portal visit is needed.
- **No `ShieldAction` extension.** The decided shield has no button, so there is nothing for it to do. Adding it later is a `project.yml` block and a folder.
- **Project generation is XcodeGen.** `project.yml` is committed; the generated `.xcodeproj` is gitignored and regenerated on every sync.
- **`Package.swift` needs `swift-tools-version:6.2`.** Naming `.iOS(.v26)` under 6.0 fails with `'v26' is unavailable`. Declare `platforms: [.iOS(.v26), .macOS(.v13)]` so the kit's tests can run on the Mac.

**Sharpened here: the package has two targets, not one.** [ADR 0009](./adr/0009-a-foundation-only-kit-and-a-hardware-pass-a-human-walks.md) requires `FreedomFromKit` to import no Apple framework, which leaves the `SecItem` calls with nowhere shared to live and would otherwise triplicate them across three signed targets. So:

- **`FreedomFromKit`** — Foundation only. All logic, all types, the record's `Codable` shape and its codec. This is the tested target.
- **`FreedomFromPlatform`** — imports `Security`, `os`, and `FreedomFromKit`. Everything that touches an Apple framework and holds no logic: the `SecItem` record store, and the logging contract of §10 expressed as named events rather than a free-form `log(_:)`. Not headlessly testable and not tested; its failure mode is hardware check S1.

> The logger belongs here rather than in each target because the subsystem string and the public-versus-never-logged rule would otherwise be restated three times, in a contract ADR 0009 calls load-bearing. That is also why this target is named for the boundary it sits on rather than for the store alone.

### 3. The data model

One Keychain record. Access group `$(AppIdentifierPrefix)com.samuelcolacchia.freedomfrom`, `kSecAttrAccessibleAfterFirstUnlock`, explicitly non-synchronizable, a single `kSecClassGenericPassword` item holding JSON. There is no second store and no mirror, so there is never a question of which copy is right.

The record holds four things:

| | |
|---|---|
| The **active commitment**, or none | started-at, absolute deadline, the encoded `FamilyActivitySelection`, the target handles named at commit, the canonical web domains, and the degraded and broken marks |
| The **commitment history** | one closed commitment per entry, with its outcome |
| The **draft** | the domains and the chosen length. **Amended by S3:** the encoded selection and the app-target count were here until hardware check S3 came back red; apps are now re-picked every time and live only in the session that picked them |
| Two **flags** | whether first run has been shown, and whether an "Ended." screen is pending |

Three rules follow, and they are the point of the design:

- **The deadline is authoritative.** Absolute wall-clock time. Nothing shortens it. Everything reconciles against it rather than trusting a `DeviceActivity` callback to arrive.
- **A target that no longer resolves degrades coverage, never duration.** It is dropped from what is applied, the commitment is marked degraded, and the deadline stands.
- **A break is a surviving record met by a fresh install.** Because the record outlives app deletion, an app that launches and finds a commitment still running knows it was deleted mid-commitment. That is the only signal available.

**One value lives outside the record**, and only one: the running commitment's deadline, mirrored into the App Group at commit and cleared at release. `ShieldConfig` reads it; nothing else does. It is derived and never authoritative, it is an atomic file write rather than `UserDefaults`, and a stale copy can only cost a wrong number on a shield or a late release, never an early one.

**Sharpened here: a second thing lives outside the record, and it holds no value at all.** The break rule above says an app that launches and finds a commitment still running knows it was deleted mid-commitment. Read literally that is every launch, which would mark every commitment broken the second time it was opened. The missing half is a zero-byte marker in the app's *own* sandbox — the one store here that does **not** survive deletion. Record present, marker absent, therefore this install is not the one that committed. It carries nothing; its existence is the whole signal, so a read failure and an absent file are deliberately the same answer.

Two smaller consequences of building it: the deadline mirror is written at **every** reconciliation rather than only at commit, so a mirror lost to a reinstall is repaired rather than left missing for the life of the commitment; and release writes `nil` to `webContent.blockedByFilter` rather than the `.none` written at §7, because that property is an optional whose wrapped type also has a `none` case and `.none` would resolve to `Optional.none` regardless. Unset is what release means.

**The two flags are not part of "everything you authored."** A clean slate erases the history and the draft; first run still shows once, ever, and a pending "Ended." survives it. See [ADR 0008](./adr/0008-the-root-holds-a-draft.md).

**Each device is an island.** Tokens are device-local and opaque, authorization is per device, and nothing syncs. Committing on the iPhone does nothing to the iPad, and `denyAppRemoval` bites per device.

### 4. `FreedomFromKit` — the seam

Everything below is Foundation-only and pure. The app owns every conversion to and from a `FamilyActivitySelection`; what crosses this seam is opaque handles, counts, dates, and strings.

```swift
/// An opaque, app-minted key for one selection token. The kit never interprets it.
/// The app mints it as the base64 of the encoded token; a churned token yields a
/// different handle, which is exactly how "no longer resolves" is detected.
public struct TargetHandle: Hashable, Codable, Sendable { public let value: String }

/// A canonical host. Only `canonicalize` may construct one.
public struct WebDomain: Hashable, Codable, Sendable { public let host: String }

public enum CommitmentLength: Equatable, Codable, Sendable {
  case preset(Preset)              // .fifteenMinutes .oneHour .threeHours .twelveHours
                                   // .oneDay .threeDays .sevenDays .thirtyDays
  case custom(seconds: TimeInterval)  // clamped to [15 min, 365 days]
}

public struct Draft: Equatable, Codable, Sendable {
  public var domains: [WebDomain]        // apps left here when S3 came back red
  public var length: CommitmentLength?
}

public struct Commitment: Equatable, Codable, Sendable {
  public let id: UUID
  public let startedAt: Date
  public let deadline: Date              // absolute, authoritative
  public let encodedSelection: Data?
  public let namedHandles: [TargetHandle]
  public let domains: [WebDomain]
  public internal(set) var isDegraded: Bool
  public internal(set) var isBroken: Bool
}

public enum Outcome: String, Codable, Sendable { case completed, completedDegraded, broken }

public struct ClosedCommitment: Equatable, Codable, Sendable {
  public let startedAt: Date, deadline: Date
  public let namedTargetCount: Int
  public let domains: [WebDomain]
  public let outcome: Outcome
}

public struct Coverage: Equatable, Sendable {
  public let resolved: Int, named: Int
  public var isComplete: Bool { resolved == named }
}

public struct MonitoringWindow: Equatable, Sendable {
  public enum Kind: Sendable { case walk, final }
  public let start: Date, end: Date, kind: Kind
}
```

**The functions.**

| Function | Contract |
|---|---|
| `duration(of: CommitmentLength, from now: Date) -> TimeInterval` | A remembered length is re-anchored to now, never restored as a stored date |
| `clamp(_ seconds: TimeInterval) -> Result<TimeInterval, LengthError>` | Under 15 minutes refused, over 365 days refused |
| `deadline(for:from:) -> Date` | `now + clamped duration` |
| `shouldRelease(deadline:now:) -> Bool` | `now >= deadline` |
| `lateness(deadline:now:) -> TimeInterval` | For the release log line |
| `nextWindow(deadline:now:) -> MonitoringWindow?` | See below |
| `coverage(named:resolved:) -> Coverage` | Set intersection over handles |
| `canonicalize(_ typed: String) -> WebDomain?` | See below |
| `add(_ typed: String, to: [WebDomain]) -> [WebDomain]` | Canonicalize, dedupe, refuse the 51st silently |
| `outcome(isBroken:isDegraded:) -> Outcome` | broken wins; else degraded; else completed |
| `holdDuration(for: CommitmentLength) -> TimeInterval` | See §8 |

**The walk-forward step.** Exactly one `DeviceActivity` activity is registered at a time, under one constant name. Every registration stops the existing activity first, so re-registration is idempotent.

| Remaining | Window produced |
|---|---|
| `now >= deadline` | `nil` — do not register; release instead |
| more than 7 days | `.walk(now, now + 7d)` — wake me again later to re-register |
| 7 days or less | `.final(deadline, deadline + 7d)` — the release trigger |

**Sharpened here.** ADR 0009's test list reads "a deadline inside one legal window yields a window ending at it; … the final window starts at the deadline". [ADR 0004](./adr/0004-commitments-run-to-a-year-on-a-walked-forward-watchdog.md)'s reasoning settles the conflict against a window that ends at the deadline: *"A window that ends at the deadline is a net only as wide as its final minutes."* `intervalDidStart` fires on first device use inside the interval, so a window starting at the deadline is a week-wide net for the release. Two consequences worth stating: **every window this function produces is exactly seven days long**, so the 15-minute floor never applies to a window (only to a commitment's duration); and nothing is registered during the final stretch before the deadline, which is correct, because nothing needs to happen before it. ADR 0009's test-list line is amended in place to match.

**Domain canonicalization.** Trim whitespace, lowercase, and keep the host only: scheme, userinfo, path, query, fragment, port, and any trailing dot are removed. `www` is preserved exactly as typed — stripping or adding it would guess at matching rules Apple has not documented. Displayed, stored, and applied are always the same string.

**Sharpened here:** an entry that canonicalizes to empty, contains whitespace, or contains no dot is refused, silently, exactly like the 51st. [ADR 0006](./adr/0006-web-targets-block-by-filter-not-by-shield.md) fixed the transformation but not the validity floor, and a `WebDomain` with no dot cannot match anything.

### 5. Bypass resistance and restrictions

Decided by [ADR 0001](./adr/0001-app-applied-restrictions-as-v1-bypass-resistance.md). **Authorization is `.individual`, and there is no setup ritual.** A TestFlight tester's first run is identical to the developer's.

| # | Escape route | Closed by |
|---|---|---|
| 1 | Settings → Screen Time → freedomfrom → revoke | **Nothing.** Only supervision closes it, and supervision requires erasing the device |
| 2 | Delete the app | `store.application.denyAppRemoval = true`, applied for the commitment's duration |
| 3 | Move the device clock forward | `store.dateAndTime.requireAutomaticDateAndTime = true`, applied for the commitment's duration |

- **Restrictions are always on for a commitment's duration**, with no per-commitment toggle. A toggle would be a lever the user's future weak self pulls at commit time.
- **`denyAppRemoval` is device-wide.** No app can be deleted on the phone while a commitment runs — up to a year. This is the collateral, and first run states it at full weight.
- **There is no in-app escape hatch.** Route 1 already is one, at roughly fifteen seconds. The app names it plainly instead of hiding it.
- **Routes 2 and 3 are probable, not certain** under `.individual`, and there is no read-back of effective state. Hardware check C6 is the one that matters most before a stranger installs the app, because informed consent rests entirely on one first-run sentence.
- The app applies restrictions and **never checks whether they took**.

### 6. The commitment: durations and the three reconciliation points

Decided by [ADR 0004](./adr/0004-commitments-run-to-a-year-on-a-walked-forward-watchdog.md). A commitment lasts **15 minutes to one year**.

Presets, tapped: 15 minutes, 1 hour, 3 hours, 12 hours, 24 hours, 3 days, 7 days, 30 days. A final row opens a date picker bounded at 365 days out.

**The schedule is not what blocks.** Shields, the filter, and restrictions live in one named `ManagedSettingsStore` and persist until something clears them. A schedule that never fires does not release a commitment early; it fails in the direction of the block staying up. `DeviceActivity` exists only to *release* on time.

**Three things reconcile**, each comparing now against the stored absolute deadline, and each clearing the store and stopping monitoring if it has passed:

| Runs | When |
|---|---|
| `Monitor` extension | whenever a window boundary wakes it (`intervalDidStart` and `intervalDidEnd`) |
| the app | every launch and every foreground |
| `ShieldConfig` extension | every time a shielded target is opened |

The third is the one that fires at the moment of harm. A stale shield nobody touches has cost nobody anything; the instant someone opens a target, the extension drawing the shield is already running with the same access group, and it checks.

**A commitment can end late, never early.** That is the named failure mode and the acceptable direction.

**On every reconciliation that does not release:** recompute coverage from the stored selection, apply what resolves, mark degraded if anything does not, and re-register the window from wherever the deadline now sits.

**v1 registers no `DeviceActivityEvent`.** Schedules only.

### 7. Enforcement: shields for apps, the filter for web domains

Decided by [ADR 0006](./adr/0006-web-targets-block-by-filter-not-by-shield.md).

| | Apps | Web domains |
|---|---|---|
| Chosen by | the system `FamilyActivityPicker` | typed by hand |
| Applied through | `store.shield.applications` | `store.webContent.blockedByFilter = .specific(Set<WebDomain>)` |
| What a blocked thing shows | freedomfrom's shield: a countdown in the dark | Apple's own page — nothing freedomfrom can style |
| Ceiling | none | 50, enforced at input |
| Can degrade | yes — tokens are opaque and churn | no — a typed string always resolves |
| Readable back to the user | no, only a count | yes, in words |

- Released by setting the shield to `nil` and the filter to `.none`, on the same one named store.
- **Safari Private Browsing is off while a filter is applied.** The targets screen says so. First run does not, because it is conditional on having typed a domain.
- **The app names no browser.** Which browsers a `.specific` filter actually covers is undocumented; hardware check C3 is a survey, and the targets step names only what it observed.
- **A commitment exists if its *enforcement* applied, not if its shield did.** A website-only commitment is first-class. Nothing is written if enforcement fails to apply; the app re-requests authorization rather than reporting an error.
- **A website-only commitment never wakes `ShieldConfig`**, leaving two of the three reconciliation points. The release still arrives late rather than early.

**Sharpened here: category tokens are applied, not dropped.** `FamilyActivityPicker` can return `categoryTokens`, and the map's out-of-scope list excludes "category-level blocks" as a *product feature* — the app-provided adult-content auto-filter, `FilterPolicy.auto`. Honouring a user's own explicit pick in the system picker is not that feature, and silently ignoring it would be the app editing the user's list, which ADR 0008 forbids for the same reason it refuses to prune dead tokens. So: `store.shield.applicationCategories = .specific(selection.categoryTokens)` when non-empty, category tokens get handles and count toward coverage like any other target, and the count on the targets screen is the number of targets that will actually be enforced. v1 still offers no category feature of its own, and `FilterPolicy.auto` is never used.

### 8. The screens

Decided by [ADR 0003](./adr/0003-a-wordless-v1-flow.md) (the voice), [ADR 0007](./adr/0007-a-line-with-spurs.md) (the navigation), and [ADR 0008](./adr/0008-the-root-holds-a-draft.md) (what the root remembers).

**The rule, an invariant with no exceptions: every screen is one statement and one action.** freedomfrom does not argue. What little it says is load-bearing; nothing is decorative. One type treatment throughout. The only ceremony is the hold, and **a hold means this cannot be undone**.

**The line.**

| Screen | Shows when | Statement | Its one action |
|---|---|---|---|
| First run | once, ever | Two sentences — what it does, and that you will not be able to undo it — then the collateral at **full weight**: *while it runs, no app on this phone can be deleted, not just this one, and the clock stays automatic* | Begin |
| **Targets** (root when idle) | no commitment is running | The app-target count, the typed domains as plain text, and the Private Browsing line when any domain is typed | Next |
| Commit | after Targets | The duration list, with the resulting deadline in words beneath it | **hold to commit** |
| **Countdown** (root when running) | a commitment is running | Time remaining, and current coverage as a count | the exit line |
| Ended | once, on the first launch after a release | "Ended." The screen turns light | Again |

**The two spurs**, both pushed with a Back:

| Spur | Hangs off | Reachable when |
|---|---|---|
| Escape | the Countdown | a commitment is running |
| History | Targets | nothing is running, **and** the history is non-empty |

Plus one screen freedomfrom does not draw in its own process:

| Shield | Drawn by | Shape |
|---|---|---|
| The shielded app | `ShieldConfig` extension | A countdown in the dark. No app name, no explanation, no button, no scolding |

**Sheets return values; pushes go somewhere.** The system app picker and the date picker are sheets. Escape and History are pushes. Two presentations meaning two different things is one vocabulary.

**Screen by screen.**

- **Targets** is the busiest screen in the app, and it is the root, so it carries the weight the rest of the line does not: the count, "Choose apps", the domain field, the typed list, "Next", and — only when the history is non-empty — the history line. The line is **absent** when there is no history rather than present and empty.
- **Targets arrives holding the draft**: the last typed domains as text, and the last length selected on the Commit screen with its deadline sentence recomputed from now. The draft is written when a domain is committed with return, and when the app backgrounds — so a finished domain always survives an interruption and a half-typed one never does. **Amended by S3:** this line read "the last selection (verified by opening the picker, which arrives with them checked)" first. It does not arrive with them checked, so the selection is gone from the draft and the picker opens empty every launch. The count above it reads what this session picked.
- **Next is unreachable with nothing selected.** One typed domain is enough. This is a flow rule, not an error, so it needs no voice. **Amended by S3:** the question now spans two places, since the apps are the session's and the domains are the draft's.
- **Nothing prunes the draft.** A finished domain stays in it until you remove it. **Amended by S3:** this line read "a handle that no longer resolves stays in it, so a commitment can be degraded at birth". With apps out of the draft, every token is freshly minted and freshly seen, so born-degraded is no longer reachable — and the count on Targets stops being able to lie. Mid-commitment churn still degrades; that is unchanged.
- **Commit's hold scales with what it buys**: about 1.5s at fifteen minutes, about 5s at thirty days and above, clamped at both ends. **Sharpened here:** interpolate linearly in `log(duration)` between those two anchors. ADR 0004 fixed the anchors and the principle, not the curve.
- **Countdown states coverage**, not what the commitment named at commit time. This is the substitute for every message the app refuses to show, which makes coverage accuracy load-bearing rather than cosmetic.
- **Escape** is four lines: where the exit is, that it takes about fifteen seconds, that it will be written down, that the other two routes do not work, and the honest ceiling. Then it stops. The product does not defend itself here.
- **"Ended." says nothing about how it ended.** The release can land while the app is closed, so the screen is drawn on the first launch after it and every launch after that goes straight to Targets. Naming the outcome here would be the app getting the last word.
- **Re-arm is not a destination.** A reinstalled app with a commitment still running lands on the Countdown, indistinguishable from any other launch.
- **History** is one row per closed commitment, stating what was committed and how it ended in plain words, from the three-value vocabulary. Degraded reads as a coverage fact, not a verdict. This is the one screen that spends words, because the record *is* the statement.
- **History's one action is the clean slate**, at the foot of the screen, on a fixed hold longer than any commit hold. **Sharpened here:** 6 seconds. It erases the history and the draft together; Targets is blank afterwards, and first run does not return.
- **There is no settings surface**, no hub, and no tab bar. Every candidate for a settings screen was already placed or refused; the inventory is in ADR 0007.

**The priced cost, stated rather than hidden:** history is unreachable while a commitment runs, so during a year-long commitment the app's honest mirror is locked away for exactly as long as the thing it reflects is happening. It buys back that a clean slate can never be mistaken for an escape route.

### 9. Failure modes

Decided by [ADR 0005](./adr/0005-what-v1-repairs-and-what-it-accepts.md). **Repair what the app can fix alone, accept what it cannot, and narrate neither.**

**Repaired.**

| Failure | What v1 does |
|---|---|
| `intervalDidStart` / `intervalDidEnd` never arrives | Nothing new. The shield holds itself; the next reconciliation point repairs the registration |
| `Monitor` jetsammed, or the device off across the deadline | Same. The release arrives late |
| The shield is still applied after the deadline | Cleared by whichever reconciliation point runs next. Nothing says it was late |
| A stored token no longer resolves | Coverage recomputed on every reconciliation. The target is dropped, the commitment marked degraded, the deadline untouched |
| Authorization revoked mid-commitment | Observed on the next launch. Marked broken **once**; authorization re-requested on **every** launch while it runs; coverage re-armed if granted |
| Deleted and reinstalled mid-commitment | The record survives. The app finds a running commitment, marks it broken, and re-arms without comment |
| Enforcement fails to apply at commit | No commitment is written. The app re-requests authorization instead of reporting an error |
| The user picks freedomfrom itself as a target | `ShieldConfig` drops its own token from the store the first time the shielded app is opened. The host app must not attempt this — it cannot reliably tell which token is itself |
| An extension wakes and cannot read the Keychain | It touches nothing, registers nothing, and exits. `ShieldConfig` additionally falls back to a dark shield with no countdown |

**Accepted.** Named, and nothing is built for them: the clock moved forward; a restriction silently no-op'ing; a late release; **a commitment that ends unobserved being recorded as completed**; a timezone shift moving a window; a restriction failing to apply at commit; the user declining the re-request after revoking.

**The four rules underneath.**

1. **The app has no voice for things going wrong.** There is no eighth kind of screen for anomalies. A late release, a degraded commitment, and a re-arm all pass in silence. What replaces the message is a live surface that is accurate.
2. **A break marks a running commitment; it does not end one.** Nothing the user does shortens the deadline, so "ended early" names a state that does not exist. Broken is a property of *how a commitment ran*, recorded once on first observation and never re-marked.
3. **Enforcement is a precondition for a commitment existing; the restrictions are not.** A countdown over nothing looks like enforcement without being any. `denyAppRemoval` or `requireAutomaticDateAndTime` failing changes nothing — the user still gets what they asked for.
4. **Nothing is inferred about state that cannot be read back.** v1 applies restrictions and never checks. It never guesses at the clock: a forward jump is indistinguishable from the device being switched off, and a backward jump is worthless to detect because it lengthens the commitment.

**Degraded never clears.** The mark records how a commitment ran, so a degraded commitment whose handles all resolve again stays degraded.

### 10. The logging contract

Decided by [ADR 0009](./adr/0009-a-foundation-only-kit-and-a-hardware-pass-a-human-walks.md). A wordless app returns no other signal, which makes this load-bearing rather than debug scaffolding.

- Subsystem `com.samuelcolacchia.freedomfrom`. One category per process: `app`, `monitor`, `shieldconfig` — which is what keeps "the monitor never woke" distinguishable from "the monitor woke and found nothing".
- **Permanent in release builds.**
- **Public** (`%{public}` deliberately, because default redaction would print `<private>` and make a run unfalsifiable): whether the record was read, whether a store mutation landed, resolved-of-named coverage counts, the absolute deadline, which window was registered and its kind, the release and how late it was, and every break or degrade mark.
- **Never logged at all: target identities.** No bundle identifiers, no tokens, no domain strings. Nothing on the hardware checklist needs to know *which* app was shielded, only how many resolved.
- The device record is `devicectl device sysdiagnose` read with `log show --archive`. `log stream --device` was removed in macOS 26.6 and `devicectl` has no log subcommand. Console.app is a live convenience, not the record.
- On the simulator, `scripts/mac run` reads these lines back by predicate in the same second, so a field that prints `<private>` where this contract requires public says so on day one.

### 11. Work item order

1. **Repo scaffolding.** `project.yml`, the three entitlements files, `Package.swift` with both package targets. Nothing that runs yet.
2. **The walking skeleton** — ADR 0009's work item one, and it is **kept, not thrown away**. The real three targets with their real bundle IDs and entitlements, doing nothing but authorizing, picking, storing to the Keychain, shielding, and letting both extensions read and log. Built and launched for the **simulator first**, so a failure there is a code failure rather than a signing one. Then installed on the device, where it runs checks **E1, S1, S2, S3**. It is also the first thing to exercise the whole headless build-sign-install chain, so it doubles as proof of the workflow and identity decisions.
3. **`FreedomFromKit`, tests first.** Every case in the Testing Decisions list below, written before its implementation, then made to pass. `scripts/mac test`.
4. **`FreedomFromPlatform`** — the `SecItem` wrapper and the logger, promoted from whatever the skeleton did by hand.
5. **The app**, in line order: First run, Targets, Commit, Countdown, Escape, Ended, History.
6. **The extensions**, promoted from the skeleton: `Monitor`'s two callbacks, `ShieldConfig`'s countdown, its reconciliation, and its self-shield drop.
7. **The hardware pass**: the clean run (C1–C9), then the sacrificial run (X1–X6).
8. **Reconcile the app's copy against what the runs showed**, then TestFlight — which additionally waits on [issue #10](https://github.com/SamuelColacchia/freedomfrom/issues/10).

If S1 or S2 comes back red at step 2, apply the amendment written beside it on the checklist and amend the ADR. Do not reopen the decision.

---

## Testing Decisions

Decided by [ADR 0009](./adr/0009-a-foundation-only-kit-and-a-hardware-pass-a-human-walks.md). Testing splits along the line the SDK draws, and the line is forced rather than chosen: a headless `swift test` on macOS may not *name* a single Screen Time type. `FamilyActivitySelection` is absent from the macOS module entirely; `ApplicationToken`, `Token`, `ManagedSettingsStore`, `DeviceActivityCenter`, `AuthorizationCenter` and the rest are all `@available(macOS, unavailable)`. The simulator adds only the ability to *name* them — `Token`'s one public initializer is `init(from decoder:)`, so no test can construct one without a blob captured from a real device.

### The one seam

**`FreedomFromKit`.** One seam, and it is the highest one available: handles, counts, dates, and strings cross it, and nothing else does. Anything that must hold a `FamilyActivitySelection` lives in the app target and is therefore not headless-testable — a cost paid deliberately.

**A good test here asserts external behaviour**: given a deadline and a now, what window comes back; given a typed string, what domain comes back. It never reaches for internals. There is no prior art in the repo — these are the first tests it has.

**Written before the code.** With no paired device these are the only executable feedback in the entire project, and tests written afterwards get written to match the code.

### The named cases

Every one is a transcription of a rule an ADR already fixed, not new design.

**Deadline reconciliation** — holds before the deadline; releases at it; releases at launch on a deadline already past, silently; lateness is reported from the deadline, not from the window.

**Walk-forward step** — a deadline more than seven days out yields a `.walk` window of exactly seven days from now; a deadline seven days or less out yields the `.final` window starting *at* the deadline and running seven days; a passed deadline yields nothing; **no window is ever longer or shorter than seven days**; re-registering with the same inputs yields the same window.

**Clamps** — a duration under 15 minutes is refused; over 365 days is refused; a remembered length is re-anchored to now rather than restored as a stored date; a `.custom` length that would now resolve to a past deadline still re-anchors forward.

**Coverage and degradation** — all handles resolving gives full coverage and no mark; a missing handle shrinks coverage and marks degraded; a degraded commitment whose handles all resolve again **stays degraded**; a commitment with only web domains has full coverage and can never degrade.

**Domain canonicalization and the 50 rule** — scheme, userinfo, path, query, fragment, port and trailing dot stripped; lowercased; whitespace trimmed; `www` preserved exactly as typed; duplicates collapse *after* canonicalization; an entry with no dot, with internal whitespace, or that canonicalizes to empty is refused; the 51st domain is refused and nothing is said.

**The draft** — survives between commitments; survives an edit abandoned before the hold; committing consumes nothing; a clean slate erases the draft and the history together and leaves the first-run flag alone.

**Outcome vocabulary** — completed, completed-degraded, broken; broken and degraded can both be true of one commitment and the row reads broken; broken is recorded once and never re-marked; an unwitnessed commitment reads completed.

**Hold duration** — 15 minutes gives the short anchor, 30 days and a year both give the long anchor, and the curve is monotonic in between.

### The hardware pass

The device half is manual, and it lives at [`docs/hardware-smoke-checklist.md`](./hardware-smoke-checklist.md). Three things about it that matter to whoever executes this spec:

- **Two checks can block a build** — S1 (an extension reading the Keychain access group) and S2 (`ShieldConfig` mutating a `ManagedSettingsStore` inside its memory budget). They change the architecture when red, so they run on the walking skeleton, before v1 is written. Everything else fires a pre-bound amendment instead.
- **The rest is observed across exactly two commitments**, one clean and one sacrificial, because three of the checks are destructive and a break contaminates every later observation of a clean run. Inside the sacrificial run the order is forced: **revoke before deleting**, because a working `denyAppRemoval` prevents deleting the app. Roughly 40 minutes, most of it waiting.
- **Every check names its amendment before it runs**, so a red result triggers a decision instead of reopening one.

### What gates a TestFlight invite

**Not a green checklist.** An all-green gate would deadlock on questions nobody can answer, like what Brave does with a `.specific` filter. The gate is that **both runs have happened and the app's claims have been reconciled against what they showed.** A red result changes what the app says, not whether it ships.

This matters most for C6. Informed consent rests entirely on one first-run sentence; if `denyAppRemoval` silently no-ops under `.individual`, that sentence claims a restriction that does not exist — a known unknown for the developer, and a false claim for a stranger.

---

## Out of Scope

Carried from the map, so nobody helpfully adds one of these:

- **Recurring schedules.** "Block social media every weekday 9–5" is a different product from the one-shot commitment this is built around.
- **An adult-content category filter.** `FilterPolicy.auto` and any app-provided category-level blocking. (A category the *user* picks in the system picker is applied — see §7.)
- **Child authorization.** Ruled out on two independent grounds: no second person holds guardian credentials, and converting a daily driver to a child iCloud account is unacceptable.
- **Supervision via Apple Configurator.** The one genuinely strong mechanism, and it requires erasing the device. Recorded in the README as the honest answer for anyone who wants real enforcement. Not built.
- **A `ShieldAction` extension**, an App Group, and a settings screen. Each was considered and each has nothing to do.
- **Cross-device sync.** The universal build is two islands, not one net.
- **Notifications.** Deferred, and held in reserve as the fallback if hardware check S2 is red. They cost a permission prompt in front of "Begin" and the app its first words.
- **Public App Store release.** TestFlight is the distribution ceiling for this effort.
- **macOS, watchOS, or Android.**
- **CI.** Returns when a second contributor does.

---

## Further Notes

**Three things this spec sharpened beyond its ADRs**, each marked in place above, each a place where an implementer would otherwise have had to decide: the package's second target for the `SecItem` calls; the walk-forward window always being exactly seven days and always starting at the deadline in its final form; and category tokens being applied rather than dropped. If any of the three is wrong, it is wrong here and not in an ADR.

**Two numbers were invented here** because their ADRs fixed the principle and not the value: the commit hold interpolates in `log(duration)` between 1.5s and 5s, and the clean-slate hold is 6s.

**Every enforcement claim is conditional on "while authorized."** `.individual` authorization is user-revocable in fifteen seconds behind a Face ID scan, and nothing short of supervision closes that. No copy anywhere in the app may exceed the honest claim at the top of this document.

**What only hardware can settle**, and which no copy may claim until it does: which browsers a `.specific` filter covers; whether a bare domain covers its subdomains; whether `denyAppRemoval` and `requireAutomaticDateAndTime` bite under `.individual`; whether an unresolvable token is detectable at all; whether `requestAuthorization` re-prompts from `.denied`; and whether a sysdiagnose contains this subsystem's lines.

**The prototype is thrown away, not promoted.** [`prototype/v1-commit-flow`](https://github.com/SamuelColacchia/freedomfrom/tree/prototype/v1-commit-flow) is a single throwaway HTML file written under prototype constraints — no tests, no error handling, no persistence. It is the primary source for the *voice*, and nothing else.

**Where the reasoning lives.** [`docs/adr/`](./adr/) 0001 through 0010, and the glossary in [`CONTEXT.md`](../CONTEXT.md). Use that vocabulary — commitment, target, draft, deadline, coverage, enforcement, shield, filter, restriction, re-arm, release, break, clean slate — in code, in copy, and in commit messages. It is precise, and each term lists the words it is deliberately not.
