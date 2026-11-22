// Builds the URL filter's two inputs from one list of entries, one per line:
// the extension's bloom_filter.plist and the PIR server's data/input.txtpb.
// It is SwiftBloomFilter and BloomFilterTool in Bun, so the lists can change
// without building a macOS tool. `--check` proves the port byte-identical
// against the plist Apple's sample shipped before writing anything.
//
//   bun probes/url-filter/make-lists.ts LIST [--seed N]
//   bun probes/url-filter/make-lists.ts --check

import { dirname, join } from "node:path";

const here = dirname(new URL(import.meta.url).pathname);
const plistPath = join(here, "SimpleURLFilter/SimpleURLFilterExtension/bloom_filter.plist");
const pirPath = join(here, "PIR Server/data/input.txtpb");
const fpTolerance = 0.001;

function fnv1a(bytes: Uint8Array): number {
  let h = 0x811c9dc5;
  for (const b of bytes) h = Math.imul(h ^ b, 0x01000193) >>> 0;
  return h;
}

function murmur3(bytes: Uint8Array, seed: number): number {
  const rotl = (x: number, r: number) => ((x << r) | (x >>> (32 - r))) >>> 0;
  const c1 = 0xcc9e2d51, c2 = 0x1b873593;
  let h = seed >>> 0;
  const n = bytes.length, blocks = n >>> 2;
  for (let i = 0; i < blocks; i++) {
    const o = i * 4;
    let k = (bytes[o] | (bytes[o + 1] << 8) | (bytes[o + 2] << 16) | (bytes[o + 3] << 24)) >>> 0;
    k = Math.imul(rotl(Math.imul(k, c1) >>> 0, 15), c2) >>> 0;
    h = rotl((h ^ k) >>> 0, 13);
    h = (Math.imul(h, 5) + 0xe6546b64) >>> 0;
  }
  const t = blocks * 4;
  let k = 0;
  switch (n & 3) {
    case 3: k ^= bytes[t + 2] << 16; // falls through
    case 2: k ^= bytes[t + 1] << 8; // falls through
    case 1:
      k ^= bytes[t];
      k = Math.imul(rotl(Math.imul(k, c1) >>> 0, 15), c2) >>> 0;
      h = (h ^ k) >>> 0;
  }
  h = (h ^ n) >>> 0;
  h ^= h >>> 16; h = Math.imul(h, 0x85ebca6b) >>> 0;
  h ^= h >>> 13; h = Math.imul(h, 0xc2b2ae35) >>> 0;
  h ^= h >>> 16;
  return h >>> 0;
}

function bloom(items: string[], seed: number) {
  const n = items.length;
  const bitCount = Math.ceil(-(n * Math.log(fpTolerance)) / Math.LN2 ** 2);
  const hashCount = Math.ceil((bitCount / n) * Math.LN2);
  const bits = new Uint8Array(Math.ceil(bitCount / 8));
  const enc = new TextEncoder();
  for (const item of items) {
    const b = enc.encode(item);
    const f = fnv1a(b), m = murmur3(b, seed);
    for (let i = 0; i < hashCount; i++) {
      // Swift: (fnv &+ count &* murmur) % bitCount, all UInt32.
      const idx = ((f + Math.imul(i, m)) >>> 0) % bitCount;
      bits[idx >>> 3] |= 1 << (idx & 7);
    }
  }
  return { n, seed, bitCount, hashCount, bits };
}

function plist(f: ReturnType<typeof bloom>): string {
  const b64 = Buffer.from(f.bits).toString("base64").replace(/.{1,68}/g, "\t$&\n");
  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>bitCount</key>
\t<integer>${f.bitCount}</integer>
\t<key>byteCount</key>
\t<integer>${f.bits.length}</integer>
\t<key>data</key>
\t<data>
${b64}\t</data>
\t<key>falsePositiveTolerance</key>
\t<real>${fpTolerance}</real>
\t<key>hashCount</key>
\t<integer>${f.hashCount}</integer>
\t<key>itemCount</key>
\t<integer>${f.n}</integer>
\t<key>murmurSeed</key>
\t<integer>${f.seed}</integer>
</dict>
</plist>
`;
}

const pir = (items: string[]) =>
  items.map((k) => `rows {\n  keyword: ${JSON.stringify(k)}\n  value: "1"\n}\n`).join("");

const args = Bun.argv.slice(2);
if (args[0] === "--check") {
  const sample = ["example.com", "example2.com", "example3.com", "example4.com", "example5.com",
    "example6.com", "example7.com", "example8.com", "example9.com", "example10.com/resource?query=bugs"];
  const got = Buffer.from(bloom(sample, 624656550).bits).toString("base64");
  const want = "drTfH9rdTUxh8MMyOMHdj00m";
  console.log(got === want ? `ok: ${got}` : `MISMATCH: got ${got}, want ${want}`);
  process.exit(got === want ? 0 : 1);
}

const listPath = args[0];
if (!listPath) throw new Error("usage: make-lists.ts LIST [--seed N] | --check");
const seedArg = args.indexOf("--seed");
const seed = seedArg >= 0 ? Number(args[seedArg + 1]) >>> 0 : crypto.getRandomValues(new Uint32Array(1))[0];
const items = [...new Set((await Bun.file(listPath).text()).split("\n").map((l) => l.trim()).filter(Boolean))];
const f = bloom(items, seed);
await Bun.write(plistPath, plist(f));
await Bun.write(pirPath, pir(items));
console.log(`${items.length} entries, seed ${seed}, ${f.bitCount} bits, ${f.hashCount} hashes`);
