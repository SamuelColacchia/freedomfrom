# What v1 repairs when enforcement fails, and what it accepts

Every documented way this stack fails sorts into one of two columns. v1 writes behaviour for the failures the app can detect and fix by itself, names the rest, and does nothing about them. The rule that sorts them: **repair what the app can fix alone, accept what it cannot, and narrate neither.**

This extends ADR 0001 rather than contradicting it. The honest claim is unchanged: freedomfrom resists casual bypass while authorized, and cannot prevent a determined bypass.

## Repaired

| Failure | What v1 does |
|---|---|
| `intervalDidStart` / `intervalDidEnd` never arrives | Nothing new. The shield holds itself, and the next of ADR 0004's three reconciliation points repairs the registration |
| `Monitor` jetsammed, or the device off across the deadline | Same. The release arrives late |
| The shield is still applied after the deadline | Cleared by whichever reconciliation point runs next. Nothing says it was late |
| A stored selection token no longer resolves | Coverage is recomputed from the stored selection on every reconciliation. The target is dropped, the commitment is marked degraded, the deadline is untouched |
| Authorization revoked mid-commitment | Observed on the next launch. The commitment is marked broken once, authorization is re-requested on every launch while it runs, and coverage is re-armed if it is granted |
| Deleted and reinstalled mid-commitment | The Keychain record survives (ADR 0002). The app finds a running commitment beside no install marker, marks it broken, and re-arms without comment |
| The shield fails to apply at commit | No commitment is written. The app re-requests authorization instead of reporting an error |
| The user picks freedomfrom itself as a target | `ShieldConfig` drops its own token from the store the first time the shielded app is opened |
| An extension wakes and cannot read the Keychain | It touches nothing, registers nothing, and exits |

## Accepted

| Failure | Why it is not repaired |
|---|---|
| The clock is moved forward | Undetectable at the API level. `requireAutomaticDateAndTime` is the only mitigation and is itself unverified. This is escape route 3, and ADR 0001 already accepts it |
| A restriction silently no-ops | There is no read-back of effective state, so there is nothing to detect and nothing to do if it were detected |
| A release arrives late | The named failure mode, in the only acceptable direction. ADR 0004 |
| A commitment that ends unobserved is recorded as completed | Delete-and-wait past the deadline is indistinguishable from a phone left in a drawer. Recording it as a break would be a guess, and a third outcome for "we do not know" adds a concept that resolves nothing |
| A timezone shift moves a scheduled window | A schedule only wakes something; the absolute deadline gates the release. Drift changes when the app is woken, never whether the release is early |
| A restriction fails to apply at commit | Restrictions are collateral, not the product. The commitment proceeds and the failure is not mentioned |
| The user declines the re-request after revoking | The countdown runs over zero coverage. Forcing the point would need a lever, and ADR 0001 builds none |
| `eventDidReachThreshold` misfires | Out by construction. v1 registers no `DeviceActivityEvent` — ADR 0004's watchdog uses schedules only |
| App Group propagation drift | Out by construction. ADR 0002 removed the App Group |

## The rules underneath

**The app has no voice for things going wrong.** ADR 0003 gives it seven screens, one statement and one action each, and no eighth kind for anomalies. A late release, a degraded commitment, and a re-arm all pass in silence. What replaces the message is a live surface that is accurate: the running-commitment screen states current coverage, so losing a target reads as a smaller count rather than an announcement. This only holds because ADR 0002 already rejected acting on degradation — "re-select your targets" and "select nothing" are the same gesture — so any message here would be information with nothing attached to it.

**A break marks a running commitment; it does not end one.** The deadline is authoritative (ADR 0002) and nothing the user does shortens it, so "ended early" names a state that does not exist. Taking an escape route stops enforcement, not the commitment. Broken is therefore a property of *how a commitment ran*, recorded once on first observation and never re-marked. Re-arm has something to re-arm precisely because the commitment is still there.

> **Amended by the build.** The delete-and-reinstall row above was written as though finding a running commitment at launch were itself the signal. It is not: every launch finds one, so read literally it marks every commitment broken the second time the app is opened. What supplies the missing half is a zero-byte marker in the app's own sandbox — the one store in the project that deliberately does *not* survive deletion. A running commitment beside an absent marker is a reinstall; a running commitment beside a present one is Tuesday. The marker holds nothing, so a read failure and an absent file are the same answer: marking a break wrongly costs a row in the history, where missing one costs the record its honesty. Recorded in §3 of the v1 build spec.

**The shield is a precondition; the restrictions are not.** A commitment exists only if its shield applied. A countdown over an unapplied shield is the failure ADR 0002 rejected for cross-device sync — it looks like enforcement without being any — so on failure nothing is written, and there is nothing to release, reconcile, or file in the history. The realistic cause is missing authorization, and the OS owns that prompt, so the app re-requests rather than reporting. `denyAppRemoval` and `requireAutomaticDateAndTime` failing changes nothing: the user still gets the thing they asked for.

**Nothing is inferred about state that cannot be read back.** Apple warns that Managed Settings does not guarantee configured settings govern device behaviour, and exposes no query for effective state. v1 applies restrictions and never checks. It also never guesses at the clock: the escape is a *forward* jump, which is indistinguishable from the device being switched off, and the only thing that could catch it is a trusted network time source — a server dependency bought to lock a window beside a door that opens in fifteen seconds. A backward jump is cheaply detectable and worthless, because it lengthens the commitment.

