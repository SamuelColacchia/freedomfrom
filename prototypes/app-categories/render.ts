// THROWAWAY HTML report. All data is embedded; opening the file sends no requests.
import { apps, candidates, categories, sources } from "./fetch";
import type { Snapshot } from "./fetch";

const escape = (value: unknown): string => String(value ?? "").replace(/[&<>"']/g, c => `&#${c.charCodeAt(0)};`);
export function render(snapshot: Snapshot, reviews: Readonly<Record<string, string>>): string {
  const unique = new Set(snapshot.requests.flatMap(apps).map(a => a.bundleId)).size;
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light dark"><title>App category data explorer</title>
<style>
:root{color-scheme:light dark;--bg:#fafafa;--panel:#fff;--ink:#171719;--muted:#505057;--line:#76767f;--link:#164f9b;--wash:#ececf0;--focus:#164f9b}
@media(prefers-color-scheme:dark){:root{--bg:#101012;--panel:#19191d;--ink:#ededf0;--muted:#b7b7c0;--line:#85858e;--link:#9ec6ff;--wash:#28282e;--focus:#9ec6ff}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:17px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
main{max-width:1120px;margin:auto;padding:40px 28px 80px}h1{font-size:34px;line-height:1.2;margin:0 0 24px}h2{font-size:27px;line-height:1.25;margin:36px 0 16px}h3{font-size:22px;margin:32px 0 12px}
p{max-width:76ch;margin:12px 0}a{color:var(--link);text-underline-offset:3px;overflow-wrap:anywhere}a:hover{text-decoration-thickness:2px}
small,.muted{color:var(--muted);font-size:15px}code{font:inherit;overflow-wrap:anywhere}select{display:block;width:100%;max-width:500px;min-height:48px;padding:10px;background:var(--panel);color:var(--ink);border:1px solid var(--line);border-radius:4px;font:inherit;margin:8px 0 28px}
label{font-weight:600}select:hover,summary:hover{background:var(--wash)}:focus-visible{outline:3px solid var(--focus);outline-offset:4px}
::selection{background:var(--ink);color:var(--bg)}html{scrollbar-color:var(--line) var(--bg);caret-color:var(--ink)}
.facts{display:grid;grid-template-columns:140px 1fr;gap:8px 18px;margin:20px 0 28px}.facts dt{color:var(--muted)}.facts dd{margin:0;overflow-wrap:anywhere}
.notice{padding:16px 20px;background:var(--wash);margin:24px 0}.notice p{margin:0}
table{border-collapse:collapse;width:100%;font-size:15px;table-layout:fixed}th,td{text-align:left;vertical-align:top;padding:16px 12px;border-bottom:1px solid var(--line);overflow-wrap:anywhere}
th{font-weight:600}th:first-child{width:56%}th:nth-child(2){width:27%}th:last-child{width:17%;text-align:right}td:last-child{text-align:right;font-variant-numeric:tabular-nums}
td strong{font-size:17px}td p{margin:8px 0}summary{cursor:pointer;min-height:44px;padding:8px 0;color:var(--link)}details p{white-space:pre-line}details .source{display:block;padding:6px 0}
.status{font-weight:600}.requests{list-style:none;padding:0}.requests li{padding:12px 0;border-bottom:1px solid var(--line)}
[hidden]{display:none!important}
@media(max-width:600px){main{padding:28px 18px 56px}h1{font-size:30px}h2{font-size:25px}.facts{grid-template-columns:1fr;gap:4px}.facts dd{margin-bottom:12px}table,tbody,tr,td{display:block}thead{display:none}tr{padding:12px 0;border-bottom:1px solid var(--line)}td{border:0;padding:6px 0;font-size:17px}td:last-child{text-align:left}td[data-label]::before{content:attr(data-label) ": ";color:var(--muted)}}
@media print{section[hidden]{display:block!important}select,label{display:none}main{max-width:none}}
</style></head><body><main>
<h1>App category data explorer</h1>
<p>What public App Store data can help build our own blocking categories? This throwaway prototype proposes candidate lists from US keyword searches and chart seeds. These are review queues, not approved block lists.</p>
<p class="muted">${unique} unique apps with bundle IDs across ${snapshot.requests.length} requests. Snapshot: ${escape(new Date(snapshot.fetchedAt).toLocaleString("en-US", {timeZone:"UTC"}))} UTC. No external assets or live requests on this page.</p>
<div class="notice"><p><strong>Useful surprise:</strong> returned <code>advisories</code> can contain <code>Loot Boxes</code> and gambling descriptors. Their absence is not an assurance. Search results, age ratings and genres still cannot define our categories by themselves.</p></div>
<label for="category">Explore a proposed category</label>
<select id="category">${categories.map(c => `<option value="${c.id}">${escape(c.name)} (${candidates(c, snapshot).length})</option>`).join("")}</select>
${categories.map((c, i) => {
    const list = candidates(c, snapshot);
    return `<section id="${c.id}"${i ? " hidden" : ""} aria-labelledby="heading-${c.id}">
<h2 id="heading-${c.id}">${escape(c.name)}</h2>
<dl class="facts"><dt>Candidate count</dt><dd>${list.length}, sorted by all-version rating count</dd>
<dt>Discovery query</dt><dd><code>${escape(c.keyword)}</code>, up to 20 software results requested; no genre restriction</dd>
<dt>Genre hints</dt><dd>${escape(c.genreHints)}. Hints are review evidence, not hard filters.</dd>
<dt>Rating hints</dt><dd>${escape(c.ratingHints)}</dd>
<dt>Inclusion rule</dt><dd>All results of this category's keyword search.${c.id === "social" ? " Also enriched Social Networking chart seeds." : ""}${c.id === "loot-boxes" ? " Also any fetched Games app explicitly marked Loot Boxes." : ""} De-duplicate by bundle ID.</dd>
<dt>Precision caveat</dt><dd>${escape(c.caveat)}</dd></dl>
<p><strong>Manual spot-check:</strong> ${escape(reviews[c.id] ?? "Not yet reviewed for this snapshot. Do not treat the candidates as confirmed members.")}</p>
${list.length ? `<table><thead><tr><th scope="col">App and evidence</th><th scope="col">Primary genre / age</th><th scope="col">Rating count</th></tr></thead><tbody>${list.map(a => `<tr>
<td><strong><a href="${escape(a.trackViewUrl)}">${escape(a.trackName)}</a></strong><br><code>${escape(a.bundleId)}</code>
<details><summary>Inspect metadata and provenance</summary>
<p><strong>Seller:</strong> ${escape(a.sellerName || "Not returned")}<br>
<strong>Genre IDs:</strong> ${escape(a.genreIds.join(", "))}<br><strong>Genres:</strong> ${escape(a.genres.join(", "))}<br>
<strong>trackContentRating:</strong> ${escape(a.trackContentRating || "Not returned")}<br><strong>contentAdvisoryRating:</strong> ${escape(a.contentAdvisoryRating || "Not returned")}<br>
<strong>Advisories:</strong> ${escape(a.advisories.join("; ") || "None returned; not proof of absence")}</p>
<p>${escape(a.description || "Description not returned.")}</p>
${sources(a, snapshot).map(r => `<a class="source" href="${escape(r.url)}">Source: ${escape(r.key)}</a>`).join("")}</details></td>
<td data-label="Genre / age">${escape(a.primaryGenreName)} (${a.primaryGenreId})<br>${escape(a.contentAdvisoryRating || a.trackContentRating || "Age not returned")}</td>
<td data-label="Rating count">${a.userRatingCount === null ? "Not returned" : a.userRatingCount.toLocaleString("en-US")}</td></tr>`).join("")}</tbody></table>` : "<p>No candidates were returned. Inspect endpoint status below before drawing conclusions.</p>"}</section>`;
  }).join("")}
<h2>What this snapshot cannot prove</h2>
<p>There is no public catalogue crawl here, no completeness estimate, no installed-app visibility and no proof of bundle-ID blocking. Country availability, seller metadata and ratings can change. Rating count measures submitted ratings, not downloads or risk. Spot-checks read listing metadata only; no app was installed or played.</p>
<h2>Endpoint receipts</h2>
<p>Requests ran sequentially with at least ${snapshot.delayMs / 1000} seconds between them. HTTP or network failures are retained, without automatic retries. Raw response bodies and URLs are in <code>raw-data.json</code>.</p>
<ul class="requests">${snapshot.requests.map(r => `<li><span class="status">${escape(r.key)}: ${escape(r.error ?? `HTTP ${r.status}`)}</span><br><a href="${escape(r.url)}">${escape(r.url)}</a></li>`).join("")}</ul>
</main><script>
const picker=document.getElementById("category");
const showCategory=()=>{document.querySelectorAll("main>section").forEach(section=>{section.hidden=section.id!==picker.value});};
picker.addEventListener("change",showCategory);
window.addEventListener("pageshow",showCategory);
</script></body></html>`;
}
