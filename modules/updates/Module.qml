// updates module - pacman and AUR upgrade counts.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import "../../core"

Item {
    id: root

    required property BarState barState

    readonly property int iconSize: 17
    readonly property int labelSize: 10
    readonly property int numberSize: 14
    readonly property int gap: 5
    readonly property int chipWidth: 34
    readonly property int chipHeight: 22
    readonly property int chipRadius: 9
    readonly property int refreshInterval: 30 * 60 * 1000
    readonly property bool checking: pacmanProc.running || paruProc.running
    readonly property color pacmanColor: pacmanCount > 0 ? Theme.primary : Theme.fgVariant
    readonly property color paruColor: paruCount > 0 ? Theme.tertiary : Theme.fgVariant
    readonly property string iconName: checking ? "sync" : (totalCount > 0
        ? "download_for_offline" : "verified")
    readonly property int totalCount: Math.max(0, pacmanCount) + Math.max(0, paruCount)

    property int pacmanCount: -1
    property int paruCount: -1
    property string pacmanOutput: ""
    property string paruOutput: ""
    property real hoverProgress: hover.hovered ? 1 : 0

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Behavior on hoverProgress {
        NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
    }

    function countLines(output: string): int {
        const text = output.trim();
        return text === "" ? 0 : text.split("\n").length;
    }

    function refresh(): void {
        if (!pacmanProc.running) {
            pacmanOutput = "";
            pacmanProc.running = true;
        }
        if (!paruProc.running) {
            paruOutput = "";
            paruProc.running = true;
        }
    }

    Row {
        id: layout

        anchors.centerIn: parent
        spacing: root.gap

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.iconName
            color: root.checking ? Theme.secondary
                : (root.totalCount > 0 ? Theme.primary : Theme.fgVariant)
            renderType: Text.NativeRendering
            font.family: Theme.iconFont
            font.pixelSize: root.iconSize
            font.variableAxes: { "FILL": root.totalCount > 0 || root.checking ? 1 : 0, "GRAD": -25 }
        }

        PackageCount {
            label: "P"
            count: root.pacmanCount
            accent: root.pacmanColor
            fill: Qt.alpha(Theme.primary, root.pacmanCount > 0 ? 0.18 : 0.07)
        }

        PackageCount {
            label: "A"
            count: root.paruCount
            accent: root.paruColor
            fill: Qt.alpha(Theme.tertiary, root.paruCount > 0 ? 0.18 : 0.07)
        }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.refresh()
    }

    Timer {
        interval: root.refreshInterval
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: pacmanProc

        command: ["sh", "-c", "command -v checkupdates >/dev/null || exit 127; checkupdates 2>/dev/null || true"]
        stdout: SplitParser {
            onRead: data => root.pacmanOutput += data
        }
        stderr: SplitParser {}
        onExited: (code, status) => root.pacmanCount =
            code === 127 ? -1 : root.countLines(root.pacmanOutput)
    }

    Process {
        id: paruProc

        command: ["sh", "-c", "command -v paru >/dev/null || exit 127; paru -Qua 2>/dev/null || true"]
        stdout: SplitParser {
            onRead: data => root.paruOutput += data
        }
        stderr: SplitParser {}
        onExited: (code, status) => root.paruCount =
            code === 127 ? -1 : root.countLines(root.paruOutput)
    }

    Component.onCompleted: refresh()

    component PackageCount: Item {
        required property string label
        required property int count
        required property color accent
        required property color fill

        readonly property string countText: count < 0
            ? (root.checking ? "..." : "--") : String(count)

        implicitWidth: root.chipWidth
        implicitHeight: root.chipHeight
        width: implicitWidth
        height: implicitHeight

        Rectangle {
            anchors.fill: parent
            radius: root.chipRadius
            color: Qt.tint(fill, Qt.alpha(accent, root.hoverProgress * 0.08))
            border.width: 1
            border.color: Qt.alpha(accent, count > 0
                ? 0.48 + root.hoverProgress * 0.28
                : 0.18 + root.hoverProgress * 0.2)

            Behavior on color {
                ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            Behavior on border.color {
                ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: 12
            radius: 2
            color: count > 0 ? accent : Theme.outline

            Behavior on color {
                ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
        }

        Row {
            id: chipRow

            anchors.centerIn: parent
            spacing: 4

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: label
                color: count > 0 ? Qt.alpha(accent, 0.95) : Theme.outline
                renderType: Text.NativeRendering
                font.family: Theme.bodyFont
                font.pixelSize: root.labelSize
                font.weight: Font.DemiBold
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: countText
                color: accent
                renderType: Text.NativeRendering
                font.family: Theme.monoFont
                font.pixelSize: root.numberSize
                font.weight: count > 0 ? Font.Bold : Font.DemiBold

                Behavior on color {
                    ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
