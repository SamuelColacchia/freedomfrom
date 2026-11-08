# Filtering past 50 domains

**The traditional Network Extension content filter does not qualify for this product's individual authorization. The strongest documented large-list candidate is the separate iOS 26 URL filter, but the owner can disable it in Settings. Encrypted DNS is another supported, user-disableable option. None of the sources establishes an owner-proof commitment on an unsupervised device.** Apple explicitly restricts the traditional filter's Screen Time exception to child authorization; its URL-filter sample explicitly permits later Settings disablement. [Deployment requirements][deployment] [URL-filter sample][url-sample] [Individual authorization][wwdc22]

| Mechanism | Max sites | Unsupervised and individual-auth allowed | Entitlement or approval needed | Browser coverage | Can user turn it off mid-commitment? | Can app detect that? | Primary sources |
|---|---|---|---|---|---|---|---|
| Traditional `NEFilterManager`, data/control providers | No published domain-count maximum found; unusable for this authorization | **No** for standalone individual authorization. Screen Time exception is child-only | NE `content-filter-provider`; Family Controls distribution approval for child route | WebKit browser flows; socket flows if configured | Not installable through the supported individual route; child protections cannot be transferred to it | Configuration notification and reload where supported, not proof every flow was blocked | [TN3134][deployment], [providers][content-providers], [configuration][filter-manager] |
| iOS 26 `NEURLFilterManager` and control provider | Apple says **millions of URLs**; no fixed maximum published | **Yes**; unmanaged consumer deployment, independent of Family Controls | NE `url-filter-provider`; Apple relay/server validation and registration before distribution | WebKit and `URLSession`; other stacks must voluntarily participate | **Yes**, explicitly in Settings | Configuration/status sequences, reload, enabled state; no continuous background guarantee | [Overview][url-overview], [sample][url-sample], [WWDC25][wwdc25] |
| `NEDNSSettingsManager` plus filtering DoH/DoT resolver | Resolver-dependent; no Apple domain-list cap specified | **Yes**, iOS 14+; independent of Family Controls | NE `dns-settings`; no provider extension | System DNS users, across apps; not arbitrary app-managed resolution | **Yes**; user enables/selects DNS in Settings; VPN DNS can supersede it | Reload and read `isEnabled`; not proof all queries used it | [Manager][dns-manager], [WWDC20][dns-video], [Private Relay paper][relay-paper] |
| `NEDNSProxyProvider` | No published domain-list maximum found | **No** standalone individual route; supervised/managed modes exist | NE `dns-proxy`; relevant managed deployment | Intercepted TCP/UDP DNS sockets on port 53, not arbitrary HTTPS | Managed policy determines controls; outside this product model | Manager state in an eligible deployment, not an individual-auth solution | [TN3134][deployment], [provider][dns-proxy], [Deployment guide][deployment-filtering] |
| `NEPacketTunnelProvider` | No website-list cap specified for a real remote VPN; **local filtering use is unsupported** | **Yes** for an ordinary VPN; **no** supported local-filter substitute | NE `packet-tunnel-provider`; guideline 5.4 approval/requirements | Routed IP traffic; no guaranteed decrypted hostname or URL metadata | **Yes** for an unmanaged VPN; On Demand is not Always On | Connection/configuration state and notifications while executable | [TN3120][packet-use], [TN3134][deployment], [5.4][review-vpn] |
| Safari content blocker | **Unverified** current numeric ceiling in the requested source classes; do not treat 150,000 rules as a verified shipped-device guarantee | **Yes**; independent of Family Controls | Content blocker extension and normal App Review | Safari; `SFSafariViewController` supports content blocking; not arbitrary other web views | **Yes**, user-controlled extension/site settings | Global enabled state query; per-page effective protection **Unverified** | [Creation][safari-create], [enabled state][safari-enabled], [Safari view controller][safari-view] |
| `WKContentRuleList` | **Unverified** current numeric ceiling; rules are not sites | **Yes**, for the app's own web view | Normal app distribution; no Family Controls authority needed for its own view | Only web views to which the owning app attaches rules | User can use a different browser/app | Own list attachment can be inspected; no system-wide enforcement state | [Rule list][wk-rules], [controller][wk-controller] |
| ManagedSettings `.specific` domain list | 50 app-provided domains; hardware found an approximately 50-unique-domain union across stores | **Yes** | Family Controls distribution approval | Safari observed by #80; exhaustive browser matrix **Unverified** | **Yes**, revoke Family Controls | Authorization change; configured list readback does **not** prove effective filtering | [Property][blocked-filter], [#80 results][capacity], [WWDC22][wwdc22] |
| `shield.webDomains` | **50 web-domain tokens** at once | **Yes** | Family Controls distribution approval | Website shielding; exact browser matrix **Unverified** | **Yes**, revoke Family Controls | Authorization observable; no documented universal effective-shield query | [Property][shield-domains], [store caveat][managed-store], [WWDC22][wwdc22] |
| `shield.webDomainCategories` | **50 category tokens**, 50 domain-token exceptions; site count per category not specified | **Yes** | Family Controls distribution approval | Website category shielding; exact browser matrix **Unverified** | **Yes**, revoke Family Controls | Authorization observable; category contents/effective coverage not certified | [Property][shield-categories], [WWDC22][wwdc22] |
| `blockedByFilter = .auto(...)` | Apple adult classifier has no published site count; app additions and exceptions each capped at 50 | **Yes** | Family Controls distribution approval | Built-in filter; Safari observed for explicit additions; exact adult-filter matrix **Unverified** | **Yes**, revoke Family Controls | Authorization observable; no classification/effective-filter certificate | [Auto policy][auto], [Deployment guide][deployment-filtering], [#80][capacity] |
| `blockedByFilter = .all(except:)` | All websites, with at most **50 exception domains** | **Yes** | Family Controls distribution approval | Built-in filter; exact browser matrix **Unverified** | **Yes**, revoke Family Controls | Authorization observable; not effective reachability | [All policy][all-policy], [store caveat][managed-store] |
| Global HTTP proxy | No site-list maximum stated; proxy-dependent | **No** for device-wide iPhone/iPad deployment without supervision | Supervised configuration, generally management infrastructure | Most HTTP(S) traffic; non-HTTP apps can bypass it | Managed policy determines controls; outside this model | No standalone Family Controls solution | [Deployment guide][deployment-filtering] |
| Native Screen Time website/app limits | No useful custom-list expansion established here | **No** as a separate third-party control channel beyond the Screen Time APIs above | User/guardian configures native Screen Time | Native system restrictions; no extra third-party coverage guarantee | Owner controls individual authorization; native passcode setup is a separate ritual | No public Screen Time passcode management API established | [Screen Time API introduction][wwdc21], [individual API][wwdc22], [ADR 0001][adr1] |
| Declared Age Range | Not a website filter | **Yes** to requesting age information; **no** to cross-app blocking authority | Declared Age Range capability | Own app's age-appropriate experience | Does not impose a website commitment | Age information is not filter-state evidence | [Framework][age-range] |

Research for [#83](https://github.com/SamuelColacchia/freedomfrom/issues/83), checked 2026-11-08. This is a documentation report, not the hardware completion of that issue. No installations, device probes, entitlement applications, or App Review submissions were performed.

## Evidence and scope

The target is the owner's unsupervised iPhone/iPad with `requestAuthorization(for: .individual)`. Apple introduced independent individual authorization in iOS 16 and explicitly lets individuals deauthorize apps through either of two Settings switches. It also says the child mode's implicit iCloud sign-out and app-deletion restrictions do not apply to individual authorization. Do not interpret an entitlement, an installed configuration, or a running extension as a stronger authorization contract. [WWDC22][wwdc22] [Family Controls][family]

The existing [#80 results][capacity] are hardware evidence for one iPad Pro on iPadOS 27.0.1, Safari, individual authorization, and the recorded configuration only. They show that 26 plus 26 distinct domains across two stores disabled all tested filtering, while 25 plus 25 worked. They do not measure Network Extension providers, shield-token capacity, another app's stores, or all browsers. They also show that reading configured lists back cannot identify this overflow failure. [Recorded experiment][capacity]

External authorities below are Apple documentation, WWDC transcripts, Apple deployment/security material, App Review rules, and Apple's privacy paper and user instructions where these explain Settings or Private Relay. No third-party article or non-staff forum assertion is used as authority. Apple's JSON documentation endpoints were used when needed, including [TN3134 JSON](https://developer.apple.com/tutorials/data/documentation/technotes/tn3134-network-extension-provider-deployment.json). One attempted forum page, [812453](https://developer.apple.com/forums/thread/812453), returned a human-verification page and supplies no evidence here. The Family Controls request form's unauthenticated response exposed no substantive approval criteria; the entitlement documentation and technote establish the request requirement instead. [Family Controls entitlement][family-entitlement]

## Traditional Network Extension content filter

### Eligibility is child-only, not individual

The decisive source is Apple's current deployment technote, not an inference from WWDC21's broad description of the Screen Time API:

> "In the Screen Time case, content filters are only supported on child devices."
>
> "Run it on a device where the user has signed in as an under 18 child member of an iCloud family."
>
> On iOS 16 and later, request authorization "passing in the `.child` option."

The same section requires parental/guardian authorization and Family Controls distribution permission. Its table dates the Screen Time route to iOS 15, the ordinary supervised content-filter route to iOS 9, and per-app filtering on managed devices to iOS 16. None is a standalone `.individual` consumer exception. [TN3134][deployment]

WWDC21 says authorized apps' on-device Network Extension filters "will be installed automatically and cannot be removed." That session describes child authorization through a guardian, before individual authorization existed. WWDC22's addition of `.individual` does not broaden that promise; TN3134 expressly resolves the ambiguity. [WWDC21][wwdc21] [WWDC22][wwdc22] [TN3134][deployment]

Development success is insufficient evidence. `NEFilterManager` documentation permits a temporary supervision override for development/testing with `get-task-allow`; its distribution discussion requires supervised devices. TN3134 adds the narrowly defined child exception. A development build prompting to install a filter on an adult's phone therefore does not establish App Store/TestFlight eligibility. [Manager][filter-manager] [TN3134][deployment]

### Entitlements and distribution

The iOS entitlement is `com.apple.developer.networking.networkextension` with `content-filter-provider`. Apple's entitlement page says to enable the Network Extensions capability in Xcode for an App Store app. It describes `content-filter-provider-systemextension` as the Developer ID variant, not an iOS permission upgrade. TN3134 packages iOS providers as app extensions; macOS system-extension deployment is a separate case. [Entitlement values][ne-entitlement] [Deployment matrix][deployment]

For the child Screen Time route, add the Family Controls capability and obtain its distribution permission through Apple's [Family Controls request page](https://developer.apple.com/contact/request/family-controls-distribution). The cited sources establish no separate special application form for ordinary iOS `content-filter-provider` entitlement use, and obtaining that entitlement would not waive the child/supervision restriction. Approval for freedomfrom or any new bundle identifier is **Unverified** until its provisioning profiles and distribution submission are accepted. [Family entitlement][family-entitlement] [TN3134][deployment] [NE entitlement][ne-entitlement]

### Visibility, capacity, privacy, and removal

A data provider evaluates network flows and returns allow/block decisions. The control provider can maintain a disk database of rules. The data provider's restricted sandbox prevents exporting observed network content; the control provider can update rules but cannot access that content. This is a custom rules/database design, not the ManagedSettings 50-domain property. No fixed domain-rule maximum is stated by these provider documents; a practical capacity guarantee is **Unverified** and would require a relevant-device measurement. [Provider architecture][content-providers] [Control provider][filter-control]

Do not equate encrypted bytes with full URL access. `NEFilterFlow.url` is non-nil only for flows from WebKit browser objects. `NEFilterSocketFlow.remoteHostname` is populated only for create-by-name APIs such as `URLSession` or Network framework. Browser filtering and socket filtering are separately configurable. WWDC25 says a traditional filter can use host/port information but cannot obtain encrypted HTTPS resource paths or query parameters from traffic inspection. WebKit browser-flow metadata is the separate documented case. Universal SNI or hostname availability is **Unverified**. [Flow URL][flow-url] [Remote hostname][remote-host] [Browser switch][filter-browsers] [Socket switch][filter-sockets] [WWDC25][wwdc25]

`NEFilterConfigurationDidChange` reports preference changes, after which the app can reload configuration. It does not certify that every intended website was denied. For this product, the supported installation route is already absent, so there is no valid individual-mode "cannot remove" guarantee to exploit or measure as a product promise. [Notification][filter-notification] [Manager][filter-manager] [TN3134][deployment]

## iOS 26 URL filter

### A different API with a supported consumer route

This API exists. The configuration API is `NEURLFilterManager`; an extension implements the `NEURLFilterControlProvider` protocol. `NEURLFilter` itself is the participation API for applications that otherwise would not be covered automatically. TN3134 and WWDC25 place the new URL-filter provider at iOS 26. The standalone `NEURLFilter` JSON page currently exposes inconsistent older numeric availability metadata; use the deployment matrix, manager/provider availability, and WWDC announcement rather than inventing an iOS 19 product requirement from that field. [TN3134][deployment] [Manager][url-manager] [Participation API][url-participation] [WWDC25][wwdc25]

Apple says URL filters support "millions of URLs" and "both managed and unmanaged devices." Automatic checking covers requests made through WebKit and `URLSession`. Other networking stacks must voluntarily call the participation API and honor denial. Thus "system-wide" in Apple's introduction does not mean every browser engine, custom HTTP implementation, or raw socket is compelled to participate. [Overview][url-overview] [WWDC25][wwdc25]

### Data, approval, and privacy

The app supplies an on-device Bloom filter and a matching off-device Private Information Retrieval database. Negative Bloom results can be allowed locally; positive matches require a final lookup because Bloom filters can produce false positives. The operating system performs filtering; the app does not receive the user's URLs in the filtering path. Apple's design combines PIR, Privacy Pass, and an Apple-hosted Oblivious HTTP relay so the server cannot learn the queried URL or link it to the originating IP address. A bundled Bloom filter alone is not the complete documented filtering solution. [Overview][url-overview] [WWDC25][wwdc25]

Enable the NE `url-filter-provider` entitlement. The current overview directs developers to register the configuration on CloudKit Console's Identity & Trust page. WWDC25 says Apple validates the relay/server configuration before distribution, including App Store, TestFlight, ad hoc, and enterprise builds; development-signed builds are exempt. These are additional gates beyond possessing Family Controls distribution permission. Actual account approval and end-to-end distribution remain **Unverified** for freedomfrom. [Entitlement][ne-entitlement] [Registration][url-overview] [WWDC25][wwdc25]

The matching model can represent host-wide blocks. The manager generates sub-URLs including parent hosts and path prefixes; its documented example produces `example.com` from a request to `www.sub1.example.com`. Dataset matching does not support wildcards or regular expressions directly, although parsing can be configured. This is not proof that a child's subdomain exception can override an included parent key: a final denial can still match another generated key. Per-user domains, nine independently selected groups, exceptions, and synchronized dataset changes require a concrete dataset design and verification. Those product semantics are **Unverified**. [Parsing and matching][url-manager]

### Disablement and detection

Apple's sample is explicit:

> "You can also use the Settings app to enable or disable it later."

The same sample describes the installation permission prompt, device password, and Settings confirmation. Family Controls is not what installs or locks this configuration. There is no documented individual-mode promise that it becomes unremovable for the commitment's duration. [Sample setup][url-sample]

The manager exposes `handleConfigChange()`, `handleStatusChange()`, `isEnabled`, status, and preference loading. These let a running app observe configuration changes and stopped/invalid/running states. They do not establish that a suspended or deleted app receives an immediate durable record of every bypass. Exact notification latency and stopped-app behavior are **Unverified**. [Configuration changes][url-config-change] [Status changes][url-status-change] [Sample monitoring][url-sample]

`shouldFailClosed` defaults to false. When true, an enabled filter blocks if it cannot decide, including PIR communication failure. This helps with server/network failure, not user disablement. Offline positive-match behavior, cached decisions, stale dataset transitions, and timely release at the commitment deadline must be probed before this can replace the current enforcement path. [Failure policy][url-fail-closed]

## Encrypted DNS settings and a filtering resolver

`NEDNSSettingsManager`, available from iOS 14, can configure DoH or DoT using NE `dns-settings`. Apple's demonstration requires only an app, not a provider extension, and shows system-wide DNS configuration selected in Settings. This can direct DNS resolution to a service that refuses listed names; Apple does not specify a 50-domain blocklist budget for that resolver. Its list size and classification are the resolver's responsibility. [Manager][dns-manager] [Entitlement][ne-entitlement] [WWDC20][dns-video]

This is an independent user-controlled configuration. Apple requires the user to enable it, and `isEnabled` is read-only. The app can reload preferences to see whether its configuration is enabled; an old in-memory manager object can retain removed settings until it reloads. Configuration state is not proof that every lookup used the resolver. [Manager][dns-manager] [Enabled state][dns-enabled] [Removal semantics][dns-removal]

Coverage is by DNS use rather than by browser brand. Apple documents VPN precedence: "resolution within the VPN tunnel will use the VPN's DNS settings and not your system-wide settings." It also documents captive-network exceptions and configurable network/domain exceptions. An app making its own HTTPS request to another resolver is outside a system-resolver selection API's documented control; that is a mechanism-based inference, not an observed bypass on these devices. Path-specific or mixed-content-page filtering is not a DNS hostname decision. [WWDC20][dns-video] [DNS scope][dns-overview]

Private Relay is not automatically a bypass of app-configured encrypted DNS. Apple's paper says:

> "If a user has configured custom-encrypted DNS settings using a profile or an app, the DNS server specified will be used instead of ODoH."

Safari resolves through that server before Private Relay routing. The paper separately says ordinary unencrypted network/manual DNS is not used for Private Relay traffic. These must be tested as different configurations. Current-device behavior with the selected resolver, VPNs, caching, and app-specific DNS remains **Unverified**. [Private Relay overview, page 10][relay-paper]

This route would require a resolver service and its privacy policy. The NE entitlement documentation does not prescribe a separate Family Controls approval for DNS settings. Normal App Review and user-data obligations still apply; selecting or operating a service is a later product/technology decision. [Entitlement][ne-entitlement] [Review privacy requirements][review-privacy]

## DNS proxy provider

TN3134 lists system-wide DNS proxy deployment on supervised devices from iOS 11, plus per-app deployment on managed devices from iOS 16. Its DNS proxy table has no Screen Time exception. The content-filter exception is expressly child-only and does not grant a DNS proxy permission. [TN3134][deployment]

The Deployment guide separately says that the DNS Proxy payload no longer requires supervision from iOS/iPadOS 15, but "you need to install it using a device management service." This is not a standalone App Store app permission. The exact reconciliation of that iOS 15 payload wording with TN3134's iOS 16 per-app provider row is **Unverified**, but both exclude using `.individual` alone as the installation authority. [Deployment guide][deployment-filtering] [TN3134][deployment]

The provider intercepts flows to TCP or UDP port 53. It is not documented as capturing arbitrary DoH requests or all encrypted name resolution. NE `dns-proxy` is the entitlement; management policy, not this product's individual authorization, would supply installation and persistence controls. There is no eligible consumer-mode removal guarantee to report. [Provider][dns-proxy] [Entitlement][ne-entitlement] [TN3134][deployment]

## Packet tunnel and VPN

An ordinary device-wide `NEPacketTunnelProvider` VPN is deployable without supervision from iOS 9; TN3134 reserves managed-device requirements for its per-app mode. However, a tunnel is not Apple's supported way to build the proposed local DNS/SNI blocker. [TN3134][deployment]

TN3120 is decisive:

> "Do not use a packet tunnel provider to implement a network content filter."
>
> "Do not use a packet tunnel provider to intercept all DNS traffic on the system."

Apple says packets read from `NEPacketTunnelFlow` should go over a tunnel to a remote network, rather than be dropped or reinjected locally. It also rejects selectively claiming traffic and proxying the remainder through another interface. A real VPN sending traffic to a filtering remote network is a different, supported architecture; App Store presence of another local blocker would not override this technical guidance. [TN3120][packet-use] [Deployment filtering overview][deployment-filtering]

The tunnel receives IP packets, not a contract for decrypted HTTPS URLs or hostnames. DNS/SNI inspection therefore cannot be advertised as complete URL or hostname coverage. Current ECH, QUIC, custom-resolution, and proxy behavior for specific clients is **Unverified**. Apple's own WWDC25 guidance says packet tunnel providers lack the application-level metadata needed for filtering and recommends the dedicated filter APIs. [Packet flow][packet-flow] [WWDC25][wwdc25]

Connect On Demand evaluates rules to start a connection; it does not supply the supervision-backed Always On VPN guarantee. Apple reserves Always On VPN for supervised deployment with IKEv2, including dropping IP traffic when its tunnels are down. An unmanaged owner can change or remove VPN/filter settings. A simple Disconnect may reconnect with On Demand, but disabling On Demand or removing the unmanaged configuration is still a different escape to probe. [On Demand rules][vpn-demand] [VPN security][vpn-security] [User settings controls][settings-removal]

Connection status and `NEVPNStatusDidChange`, configuration notifications, and reloading preferences provide observations while the app can execute. `.invalid` can mean either absent or not enabled; it does not uniquely prove deletion. Another custom tunnel may also conflict: `NETunnelProviderManager` documents only one enabled enterprise VPN configuration at a time, while distinguishing Personal VPN coexistence. Avoid the blanket claim that every kind of VPN is mutually exclusive. [Connection][vpn-connection] [Invalid status][vpn-invalid] [Tunnel configuration model][tunnel-manager]

App Review guideline 5.4 permits "Parental control, content blocking, and security apps, among others, from approved providers" to use the VPN API. It also requires VPN service apps to use `NEVPNManager`, organization enrollment, advance in-app data-use disclosure, the stated prohibition on third-party data use/disclosure, a corresponding privacy commitment, and licenses where applicable. This is an approval route, not approval for this implementation or an exemption from TN3120. freedomfrom's approval is **Unverified** until Apple accepts the actual submission. [Guideline 5.4][review-vpn]

## Safari content blockers and WKContentRuleList

A Safari content blocker supplies declarative JSON rules matching URLs, document/resource types, and domain conditions. It can block loads rather than merely hide an element. The containing app delivers the extension through the App Store; Safari applies compiled rules without consulting the app while browsing, and the blocker does not learn the user's history or visited websites. This is separate from Family Controls and its 50-domain property. [Creating a content blocker][safari-create]

**Unverified: the current numeric rule ceiling within the requested documentation/source classes.** This investigation did not find a current developer.apple.com document, WWDC statement, or identified Apple-staff forum answer establishing a shipped iOS 26/27 limit of 150,000 rules per list, a higher limit, or a guaranteed device-wide total. Do not promote that commonly quoted number into a verified API guarantee. A JSON rule is also not necessarily one website because its trigger can match many URLs. Compile and enforce the boundary on the target SDK/devices, or obtain a current Apple statement. [Documented rule format][safari-create] [Safari 27 release notes][safari27]

Safari is not the only relevant view: Apple explicitly lists content blocking among `SFSafariViewController`'s supported Safari features. Conversely, `WKContentRuleList` is attached through `WKUserContentController` to an app's own web views. It cannot install rules into every other app's `WKWebView`. Exact propagation of a particular Safari extension into Safari view controllers, private browsing, and current browsers is **Unverified** until measured. [Safari view controller][safari-view] [Rule list][wk-rules] [Web-view controller][wk-controller]

The owner can disable Safari extensions in Settings and change content-blocker use per website. `SFContentBlockerManager` exposes the extension's global enabled state; it does not document a certificate that a particular navigation was filtered. Per-site or temporary bypass detection is **Unverified**. No public ManagedSettings Safari-extension lock was found: `SafariSettings` documents cookies and AutoFill, not extension enablement. [Apple's extension instructions][safari-user] [Per-site instructions][safari-sites] [Enabled state][safari-enabled] [SafariSettings][safari-settings]

Safari Web Extensions provide another Safari-scoped implementation approach, including declarative request blocking. WWDC26 demonstrates a website blocker and new packaging/distribution tooling; this does not turn it into a device-wide or non-disableable commitment mechanism. [WWDC26 extension session][webextensions26] [Safari 27 overview][webkit26]

## ManagedSettings beyond the string-domain list

### Direct website shields

Apple documents "up to 50 web domain tokens at once" for `shield.webDomains`. These are picker-issued tokens, not a way to turn a bundled list of arbitrary hostnames into thousands of shields. The current product deliberately rejected this opaque representation in favor of typed names; revisiting it would change ADR 0006's product trade-off. [Shield domains][shield-domains] [Screen Time picker introduction][wwdc21] [ADR 0006][adr6]

### Category shields

`shield.webDomainCategories` supports up to 50 category tokens and 50 website-token exceptions. A category can cover more sites than one explicit domain token, so this is a possible broad Apple-category shield, not a 50-site claim. Apple does not publish the number of websites in each category or guarantee that its categories map to the nine requested groups. A token for an Apple category is not a custom taxonomy definition. [Category property][shield-categories] [Picker and opaque tokens][wwdc21]

**Unverified:** whether the direct-shield and category policies share any enforcement budget with `blockedByFilter`, how multiple stores aggregate those limits, which websites/categories are selectable before use, and exact browser/web-view coverage. Separate documented properties do not prove independent effective budgets. #80 measured only the string-domain filtering path, so neither its overflow result nor its approximate 50-domain union can be transferred to shields without a mixed-policy probe. [Shield properties][shield-domains] [Category property][shield-categories] [#80 experiment][capacity]

### Adult filtering and allowlist mode

`.auto` means "The system blocks adult content," with up to 50 extra blocked domains and 50 exceptions. The adult classifier is not bounded to those 50 supplied names, but Apple supplies neither a category inventory nor a numeric site count. It cannot be claimed to implement the other eight groups, or a user-defined mixed-content policy. The Deployment guide describes built-in filtering of Safari and third-party apps but does not prove an exhaustive `.individual` browser matrix. [Auto policy][auto] [Deployment guide][deployment-filtering]

`.all(except:)` blocks all sites with up to 50 allowed exceptions. It can deny more than 50 sites by blocking nearly everything, but implements the inverse product: a small allowlist rather than nine large denylist groups. Any non-`.none` `blockedByFilter` policy also disables Safari Private Browsing. [All policy][all-policy] [Filter property][blocked-filter]

### Can ManagedSettings lock the other settings?

The relevant documented controls are `application.denyAppRemoval`, `passcode.lockPasscode`, and `account.lockAccounts`. They respectively describe preventing app removal, changes to the device passcode, and changes to account information. They do not describe locking a VPN/DNS/content-filter switch or setting an unrecoverable Screen Time PIN. `CellularSettings` covers cellular-data/plan/eSIM changes; `SafariSettings` covers cookies/AutoFill. No VPN, DNS, or Safari-extension enablement lock appears in the reviewed `ManagedSettingsStore` groups. [Removal][deny-removal] [Passcode][passcode] [Account][account] [Cellular][cellular] [Safari][safari-settings] [Store groups][managed-store]

**Unverified:** effective behavior of those explicit removal/passcode/account controls under `.individual`, and their collateral on a particular current device. Apple's statement that child mode's *implicit* protections do not apply does not prove every explicit property is ignored. Conversely, setting an explicit property does not establish enforcement: Apple warns, "The system doesn't guarantee that the settings you specify govern the device's behavior." Even a working app-removal restriction is not evidence of a DNS/VPN switch lock, and individual authorization remains revocable. [WWDC22][wwdc22] [Store caveat][managed-store]

The iOS 26.5 `isActive`, `stores`, and token-refresh APIs do not establish an effective-filter query or increase a website-list cap. `isActive` controls whether a store participates in effective-settings calculation; `stores` lists this app's configured stores; refresh APIs refresh expired tokens. These are useful management changes, not evidence that a configured 52-domain union is being enforced. [isActive][store-active] [stores][store-list] [Token refresh][store-refresh] [#80][capacity]

## Other mechanisms and iOS 27

The Deployment guide requires supervision for global HTTP proxy on iPhone/iPad and warns that non-HTTP applications can bypass it. MDM-installed filters, nonremovable management policy, and Always On VPN therefore do not answer the standalone consumer-app question by merely avoiding the ManagedSettings list. Supervision would change the stated deployment model and ADR 0001's decision. [Deployment guide][deployment-filtering] [VPN security][vpn-security] [ADR 0001][adr1]

Declared Age Range requests an age range so an app can tailor its own experience. Its documented purpose and entitlement do not grant network filtering, Family Controls child authorization, or control over other applications. Native Screen Time limits likewise do not establish a second programmable channel for this app beyond the Screen Time frameworks already examined. No public way to set or verify a Screen Time passcode was established; ADR 0001 already rejects a setup ritual based on it. [Age framework][age-range] [Screen Time API][wwdc21] [ADR 0001][adr1]

The current [iOS/iPadOS 27 release notes][ios27] were checked, including NetworkExtension, Screen Time, and Safari Extensions. They record a VPN `includeAllNetworks`/CarPlay fix and a child-account restriction fix, not an individual-authorization expansion for traditional content filters. The [Safari 27 notes][safari27] and [WWDC26 WebKit session][webkit26] were also checked. WWDC26's web-extension work adds browser extension tooling rather than a non-disableable system filter. This is a bounded source review, not proof that no other relevant API can ever exist; any claimed new individual-mode exception needs an explicit current Apple contract. [TN3134 remains explicit about child-only content filters][deployment]

## Recommended path and what hardware must confirm

Recommend the **iOS 26 URL filter as the next feasibility probe**, with its server, distribution, and Settings bypass treated as gating costs. It directly addresses large URL sets, supports unmanaged consumer deployment, and uses the intended filtering API. Do not implement the traditional data/control filter for `.individual`, and do not use a local packet tunnel to evade its deployment restriction. Those recommendations follow Apple's explicit contracts. [URL filtering][url-overview] [TN3134][deployment] [TN3120][packet-use]

This remains a proposal, not a technology selection or an implementation authorization. The product's claim should remain ADR 0001's "resists casual bypass while authorized" and "cannot prevent a determined bypass." A URL-filter Settings exit is an additional exit that remains available while Family Controls itself is authorized. It must be measured and included in coverage/reconciliation design, not hidden behind the existing authorization indicator. ADR 0005's rule to repair only what the app can observe and repair also rules out claiming an always-running anti-disable watchdog. [ADR 0001][adr1] [ADR 0005][adr5] [Settings disablement][url-sample]

If URL-filter backend operation, approval, or per-commitment data changes fail feasibility, encrypted DNS is a supported secondary direction, with weaker guarantees against alternate resolution and VPN DNS. Safari content blocking is a narrower companion or Safari-specific product choice. Apple category shields/adult auto filtering can supply selected broad behavior but do not establish the requested nine-group curated taxonomy. Keeping explicit ManagedSettings domains must preserve the observed aggregate budget; distributing the catalogue across stores is already disproven. [DNS behavior][dns-video] [Safari scope][safari-create] [Categories][shield-categories] [Adult filter][auto] [#80][capacity]

The following are proposed probes, **not completed results**. Use separate probe/sample apps before product implementation. For every run, record device model, OS build, authorization mode, signing/distribution type, installed profiles/extensions, active VPN/DNS/Private Relay settings, and initial reachability. Capture the page and UI tree for every counted host, including the actual final host after redirects; preserve raw observations and incomplete runs. This follows the existing [#80 method][capacity]. A readback, simulator result, or successful compilation is not a pass for enforcement.

1. **Prove the consumer distribution route.** Install Apple's URL-filter sample with a working PIR/Privacy Pass/OHTTP setup on an unsupervised iPhone and iPad, first development-signed and then through approved TestFlight distribution. Test with no Family Controls grant and then with `.individual`. Record every prompt and Settings confirmation. Pass only if the distribution build enables and actually blocks its sentinel URL on both intended OS versions. A development-only success, missing relay approval, or installed-but-nonfunctional filter fails the shipping gate. The traditional content filter's child-only contract is a documented rejection; do not count a development override as contrary evidence. [URL sample][url-sample] [WWDC25 distribution gate][wwdc25] [TN3134][deployment]
2. **Prove large-set capacity and updates.** Load synchronized URL datasets containing 51, 100, 1,000, and the expected launch-catalogue count, using reachable harmless hosts. Check every listed host at the smaller sizes and all independently established sentinels plus a reproducible sample at catalogue size, with unlisted controls. Repeat with two different group selections and an added explicit user host. Pass only if all counted listed hosts deny and controls load, including after provider/app termination and restart; any silent wholesale disablement fails. This is needed because Apple's "millions" capability does not measure this configuration. [URL overview][url-overview]
3. **Prove matching and per-user separation.** In the URL sample, test apex, multiple subdomains, unrelated siblings, IDNs, ports, paths, query variants, redirects, and a requested exception beneath a blocked parent. Use two devices with different active group selections and explicit domains against the same proposed service. Pass only if observed behavior matches the written product policy and one device's choice does not change the other's. A parent key still denying an intended exception or stale Bloom/PIR disagreement fails that policy design. [URL parsing][url-manager]
4. **Measure the actual Settings exit and detection.** While a URL-filter commitment sample is running, disable the filter in Settings with the app foregrounded, backgrounded, terminated, and after reboot. Log status/configuration events and reload results, then reopen the app. Repeat with explicit app-removal restriction applied under `.individual`, then revoke Family Controls and attempt deletion. Pass for honest state reporting only if a disabled filter is reflected at the next supported observation point without reporting working coverage. It fails any claim that removal protection also locks the filter toggle. Record latency rather than inventing an immediate-wakeup guarantee. [Sample disablement][url-sample] [Status observation][url-status-change] [Removal property][deny-removal]
5. **Measure coverage and alternate transports.** Test the same listed/unlisted URLs in Safari normal/private modes where available, `SFSafariViewController`, a separate test app's `WKWebView`, a `URLSession` test client, installed browsers, and an eligible alternative-engine/custom HTTP client. Repeat on Wi-Fi/cellular with custom encrypted DNS, Private Relay, an ordinary VPN, and HTTP/3 where supported. Pass only for the explicitly tested combinations that deny the site and leave controls usable; a custom stack bypass must narrow the advertised scope. [Automatic/voluntary URL checking][url-overview] [Safari view controller][safari-view]
6. **Test server failure and deadline release.** Run URL filtering with `shouldFailClosed` false and true, then interrupt PIR/OHTTP reachability, reboot, change networks, and exercise cached and unseen matches. Verify that an active commitment never silently changes to allowed coverage under the chosen contract, and that all policies release after the absolute deadline through the intended reconciliation points. Record first-unlock and stopped-app behavior. Failure to deny when promised, or failure to release within the defined reconciliation behavior, fails product readiness. [Failure policy][url-fail-closed] [ADR 0005][adr5]
7. **Test composition without exceeding the known list budget.** Combine the URL filter with a ManagedSettings `.specific` policy of at most 50 unique domains, then with `.auto` and category shields separately. Include conflicting allow/deny sentinels. Clear each mechanism separately and verify what remains denied; finally clear all. Pass only if a release or exception produces exactly the promised coverage. Treat composition between URL filtering and ManagedSettings as **Unverified** until this run; WWDC22's store-composition rule alone does not describe cross-framework composition. [Store rule][wwdc22] [URL manager][url-manager] [#80][capacity]
8. **If DNS remains a candidate, test its real bypasses.** Install a `NEDNSSettingsManager` app with a filtering DoH/DoT resolver and more than 50 reachable listed hosts. Test Settings disable/change, VPN-supplied DNS, manual unencrypted DNS, Private Relay, a client using its own DoH endpoint, cached lookups, direct-address access, and captive-network transitions. Compare actual pages with reloaded `isEnabled` and resolver evidence. Pass only for a declared, reproducible coverage contract; an enabled flag beside reachable blocked content fails a universal-coverage claim. In particular, test app-configured encrypted DNS with Private Relay separately from router/manual DNS. [WWDC20][dns-video] [Private Relay paper][relay-paper]
9. **If Safari remains a candidate, establish its boundary and bypasses.** Install a content blocker with sentinel document rules in lists of 150,000 and 150,001 distinct valid rules, plus smaller controls. Compile equivalent lists for the test app's `WKWebView`; test multiple independently enabled lists rather than assuming their totals. Capture compilation errors and verify first/middle/last sentinel enforcement. Then disable the extension globally and per site, use any offered temporary bypass, and compare actual loading with the enabled-state query. Pass only for the measured capacity and scope; no numeric cap is considered verified by this report alone. [Rule format][safari-create] [Web-view rules][wk-rules] [Enabled query][safari-enabled]
10. **Resolve shield budgets and explicit locks if they affect the proposal.** With individual authorization, establish 50 working string-domain blocks, add distinct direct shield tokens at 1 and 50, attempt 51, then reverse order and repeat across stores. Test category shields separately with many baseline-reachable sites in one category and compare those category labels with the nine proposed groups. Separately apply removal, passcode, and account locks and attempt the exact Settings changes, including DNS/VPN/URL-filter/Safari toggles and authorization revocation. Pass only for observed coverage/locks; an untested shield/filter budget relationship or a stored restriction value is not evidence. Restore every setting and verify baseline loading after release. [Shield cap][shield-domains] [Category cap][shield-categories] [Store caveat][managed-store]

## Corrections to #65's report

The earlier report was read with `git show origin/research/improvements-65:docs/research/website-category-filtering-and-exceptions-65.md`.

1. Its custom Network Extension classifier suggestion did not distinguish child authorization from individual authorization. TN3134 explicitly makes the traditional content-filter Screen Time exception child-only. That path is not available to this product merely because it already has Family Controls. The iOS 26 URL-filter API is the relevant additional consumer candidate. [TN3134][deployment] [URL filters][url-overview]
2. The 50-domain wording must not be read as 50 per store or an aggregate capacity that can be multiplied. Current property documentation says "Your app," and #80 measured wholesale loss of filtering for a 52-unique-domain union across two stores. The report's caution about aggregate behavior was appropriate; the hardware has now answered it for the recorded configuration. [Property][blocked-filter] [#80][capacity]
3. #65 repeated Apple's statement that `auto` exceptions override both adult filtering and explicit `domains`. The current documentation still says that. However, #80's `auto-self-except`, `wiki-except`, and `mc-except` observations contradict the explicit-domain override in the tested configuration. Record this as a **documentation/hardware discrepancy**, not a universal undocumented rule or a silently corrected Apple contract. An exception overlapping an explicit block must remain **Unverified** on another target OS until re-probed. [Auto documentation][auto] [Measured cases][capacity]
4. "Network Extension entitlement/distribution approval" should be separated into gates: the ordinary NE entitlement is added through Xcode, Family Controls has a distribution request for its authorized use, and the new URL filter has an additional relay/server validation and registration process. None implies approval for another mechanism or for freedomfrom's actual submission. [NE entitlement][ne-entitlement] [Family entitlement][family-entitlement] [WWDC25][wwdc25]

## Unverified claims and how to settle them

These are unresolved facts, not implied product guarantees:

- **Distribution acceptance for freedomfrom**, including URL relay/server registration, provisioning, TestFlight, and any VPN App Review classification. Settle with accepted profiles/registration and the real distribution submission, then probe 1.
- **Practical capacity, per-user datasets, atomic updates, exceptions, offline behavior, deadline release, cross-framework composition, and current transport/browser coverage of the proposed URL-filter configuration.** Settle with probes 2, 3, 5, 6, and 7.
- **Notification and state-refresh timing while apps are suspended, terminated, or deleted.** APIs document observable state, not an always-running bypass recorder. Settle with probe 4.
- **Current Safari/WKContentRuleList numeric ceilings**, including the 150,000-per-list claim, multiple-list totals, private-browsing/Safari-view-controller propagation, and per-site/temporary bypass detection. Settle with current Apple documentation/staff clarification and probes 5 and 9.
- **Shield budget independence and aggregation**, category contents, cold-site selection, mapping to nine groups, and exhaustive browser coverage. Settle with probes 5 and 10 and an explicit Apple contract where measurements cannot establish a lasting guarantee.
- **Effective explicit removal/passcode/account restrictions under individual authorization**, and any proposed indirect effect on network/extension switches. Settle with probe 10. No public direct VPN/DNS/extension lock was found in the reviewed API groups.
- **Current DNS/Private Relay/VPN/custom-resolution/cache behavior and SNI/ECH visibility** for specific clients. Settle with probe 8 and, only if pursuing a supported remote VPN, a separate routed-traffic measurement. Historical clear-SNI assumptions are insufficient.
- **The iOS 15 MDM DNS Proxy payload versus iOS 16 per-app provider wording.** Settle with Apple deployment/DTS clarification if managed deployment becomes relevant; it does not change the standalone individual verdict.
- **The adult-filter exception discrepancy and classifier coverage.** Re-run the overlapping-domain/exception cases on every supported OS and seek Apple clarification; do not assume an exception defeats an explicit deny.
- **Any newer individual-mode installation or anti-disable exception absent from the reviewed iOS 27/API sources.** Settle with an explicit current Apple document or Apple-staff answer and a distribution-build probe. No such exception is asserted here.

[deployment]: https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment
[content-providers]: https://developer.apple.com/documentation/networkextension/content-filter-providers
[filter-manager]: https://developer.apple.com/documentation/networkextension/nefiltermanager
[filter-control]: https://developer.apple.com/documentation/networkextension/nefiltercontrolprovider
[flow-url]: https://developer.apple.com/documentation/networkextension/nefilterflow/url
[remote-host]: https://developer.apple.com/documentation/networkextension/nefiltersocketflow/remotehostname
[filter-browsers]: https://developer.apple.com/documentation/networkextension/nefilterproviderconfiguration/filterbrowsers
[filter-sockets]: https://developer.apple.com/documentation/networkextension/nefilterproviderconfiguration/filtersockets
[filter-notification]: https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/nefilterconfigurationdidchange
[ne-entitlement]: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.networking.networkextension
[family-entitlement]: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.family-controls
[family]: https://developer.apple.com/documentation/familycontrols
[wwdc21]: https://developer.apple.com/videos/play/wwdc2021/10123/
[wwdc22]: https://developer.apple.com/videos/play/wwdc2022/110336/
[wwdc25]: https://developer.apple.com/videos/play/wwdc2025/234/
[url-overview]: https://developer.apple.com/documentation/networkextension/url-filters
[url-manager]: https://developer.apple.com/documentation/networkextension/neurlfiltermanager
[url-participation]: https://developer.apple.com/documentation/networkextension/neurlfilter
[url-sample]: https://developer.apple.com/documentation/networkextension/filtering-traffic-by-url
[url-config-change]: https://developer.apple.com/documentation/networkextension/neurlfiltermanager/handleconfigchange()
[url-status-change]: https://developer.apple.com/documentation/networkextension/neurlfiltermanager/handlestatuschange()
[url-fail-closed]: https://developer.apple.com/documentation/networkextension/neurlfiltermanager/shouldfailclosed
[dns-manager]: https://developer.apple.com/documentation/networkextension/nednssettingsmanager
[dns-overview]: https://developer.apple.com/documentation/networkextension/dns-settings
[dns-enabled]: https://developer.apple.com/documentation/networkextension/nednssettingsmanager/isenabled
[dns-removal]: https://developer.apple.com/documentation/networkextension/nednssettingsmanager/removefrompreferences(completionhandler:)
[dns-video]: https://developer.apple.com/videos/play/wwdc2020/10047/
[dns-proxy]: https://developer.apple.com/documentation/networkextension/nednsproxyprovider
[relay-paper]: https://www.apple.com/privacy/docs/iCloud_Private_Relay_Overview_Dec2021.PDF
[packet-use]: https://developer.apple.com/documentation/technotes/tn3120-expected-use-cases-for-network-extension-packet-tunnel-providers
[packet-flow]: https://developer.apple.com/documentation/networkextension/nepackettunnelprovider/packetflow
[vpn-demand]: https://developer.apple.com/documentation/networkextension/nevpnmanager/ondemandrules
[vpn-security]: https://support.apple.com/guide/security/vpn-security-sec802e8ab55/web
[vpn-connection]: https://developer.apple.com/documentation/networkextension/nevpnconnection
[vpn-invalid]: https://developer.apple.com/documentation/networkextension/nevpnstatus/invalid
[tunnel-manager]: https://developer.apple.com/documentation/networkextension/netunnelprovidermanager
[settings-removal]: https://support.apple.com/en-gb/102281
[review-vpn]: https://developer.apple.com/app-store/review/guidelines/#vpn-apps
[review-privacy]: https://developer.apple.com/app-store/review/guidelines/#privacy
[deployment-filtering]: https://support.apple.com/guide/deployment/filter-content-dep1129ff8d2/web
[safari-create]: https://developer.apple.com/documentation/safariservices/creating-a-content-blocker
[safari-enabled]: https://developer.apple.com/documentation/safariservices/sfcontentblockerstate/isenabled
[safari-view]: https://developer.apple.com/documentation/safariservices/sfsafariviewcontroller
[safari-user]: https://support.apple.com/en-us/105082
[safari-sites]: https://support.apple.com/en-us/118392
[wk-rules]: https://developer.apple.com/documentation/webkit/wkcontentrulelist
[wk-controller]: https://developer.apple.com/documentation/webkit/wkusercontentcontroller
[shield-domains]: https://developer.apple.com/documentation/managedsettings/shieldsettings/webdomains-swift.property
[shield-categories]: https://developer.apple.com/documentation/managedsettings/shieldsettings/webdomaincategories-swift.property
[blocked-filter]: https://developer.apple.com/documentation/managedsettings/webcontentsettings/blockedbyfilter-swift.property
[auto]: https://developer.apple.com/documentation/managedsettings/webcontentsettings/filterpolicy/auto(_:except:)
[all-policy]: https://developer.apple.com/documentation/managedsettings/webcontentsettings/filterpolicy/all(except:)
[managed-store]: https://developer.apple.com/documentation/managedsettings/managedsettingsstore
[safari-settings]: https://developer.apple.com/documentation/managedsettings/safarisettings
[deny-removal]: https://developer.apple.com/documentation/managedsettings/applicationsettings/denyappremoval-swift.property
[passcode]: https://developer.apple.com/documentation/managedsettings/passcodesettings/lockpasscode-swift.property
[account]: https://developer.apple.com/documentation/managedsettings/accountsettings/lockaccounts-swift.property
[cellular]: https://developer.apple.com/documentation/managedsettings/cellularsettings
[store-active]: https://developer.apple.com/documentation/managedsettings/managedsettingsstore/isactive
[store-list]: https://developer.apple.com/documentation/managedsettings/managedsettingsstore/stores
[store-refresh]: https://developer.apple.com/documentation/managedsettings/managedsettingsstore/refresh(_:)-4v4xe
[age-range]: https://developer.apple.com/documentation/declaredagerange
[ios27]: https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes
[safari27]: https://developer.apple.com/documentation/safari-release-notes/safari-27-release-notes
[webkit26]: https://developer.apple.com/videos/play/wwdc2026/204/
[webextensions26]: https://developer.apple.com/videos/play/wwdc2026/216/
[capacity]: ../../probes/filter-capacity/RESULTS.md
[adr1]: ../adr/0001-app-applied-restrictions-as-v1-bypass-resistance.md
[adr5]: ../adr/0005-what-v1-repairs-and-what-it-accepts.md
[adr6]: ../adr/0006-web-targets-block-by-filter-not-by-shield.md
