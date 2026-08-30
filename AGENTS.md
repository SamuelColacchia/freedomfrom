# freedomfrom

iOS app for restricting access to apps and websites — filtering and blocking.

## Build host

iOS/macOS work happens on a remote Mac reachable at `ssh mac` (macOS 26.6,
Xcode 26.6, arm64). Xcode builds, simulators, signing, and `xcodebuild` runs go
there; this Linux box holds the repo and drives the agent skills.

**Never run `xcodebuild`, `xcodegen`, `swift test`, or `simctl` by hand.** Use
`scripts/mac`, which knows the paths, the PATH, and the log handling:

```
scripts/mac build          # compile for the simulator. ~1.7s warm. No signing, no human.
scripts/mac test           # swift test on FreedomFromKit, against Darwin Foundation
scripts/mac uitest         # drive the app on the simulator. The only verb that presses anything
scripts/mac run [secs]     # build, launch on the simulator, print the app's own log lines
scripts/mac shot [file]    # capture what the simulator is showing right now
scripts/mac log [mins]     # re-read those log lines without rebuilding
scripts/mac rawlog [lines] # tail the unfiltered xcodebuild log
scripts/mac device         # sign and install on the phone. Needs a human.
scripts/mac clean          # drop the derived-data cache and the generated project
```

This repo is the **only** source of truth. Every verb rsyncs it into
`~/builds/freedomfrom/src` on the Mac first, destructively, so there is no sync
step to forget and nothing on the Mac is ever edited or committed from.

Failures come back as `file:line:col` with the message, through `xcbeautify`,
with the exit code preserved. If the summary is not enough, `scripts/mac rawlog`.

`scripts/mac uitest` is the only thing in the loop that touches the app the way
a person does. `build` proves it compiles and `test` proves the kit's logic;
neither presses anything, which is how two broken hold-to-confirm fixes shipped
green. Use it for anything a user does with a finger.

It has a hard limit worth knowing before you trust it: **a synthesised press is
perfectly still.** Gesture bugs that need a real thumb — drift, jitter, a
recogniser that fails only under actual input — pass here and fail on the phone.
FB15711941 is one of those. A green `uitest` means the wiring is right, not that
the gesture survives a hand.

`scripts/mac device` is the one verb that needs a person: the phone has to be
cabled, and the login keychain has to be unlocked inside a shared SSH session.
It probes both in under a second and prints the exact unlock lines for a human
to run in their own shell. Do not run those lines yourself and do not ask for
the password — printing them is what keeps it out of the agent's session.

The full reasoning, and the measurements behind it, are in
`docs/adr/0010-the-mac-is-a-mirror-and-a-simulator.md`.

## The hardware pass

`docs/hardware-smoke-checklist.md` is walked by a person on a cabled phone, and
no agent can close it: the picker's tokens exist only once somebody has tapped
them, several checks are somebody looking at a screen, and `log collect` is
root-gated on the Mac. **Do not fill in a results row you did not observe.** A
fabricated row is worse than an empty one, because every claim the app makes is
reconciled against that table before TestFlight.

`scripts/hardware-s2-s3` is the wizard for the two gates on the walking
skeleton. It does the install, the log reads, the verdicts, the results table,
and the bound amendment; the human supplies the taps and the one `sudo` line it
prints rather than runs. Other phases have no wizard yet, and one built the same
way is the right way to add them.

## Agent skills

### Issue tracker

Issues and PRDs live in this repo's GitHub Issues, via the `gh` CLI. **Every issue gets a milestone at creation time** — currently `v1`. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles, using their default label strings. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context — one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
