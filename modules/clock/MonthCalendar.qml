// MonthCalendar - compact current-month panel for the clock module.
pragma ComponentBehavior: Bound

import QtQuick
import "../../core"

Rectangle {
    id: root

    required property date now

    readonly property int padding: 14
    readonly property int cellSize: 30
    readonly property int gridGap: 4
    readonly property int gridWidth: cellSize * 7 + gridGap * 6
    readonly property int firstWeekday: {
        const first = new Date(now.getFullYear(), now.getMonth(), 1);
        return (first.getDay() + 6) % 7;
    }
    readonly property int daysInMonth:
        new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate()
    readonly property int today: now.getDate()
    readonly property var weekdays: [
        qsTr("一"), qsTr("二"), qsTr("三"), qsTr("四"),
        qsTr("五"), qsTr("六"), qsTr("日")
    ]

    width: gridWidth + padding * 2
    height: header.height + weekdayRow.height + calendarGrid.height
        + padding * 2 + 16
    radius: 18
    color: Theme.surfaceContainer
    border.width: 1
    border.color: Qt.alpha(Theme.outlineVariant, 0.8)

    function dayAt(index: int): int {
        const day = index - firstWeekday + 1;
        return day >= 1 && day <= daysInMonth ? day : 0;
    }

    function monthTitle(): string {
        return Qt.formatDate(now, qsTr("yyyy年M月"));
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: parent.radius - 1
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(Theme.primary, 0.14)
    }

    Row {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.padding
        height: 32
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "calendar_month"
            color: Theme.tertiary
            renderType: Text.NativeRendering
            font.family: Theme.iconFont
            font.pixelSize: 18
            font.variableAxes: { "FILL": 1, "GRAD": -25 }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.monthTitle()
            color: Theme.fg
            renderType: Text.NativeRendering
            font.family: Theme.bodyFont
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 6
            radius: 3
            color: Theme.primary
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDate(root.now, qsTr("dddd"))
            color: Theme.fgVariant
            renderType: Text.NativeRendering
            font.family: Theme.bodyFont
            font.pixelSize: 11
            font.weight: Font.Medium
        }
    }

    Row {
        id: weekdayRow

        anchors.top: header.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.gridGap

        Repeater {
            model: root.weekdays

            Text {
                required property string modelData

                width: root.cellSize
                height: 18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData
                color: Theme.outline
                renderType: Text.NativeRendering
                font.family: Theme.bodyFont
                font.pixelSize: 10
                font.weight: Font.Medium
            }
        }
    }

    Grid {
        id: calendarGrid

        anchors.top: weekdayRow.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        columns: 7
        rows: 6
        spacing: root.gridGap

        Repeater {
            model: 42

            Rectangle {
                id: dayCell

                required property int index
                readonly property int day: root.dayAt(index)
                readonly property bool inMonth: day > 0
                readonly property bool isToday: inMonth && day === root.today
                readonly property bool isWeekend: index % 7 >= 5

                width: root.cellSize
                height: root.cellSize
                radius: 10
                color: isToday ? Theme.primary
                    : inMonth && isWeekend ? Qt.alpha(Theme.tertiaryContainer, 0.18)
                    : "transparent"
                border.width: isToday ? 0 : 1
                border.color: inMonth ? Qt.alpha(Theme.outlineVariant, 0.35)
                    : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: dayCell.inMonth ? String(dayCell.day) : ""
                    color: dayCell.isToday ? Theme.surface
                        : dayCell.isWeekend ? Theme.tertiary
                        : Theme.fg
                    renderType: Text.NativeRendering
                    font.family: Theme.bodyFont
                    font.pixelSize: dayCell.isToday ? 13 : 12
                    font.weight: dayCell.isToday ? Font.DemiBold : Font.Medium
                }
            }
        }
    }
}
