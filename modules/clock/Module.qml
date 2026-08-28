// clock module - compact date display with hover month calendar.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../core"

Item {
    id: root

    required property BarState barState

    readonly property int iconSize: 18
    readonly property int dateSize: 10
    readonly property int horizontalGap: 8
    readonly property string dateText: Qt.formatDate(now, qsTr("yyyy年MM月dd日"))
    readonly property bool calendarActive: moduleHover.hovered || calendarHover.hovered
    property date now: new Date()
    property bool calendarOpen: false
    property bool calendarVisible: false

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight
    width: implicitWidth
    height: implicitHeight

    function showCalendar(): void {
        hideCalendar.stop();
        closeCalendar.stop();
        calendarPopup.anchor.updateAnchor();
        if (calendarVisible) {
            calendarOpen = true;
            return;
        }

        calendarOpen = false;
        calendarVisible = true;
        Qt.callLater(() => {
            if (root.calendarVisible && root.calendarActive)
                root.calendarOpen = true;
        });
    }

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
                root.showCalendar();
            } else {
                hideCalendar.restart();
            }
        }
    }

    Timer {
        id: hideCalendar

        interval: 140
        onTriggered: {
            if (!root.calendarActive) {
                root.calendarOpen = false;
                closeCalendar.restart();
            }
        }
    }

    Timer {
        id: closeCalendar

        interval: 240
        onTriggered: {
            if (!root.calendarActive && !root.calendarOpen)
                root.calendarVisible = false;
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

        implicitWidth: calendar.width
        implicitHeight: calendar.height
        visible: root.calendarVisible
        color: "transparent"

        anchor.item: root
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.margins.top: 18

        MonthCalendar {
            id: calendar

            now: root.now
            open: root.calendarOpen

            HoverHandler {
                id: calendarHover

                onHoveredChanged: {
                    if (hovered) {
                        root.showCalendar();
                    } else {
                        hideCalendar.restart();
                    }
                }
            }
        }
    }
}
