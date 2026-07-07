import Foundation
import IOKit

// MARK: - L2: IORegistry Protection

/// L2: Adjusts IORegistry power management properties to influence
/// kernel-level sleep behavior. This modifies IOPMrootDomain properties
/// that affect how the system handles sleep transitions.
final class IORegistryProtection: ProtectionLayer {
    let level: ProtectionLevel = .ioRegistry
    private(set) var isActive: Bool = false
    private var service: io_registry_entry_t = 0

    func activate() throws {
        guard !isActive else { return }

        // Get the root power domain
        service = IORegistryEntryFromPath(
            kIOMainPortDefault,
            "IOService:/IOResources/IOPMrootDomain"
        )

        guard service != 0 else {
            throw ProtectionError.activationFailed(
                level: level,
                reason: "无法获取 IOPMrootDomain"
            )
        }

        // Set the "SleepDisabled" property in IORegistry
        let key = "SleepDisabled" as CFString
        let value = kCFBooleanTrue

        let result = IORegistryEntrySetCFProperty(service, key, value)

        if result == kIOReturnSuccess {
            isActive = true
            LidFlowLogger.protection.info("L2 IORegistry protection activated")
        } else {
            IOObjectRelease(service)
            service = 0
            throw ProtectionError.activationFailed(
                level: level,
                reason: "IORegistryEntrySetCFProperty failed: \(result)"
            )
        }
    }

    func deactivate() {
        guard isActive, service != 0 else { return }

        // Restore the property
        let key = "SleepDisabled" as CFString
        let value = kCFBooleanFalse
        IORegistryEntrySetCFProperty(service, key, value)

        IOObjectRelease(service)
        service = 0
        isActive = false
        LidFlowLogger.protection.info("L2 IORegistry protection deactivated")
    }
}
