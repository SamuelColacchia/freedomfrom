# A line with spurs

freedomfrom is a forward line of screens with two spurs off it. There is no hub, no tab bar, and no settings surface. ADR 0003's rule holds everywhere with no exceptions — **every screen is one statement and one action** — and the root is always the current state of the one thing: a commitment running shows the countdown, none running shows the commitment you would make.

This answers the navigation problem ADR 0003 named and handed to the build spec: the history is the only place a break is visible, and it had to be reachable from screens that are deliberately wordless.

## The line

| Screen | Shows when | Its one action |
|---|---|---|
| First run | once, ever | Begin |
| Targets | no commitment is running | Next |
| Commit | after Targets | hold to commit |
| Countdown | a commitment is running | the exit line |
| Ended | once, on the first launch after a release | Again |

**Targets is the root when idle.** Every re-entry path already ended there — "Again" means pick targets — so an idle screen announcing that nothing is running would be a screen whose only job is to point at another screen. That is the hub, wearing one screen instead of a row.

**"Ended." shows once and says nothing about how it ended.** The release can land while the app is closed (ADR 0004), so the screen is drawn on the first launch after it; every launch after that goes straight to Targets. Naming the outcome here would be the anomaly voice ADR 0005 refused — a break announced on the way out is the app getting the last word.

**Re-arm is not a destination.** A reinstalled app with a commitment still running lands on the countdown, indistinguishable from any other launch (ADR 0003).

## The two spurs

Both are pushes with a Back.

| Spur | Hangs off | Reachable when |
|---|---|---|
| Escape | the countdown | a commitment is running |
| History | Targets | nothing is running, and the history is non-empty |

The history line is **absent** from Targets when there is no history rather than present and empty. Absence reads as absence, not as "no history yet" — ADR 0005's no-voice rule applied to an empty list.

**History is unreachable while a commitment runs**, which is the priced cost of keeping the countdown to one action. The countdown's action is the exit line, and it cannot lose it: ADR 0001 requires the exit be named plainly rather than concealed. The history holds *closed* commitments (ADR 0002), so it has nothing to say about the one running, and the mark a break leaves is deliberately invisible until the commitment closes (ADR 0005) — a history line on the countdown would advertise a place to go looking for a mark that is not there yet. The honest statement of the cost: during a year-long commitment, the app's honest mirror is locked away for exactly as long as the thing it reflects is happening.

It buys something back. Because history is idle-only, **clean slate can never be mistaken for an escape route** — there is never a commitment on screen when you can reach the erase.

## The history screen

One row per closed commitment, stating what was committed and how it ended, **in plain words**. ADR 0005 fixed the vocabulary at three outcomes — completed, completed-degraded, broken — and all three are named rather than encoded. Degraded reads as a coverage fact (what was lost) rather than a verdict (that something went wrong), which keeps the app from scolding while still recording.

This is the one screen in the app that spends words, and that is the rule being followed rather than bent: the record *is* the statement. ADR 0005's no-voice rule bans announcing anomalies as they happen, on the grounds that a message the user cannot act on is the app arguing. A past record is not an argument.

**Its one action is the erase.** Clean slate sits at the foot of the screen on a **fixed hold, longer than any commit hold** — the longest in v1. ADR 0004 scales the commit hold by what it buys; clean slate buys the largest irreversible thing in the app and scales with nothing.

This generalises ADR 0003's ceremony from *the hold that commits you* to **the hold means this cannot be undone**. Same gesture, same meaning, one more place — not a second voice.

## Sheets return values, pushes go somewhere

ADR 0004 flagged the duration row's date picker as the flow's single exception and left open whether it established a pattern. It did not establish one; it belongs to a category, and the category has a rule.

| Second surface | Presentation | Because |
|---|---|---|
| system app picker | sheet | hands a selection back to Targets |
| date picker | sheet | hands a deadline back to Commit |
| Escape | push | somewhere you go and come back from |
| History | push | somewhere you go and come back from |

Two presentations meaning two different things is one vocabulary. One presentation meaning two different things is the ambiguity. The rule also agrees with the one surface the app does not control: `FamilyActivityPicker` arrives as a sheet by convention.

## No settings surface

