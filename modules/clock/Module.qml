// clock module - compact date display with hover month calendar.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../core"

Item {
    id: root

    required property BarState barState

    readonly property int iconSize: 18
    readonly property int timeSize: 15
    readonly property int dateSize: 10
    readonly property int horizontalGap: 8
    readonly property int verticalGap: -2
    readonly property string timeText: Qt.formatDateTime(now, "HH:mm")
    readonly property string dateText: Qt.formatDate(now, qsTr("yyyy年MM月dd日"))
    readonly property bool calendarActive: moduleHover.hovered || calendarHover.hovered
    property date now: new Date()
    property bool calendarOpen: false

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
                text: root.timeText
                color: Theme.fg
                renderType: Text.NativeRendering
                font.family: Theme.bodyFont
                font.pixelSize: root.timeSize
                font.weight: Font.Medium
            }

            Text {
                text: root.dateText
                color: Theme.tertiary
                renderType: Text.NativeRendering
                font.family: Theme.bodyFont
                font.pixelSize: root.dateSize
                font.weight: Font.Normal
            }
        }
    }

    HoverHandler {
        id: moduleHover

        onHoveredChanged: {
            if (hovered) {
                hideCalendar.stop();
                root.calendarOpen = true;
                calendarPopup.anchor.updateAnchor();
            } else {
                hideCalendar.restart();
            }
        }
    }

    Timer {
        id: hideCalendar

        interval: 140
        onTriggered: {
            if (!root.calendarActive)
                root.calendarOpen = false;
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    PopupWindow {
        id: calendarPopup

        width: calendar.width
        height: calendar.height
        visible: root.calendarOpen
        color: "transparent"

        anchor.item: root
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.margins.top: 10

        MonthCalendar {
            id: calendar

            now: root.now
            opacity: root.calendarOpen ? 1 : 0
            scale: root.calendarOpen ? 1 : 0.96
            transformOrigin: Item.Bottom

            HoverHandler {
                id: calendarHover

                onHoveredChanged: {
                    if (hovered) {
                        hideCalendar.stop();
                        root.calendarOpen = true;
                    } else {
                        hideCalendar.restart();
                    }
                }
            }

            Behavior on opacity {
                OpacityAnimator { duration: 150; easing.type: Easing.OutCubic }
            }

            Behavior on scale {
                NumberAnimation { duration: 180; easing.type: Easing.OutBack }
            }
        }
    }
}
