# The Mac is a mirror and a simulator, and the human is one visit

The WSL2 tree is the only source of truth. Every build rsyncs it destructively into a scratch directory on the Mac, which holds no clone, no credential, and nothing that can author a commit. The loop an agent runs all day targets the **iOS Simulator**, which ad-hoc signs and therefore needs no identity, no keychain, and no person — measured at **1.7 seconds** from edit to `Build Succeeded`. Signing exists only on the device path, where a human is already required to cable the phone, so the two human moments collapse into one visit.

Every command in this ADR was run against `ssh mac` before it was written down.

## The loop

`scripts/mac` is one dispatcher on the WSL2 side. **There is no `sync` verb**: the rsync is inside every verb, so nothing can run against a stale mirror.

| Verb | What it does | Measured |
|---|---|---|
| `build` | sync, `xcodegen generate`, `xcodebuild` for the simulator, through `xcbeautify` | 1.7s warm, 4.6s cold |
| `test` | sync, `swift test` on `FreedomFromKit` | 10s cold |
| `run [secs]` | `build`, boot, install, launch, print the app's own log lines | +9s for a cold boot |
| `log [mins]` | re-read those lines without rebuilding | under 1s |
| `rawlog [lines]` | tail the unfiltered `xcodebuild` log | under 1s |
| `device` | probe the cable and the signing socket, then archive, sign, install | attended |
| `clean` | drop the derived-data cache and the generated project | — |

Layout on the Mac, all under `~/builds/freedomfrom`:

- `src/` — the mirror. `rsync -az --delete`, excluding `.git/`, `.build/`, `DerivedData/`, and the two agent-runtime directories.
- `derived/` — the derived-data cache, **outside `src/`** so `--delete` cannot reach it. This is the whole 1.7s.
- `logs/` — the raw `xcodebuild` output, which is what `rawlog` reads.

`~/builds/`, not `/tmp/`: macOS reaps `/private/var/tmp` files untouched for three days, so a `/tmp` scratch would silently degrade to the cold path after any quiet weekend.

The generated `FreedomFrom.xcodeproj` lives inside `src/` and is therefore deleted and regenerated on every single sync. That was expected to cost the incremental cache and measurably does not: 1.36s and 1.55s deleting it every time, against 1.44s and 1.41s excluding it. Derived data is keyed by project path and build settings, not by inode. So there is no rsync exclusion for it, and one less rule to explain.

## Why the fast loop needs no signing

Issue #13 handed this decision the question *"per session, so which session"* — a human-unlocked `ControlMaster` socket, a dedicated keychain with its password on disk, or the App Store Connect key. A probe reframed it. An app carrying `com.apple.developer.family-controls` built for the simulator over a **fresh, unmultiplexed SSH connection with no keychain unlock**:

```
Signing Identity:     "Sign to Run Locally"
** BUILD SUCCEEDED **
```

The simulator platform ad-hoc signs. So the signing problem leaves the daily path entirely: an agent iterating on `FreedomFromKit` and the app's logic never needs an identity, a keychain, or a person. The ASC key was never a `codesign` answer in the first place — it provisions, it does not sign.

What remains on the device path needs a human twice over, and both are the same visit: issue #13 fixed that **devices are plugged in only when installing**, and that a keychain unlock **does not cross a login session**. The person standing at the Mac with a cable unlocks the socket while they are there.

`scripts/mac device` therefore **probes before it builds**. Both preconditions are checkable in well under a second, against an archive that is minutes, and they need different things from the human, so only a probe can tell them apart in advance. Verified: with no socket it exits 3 and prints the unlock lines; with a socket that was never unlocked it exits 3 and says so; a missing cable exits 4.

The unlock lines are **printed, never run**. That is what keeps issue #13's property intact — the password is typed into the human's own shell and piped over the shared socket, and never enters the agent's session.

## Failure comes back as `file:line:col`

Raw `xcodebuild` names the failed *commands* and not the reason:

```
SwiftCompile normal arm64 .../Broken.swift (in target 'FreedomFrom')
(5 failures)
```

The same build through `xcbeautify --quiet`:

```
❌ .../Sources/App/Broken.swift:2:37: cannot convert value of type 'String' to specified type 'Int'
struct Broken { let deadline: Int = "not a date" }
                                    ^~~~~~~~~~~~
exit=65
```

`file:line:col` maps to an edit without a second lookup. The message lives thousands of lines above the tail, so tailing the log fails structurally rather than cosmetically. `set -o pipefail` carries xcodebuild's exit 65 through the pipe; without it the pipeline reports the filter's success. `tee` keeps the unfiltered log at a fixed path for the cases the summary drops — linker errors, provisioning diagnostics, extension embedding — and `rawlog` reads it without rebuilding.

`xcbeautify` 3.2.1 is already on the Mac's SSH `PATH`, so this adds no dependency. Nothing here parses `xcodebuild`'s output by hand.

## The simulator answers ADR 0009's evidence channel, halfway

ADR 0009 made the logging contract load-bearing because a wordless app returns no other signal, and routed the evidence through `devicectl device sysdiagnose` read with `log show --archive`, noting that *"the evidence channel is itself unverified"*. That is still true of the device. It is now false of the simulator:

```
2026-08-29 21:59:25.711 Df FreedomFrom[50334] [com.samuelcolacchia.freedomfrom:app] launch coverage resolved=2 of named=3
```

