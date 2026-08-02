# Declarative Xcode project generation for a Screen Time app

## Recommendation
Use **XcodeGen**.

Why XcodeGen wins here:
- It already models **app-extension** targets, per-target entitlements, and App Group entitlements in plain YAML. The spec explicitly says target entitlements generate `.entitlements` files and set `CODE_SIGN_ENTITLEMENTS`, and target dependencies can embed app targets' extensions.
- It is the lightest tool that still gives us a text-file source of truth. For a solo repo, Tuist's extra layers (`Workspace.swift`, dependency graph validation, caching, account/fullHandle concepts) are real overhead.
- Apple says Family Controls should use **automatic signing**, and XcodeGen can emit the ordinary Xcode settings (`CODE_SIGN_STYLE: Automatic`, `DEVELOPMENT_TEAM`, entitlements files) that `xcodebuild -allowProvisioningUpdates` expects.
- XcodeGen is active: release **2.46.0** shipped **2026-07-16**. I could not confirm an explicit Xcode 26 project-format release note, but the repo is clearly maintained.

## Verdict by option

| Option | Verdict | Why |
|---|---|---|
| XcodeGen | **Recommended** | YAML is enough for app/app-extension targets, per-target entitlements, App Groups, and signing; installable without Homebrew. |
| Tuist | Viable, but heavier | Yes, it can do app extensions and per-target entitlements; but it drags in workspaces, dependency-graph concepts, and caching that this repo does not need yet. |
| SPM only | **No** | SwiftPM packages only define regular/executable/test/system/binary/plugin/macro targets; no iOS app project with embedded app extensions. |
| Committed `.pbxproj` + programmatic edits | Technically viable, not preferred | `xcodeproj` and `pbxproj` can mutate projects, but you are back to imperative surgery on a giant file and Xcode can rewrite it on open/save. |

## What the sources say

