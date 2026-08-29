# Web-domain shielding on iOS 26.5

**Scope.** This resolves issue #15 against the iOS 26.5 SDK shipped with Xcode 26.6 on the configured Mac (`iPhoneOS26.5.sdk`). The interface files were present, including under `.swiftmodule`; no fallback to headers or API notes was needed. Claims below are labelled `DOCUMENTED`, `FORUM-REPORTED`, or `UNVERIFIED`, with confidence and a source for each substantive claim.

## Decision

- **DOCUMENTED | high.** **`WebDomain(domain:)` is publicly constructible, but it is not the element type accepted by `ShieldSettings.webDomains`.** Typed domains therefore cannot produce a shield overlay through that property. However, `ManagedSettingsStore.webContent.blockedByFilter` accepts `WebContentSettings.FilterPolicy`, whose `.specific(Set<WebDomain>)` case is the typed-domain filtering path. That is the primary v1 design candidate, subject to Apple’s 50-domain limit and unresolved browser/runtime behavior. If v1 specifically requires shield-overlay semantics, the conditional alternative is picker-selected `WebDomainToken`s. [Apple: WebDomain](https://developer.apple.com/documentation/managedsettings/webdomain), [Apple: ShieldSettings.webDomains](https://developer.apple.com/documentation/managedsettings/shieldsettings/webdomains-swift.property)

## 1. Exact SDK surface

The following is quoted verbatim from the actual Xcode 26.6 / iOS 26.5 interfaces on the Mac. The interface files were present under `.swiftmodule`; no header or API-notes fallback was needed:

```swift
// ManagedSettings.swiftinterface
public struct ShieldSettings : ManagedSettings.ManagedSettingsGroup {
  public var webDomains: Swift.Set<ManagedSettings.WebDomainToken>? {
    get
    set
  }
  public static let webDomains: ManagedSettings.SettingMetadata<Swift.Set<ManagedSettings.WebDomainToken>>
}

public struct Token<T> : Swift.Codable, Swift.Equatable, Swift.Hashable {
  public init(from decoder: any Swift.Decoder) throws
}

public typealias WebDomainToken = ManagedSettings.Token<ManagedSettings.WebDomain>

public struct WebDomain : Swift.Equatable, Swift.Hashable {
  public let domain: Swift.String?
  public let token: ManagedSettings.WebDomainToken?
  public init(domain: Swift.String)
  public init(token: ManagedSettings.WebDomainToken)
}

public struct WebContentSettings : ManagedSettings.ManagedSettingsGroup {
  public enum FilterPolicy : Swift.Equatable {
    case none
    case specific(_: Swift.Set<ManagedSettings.WebDomain>)
    case auto(_: Swift.Set<ManagedSettings.WebDomain> = [], except: Swift.Set<ManagedSettings.WebDomain> = [])
    case all(except: Swift.Set<ManagedSettings.WebDomain> = [])
  }
}
```

```swift
// FamilyControls.swiftinterface
public struct FamilyActivitySelection : Swift.Codable, Swift.Equatable {
  public var applicationTokens: Swift.Set<ManagedSettings.ApplicationToken>
  public var categoryTokens: Swift.Set<ManagedSettings.ActivityCategoryToken>
  public var webDomainTokens: Swift.Set<ManagedSettings.WebDomainToken>
  public var applications: Swift.Set<ManagedSettings.Application>
  public var categories: Swift.Set<ManagedSettings.ActivityCategory>
  public var webDomains: Swift.Set<ManagedSettings.WebDomain>
}
```

```swift
// ManagedSettings.swiftinterface
public var blockedByFilter: ManagedSettings.WebContentSettings.FilterPolicy? {
  get
  set
}
public static let blockedByFilter: ManagedSettings.SettingMetadata<ManagedSettings.WebContentSettings.FilterPolicy>
```

- **DOCUMENTED | high.** `WebDomain(domain: "example.com")` is publicly constructible. The SDK declaration is `public init(domain: Swift.String)`. [Apple: WebDomain](https://developer.apple.com/documentation/managedsettings/webdomain)
- **DOCUMENTED | high.** `ShieldSettings.webDomains` is `Set<WebDomainToken>?`, not `Set<WebDomain>`. [Apple: ShieldSettings.webDomains](https://developer.apple.com/documentation/managedsettings/shieldsettings/webdomains-swift.property)
- **DOCUMENTED | high.** `FamilyActivitySelection.webDomainTokens` is `Set<WebDomainToken>`, while its read-only convenience projection `webDomains` is `Set<WebDomain>`. [Apple: FamilyActivitySelection](https://developer.apple.com/documentation/familycontrols/familyactivityselection)
- **DOCUMENTED | high.** `WebContentSettings.FilterPolicy.specific`, `.auto`, and `.all` use `Set<WebDomain>`, so they are the API surface that accepts `WebDomain(domain:)`. [Apple: FilterPolicy](https://developer.apple.com/documentation/managedsettings/webcontentsettings/filterpolicy)

- **DOCUMENTED | high.** `store.shield.webDomains = [WebDomain(domain: "example.com")]` does not type-check. Constructing a `WebDomain` does not manufacture its required `WebDomainToken`; the token initializer requires an existing token. [Apple: ShieldSettings.webDomains](https://developer.apple.com/documentation/managedsettings/shieldsettings/webdomains-swift.property), [Apple: WebDomain](https://developer.apple.com/documentation/managedsettings/webdomain)

## 2. What the filter policy expresses

- **DOCUMENTED | high.** `.specific(Set<WebDomain>)` is the named-domain policy. It is the direct representation of a finite named-domain blocklist. [Apple: `specific`](https://developer.apple.com/documentation/managedsettings/webcontentsettings/filterpolicy/specific(_:))
- **DOCUMENTED | high.** `.all(except:)` blocks all websites except the named exceptions. It is allowlist-shaped, not a named-domain blocklist. [Apple: `all(except:)`](https://developer.apple.com/documentation/managedsettings/webcontentsettings/filterpolicy/all%28except%3A%29)
- **DOCUMENTED | high.** `.auto(_:except:)` has a first named-domain set and an exception set, while also applying Apple’s adult-content filter. Its shape is `auto(domains, except: exceptions)`. Category behavior is out of scope here. [Apple: `auto(_:except:)`](https://developer.apple.com/documentation/managedsettings/webcontentsettings/filterpolicy/auto%28_%3Aexcept%3A%29)
- **DOCUMENTED | high.** `blockedByFilter` configures which websites the user can access, and Apple documents a limit of 50 blocked domains plus 50 exceptions at once. Any policy other than `.none` disables Safari Private Browsing. [Apple: `blockedByFilter`](https://developer.apple.com/documentation/managedsettings/webcontentsettings/blockedbyfilter-swift.property)

- **DOCUMENTED | high.** Thus the answer to “blocklist or only allowlist?” is: **a named-domain blocklist exists as `.specific`; `.all(except:)` is allowlist-shaped; `.auto` is a category-plus-domain policy and is not a v1 choice.**

## 3. Does selection require prior activity?

- **DOCUMENTED | high.** Apple says the picker displays applications and websites from the same device for `.individual` authorization, and from authorized child devices when shown on a parent device. It does not say that a website must first appear in Screen Time history. [Apple: `FamilyActivityPicker`](https://developer.apple.com/documentation/familycontrols/familyactivitypicker)
- **DOCUMENTED | high.** Apple describes `FamilyActivitySelection` as values selected by the user and says the picker uses opaque values to represent those selections. [Apple: `FamilyActivitySelection`](https://developer.apple.com/documentation/familycontrols/familyactivityselection)
- **UNVERIFIED | low.** Whether the picker can select an entirely cold, never-visited site is not settled by the public documentation or the inspected interface. Do not make cold-site selection a design dependency. The strongest practical evidence is contrary: an Apple Developer Forums report says individual app entries only appeared after they were used, and another report says typed domain strings could not be turned into shielding tokens. [Forum report on picker inventory](https://developer.apple.com/forums/thread/709851), [Forum report on typed domains](https://developer.apple.com/forums/thread/735923)

- **UNVERIFIED | low.** The safe conclusion is not “history is definitely required,” but **Apple has not documented cold-site availability, and picker tokens remain opaque even if a site can be selected.** [Apple: FamilyActivityPicker](https://developer.apple.com/documentation/familycontrols/familyactivitypicker)

## 4. Browser and WebView scope

- **DOCUMENTED | high.** Apple describes `ShieldSettings.webDomains` as websites the system covers with a shielding view and describes Managed Settings as filtering web traffic, but it does not enumerate Safari, Chrome, Firefox, Brave, or embedded WebViews. [Apple: `ShieldSettings.webDomains`](https://developer.apple.com/documentation/managedsettings/shieldsettings/webdomains-swift.property), [Apple: Screen Time Technology Frameworks](https://developer.apple.com/documentation/screentimeapidocumentation)
- **UNVERIFIED | low.** The public Managed Settings documentation is silent on a browser-by-browser compatibility contract for web-domain shields. There is no Apple statement found here that promises identical coverage in Safari, Chrome, Firefox, Brave, and every in-app `WKWebView`.
- **DOCUMENTED | high, separate API.** Apple’s iOS 26 Network Extension URL Filter is explicitly system-wide for HTTP/HTTPS requests made through Apple networking APIs, including WebKit and URLSession. Apps using other networking APIs must participate explicitly. This is a different API and entitlement, not evidence that Managed Settings shielding has the same scope. [Apple: WWDC25 “Filter and tunnel network traffic with NetworkExtension”](https://developer.apple.com/videos/play/wwdc2025/234/)
- **FORUM-REPORTED | medium.** A Developer Forums discussion reports that third-party browser traffic did not arrive as browser flows in a Network Extension content-filter experiment, and specifically discusses Chrome and Firefox. That is about Network Extension content filtering, not Managed Settings, so it cannot prove Managed Settings behavior. [Apple Developer Forums](https://developer.apple.com/forums/thread/735664)

- **UNVERIFIED | low.** **Per browser:** Safari, Chrome, Firefox, Brave, and in-app `WKWebView` are all **UNVERIFIED** for this Managed Settings feature. The product must not claim “all browsers” without hardware tests on each app and representative WebViews. The only documented broad system-wide statement located is for the newer Network Extension URL Filter, not this Screen Time shield.

## 5. `.individual` versus `.child`

- **DOCUMENTED | high.** `requestAuthorization(for:)` supports both `.individual` and `.child`; a child authorization requires parent/guardian authentication, while an individual authenticates their own account. [Apple: `requestAuthorization(for:)`](https://developer.apple.com/documentation/familycontrols/authorizationcenter/requestauthorization(for:))
- **DOCUMENTED | high.** The picker’s source differs: individually authorized picker views include apps and websites from that same device; a parent-device picker displays authorized child-device activity. [Apple: `FamilyActivityPicker`](https://developer.apple.com/documentation/familycontrols/familyactivitypicker)
- **UNVERIFIED | medium.** No public Apple documentation found establishes a different `WebDomain`/`WebDomainToken` type rule, `.specific` behavior, or browser coverage under `.individual` versus `.child`. The type distinction and filter-policy conclusions therefore apply equally at the API signature level, while the available picker inventory and authorization actor differ.
- **DOCUMENTED | high.** Apple says that after an individual authorizes an app, the system removes restrictions that prevent the user from bypassing parental controls, including deleting the authorized app or signing out of iCloud. [Apple: `requestAuthorization(for:)`](https://developer.apple.com/documentation/familycontrols/authorizationcenter/requestauthorization(for:))

- **DOCUMENTED | high.** This does not make `.individual` a different web-shield API. It does make the enforcement context materially weaker for this self-restraint product, as already recorded in the project ADRs. [Apple: requestAuthorization(for:)](https://developer.apple.com/documentation/familycontrols/authorizationcenter/requestauthorization(for:))

## 6. Replacement for the targets screen and design consequence

- **DOCUMENTED | high.** Keep the typed-domain targets screen as the primary design, but apply typed entries through `ManagedSettingsStore.webContent.blockedByFilter = .specific(Set<WebDomain>)`, not `store.shield.webDomains`. The inspected interface exposes `blockedByFilter` as a settable `FilterPolicy?`, and `.specific` takes `Set<WebDomain>`. [Apple: `blockedByFilter`](https://developer.apple.com/documentation/managedsettings/webcontentsettings/blockedbyfilter-swift.property), [Apple: `specific`](https://developer.apple.com/documentation/managedsettings/webcontentsettings/filterpolicy/specific(_:))

- **DOCUMENTED | high.** This is filtering semantics, not a `ShieldSettings` shield-overlay promise. Apple describes `blockedByFilter` as configuring which websites a user can access and documents up to 50 blocked domains plus 50 exceptions at once. [Apple: `blockedByFilter`](https://developer.apple.com/documentation/managedsettings/webcontentsettings/blockedbyfilter-swift.property)

- **UNVERIFIED | low.** Treat actual enforcement of `.specific` for typed domains as a hardware/runtime test requirement. The public API signatures prove that the policy is representable, but the sources inspected here do not establish exact matching rules, browser coverage, or behavior in every WebView.

- **DOCUMENTED | high.** Conditional alternative: if the product requires shield-overlay semantics, replace typed website entries with the system `FamilyActivityPicker`, persist its `webDomainTokens`, and assign those tokens to `ShieldSettings.webDomains`. Apple says picker selections are opaque and does not provide a stable user-readable domain-name read-back. The screen then shows counts or opaque “websites selected” state, not names. [Apple: `FamilyActivityPicker`](https://developer.apple.com/documentation/familycontrols/familyactivitypicker), [Apple: `FamilyActivitySelection`](https://developer.apple.com/documentation/familycontrols/familyactivityselection), [Apple: `ShieldSettings.webDomains`](https://developer.apple.com/documentation/managedsettings/shieldsettings/webdomains-swift.property)

- **UNVERIFIED | medium.** The schedule record can retain typed strings for the filter path, or an encoded selection/token set for the picker path. For picker tokens, stable name reconstruction, migration, and cross-device portability must not be assumed. If a token stops resolving, ADR 0002’s existing rule applies: coverage degrades, never the deadline. [Apple: `FamilyActivitySelection`](https://developer.apple.com/documentation/familycontrols/familyactivityselection)

- **UNVERIFIED | medium.** The correction to ADR 0003 is therefore conditional, not absolute: **typed entries remain if filtering semantics are acceptable; picker tokens replace them only when shield-overlay semantics are required.** The interface signatures establish the two representations, but runtime matching and coverage still require hardware validation. [Apple: `blockedByFilter`](https://developer.apple.com/documentation/managedsettings/webcontentsettings/blockedbyfilter-swift.property), [Apple: `ShieldSettings.webDomains`](https://developer.apple.com/documentation/managedsettings/shieldsettings/webdomains-swift.property)

## Gaps that remain open

1. **UNVERIFIED | low.** Cold-site picker behavior is undocumented. No claim that a never-visited site can be selected is safe. [Apple: `FamilyActivityPicker`](https://developer.apple.com/documentation/familycontrols/familyactivitypicker)
2. **UNVERIFIED | low.** Managed Settings browser scope is undocumented. Safari, Chrome, Firefox, Brave, and each embedded WebView require hardware tests. [Apple: `ShieldSettings.webDomains`](https://developer.apple.com/documentation/managedsettings/shieldsettings/webdomains-swift.property)
3. **UNVERIFIED | medium.** `.individual` enforcement details beyond authorization are undocumented. The type signatures do not vary, but bypass behavior is explicitly different. [Apple: `requestAuthorization(for:)`](https://developer.apple.com/documentation/familycontrols/authorizationcenter/requestauthorization(for:))
4. **UNVERIFIED | high.** This research did not run on a paired iPhone or iPad. The Mac interface inspection succeeded; runtime behavior, token resolution, and browser coverage remain unverified.