**freedomfrom is never a valid target, and only `ShieldConfig` can enforce that.** `FamilyActivityPicker` can list the app itself and Apple documents no way to exclude an app from it. The host app cannot reliably tell which token is itself: [`localizedDisplayName` is documented as nil outside a shield-configuration extension](https://developer.apple.com/documentation/managedsettings/application/localizeddisplayname), `bundleIdentifier` is undocumented there, and tokens are [reported to churn across OS events](https://developer.apple.com/forums/thread/814571). Inside a shield-configuration extension that name is documented as available — so the one process that can recognise the app is the one already mutating the store under ADR 0004. It drops the token at the moment of harm, invisibly. Shielding freedomfrom buys nothing anyway: ADR 0001 gives the app no in-app escape worth protecting, so the token costs zero enforcement and, unremoved, would cost the countdown, the history, and the ability to commit again for up to a year.

## Considered options

**An anomaly voice (rejected).** Either one reusable line of type carried by whichever screen is showing, or per-anomaly screens. Rejected because an announcement the user cannot act on is the app arguing, which is the one thing ADR 0003's rule forbids, and because a second register is a seam — the reason The Quiet Room beat the mix was one voice throughout. The counter-pressure is real and worth recording: silence about degradation is not neutral, because the user believes they are covered and partly is not. The answer is an accurate live surface, not a message, and it makes coverage accuracy load-bearing rather than cosmetic.

**A break as a terminal state (rejected).** The record closes as broken, and re-arming starts a fresh commitment inheriting the old deadline. It needs a second commitment object to express something the first already expresses, and it makes "re-arm" a misnomer.

**Clock-tamper detection (rejected).** Two variants: persist the last observed `Date()` and flag a backward jump, or compare against a trusted network time on every reconciliation. The cheap one catches only the direction that does not help the user escape. The expensive one adds a network dependency and a false-positive class that accuses a user whose phone sat unused, inverting ADR 0001's honest-mirror stance.

**Best-effort self-exclusion in the host app (rejected).** Filter the selection by bundle ID wherever it happens to be readable, and let it through when nil. This is the tempting option and the worst one: an unreliable identity check that silently drops the *wrong* app reduces coverage while the app reports itself whole, which is worse than the footgun it was built to prevent.

**Blind re-registration from an extension that cannot read the deadline (rejected).** Register a fixed short window so the extension is woken again to retry. It cannot distinguish "before first unlock" from "the access group does not work at all", so in the second case it re-registers forever while learning nothing, and it has to choose a window length without knowing the one number the design treats as authoritative.

**Degraded as a live property (rejected).** The mark reflects current coverage and clears when everything resolves again. Rejected for symmetry with broken: both record how a commitment ran, and un-marking erases evidence that ADR 0001 and ADR 0002 both went out of their way to preserve.

**Everything best-effort at commit (rejected).** Write the record regardless, and treat a commitment that shielded nothing as fully degraded from birth. It makes committing incapable of failing, which suits a wordless app, at the price of a countdown that means nothing.

**Re-requesting authorization once per commitment, or never (rejected).** Both leave a running commitment with zero coverage for want of a prompt the OS is willing to show. The app is deliberately not somewhere you go, so "every launch" is a handful of prompts across a month. If iOS declines to re-prompt from `.denied`, this degrades into the never-ask option at the cost of one wasted call.

## Consequences

- **Coverage becomes a first-class thing the app must get right.** It is the substitute for every message this ADR refused to write, so the running-commitment surface has to state what is shielded *now*, not what the commitment named at commit time. `CONTEXT.md` gains it as a term.
- **`FreedomFromKit` gains the coverage computation.** Given a stored selection and whatever currently resolves, it returns the set to apply and whether the commitment is degraded. Pure logic alongside ADR 0002's deadline reconciliation and ADR 0004's walk-forward step, and headless-testable for the same reason.
- **The history's outcome vocabulary is fixed at three values**: completed, completed-degraded, and broken — where broken and degraded can both be true of one commitment, and where a commitment nobody witnessed reads as completed.
- **`ShieldConfig` is now load-bearing twice.** ADR 0004 made it a reconciliation point; this makes it the self-shield fix. Both rest on the same unverified premise, that it can mutate a `ManagedSettingsStore` from inside its memory budget. If hardware says no, both fall together, and the fallbacks are ADR 0004's deferred notification and simply accepting a self-shield.
- **The commit screen is unreachable with nothing selected.** A commitment with no targets would apply device-wide restrictions and shield nothing, which is the countdown-over-nothing failure by another route. Gating the flow on selection is a flow rule, not an error, so it needs no voice.
- **A `ShieldAction` extension stays deferred.** Nothing in this ADR gives a shield button anything to do; ADR 0002's and ADR 0003's reasoning is untouched.
- **Five things move onto the hardware smoke checklist**, and the first two now carry more weight than they did:
  - `ShieldConfig` mutating a `ManagedSettingsStore` (ADR 0004, and now the self-shield fix)
  - the Keychain access group being readable from an extension (ADR 0002)
  - whether an unresolvable token is detectable at all, which the whole degradation path assumes
  - whether `denyAppRemoval` and `requireAutomaticDateAndTime` bite under `.individual` (ADR 0001)
  - whether `requestAuthorization` re-prompts from a `.denied` status
