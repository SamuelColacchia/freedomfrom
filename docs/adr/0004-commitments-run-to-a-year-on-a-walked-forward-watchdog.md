# Commitments run to a year, on a walked-forward watchdog

A commitment lasts anywhere from **15 minutes to one year**. Nothing is chained to hold it: `ManagedSettings` holds the shield by itself, with no documented expiry. `DeviceActivity` exists only to **release** on time, and it is walked forward one legal step at a time rather than pre-registered across the whole span. Three separate places reconcile against the absolute deadline, so a commitment can end **late, never early**.

This supersedes the provisional ceiling in ADR 0003, which stopped the duration list at seven days because a single `DeviceActivitySchedule` stops there.

## The duration range

Presets, tapped: 15 minutes, 1 hour, 3 hours, 12 hours, 24 hours, 3 days, 7 days, 30 days. A final row opens a date picker, bounded at 365 days out.

The picker is an amendment to ADR 0003, which decided the list was discrete all the way up. A year is a product claim, not a technical one — the mechanism below has no ceiling of its own. It is set where the app can still mean what it says: over a longer span an OS update, an app update, or token churn make a degraded commitment near-certain, and offering five years would be offering something the app cannot hold.

## The mechanism

**The schedule is not what blocks.** Shields and restrictions live in a named `ManagedSettingsStore` and persist until something clears them. A schedule that never fires does not release a commitment early; it fails in the direction of the block staying up.

**The watchdog is walked forward, not chained ahead.** At any moment exactly one `DeviceActivity` activity is registered: a non-repeating window of the longest legal step — up to 7 days — toward the deadline. Every time the monitor extension wakes, and every time the app launches, the window is re-registered from wherever the deadline now sits. One slot of the documented twenty, whether the commitment is an hour or a year.

**The last window starts at the deadline rather than ending at it**, and runs a further seven days. `intervalDidStart` fires on the first device use inside the interval, so this catches any use in the week after expiry. A window that *ends* at the deadline is a net only as wide as its final minutes.

**Three things reconcile**, each comparing now against the stored absolute deadline and clearing the store and stopping monitoring if it has passed:

| Runs | When |
|---|---|
| `Monitor` extension | whenever a window boundary wakes it |
| the app | every launch |
| `ShieldConfig` extension | every time a shielded target is opened |

The third is the one that fires at the moment of harm. A stale shield nobody touches has cost nobody anything; the instant someone opens a target, the extension that draws the shield is already running with the same keychain access group, and it checks.

**Committing scales with what it buys.** The hold runs about 1.5s at fifteen minutes and about 5s at a month and above, clamped at both ends. ADR 0003 named hold length as the correct lever if committing proved too easy, and the date picker reintroduces the problem the tapped list removed: scrolling to next March is no harder than tapping "1 hour".

## Considered options

**Cap v1 at seven days (rejected).** The smallest usable v1, and the research agent's own recommendation, since it needs nothing unverified. Rejected because a week is a long weekend of resolve, not a habit change — the horizons where a commitment device earns its keep are the ones a single schedule cannot express.

**One deferred window ending at the deadline (rejected).** The elegant answer: for a 30-day commitment, register a single short window 30 days out and never chain anything. Rejected on evidence. Apple constrains interval *length* to a week but says nothing about how far ahead `intervalStart` may sit, and no forum report or open-source project tries it. Two unverified assumptions stacked — far-future acceptance, and delivery after a long powered-down stretch — under the one mechanism that releases the block.

**Pre-register the whole chain at commit time (rejected).** One activity per seven-day link, all registered up front. It burns the documented 20-activity budget (`MonitoringError.excessiveActivities`), which fixes the ceiling near 140 days, and it depends on exactly the far-future behaviour the walked-forward design avoids needing.

**No watchdog past the first window (rejected).** Register one window, rely on app-launch reconciliation for anything longer. Correct, and too slow: the app is deliberately not somewhere you go, so "open it and it fixes itself" is a fine backstop and a poor only-plan.

**A local notification at the deadline (deferred, not rejected).** It would pull the user back into the app so it can reconcile. It costs a notification permission prompt in front of "Begin" — the one screen carrying all of ADR 0001's consent, in an app ADR 0001 gives no setup ritual — and it costs the app its first words, since there is no wordless notification. Held in reserve for the case below.

**A fixed hold for every duration (rejected).** It treats a year and a lunch break as the same act. A confirmation step above some threshold was also rejected: ADR 0003 already ruled that a dialog is a second tap, not a second thought.

## Consequences

- **A commitment can end late, never early.** This is the named failure mode and it is the acceptable direction. A missed callback stalls nothing permanent: the shield holds itself, and the next of the three reconciliation points repairs the registration.
- **`FreedomFromKit` gains the walk-forward step calculation.** Given a deadline and a now, it returns the next window to register, or the final start-at-deadline window, or nothing because the deadline has passed. Pure logic, headless-testable on the Mac, and the natural home for the 15-minute and 7-day clamps that were already going to live there (ADR 0002).
- **The `ShieldConfig` extension is no longer purely presentational.** It reads the keychain record and may mutate a `ManagedSettingsStore`, inside a memory-starved process. **Unverified**, and now a first-order hardware smoke check. If it proves impossible, the deferred notification is the fallback and this ADR is amended rather than reopened.
- **A year-long commitment will probably degrade.** Tokens churn across OS and app updates; ADR 0002 already fixes what happens — coverage drops, the deadline stands. Long horizons make that path common rather than exotic, so it is a tested path, not an edge case.
- **The escape route dominates long before the ceiling does.** Someone who wants out at month seven revokes authorization in fifteen seconds (ADR 0001). Nothing here changes the honest claim; a longer maximum does not make it weaker, because it was never resting on duration.
- **The duration row that opens a picker is the only place in the flow with a second surface.** ADR 0003's rule is one statement and one action per screen. A picker is a modal step inside the commit screen, and it is the one exception the flow now carries. **Amended by [ADR 0007](./0007-a-line-with-spurs.md)**: it is not an exception but the first member of a category. A sheet returns a value to the screen beneath it (the system app picker, this date picker); a push goes somewhere and comes back (the escape and history screens). The one-action rule holds with no exceptions.
