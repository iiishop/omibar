// notifications module - compact Caelestia-style inbox status.
pragma ComponentBehavior: Bound

import QtQuick
import "../../core"

Item {
    id: root

    required property BarState barState

    readonly property int count: barState.notificationCount
    readonly property bool dnd: barState.notificationDnd
    readonly property bool hasUnread: count > 0
    readonly property string iconName: dnd ? "notifications_paused"
        : (hasUnread ? "notifications_unread" : "notifications")
    readonly property string statusText: dnd ? "quiet"
        : (hasUnread ? (count > 99 ? "99+" : String(count)) : "clear")
    readonly property color accent: dnd ? Theme.primary : Theme.secondary
    readonly property int iconSize: 18
    readonly property int labelSize: 12
    readonly property int gap: 7

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight
    width: implicitWidth
    height: implicitHeight
    visible: true

    Row {
        id: layout

        anchors.centerIn: parent
        spacing: root.gap

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.iconName
            color: root.accent
            renderType: Text.NativeRendering
            font.family: Theme.iconFont
            font.pixelSize: root.iconSize
            font.variableAxes: { "FILL": root.hasUnread || root.dnd ? 1 : 0, "GRAD": -25 }

            Behavior on color {
                ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.statusText
            color: root.hasUnread || root.dnd ? Theme.fg : Theme.fgVariant
            renderType: Text.NativeRendering
            font.family: Theme.bodyFont
            font.pixelSize: root.labelSize
            font.weight: root.hasUnread || root.dnd ? Font.Medium : Font.Normal

            Behavior on color {
                ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: CaelestiaBridge.openSidebar()
    }

    Component.onCompleted: CaelestiaBridge.refreshNotifications()
}
