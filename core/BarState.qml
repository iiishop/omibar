// BarState — 全局状态机，唯一事实来源。
// HyprEvents（快通道）和 CaelestiaBridge（慢通道）只往这里写数，
// bar 的几何/可见性全部由这里的派生属性算出。
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root

    // ---- 快通道（Hyprland 事件驱动）----
    property bool fullscreen: false
    property string activeWorkspace: "1"
    property string activeWindowTitle: ""

    // ---- 慢通道（Caelestia IPC 轮询）----
    property bool caelestiaAvailable: false
    property bool launcherOpen: false
    property bool dashboardOpen: false
    property bool sidebarOpen: false

    // ---- 派生：bar 是否让位 ----
    readonly property bool shouldYield: fullscreen || launcherOpen || dashboardOpen

    // bar 自身几何，由 BarWindow 回写
    property real barHeight: 0
    // 让位时整条滑出屏幕底部（含 margin），归位时回到贴底位置
    readonly property real yieldOffset: shouldYield ? barHeight + 12 : 0
}
