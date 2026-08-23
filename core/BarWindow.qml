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
    // 下沉到 caelestia 凸条顶：gaps_out 底部 10 + caelestia border 厚度 10
    margins.bottom: 3

    // 胶囊几何（panel 内定义，这里引用做窗口尺寸）
    readonly property int capsuleHeight: 32
    readonly property int bottomMargin: 0

    implicitHeight: capsuleHeight + bottomMargin
    implicitWidth: panel.width

    // 排他：把普通窗口抬到胶囊顶之上（窗口底=1440-Z-gaps10=1394），
    // 排他 26（实测校准）：普通窗口底边=1390，与胶囊顶(1395)保持 5px 间距；
    // 胶囊底(1427)到 caelestia 凸条(1440)约 13px
    exclusiveZone: BarState.shouldYield ? 0 : 26

    Component.onCompleted: {
        console.log("[bar] completed. screen:", screenW, "x", screenH,
                    "SIG:", Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "(unset!)");
    }

    // 胶囊本体：宽度由模块内容驱动，水平居中
    Rectangle {
        id: panel

        readonly property real targetWidth: host.contentWidth > 0
            ? host.contentWidth : 10

        // 窗口本身就是胶囊大小（只锚 bottom，宽度随内容），panel 填满窗口即可。
        // 水平居中由 layer-shell 的锚定布局处理：不锚 left/right 时 Hyprland
        // 把 surface 放在屏幕水平中心（实测 xywh x=1262 ≈ 居中）。
        x: 0
        y: root.bottomMargin + (BarState.shouldYield ? root.implicitHeight + 12 : 0)

        width: targetWidth
        height: root.capsuleHeight

        radius: height / 2          // 全圆角胶囊
        color: "#0a0a0c"            // 灵动岛近黑：岛是"屏幕上的洞"，不跟主题

        opacity: BarState.shouldYield ? 0.0 : 1.0

        // ---- 弹簧物理 ----
        Behavior on width {
            SpringAnimation { spring: 3; damping: 0.62; mass: 0.8 }
        }
        Behavior on x {
            SpringAnimation { spring: 3; damping: 0.62; mass: 0.8 }
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

        // 模块装载：清单驱动，左中右三区
        ModuleHost {
            id: host

            configDir: Quickshell.env("HOME") + "/Projects/omibar"
            height: parent.height
            width: contentWidth
        }
    }
}
