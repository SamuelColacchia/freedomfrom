# App Store data for custom self-restraint categories

Checked 2026-11-22 against Apple documentation and live Apple responses. Context7 discovery returned no available tool, so this note uses Apple pages and endpoints directly. "Observed" describes these responses, not a promised API contract.

## Findings

Apple's public Search and Lookup APIs can supply candidate apps, bundle identifiers, store genres, descriptions, and content advisories. They are useful inputs to a reviewed taxonomy, but the documented search interface and chart feeds do not establish an exhaustive catalogue. Store categories describe discovery placement; they do not directly define custom categories such as short video or games with loot boxes. Apple even distinguishes its Social Media Time Allowance category from App Store categories, using declared social capabilities instead. [Search documentation][search-doc] [Category guidance][categories]

`advisories` is a useful observed signal and must be retained. The US `short video` search returned Kwai, `com.kwai.intl`, with `"Loot Boxes"` in `advisories`, alongside Entertainment and Social Networking genres. Bundle-ID Lookup independently returned the same advisory. Both age scalar fields were `"12+"`. Thus a loot-box signal exists outside Games, and an age threshold alone cannot express the desired category. [Search response][sample-search] [Lookup response][sample-lookup]

Production reuse needs clarification. Apple's Search overview permits promotional assets only to promote store content. It does not establish a clear license for a standalone blocking taxonomy. EPF's published terms are substantially narrower than "download a catalogue": they restrict Feed Data to generating Apple Services links and explicitly prohibit training AI systems or using existing AI systems to process the data. [Search terms][search-doc] [EPF legal section][epf]

## Sources, fields, and limits

| Source or field | Verified information | Limit or implication |
| --- | --- | --- |
| Search | `https://itunes.apple.com/search?term=…&media=software&entity=software&country=us&limit=…`; JSON results. Apple documents `software`, `iPadSoftware`, and `desktopSoftware` entities. [Documentation][search-doc] | Required text `term`; documented default limit 50, allowed range 1–200. The parameter table documents no pagination or complete-enumeration mechanism. A result cap is not a coverage guarantee. [Documentation][search-doc] |
| Lookup | ID-based lookup is documented as faster with fewer false positives. `lookup?bundleId=com.kwai.intl&country=us` returned one software record with numeric `trackId=1338605092`. [Documentation][search-doc] [Observed response][sample-lookup] | The cited public parameter documentation does not specify the `bundleId` selector, its batch limits, or a software-specific schema. Treat bundle-ID lookup support as observed. |
| `bundleId` | String returned in both sampled software Search and Lookup records. [Search][sample-search] [Lookup][sample-lookup] | Useful identifier for taxonomy records; charts need Lookup enrichment because the sampled modern chart lacks this field. [Chart response][modern100] |
| `primaryGenreName`, `primaryGenreId`, `genreIds`, `genres` | Software responses expose primary genre name/ID and arrays of genre IDs and names. Kwai has Entertainment `6016` and Social Networking `6005`. [Lookup][sample-lookup] | Developers choose primary and secondary categories; games can have subcategories. Preserve all IDs rather than selecting only the primary name. This is a recommendation based on Apple's category model. [Category guidance][categories] |
| `trackContentRating`, `contentAdvisoryRating` | Both observed as strings, including `12+` and `17+` in the search sample. [Search][sample-search] | These scalar values do not identify the underlying reason. Apple documents different ratings by region and OS generation; do not assume a universal numeric scale or silently translate old values into new ones. [Definitions][age-definitions] |
| `advisories` | Observed array of descriptive strings, sometimes with frequency prefixes. Kwai includes exactly `"Loot Boxes"`. [Search][sample-search] [Lookup][sample-lookup] | The cited Search result-key documentation does not define this field or promise descriptor completeness, stable wording, localization, or update timing. Missing or empty must mean unknown, not proven absence. |
| `description`, `sellerName`, `userRatingCount` | Observed text description, seller string, and numeric rating-count field in software responses. The search sample includes an app with count `0`. [Search][sample-search] | Use descriptions as candidate evidence and rating count for review prioritization, not as proof of behavior or installation counts. Those uses are recommendations, not Apple classifications. |
| Search/Lookup operation | Apple documents approximately 20 Search API calls/minute, subject to change, and recommends caching Search and Lookup requests. `country` selects the country storefront, defaults to US; documented `lang` values are `en_us` and `ja_jp`. [Documentation][search-doc] | Send country explicitly and cache by country and query/identifier. Per-IP versus per-client enforcement, software Lookup batching limits, and a guaranteed quota/SLA are **unverified**. Do not treat 20/minute as a throughput entitlement. |
| Current marketing RSS | Generator offers Apps; its app configuration lists Top Free and Top Paid. URL pattern is `/api/v2/{country}/apps/{top-free or top-paid}/{count}/apps.json`. [Generator][rss-builder] [App configuration][rss-app-feeds] | No genre control appears in the generator or its URL-building code. The observed JSON contains app IDs, name, artist, URL, artwork, and `genres`, but not the requested Lookup detail fields. Ten of the 100 sampled records had empty `genres`. [Generator code][rss-code] [Response][modern100] |
| Legacy RSS | `/us/rss/topfreeapplications/limit=10/genre=6005/json` returned 10 entries, all with category ID `6005`. The official genre service also publishes genre-specific legacy RSS URLs. [Response][legacy10] [Genre service][genre-list] | Nested `feed.entry` objects use `id.attributes["im:id"]` and `category.attributes`, unlike modern `feed.results`. Lookup enrichment is still needed for bundle IDs and advisories. [Response][legacy10] |
| Official genre list | Apple's live genre service at `…/ws/genres?id=36` returns the App Store root, IDs, names, nested subgenres, and RSS URLs. Apple's category guide explains meaning and category selection. [JSON list][genre-list] [Guide][categories] | The service is Apple-hosted primary data, but its versioning/support contract is **unverified**. It includes names such as Catalogs; do not assume every returned legacy genre remains selectable today. |
| App Store Connect age declarations | Documented structured attributes include `gambling: boolean`, `gamblingSimulated: string`, and `lootBox: boolean`. [Attribute schema][age-schema] | This authenticated publisher API requires signed JWTs. It is distinct from the public Search `advisories` array and does not establish public access to all apps' questionnaires. [Authentication][asc-auth] [Your-app declaration resource][age-resource] |
| Enterprise Partner Feed | Apple describes partner username/password access, weekly full exports, daily incrementals, and an application schema with `recommended_age`, `seller_name`, localized descriptions, and genre relationships. [EPF][epf] | Partner feed, not anonymous public API. Its current page mixes a media overview omitting apps with application tables and other historical text. Current app-feed enrollment, actual app coverage, advisory fields, and permissions for this use are **unverified**; do not promise an available complete app dump. [EPF][epf] |

