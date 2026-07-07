import Foundation
import AppKit

/// What kind of target we're monitoring
enum TargetKind: String, Codable, CaseIterable {
    case gui = "gui"      // macOS .app (VS Code, Cursor, etc.)
    case cli = "cli"      // CLI tool running in a terminal (claude, codex, etc.)

    var displayName: String {
        switch self {
        case .gui: return "应用"
        case .cli: return "CLI"
        }
    }

    var iconName: String {
        switch self {
        case .gui: return "app.fill"
        case .cli: return "terminal.fill"
        }
    }
}

/// Represents a target application or CLI tool to monitor
struct TargetApp: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var bundleIdentifier: String?
    var kind: TargetKind
    /// Process names to match for CLI tools (checked via pgrep)
    var processNames: [String]
    var isEnabled: Bool
    var isInstalled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifier: String? = nil,
        kind: TargetKind = .gui,
        processNames: [String] = [],
        isEnabled: Bool = true,
        isInstalled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.kind = kind
        self.processNames = processNames
        self.isEnabled = isEnabled
        self.isInstalled = isInstalled
    }

    /// Known bundle identifiers for GUI apps
    static let knownBundleIds: [String: String] = [
        "Visual Studio Code": "com.microsoft.VSCode",
        "Cursor": "com.todesktop.230313mzl4w4u92",
        "Windsurf": "com.exafunction.windsurf",
        "QoderWork": "com.qoder.work",
        "Codex": "com.openai.codex"
    ]

    /// Create preset target apps (GUI + CLI)
    static func defaultApps() -> [TargetApp] {
        let guiApps: [TargetApp] = [
            TargetApp(name: "Visual Studio Code", bundleIdentifier: "com.microsoft.VSCode"),
            TargetApp(name: "Cursor", bundleIdentifier: "com.todesktop.230313mzl4w4u92"),
            TargetApp(name: "Windsurf", bundleIdentifier: "com.exafunction.windsurf"),
            TargetApp(name: "QoderWork", bundleIdentifier: "com.qoder.work"),
            TargetApp(name: "Codex", bundleIdentifier: "com.openai.codex"),
        ]
        .map { app in
            var a = app
            a.isInstalled = isAppInstalled(name: a.name, kind: .gui)
            return a
        }

        let cliTools: [TargetApp] = [
            TargetApp(
                name: "Claude Code",
                kind: .cli,
                processNames: ["claude"]
            ),
            TargetApp(
                name: "Kimi Code",
                kind: .cli,
                processNames: ["kimi"]
            ),
            TargetApp(
                name: "Codex CLI",
                kind: .cli,
                processNames: ["codex"]
            ),
            TargetApp(
                name: "QoderWork CLI",
                kind: .cli,
                processNames: ["qoder"]
            ),
        ]
        .map { tool in
            var t = tool
            t.isInstalled = isCLIInstalled(processNames: t.processNames)
            // CLI tools default to disabled if not installed
            if !t.isInstalled { t.isEnabled = false }
            return t
        }

        return guiApps + cliTools
    }

    // MARK: - Installation Detection

    /// Check if a GUI app is installed
    static func isAppInstalled(name: String, kind: TargetKind = .gui) -> Bool {
        guard kind == .gui else { return false }
        let workspace = NSWorkspace.shared
        if let bundleId = knownBundleIds[name],
           workspace.urlForApplication(withBundleIdentifier: bundleId) != nil {
            return true
        }
        let appPath = "/Applications/\(name).app"
        return FileManager.default.fileExists(atPath: appPath)
    }

    /// Check if a CLI tool is available on the system
    static func isCLIInstalled(processNames: [String]) -> Bool {
        for name in processNames {
            // Check common paths and PATH
            let paths = [
                "/usr/local/bin/\(name)",
                "/opt/homebrew/bin/\(name)",
                "\(NSHomeDirectory())/.local/bin/\(name)",
                "\(NSHomeDirectory())/.npm-global/bin/\(name)",
                "\(NSHomeDirectory())/.cargo/bin/\(name)",
            ]
            for path in paths {
                if FileManager.default.fileExists(atPath: path) {
                    return true
                }
            }
            // Check via `which`
            if let output = try? shellOutput("which \(name)"), !output.isEmpty {
                return true
            }
        }
        return false
    }

    /// Check if any matching CLI process is currently running
    static func isCLIProcessRunning(processNames: [String]) -> Bool {
        for name in processNames {
            // pgrep returns 0 if at least one matching process exists
            let result = try? shellOutput("pgrep -x \(name) 2>/dev/null || pgrep -f 'node.*\(name)' 2>/dev/null || pgrep -f 'python.*\(name)' 2>/dev/null")
            if let output = result, !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }
        }
        return false
    }

    // MARK: - Shell Helper

    private static func shellOutput(_ command: String) throws -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}
