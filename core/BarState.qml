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
    property bool launcherOpen: false
    property real screenWidth: 0
    property int deformPulse: 0
    readonly property real launcherWidth: 630
    readonly property real launcherPadding: 14

    property bool dashboardOpen: false
    property bool sidebarOpen: false
    property int notificationCount: 0
    property bool notificationDnd: false
    property bool notificationStateReady: false

    property bool mediaAvailable: false
    property bool mediaPlaying: false
    property string mediaTitle: ""
    property string mediaArtist: ""
    property string mediaAlbum: ""
    property real mediaPosition: 0
    property real mediaLength: 0
    property bool mediaLyricsLoading: false
    property bool mediaLyricsAvailable: false
    property string mediaLyric: ""
    property var mediaSpectrum: []
    property string mediaPlayMode: "sequential"
    property bool mediaPlayModeAvailable: false
    readonly property real mediaProgress: mediaLength > 0
        ? Math.max(0, Math.min(1, mediaPosition / mediaLength))
        : 0

    property real avoidanceWidth: 0
    readonly property real moduleHeight: 32
    readonly property real moduleGap: 10
    readonly property real launcherLeft: (screenWidth - launcherWidth) / 2
    readonly property real launcherRight: launcherLeft + launcherWidth
    readonly property real launcherCenterX: screenWidth / 2
    readonly property real avoidanceInset: (launcherWidth + avoidanceWidth) / 2
        + launcherPadding

}
