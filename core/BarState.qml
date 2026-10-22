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

    property var todoCountByDate: ({})
    property var overdueCountByDate: ({})
    property bool noteAvailable: false
    property string noteDateRequest: ""
    property int noteDateRequestSerial: 0

    property bool mediaAvailable: false
    property bool mediaPlaying: false
    property string mediaTitle: ""
    property string mediaArtist: ""
    property string mediaAlbum: ""
    property string mediaArtUrl: ""
    property real mediaPosition: 0
    property real mediaLength: 0
    property bool mediaLyricsLoading: false
    property bool mediaLyricsAvailable: false
    property string mediaLyric: ""
    property var mediaSpectrum: []
    property int mediaCardPulse: 0
    property string mediaPlayMode: "sequential"
    property bool mediaPlayModeAvailable: false
    // 播放器身份（MPRIS identity，如 "Spotify" / "sidra"）与可拖动性。
    property string mediaPlayerName: ""
    property bool mediaCanSeek: false
    readonly property real mediaProgress: mediaLength > 0
        ? Math.max(0, Math.min(1, mediaPosition / mediaLength))
        : 0

    component UpdateSource: QtObject {
        property string status: "unchecked"
        // Count belongs to lastSuccess, including while a later attempt fails.
        property int count: -1
        property double lastAttempt: 0
        property double lastSuccess: 0
        property string error: ""
        property string diagnostic: ""
    }

    readonly property QtObject updateRepo: UpdateSource {}
    readonly property QtObject updateAur: UpdateSource {}
    readonly property list<QtObject> updateSources: [updateRepo, updateAur]
    readonly property int updateTotalCount: updateSources.reduce((total, source) =>
        total + (source.status === "success" ? source.count : 0), 0)
    readonly property string updateState: {
        const states = updateSources.map(source => source.status);
        if (states.includes("checking")) return "checking";
        if (states.includes("unchecked")) return "unchecked";
        if (states.includes("busy")) return "busy";
        if (states.every(state => state === "success"))
            return updateTotalCount > 0 ? "available" : "up_to_date";
        return states.includes("success") ? "partial_failure" : "error";
    }

    property real avoidanceWidth: 0
    // 灵动岛展开时向胶囊上方借的高度，0 表示全部收起。
    property real islandExpandExtent: 0
    readonly property real moduleHeight: 32
    readonly property real moduleGap: 10
    readonly property real launcherLeft: (screenWidth - launcherWidth) / 2
    readonly property real launcherRight: launcherLeft + launcherWidth
    readonly property real launcherCenterX: screenWidth / 2
    readonly property real avoidanceInset: (launcherWidth + avoidanceWidth) / 2
        + launcherPadding

}
