import FamilyControls
import Foundation
import ManagedSettings
import SwiftUI

// Launched with `apply <scenario>`, the probe writes that scenario to its two
// stores, prints one JSON line of what it wrote and read back, and exits. A
// plain launch changes nothing: it shows authorization and the stores' state,
// and its one button asks for authorization. Nothing reapplies on launch, so a
// restart check observes what the system kept rather than what the app redid.

struct StoreSpec: Decodable {
    let policy: String
    let domains: [String]?
    let except: [String]?
}

enum StoreAction: Decodable {
    case keep
    case set(StoreSpec)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let word = try? container.decode(String.self), word == "keep" {
            self = .keep
        } else {
            self = .set(try container.decode(StoreSpec.self))
        }
    }
}

struct Scenario: Decodable {
    let id: String
    let stores: [String: StoreAction]
}

struct Manifest: Decodable {
    let version: Int
    let stores: [String]
    let scenarios: [Scenario]

    static func bundled() throws -> Manifest {
        guard let url = Bundle.main.url(forResource: "scenarios", withExtension: "json") else {
            throw ProbeError.noManifest
        }
        return try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url))
    }
}

enum ProbeError: Error, CustomStringConvertible {
    case noManifest
    case unknownScenario(String)
    case unknownPolicy(String)
    case foreignStore(String)

    var description: String {
        switch self {
        case .noManifest: "scenarios.json is not in the bundle"
        case .unknownScenario(let id): "no scenario named \(id)"
        case .unknownPolicy(let p): "unknown policy \(p)"
        case .foreignStore(let s): "\(s) is not a probe store"
        }
    }
}

enum Probe {
    static func policy(_ spec: StoreSpec) throws -> WebContentSettings.FilterPolicy? {
        let domains = Set((spec.domains ?? []).map { WebDomain(domain: $0) })
        let except = Set((spec.except ?? []).map { WebDomain(domain: $0) })
        switch spec.policy {
        case "none": return nil
        case "specific": return .specific(domains)
        case "auto": return .auto(domains, except: except)
        default: throw ProbeError.unknownPolicy(spec.policy)
        }
    }

    static func describe(_ policy: WebContentSettings.FilterPolicy?) -> [String: Any] {
        func hosts(_ set: Set<WebDomain>) -> [String] { set.compactMap(\.domain).sorted() }
        switch policy {
        case nil: return ["policy": "unset"]
        case .none?: return ["policy": "none"]
        case .specific(let d)?: return ["policy": "specific", "count": d.count, "domains": hosts(d)]
        case .auto(let d, let e)?:
            return ["policy": "auto", "count": d.count, "exceptCount": e.count,
                    "domains": hosts(d), "except": hosts(e)]
        case .all(let e)?: return ["policy": "all", "exceptCount": e.count, "except": hosts(e)]
        @unknown default: return ["policy": "unknown"]
        }
    }

    static func authorization() -> String {
        let status = AuthorizationCenter.shared.authorizationStatus
        switch status {
        case .approved: return "approved"
        case .denied: return "denied"
        case .notDetermined: return "notDetermined"
        default: return String(describing: status)
        }
    }

    static func readback(_ names: [String]) -> [String: Any] {
        Dictionary(uniqueKeysWithValues: names.map { name in
            (name, describe(ManagedSettingsStore(named: .init(name)).webContent.blockedByFilter))
        })
    }

    static func apply(_ id: String) throws -> [String: Any] {
        let manifest = try Manifest.bundled()
        guard let scenario = manifest.scenarios.first(where: { $0.id == id }) else {
            throw ProbeError.unknownScenario(id)
        }
        var written: [String: Any] = [:]
        for (name, action) in scenario.stores.sorted(by: { $0.key < $1.key }) {
            guard manifest.stores.contains(name) else { throw ProbeError.foreignStore(name) }
            guard case .set(let spec) = action else { written[name] = "kept"; continue }
            ManagedSettingsStore(named: .init(name)).webContent.blockedByFilter = try policy(spec)
            written[name] = spec.policy
        }
        return ["scenario": id, "written": written]
    }

    static func emit(_ object: [String: Any]) {
        var line = object
        line["at"] = ISO8601DateFormatter().string(from: Date())
        line["authorization"] = authorization()
        let data = (try? JSONSerialization.data(withJSONObject: line, options: [.sortedKeys])) ?? Data()
        FileHandle.standardOutput.write(data + Data("\n".utf8))
    }
}

@main
struct FilterProbeApp: App {
    init() {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let verb = args.first, verb == "apply" || verb == "status" else { return }
        let names = (try? Manifest.bundled().stores) ?? []
        do {
            var result: [String: Any] = verb == "apply" ? try Probe.apply(args.dropFirst().first ?? "") : [:]
            result["readback"] = Probe.readback(names)
            Probe.emit(result)
            exit(0)
        } catch {
            Probe.emit(["error": "\(error)", "readback": Probe.readback(names)])
            exit(1)
        }
    }

    var body: some Scene {
        WindowGroup { ProbeView() }
    }
}

struct ProbeView: View {
    @State private var status = Probe.authorization()
    @State private var failure: String?

    var body: some View {
        List {
            Section("Authorization") {
                Text(status).accessibilityIdentifier("authorization")
                Button("Authorize Filter Probe") {
                    Task {
                        do {
                            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                        } catch {
                            failure = "\(error)"
                        }
                        status = Probe.authorization()
                    }
                }
                if let failure { Text(failure).foregroundStyle(.red) }
            }
            Section("Stores") {
                ForEach(((try? Manifest.bundled().stores) ?? []), id: \.self) { name in
                    let d = Probe.describe(ManagedSettingsStore(named: .init(name)).webContent.blockedByFilter)
                    Text(verbatim: "\(name): \(d["policy"] ?? "?") \(d["count"].map { "\($0)" } ?? "")")
                }
            }
        }
    }
}
