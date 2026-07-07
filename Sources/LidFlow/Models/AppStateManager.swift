import Foundation
import SwiftUI
import AppKit
import Combine

/// Central state manager that coordinates between AppDetector, IdleDetector,
/// and ProtectionManager. This is the "brain" of LidFlow.
@MainActor
final class AppStateManager: ObservableObject {
    @Published var currentState: LidFlowState = .idle
    @Published var isManualMode: Bool = false

    let protectionManager = ProtectionManager()
    let appDetector = AppDetector()
    let idleDetector = IdleDetector()

    private var cancellables = Set<AnyCancellable>()
    private var mainWindowController: NSWindowController?

    init() {
        setupBindings()
        setupKeyboardShortcuts()
    }

    // MARK: - Bindings

    private func setupBindings() {
        // When target app state changes → manage protection
        appDetector.$isAnyTargetAppRunning
            .combineLatest(appDetector.$runningTargetAppNames)
            .receive(on: RunLoop.main)
            .sink { [weak self] isRunning, names in
                guard let self else { return }
                self.handleTargetAppChange(isRunning: isRunning, names: names)
            }
            .store(in: &cancellables)

        // When idle detector signals deactivation
        idleDetector.$shouldDeactivateProtection
            .filter { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleIdleTimeout()
            }
            .store(in: &cancellables)

        // Update state when protection changes
        protectionManager.$activeLayers
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateState()
            }
            .store(in: &cancellables)

        // Update state from idle detector countdown
        idleDetector.$isCountdownActive
            .combineLatest(idleDetector.$remainingSeconds)
            .receive(on: RunLoop.main)
            .sink { [weak self] isCountdown, remaining in
                self?.updateState()
            }
            .store(in: &cancellables)
    }

    // MARK: - State Transitions

    private func handleTargetAppChange(isRunning: Bool, names: [String]) {
        guard !isManualMode else { return }

        if isRunning {
            // Target apps detected → cancel countdown, activate protection
            idleDetector.cancelCountdown()
            if !protectionManager.isProtectionActive {
                protectionManager.activateProtection()
                LidFlowLogger.general.info("Protection activated — target apps: \(names.joined(separator: ", "))")
            }
        } else {
            // All target apps exited → start countdown (if protection is active)
            if protectionManager.isProtectionActive {
                idleDetector.startCountdown()
                LidFlowLogger.general.info("All target apps exited — starting idle countdown")
            }
        }
        updateState()
    }

    private func handleIdleTimeout() {
        protectionManager.deactivateProtection()
        LidFlowLogger.general.info("Idle timeout reached — protection deactivated, normal sleep restored")
        updateState()
    }

    private func updateState() {
        if idleDetector.isCountdownActive {
            currentState = .countdown(remainingSeconds: idleDetector.remainingSeconds)
        } else if protectionManager.isProtectionActive {
            currentState = .protecting
        } else {
            currentState = .idle
        }
    }

    // MARK: - Manual Control

    func toggleManualProtection() {
        isManualMode = true

        if protectionManager.isProtectionActive {
            protectionManager.deactivateProtection()
            idleDetector.cancelCountdown()
        } else {
            protectionManager.activateProtection()
        }
        updateState()

        // Re-enable auto mode after 5 minutes
        Task {
            try? await Task.sleep(for: .seconds(300))
            self.isManualMode = false
        }
    }

    // MARK: - Main Window

    func showMainWindow() {
        if let controller = mainWindowController,
           let window = controller.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = Constants.appName
        window.center()
        window.setFrameAutosaveName("LidFlowMainWindow")

        let settingsView = MainWindow()
            .environmentObject(protectionManager)
            .environmentObject(appDetector)
            .environmentObject(idleDetector)
            .environmentObject(self)

        window.contentView = NSHostingView(rootView: settingsView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        mainWindowController = NSWindowController(window: window)
    }

    // MARK: - Keyboard Shortcuts

    private func setupKeyboardShortcuts() {
        // ⌃⌥⌘L — Toggle protection
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let requiredFlags: NSEvent.ModifierFlags = [.control, .option, .command]

            guard flags == requiredFlags else { return }

            Task { @MainActor in
                switch event.keyCode {
                case 37: // 'L' key
                    self.toggleManualProtection()
                case 3:  // 'F' key
                    self.showMainWindow()
                default:
                    break
                }
            }
        }
    }

    // MARK: - App Lifecycle

    func quit() {
        protectionManager.deactivateProtection()
        NSApp.terminate(nil)
    }
}
