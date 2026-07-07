import Foundation

/// Represents a target application to monitor
struct TargetApp: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var bundleIdentifier: String?
    var isEnabled: Bool
    var isInstalled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifier: String? = nil,
        isEnabled: Bool = true,
        isInstalled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.isEnabled = isEnabled
        self.isInstalled = isInstalled
    }

    /// Known bundle identifiers for preset apps
    static let knownBundleIds: [String: String] = [
        "Visual Studio Code": "com.microsoft.VSCode",
        "Cursor": "com.todesktop.230313mzl4w4u92",
        "Windsurf": "com.exafunction.windsurf",
        "QoderWork": "com.qoder.work"
    ]

    /// Create preset target apps
    static func defaultApps() -> [TargetApp] {
        Constants.defaultTargetApps.map { name in
            TargetApp(
                name: name,
                bundleIdentifier: knownBundleIds[name],
                isEnabled: true,
                isInstalled: isAppInstalled(name: name)
            )
        }
    }

    /// Check if an app is installed on the system
    static func isAppInstalled(name: String) -> Bool {
        let workspace = NSWorkspace.shared
        // Check by bundle identifier
        if let bundleId = knownBundleIds[name],
           workspace.urlForApplication(withBundleIdentifier: bundleId) != nil {
            return true
        }
        // Fallback: check /Applications directory
        let appPath = "/Applications/\(name).app"
        return FileManager.default.fileExists(atPath: appPath)
    }
}

import AppKit
