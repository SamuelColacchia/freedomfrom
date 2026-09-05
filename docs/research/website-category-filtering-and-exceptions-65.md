# Website-category filtering and false-positive exceptions

Research for [issue #65](https://github.com/SamuelColacchia/freedomfrom/issues/65), downstream of [map #62](https://github.com/SamuelColacchia/freedomfrom/issues/62). Researched 2026-09-04. No implementation or product decision is made here.

## Findings

### 1. Apple exposes an adult-content policy, not an arbitrary taxonomy

Apple’s public `WebContentSettings` API describes filtering by specific web domains and exposes `FilterPolicy`; the documented policy surface is an Apple-managed web-content policy, not a developer-defined set of labels such as “social”, “news”, or “work”.

Sources: [WebContentSettings](https://developer.apple.com/documentation/managedsettings/webcontentsettings), [WebContentSettings.FilterPolicy](https://developer.apple.com/documentation/managedsettings/webcontentsettings/filterpolicy).

Apple’s user-facing Screen Time controls explicitly offer unrestricted access, limiting adult websites, or only approved websites. This confirms the built-in classification is adult-content filtering, while allow/deny lists are explicit domain mechanisms. Source: [Apple Support, prevent inappropriate web content](https://support.apple.com/en-us/105121).

**Limit:** the public API does not document a supported way to supply an arbitrary category taxonomy or replace Apple’s classifier. “Category” in Family Controls is a selectable Apple activity category token, not an app-authored web classifier. Source: [FamilyActivitySelection](https://developer.apple.com/documentation/familycontrols/familyactivityselection).

### 2. Viable enforcement mechanisms

- **Apple adult filter:** use Managed Settings’ web-content filter policy. This is the only first-party category-like web mechanism identified, and its taxonomy/decisions are Apple-owned.
- **Explicit domain deny list:** use `WebContentSettings` with app-maintained domains. This is deterministic and suitable for known false positives, but it is not category filtering.
- **Explicit allow list / approved websites:** model “only these sites” as a domain allow list. It is the strictest false-positive avoidance mechanism, but requires maintaining every desired domain and may not cover arbitrary navigations. Source: [Apple Support](https://support.apple.com/en-us/105121).
- **Network Extension content filter:** Apple’s WWDC21 material says an on-device web content filter built with Network Extensions can filter web traffic and is installed automatically for a parental-control app. This is the only identified path for a genuinely app-owned taxonomy/classifier, but it is a separate subsystem with its own entitlement, extension, signing, review, privacy, and behavior-validation constraints. Source: [WWDC21 Meet the Screen Time API](https://developer.apple.com/videos/play/wwdc2021/10123/).

### 3. False-positive exception mechanisms

- **Exact-domain exception:** remove a domain from the blocked set or add it to the permitted set. This is the clearest mechanism and aligns with Apple’s documented permitted/denied URL model.
- **Trusted-person approval of an active exception:** represent an exception as a separate approval action, then update the locally enforced domain policy only after that approval. The Screen Time APIs provide enforcement primitives, but do not provide a trusted-person workflow, identity protocol, or remote approval service; that workflow remains application policy and is outside this research ticket’s implementation scope.
- **Apple classifier override:** Apple documents permitted URLs that can allow a site even when considered adult, and denied URLs that block a nonadult site. This is an Apple-supported override at the explicit-URL level, not a general category exception API. Source: [Apple Support](https://support.apple.com/en-us/105121).

### 4. Entitlements and infrastructure constraints

Family Controls is required for Screen Time API parental-control features and app extensions. Apple’s configuration guidance says the capability adds `com.apple.developer.family-controls`; distribution requires requesting the entitlement for the app and each Screen Time extension. Sources: [Screen Time Technology Frameworks](https://developer.apple.com/documentation/screentimeapidocumentation), [Configuring Family Controls](https://developer.apple.com/documentation/familycontrols/configuring-family-controls).

A Network Extension content filter would require the relevant Network Extension capability/entitlement and a filter-provider extension; its exact availability and App Store distribution approval must be confirmed against the target SDK and Apple Developer account. This report does **not** assume that entitlement is granted. Gate: a human must verify the capability is available for this App ID and obtain Apple approval before choosing this path.

The repo already has an app plus Monitor and ShieldConfig extensions and Family Controls assumptions in [the build spec](https://github.com/SamuelColacchia/freedomfrom/blob/main/docs/v1-build-spec.md#L97-L112). Adding a Network Extension would change target topology and signing surface; no such change is authorized here.

## Recommendation-neutral decision inputs

The viable choices for the later human decision are: (A) Apple adult filter plus exact-domain trusted-person exceptions; (B) explicit domain lists only; or (C) a separately approved Network Extension classifier. A and B use documented Managed Settings/domain primitives. C is the only route found for arbitrary taxonomies, but it has the largest entitlement, review, extension, privacy, and validation burden.

## Limits and unknowns

1. Apple’s current public docs do not specify the adult classifier’s taxonomy, update cadence, false-positive rate, or wildcard/domain matching edge cases.
2. The docs do not establish whether every modern browser and web view is covered identically by Managed Settings’ web filter. This requires a human device probe; do not infer it from simulator results.
3. Network Extension entitlement availability and App Store approval are account- and submission-dependent; verify before treating C as viable.
4. No source found documents a built-in trusted-person approval or remote exception protocol. The chosen trusted-person approval flow therefore needs a later product/security decision, not an Apple API assumption.
5. The online re-rating/filtering service is a separate milestone and intentionally excluded from this map.
