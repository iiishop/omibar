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
    // 避让策略待定：滑出（offset = height）或原地缩小。先按滑出实现。
    readonly property bool shouldYield: fullscreen || launcherOpen || dashboardOpen

    // bar 自身高度，由 BarWindow 回写，供 offset 计算用
    property real barHeight: 0
    // 0 = 原位；正值 = 向下滑出的距离
    readonly property real yieldOffset: shouldYield ? barHeight + 8 : 0
}
