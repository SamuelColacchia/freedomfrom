/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The main view of the application.
*/

import SwiftUI
import OSLog

// ContentView presents the status of the network filter as well as any error messages.
// A Configure button presents the ConfigurationView, where someone can view and change the network filter configuration parameters.
// An Enable/Disable button allows for quick access to enable and disable the filter.
// Additionally, a utility menu provides an interface to interact with other aspects of the underlying NEURLFilterManager API.
// The ContentView listens for changes in the `scenePhase` and refreshes state from the underlying API when the scene indicates the app became active.
// This keeps the interface up to date and representative of the status of the filter.
// ContentView maintains an `ActivityState` which is used to give feedback on the progress and state of various activities the user can perform.
struct ContentView: View {
    @Environment(ContentViewModel.self) private var viewModel

    @ScaledMetric private var networkImageSize = 100
    @ScaledMetric private var activityMessageHeight = 30

    var body: some View {
        @Bindable var viewModel = viewModel
        
        NavigationStack {
            VStack {
                mainImageView()
                statusView()
                errorView()
                // The spacer gives a flexible space to add and remove the error presentation.
                Spacer()
                actionView()
            }
            .sheet(isPresented: $viewModel.editorPresented) {
                // Create an explicit binding from the Environment configurationModel.
                @Bindable var configurationModel = viewModel.configurationModel
                ConfigurationView(configuration: $configurationModel.currentConfiguration)
                    .environment(configurationModel)
            }
            .frame(maxWidth: 400)
#if os(iOS)
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    Menu {
                        viewModel.actionMenu()
                    } label: {
                        Image(systemName: "wrench.and.screwdriver")
                    }
                }
            }
#endif
        }
#if os(macOS)
        .frame(
            minWidth: 420, maxWidth: 420,
            minHeight: 450, maxHeight: 450)
#endif
        .alert(
            viewModel.errorDetails?.title ?? "Error",
            isPresented: $viewModel.presentErrorAlert,
            presenting: viewModel.errorDetails,
            actions: { _ in },
            message: { details in
                Text(details.message)
            }
        )
    }

    @ViewBuilder
    func mainImageView() -> some View {
        Image(systemName: viewModel.networkImageName)
            .imageScale(.large)
            .foregroundStyle(.tint)
            .disabled(viewModel.networkImageDisabled)
            // Giving this a frame helps the animations between different size symbols keep the UI steady and supports dynamic type.
            .frame(width: networkImageSize, height: networkImageSize)
            .font(.system(size: networkImageSize))
            .padding(.top, 100)
            .padding(.bottom, 20)
            // Animates when the status represents a transition.
            .symbolEffect(.pulse.byLayer, isActive: viewModel.indeterminateStatus)
            // Animate when the image is changed.
            .contentTransition(.symbolEffect(.replace))
    }

    @ViewBuilder
    func statusView() -> some View {
        Text(viewModel.statusMessage)
            .font(.largeTitle)
            .animation(.default, value: viewModel.statusMessage)
        Text(viewModel.activityMessage)
            .foregroundStyle(.secondary)
            .font(.subheadline)
            .frame(height: activityMessageHeight, alignment: .top)
            .animation(.default, value: viewModel.activityMessage)
            .onReceive(viewModel.activityStateTimer) { _ in
                // When the timer fires, cancel it (it recurs), and update the activity state to idle to remove the activity message.
                viewModel.activityStateTimer.upstream.connect().cancel()
                guard viewModel.activityState != .idle else { return }
                viewModel.activityState = ActivityState.idle
            }
            .onChange(of: viewModel.activityState) {
                // When the activity state changes, cancel the current timer and restart a timer.
                viewModel.activityStateTimer.upstream.connect().cancel()
                viewModel.activityStateTimer = Timer.publish(every:
                                                                ContentViewModel.activityStateClearTimeInterval,
                                                             on: .main,
                                                             in: .common).autoconnect()
            }
    }

    @ViewBuilder
    func errorView() -> some View {
        if viewModel.errorMessage != nil {
            // To provide a full-width text background wrap in a VStack to enable different coloring from the outer stack.
            VStack {
                Text(viewModel.errorMessage ?? "")
                    .foregroundStyle(.red)
                    .font(.subheadline)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(.default, value: viewModel.errorMessage)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.thinMaterial)
            )
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    func actionView() -> some View {
        HStack {
            Button {
                viewModel.currentConfiguration(enable: viewModel.filterActivationButtonState.action == .enableFilter)
            } label: {
                Text(viewModel.filterActivationButtonState.title)
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.filterActivationButtonState.enabled)
            .clipShape(Capsule())
            Button {
                viewModel.editorPresented = true
            } label: {
                Text("Configure")
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(Capsule())
        }
        .padding()
    }

    private let log = Logger.createLogger(for: Self.self)
}

#Preview {
    ContentView()
}