Every candidate was already placed or refused, so a settings screen in v1 would be an empty room with a name. Recorded so a future reader can tell it was checked rather than forgotten:

| Would have lived there | Where it actually is |
|---|---|
| Authorization state, re-request | OS-owned; re-requested every launch while a commitment runs (ADR 0005) |
| Restriction toggles | Refused. A toggle is a lever the user's future weak self pulls at commit time (ADR 0001) |
| Notifications | Deferred (ADR 0004), and it costs a permission prompt in front of "Begin" |
| Cross-device sync | Removed. The two devices are islands by design (ADR 0002) |
| Erase the history | The history screen, above |
| What the app is, and how to get out | First run and the escape screen, where ADR 0003 made the sentence load-bearing |

## Considered options

**A hub at the root (rejected).** Opening the app lands on a small home — countdown or "nothing running" — with named rows for History and the exit. Discoverable, one tap to everything, and it makes the app a place. ADR 0005 states plainly that the app *is deliberately not somewhere you go*, which is the reason re-requesting authorization on every launch was affordable at all. A hub is exactly somewhere you go, and it would be a second navigation vocabulary in an app that just spent ADR 0003 buying one voice.

**Hidden gestures (rejected).** History behind a swipe or long-press on the countdown, with nothing visible. Maximum silence and zero chrome, and it contradicts ADR 0001's stance everywhere else: the app names its exits rather than concealing them. It hides nothing; it just does not shout. ADR 0001 asks that a break be *visible only if the user goes looking* — a quiet named line is literally that, where a hub row makes it a destination and a hidden gesture makes it unfindable.

**The countdown carrying both lines (rejected).** Exit and history, two quiet lines under the countdown, keeping the record reachable the whole time. Rejected for the one-action rule on the app's most-seen screen — two quiet lines beneath a countdown is a menu with the chrome filed off — but the counter-pressure is real and is recorded above as a priced cost, not a free win.

**History behind the escape screen (rejected).** It would have kept the countdown to one action and still reached the record while running. It puts the exit in front of someone who came to look at their own history, which is the worst possible moment to show it.

**Clean slate as a plain tap (rejected).** ADR 0002 asked only for a plainly-named erase, not a ceremonious one. It is a one-tap footgun in an app with no undo and no dialogs, and it would rank erasing every record below committing to an afternoon.

**Clean slate on its own screen (rejected).** A spur off a spur, whose statement would be *this ends nothing and lifts nothing* — a sentence with nobody left to say it to, once history became idle-only.

**Typographic-only outcomes (rejected).** Rows distinguished by dimming and marks, with no outcome vocabulary. Maximally consistent with wordlessness, and it makes "broken" a dimmed row the user has to be taught to decode by an app that refuses to tell them. That is concealment.

**No expiry screen (rejected).** Land on Targets after a release, silent like everything else. One fewer screen, and a commitment that ran for a month would end with the app quietly showing a target picker. The release is the one thing the whole design exists to deliver on time.

**A settings spur off Targets (rejected).** A second quiet line beside the history one, to give future additions a home. A screen with nothing in it, bought with a second action on the root.

## Consequences

- **The one-action rule becomes an invariant the spec can state and check**: every screen in v1 has exactly one action, and there are no exceptions to reason about.
- **ADR 0003 is amended in wording, not in substance.** "The only ceremony in the app is the hold that commits you" becomes "the hold means this cannot be undone", which now covers two acts.
- **ADR 0004's consequence is amended.** The date picker is not the flow's only second surface; it is the first member of a category governed by the sheet-versus-push rule above.
- **Targets becomes the busiest screen in the app** — a count, a text field, "Choose apps", "Next", and a history line. It is the root, so it carries the weight the rest of the line does not.
- **The erase hold is the longest gesture in v1**, which makes hold length a ranking rather than a single lever: fifteen minutes is the shortest commit hold, a month and above the longest, and clean slate above that.
- **What Targets remembers between commitments is now a decision with nowhere to hide.** Opening blank makes every commitment a fresh deliberate choice; remembering the last selection makes re-committing one tap. Carried by [Decide what the targets root remembers between commitments](https://github.com/SamuelColacchia/freedomfrom/issues/20).
- **No new glossary terms.** Consistent with ADR 0003: flow and navigation decisions describe how the domain is reached, not what it contains.
