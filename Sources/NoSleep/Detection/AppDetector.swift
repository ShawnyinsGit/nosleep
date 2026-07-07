import Foundation
import AppKit
import Combine

/// Monitors running applications and detects when target apps are active.
/// Uses NSWorkspace notifications for real-time detection plus polling as backup.
@MainActor
final class AppDetector: ObservableObject {
    @Published var targetApps: [TargetApp] = TargetApp.defaultApps()
    @Published var isAnyTargetAppRunning: Bool = false
    @Published var runningTargetAppNames: [String] = []

    private var pollingTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupWorkspaceObservers()
        startPolling()
        // Initial check
        checkRunningApps()
    }

    deinit {
        pollingTimer?.invalidate()
        for observer in workspaceObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Workspace Observers (real-time)

    private func setupWorkspaceObservers() {
        let nc = NSWorkspace.shared.notificationCenter

        // App launched
        let launchObserver = nc.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in self?.checkRunningApps() }
        }

        // App terminated
        let terminateObserver = nc.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in self?.checkRunningApps() }
        }

        // App activated (brought to foreground)
        let activateObserver = nc.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in self?.checkRunningApps() }
        }

        // Store all observers for cleanup
        workspaceObservers = [launchObserver, terminateObserver, activateObserver]
    }

    // MARK: - Polling (backup)

    private func startPolling() {
        pollingTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.detectionPollInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkRunningApps()
            }
        }
    }

    // MARK: - Detection Logic

    private func checkRunningApps() {
        let runningApps = NSWorkspace.shared.runningApplications
        let runningNames = Set(runningApps.compactMap { $0.localizedName })
        let runningBundleIds = Set(runningApps.compactMap { $0.bundleIdentifier })

        var activeNames: [String] = []

        for index in targetApps.indices {
            let app = targetApps[index]
            guard app.isEnabled && app.isInstalled else { continue }

            let isRunning: Bool
            if let bundleId = app.bundleIdentifier {
                isRunning = runningBundleIds.contains(bundleId) || runningNames.contains(app.name)
            } else {
                isRunning = runningNames.contains(app.name)
            }

            if isRunning {
                activeNames.append(app.name)
            }
        }

        let wasRunning = isAnyTargetAppRunning
        runningTargetAppNames = activeNames
        isAnyTargetAppRunning = !activeNames.isEmpty

        if isAnyTargetAppRunning != wasRunning {
            if isAnyTargetAppRunning {
                NoSleepLogger.detection.info("Target apps detected: \(activeNames.joined(separator: ", "))")
            } else {
                NoSleepLogger.detection.info("No target apps running")
            }
        }
    }

    // MARK: - App Management

    func toggleApp(_ app: TargetApp) {
        guard let index = targetApps.firstIndex(where: { $0.id == app.id }) else { return }
        targetApps[index].isEnabled.toggle()
    }

    func addApp(name: String, bundleIdentifier: String? = nil) {
        let newApp = TargetApp(
            name: name,
            bundleIdentifier: bundleIdentifier,
            isEnabled: true,
            isInstalled: TargetApp.isAppInstalled(name: name)
        )
        targetApps.append(newApp)
    }

    func removeApp(_ app: TargetApp) {
        targetApps.removeAll { $0.id == app.id }
    }

    /// Refresh installation status of all target apps
    func refreshInstallationStatus() {
        for index in targetApps.indices {
            targetApps[index].isInstalled = TargetApp.isAppInstalled(name: targetApps[index].name)
        }
    }
}
