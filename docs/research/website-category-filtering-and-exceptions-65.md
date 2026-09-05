# Website-category filtering and false-positive exceptions

Research for [issue #65](https://github.com/SamuelColacchia/freedomfrom/issues/65), updated 2026-09-05. No implementation or product decision is made here.

## Apple’s four distinct mechanisms

### 1. Apple adult-content auto filter

`ManagedSettings.WebContentSettings` exposes `blockedByFilter`; its `FilterPolicy.auto(_:except:)` is exact Swift API: `auto(Set<WebDomain> = [], except: Set<WebDomain> = [])`. Apple says it blocks adult content, additionally blocks the supplied `domains`, and allows the supplied `except` domains, overriding both the adult filter and `domains`; each set is capped at 50 domains.

Sources: [WebContentSettings](https://developer.apple.com/documentation/managedsettings/webcontentsettings.md), [FilterPolicy](https://developer.apple.com/documentation/managedsettings/webcontentsettings/filterpolicy.md), [auto(_:except:)](https://developer.apple.com/documentation/managedsettings/webcontentsettings/filterpolicy/auto(_:except:).md).

### 2. Bounded arbitrary taxonomy as explicit domain sets

An externally curated category such as “social” or “news” can be mapped to a bounded `Set<WebDomain>` and enforced with `specific(Set<WebDomain>)`, whose documented cap is 50 domains. Or it can be combined with `auto(domains:except:)` to add up to 50 category domains while retaining Apple’s adult filter and up to 50 exceptions. This is a bounded list, not a dynamic classifier: coverage depends on the list, domain matching, and update policy chosen later.

Source: [specific(_:)](https://developer.apple.com/documentation/managedsettings/webcontentsettings/filterpolicy/specific(_:).md).

`all(except:)` blocks all websites except up to 50 exception domains. It is an allowlist, not a category taxonomy. Source: [all(except:)](https://developer.apple.com/documentation/managedsettings/webcontentsettings/filterpolicy/all(except:).md).

### 3. Opaque Apple category tokens are shields, not current filtering

`ShieldSettings.webDomainCategories` accepts `ActivityCategoryPolicy<WebDomain>?`; Apple documents up to 50 category tokens and up to 50 web-domain-token exceptions. When a matching website is visited, the system calls the shield customization extension. This produces a shield UI, not the `webContent.blockedByFilter` policy used for current web filtering.

Sources: [ShieldSettings](https://developer.apple.com/documentation/managedsettings/shieldsettings.md), [webDomainCategories](https://developer.apple.com/documentation/managedsettings/shieldsettings/webdomaincategories-swift.property.md).

### 4. Custom Network Extension classifier

Apple’s WWDC21 Screen Time session identifies an on-device Network Extensions web content filter as a route to filter web traffic. This is the custom-classifier route, but it adds a separate filter-provider extension, Network Extension entitlement/distribution approval, privacy review, and device validation. No entitlement grant is assumed here. Source: [Meet the Screen Time API](https://developer.apple.com/videos/play/wwdc2021/10123/).

## Stores and exceptions

Named `ManagedSettingsStore`s are available from iOS 16; each store contains settings applied by the client app. Apple’s WWDC22 session states that the most restrictive setting wins across stores: clearing a Social store does not undo a Gaming store’s restriction. Therefore an exception in one store cannot override another store’s more restrictive explicit domain policy or category shield. Any trusted-person exception flow must coordinate every store that contributes the restriction, or it will appear approved while coverage remains. Sources: [ManagedSettingsStore](https://developer.apple.com/documentation/managedsettings/managedsettingsstore.md), [WWDC22](https://developer.apple.com/videos/play/wwdc2022/110336/).

## Viable mechanisms for later human choice

- Apple adult auto filter plus explicit exceptions: strongest first-party category-like baseline; taxonomy is Apple-owned; 50 blocked domains and 50 exceptions per `auto` value.
- Curated category-to-domain sets: arbitrary labels are possible as bounded domain lists; `specific` supports 50 domains, or `auto` can carry 50 additions and 50 exceptions. This does not classify unseen domains.
- Opaque Apple category web shields: up to 50 category tokens and 50 domain-token exceptions; shield behavior, not a silent/current filter.
- `all(except:)`: up to 50 allowed domains; strict allowlist.
- Network Extension classifier: dynamic/on-device custom taxonomy route, gated on entitlement, review, extension topology, privacy, and hardware validation.

Trusted-person approval of an active exception is not an Apple-provided workflow. It remains application policy, and the approval must ensure no other Managed Settings store still imposes the block. The online re-rating/filtering service remains a separate milestone and is excluded.

## Limits and unknowns

1. Apple does not document the adult classifier taxonomy, update cadence, false-positive rate, or all domain-matching edge cases.
2. The 50-item caps above are per documented policy/property assignment; this report does not infer a larger effective aggregate cap across stores.
3. Browser/web-view coverage and behavior require human device probes; simulator success is not evidence.
4. Network Extension capability availability and App Store approval are account/submission gates.
5. Sources are Apple documentation and Apple WWDC material; licensing, privacy, offline updates, and source-list provenance are later decision inputs, not settled here.
