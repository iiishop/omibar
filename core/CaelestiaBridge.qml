// CaelestiaBridge — 慢通道：轮询 caelestia shell 的公开 IPC。
// 本文件是全仓库唯一允许出现 "qs -c caelestia ipc" 的地方。
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root

    property int intervalMs: 800
    property bool enabled: true

    readonly property string ipcCmd: "qs -c caelestia ipc call"

    function queryDrawer(name: string, callback: var): void {
        Quickshell.execDetached({
            command: ["sh", "-c", ipcCmd + " drawers isOpen " + name],
            onExit: (exitInfo) => callback(exitInfo.stdout.trim() === "1")
        });
    }

    function probeAvailable(callback: var): void {
        Quickshell.execDetached({
            command: ["sh", "-c", "qs -c caelestia ipc show 2>/dev/null | grep -q drawers"],
            onExit: (exitInfo) => callback(exitInfo.exitCode === 0)
        });
    }

    function poll(): void {
        if (!enabled)
            return;
        probeAvailable((ok) => {
            BarState.caelestiaAvailable = ok;
            if (!ok)
                return;
            queryDrawer("launcher", v => BarState.launcherOpen = v);
            queryDrawer("dashboard", v => BarState.dashboardOpen = v);
            queryDrawer("sidebar", v => BarState.sidebarOpen = v);
        });
    }

    readonly property Timer timer: Timer {
        interval: root.intervalMs
        running: root.enabled
        repeat: true
        onTriggered: root.poll()
    }

    Component.onCompleted: poll()
}
