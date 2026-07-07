import SwiftUI

/// Settings view for NoSleep preferences
struct SettingsView: View {
    @EnvironmentObject var appDetector: AppDetector
    @EnvironmentObject var protectionManager: ProtectionManager
    @EnvironmentObject var idleDetector: IdleDetector

    @State private var showAddAppSheet = false
    @State private var newAppName = ""
    @State private var newAppBundleId = ""
    @State private var newAppKind: TargetKind = .gui
    @State private var newAppProcessNames = ""
    @State private var idleTimeoutMinutes: Double = Constants.defaultIdleTimeout / 60.0
    @State private var lowBatteryEnabled = true
    @State private var lowBatteryThreshold: Double = Double(Constants.defaultLowBatteryThreshold)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // App monitoring settings
                appMonitoringSection

                // Protection level
                protectionLevelSection

                // Idle timeout
                idleTimeoutSection

                // Low battery protection
                lowBatterySection

                // About
                aboutSection
            }
            .padding(20)
        }
        .frame(minWidth: 480, minHeight: 520)
        .sheet(isPresented: $showAddAppSheet) {
            addAppSheet
        }
    }

    // MARK: - App Monitoring

    private var appMonitoringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("监控应用", systemImage: "app.badge.checkmark")
                .font(.headline)

            Text("当以下应用运行时，NoSleep 将自动开启防护")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(appDetector.targetApps) { app in
                    HStack {
                        // Status dot
                        Circle()
                            .fill(app.isInstalled ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)

                        // Kind badge
                        Image(systemName: app.kind.iconName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 16)

                        Text(app.name)
                            .font(.body)

                        if !app.isInstalled {
                            Text("未安装")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Capsule())
                        }

                        Spacer()

                        // Running indicator
                        if appDetector.runningTargetAppNames.contains(app.name) {
                            Text("运行中")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }

                        Toggle("", isOn: Binding(
                            get: { app.isEnabled },
                            set: { _ in appDetector.toggleApp(app) }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)

                        // Delete button
                        Button {
                            appDetector.removeApp(app)
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    if app.id != appDetector.targetApps.last?.id {
                        Divider()
                    }
                }
            }
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button {
                showAddAppSheet = true
            } label: {
                Label("添加应用", systemImage: "plus.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Protection Level

    private var protectionLevelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("防护等级", systemImage: "shield.lefthalf.filled")
                .font(.headline)

            Picker("最高防护层级", selection: $protectionManager.maxLevel) {
                ForEach(ProtectionLevel.allCases, id: \.self) { level in
                    VStack(alignment: .leading) {
                        Text("L\(level.rawValue) - \(level.displayName)")
                            .font(.body)
                    }
                    .tag(level)
                }
            }
            .pickerStyle(.menu)

            // Show description of selected level
            Text(protectionManager.maxLevel.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            if protectionManager.maxLevel.requiresSudo {
                Label("此等级需要管理员密码授权", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Idle Timeout

    private var idleTimeoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("空闲休眠", systemImage: "timer")
                .font(.headline)

            HStack {
                Text("目标应用退出后等待")
                Spacer()
                Text("\(Int(idleTimeoutMinutes)) 分钟")
                    .foregroundStyle(.blue)
                    .monospaced()
            }

            Slider(value: $idleTimeoutMinutes, in: 1...10, step: 1)
                .onChange(of: idleTimeoutMinutes) { _, newValue in
                    idleDetector.updateTimeout(newValue * 60)
                }

            Text("空闲超过设定时间后，NoSleep 将自动关闭防护并恢复正常休眠")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Low Battery

    private var lowBatterySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("低电量保护", systemImage: "battery.25")
                .font(.headline)

            Toggle("启用低电量自动保护", isOn: $lowBatteryEnabled)
                .toggleStyle(.switch)

            if lowBatteryEnabled {
                HStack {
                    Text("电量低于")
                    Spacer()
                    Text("\(Int(lowBatteryThreshold))%")
                        .foregroundStyle(.orange)
                        .monospaced()
                }

                Slider(value: $lowBatteryThreshold, in: 5...30, step: 5)

                Text("电量低于阈值时自动暂停防护，防止过夜耗尽电池")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("关于", systemImage: "info.circle")
                .font(.headline)

            HStack {
                Text("版本")
                Spacer()
                Text(Constants.appVersion)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("快捷键")
                Spacer()
                VStack(alignment: .trailing) {
                    Text("⌃⌥⌘L  切换防护")
                    Text("⌃⌥⌘F  主窗口")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Add App Sheet

    private var addAppSheet: some View {
        VStack(spacing: 16) {
            Text("添加监控应用")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("类型")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("类型", selection: $newAppKind) {
                    ForEach(TargetKind.allCases, id: \.self) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                Text("应用名称")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(
                    newAppKind == .cli ? "例如：Claude Code" : "例如：IntelliJ IDEA",
                    text: $newAppName
                )
                .textFieldStyle(.roundedBorder)

                if newAppKind == .gui {
                    Text("Bundle ID（可选）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("例如：com.jetbrains.intellij", text: $newAppBundleId)
                        .textFieldStyle(.roundedBorder)
                } else {
                    Text("进程名称（逗号分隔）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("例如：claude, claude-code", text: $newAppProcessNames)
                        .textFieldStyle(.roundedBorder)
                    Text("NoSleep 会通过 pgrep 检测这些进程是否在运行")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack {
                Button("取消") {
                    resetAddSheet()
                    showAddAppSheet = false
                }

                Button("添加") {
                    if !newAppName.isEmpty {
                        let names = newAppProcessNames
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        appDetector.addApp(
                            name: newAppName,
                            bundleIdentifier: newAppKind == .gui ? (newAppBundleId.isEmpty ? nil : newAppBundleId) : nil,
                            kind: newAppKind,
                            processNames: names
                        )
                        resetAddSheet()
                        showAddAppSheet = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newAppName.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 380)
    }

    private func resetAddSheet() {
        newAppName = ""
        newAppBundleId = ""
        newAppProcessNames = ""
        newAppKind = .gui
    }
}
