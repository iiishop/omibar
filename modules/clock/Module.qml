// clock module - compact Caelestia-style time block.
pragma ComponentBehavior: Bound

import QtQuick
import "../../core"

Item {
    id: root

    required property BarState barState

    readonly property int iconSize: 18
    readonly property int timeSize: 15
    readonly property int dateSize: 10
    readonly property int horizontalGap: 8
    readonly property int verticalGap: -2
    property string timeFormat: "HH:mm"
    property string dateFormat: "ddd d"
    property date now: new Date()

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Row {
        id: layout

        anchors.centerIn: parent
        spacing: root.horizontalGap

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "calendar_month"
            color: Theme.tertiary
            renderType: Text.NativeRendering
            font.family: Theme.iconFont
            font.pixelSize: root.iconSize
            font.variableAxes: { "FILL": 1, "GRAD": -25 }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.verticalGap

            Text {
                text: Qt.formatDateTime(root.now, root.timeFormat)
                color: Theme.fg
                renderType: Text.NativeRendering
                font.family: Theme.bodyFont
                font.pixelSize: root.timeSize
                font.weight: Font.Medium
            }

            Text {
                text: Qt.formatDateTime(root.now, root.dateFormat).toLowerCase()
                color: Theme.tertiary
                renderType: Text.NativeRendering
                font.family: Theme.bodyFont
                font.pixelSize: root.dateSize
                font.weight: Font.Normal
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }
}
