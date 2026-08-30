// swift-tools-version:6.2
//
// Tools version 6.2 is required, not preferred: naming `.iOS(.v26)` under 6.0
// fails with `'v26' is unavailable` (ADR 0010).

import PackageDescription

let package = Package(
    name: "FreedomFromKit",
    platforms: [.iOS(.v26), .macOS(.v13)],
    products: [
        .library(name: "FreedomFromKit", targets: ["FreedomFromKit"]),
        .library(name: "FreedomFromPlatform", targets: ["FreedomFromPlatform"]),
    ],
    targets: [
        // Foundation only. Every Screen Time type is either absent from the
        // macOS module or `@available(macOS, unavailable)`, so importing one
        // here would end the headless test loop (ADR 0009).
        .target(name: "FreedomFromKit"),

        // The thin layer that touches Apple frameworks and holds no logic:
        // the Keychain record store and the logging contract. Not headlessly
        // tested; its failure mode is hardware check S1.
        .target(name: "FreedomFromPlatform", dependencies: ["FreedomFromKit"]),

        .testTarget(name: "FreedomFromKitTests", dependencies: ["FreedomFromKit"]),
    ]
)
