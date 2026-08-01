# freedomfrom

iOS app for restricting access to apps and websites — filtering and blocking.

## Build host

iOS/macOS work happens on a remote Mac reachable at `ssh mac` (macOS 26.6,
Xcode 26.6, arm64). Xcode builds, simulators, signing, and `xcodebuild` runs go
there; this Linux box holds the repo and drives the agent skills.

## Agent skills

### Issue tracker

Issues and PRDs live in this repo's GitHub Issues, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles, using their default label strings. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context — one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
