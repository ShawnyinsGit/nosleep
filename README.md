# LidFlow

**让合盖重新变成一个不需要思考的动作。**

LidFlow 是一款 macOS 菜单栏工具，当你的开发工具（VS Code、Cursor、Windsurf、QoderWork）在跑任务时，合盖后任务继续运行；任务结束后，自动恢复正常休眠。

## 核心原理

macOS 把"合盖"和"空闲"当成两件不同的事。`caffeinate -i` 只能防止空闲休眠，合盖场景下无效。LidFlow 通过**五层冗余防护**解决这个问题：

| 层级 | 机制 | 需要 sudo |
|------|------|-----------|
| L1 | IOPMAssertion 系统断言 | 否 |
| L2 | IORegistry 内核层电源管理 | 否 |
| L3 | **虚拟显示器（主力）** — 模拟外接屏进入 Clamshell Mode | 否 |
| L4 | 定时唤醒补丁 | 否 |
| L5 | `pmset disablesleep` 完全禁用睡眠 | **是** |

## 功能特性

- **自动触发** — 检测到目标应用运行时自动开启防护，无需手动操作
- **智能空闲** — 目标应用退出后 120 秒倒计时，自动恢复正常休眠
- **多层冗余** — 五层防护逐层启用，单层失效不影响整体
- **菜单栏状态** — 图标颜色实时反映状态（绿/蓝/黄/红）
- **低电量保护** — 电量低于阈值时自动暂停防护
- **深度防护** — L5 级别需用户明确授权，不会偷偷启用

## 快速开始

### 安装

```bash
# 打开 DMG，拖拽 LidFlow.app 到 Applications
open build/LidFlow.dmg
```

### 从源码构建

```bash
git clone https://github.com/ShawnyinsGit/LidFlow.git
cd LidFlow

# 构建 .app
./build.sh

# 运行
open build/LidFlow.app

# 打包 DMG
./package-dmg.sh
```

### 使用

启动后菜单栏出现图标：

| 颜色 | 状态 |
|------|------|
| 🟢 绿色 | 待命 — 无目标应用运行 |
| 🔵 蓝色 | 防护中 — 目标应用活跃 |
| 🟡 黄色 | 空闲倒计时 — 目标应用已退出 |
| 🔴 红色 | 过热暂停 |

**快捷键：**
- `⌃⌥⌘L` — 切换防护开关
- `⌃⌥⌘F` — 打开主窗口

## 系统要求

- macOS 14.0+ (Sonoma)
- Apple Silicon 或 Intel

## 验证防护

```bash
# 查看当前系统断言
pmset -g assertions

# 启动 LidFlow 后打开 VS Code，再查看
# 应出现 "PreventUserIdleSystemSleep" 相关断言
```

## 许可证

MIT