`xcrun simctl spawn booted log show --predicate 'subsystem == "com.samuelcolacchia.freedomfrom"'`, in the same second, with the `.public` values rendered. So the contract is testable months before a device is cabled: a field that prints `<private>` where ADR 0009 requires public says so on day one.

`build` and `run` stay separate verbs. `build` answers *does it compile* and is the thing an agent runs most; paying the ~9 second cold boot to answer that would tax the whole loop. Reading by predicate rather than dumping the console is what preserves the distinction ADR 0009 bought its per-process categories for: *the monitor never woke* against *the monitor woke and found nothing*.

**The limit, stated plainly.** The simulator proves a line was emitted and a build launches. It never proves a shield applied. Every enforcement claim still belongs to the hardware pass in [`docs/hardware-smoke-checklist.md`](../hardware-smoke-checklist.md).

## `swift test` runs on the Mac, not here

`FreedomFromKit` is Foundation-only by ADR 0009, which also makes it Linux-capable, and swift.org ships an Ubuntu 24.04 toolchain. Running the kit's tests locally would remove the network hop entirely.

Rejected, because Linux runs **swift-corelibs-Foundation** and the kit's subject matter is exactly where the two Foundations diverge: `Date`, `Calendar`, `DateComponents`, `TimeZone`. ADR 0004's walk-forward step is calendar arithmetic across week boundaries — the precise bug class that would pass here, fail there, and stay hidden. ADR 0009 called these tests "the contract" and "the only executable feedback in the entire project"; a contract verified against an implementation that does not ship is worth less than the second it saves. The ssh hop measures 0.18s.

## No CI for v1

There is no `.github/`, and none is added. CI's value is catching what a developer skipped, and this is a solo repo where every change already goes through `scripts/mac test` on its way to being believed.

The only check a hosted runner could perform for free is the kit's tests, because the kit imports no Apple framework — and that is also the check that already runs in ten seconds on demand. It could not touch the app targets at all: those need the signing identity, which lives only on this Mac, and **this repo is public**, so putting that identity in Actions secrets buys real exposure for a check the Mac does better. A self-hosted runner on the Mac mini has the identity but inherits issue #13's per-login-session keychain problem in a daemon context nobody has probed.

CI returns when a second contributor does.

## Considered options

**GitHub as the transport (rejected).** Commit and push from WSL2, pull on a Mac clone. It taxes every build attempt with a commit — against a 1.7s build, the commit is the dominant cost — and fills the history with "try again". The Mac can already pull this public repo over HTTPS, but its SSH key is not registered with GitHub, so it cannot push. That is a feature: nothing on the build host can author a commit, which is what makes the WSL2 tree the only thing that *can* be the source of truth.

**sshfs (rejected).** Puts the compiler's file reads over the LAN for a build that currently reads local APFS.

**Drift as an argument against rsync (does not apply).** Drift needs two writable copies. A one-way `--delete` mirror into a directory nobody edits cannot drift; the Mac copy is output, not a peer.

**A dedicated signing keychain with its password on disk (rejected).** It would buy unattended device builds, but the thing it unblocks is *install*, which is already gated on someone holding a cable. A permanent credential on disk for no reachable benefit.

**One script per verb sharing a `_common.sh` (rejected).** Every verb shares the same preamble — the scratch paths, `export PATH=$HOME/.local/bin` (xcodegen and xcbeautify are not on the non-interactive SSH `PATH` by default), `set -o pipefail`, and the rsync. That is two files of indirection for five short functions, and a second place for the sync to be forgotten.

**A Makefile (rejected).** Buys dependency tracking xcodebuild already does better, and adds tab-versus-space failure modes to a file agents edit.

**One verb that always launches (rejected).** Simpler surface, but it charges the boot to every compile check.

**A `sync` verb (rejected).** Any verb that can be *forgotten* eventually is. Folding it into each command makes a stale mirror unreachable rather than merely unlikely.

## Consequences

- **Nothing on the Mac is ever committed from.** It has no clone, no `gh`, and no GitHub push credential, so `~/builds/freedomfrom` needs no `.gitignore` of its own. It is output.
- **Manual edits in Xcode are ephemeral, twice over.** The next `xcodegen generate` overwrites the project, and the next sync overwrites the sources. Anyone opening the GUI is editing a copy.
- **The named commands are the interface, and `AGENTS.md` carries them.** Issue #7's requirement that they "live in the repo, not in an agent's memory".
- **`FreedomFromKit`'s `Package.swift` needs `swift-tools-version:6.2`.** Naming `.iOS(.v26)` under 6.0 fails with `'v26' is unavailable`; found by building it. The build spec should carry this.
- **The device path is specified but unexercised.** Its two preconditions are verified to fire correctly; the archive-sign-install behind them has not run since issue #13 proved the same sequence by hand. The walking skeleton is what proves it, which ADR 0009 already predicted: it "doubles as proof of the workflow and identity decisions".
- **Cold numbers here come from a one-file probe.** 4.6s cold and 1.7s warm are the shape, not a promise; three targets and a package will be slower cold. Warm incremental is the number that matters and it is dominated by what changed, not by the transport.
- **`CONTEXT.md` gains nothing.** Mirror, scratch, and signing socket are workflow vocabulary, and the glossary is a domain glossary.
