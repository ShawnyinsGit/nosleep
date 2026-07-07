import Foundation

/// Protection level enum representing the five defense layers
enum ProtectionLevel: Int, CaseIterable, Comparable {
    case assertion = 1      // L1: IOPMAssertion (prevent idle sleep)
    case ioRegistry = 2     // L2: IORegistry power management adjustments
    case virtualDisplay = 3 // L3: Virtual display (core — simulates external monitor)
    case wakeTimer = 4      // L4: Scheduled wake (covers brief sleep windows)
    case pmSet = 5          // L5: pmset disablesleep (nuclear option, requires sudo)

    static func < (lhs: ProtectionLevel, rhs: ProtectionLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .assertion: return "系统断言"
        case .ioRegistry: return "IORegistry 调整"
        case .virtualDisplay: return "虚拟显示器"
        case .wakeTimer: return "定时唤醒"
        case .pmSet: return "pmset 禁用睡眠"
        }
    }

    var description: String {
        switch self {
        case .assertion:
            return "IOPMAssertion 防止空闲休眠，基础防护层"
        case .ioRegistry:
            return "内核层面调整电源管理相关属性"
        case .virtualDisplay:
            return "模拟外接显示器，让系统进入 Clamshell Mode 合盖不休眠（主力方案）"
        case .wakeTimer:
            return "定时唤醒覆盖可能存在的短暂休眠窗口"
        case .pmSet:
            return "完全禁用系统睡眠（需要管理员授权，仅用于关键任务）"
        }
    }

    var requiresSudo: Bool {
        self == .pmSet
    }
}
