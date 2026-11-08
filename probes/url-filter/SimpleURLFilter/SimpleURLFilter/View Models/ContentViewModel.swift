/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The view logic and display-centric information used by the app's views.
*/

import SwiftUI
import OSLog

extension ContentViewModel {
    static let activityStateClearTimeInterval: TimeInterval = 3
}

@MainActor
@Observable
class ContentViewModel {

    let configurationModel: ConfigurationModel
    var editorPresented = false
    var presentErrorAlert = false
    var errorDetails: ErrorDetails?
    var activityState = ActivityState.idle
    var activityStateTimer = Timer.publish(every: ContentViewModel.activityStateClearTimeInterval, on: .main, in: .common).autoconnect()
    private let log = Logger.createLogger(for: ContentViewModel.self)

    init(configurationModel: ConfigurationModel) {
        self.configurationModel = configurationModel
    }

    @ViewBuilder
    func actionMenu() -> some View {
        Button("Reload Configuration", systemImage: "arrow.trianglehead.2.clockwise.rotate.90.circle") {
            self.refreshConfiguration()
        }
        .keyboardShortcut("R")
        .disabled(editorPresented)

        Button("Reset PIR Cache", systemImage: "arrow.counterclockwise.circle") {
            self.resetPIRCache()
        }
        .disabled(editorPresented)

        Button("Refresh PIR Parameters", systemImage: "arrow.up.arrow.down.circle") {
            self.refreshPIRParameters()
        }
        .disabled(editorPresented)

        Button("Remove Filter", systemImage: "xmark.shield.fill", role: .destructive) {
            self.removeCurrentConfiguration()
        }
        .keyboardShortcut(".")
        .disabled(editorPresented)
    }

    @ViewBuilder
    func createConfigurationView() -> some View {
        // Create an explicit binding from the configurationModel.
        @Bindable var configurationModel = configurationModel
        ConfigurationView(configuration: $configurationModel.currentConfiguration)
            .environment(configurationModel)
    }
    
    func currentConfiguration(enable: Bool) {
        Task {
            do {
                activityState = enable ? .configurationEnableStart : .configurationDisableStart
                try await configurationModel.currentConfiguration(enable: enable)
                activityState = enable ? .configurationEnableEnd : .configurationDisableEnd
            } catch {
                log.error("Failed to \(enable ? "enable" : "disable") current configuration: \(error)")
                activityState = enable ? .configurationEnableFailed : .configurationDisableFailed
                presentErrorAlert = true
                errorDetails = ErrorDetails(
                    title: "Unable to \(enable ? "Enable" : "Disable") Configuration",
                    message: error.localizedDescription)
            }
        }
    }

    func refreshConfiguration() {
        Task {
            do {
                activityState = .configurationLoadStart
                try await configurationModel.refreshFromSystem()
                activityState = .configurationLoadEnd
            } catch {
                activityState = .configurationLoadFailed
                // Show an alert with the error.
                presentErrorAlert = true
                errorDetails = ErrorDetails(title: "Unable to Load Configuration", message: error.localizedDescription)
            }
        }
    }

    func resetPIRCache() {
        Task {
            do {
                activityState = .pirCacheResetStart
                try await configurationModel.resetPIRCache()
                activityState = .pirCacheResetEnd
            } catch {
                log.error("Failed to reset PIR cache: \(error)")
                activityState = .pirCacheResetFailed
                // Show an alert with the error.
                presentErrorAlert = true
                errorDetails = ErrorDetails(title: "Unable to Reset PIR Cache", message: error.localizedDescription)
            }
        }
    }

    func refreshPIRParameters() {
        Task {
            do {
                activityState = .pirParametersRefreshStart
                try await configurationModel.refreshPIRParameters()
                activityState = .pirParametersRefreshEnd
            } catch {
                log.error("Failed to refresh PIR parameters: \(error)")
                activityState = .pirParametersRefreshFailed
                // Show an alert with the error.
                presentErrorAlert = true
                errorDetails = ErrorDetails(title: "Unable to Refresh PIR Parameters", message: error.localizedDescription)
            }
        }
    }

