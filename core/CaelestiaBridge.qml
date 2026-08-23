// CaelestiaBridge — 慢通道：轮询 caelestia shell 的公开 IPC。
// 本文件是全仓库唯一允许出现 "qs -c caelestia ipc" 的地方。
//
// 实现说明：用常驻 Process + 手动节流（而非 Timer + execDetached）。
// execDetached 拿不到 stdout，是之前 drawers 状态永远读不回来的根因。
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property int intervalMs: 800
    property bool enabled: true
    // 探测失败退避：间隔按 2^backoffSteps 增长，上限 30s；探测成功归零即回基础间隔
    readonly property int pollIntervalMs: Math.min(intervalMs * Math.pow(2, backoffSteps), 30000)
    property int backoffSteps: 0

    // 待查询的 drawer 队列；一轮 poll 逐个发命令（单 Process 复用，避免并发起进程）
    readonly property var drawers: ["launcher", "dashboard", "sidebar"]
    property int queryIndex: 0

    readonly property string ipcCmd: "qs -c caelestia ipc call"

    function poll(): void {
        if (!enabled || proc.running)
            return;
        queryIndex = 0;
        probe();
    }

    // 第一步：探测 caelestia 是否可用
    function probe(): void {
        proc.command = ["sh", "-c", ipcCmd + " drawers isOpen launcher"];
        proc.running = true;
    }

    // 第二步：探测成功后查剩余 drawer
    function queryNext(): void {
        if (queryIndex >= drawers.length) {
            backoffSteps = 0;
            return;
        }
        const name = drawers[queryIndex];
        proc.command = ["sh", "-c", ipcCmd + " drawers isOpen " + name];
        proc.running = true;
    }

    function applyResult(name: string, output: string): void {
        const open = output.trim() === "1";
        if (name === "launcher") BarState.launcherOpen = open;
        else if (name === "dashboard") BarState.dashboardOpen = open;
        else if (name === "sidebar") BarState.sidebarOpen = open;
    }

    readonly property Process proc: Process {
        id: proc

        stdout: SplitParser {
            onRead: data => {
                const out = data.trim();
                // 第一条命令兼任探测：空输出/报错 = caelestia 不可用
                if (out === "" ) {
                    BarState.caelestiaAvailable = false;
                    backoffSteps = Math.min(backoffSteps + 1, 6);
                    return;
                }
                BarState.caelestiaAvailable = true;

                // 响应顺序与请求一致：launcher→dashboard→sidebar，
                // 但首轮响应是探测本身（launcher），后续轮询依次推进。
                applyResult(drawers[queryIndex] ?? "launcher", out);
                queryIndex++;
                queryNext();
            }
        }
        stderr: SplitParser {
            onRead: data => console.warn("[bridge] stderr:", data.trim())
        }
        onExited: (code, status) => {
            // 命令退出但无输出 = caelestia 不在跑（退避由 stdout 空分支处理）
        }
    }

    readonly property Timer timer: Timer {
        interval: root.pollIntervalMs
        running: root.enabled
        repeat: true
        onTriggered: root.poll()
    }

    Component.onCompleted: {
        poll();
    }
}
