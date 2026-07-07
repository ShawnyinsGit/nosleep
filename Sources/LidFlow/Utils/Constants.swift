import Foundation

enum Constants {
    static let appName = "LidFlow"
    static let appVersion = "0.2.3"
    static let appBundleId = "com.lidflow.app"

    // Detection polling interval in seconds
    static let detectionPollInterval: TimeInterval = 5.0

    // Idle countdown before restoring normal sleep (seconds)
    static let defaultIdleTimeout: TimeInterval = 120.0

    // Battery protection defaults
    static let defaultLowBatteryThreshold: Int = 15

    // Default target applications
    static let defaultTargetApps: [String] = [
        "Visual Studio Code",
        "Cursor",
        "Windsurf",
        "QoderWork"
    ]

    // Wake timer interval for L4 (seconds)
    static let wakeTimerInterval: TimeInterval = 25.0

    // Thermal threshold (Celsius) — pause protection if battery temp exceeds
    static let thermalThreshold: Double = 45.0
}
