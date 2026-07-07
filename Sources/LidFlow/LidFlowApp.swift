import SwiftUI
import AppKit

@main
struct LidFlowApp: App {
    @StateObject private var appState = AppStateManager()

    var body: some Scene {
        // Menu bar extra
        MenuBarExtra {
            MenuPopover()
                .environmentObject(appState.protectionManager)
                .environmentObject(appState.appDetector)
                .environmentObject(appState.idleDetector)
                .environmentObject(appState)
        } label: {
            Label {
                Text("LidFlow")
            } icon: {
                Image(systemName: appState.currentState.menuBarIconName)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(menuBarColor)
            }
        }
        .menuBarExtraStyle(.window)

        // Hidden settings scene (accessed via main window button)
        Settings {
            SettingsView()
                .environmentObject(appState.appDetector)
                .environmentObject(appState.protectionManager)
                .environmentObject(appState.idleDetector)
        }
    }

    private var menuBarColor: Color {
        switch appState.currentState {
        case .idle: return .green
        case .protecting: return .blue
        case .countdown: return .yellow
        case .overheated: return .red
        case .lowBattery: return .orange
        }
    }
}
