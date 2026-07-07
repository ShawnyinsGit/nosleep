import Foundation

/// Represents the current operational state of LidFlow
enum LidFlowState: Equatable {
    /// No target apps running, protection inactive
    case idle

    /// Target apps running, protection layers active
    case protecting

    /// Target apps exited, countdown before restoring sleep
    case countdown(remainingSeconds: Int)

    /// Protection paused due to thermal concerns
    case overheated

    /// Protection paused due to low battery
    case lowBattery

    var displayName: String {
        switch self {
        case .idle:
            return "待命"
        case .protecting:
            return "防护中"
        case .countdown(let seconds):
            return "倒计时 \(seconds)s"
        case .overheated:
            return "过热暂停"
        case .lowBattery:
            return "低电量保护"
        }
    }

    var menuBarIconName: String {
        switch self {
        case .idle:
            return "moon.fill"
        case .protecting:
            return "shield.fill"
        case .countdown:
            return "timer"
        case .overheated:
            return "thermometer.sun.fill"
        case .lowBattery:
            return "battery.25"
        }
    }

    var menuBarTintColor: String {
        switch self {
        case .idle: return "green"
        case .protecting: return "blue"
        case .countdown: return "yellow"
        case .overheated: return "red"
        case .lowBattery: return "orange"
        }
    }
}
