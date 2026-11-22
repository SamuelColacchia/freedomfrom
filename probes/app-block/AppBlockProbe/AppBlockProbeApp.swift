import FamilyControls
import Foundation
import ManagedSettings
import SwiftUI

// Launched with `block <bundle-id>[,<bundle-id>...]`, the probe writes those
// bundle identifiers to its one store's `application.blockedApplications`,
// prints one JSON line of what it wrote and read back, and exits. `release`
// clears the store and `status` only reads it. A plain launch changes nothing:
// it shows authorization and its one button asks for it.

enum Probe {
    static var store: ManagedSettingsStore { ManagedSettingsStore(named: .init("appBlockProbe")) }

    static func authorization() -> String {
        let status = AuthorizationCenter.shared.authorizationStatus
        switch status {
        case .approved: return "approved"
        case .denied: return "denied"
        case .notDetermined: return "notDetermined"
        default: return String(describing: status)
        }
    }

    static func readback() -> [String] {
        (store.application.blockedApplications ?? []).compactMap(\.bundleIdentifier).sorted()
    }

    /// A cold launch reads `notDetermined` before the real status arrives
    /// (#54), so nothing is written until it changes or five seconds pass.
    @MainActor
    static func settledAuthorization() async -> Int {
        let start = Date()
        while AuthorizationCenter.shared.authorizationStatus == .notDetermined,
              Date().timeIntervalSince(start) < 5 {
            try? await Task.sleep(for: .milliseconds(50))
        }
        return Int(Date().timeIntervalSince(start) * 1000)
    }

    static func emit(_ object: [String: Any]) {
        var line = object
        line["at"] = ISO8601DateFormatter().string(from: Date())
        line["authorization"] = authorization()
        line["readback"] = readback()
        let data = (try? JSONSerialization.data(withJSONObject: line, options: [.sortedKeys])) ?? Data()
        FileHandle.standardOutput.write(data + Data("\n".utf8))
    }
}

@main
struct AppBlockProbeApp: App {
    init() {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let verb = args.first, ["block", "release", "status"].contains(verb) else { return }
        let ids = (args.dropFirst().first ?? "").split(separator: ",").map(String.init)
        Task { @MainActor in
            let settledMs = await Probe.settledAuthorization()
            guard Probe.authorization() == "approved" || verb == "status" else {
                Probe.emit(["error": "not authorized, nothing written", "verb": verb, "authorizationSettledMs": settledMs])
                exit(1)
            }
            switch verb {
            case "block":
                Probe.store.application.blockedApplications = Set(ids.map { Application(bundleIdentifier: $0) })
            case "release":
                Probe.store.application.blockedApplications = nil
            default:
                break
            }
            Probe.emit(["verb": verb, "requested": ids, "authorizationSettledMs": settledMs])
            exit(0)
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
                Button("Authorize App Block Probe") {
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
            Section("Blocked by bundle identifier") {
                ForEach(Probe.readback(), id: \.self) { Text($0) }
            }
        }
    }
}