### Chart count and filtering checks

The current generator's HTML offers result limits **10, 25, 50**. Directly requesting **100** returned HTTP 200 with exactly 100 apps, so 100 is a working endpoint size beyond the displayed generator options. A request for 101 returned HTTP 500; 200 timed out after 20 seconds. These observations establish 100 as the largest successful size in this check, not a documented hard maximum. The exact supported maximum remains **unverified**. [Generator][rss-builder] [100 response][modern100] [101 request][modern101] [200 request][modern200]

Adding `?genre=6005` to the modern 100-app feed returned the same ordered IDs as the unfiltered feed. It did not filter the chart. Legacy genre filtering did work in the 10-entry check. Legacy requests with `limit=200` returned only 100 entries, both overall and for Social Networking; do not promise 200 entries merely from the URL. [Modern query][modern-filter] [Unfiltered][modern100] [Legacy 10][legacy10] [Legacy genre 200][legacy200] [Legacy overall 200][legacy-all200]

Availability is intermittent. The concurrent prototype's saved run contains 14 HTTP 200 responses, including the current chart, after an initial HTTP 504 reported separately. Preserve status/body and fetch time rather than converting failure into an empty chart. The 504 is a **reported observation**, not independently reproduced here. [Current endpoint][modern10] [Saved responses](../../prototypes/app-categories/raw-data.json)

### Official genre IDs useful to the prototype

These are observed mappings from Apple's full JSON list, not a new custom taxonomy. The linked service supplies the complete hierarchy. [Official list][genre-list]

| ID | Name | ID | Name |
| --- | --- | --- | --- |
| 36 | App Store root | 6014 | Games |
| 6005 | Social Networking | 6016 | Entertainment |
| 6008 | Photo & Video | 6024 | Shopping |
| 6012 | Lifestyle | 6015 | Finance |
| 7006 | Casino, under Games | 7015 | Simulation, under Games |

## Advisory semantics and gaps

Apple defines **Gambling** as wagering real money or currency exchangeable for real money; **Simulated Gambling** excludes both; **Loot Boxes** are purchasable virtual containers with randomized virtual items. These are separate descriptors. A loot-box advisory is not proof of real-money gambling, and Casino or Simulation genre alone is not proof of either behavior. The last two cautions are classification judgments based on Apple's definitions. [Definitions][age-definitions] [Genres][genre-list]

The official questionnaire uses frequency choices for simulated gambling and contests, and yes/no answers for gambling and loot boxes. The publisher schema provides structured values, while public Search exposes observed strings. No source checked promises that every questionnaire answer reaches `advisories`. Preserve the raw strings and their country; model a positive match separately from unknown coverage. [Questionnaire instructions and screenshot][age-setup] [Schema][age-schema] [Public example][sample-lookup]

Apple's current category guide says a Social Media descriptor appears on applicable product pages. Its November 2026 announcement adds Shared Location and Dating and Relationships declarations, with all apps due to complete those declarations by January 12, 2027. Public Search serialization and rollout completeness for these descriptors are **unverified**. Product-page or questionnaire capabilities must not be assumed to exist as Search fields. [Categories][categories] [Announcement][new-descriptors]

