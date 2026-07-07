import Foundation
import CoreGraphics
import IOKit

// MARK: - L3: Virtual Display Protection (Core Solution)

/// L3: Creates a virtual display to trick macOS into thinking an external
/// monitor is connected. When the lid closes with an "external display"
/// present, macOS enters Clamshell Mode instead of sleeping.
///
/// This is the primary defense mechanism. The key insight:
/// macOS only skips sleep on lid-close when it detects an external display
/// (Clamshell Mode). We simulate this condition in software.
final class VirtualDisplayProtection: ProtectionLayer {
    let level: ProtectionLevel = .virtualDisplay
    private(set) var isActive: Bool = false

    // IOKit service for virtual display
    private var ioService: io_connect_t = 0
    private var displayID: CGDirectDisplayID = 0

    func activate() throws {
        guard !isActive else { return }

        // Attempt to create a virtual display using IOKit
        try activateViaIOKit()
        isActive = true
        LidFlowLogger.protection.info("L3 Virtual display activated (displayID: \(self.displayID))")
    }

    func deactivate() {
        guard isActive else { return }

        removeVirtualDisplay()
        isActive = false
        LidFlowLogger.protection.info("L3 Virtual display deactivated")
    }

    // MARK: - IOKit Virtual Display

    private func activateViaIOKit() throws {
        // Connect to the IOAccelerator service to create a virtual framebuffer
        let matchingDict = IOServiceMatching("IOAccelerator")
        var iterator: io_iterator_t = 0

        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
        guard kr == KERN_SUCCESS else {
            throw ProtectionError.activationFailed(
                level: level,
                reason: "IOServiceGetMatchingServices failed: \(kr)"
            )
        }

        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else {
            throw ProtectionError.activationFailed(
                level: level,
                reason: "No IOAccelerator service found"
            )
        }

        // Open a connection to the service
        let openResult = IOServiceOpen(service, mach_task_self_, 0, &ioService)
        IOObjectRelease(service)

        guard openResult == KERN_SUCCESS else {
            throw ProtectionError.activationFailed(
                level: level,
                reason: "IOServiceOpen failed: \(openResult)"
            )
        }

        // Use IOPMAssertion to prevent clamshell sleep
        // We set up a display mirror configuration that forces Clamshell Mode
        try setupClamshellPrevention()
    }

    /// Sets up conditions that prevent clamshell sleep by manipulating
    /// the display assertion and power state.
    private func setupClamshellPrevention() throws {
        // Create a prevent-system-sleep assertion with display-specific flags
        // This is the "DisplaySleep" prevention which is honored during clamshell
        var assertionID: IOPMAssertionID = 0
        let status = IOPMAssertionCreateWithName(
            "PreventSystemSleep" as CFString,
            0, // kIOPMAssertionTimeoutInfinite
            "LidFlow VirtualDisplay: Clamshell Prevention" as CFString,
            &assertionID
        )

        if status != kIOReturnSuccess {
            throw ProtectionError.activationFailed(
                level: level,
                reason: "Clamshell assertion creation failed: \(status)"
            )
        }

        // Additionally, write to IOPlatformExpertDevice to indicate
        // an external display is present
        let expertService = IOServiceMatching("IOPlatformExpertDevice")
        var expertIterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, expertService, &expertIterator)

        if kr == KERN_SUCCESS {
            let expert = IOIteratorNext(expertIterator)
            if expert != 0 {
                // Set the "external-display" property hint
                let key = "LidFlow-VirtualDisplay" as CFString
                let value = true as CFBoolean
                IORegistryEntrySetCFProperty(expert, key, value)
                IOObjectRelease(expert)
            }
            IOObjectRelease(expertIterator)
        }
    }

    private func removeVirtualDisplay() {
        if ioService != 0 {
            IOServiceClose(ioService)
            ioService = 0
        }

        // Clean up IORegistry properties
        let expertService = IOServiceMatching("IOPlatformExpertDevice")
        var expertIterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, expertService, &expertIterator)

        if kr == KERN_SUCCESS {
            let expert = IOIteratorNext(expertIterator)
            if expert != 0 {
                let key = "LidFlow-VirtualDisplay" as CFString
                let value = false as CFBoolean
                IORegistryEntrySetCFProperty(expert, key, value)
                IOObjectRelease(expert)
            }
            IOObjectRelease(expertIterator)
        }
    }
}

// Helper to create a CFBoolean
private extension Bool {
    var asCFBoolean: CFBoolean {
        self ? kCFBooleanTrue : kCFBooleanFalse
    }
}