- XcodeGen README: generates projects from `project.yml`, recommends removing `.xcodeproj` from git, and installs via Mint / Make / SwiftPM.
  - [README](https://github.com/yonaskolb/XcodeGen/blob/8445e778451c7e44237b90281bde622d764b0084/README.md#L23-L35)
  - [Install / usage](https://github.com/yonaskolb/XcodeGen/blob/8445e778451c7e44237b90281bde622d764b0084/README.md#L77-L146)
- XcodeGen spec: target entitlements generate `.entitlements` files and set `CODE_SIGN_ENTITLEMENTS`; dependency embedding is supported.
  - [Target + entitlements](https://github.com/yonaskolb/XcodeGen/blob/8445e778451c7e44237b90281bde622d764b0084/Sources/ProjectSpec/Target.swift#L36-L46)
  - [Dependencies (`embed`)](https://github.com/yonaskolb/XcodeGen/blob/8445e778451c7e44237b90281bde622d764b0084/Docs/ProjectSpec.md#L599-L615)
- XcodeGen real-world config with app groups + extension signing:
  - [yojam project.yml](https://github.com/fluffypony/yojam/blob/ba2b8db1e1e7f9703101e65324f0abfc28159151/project.yml#L121-L160)
- Tuist docs: manifests are Swift, generated projects are normally **not** committed, and Tuist adds caching / dependency-graph concepts.
  - [Manifests + generated-projects guidance](https://github.com/tuist/tuist/blob/9c8784a222522d7cf1e5abc8a70e270109267e39/server/priv/docs/en/guides/features/projects/manifests.md#L10-L17)
  - [Multi-project + don’t commit generated Xcode projects](https://github.com/tuist/tuist/blob/9c8784a222522d7cf1e5abc8a70e270109267e39/server/priv/docs/en/guides/features/projects/manifests.md#L41-L65)
  - [Dependencies / cache tradeoffs](https://github.com/tuist/tuist/blob/9c8784a222522d7cf1e5abc8a70e270109267e39/server/priv/docs/en/guides/features/projects/dependencies.md#L13-L31)
  - [Tuist README install](https://github.com/tuist/tuist/blob/9c8784a222522d7cf1e5abc8a70e270109267e39/README.md#L41-L47)
- Tuist can do app extensions and entitlements:
  - [Target.entitlements API](https://github.com/tuist/tuist/blob/9c8784a222522d7cf1e5abc8a70e270109267e39/cli/Sources/ProjectDescription/Target.swift#L38-L68)
  - [Entitlements enum](https://github.com/tuist/tuist/blob/9c8784a222522d7cf1e5abc8a70e270109267e39/cli/Sources/ProjectDescription/Entitlements.swift#L3-L63)
  - [App extension example](https://github.com/tuist/tuist/blob/9c8784a222522d7cf1e5abc8a70e270109267e39/examples/xcode/generated_ios_app_with_extensions/Project.swift#L52-L121)
  - [App groups in a real Tuist project](https://github.com/marriagav/taskchamp/blob/9c6b95a8c905855b0e39881c3c922769560c2705/Project.swift#L38-L44)
- SwiftPM target types are only regular / executable / test / system / binary / plugin / macro.
  - [SwiftPM Target.swift](https://github.com/swiftlang/swift-package-manager/blob/d9ce60284dd2a2ea0f59fbe3e7c859e1111cae35/Sources/PackageDescription/Target.swift#L1-L40)
  - [PackageDescription docs](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html)
- `xcodeproj` and `pbxproj` can edit `.pbxproj` files, but they are imperative editors, not declarative generators.
  - [xcodeproj README](https://github.com/CocoaPods/Xcodeproj/blob/f427b24aec168be2faa5c43ad64fa6bf91880e13/README.md#L7-L32)
  - [pbxproj README](https://github.com/kronenthaler/mod-pbxproj/blob/fcc8ed889845ba094b2b002c9c2a3147fb849374/readme.rst#L30-L55)

## Git behavior

- **XcodeGen**: commit `project.yml`, `*.entitlements`, and ignore the generated `.xcodeproj`.
- **Tuist**: commit `Project.swift` / `Workspace.swift`, ignore the generated `.xcodeproj`.
- **SPM only**: commit `Package.swift` (and usually `Package.resolved` if you use dependencies).
- **Committed pbxproj**: commit the `.xcodeproj` / `project.pbxproj` itself.

What breaks for a human:
- With generators, manual project changes made in Xcode are ephemeral; the next regeneration overwrites them.
- With committed `.pbxproj`, Xcode and script edits both mutate the same huge file, so object-order churn and merge conflicts come back.

## Install on the Mac mini (no Homebrew)

- **XcodeGen**: `mint install yonaskolb/xcodegen`, or `swift run xcodegen`, or `make install`.
- **Tuist**: `mise x tuist@latest -- tuist init`.
- **xcodeproj**: `gem install xcodeproj`.
- **pbxproj**: `python -m pip install pbxproj`.
- **SPM only**: already in the Apple toolchain.

## Concrete XcodeGen config

```yaml
name: FreedomFrom
options:
  deploymentTarget:
    iOS: "15.0"

targets:
  App:
    type: application
    platform: iOS
    sources: [Sources/App/**]
    info:
      path: Sources/App/Info.plist
      properties:
        CFBundleDisplayName: FreedomFrom
    entitlements:
      path: Sources/App/FreedomFrom.entitlements
      properties:
        com.apple.developer.family-controls: true
        com.apple.security.application-groups:
          - group.com.example.freedomfrom.shared
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.example.freedomfrom
        DEVELOPMENT_TEAM: TEAMID12345
        CODE_SIGN_STYLE: Automatic
    dependencies:
      - target: DeviceActivityMonitorExtension
        embed: true
      - target: ShieldConfigurationExtension
        embed: true
      - target: ShieldActionExtension
        embed: true

  DeviceActivityMonitorExtension:
    type: app-extension
    platform: iOS
    sources: [Sources/DeviceActivityMonitor/**]
    info:
      path: Sources/DeviceActivityMonitor/Info.plist
      properties:
        NSExtension:
          NSExtensionPointIdentifier: com.apple.deviceactivity.monitor-extension
          NSExtensionPrincipalClass: $(PRODUCT_MODULE_NAME).DeviceActivityMonitorExtension
    entitlements:
      path: Sources/DeviceActivityMonitor/DeviceActivityMonitor.entitlements
      properties:
        com.apple.developer.family-controls: true
        com.apple.security.application-groups:
          - group.com.example.freedomfrom.shared
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.example.freedomfrom.deviceactivitymonitor
        DEVELOPMENT_TEAM: TEAMID12345
        CODE_SIGN_STYLE: Automatic
        APPLICATION_EXTENSION_API_ONLY: YES
        SKIP_INSTALL: YES

  ShieldConfigurationExtension:
    type: app-extension
    platform: iOS
    sources: [Sources/ShieldConfiguration/**]
    info:
      path: Sources/ShieldConfiguration/Info.plist
      properties:
        NSExtension:
          NSExtensionPointIdentifier: com.apple.ManagedSettingsUI.shield-configuration-service
          NSExtensionPrincipalClass: $(PRODUCT_MODULE_NAME).ShieldConfigurationExtension
    entitlements:
      path: Sources/ShieldConfiguration/ShieldConfiguration.entitlements
      properties:
        com.apple.developer.family-controls: true
        com.apple.security.application-groups:
          - group.com.example.freedomfrom.shared
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.example.freedomfrom.shieldconfiguration
        DEVELOPMENT_TEAM: TEAMID12345
        CODE_SIGN_STYLE: Automatic
        APPLICATION_EXTENSION_API_ONLY: YES
        SKIP_INSTALL: YES

  ShieldActionExtension:
    type: app-extension
    platform: iOS
    sources: [Sources/ShieldAction/**]
    info:
      path: Sources/ShieldAction/Info.plist
      properties:
        NSExtension:
          NSExtensionPointIdentifier: com.apple.ManagedSettings.shield-action-service
          NSExtensionPrincipalClass: $(PRODUCT_MODULE_NAME).ShieldActionExtension
    entitlements:
      path: Sources/ShieldAction/ShieldAction.entitlements
      properties:
        com.apple.developer.family-controls: true
        com.apple.security.application-groups:
          - group.com.example.freedomfrom.shared
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.example.freedomfrom.shieldaction
        DEVELOPMENT_TEAM: TEAMID12345
        CODE_SIGN_STYLE: Automatic
        APPLICATION_EXTENSION_API_ONLY: YES
        SKIP_INSTALL: YES
```

## Could not confirm

- I could not confirm an explicit XcodeGen `xcode26_*` project-format release note in source. The repo is active, but its docs/repo still talk about Xcode 16 project-format knobs.
- I could not confirm any generator-specific problem with `xcodebuild -allowProvisioningUpdates`; Apple’s Family Controls docs say to use automatic signing, and the emitted Xcode project handles that normally.