The prototype snapshot demonstrates both recall and precision gaps. Searches requesting 20 returned 17–20 apps. The short-video query missed TikTok although bundle Lookup found it; `gacha` returned the illustration tool ibis Paint X; the social genre chart included Life360. These are candidate queues, not validated block lists. [Short-video search][prototype-short] [TikTok Lookup][tiktok-lookup] [Gacha search][prototype-gacha] [Social chart][legacy10] [Saved responses](../../prototypes/app-categories/raw-data.json)

FanDuel's returned advisories include both `"Gambling"` and `"Frequent/Intense Simulated Gambling"`. Kalshi has Finance and Sports genres but an empty advisory array, leaving prediction-market inclusion a policy decision rather than a descriptor match. This is metadata evidence, not a legal classification or gameplay audit. [Betting search][prototype-betting] [Saved review](../../prototypes/app-categories/spot-checks.json)

Complete catalogue coverage and permission to retain/distribute metadata as a blocking taxonomy remain **unverified**. Search terms discuss promotional use. EPF restricts use to link generation and bans AI processing, so it is not an approved route around these gaps. [Search terms][search-doc] [EPF terms][epf]

## Recommendation

Use the Bun/fetch prototype to measure **candidate discovery**, with explicit storefronts, raw-response evidence, cached low-rate Search/Lookup calls, and separate chart adapters. Use current charts for broad seeds and verified legacy genre feeds for targeted seeds, then enrich by numeric app ID. Save `trackId`, `bundleId`, all genre IDs/names, both age strings, full `advisories`, description, seller, rating count, source URL, storefront, and fetch time. This recommendation follows the observed response differences and Apple's caching guidance. [Search guidance][search-doc] [Modern response][modern100] [Legacy response][legacy10] [Lookup][sample-lookup]

Keep initial custom categories reviewed and evidence-backed. For **games with loot boxes**, require Games membership `6014` **and** the positive loot-box advisory; Kwai demonstrates why the advisory alone would include non-games. Keep real-money gambling and simulated gambling separate. Use descriptions to find candidates for categories such as short video, then review inclusions and allow corrections. Treat missing advisories and missed search results as unknowns. Before distributing a production taxonomy or using metadata in model processing, establish reuse rights for the chosen source; do not assume EPF is permitted. [Kwai][sample-lookup] [Definitions][age-definitions] [Search terms][search-doc] [EPF terms][epf]

[search-doc]: https://performance-partners.apple.com/search-api
[categories]: https://developer.apple.com/app-store/categories/
[sample-search]: https://itunes.apple.com/search?term=short+video&entity=software&country=us&limit=5
[sample-lookup]: https://itunes.apple.com/lookup?bundleId=com.kwai.intl&country=us
[prototype-short]: https://itunes.apple.com/search?term=short+video&country=us&media=software&entity=software&limit=20
[tiktok-lookup]: https://itunes.apple.com/lookup?bundleId=com.zhiliaoapp.musically&country=us&entity=software
[prototype-gacha]: https://itunes.apple.com/search?term=gacha&country=us&media=software&entity=software&limit=20
[prototype-betting]: https://itunes.apple.com/search?term=sports+betting&country=us&media=software&entity=software&limit=20
[age-definitions]: https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions
[age-setup]: https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/
[age-schema]: https://developer.apple.com/documentation/appstoreconnectapi/ageratingdeclaration/attributes-data.dictionary
[age-resource]: https://developer.apple.com/documentation/appstoreconnectapi/ageratingdeclaration
[asc-auth]: https://developer.apple.com/documentation/appstoreconnectapi/generating-tokens-for-api-requests
[new-descriptors]: https://developer.apple.com/news/?id=yxkh08us
[rss-builder]: https://rss.marketingtools.apple.com/
[rss-code]: https://rss.marketingtools.apple.com/packs/js/rss-aae5eb19654ca3e4927b.js
[rss-app-feeds]: https://rss.marketingtools.apple.com/apple/apps/us/apps/feeds
[modern10]: https://rss.marketingtools.apple.com/api/v2/us/apps/top-free/10/apps.json
[modern100]: https://rss.marketingtools.apple.com/api/v2/us/apps/top-free/100/apps.json
[modern101]: https://rss.marketingtools.apple.com/api/v2/us/apps/top-free/101/apps.json
[modern200]: https://rss.marketingtools.apple.com/api/v2/us/apps/top-free/200/apps.json
[modern-filter]: https://rss.marketingtools.apple.com/api/v2/us/apps/top-free/100/apps.json?genre=6005
[legacy10]: https://itunes.apple.com/us/rss/topfreeapplications/limit=10/genre=6005/json
[legacy200]: https://itunes.apple.com/us/rss/topfreeapplications/limit=200/genre=6005/json
[legacy-all200]: https://itunes.apple.com/us/rss/topfreeapplications/limit=200/json
[genre-list]: https://itunes.apple.com/WebObjects/MZStoreServices.woa/ws/genres?id=36
[epf]: https://performance-partners.apple.com/epf
