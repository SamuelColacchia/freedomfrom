# Filter-capacity probe (#80)

How many websites can iOS actually block when a commitment's lists are spread
over named `ManagedSettingsStore`s, and how do Apple's adult filter, its
exceptions and two overlapping stores combine? Apple's documentation states 50
domains per `specific` policy. This probe measures what a real device enforces
beyond that, on real pages in Safari. Its results feed #79's catalogue budget.
A result covers the configuration tested, on the device and iOS it ran on, and
nothing wider.

## What is here

| Path | What it is |
|---|---|
| `project.yml`, `FilterProbe/` | A separate app, `com.samuelcolacchia.freedomfrom.filterprobe`, with only the Family Controls entitlement. It writes only `filterProbeA` and `filterProbeB` and shares nothing with FreedomFrom. |
| `scenarios.json` | The single source of truth: 100 capacity hosts, 3 unlisted controls, and 19 scenarios, each listing what goes in each store and which hosts to observe. Bundled into the app. |
| `hosts.txt`, `controls.txt` | The same hosts, readable. Each one answered 200 from WSL on 2026-10-31; that is not a device observation. |
| `observe` | The harness. It applies a scenario, then loads every host in Safari through macbridge and records a verdict, a screenshot and the full UI tree for each. |
| `results/` | Git-ignored. Raw output per run. |

## Isolation

- A plain launch changes nothing. Only `observe apply` (the app launched with `apply <id>`) writes the stores, and the app exits straight after, so every sweep runs with the app terminated.
- Nothing reapplies on launch or reboot. The persistence checks observe what the system kept.
- The `release` scenario clears both probe stores. Uninstalling the app also removes them.
- metalcloak.com is used through its existing pages only: no DNS, hosting or content changes.

## Running it

The device needs macbridge's phone setup (Developer Mode, UI Automation, WebDriverAgent built) and Safari with a single tab open.

```sh
export FREEDOMFROM_DEVICE=<udid>
scripts/mac probe                                     # archive, sign, install
# A person opens Filter Probe and taps "Authorize Filter Probe" (passcode or Face ID).
probes/filter-capacity/observe preflight
probes/filter-capacity/observe sweep baseline         # every host must load first
probes/filter-capacity/observe scenario split-52      # apply, then observe
probes/filter-capacity/observe scenario split-100
probes/filter-capacity/observe reboot                 # persistence: no reapply
probes/filter-capacity/observe sweep split-100 after-reboot
probes/filter-capacity/observe scenario release       # everything must load again
probes/filter-capacity/observe summary
```

`overlap-clear-b` keeps store A as `overlap` left it, so run it straight after `overlap`.

## Verdicts

| Verdict | Means |
|---|---|
| `blocked` | Safari showed the Screen Time restriction page for this host. |
| `accessible` | The page finished loading, and the address bar showed this host, a subdomain of it, or its recorded redirect. |
| `failed` | Safari showed its own load-error page. A network failure is not evidence of filtering. |
| `unobserved` | Nothing settled within the time limit, or the address bar showed a different site. Never counted either way. |

### Calibration

The block-page pattern (`BLOCKED_RE` in `observe`) is the wording Safari showed on iPadOS 27.0.1 for the first real block (`single-25`, `bbc.co.uk`): **Website Not Allowed** and **"bbc.co.uk" is a restricted website.** The first guess at that wording matched neither, so block pages were scored `accessible`. That is how a wrong pattern fails, and why every row keeps its UI tree.

On any other OS, open the first listed host's screenshot and tree before trusting a count. If the wording differs, fix `BLOCKED_RE` and run `observe rescore ID` on each affected sweep. Rescore re-reads the captured trees, keeps the originals as `rows.orig.tsv`, and never navigates. Never rescore a sweep that is still running, since it is still appending rows.

## Known confounds

- The iPad's Safari has the uBO Lite content blocker installed. It filters content, not navigations, but it is recorded with every run.
- On iPad, Safari loads with the desktop user agent, so redirects can differ from an iPhone.
- `www.metalcloak.com` and `blog.metalcloak.com` both redirect to the apex. Exact-host exception matching on metalcloak therefore cannot be told apart from parent matching, and those rows stay inconclusive. The Wikipedia scenarios (`en.` and `de.` are distinct sites) carry that question instead.
- Only Safari is installed on the test iPad, so browser coverage beyond Safari is unobserved.
