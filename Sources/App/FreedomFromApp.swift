import SwiftUI

@main
struct FreedomFromApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .preferredColorScheme(.dark)
        }
    }
}

/// The root is always the current state of the one thing: a commitment running
/// shows the countdown, none running shows the commitment you would make
/// (ADR 0007). There is no hub, no tab bar, and no settings surface.
struct RootView: View {
    @Bindable var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    /// A foreground is a return from `.background`, and nothing else.
    ///
    /// The launch transition is `.inactive` → `.active`, so keying off the
    /// previous phase would reconcile twice at launch and log everything twice
    /// in a channel that is the product's only signal (ADR 0009). Every
    /// backgrounding passes through `.background`, so this flag is exactly the
    /// question being asked.
    @State private var wasBackgrounded = false

    var body: some View {
        Group {
            if !model.hasReadRecord {
                // The launch background, held until the record says which
                // screen is true. Milliseconds, and the alternative is a flash
                // of first run in front of a running commitment.
                Quiet.background.ignoresSafeArea()
            } else {
                switch model.destination {
                case .firstRun:
                    FirstRunView(model: model)
                case .targets:
                    NavigationStack { TargetsView(model: model) }
                case .countdown:
                    NavigationStack { CountdownView(model: model) }
                case .ended:
                    EndedView(model: model)
                }
            }
        }
        .task { await model.onLaunch() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active where wasBackgrounded:
                wasBackgrounded = false
                Task { await model.onForeground() }
            case .background:
                wasBackgrounded = true
                model.persist()
            default:
                break
            }
        }
    }
}
