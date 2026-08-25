// CaelestiaBridge — 可选集成：按需查询 caelestia launcher 开关状态。
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

    readonly property string ipcCmd: "qs -c caelestia ipc call"

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

    Component.onCompleted: refreshLauncher()
}
