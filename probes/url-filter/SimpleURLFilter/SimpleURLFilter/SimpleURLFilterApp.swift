/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The main entry point and scene configuration for the app.
*/

import SwiftUI

//  The app creates a ConfigurationModel, holds it as a property, and provides it to the Environment for use by the ContentView and ConfigurationView.
@main
struct SimpleURLFilterApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var configurationModel: ConfigurationModel
    @State private var viewModel: ContentViewModel

    init() {
        let configurationModel = ConfigurationModel()
        self.configurationModel = configurationModel

        viewModel = ContentViewModel(configurationModel: configurationModel)
    }

    @ViewBuilder
    func content() -> some View {
        ContentView()
            .environment(viewModel)
    }

    // Create a single windowed app on macOS, and on other platforms use a WindowGroup.
    // This allows the Mac app to behave as a standard one-window app, as that suits this use case best.
    var sceneBody: some Scene {
#if os(macOS)
        Window("Network Filter", id: "main") {
            content()
        }
#else
        WindowGroup {
            content()
        }
#endif
    }

    var body: some Scene {
        sceneBody.onChange(of: scenePhase) {
            if scenePhase == .active {
                // Refresh state when the app becomes active
                viewModel.refreshConfiguration()
            }
        }
        .commands {
            CommandMenu("Actions") {
                viewModel.actionMenu()
            }
        }
        .windowResizability(.contentSize)
    }
}
