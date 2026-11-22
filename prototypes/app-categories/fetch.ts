// THROWAWAY data exploration. No app integration or blocking behaviour.
import { render } from "./render";

export type App = {
  readonly trackId: number;
  readonly trackName: string;
  readonly bundleId: string;
  readonly primaryGenreName: string;
  readonly primaryGenreId: number;
  readonly genreIds: readonly string[];
  readonly genres: readonly string[];
  readonly contentAdvisoryRating: string;
  readonly trackContentRating: string;
  readonly advisories: readonly string[];
  readonly description: string;
  readonly sellerName: string;
  readonly userRatingCount: number | null;
  readonly trackViewUrl: string;
};
export type Request = {
  readonly key: string;
  readonly url: string;
  readonly fetchedAt: string;
  readonly status: number | null;
  readonly error: string | null;
  readonly body: unknown;
};
export type Snapshot = {
  readonly fetchedAt: string;
  readonly country: string;
  readonly delayMs: number;
  readonly requests: readonly Request[];
};
export type Category = {
  readonly id: string;
  readonly name: string;
  readonly keyword: string;
  readonly genreHints: string;
  readonly ratingHints: string;
  readonly caveat: string;
};
export const categories = [
  { id: "short-video", name: "Short video", keyword: "short video", genreHints: "6005 Social Networking; 6016 Entertainment; 6008 Photo & Video",
    ratingHints: "No short-video descriptor. Age ratings cannot identify scrolling feeds.",
    caveat: "Search mixes social clips, scripted microdramas and editing tools. Decide whether microdramas belong before approving a list." },
  { id: "dating", name: "Dating", keyword: "dating", genreHints: "6012 Lifestyle; 6005 Social Networking",
    ratingHints: "Mature/suggestive themes can corroborate a review but do not prove dating.",
    caveat: "Dating keywords also retrieve chat, friendship and relationship advice. Check the actual service, not just its name." },
  { id: "betting", name: "Gambling and betting", keyword: "sports betting", genreHints: "6004 Sports; 6014 Games; 7006 Casino",
    ratingHints: "Look for Gambling or Simulated Gambling in advisories. They mean different things; an age scalar does not distinguish them.",
    caveat: "Sportsbook search also retrieves odds, picks and tracking tools. A gambling advisory is useful evidence, not a complete inventory." },
  { id: "social", name: "Social feeds", keyword: "social network", genreHints: "6005 Social Networking; legacy chart supplies extra seeds",
    ratingHints: "No feed/addictive-use descriptor. Unrestricted Web Access is much broader.",
    caveat: "Social Networking includes private messaging and community utilities. Genre membership alone does not prove an endless feed." },
  { id: "news", name: "News", keyword: "news", genreHints: "6009 News; 6021 Magazines & Newspapers",
    ratingHints: "No doomscrolling descriptor. Violence advisories may reflect reporting rather than a risky product mechanic.",
    caveat: "Publishers and aggregators fit a broad news block; utilities and newsletters may not fit a narrower news-feed policy." },
  { id: "shopping", name: "Shopping", keyword: "shopping", genreHints: "6024 Shopping; some marketplaces use 6012 Lifestyle",
    ratingHints: "No compulsive-shopping descriptor. Price and rating count are not risk scores.",
    caveat: "Search can include grocery, resale and list-making tools. Decide whether essential purchases and shopping utilities belong." },
  { id: "loot-boxes", name: "Mobile games with loot boxes", keyword: "gacha", genreHints: "6014 Games; chart seeds plus all observed game advisories",
    ratingHints: "The observed advisories array can explicitly contain Loot Boxes. A missing descriptor is not proof of absence.",
    caveat: "Gacha is a weak proxy: search can find art tools and companion apps. Even an explicit descriptor needs current gameplay review." },
  { id: "casino", name: "Simulated casino games", keyword: "casino slots", genreHints: "6014 Games; 7006 Casino",
    ratingHints: "Simulated Gambling helps separate casino simulation from real-money betting, where it is actually returned.",
    caveat: "Cash-prize, sweepstakes and simulated casinos can share search terms. Do not silently combine their legal or product meanings." },
] as const satisfies readonly Category[];

