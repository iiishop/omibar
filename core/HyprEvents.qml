// HyprEvents — 快通道：订阅 Hyprland 事件流，写入 BarState。
// 只做事件→状态的翻译，不含任何 UI 或避让逻辑。
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland

QtObject {
    function handle(event: HyprlandEvent): void {
        const name = event.name;
        if (name === "fullscreen") {
            // payload: "0"/"1"
            BarState.fullscreen = event.data[0] === "1";
        } else if (name === "workspacev2") {
            // payload: workspaceId, workspaceName
            BarState.activeWorkspace = event.data[1] ?? event.data[0];
        } else if (name === "activewindow") {
            // payload: class, title；空 class = 无活动窗口
            BarState.activeWindowTitle = event.data[0] === "" ? "" : (event.data[1] ?? "");
        }
    }

    function refreshFullscreen(): void {
        Quickshell.execDetached({
            command: ["sh", "-c", "hyprctl -j activewindow 2>/dev/null | jq -c .fullscreen"],
            onExit: (exitInfo) => {
                const v = exitInfo.stdout.trim();
                BarState.fullscreen = v === "1" || v === "true";
            }
        });
    }

    readonly property Connections events: Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            handle(event);
        }
    }

    Component.onCompleted: refreshFullscreen()
}
