# freedomfrom

An iOS app for one person restraining themselves.

Choose apps and websites, choose a length from fifteen minutes to a year, hold to commit. Until the deadline the apps are shielded and the websites filtered, and the app offers no way to lift it early.

**The honest claim, which no copy in the app may exceed: freedomfrom resists a casual bypass while it is authorized. It cannot prevent a determined one.**

## The way out, named rather than hidden

Screen Time access is revocable in Settings, in about fifteen seconds, behind a Face ID scan. That route exists, the app cannot close it, and the app tells you where it is — on its own Escape screen, in the same words as here.

Revoking does not shorten a commitment. The deadline is absolute and stored, so it passes whether or not the app is installed or running. What revoking ends is the enforcement: the shield, the filter, and the two device-wide restrictions. The commitment is marked broken once and the history says so afterwards.

That is the whole of the bypass resistance, and it is thin on purpose. Anything stronger needs a second person or a supervised device, and this app assumes neither.

## If you want enforcement that actually holds

**Supervise the device with Apple Configurator.** It is the one genuinely strong mechanism available on iOS, and this app deliberately does not build on it.

A supervised device can have Screen Time locked behind a passcode you do not hold, restrictions applied that no app-level API can lift, and profile removal itself blocked. That is the difference between resisting a casual bypass and preventing a determined one.

**It costs erasing the device.** Supervision is applied during setup, so the phone is wiped and restored. That is a real price and it is why this app does not ask you to pay it — but if fifteen seconds and a Face ID scan is not a barrier for you, no amount of app design will make it one, and supervision is the honest answer rather than a better app.

## What it does while it is authorized

Each of these was walked on hardware before being written down, and the results table is in [`docs/hardware-smoke-checklist.md`](docs/hardware-smoke-checklist.md).

- **Apps you pick are shielded.** Apple's shield replaces them.
- **Websites you type are blocked** in Safari, Chrome, Firefox and Brave, and in links opened inside other apps. A bare domain covers its subdomains. Those five are the browsers that were observed to block; the app names no others and does not generalize from them.
- **Safari's Private Browsing switches off** while a commitment with websites runs.
- **No app on the phone can be deleted** — not just this one — and the clock is held automatic. Both were observed to bite under `.individual` authorization.
- **The release arrives on its own**, late rather than early. Two seconds late on the last run, with the app closed.

## What it does not do

- **No lever.** There is no pause, no early release, no "just five minutes". That is the product, not an omission (ADR 0001).
- **No voice.** The app does not announce anomalies, argue with you, or send a notification. What replaces a message is a countdown that states real coverage and a history row written afterwards (ADR 0005).
- **No second device, no account, no sync.** One device, one record, and it is in the Keychain.
- **No claim about degradation.** The app can mark a commitment degraded when a target stops resolving, and whether that is detectable at all has never been observed — the check that would settle it came back inconclusive.

## Building it

iOS and macOS work happens on a remote Mac. `scripts/mac` drives it; `AGENTS.md` has the verbs and the reasoning.

```
scripts/mac build     # compile for the simulator
scripts/mac test      # the kit's suite
scripts/mac uitest    # drive the app on the simulator
scripts/mac device    # sign and install on a connected device. Needs a person
```

The hardware checks are walked by a person on a cabled phone, with a wizard per phase — `scripts/hardware-s2-s3`, `scripts/hardware-c1-c9`, `scripts/hardware-x1-x5`. No agent can close them: several checks are somebody looking at a screen, and the log capture is root-gated.

## Reading the reasoning

Every decision that shaped this is an ADR in [`docs/adr/`](docs/adr/), and several carry amendments fired by hardware results rather than by argument. [`CONTEXT.md`](CONTEXT.md) is the glossary, and each term lists the words it is deliberately not.
