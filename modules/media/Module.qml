// media module - fixed-width lyrics, controls, progress, and fallback spectrum.
pragma ComponentBehavior: Bound

import QtQuick
import "../../core"

Item {
    id: root

    required property BarState barState

    readonly property int lyricSize: 13
    readonly property int iconSize: 18
    readonly property int buttonSize: 24
    readonly property int spectrumBars: 18
    readonly property bool hovered: hoverHandler.hovered
    readonly property bool showLyrics: barState.mediaAvailable
        && barState.mediaLyricsAvailable
        && barState.mediaLyric !== ""
    readonly property string sourceLyric: showLyrics
        ? barState.mediaLyric
        : (barState.mediaAvailable ? "" : "没有播放中的媒体")

    property string displayedLyric: sourceLyric
    property real phase: 0

    implicitWidth: lyricMetrics.width
    implicitHeight: barState.moduleHeight
    width: implicitWidth
    height: implicitHeight
    clip: true

    function spectrumValue(index: int): real {
        const values = barState.mediaSpectrum ?? [];
        if (values.length > index)
            return Math.max(0, Math.min(1, values[index]));

        const left = Math.sin(phase + index * 0.72) * 0.5 + 0.5;
        const right = Math.sin(phase * 0.63 + index * 0.37) * 0.5 + 0.5;
        return 0.18 + left * 0.36 + right * 0.22;
    }

    onSourceLyricChanged: lyricSwap.restart()

    TextMetrics {
        id: lyricMetrics

        font.family: Theme.bodyFont
        font.pixelSize: root.lyricSize
        text: "一二三四五六七八九十一二三四五"
    }

    HoverHandler {
        id: hoverHandler
    }

    Timer {
        interval: 42
        running: root.barState.mediaAvailable && !root.showLyrics
        repeat: true
        onTriggered: root.phase += root.barState.mediaPlaying ? 0.22 : 0.055
    }

    Item {
        id: spectrum

        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 5
        anchors.bottomMargin: 6
        opacity: root.barState.mediaAvailable && !root.showLyrics && !root.hovered ? 1 : 0

        Repeater {
            model: root.spectrumBars

            delegate: Item {
                id: barSlot

                required property int index

                readonly property real amount: root.spectrumValue(index)
                readonly property real slotWidth: spectrum.width / root.spectrumBars

                x: index * slotWidth
                y: 0
                width: slotWidth
                height: spectrum.height

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 4 + barSlot.amount * (spectrum.height - 4)
                    radius: width / 2
                    color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.72)

                    Behavior on height {
                        NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5 + barSlot.amount * 9
                    height: 5 + barSlot.amount * 9
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18 + barSlot.amount * 0.22)
                    opacity: 0.9

                    Behavior on width {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }

                    Behavior on height {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }
                }
            }
        }

        Behavior on opacity {
            NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
        }
    }

    Text {
        id: lyricText

        anchors.centerIn: parent
        width: parent.width
        text: root.displayedLyric
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        color: root.barState.mediaAvailable ? Theme.fg : Theme.fgVariant
        renderType: Text.NativeRendering
        font.family: Theme.bodyFont
        font.pixelSize: root.lyricSize
        font.weight: Font.Medium
        opacity: root.showLyrics || !root.barState.mediaAvailable ? (root.hovered ? 0.18 : 1) : 0

        Behavior on opacity {
            NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
        }
    }

    Row {
        id: controls

        anchors.centerIn: parent
        spacing: 7
        opacity: root.hovered && root.barState.mediaAvailable ? 1 : 0

        MediaButton {
            iconName: "skip_previous"
            enabled: MediaController.active !== null && MediaController.active.canGoPrevious
            onClicked: MediaController.previous()
        }

        MediaButton {
            iconName: root.barState.mediaPlaying ? "pause" : "play_arrow"
            enabled: MediaController.active !== null && MediaController.active.canTogglePlaying
            onClicked: MediaController.toggle()
        }

        MediaButton {
            iconName: "skip_next"
            enabled: MediaController.active !== null && MediaController.active.canGoNext
            onClicked: MediaController.next()
        }

        Behavior on opacity {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 2
        radius: 1
        color: Qt.rgba(Theme.outlineVariant.r, Theme.outlineVariant.g, Theme.outlineVariant.b, 0.42)
        opacity: root.barState.mediaAvailable ? 1 : 0

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * root.barState.mediaProgress
            radius: parent.radius
            color: Theme.primary

            Behavior on width {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
        }

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
    }

    SequentialAnimation {
        id: lyricSwap

        NumberAnimation {
            target: lyricText
            property: "opacity"
            to: 0
            duration: 80
            easing.type: Easing.OutCubic
        }

        PropertyAction {
            target: root
            property: "displayedLyric"
            value: root.sourceLyric
        }

        NumberAnimation {
            target: lyricText
            property: "opacity"
            to: root.showLyrics || !root.barState.mediaAvailable ? 1 : 0
            duration: 130
            easing.type: Easing.OutCubic
        }
    }

    component MediaButton: Item {
        id: buttonRoot

        required property string iconName
        signal clicked()

        width: root.buttonSize
        height: root.buttonSize
        opacity: enabled ? 1 : 0.35

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: mouseArea.containsMouse
                ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.16)
                : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08)

            Behavior on color {
                ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }

        Text {
            anchors.centerIn: parent
            text: buttonRoot.iconName
            color: Theme.fg
            renderType: Text.NativeRendering
            font.family: Theme.iconFont
            font.pixelSize: root.iconSize
            font.variableAxes: { "FILL": 1, "GRAD": -20 }
        }

        MouseArea {
            id: mouseArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: buttonRoot.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (buttonRoot.enabled)
                    buttonRoot.clicked();
            }
        }
    }
}
