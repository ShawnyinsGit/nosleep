import Foundation
import IOKit
import IOKit.pwr_mgt

/// Protocol for all protection layers
protocol ProtectionLayer: AnyObject {
    var level: ProtectionLevel { get }
    var isActive: Bool { get }
    func activate() throws
    func deactivate()
}

// MARK: - L1: System Assertion Protection

/// L1: Uses IOPMAssertionCreateWithName to prevent idle sleep.
/// Note: This does NOT prevent clamshell (lid-close) sleep.
final class AssertionProtection: ProtectionLayer {
    let level: ProtectionLevel = .assertion
    private(set) var isActive: Bool = false
    private var assertionID: IOPMAssertionID = 0

    func activate() throws {
        guard !isActive else { return }

        let status = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleSystemSleep as CFString,
            0, // kIOPMAssertionTimeoutInfinite
            "LidFlow: Preventing idle sleep for development tasks" as CFString,
            &assertionID
        )

        if status == kIOReturnSuccess {
            isActive = true
            LidFlowLogger.protection.info("L1 Assertion activated (id: \(self.assertionID))")
        } else {
            throw ProtectionError.activationFailed(level: level, reason: "IOPMAssertionCreate failed with status \(status)")
        }
    }

    func deactivate() {
        guard isActive else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isActive = false
        LidFlowLogger.protection.info("L1 Assertion deactivated")
    }
}

// MARK: - L4: Wake Timer Protection

/// L4: Schedules periodic wake events to cover brief sleep windows
final class WakeTimerProtection: ProtectionLayer {
    let level: ProtectionLevel = .wakeTimer
    private(set) var isActive: Bool = false
    private var timer: Timer?

    func activate() throws {
        guard !isActive else { return }
        scheduleNextWake()
        startTimer()
        isActive = true
        LidFlowLogger.protection.info("L4 WakeTimer activated")
    }

    func deactivate() {
        guard isActive else { return }
        timer?.invalidate()
        timer = nil
        isActive = false
        LidFlowLogger.protection.info("L4 WakeTimer deactivated")
    }

    private func scheduleNextWake() {
        let now = Date()
        let wakeDate = now.addingTimeInterval(Constants.wakeTimerInterval)

        let result = IOPMSchedulePowerEvent(
            wakeDate as CFDate,
            Constants.appBundleId as CFString,
            kIOPMAutoWake as CFString
        )

        if result != kIOReturnSuccess {
            LidFlowLogger.protection.warning("L4 Failed to schedule wake event: \(result)")
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: Constants.wakeTimerInterval - 5, repeats: true) { [weak self] _ in
            self?.scheduleNextWake()
        }
    }
}

// MARK: - Errors

enum ProtectionError: LocalizedError {
    case activationFailed(level: ProtectionLevel, reason: String)
    case deactivationFailed(level: ProtectionLevel, reason: String)
    case sudoRequired(level: ProtectionLevel)

    var errorDescription: String? {
        switch self {
        case .activationFailed(let level, let reason):
            return "\(level.displayName) 激活失败: \(reason)"
        case .deactivationFailed(let level, let reason):
            return "\(level.displayName) 停用失败: \(reason)"
        case .sudoRequired(let level):
            return "\(level.displayName) 需要管理员授权"
        }
    }
}
