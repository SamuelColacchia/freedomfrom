# Bypass resistance for a solo self-restraint user

## ⚠️ Wipe-required answer first

If the goal is **real bypass resistance**, the only Apple-supported route I found that materially hardens an iPhone/iPad is **supervision on a freshly erased device** plus supervised restrictions. Apple says manual supervision with Apple Configurator requires the device be in your physical possession, connected to a Mac, and that “the device is erased and all data is lost.” Changing supervision later also requires erase/prepare/supervise again. [Apple Configurator manual prepare](https://support.apple.com/guide/apple-configurator-mac/prepare-an-iphone-ipad-or-apple-tv-manually-cad99bc2a859/mac) · [About Apple device supervision](https://support.apple.com/guide/deployment/about-device-supervision-dep1d89f0bff/web)

## Ranked by strength vs setup cost

| Rank | Mechanism | What it actually blocks | What it does **not** block | Setup cost | Wipe? | FamilyControls coexistence |
|---|---|---|---|---|---|---|
| 1 | **Supervised device + supervised restrictions** | App removal (`allowAppRemoval=false`), Screen Time/restrictions changes (`allowEnablingRestrictions=false`), and potentially profile removal (`PayloadRemovalDisallowed=true`) on supervised profiles | A full device erase, and anything you did not explicitly restrict | High | **Yes** | Likely yes; I found no Apple doc saying it conflicts |
| 2 | **Built-in Screen Time passcode** | Changes to Screen Time settings; on Opal’s docs, also deleting the blocker app / disabling its permissions | Device erase; if recovery Apple Account creds are known, reset reopens the bypass | Low | No | Yes |
| 3 | **App-level friction stack** (App Uninstall Protection, Pin Code, Focus Filters, Shortcuts) | Makes cancellation annoying; can block uninstall during an active session, redirect Settings, or auto-launch blocks | A determined user who can end sessions, disable automations, or reset Screen Time | Low | No | Yes |
| 4 | **DNS / VPN / Network Extension filtering** | Web destinations, some app traffic, depending on payload and routing | App deletion, Settings changes, and many offline bypasses | Medium | Usually no, but many strong forms are supervised-only | Yes |
| 5 | **Persistence only** (Keychain / CloudKit) | Preserves the commitment record so reinstalling does not erase the history | Actual bypass; the user can still delete the app or wipe the device | Low | No | Yes |
| 6 | **Focus-mode / Shortcut automation only** | Adds friction or redirects | Almost everything if the user disables Focus/Shortcuts | Low | No | Yes |

## Mechanism notes

### 1) Supervised device + supervised restrictions

This is the strongest real answer. Apple’s supervised-device docs say supervision gives “ongoing control,” some payloads are supervised-only, and manual supervision via Apple Configurator requires physical possession and a wipe. Apple’s platform restrictions docs say `allowAppRemoval=false` disables app removal on iPhone, and `allowEnablingRestrictions=false` disables the Enable Restrictions / Enable Screen Time UI and disables Screen Time if already enabled. [Restrictions YAML permalink](https://github.com/apple/device-management/blob/67045e2fa06f528b196c01edee6a8bf88b844beb/mdm/profiles/com.apple.applicationaccess.yaml#L343-L364) · [Restrictions YAML permalink](https://github.com/apple/device-management/blob/67045e2fa06f528b196c01edee6a8bf88b844beb/mdm/profiles/com.apple.applicationaccess.yaml#L1357-L1384)

For profile removal, Apple’s Configuration Profile Reference documents `PayloadRemovalDisallowed` as supervised-only. The caveat: Apple also says manually installed profiles with that key can still be removed manually with administrative authority, so I would **not** treat this as a magic anti-delete button by itself. It only becomes meaningful as part of a supervised/device-management posture. [Configuration Profile Reference PDF](https://developer.apple.com/business/documentation/Configuration-Profile-Reference.pdf)

**Verdict:** strongest real bypass resistance, but it costs a wipe and is therefore the right “hard block” lever if you can tolerate the setup.

### 2) Built-in Screen Time passcode

Apple says a Screen Time passcode must be entered before changing Screen Time settings. If you forget it, Apple’s recovery flow resets it using the Apple Account used when the passcode was set; on child devices, only the family organizer can reset it. Screen Time settings also sync across devices using CloudKit end-to-end encryption. [Apple Support](https://support.apple.com/en-us/102677) · [Screen Time security](https://support.apple.com/guide/security/screen-time-security-secd8831e732/web)

This is the best **non-wipe** layer for a solo user, but it is not unbreakable: if the recovery Apple Account is available, the bypass reopens.

**Programmatic setup:** I could not confirm a public API to set the passcode programmatically; Apple’s docs I found only describe setting it in Settings.

### 3) App-level friction stack (Opal-style)

Opal documents four useful pieces:
- **App Uninstall Protection** prevents uninstalling Opal or other apps during a Session, and also blocks changing the phone’s time/date. [Opal help](https://www.opal.so/help/what-is-app-uninstall-protection)
- **Screen Time Passcode** is documented as the “single strongest foolproof move on iOS”; Opal says it prevents disabling Opal’s Screen Time access and can require the passcode to delete Opal. [Opal help](https://www.opal.so/help/what-is-screen-time-passcode)
- **Lock Opal’s Screen Time Access** adds a Shortcuts-based Settings trap on older iOS versions. [Opal help](https://www.opal.so/help/how-to-lock-opals-screen-time-access)
- **Focus Mode sync** can auto-start/end sessions, but ending Focus does not end an Opal session; it’s one-directional. [Opal help](https://www.opal.so/help/how-to-use-iphone-focus-filters-together-with-opal)

This is good UX friction, not strong security.

### 4) DNS / VPN / Network Extension filtering

Apple’s deployment docs expose `Web Content Filter`, `DNS Settings`, `DNS Proxy`, `Global HTTP Proxy`, and VPN payloads for managed devices. These can meaningfully block web access, but they are not app-uninstall resistance; they are network controls. Many of the stronger forms are supervised-device/MDM territory. [Apple Platform Deployment](https://support.apple.com/guide/deployment/welcome/web)

**Verdict:** useful as an additional layer, not as the core bypass-resistance answer.

### 5) Persistence only: Keychain / CloudKit

Apple Platform Security says Screen Time data syncs across devices via CloudKit, and the keychain is a device database with app access-group isolation. The practical upside is persistence: a commitment record or secret can survive an uninstall/reinstall cycle even if the app goes away. Apple DTS has also said app keychain items survive app deletion, and a June 2024 forum reply says that was still true on iOS 17.5. [Apple forum thread](https://developer.apple.com/forums/thread/36442) · [Keychain data protection](https://support.apple.com/guide/security/keychain-data-protection-secb0694df1a/web)

This is **not** bypass resistance. It only preserves evidence/state after the user escapes.

### 6) Focus modes / Shortcut automation only

one sec documents its setup as a personal automation in Shortcuts, triggered when an app opens. That’s friction, not hard enforcement. [one sec tutorial](https://tutorials.one-sec.app/en/articles/3034626)

Jomo’s public feature page says **Strict Mode** makes rules “unbreakable” and you “can’t delete or bypass them,” but I could not confirm the underlying mechanism from a primary source beyond their product docs. [Jomo features](https://jomo.so/features)

Freedom’s homepage says **Locked Mode** prevents quitting a Freedom session. That’s also softer than OS-level protection. [Freedom homepage](https://freedom.to/)

## Could not confirm

- A **programmatic API** for setting a Screen Time passcode.
- A truly robust **no-MDM, no-wipe** path that both prevents app removal and makes the blocker profile itself effectively nonremovable on a personally-owned iPhone.
- Public docs for **Brick** and **ScreenZen**: their sites returned bot/availability errors from this environment, so I could not verify their “strict/deep/hard block” mechanisms directly.

## Bottom line

If you want the **strongest real bypass resistance**, the answer is: **supervise a freshly erased device and use supervised restrictions**. If you want **minimal setup cost**, use Apple Screen Time passcode + app-level friction, but be honest that this is not tamper-proof.
