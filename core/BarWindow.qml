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

    readonly property int capsuleHeight: 32
    property bool completed: false

    implicitHeight: capsuleHeight
    implicitWidth: panel.width + 2 * BarState.yieldShift

    exclusiveZone: BarState.fullscreen ? 0 : 26

    Component.onCompleted: {
        completed = true;
        console.log("[bar] completed. screen:", screenW, "x", screenH,
                    "SIG:", Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "(unset!)");
    }

    // 外层只负责整组移动和形变；每个非空区域的胶囊由 ModuleHost 绘制。
    Item {
        id: panel

        readonly property real targetWidth: host.contentWidth > 0
            ? host.contentWidth : 10
        property real deformX: 1.0
        property real deformY: 1.0

        x: BarState.yieldShift
            + (BarState.launcherOpen ? BarState.yieldDirection * BarState.yieldShift : 0)
        y: BarState.fullscreen ? 5 : 0

        width: targetWidth
        height: root.capsuleHeight

        opacity: 1.0

        function playDeform(): void {
            deformAnimation.stop();
            deformX = 1.0;
            deformY = 1.0;
            deformAnimation.start();
        }

        transform: Scale {
            xScale: panel.deformX
            yScale: panel.deformY
            origin.x: BarState.yieldDirection < 0 ? panel.width : 0
            origin.y: panel.height / 2
        }

        // ---- 弹簧物理 ----
        Behavior on width {
            SpringAnimation { spring: 3; damping: 0.62; mass: 0.8 }
        }
        Behavior on x {
            SpringAnimation { spring: 4; damping: 0.6; mass: 1.0 }
        }
        Behavior on y {
            SpringAnimation { spring: 4; damping: 0.7; mass: 1.0 }
        }

        SequentialAnimation {
            id: deformAnimation

            ParallelAnimation {
                NumberAnimation {
                    target: panel
                    property: "deformX"
                    to: 0.72
                    duration: 130
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: panel
                    property: "deformY"
                    to: 1.18
                    duration: 130
                    easing.type: Easing.OutQuad
                }
            }
            ParallelAnimation {
                NumberAnimation {
                    target: panel
                    property: "deformX"
                    to: 1.14
                    duration: 115
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: panel
                    property: "deformY"
                    to: 0.92
                    duration: 115
                    easing.type: Easing.OutCubic
                }
            }
            ParallelAnimation {
                SpringAnimation {
                    target: panel
                    property: "deformX"
                    to: 1.0
                    spring: 4
                    damping: 0.28
                    mass: 0.8
                    epsilon: 0.002
                }
                SpringAnimation {
                    target: panel
                    property: "deformY"
                    to: 1.0
                    spring: 4
                    damping: 0.28
                    mass: 0.8
                    epsilon: 0.002
                }
            }
        }

        Connections {
            target: BarState

            function onLauncherOpenChanged(): void {
                if (root.completed)
                    panel.playDeform();
            }

            function onDeformPulseChanged(): void {
                if (root.completed)
                    panel.playDeform();
            }
        }

        Binding {
            target: BarState
            property: "capsuleWidth"
            value: panel.width
        }

        Binding {
            target: BarState
            property: "screenWidth"
            value: root.screenW
        }

        Binding {
            target: BarState
            property: "capsuleCenterX"
            value: root.screenW / 2 - root.implicitWidth / 2
                + BarState.yieldShift + panel.width / 2
        }

        // 模块装载：清单驱动，左中右三区。集体避让由 ModuleHost 内部处理。
        ModuleHost {
            id: host

            configDir: Quickshell.env("HOME") + "/Projects/omibar"
            height: parent.height
            width: contentWidth
        }
    }
}
