// MonthCalendar - current-month panel, revealed from the clock below it.
pragma ComponentBehavior: Bound

import QtQuick
import "../../core"

Item {
    id: root

    required property date now
    property BarState barState: BarState
    property bool open: false

    readonly property int enterDuration: 460
    readonly property int exitDuration: 300
    readonly property int padding: 20
    readonly property int outerMargin: 12
    readonly property int cellSize: 36
    readonly property int gridGap: 4
    readonly property int gridWidth: cellSize * 7 + gridGap * 6
    readonly property int riseDistance: 16
    readonly property real closedWidthScale: 0.24
    readonly property real closedHeightScale: 0.06
    property real reveal: 0
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

    width: gridWidth + padding * 2 + outerMargin * 2
    height: card.height + outerMargin * 2

    function dayAt(index: int): int {
        const day = index - firstWeekday + 1;
        return day >= 1 && day <= daysInMonth ? day : 0;
    }

    function requestDate(key: string): void {
        if (!barState.noteAvailable || !(barState.todoCountByDate[key] > 0)) return;
        barState.noteDateRequest = key;
        barState.noteDateRequestSerial++;
    }

    state: open ? "open" : ""
    states: State {
        name: "open"
        PropertyChanges { root.reveal: 1 }
    }
    transitions: [Transition {
        from: ""
        to: "open"
        NumberAnimation {
            property: "reveal"
            duration: root.enterDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.2, 0.85, 0.25, 1.08, 1, 1]
        }
    }, Transition {
        from: "open"
        to: ""
        NumberAnimation {
            property: "reveal"
            duration: root.exitDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.55, 0, 0.8, 0.3, 1, 1]
        }
    }]

    Item {
        id: surface

        anchors.fill: parent
        opacity: Math.min(1, root.reveal * 3)
        transform: [
            Translate { y: root.riseDistance * (1 - root.reveal) },
            Scale {
                origin.x: root.width / 2
                origin.y: root.height
                // Width unfolds first; height follows, keeping the base pinned.
                xScale: root.closedWidthScale + (1 - root.closedWidthScale)
                    * root.reveal * (2 - root.reveal)
                yScale: root.closedHeightScale + (1 - root.closedHeightScale) * root.reveal
            }
        ]
        // Keep the hover target fixed while only the visual surface moves.
        layer.enabled: root.reveal > 0 && root.reveal !== 1
        layer.smooth: true

        Repeater {
            model: 3

            Rectangle {
                required property int index

                anchors.centerIn: card
                anchors.verticalCenterOffset: 3
                width: card.width + (index + 1) * 6
                height: card.height + (index + 1) * 6
                radius: card.radius + (index + 1) * 3
                color: Qt.rgba(0, 0, 0, 0.035)
                Accessible.ignored: true
            }
        }

        Rectangle {
            id: card

            x: root.outerMargin
            y: root.outerMargin
            width: root.gridWidth + root.padding * 2
            height: content.implicitHeight + root.padding * 2
            radius: 24
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.surfaceContainerHigh }
                GradientStop { position: 1; color: Theme.surfaceContainer }
            }
            border.width: 1
            border.color: Qt.alpha(Theme.outline, 0.3)

            Column {
                id: content

                x: root.padding
                y: root.padding
                width: root.gridWidth
                spacing: 16

                Item {
                    width: parent.width
                    height: 70

                    Text {
                        id: dateNumber

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDate(root.now, "dd")
                        color: Theme.primary
                        font.family: Theme.bodyFont
                        font.pixelSize: 54
                        font.weight: Font.Light
                    }

                    Column {
                        anchors.left: dateNumber.right
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5

                        Text {
                            text: Qt.formatDate(root.now, qsTr("yyyy年M月"))
                            color: Theme.fg
                            font.family: Theme.bodyFont
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: Qt.formatDate(root.now, qsTr("dddd"))
                            color: Theme.fgVariant
                            font.family: Theme.bodyFont
                            font.pixelSize: 12
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: 4
                        width: 40
                        height: 22
                        radius: 11
                        color: Qt.alpha(Theme.primary, 0.12)

                        Text {
                            anchors.centerIn: parent
                            text: qsTr("今日")
                            color: Theme.primary
                            font.family: Theme.bodyFont
                            font.pixelSize: 10
                            font.weight: Font.Medium
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Qt.alpha(Theme.outlineVariant, 0.65)
                }

                Column {
                    width: parent.width
                    spacing: 8

                    Row {
                        spacing: root.gridGap

                        Repeater {
                            model: root.weekdays

                            Text {
                                required property string modelData
                                required property int index

                                width: root.cellSize
                                height: 20
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: modelData
                                color: index % 7 >= 5 ? Theme.tertiary : Theme.fgVariant
                                font.family: Theme.bodyFont
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }
                        }
                    }

                    Grid {
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
                                readonly property string dateKey: Qt.formatDate(
                                    new Date(root.now.getFullYear(), root.now.getMonth(), day), "yyyy-MM-dd")
                                readonly property int todoCount: inMonth ? root.barState.todoCountByDate[dateKey] ?? 0 : 0
                                readonly property int overdueCount: root.barState.overdueCountByDate[dateKey] ?? 0
                                readonly property bool clickable: root.barState.noteAvailable && todoCount > 0

                                width: root.cellSize
                                height: root.cellSize
                                radius: 12
                                color: isToday ? Theme.primary
                                    : dayHover.hovered && clickable ? Theme.surfaceContainerHighest
                                    : inMonth && isWeekend ? Qt.alpha(Theme.tertiary, 0.06)
                                    : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: dayCell.inMonth ? String(dayCell.day) : ""
                                    color: dayCell.isToday ? Theme.surface
                                        : dayCell.isWeekend ? Theme.tertiary : Theme.fg
                                    font.family: Theme.bodyFont
                                    font.pixelSize: 13
                                    font.weight: dayCell.isToday ? Font.Bold : Font.Normal
                                }

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 3
                                    spacing: 2
                                    Accessible.ignored: true
                                    Repeater {
                                        model: Math.min(dayCell.todoCount, 5)
                                        Rectangle {
                                            required property int index
                                            width: 3
                                            height: 3
                                            radius: 1.5
                                            color: dayCell.isToday ? Theme.surface
                                                : index < dayCell.overdueCount ? Theme.error : Theme.tertiary
                                        }
                                    }
                                }
                                activeFocusOnTab: clickable
                                Accessible.role: Accessible.Button
                                Accessible.name: qsTr("%1，%2 项待办，%3 项已到期")
                                    .arg(dateKey).arg(todoCount).arg(overdueCount)
                                Accessible.onPressAction: root.requestDate(dateKey)
                                border.width: activeFocus ? 1 : 0
                                border.color: Theme.primary
                                Keys.onReturnPressed: root.requestDate(dateKey)
                                Keys.onSpacePressed: root.requestDate(dateKey)
                                HoverHandler { id: dayHover; cursorShape: dayCell.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor }
                                TapHandler {
                                    enabled: dayCell.clickable
                                    onTapped: root.requestDate(dayCell.dateKey)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
