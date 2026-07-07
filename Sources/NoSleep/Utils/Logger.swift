import Foundation
import os.log

enum NoSleepLogger {
    static let subsystem = "com.nosleep.app"

    static let protection = Logger(subsystem: subsystem, category: "Protection")
    static let detection = Logger(subsystem: subsystem, category: "Detection")
    static let ui = Logger(subsystem: subsystem, category: "UI")
    static let general = Logger(subsystem: subsystem, category: "General")
}
