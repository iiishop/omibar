// BarWindow — 底部灵动岛式 bar 的 layer-shell 宿主窗口。
//
// A fixed-width bottom strip keeps compositor geometry out of capsule animations.
// The input mask follows the bands; transparent space passes pointer events through.
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
    anchors.left: true
    anchors.right: true
    // 贴近屏幕底部，避开 Hyprland gaps。
    margins.bottom: bottomGap - surfacePadding

    readonly property real capsuleHeight: BarState.moduleHeight
    readonly property int bottomGap: 3
    readonly property int surfacePadding: Math.ceil(capsuleHeight * host.resizeHeightLimit / 2)
    // 灵动岛从胶囊向上生长。窗口高度必须固定预留：layer surface 每次 resize
    // 都会重新提交 surface，跟着动画改高度会瞬移并掉帧。
    // 收起时多出来的区域是透明的，由 mask 决定不接收输入。
    readonly property int islandReserve: 208
    property bool completed: false

    implicitHeight: capsuleHeight + surfacePadding * 2 + islandReserve
    mask: host.inputRegion

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

        // Preserve fractional centers throughout width interpolation.
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.alignWhenCentered: false
        // 窗口高度会随灵动岛展开变化，胶囊必须钉在窗口底边，
        // 否则窗口一长，整条 bar 会被顶上去。
        anchors.bottom: parent.bottom
        anchors.bottomMargin: bottomOffset
        property real bottomOffset: root.surfacePadding + (BarState.fullscreen ? 5 : 0)

        width: targetWidth
        height: root.capsuleHeight

        opacity: 1.0

        // ---- 弹簧物理 ----
        Behavior on bottomOffset {
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

        // 模块装载：清单驱动，左右两个避让 band。水平避让由各胶囊分别处理。
        ModuleHost {
            id: host

            configDir: Quickshell.env("HOME") + "/Projects/omibar"
            neutralScreenX: root.screenW / 2 - panel.width / 2
            movementOriginX: BarState.launcherCenterX
            height: parent.height
            width: contentWidth
        }
    }
}
