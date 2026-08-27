// media module - fixed-width lyrics, controls, progress, and fallback spectrum.
pragma ComponentBehavior: Bound

import QtQuick
import "../../core"

Item {
    id: root

    required property BarState barState

    readonly property int lyricSize: 13
    readonly property int metadataSize: 10
    readonly property int iconSize: 18
    readonly property int buttonSize: 24
    readonly property int controlGap: 5
    readonly property int spectrumBars: 18
    readonly property int sideSpectrumBars: 7
    readonly property int lyricSideInset: showLyrics ? 20 : 0
    readonly property int metadataInset: showMetadata ? 18 : 7
    readonly property bool hovered: hoverHandler.hovered
    readonly property bool hasTitle: barState.mediaTitle !== ""
    readonly property bool hasArtist: barState.mediaArtist !== ""
    readonly property bool showMetadata: barState.mediaAvailable && (hasTitle || hasArtist)
    readonly property real metadataWidth: width - metadataInset - 7
    readonly property real titleWidth: hasTitle && hasArtist
        ? metadataWidth * 0.58 : metadataWidth
    readonly property real separatorWidth: hasTitle && hasArtist ? 8 : 0
    readonly property real artistWidth: Math.max(0,
        metadataWidth - titleWidth - separatorWidth)
    readonly property bool showLyrics: barState.mediaAvailable
        && barState.mediaLyricsAvailable
        && barState.mediaLyric !== ""
    readonly property bool showLyricText: (showLyrics || !barState.mediaAvailable)
        && !hovered
    readonly property string sourceLyric: showLyrics
        ? barState.mediaLyric
        : (barState.mediaAvailable ? "" : "没有播放中的媒体")
    readonly property string playModeIcon: barState.mediaPlayMode === "shuffle"
        ? "shuffle"
        : (barState.mediaPlayMode === "repeatTrack" ? "repeat_one" : "playlist_play")
    readonly property bool playModeActive: barState.mediaPlayMode !== "sequential"

    property string displayedLyric: sourceLyric
    property real lyricOpacity: showLyricText ? 1 : 0
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

    function spectrumColor(index: int, alpha: real): color {
        if (index % 3 === 0)
            return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, alpha);
        if (index % 3 === 1)
            return Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, alpha);
        return Qt.rgba(Theme.tertiary.r, Theme.tertiary.g, Theme.tertiary.b, alpha);
    }

    function sideSpectrumValue(index: int): real {
        return spectrumValue(index * 2);
    }

    onSourceLyricChanged: {
        if (hovered) {
            displayedLyric = sourceLyric;
            lyricOpacity = 0;
            return;
        }
        lyricSwap.restart();
    }

    onShowLyricTextChanged: {
        if (!showLyricText)
            lyricSwap.stop();
        lyricOpacity = showLyricText ? 1 : 0;
    }

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
        running: root.barState.mediaAvailable
            && (root.barState.mediaPlaying || !root.showLyrics)
        repeat: true
        onTriggered: root.phase += root.barState.mediaPlaying ? 0.22 : 0.055
    }

    Item {
        id: spectrum

        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: root.showMetadata ? 13 : 5
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
                    color: root.spectrumColor(index, 0.74)

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
                    border.color: root.spectrumColor(index + 1,
                        0.16 + barSlot.amount * 0.22)
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

    Item {
        id: playingMark

        x: 7
        y: 4
        width: 8
        height: 8
        opacity: root.showMetadata && !root.hovered ? 1 : 0

        Repeater {
            model: 3

            delegate: Rectangle {
                required property int index

                readonly property real wave: Math.sin(root.phase + index * 1.35) * 0.5 + 0.5

                x: index * 3
                anchors.verticalCenter: parent.verticalCenter
                width: 1.5
                height: root.barState.mediaPlaying ? 3 + wave * 5 : 3
                radius: width / 2
                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b,
                    root.barState.mediaPlaying ? 0.85 : 0.42)

                Behavior on height {
                    NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                }
            }
        }

        Behavior on opacity {
            NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
        }
    }

    Text {
        id: titleText

        x: root.metadataInset
        y: 2
        width: root.titleWidth
        height: 11
        text: root.hasTitle ? root.barState.mediaTitle : root.barState.mediaArtist
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        color: root.hasTitle ? Theme.secondary : Theme.tertiary
        renderType: Text.NativeRendering
        font.family: Theme.bodyFont
        font.pixelSize: root.metadataSize
        font.weight: Font.Medium
        opacity: root.showMetadata && !root.hovered ? 0.88 : 0

        Behavior on opacity {
            NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
        }
    }

    Rectangle {
        x: titleText.x + root.titleWidth + 3
        y: 7
        width: root.hasTitle && root.hasArtist ? 2 : 0
        height: width
        radius: width / 2
        color: Theme.outline
        opacity: root.showMetadata && !root.hovered ? 0.72 : 0

        Behavior on opacity {
            NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
        }
    }

    Text {
        id: artistText

        x: titleText.x + root.titleWidth + root.separatorWidth
        y: 2
        width: root.artistWidth
        height: 11
        text: root.hasArtist ? root.barState.mediaArtist : ""
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        color: Theme.tertiary
        renderType: Text.NativeRendering
        font.family: Theme.bodyFont
        font.pixelSize: root.metadataSize
        font.weight: Font.Medium
        opacity: root.showMetadata && !root.hovered && root.hasTitle && root.hasArtist ? 0.9 : 0

        Behavior on opacity {
            NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
        }
    }

    Text {
        id: lyricText

        x: root.lyricSideInset
        y: root.showMetadata && root.showLyrics ? 10 : 0
        width: parent.width - root.lyricSideInset * 2
        height: parent.height - y - 2
        text: root.displayedLyric
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        color: root.barState.mediaAvailable ? Theme.fg : Theme.fgVariant
        renderType: Text.NativeRendering
        font.family: Theme.bodyFont
        font.pixelSize: root.lyricSize
        font.weight: Font.Medium
        opacity: root.lyricOpacity
    }

    SideSpectrum {
        side: -1
    }

    SideSpectrum {
        side: 1
    }

    Row {
        id: controls

        anchors.centerIn: parent
        spacing: root.controlGap
        opacity: root.hovered && root.barState.mediaAvailable ? 1 : 0

        MediaButton {
            iconName: root.playModeIcon
            highlighted: root.playModeActive
            enabled: root.barState.mediaPlayModeAvailable
            onClicked: MediaController.cyclePlayMode()
        }

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

        Rectangle {
            x: Math.max(0, parent.width * root.barState.mediaProgress - width)
            anchors.verticalCenter: parent.verticalCenter
            width: root.barState.mediaProgress > 0 ? 8 : 0
            height: 2
            radius: height / 2
            color: Theme.tertiary
            opacity: root.barState.mediaAvailable ? 0.86 : 0

            Behavior on x {
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
            target: root
            property: "lyricOpacity"
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
            target: root
            property: "lyricOpacity"
            to: root.showLyricText ? 1 : 0
            duration: 130
            easing.type: Easing.OutCubic
        }
    }

    component MediaButton: Item {
        id: buttonRoot

        required property string iconName
        property bool highlighted: false
        signal clicked()

        width: root.buttonSize
        height: root.buttonSize
        opacity: enabled ? 1 : 0.35

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: buttonRoot.highlighted
                ? Qt.rgba(Theme.secondaryContainer.r, Theme.secondaryContainer.g,
                    Theme.secondaryContainer.b, mouseArea.containsMouse ? 0.78 : 0.58)
                : mouseArea.containsMouse
                ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.16)
                : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08)

            Behavior on color {
                ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }

        Text {
            anchors.centerIn: parent
            text: buttonRoot.iconName
            color: buttonRoot.highlighted ? Theme.primary : Theme.fg
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

    component SideSpectrum: Item {
        id: sideRoot

        required property int side

        readonly property bool leftSide: side < 0

        x: leftSide ? 3 : root.width - width - 3
        y: root.showMetadata ? 12 : 5
        width: 15
        height: root.height - y - 5
        opacity: root.showLyrics && !root.hovered ? 0.82 : 0

        Repeater {
            model: root.sideSpectrumBars

            delegate: Rectangle {
                required property int index

                readonly property real center: (root.sideSpectrumBars - 1) / 2
                readonly property real normalized: center === 0 ? 0 : (index - center) / center
                readonly property real amount: root.sideSpectrumValue(index)
                readonly property real curve: 1 - Math.abs(normalized)

                x: sideRoot.leftSide
                    ? 1 + curve * 5 + amount * 2
                    : sideRoot.width - width - 1 - curve * 5 - amount * 2
                y: index * (sideRoot.height - 4) / Math.max(1, root.sideSpectrumBars - 1)
                width: 2.5 + amount * 5.5
                height: 2
                radius: height / 2
                rotation: sideRoot.side * (normalized * 34)
                color: root.spectrumColor(index + (sideRoot.leftSide ? 0 : 1),
                    0.32 + amount * 0.42)

                Behavior on width {
                    NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                }

                Behavior on x {
                    NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                }
            }
        }

        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
    }
}
