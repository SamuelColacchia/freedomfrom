# Device builds sign and install unattended, through macbridge

`scripts/mac device` archives, signs and installs on the phone with nobody at the Mac. Signing moved out of this repo into **macbridge** (`~/projects/macbridge`), a general tool for driving the Mac from WSL2: a dedicated keychain on the Mac, whose random password lives on the Mac and is unlocked by every session that signs, holds an Apple Development identity minted through the App Store Connect API; the same API key lets `xcodebuild -allowProvisioningUpdates` make profiles and register devices on its own. This supersedes the signing half of ADR 0010, which made the device path "one human visit".

Every command in this ADR was run against `ssh mac` and the phone before it was written down.

## Why the visit went

ADR 0010 rejected "a dedicated signing keychain with its password on disk" because the install it unblocks was gated on a person holding a cable anyway. Two facts moved since:

- **The phone is not cabled.** It pairs over Wi-Fi, and CoreDevice brings an idle phone's tunnel back up when a command targets it. The install no longer needs anyone at the Mac, so the keychain unlock was the only remaining reason for a visit.
- **The owner chose unattended operation over the isolation issue #13 bought.** The trade is explicit: anyone with this user's shell on the Mac can sign as the team's development identity. Revoking that one certificate undoes it; the login keychain is untouched.

## What was measured

| Step | Result |
|---|---|
| `mac signing status` over a fresh, unmultiplexed ssh with no unlock | `codesign probe: signed, nobody present` |
| `scripts/mac device`, phone on Wi-Fi then cable, no human | `Archive Succeeded`, `App installed`, 29s warm |
| Archived app | team `6989TSP54U`; `family-controls`, app group and keychain group entitlements; `Monitor.appex` and `ShieldConfig.appex` embedded |

## What changed with Xcode 27

The phone runs iOS 27, so the Mac moved to Xcode 27.0 (the developer disk image would not mount under 26.6). `devicectl list devices` now prints the hardware UDID where it printed the CoreDevice UUID, and its columns moved, so the old table parsing in `scripts/mac` and in the three wizards' preflights could no longer find the phone at all. Device selection now goes through `mac phone which`, which matches `FREEDOMFROM_DEVICE` against the CoreDevice UUID, the UDID or the name, reads `devicectl`'s JSON, and connects an idle phone rather than calling it absent. The wizards take `DEVICE_UDID` from the same row.

## Consequences

- **macbridge is a dependency of the device path.** Its `mac` CLI must be on PATH; without it `scripts/mac device` exits 3 and says so. The simulator verbs do not use it.
- **Device builds land where macbridge mirrors:** `~/builds/<repo name>` on the Mac, which is this repo's default `FREEDOMFROM_MAC_ROOT`. Overriding that root moves the simulator verbs and not the device verb.
- **The wizards ask macbridge, not a person,** whether signing works. The hardware pass still needs a human for the taps and for what only eyes can check; ADR 0009's reasons for that are unchanged.
