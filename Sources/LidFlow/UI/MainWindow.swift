import SwiftUI

/// Main window view — comprehensive status dashboard and settings
struct MainWindow: View {
    @EnvironmentObject var protectionManager: ProtectionManager
    @EnvironmentObject var appDetector: AppDetector
    @EnvironmentObject var idleDetector: IdleDetector
    @EnvironmentObject var appState: AppStateManager

    var body: some View {
        VStack(spacing: 0) {
            // Title bar area
            titleBar
            Divider()

            // Main content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Status card
                    statusCard

                    // Protection layers card
                    protectionCard

                    // Monitored apps card
                    monitoredAppsCard

                    // Settings card
                    SettingsView()
                        .environmentObject(appDetector)
                        .environmentObject(protectionManager)
                        .environmentObject(idleDetector)
                }
                .padding(20)
            }
        }
        .frame(minWidth: 520, minHeight: 680)
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack {
            Image(systemName: "shield.lefthalf.filled")
                .font(.title2)
                .foregroundStyle(.blue)
            Text(Constants.appName)
                .font(.title2.bold())
            Spacer()
            Text("v\(Constants.appVersion)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: appState.currentState.menuBarIconName)
                    .font(.largeTitle)
                    .foregroundStyle(stateColor)
                    .frame(width: 50)

                VStack(alignment: .leading, spacing: 2) {
                    Text("当前状态")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(appState.currentState.displayName)
                        .font(.title3.bold())
                }

                Spacer()

                // Big toggle
                Button {
                    appState.toggleManualProtection()
                } label: {
                    Image(systemName: protectionManager.isProtectionActive ? "power.circle.fill" : "power.circle")
                        .font(.system(size: 44))
                        .foregroundStyle(protectionManager.isProtectionActive ? .blue : .gray)
                }
                .buttonStyle(.plain)
                .help(protectionManager.isProtectionActive ? "关闭防护" : "开启防护")
            }

            if idleDetector.isCountdownActive {
                HStack {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .frame(maxWidth: .infinity)
                    Text("\(idleDetector.remainingSeconds)s")
                        .font(.caption.monospaced())
                        .foregroundStyle(.yellow)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(stateColor.opacity(0.08))
        )
    }

    // MARK: - Protection Card

    private var protectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("防护层级详情", systemImage: "shield.lefthalf.filled")
                .font(.headline)

            ForEach(ProtectionLevel.allCases, id: \.rawValue) { level in
                protectionLayerRow(level)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.06))
        )
    }

    private func protectionLayerRow(_ level: ProtectionLevel) -> some View {
        HStack(spacing: 12) {
            // Status circle
            ZStack {
                Circle()
                    .fill(protectionManager.activeLayers.contains(level) ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 24, height: 24)
                Text("L\(level.rawValue)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(level.displayName)
                    .font(.subheadline)
                Text(level.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if level.requiresSudo {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.orange)
                    .help("需要管理员授权")
            }

            if let error = protectionManager.failedLayers[level] {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(error)
            }
        }
    }

    // MARK: - Monitored Apps Card

    private var monitoredAppsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("监控中的应用", systemImage: "app.badge.checkmark")
                .font(.headline)

            if appDetector.isAnyTargetAppRunning {
                ForEach(appDetector.runningTargetAppNames, id: \.self) { name in
                    HStack {
                        Image(systemName: "app.fill")
                            .foregroundStyle(.blue)
                        Text(name)
                        Spacer()
                        Text("运行中")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } else {
                Text("当前没有监控中的应用在运行")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.06))
        )
    }

    // MARK: - Helpers

    private var stateColor: Color {
        switch appState.currentState {
        case .idle: return .green
        case .protecting: return .blue
        case .countdown: return .yellow
        case .overheated: return .red
        case .lowBattery: return .orange
        }
    }
}
