import Foundation
import AppKit
import Combine

/// Monitors running applications (GUI) and processes (CLI) to detect
/// when target tools are active.
@MainActor
final class AppDetector: ObservableObject {
    @Published var targetApps: [TargetApp] = TargetApp.defaultApps()
    @Published var isAnyTargetAppRunning: Bool = false
    @Published var runningTargetAppNames: [String] = []

    private var pollingTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []

    init() {
        setupWorkspaceObservers()
        startPolling()
        checkRunningApps()
    }

    deinit {
        pollingTimer?.invalidate()
        for observer in workspaceObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Workspace Observers (real-time, GUI only)

    private func setupWorkspaceObservers() {
        let nc = NSWorkspace.shared.notificationCenter

        let launchObserver = nc.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.checkRunningApps() }
        }

        let terminateObserver = nc.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.checkRunningApps() }
        }

        let activateObserver = nc.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.checkRunningApps() }
        }

        workspaceObservers = [launchObserver, terminateObserver, activateObserver]
    }

    // MARK: - Polling (GUI + CLI)

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
            switch app.kind {
            case .gui:
                if let bundleId = app.bundleIdentifier {
                    isRunning = runningBundleIds.contains(bundleId) || runningNames.contains(app.name)
                } else {
                    isRunning = runningNames.contains(app.name)
                }
            case .cli:
                isRunning = TargetApp.isCLIProcessRunning(processNames: app.processNames)
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
                NoSleepLogger.detection.info("Targets active: \(activeNames.joined(separator: ", "))")
            } else {
                NoSleepLogger.detection.info("No targets running")
            }
        }
    }

    // MARK: - App Management

    func toggleApp(_ app: TargetApp) {
        guard let index = targetApps.firstIndex(where: { $0.id == app.id }) else { return }
        targetApps[index].isEnabled.toggle()
    }

    func addApp(name: String, bundleIdentifier: String? = nil, kind: TargetKind = .gui, processNames: [String] = []) {
        let installed: Bool
        switch kind {
        case .gui:
            installed = TargetApp.isAppInstalled(name: name, kind: .gui)
        case .cli:
            installed = TargetApp.isCLIInstalled(processNames: processNames)
        }
        let newApp = TargetApp(
            name: name,
            bundleIdentifier: bundleIdentifier,
            kind: kind,
            processNames: processNames,
            isEnabled: true,
            isInstalled: installed
        )
        targetApps.append(newApp)
    }

    func removeApp(_ app: TargetApp) {
        targetApps.removeAll { $0.id == app.id }
    }

    func refreshInstallationStatus() {
        for index in targetApps.indices {
            switch targetApps[index].kind {
            case .gui:
                targetApps[index].isInstalled = TargetApp.isAppInstalled(
                    name: targetApps[index].name, kind: .gui
                )
            case .cli:
                targetApps[index].isInstalled = TargetApp.isCLIInstalled(
                    processNames: targetApps[index].processNames
                )
            }
        }
    }
}
