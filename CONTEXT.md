# freedomfrom

An iOS app that blocks chosen apps and websites for a fixed span of time which the person who set it cannot lift early. The person it blocks is the person who installs it — there is no guardian, and no second keyholder.

## Language

### The core object

**Commitment**:
A block of a chosen set of targets, running until a fixed deadline, which the app will not lift early. A commitment belongs to one device — the same person on a phone and a tablet makes two, independently.
_Avoid_: session, block, lock, timer

**Target**:
An app or web domain chosen to be blocked for the duration of a commitment.
_Avoid_: site, blocked app, selection

**Deadline**:
The absolute wall-clock instant a commitment ends. It passes on schedule whether or not the app is installed or running.
_Avoid_: expiry, timeout, end time

**Degraded commitment**:
A commitment still running to its deadline which has at some point lost coverage of one or more of its targets, because they could no longer be identified. The mark is permanent for the life of the commitment even if coverage later returns; the deadline is untouched throughout.
_Avoid_: partial, broken, failed, expired

**Commitment history**:
The persisted record of past commitments, including which ones were broken. It outlives the app — deleting freedomfrom does not erase it.
_Avoid_: log, journal, stats

**Clean slate**:
Deliberately erasing the commitment history. It ends nothing and lifts nothing; it removes the record of what came before.
_Avoid_: reset, wipe, clear

### Enforcement

**Shield**:
Apple's interstitial that replaces a target's interface while a commitment runs. Per-target.
_Avoid_: block screen, overlay, paywall

**Coverage**:
The targets a commitment is shielding right now, as against the targets it names. The two diverge when a target can no longer be identified, and coverage is worked out afresh every time anything reconciles.
_Avoid_: scope, protection, enforcement

**Restriction**:
A device-wide setting the app applies for a commitment's duration — no app deletion, forced automatic date and time. Distinct from a shield, which applies only to chosen targets.
_Avoid_: lock, protection, guard

**Authorization**:
The user's grant of Family Controls access to the app. Revocable by the user at any time in Settings, which is what makes every enforcement claim conditional.
_Avoid_: permission, consent, entitlement

**Re-arm**:
Reapplying the shield and restrictions to a commitment that is still running but has lost them — after the user revoked authorization, or deleted and reinstalled the app.
_Avoid_: restore, resume, reactivate

**Release**:
The app lifting a commitment's shield and restrictions because its deadline has passed. The counterpart to a break, which happens before the deadline. A release can arrive late — after the deadline, whenever something next runs to notice — but never early.
_Avoid_: unlock, unblock, expire, end

### Getting out

**Escape route**:
One of the three ways a user can end a commitment before its deadline: revoking authorization, deleting the app, or moving the device clock forward.
_Avoid_: bypass, workaround, exploit

**Break**:
A mark on a commitment whose enforcement lapsed before its deadline, because the user took an escape route. It does not end the commitment: the deadline still stands, coverage may come back, and the history records that it ran broken.
_Avoid_: quit, cancel, fail, relapse

**Completed**:
A commitment that reached its deadline with no break ever observed. A commitment nobody was running to witness reads as completed, because the app holds no evidence otherwise.
_Avoid_: successful, kept, survived
