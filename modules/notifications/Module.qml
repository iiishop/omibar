// notifications 模块 — 显示 caelestia 未读通知数或 DND 状态。
pragma ComponentBehavior: Bound

import QtQuick
import "../../core"

Item {
    id: root

    required property BarState barState

    readonly property int count: barState.notificationCount
    readonly property bool dnd: barState.notificationDnd
    readonly property string countText: count > 99 ? "99+" : String(count)

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    width: implicitWidth
    height: implicitHeight
    visible: true

    Row {
        id: row

        spacing: 6
        anchors.centerIn: parent

        Text {
            text: root.dnd ? "DND" : "N"
            color: root.dnd ? Theme.primary : Theme.fgVariant
            font.family: "monospace"
            font.pixelSize: 12
            font.bold: root.dnd
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.countText
            color: Theme.fg
            font.family: "monospace"
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: CaelestiaBridge.openSidebar()
    }

    Component.onCompleted: CaelestiaBridge.refreshNotifications()
}
