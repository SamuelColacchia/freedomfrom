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
scripts/mac run [secs]     # build, launch on the simulator, print the app's own log lines
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

`scripts/mac device` is the one verb that needs a person: the phone has to be
cabled, and the login keychain has to be unlocked inside a shared SSH session.
It probes both in under a second and prints the exact unlock lines for a human
to run in their own shell. Do not run those lines yourself and do not ask for
the password — printing them is what keeps it out of the agent's session.

The full reasoning, and the measurements behind it, are in
`docs/adr/0010-the-mac-is-a-mirror-and-a-simulator.md`.

## Agent skills

### Issue tracker

Issues and PRDs live in this repo's GitHub Issues, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles, using their default label strings. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context — one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
