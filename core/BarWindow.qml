// BarWindow — 底部灵动岛式 bar 的 layer-shell 宿主窗口。
//
// 窗口结构：只锚 bottom 的紧凑 layer（非全屏）。
// 历史教训：全屏透明层 + ExclusionMode.Normal 会把整个窗口算进排他区（巨大白板）；
// 部分锚定早期渲染失败是因为 implicitWidth 链没建立，现在 contentWidth 链已通。
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    readonly property int screenW: screen?.width ?? 0
    readonly property int screenH: screen?.height ?? 0

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "omibar"
    WlrLayershell.exclusionMode: ExclusionMode.Normal

    visible: true
    color: "transparent"

    anchors.top: false
    anchors.bottom: true
    anchors.left: false
    anchors.right: false
    // 贴近屏幕底部，避开 Hyprland gaps。
    margins.bottom: 3

    readonly property real capsuleHeight: BarState.moduleHeight
    property bool completed: false

    implicitHeight: capsuleHeight
    implicitWidth: panel.width + 2 * BarState.avoidanceInset

    exclusiveZone: BarState.fullscreen ? 0 : 26

    Component.onCompleted: {
        completed = true;
        console.log("[bar] completed. screen:", screenW, "x", screenH,
                    "SIG:", Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "(unset!)");
    }

    // 外层只保留整组的垂直避让；水平避让由每个胶囊分别处理。
    Item {
        id: panel

        readonly property real targetWidth: host.contentWidth > 0
            ? host.contentWidth : 10

        x: BarState.avoidanceInset
        y: BarState.fullscreen ? 5 : 0

        width: targetWidth
        height: root.capsuleHeight

        opacity: 1.0

        // ---- 弹簧物理 ----
        Behavior on width {
            SpringAnimation { spring: 3; damping: 0.62; mass: 0.8 }
        }
        Behavior on y {
            SpringAnimation { spring: 4; damping: 0.7; mass: 1.0 }
        }

        Binding {
            target: BarState
            property: "avoidanceWidth"
            value: host.avoidanceSideWidth
        }

        Binding {
            target: BarState
            property: "screenWidth"
            value: root.screenW
        }

        // 模块装载：清单驱动，左中右三区。水平避让由各胶囊分别处理。
        ModuleHost {
            id: host

            configDir: Quickshell.env("HOME") + "/Projects/omibar"
            neutralScreenX: root.screenW / 2 - panel.width / 2
            height: parent.height
            width: contentWidth
        }
    }
}
