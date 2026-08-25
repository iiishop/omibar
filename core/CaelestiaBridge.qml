// CaelestiaBridge — 可选集成：按需同步 caelestia 状态。
// 本文件是全仓库唯一允许出现 "qs -c caelestia ipc" 的地方。
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property bool enabled: true
    property bool refreshPending: false
    property bool refreshDndPending: false

    readonly property string ipcCmd: "qs -c caelestia ipc call"
    readonly property string notifsPath: Quickshell.env("HOME") + "/.local/state/caelestia/notifs.json"

    function refreshLauncher(): void {
        if (!enabled)
            return;
        if (proc.running) {
            refreshPending = true;
            return;
        }
        refreshPending = false;
        proc.command = ["sh", "-c", ipcCmd + " drawers isOpen launcher"];
        proc.running = true;
    }

    function refreshLauncherSoon(): void {
        if (!enabled)
            return;
        launcherRefreshDelay.restart();
    }

    function refreshDnd(): void {
        if (!enabled)
            return;
        if (dndProc.running) {
            refreshDndPending = true;
            return;
        }
        refreshDndPending = false;
        dndProc.command = ["sh", "-c", ipcCmd + " notifs isDndEnabled"];
        dndProc.running = true;
    }

    function openSidebar(): void {
        if (!enabled || sidebarProc.running)
            return;
        sidebarProc.command = ["sh", "-c", ipcCmd + " drawers toggle sidebar"];
        sidebarProc.running = true;
    }

    function refreshNotifications(): void {
        notifsFile.reload();
    }

    function applyNotifications(): void {
        try {
            const data = JSON.parse(notifsFile.text());
            BarState.notificationCount = Array.isArray(data) ? data.length : 0;
            BarState.notificationStateReady = true;
        } catch (e) {
            console.warn("[omibar] notifs.json parse failed:", e);
        }
    }

    readonly property Process proc: Process {
        id: proc

        stdout: SplitParser {
            onRead: data => {
                const out = data.trim();
                if (out === "") {
                    BarState.caelestiaAvailable = false;
                    BarState.launcherOpen = false;
                    return;
                }
                BarState.caelestiaAvailable = true;
                BarState.launcherOpen = out === "1";
            }
        }
        stderr: SplitParser {}
        onExited: (code, status) => {
            if (code !== 0) {
                BarState.caelestiaAvailable = false;
                BarState.launcherOpen = false;
            }
            if (refreshPending)
                refreshLauncher();
        }
    }

    readonly property Timer launcherRefreshDelay: Timer {
        interval: 160
        repeat: false
        onTriggered: root.refreshLauncher()
    }

    readonly property Timer launcherOpenWatcher: Timer {
        interval: 350
        running: BarState.launcherOpen
        repeat: true
        onTriggered: root.refreshLauncher()
    }

    readonly property Process dndProc: Process {
        id: dndProc

        stdout: SplitParser {
            onRead: data => {
                const out = data.trim();
                BarState.caelestiaAvailable = out !== "";
                BarState.notificationDnd = out === "true";
            }
        }
        stderr: SplitParser {}
        onExited: (code, status) => {
            if (code !== 0) {
                BarState.caelestiaAvailable = false;
                BarState.notificationDnd = false;
            }
            if (refreshDndPending)
                refreshDnd();
        }
    }

    readonly property Process sidebarProc: Process {
        id: sidebarProc

        stderr: SplitParser {}
    }

    readonly property FileView notifsFile: FileView {
        path: root.notifsPath
        watchChanges: true
        onLoaded: root.applyNotifications()
        onFileChanged: root.refreshNotifications()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                BarState.notificationCount = 0;
                BarState.notificationStateReady = true;
            }
        }
    }

    readonly property Timer dndTimer: Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refreshDnd()
    }

    Component.onCompleted: {
        refreshLauncher();
        refreshDnd();
        refreshNotifications();
    }
}
