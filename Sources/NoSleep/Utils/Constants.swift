import Foundation

enum Constants {
    static let appName = "NoSleep"
    static let appVersion = "0.2.3"
    static let appBundleId = "com.nosleep.app"

    // Detection polling interval in seconds
    static let detectionPollInterval: TimeInterval = 5.0

    // Idle countdown before restoring normal sleep (seconds)
    static let defaultIdleTimeout: TimeInterval = 120.0

    // Battery protection defaults
    static let defaultLowBatteryThreshold: Int = 15

    // CLI polling interval — CLI process checks are slightly more expensive
    static let cliPollInterval: TimeInterval = 8.0

    // Wake timer interval for L4 (seconds)
    static let wakeTimerInterval: TimeInterval = 25.0

    // Thermal threshold (Celsius) — pause protection if battery temp exceeds
    static let thermalThreshold: Double = 45.0
}
