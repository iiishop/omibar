// MonthCalendar - compact current-month panel for the clock module.
pragma ComponentBehavior: Bound

import QtQuick
import "../../core"

Item {
    id: root

    required property date now
    property bool open: false

    readonly property int padding: 18
    readonly property int cellSize: 36
    readonly property int gridGap: 5
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

    width: gridWidth + padding * 2 + 18
    height: card.height
    opacity: open ? 1 : 0
    y: open ? 0 : 14
    // 离屏渲染：动画期间只搬纹理，避免整棵树（42 格）每帧重光栅化
    layer.enabled: true
    layer.smooth: true
    transform: Scale {
        id: genieScale

        origin.x: root.width / 2
        origin.y: root.height
        xScale: root.open ? 1 : 0.34
        yScale: root.open ? 1 : 0.18

        // caelestia expressiveDefaultSpatial 曲线：c1(0.38, 1.21) 超调 → 果冻 q 弹
        Behavior on xScale {
            NumberAnimation {
                duration: 280
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [ 0.38, 1.21, 0.22, 1, 1, 1 ]
            }
        }

        Behavior on yScale {
            NumberAnimation {
                duration: 280
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [ 0.38, 1.21, 0.22, 1, 1, 1 ]
            }
        }
    }

    function dayAt(index: int): int {
        const day = index - firstWeekday + 1;
        return day >= 1 && day <= daysInMonth ? day : 0;
    }

    function monthTitle(): string {
        return Qt.formatDate(now, qsTr("yyyy年M月"));
    }

    Rectangle {
        id: card

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.gridWidth + root.padding * 2
        height: header.height + weekdayRow.height + calendarGrid.height
            + root.padding * 2 + 16
        radius: 22
        color: Qt.alpha(Theme.surfaceContainer, 0.96)
        border.width: 1
        border.color: Qt.alpha(Theme.outlineVariant, 0.8)

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: Qt.alpha(Theme.surfaceContainerHigh, 0.28)
            border.width: 1
            border.color: Qt.alpha(Theme.primary, 0.14)
        }

        Row {
            id: header

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: root.padding
            height: 36
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "calendar_month"
                color: Theme.tertiary
                renderType: Text.NativeRendering
                font.family: Theme.iconFont
                font.pixelSize: 20
                font.variableAxes: { "FILL": 1, "GRAD": -25 }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.monthTitle()
                color: Theme.fg
                renderType: Text.NativeRendering
                font.family: Theme.bodyFont
                font.pixelSize: 17
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
                font.pixelSize: 12
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
                    height: 20
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: modelData
                    color: Theme.outline
                    renderType: Text.NativeRendering
                    font.family: Theme.bodyFont
                    font.pixelSize: 11
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
                    radius: 12
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
                        font.pixelSize: dayCell.isToday ? 15 : 13
                        font.weight: dayCell.isToday ? Font.DemiBold : Font.Medium
                    }
                }
            }
        }
    }

    Behavior on opacity {
        OpacityAnimator { duration: 180; easing.type: Easing.OutCubic }
    }

    Behavior on y {
        NumberAnimation {
            duration: 280
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [ 0.38, 1.21, 0.22, 1, 1, 1 ]
        }
    }

}
