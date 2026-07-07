import SwiftUI

/// Main menu bar popover view — shows status, quick toggles, and settings access
struct MenuPopover: View {
    @EnvironmentObject var protectionManager: ProtectionManager
    @EnvironmentObject var appDetector: AppDetector
    @EnvironmentObject var idleDetector: IdleDetector
    @EnvironmentObject var appState: AppStateManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with status
            headerSection
            Divider()

            // Protection layers status
            protectionStatusSection
            Divider()

            // Active apps
            if appDetector.isAnyTargetAppRunning {
                activeAppsSection
                Divider()
            }

            // Quick actions
            quickActionsSection
            Divider()

            // Countdown (if active)
            if idleDetector.isCountdownActive {
                countdownSection
                Divider()
            }

            // Footer
            footerSection
        }
        .frame(width: 300)
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack {
            Image(systemName: appState.currentState.menuBarIconName)
                .font(.title2)
                .foregroundStyle(iconColor)
            VStack(alignment: .leading) {
                Text(Constants.appName)
                    .font(.headline)
                Text(appState.currentState.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("v\(Constants.appVersion)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var protectionStatusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("防护层级")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)

            ForEach(ProtectionLevel.allCases, id: \.rawValue) { level in
                layerRow(level)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func layerRow(_ level: ProtectionLevel) -> some View {
        HStack(spacing: 8) {
            // Status indicator
            Circle()
                .fill(layerColor(level))
                .frame(width: 8, height: 8)

            Text("L\(level.rawValue)")
                .font(.caption.monospaced())
                .frame(width: 24, alignment: .leading)

            Text(level.displayName)
                .font(.caption)

            Spacer()

            if level.requiresSudo {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if let error = protectionManager.failedLayers[level] {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .help(error)
            }
        }
    }

    private var activeAppsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("活跃应用")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(appDetector.runningTargetAppNames, id: \.self) { name in
                HStack(spacing: 6) {
                    Image(systemName: "app.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                    Text(name)
                        .font(.caption)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var quickActionsSection: some View {
        VStack(spacing: 2) {
            Button {
                appState.toggleManualProtection()
            } label: {
                HStack {
                    Image(systemName: protectionManager.isProtectionActive ? "shield.slash.fill" : "shield.fill")
                    Text(protectionManager.isProtectionActive ? "关闭防护" : "开启防护")
                    Spacer()
                    Text("⌃⌥⌘L")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Button {
                appState.showMainWindow()
            } label: {
                HStack {
                    Image(systemName: "macwindow")
                    Text("主窗口")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Button {
                appState.quit()
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("退出 NoSleep")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var countdownSection: some View {
        HStack {
            Image(systemName: "timer")
                .foregroundStyle(.yellow)
            Text("休眠倒计时")
                .font(.caption)
            Spacer()
            Text("\(idleDetector.remainingSeconds)s")
                .font(.caption.monospaced())
                .foregroundStyle(.yellow)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var footerSection: some View {
        HStack {
            Text("NoSleep — 让合盖不再焦虑")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private var iconColor: Color {
        switch appState.currentState {
        case .idle: return .green
        case .protecting: return .blue
        case .countdown: return .yellow
        case .overheated: return .red
        case .lowBattery: return .orange
        }
    }

    private func layerColor(_ level: ProtectionLevel) -> Color {
        if protectionManager.activeLayers.contains(level) {
            return .green
        } else if protectionManager.failedLayers[level] != nil {
            return .orange
        } else {
            return .gray.opacity(0.4)
        }
    }
}
