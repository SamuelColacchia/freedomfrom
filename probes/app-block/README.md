# App-block probe

Can `ManagedSettings` block an app by bundle identifier, under the individual
authorization freedomfrom uses, including an app that is not installed yet? The
picker returns opaque tokens for installed apps only, so this is the only route
to a list of apps the app writes itself (custom categories). A result covers the
device and iOS it ran on, and nothing wider.

## What is here

| Path | What it is |
|---|---|
| `project.yml`, `AppBlockProbe/` | A separate app, `com.samuelcolacchia.freedomfrom.appblockprobe`, with only the Family Controls entitlement. It writes one named store, `appBlockProbe`, and only its `application.blockedApplications`. |

## Running it

```sh
export FREEDOMFROM_DEVICE=<udid>
scripts/mac probe app-block      # archive, sign, install
# A person opens App Block Probe and taps "Authorize App Block Probe".
mac phone run com.samuelcolacchia.freedomfrom.appblockprobe block <id>[,<id>...]
mac phone run com.samuelcolacchia.freedomfrom.appblockprobe status
mac phone run com.samuelcolacchia.freedomfrom.appblockprobe release
```

Each run prints one JSON line with what was requested and what the store reads
back. A plain launch changes nothing. Uninstalling the probe removes its store.

## Results, 2026-11-22, iPad (9), iPadOS 27.2.1

| # | Check | Observed |
|---|---|---|
| A | Block an installed app (Google Earth, `com.google.b612`) | Its icon left the Home Screen and the dock. Launching it failed with `FBSApplicationLibrary returned nil`, as if it were not installed. `devicectl` still listed it. Spotlight showed only the App Store result, offering "Update", not "Open". No Screen Time block screen appeared. |
| B | Block an app that is not installed, then install it (Filter Probe, removed with `devicectl`, blocked, reinstalled with `scripts/mac probe`) | Installed, but hidden: no icon, and launching it failed the same way as A. |
| C | Release (`blockedApplications = nil`) | Both came back and launched normally, Filter Probe straight away. |
| — | Authorization | `.individual`, granted through the system prompt. Nothing else was needed. |

So the route works: a store can hold bundle identifiers for apps that are not
installed, and an app installed later is caught as it arrives.

### Not observed

- Installing from the **App Store** while blocked. B installed a signed build
  with `devicectl`; the App Store path may behave differently.
- A **reboot** with the block set.
- How many bundle identifiers one store accepts. `blockedApplications` has no
  documented cap here; the web filter's was 50 (#80).
- Whether a blocked app's **notifications** still arrive.
- What happens when freedomfrom's own identifier is in the list.

### Side effects worth knowing

- freedomfrom's `denyAppRemoval` blocks `devicectl` uninstalls too ("Uninstall
  prohibited") while a commitment runs. The test commitment was ended with the
  unlock code to run B.
- The hidden app leaves no trace a person would notice except its absence and
  the App Store's "Update" button, which may matter for the privacy goal.