    func removeCurrentConfiguration() {
        Task {
            do {
                activityState = .configurationRemoveStart
                try await configurationModel.removeCurrentConfiguration()
                activityState = .configurationRemoveEnd
            } catch {
                log.error("Failed to remove configuration: \(error)")
                activityState = .configurationRemoveFailed
                // Show an alert with the error.
                presentErrorAlert = true
                errorDetails = ErrorDetails(title: "Unable to Remove Configuration", message: error.localizedDescription)
            }
        }
    }

    var indeterminateStatus: Bool {
        switch configurationModel.filterStatus {
        case .starting, .stopping:
            return true
        default:
            return false
        }
    }

    enum ActivationButtonAction {
        case enableFilter
        case disableFilter
    }

    var statusMessage: String {
        switch configurationModel.filterStatus {
        case .unknown:
            return activityState.message
        case .disabled:
            return "Disabled"
        case .invalid:
            return "Not Configured"
        case .stopped:
            return "Stopped"
        case .starting:
            return "Starting"
        case .running:
            return "Running"
        case .stopping:
            return "Stopping"
        }
    }

    var activityMessage: String {
        return activityState.message
    }

    var errorMessage: String? {
        return configurationModel.filterStatus.errorMessage
    }

    var filterActivationButtonState: (enabled: Bool, title: String, action: ActivationButtonAction) {
        let enableFilter = !(configurationModel.currentConfiguration?.enabled ?? false)
        let title = enableFilter ? "Enable" : "Disable"
        let action: ActivationButtonAction = enableFilter ? .enableFilter : .disableFilter
        var buttonEnabled: Bool
        switch configurationModel.filterStatus {
        case .unknown, .invalid:
            buttonEnabled = false
        case .disabled, .stopped, .starting, .running, .stopping:
            buttonEnabled = true
        }
        return (enabled: buttonEnabled, title: title, action: action)
    }

    var networkImageName: String {
        switch configurationModel.filterStatus {
        case .running:
            return "network.badge.shield.half.filled"
        case .invalid:
            return "circle.badge.questionmark"
        case .stopped:
            return "network.slash"
        default:
            return "network"
        }
    }

    var networkImageDisabled: Bool {
        configurationModel.filterStatus == .disabled
    }
}

extension ActivityState {
    var message: String {
        switch self {
        case .idle:
            return ""
        case .configurationLoadStart:
            return "Loading configruation…"
        case .configurationLoadEnd:
            return "Configuration loaded"
        case .configurationLoadEmpty:
            return "No configuration"
        case .configurationLoadFailed:
            return "Failed to load configuration"
        case .configurationSaveStart:
            return "Applying configruation…"
        case .configurationSaveEnd:
            return "Configuration applied"
        case .configurationSaveFailed:
            return "Failed to apply configuration"
        case .configurationRemoveStart:
            return "Removing configruation…"
        case .configurationRemoveEnd:
            return "Configuration removed"
        case .configurationRemoveFailed:
            return "Failed to remove configuration"
        case .configurationEnableStart:
            return "Enabling configruation…"
        case .configurationEnableEnd:
            return "Configuration enabled"
        case .configurationEnableFailed:
            return "Failed to enable configuration"
        case .configurationDisableStart:
            return "Disabling configruation…"
        case .configurationDisableEnd:
            return "Configuration Disabled"
        case .configurationDisableFailed:
            return "Failed to disable configuration"
        case .pirCacheResetStart:
            return "Reseting PIR Cache…"
        case .pirCacheResetEnd:
            return "PIR Cache reset"
        case .pirCacheResetFailed:
            return "Failed to reset PIR Cache"
        case .pirParametersRefreshStart:
            return "Refreshing PIR Parameters…"
        case .pirParametersRefreshEnd:
            return "PIR Parameters refreshed"
        case .pirParametersRefreshFailed:
            return "Failed to refresh PIR Parameters"
        }
    }
}
