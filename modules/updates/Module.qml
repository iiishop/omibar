// updates module - readable status with per-source check details.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../core"

Item {
    id: root

    required property BarState barState

    readonly property int iconSize: 18
    readonly property int labelSize: 11
    readonly property int hoverGraceMs: 220
    readonly property bool checking: barState.updateState === "checking"
    readonly property bool failed: barState.updateState === "error"
        || barState.updateState === "partial_failure"
    readonly property color accent: failed ? Theme.tertiary : Theme.primary
    readonly property var titles: ({
        unchecked: qsTr("尚未检查"),
        checking: qsTr("正在检查"),
        available: qsTr("%1 项可更新").arg(barState.updateTotalCount),
        up_to_date: qsTr("已是最新"),
        busy: qsTr("等待包管理器"),
        partial_failure: qsTr("结果不完整"),
        error: qsTr("检查失败")
    })
    readonly property var descriptions: ({
        unchecked: qsTr("尚未检查官方仓库和 AUR。"),
        checking: qsTr("正在查询官方仓库和 AUR，旧结果会单独标注。"),
        available: qsTr("官方仓库与 AUR 均已检查，下面是各来源的结果。"),
        up_to_date: qsTr("本次检查中，官方仓库和 AUR 均无可用更新。"),
        busy: qsTr("包管理器数据库被占用，暂时无法检查。空闲后会自动重试。"),
        partial_failure: barState.updateTotalCount > 0
            ? qsTr("已确认 %1 项更新；另一个来源未完成检查，总数可能更多。")
                .arg(barState.updateTotalCount)
            : qsTr("一个来源检查成功，另一个未完成，暂时无法确认是否全部最新。"),
        error: qsTr("未能取得本次检查结果，请查看各来源的原因后重试。")
    })
    readonly property string title: titles[barState.updateState]
    readonly property string description: descriptions[barState.updateState]
    readonly property string iconName: checking ? "sync"
        : failed ? "error_outline"
        : barState.updateState === "up_to_date" ? "check_circle"
        : barState.updateState === "busy" ? "hourglass_top" : "system_update_alt"
    property bool popupOpen: false
    property bool pinned: false

    implicitWidth: layout.implicitWidth
    implicitHeight: 24
    width: implicitWidth
    height: implicitHeight
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: qsTr("系统更新：%1，打开详情").arg(title)
    Accessible.onPressAction: toggleDetails()
    Keys.onReturnPressed: toggleDetails()
    Keys.onSpacePressed: toggleDetails()
    Keys.onEscapePressed: closeDetails()

    function toggleDetails(): void {
        pinned = !pinned;
        popupOpen = pinned;
    }

    function closeDetails(): void {
        pinned = false;
        popupOpen = false;
    }

    Row {
        id: layout
        anchors.centerIn: parent
        spacing: 7

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.iconName
            color: root.accent
            font.family: Theme.iconFont
            font.pixelSize: root.iconSize
            Accessible.ignored: true
            RotationAnimator on rotation {
                running: root.checking && root.visible
                from: 0
                to: 360
                duration: 1100
                loops: Animation.Infinite
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("更新 · %1").arg(root.title)
            color: Theme.fg
            font.family: Theme.bodyFont
            font.pixelSize: root.labelSize
            font.weight: Font.Medium
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.popupOpen ? "expand_more" : "expand_less"
            color: Theme.fgVariant
            font.family: Theme.iconFont
            font.pixelSize: 14
            Accessible.ignored: true
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: 6
        color: "transparent"
        border.width: root.activeFocus ? 1 : 0
        border.color: Theme.primary
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hovered) {
                hideDetails.stop();
                root.popupOpen = true;
            } else {
                hideDetails.restart();
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleDetails()
    }

    Timer {
        id: hideDetails
        interval: root.hoverGraceMs
        onTriggered: {
            if (!hover.hovered && !detailsHover.hovered && !root.pinned)
                root.popupOpen = false;
        }
    }

    Component.onCompleted: UpdateService.ensureStarted()

    PopupWindow {
        implicitWidth: details.width
        implicitHeight: details.height
        visible: root.popupOpen
        color: "transparent"
        anchor.item: root
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.margins.top: 12

        UpdateDetails {
            id: details
            barState: root.barState
            title: root.title
            description: root.description
            accent: root.accent
            checking: root.checking
            onRefreshRequested: UpdateService.refresh()
            onCloseRequested: root.closeDetails()

            HoverHandler {
                id: detailsHover
                onHoveredChanged: {
                    if (hovered)
                        hideDetails.stop();
                    else
                        hideDetails.restart();
                }
            }
        }
    }
}
