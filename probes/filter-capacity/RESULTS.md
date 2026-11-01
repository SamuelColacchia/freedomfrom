# Filter-capacity results: iPad Pro, iPadOS 27.0.1, 2026-10-31

What one iPad enforced in Safari for the stores the probe wrote. Every row was captured on the device: a screenshot and a full UI tree, scored by `observe`. A host counts only if it loaded at baseline (105 of 111 did). Raw rows are in `results/20261031/` (git-ignored); the per-sweep tables are in `evidence/`.

The device: iPad Pro 13-inch (M4), iPadOS 27.0.1, no passcode, individual Family Controls authorization granted to Filter Probe, Safari only, with the uBO Lite content blocker installed. These results cover this configuration and nothing wider.

## Headline

**The limit is about 50 unique web domains across all of an app's stores together, not 50 per store. Going over it does not drop the extras. It turns web filtering off entirely, for every store.**

| Scenario | Stores (domains) | Unique | Listed blocked | Listed loaded | Unlisted blocked |
|---|---|---|---|---|---|
| `single-25` | A 25 | 25 | 23 / 23 | 0 | 0 / 75 |
| `single-50` | A 50 | 50 | 46 / 48 | 0 | 0 / 50 |
| `single-51` | A 51, read back 50 | 50 | 45 / 49 | 1 (`loc.gov`) | 0 / 49 |
| `split-40` | A 20, B 20 | 40 | 38 / 38 | 0 | 0 / 39 |
| `split-50` | A 25, B 25 | 50 | *pending re-run* | | |
| `overlap` | A 30, B 30 | 50 | 48 / 48 | 0 | 0 / 4 |
| `split-52` | A 26, B 26 | 52 | **0** / 50 | 47 | 0 / 48 |
| `split-100` | A 50, B 50 | 100 | **0** / 96 | 92 | 0 / 2 |
| `auto-plus-list` | A auto + 50, B 50 | 100 | **0** / 96 | 91 | 0 / 2 |
| `auto-50-except-50` | A auto + 50, except 50 | 50 | 46 / 48 | 0 | 0 / 50 |

"Listed other" (rows that never settled or redirected off-site) is the difference between the listed total and blocked + loaded. It is never counted either way.

- **One store truncates at 50 without saying so.** `single-51` wrote 51 domains and read back 50. The one dropped was `loc.gov`, the 51st in list order. The probe passes a Swift `Set`, whose order varies per process, so one run cannot say whether iOS always drops the last domain or an arbitrary one.
- **Two stores add up, and the sum is what is limited.** 20 + 20 is enforced. 30 + 30 with 10 shared (50 unique) is enforced. 26 + 26 (52 unique) enforces nothing at all: not the first store, not the second, and no partial set. Both stores still read back their full lists.
- **Exceptions do not count toward the 50.** One `auto` store with 50 added domains and 50 exceptions enforced all 50.
- **Apple's adult filter is no way around it.** `auto` with 50 added domains plus a 50-domain specific store (100 unique) enforced nothing, the same as two specific stores.

## Composition and exceptions

| Scenario | What it asks | Observed |
|---|---|---|
| `auto-self-except` | `auto` adds domains 0–9 and excepts 0–4 | All 10 blocked. An exception does not remove a domain its own policy adds. |
| `overlap` → `overlap-clear-b` | A 0–29, B 20–49; then B cleared, A untouched | Before: 0–49 blocked. After: 0–29 still blocked, including the 10 shared hosts; 30–49 load. Clearing a store releases only what no other store holds. |
| `except-vs-block` | A excepts 20–29 the way a helper approval would; B blocks 20–39 | *pending re-run* |

## Host matching

`wikipedia.org`, `www.`, `en.`, `de.` and `fr.` are distinct live sites. metalcloak.com was used through existing pages only: `www.` and `blog.` both redirect to the apex.

| Scenario | Listed | `wikipedia.org` | `www.` | `en.` | `de.` | `fr.` |
|---|---|---|---|---|---|---|
| `wiki-parent` | `wikipedia.org` | blocked | blocked | blocked | blocked | blocked |
| `wiki-sub` | `en.wikipedia.org` | loaded | loaded | blocked | loaded | loaded |
| `wiki-except` | `auto` adds `wikipedia.org`, excepts `en.` | blocked | blocked | **blocked** | blocked | blocked |

| Scenario | Listed | `metalcloak.com` | `www.` | `blog.` |
|---|---|---|---|---|
| `mc-parent` | `metalcloak.com` | blocked | blocked | blocked |
| `mc-www` | `www.metalcloak.com` | loaded | blocked | blocked |
| `mc-except` | `auto` adds apex, excepts `www.` | blocked | blocked | blocked |

- **A listed domain covers its subdomains; a listed subdomain covers only itself** (`wiki-parent`, `wiki-sub`).
- **An exact-host exception does not carve a subdomain out of a parent the same policy adds** (`wiki-except`, `mc-except`). This is the same rule as `auto-self-except`.
- When a parent is listed, Safari's block page for `www.wikipedia.org` names `wikipedia.org`, the listed rule, not the host typed.
- `mc-www` is one unexplained sample: listing `www.metalcloak.com` blocked `blog.metalcloak.com` but not the apex. Both redirect to the apex, so this may be about redirects rather than matching. A second sample is *pending*.

## Persistence

- **App termination:** the probe exits straight after every write, and every sweep above ran with it terminated. Stores held in every sweep.
- **Device restart:** *pending.* `single-50` was applied, the iPad rebooted, and nothing will be reapplied before the after-reboot sweep.

## What this changes for #79

A launch catalogue cannot rely on several 50-domain stores. On this device, the whole app's web filtering is on only while the union of every store's domains stays at or under 50 (50 enforced; 52 did not). Past that, every commitment's website blocking stops at once, while every store still reads back as set. An app cannot detect that from its own readback.

## How it was observed, and what went wrong on the way

`observe` loaded each host in a single Safari tab through macbridge (WebDriverAgent over CoreDevice), with `about:blank` in between. It polled the UI tree until a block page, a Safari error or a finished load appeared. A row counts only if the address bar shows that host, and a block row only if the page names that host or its listed parent.

Four harness bugs surfaced during the run. Each was fixed, and every affected row was rescored from its captured tree or re-run. None was scored by assumption:

1. **Wrong block wording.** The guessed block-page wording matched nothing, so block pages scored `accessible`. It was calibrated against `single-25`'s first block, and the sweeps were rescored.
2. **Truncated addresses.** Safari truncates long addresses (`nationalgeographi...`). Prefix matching was added and the baseline rescored.
3. **A stuck address field.** On a block page, the address field kept the old URL and typing appended to it, so 10 sweeps reloaded the previous blocked host. Those sweeps are kept as `sweep-stuck` and were re-run.
4. **Truncated sweeps.** A failed tap let ssh consume the host list, and a page that never settled tripped `set -e`, so three sweeps ended early. `split-40` lost only unlisted rows 82–103; `split-50` and `except-vs-block` are re-run.
