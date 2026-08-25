// BarState — 全局状态机，唯一事实来源。
// HyprEvents 和可选集成只往这里写数，
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

    // ---- 可选集成状态 ----
    property bool caelestiaAvailable: false
    // caelestia launcher 水平居中（源码硬编码 horizontalCenter），
    // 因此避让方向恒为左。若未来支持其他位置，此处扩展为方向枚举。
    property bool launcherOpen: false
    readonly property bool launcherCentered: true

    property bool dashboardOpen: false
    property bool sidebarOpen: false

    // ---- 避让派生状态 ----
    readonly property bool shouldYield: fullscreen || launcherOpen

    // 胶囊整体避让位移（向左滑出的距离）
    readonly property real yieldOffsetX: shouldYield ? -yieldShift : 0
    // 让位滑移量：胶囊宽度的一半再多点，视觉上"让出中心"
    property real capsuleWidth: 0
    readonly property real yieldShift: Math.min(capsuleWidth * 1.2, 400)

    // 形变：避让时胶囊水平压缩（squash），返回时恢复
    readonly property real yieldScaleX: shouldYield ? 0.82 : 1.0
}
