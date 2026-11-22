# App category data prototype

Throwaway exploration of public US App Store metadata for freedomfrom's own
categories. These are candidate queues for human review, not approved blocking
lists. Nothing here changes the iOS app or tests whether blocking works.

From the repository root, with Bun installed:

```sh
bun prototypes/app-categories/fetch.ts
```

This uses only Bun and `fetch`, with no dependencies. It makes 14 sequential
requests when chart enrichment is available: one current chart, two legacy
genre charts, the genre hierarchy, eight keyword searches, a bundle-ID lookup,
and one batch lookup of legacy chart IDs. Each request has a 30-second timeout.
There is a 3.5-second delay between requests, below Apple's documented
approximate 20 calls/minute. It does not retry or paginate. Budget a few minutes.
Failures remain visible in the receipts; the remaining requests continue.

`raw-data.json` and `index.html` are git-ignored: they carry Apple's listing
text, which this public repository must not republish. Run the fetch to make
them.

Open `index.html` directly. It embeds its data, uses system fonts and sends no
network requests until you follow an Apple source link. To open it from WSL:

```sh
explorer.exe "$(wslpath -w /home/samuelcolacchia/projects/freedomfrom/prototypes/app-categories/index.html)"
```

To regenerate the HTML without making any network requests:

```sh
bun prototypes/app-categories/fetch.ts --offline
```

Files:

- `fetch.ts` fetches full responses and derives the eight candidate lists.
- `render.ts` generates the self-contained browser.
- `raw-data.json` holds response bodies, URLs, status, errors and timestamps,
  including the genre hierarchy. It is a reproducible snapshot, not a cache
  policy or a production catalogue. Re-running overwrites it.
- `spot-checks.json` holds manual listing-metadata observations tied to the
  snapshot. Re-check those observations after a fresh fetch.
- `index.html` lets you switch category, inspect every app's bundle ID, primary
  genre, rating count, age labels, descriptors, description and source URLs.

The inclusion rule is deliberately transparent: keep all 20 keyword search
hits, then add Social Networking chart seeds to Social feeds and fetched Games
apps with an explicit `Loot Boxes` advisory to the loot-box queue. Genres shown
as hints are not hidden filters. Lists overlap and de-duplicate by bundle ID.
Rating counts are all-version submitted ratings, not installs.

Spot-checks read five high-rating-count listings per category. They do not
measure overall precision, recall, gameplay or real-money mechanics. Both
false positives and missed apps are expected. A new fetch must invalidate
these human observations until re-reviewed.

See `../../docs/research/app-store-data-for-custom-categories.md` for Apple
source citations, limits, catalogue gaps and reuse terms. Public access is
not evidence that maintaining a production blocking taxonomy or republishing
seller descriptions is licensed.

Layout: a single document scroller with a category selector, derivation facts,
and a comparison table. At narrow widths each app becomes a stacked row.
The first priorities are the experiment's limits, category derivation, then
app evidence. Selecting a category is the primary action. No app artwork,
remote fonts, analytics, persistence or integration is included.
