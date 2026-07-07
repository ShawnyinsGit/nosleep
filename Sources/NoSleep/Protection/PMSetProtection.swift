import Foundation
import IOKit

// MARK: - L5: pmset disablesleep Protection

/// L5: The nuclear option. Uses `pmset disablesleep 1` to completely
/// disable system sleep. This requires sudo/admin authorization and
/// should only be used for critical tasks.
///
/// WARNING: If not properly restored, the Mac will never sleep again,
/// draining battery if left in a bag.
final class PMSetProtection: ProtectionLayer {
    let level: ProtectionLevel = .pmSet
    private(set) var isActive: Bool = false

    func activate() throws {
        guard !isActive else { return }

        // This requires sudo, so we use AuthorizationExecuteWithPrivileges
        let result = executeWithPrivileges(
            command: "/usr/bin/pmset",
            arguments: ["disablesleep", "1"]
        )

        if result {
            isActive = true
            NoSleepLogger.protection.warning("L5 pmset disablesleep activated (REQUIRES MANUAL RESTORE)")
        } else {
            throw ProtectionError.sudoRequired(level: level)
        }
    }

    func deactivate() {
        guard isActive else { return }

        let result = executeWithPrivileges(
            command: "/usr/bin/pmset",
            arguments: ["disablesleep", "0"]
        )

        if result {
            isActive = false
            NoSleepLogger.protection.info("L5 pmset disablesleep deactivated (sleep restored)")
        } else {
            NoSleepLogger.protection.error("L5 FAILED to restore pmset disablesleep! Manual intervention needed.")
        }
    }

    // MARK: - Privileged Execution

    private func executeWithPrivileges(command: String, arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = [command] + arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            NoSleepLogger.protection.error("L5 Failed to execute privileged command: \(error.localizedDescription)")
            return false
        }
    }
}