function record(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
function strings(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((v): v is string => typeof v === "string") : [];
}
function text(value: unknown): string {
  return typeof value === "string" ? value : "";
}
export function apps(request: Request): App[] {
  if (!record(request.body) || !Array.isArray(request.body.results)) return [];
  return request.body.results.flatMap((item: unknown) => {
    if (!record(item) || typeof item.trackId !== "number" || typeof item.bundleId !== "string" || typeof item.trackName !== "string") return [];
    return [{
      trackId: item.trackId, trackName: item.trackName, bundleId: item.bundleId,
      primaryGenreName: text(item.primaryGenreName), primaryGenreId: typeof item.primaryGenreId === "number" ? item.primaryGenreId : 0,
      genreIds: strings(item.genreIds), genres: strings(item.genres),
      contentAdvisoryRating: text(item.contentAdvisoryRating), trackContentRating: text(item.trackContentRating),
      advisories: strings(item.advisories), description: text(item.description), sellerName: text(item.sellerName),
      userRatingCount: typeof item.userRatingCount === "number" ? item.userRatingCount : null,
      trackViewUrl: text(item.trackViewUrl),
    }];
  });
}
export function candidates(category: Category, snapshot: Snapshot): App[] {
  const found = new Map<string, App>();
  for (const request of snapshot.requests) {
    for (const app of apps(request)) {
      const queryHit = request.key === category.id;
      const socialSeed = category.id === "social" && request.key === "chart-enrichment" && app.genreIds.includes("6005");
      const lootHint = category.id === "loot-boxes" && app.genreIds.includes("6014") && app.advisories.some(a => /loot box/i.test(a));
      if (queryHit || socialSeed || lootHint) found.set(app.bundleId, app);
    }
  }
  return [...found.values()].sort((a, b) => (b.userRatingCount ?? -1) - (a.userRatingCount ?? -1));
}
export function sources(app: App, snapshot: Snapshot): Request[] {
  return snapshot.requests.filter(r => apps(r).some(a => a.bundleId === app.bundleId));
}

const folder = import.meta.dir;
const rawPath = `${folder}/raw-data.json`;
const requests: Request[] = [];
const delayMs = 3500; // Below Apple's documented approximate 20 calls/minute.
async function pull(key: string, url: string): Promise<Request> {
  if (requests.length) await Bun.sleep(delayMs);
  const fetchedAt = new Date().toISOString();
  let result: Request;
  try {
    const response = await fetch(url, { signal: AbortSignal.timeout(30000) });
    const body = await response.text();
    let parsed: unknown = body;
    try { parsed = JSON.parse(body); } catch (error) {
      if (!(error instanceof SyntaxError)) throw error;
    }
    result = { key, url, fetchedAt, status: response.status, error: response.ok ? null : `HTTP ${response.status}`, body: parsed };
  } catch (error) {
    if (!(error instanceof Error)) throw error;
    result = { key, url, fetchedAt, status: null, error: `${error.name}: ${error.message}`, body: null };
  }
  requests.push(result);
  console.log(`FETCH ${key} ${result.status ?? result.error}`);
  await Bun.write(rawPath, JSON.stringify({ fetchedAt, country: "us", delayMs, requests }, null, 2));
  return result;
}

if (import.meta.main) {
  let snapshot: Snapshot;
  if (Bun.argv.includes("--offline")) {
    snapshot = await Bun.file(rawPath).json();
  } else {
    await pull("current-chart", "https://rss.marketingtools.apple.com/api/v2/us/apps/top-free/10/apps.json");
    await pull("social-chart", "https://itunes.apple.com/us/rss/topfreeapplications/limit=10/genre=6005/json");
    await pull("games-chart", "https://itunes.apple.com/us/rss/topfreeapplications/limit=10/genre=6014/json");
    await pull("genre-taxonomy", "https://itunes.apple.com/WebObjects/MZStoreServices.woa/ws/genres?id=36");
    for (const category of categories) {
      const query = new URLSearchParams({ term: category.keyword, country: "us", media: "software", entity: "software", limit: "20" });
      await pull(category.id, `https://itunes.apple.com/search?${query}`);
    }
    await pull("bundle-lookup", "https://itunes.apple.com/lookup?bundleId=com.zhiliaoapp.musically&country=us&entity=software");
    const ids: string[] = [];
    for (const request of requests.filter(r => r.key.endsWith("-chart"))) {
      if (!record(request.body) || !record(request.body.feed)) continue;
      const entries = request.body.feed.entry;
      if (!Array.isArray(entries)) continue;
      for (const entry of entries) {
        if (record(entry) && record(entry.id) && record(entry.id.attributes)) {
          const id = entry.id.attributes["im:id"];
          if (typeof id === "string") ids.push(id);
        }
      }
    }
    if (ids.length) await pull("chart-enrichment", `https://itunes.apple.com/lookup?id=${[...new Set(ids)].join(",")}&country=us&entity=software`);
    snapshot = { fetchedAt: new Date().toISOString(), country: "us", delayMs, requests };
    await Bun.write(rawPath, JSON.stringify(snapshot, null, 2));
  }
  const reviewPath = `${folder}/spot-checks.json`;
  const review: { readonly snapshotFetchedAt: string; readonly notes: Record<string, string> } | null =
    await Bun.file(reviewPath).exists() ? await Bun.file(reviewPath).json() : null;
  const reviews = review?.snapshotFetchedAt === snapshot.fetchedAt ? review.notes : {};
  await Bun.write(`${folder}/index.html`, render(snapshot, reviews));
  console.log(`DONE ${snapshot.requests.length} requests; ${new Set(snapshot.requests.flatMap(apps).map(a => a.bundleId)).size} unique enriched apps`);
  for (const category of categories) console.log(`${category.name}: ${candidates(category, snapshot).length} candidates`);
}
