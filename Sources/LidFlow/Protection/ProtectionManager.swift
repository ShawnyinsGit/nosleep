import Foundation

// MARK: - Protection Manager

/// Central coordinator for all protection layers.
/// Activates layers in order (L1 → L5) and manages their lifecycle.
/// If a layer fails, logs the error and continues with remaining layers.
@MainActor
final class ProtectionManager: ObservableObject {
    @Published private(set) var activeLayers: Set<ProtectionLevel> = []
    @Published private(set) var failedLayers: [ProtectionLevel: String] = [:]
    @Published var maxLevel: ProtectionLevel = .virtualDisplay

    private let layers: [ProtectionLevel: ProtectionLayer]

    init() {
        var layerMap: [ProtectionLevel: ProtectionLayer] = [:]
        let assertionLayer = AssertionProtection()
        let ioRegistryLayer = IORegistryProtection()
        let virtualDisplayLayer = VirtualDisplayProtection()
        let wakeTimerLayer = WakeTimerProtection()
        let pmSetLayer = PMSetProtection()

        layerMap[.assertion] = assertionLayer
        layerMap[.ioRegistry] = ioRegistryLayer
        layerMap[.virtualDisplay] = virtualDisplayLayer
        layerMap[.wakeTimer] = wakeTimerLayer
        layerMap[.pmSet] = pmSetLayer

        self.layers = layerMap
    }

    /// Activate all layers up to maxLevel
    func activateProtection() {
        LidFlowLogger.protection.info("Activating protection up to L\(self.maxLevel.rawValue)")

        for level in ProtectionLevel.allCases where level <= maxLevel {
            guard let layer = layers[level] else { continue }

            // Skip sudo-requiring layers unless explicitly enabled
            if level.requiresSudo && level == .pmSet {
                // Only activate L5 if user has explicitly set maxLevel to include it
                guard maxLevel >= .pmSet else { continue }
            }

            do {
                try layer.activate()
                activeLayers.insert(level)
                failedLayers.removeValue(forKey: level)
            } catch {
                let errorMsg = error.localizedDescription
                failedLayers[level] = errorMsg
                LidFlowLogger.protection.error("Failed to activate L\(level.rawValue): \(errorMsg)")
            }
        }
    }

    /// Deactivate all active layers in reverse order
    func deactivateProtection() {
        LidFlowLogger.protection.info("Deactivating all protection layers")

        // Deactivate in reverse order (highest level first)
        for level in ProtectionLevel.allCases.reversed() {
            guard let layer = layers[level], layer.isActive else { continue }
            layer.deactivate()
            activeLayers.remove(level)
        }

        failedLayers.removeAll()
    }

    /// Check if any protection is currently active
    var isProtectionActive: Bool {
        !activeLayers.isEmpty
    }

    /// Get status summary for display
    var statusSummary: String {
        if activeLayers.isEmpty {
            return "未激活"
        }
        let activeList = activeLayers.sorted().map { "L\($0.rawValue)" }.joined(separator: " + ")
        return "活跃: \(activeList)"
    }

    /// Force activate a specific layer (for manual override)
    func forceActivateLayer(_ level: ProtectionLevel) throws {
        guard let layer = layers[level] else { return }
        try layer.activate()
        activeLayers.insert(level)
    }

    /// Force deactivate a specific layer
    func forceDeactivateLayer(_ level: ProtectionLevel) {
        guard let layer = layers[level] else { return }
        layer.deactivate()
        activeLayers.remove(level)
    }
}
