import Foundation
import Combine

/// Manages the idle countdown after target apps exit.
/// When no target apps are running, starts a countdown timer.
/// If countdown reaches zero, signals that protection should be deactivated.
@MainActor
final class IdleDetector: ObservableObject {
    @Published var isCountdownActive: Bool = false
    @Published var remainingSeconds: Int = 0
    @Published var shouldDeactivateProtection: Bool = false

    private var countdownTimer: Timer?
    private var idleTimeout: TimeInterval

    init(idleTimeout: TimeInterval = Constants.defaultIdleTimeout) {
        self.idleTimeout = idleTimeout
        self.remainingSeconds = Int(idleTimeout)
    }

    /// Start the idle countdown (called when target apps exit)
    func startCountdown() {
        guard !isCountdownActive else { return }

        remainingSeconds = Int(idleTimeout)
        isCountdownActive = true
        shouldDeactivateProtection = false

        LidFlowLogger.detection.info("Idle countdown started: \(self.remainingSeconds)s")

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    /// Cancel the countdown (called when target apps re-launch)
    func cancelCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        isCountdownActive = false
        remainingSeconds = Int(idleTimeout)
        shouldDeactivateProtection = false

        LidFlowLogger.detection.info("Idle countdown cancelled")
    }

    /// Update idle timeout setting
    func updateTimeout(_ newTimeout: TimeInterval) {
        self.idleTimeout = newTimeout
        if !isCountdownActive {
            self.remainingSeconds = Int(newTimeout)
        }
    }

    // MARK: - Private

    private func tick() {
        guard isCountdownActive else { return }

        remainingSeconds -= 1

        if remainingSeconds <= 0 {
            countdownTimer?.invalidate()
            countdownTimer = nil
            isCountdownActive = false
            shouldDeactivateProtection = true
            remainingSeconds = Int(idleTimeout)
            LidFlowLogger.detection.info("Idle countdown finished — protection should deactivate")
        }
    }
}
