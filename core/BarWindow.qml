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

    implicitHeight: capsuleHeight
    implicitWidth: panel.width

    exclusiveZone: BarState.shouldYield ? 0 : 26

    Component.onCompleted: {
        console.log("[bar] completed. screen:", screenW, "x", screenH,
                    "SIG:", Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "(unset!)");
    }

    // 胶囊本体：宽度由模块内容驱动
    Rectangle {
        id: panel

        readonly property real targetWidth: host.contentWidth > 0
            ? host.contentWidth : 10

        x: BarState.yieldOffsetX
        y: BarState.shouldYield ? root.implicitHeight + 12 : 0

        width: targetWidth
        height: root.capsuleHeight

        radius: height / 2          // 全圆角胶囊
        color: "#0a0a0c"            // 灵动岛近黑：岛是"屏幕上的洞"，不跟主题

        opacity: BarState.shouldYield ? 0.55 : 1.0

        // 水平形变：避让时压缩。transformOrigin 设为右端——压缩向右端收，
        // 视觉上像被外部浮层从右侧"挤"了一下。
        transform: Scale {
            xScale: BarState.yieldScaleX
            origin.x: panel.width      // 右缘为原点
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
        Behavior on opacity {
            NumberAnimation {
                duration: BarState.shouldYield ? 150 : 250
                easing.type: Easing.OutQuad
            }
        }

        Binding {
            target: BarState
            property: "capsuleWidth"
            value: panel.width
        }

        // 模块装载：清单驱动，左中右三区。集体避让由 ModuleHost 内部处理。
        ModuleHost {
            id: host

            configDir: Quickshell.env("HOME") + "/Projects/omibar"
            height: parent.height
            width: contentWidth
            capsuleTargetWidth: panel.targetWidth
        }
    }
}
