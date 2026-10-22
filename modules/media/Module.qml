// media module - 灵动岛式媒体胶囊：同一个形状在胶囊与卡片之间连续形变。
// 收起态显示歌词/频谱/进度；hover 后向上长成卡片，展开封面与控制。
// 展开时只抬高自身并向上溢出，不改整条 bar 的高度（AvoidingCapsule.row 高度已锁定）。
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
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
    readonly property bool pointerInside: hoverHandler.hovered || cardHover.hovered
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

    // ---- 灵动岛几何 ----
    readonly property int expandedWidth: 380
    readonly property int expandedHeight: 196
    readonly property int collapsedHeight: barState.moduleHeight
    // 尺寸由本模块自己驱动（宽高同一条曲线、同一时长），外壳纯跟随。
    // 让外壳做宽度动画而模块做高度动画，两条曲线不同步，中间态形状会被拉扯。
    readonly property bool drivesOwnSize: true
    property bool islandOpen: false
    readonly property bool expanded: islandOpen
    readonly property bool hasArt: barState.mediaArtUrl !== ""
    readonly property string cardTitle: hasTitle ? barState.mediaTitle : barState.mediaArtist
    // 卡片副标题只放艺术家；专辑留给第三行（有歌词时第三行换成歌词），避免重复。
    readonly property string cardSubtitle: hasArtist ? barState.mediaArtist : ""

    property real animWidth: 0
    property real animHeight: 0
    width: animWidth
    height: animHeight
    implicitWidth: animWidth
    implicitHeight: animHeight

    Component.onCompleted: {
        animWidth = lyricMetrics.width;
        animHeight = collapsedHeight;
    }

    ParallelAnimation {
        id: expandAnim

        NumberAnimation {
            target: root
            property: "animWidth"
            to: root.expandedWidth
            duration: 500
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.1, 0.68, 0.28, 1.02, 0.64, 1.035, 0.78, 1.035, 0.96, 1, 1, 1]
        }

        NumberAnimation {
            target: root
            property: "animHeight"
            to: root.expandedHeight
            duration: 500
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.1, 0.68, 0.28, 1.02, 0.64, 1.035, 0.78, 1.035, 0.96, 1, 1, 1]
        }
    }

    ParallelAnimation {
        id: collapseAnim

        NumberAnimation {
            target: root
            property: "animWidth"
            to: lyricMetrics.width
            duration: 360
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.16, 0.68, 0.36, 1, 1, 1]
        }

        NumberAnimation {
            target: root
            property: "animHeight"
            to: root.collapsedHeight
            duration: 360
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.16, 0.68, 0.36, 1, 1, 1]
        }
    }

    function timeText(seconds: real): string {
        const total = Math.max(0, Math.floor(seconds));
        const minutes = Math.floor(total / 60);
        const rest = total % 60;
        return minutes + ":" + (rest < 10 ? "0" : "") + rest;
    }

    onIslandOpenChanged: console.log("[island] open:", islandOpen,
                                     "hovered:", hovered,
                                     "available:", barState.mediaAvailable,
                                     "playing:", barState.mediaPlaying)

    onExpandedChanged: {
        if (expanded) {
            closeTimer.stop();
            shrinkWindow.stop();
            barState.islandExpandExtent = expandedHeight - collapsedHeight;
            collapseAnim.stop();
            expandAnim.restart();
        } else {
            openTimer.stop();
            expandAnim.stop();
            collapseAnim.restart();
            // 收起动画跑完再缩回外壳高度，避免半途被裁。
            shrinkWindow.restart();
        }
    }
    Component.onDestruction: barState.islandExpandExtent = 0

    Timer {
        id: shrinkWindow

        interval: 400
        onTriggered: {
            if (!root.islandOpen)
                root.barState.islandExpandExtent = 0;
        }
    }

    // ---- 形状本体：胶囊与卡片是同一个矩形 ----
    // 宽度必须等于外壳（root + 两侧 hPadding），否则卡片表面比外壳窄 32px，
    // 邻居之间的视觉间距就会从 10 变成 26，收起时又突变回 10。
    Rectangle {
        id: surface

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width + 32
        height: parent.height
        // radius 用离散值：绑到每帧都在变的 height 会让 Behavior 每帧重启。
        radius: root.expanded ? 24 : root.collapsedHeight / 2
        color: Theme.surfaceContainerHigh
        clip: true

        Behavior on radius {
            NumberAnimation {
                duration: 320
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.16, 0.68, 0.36, 1, 1, 1]
            }
        }
    }

    property string displayedLyric: sourceLyric
    property real lyricOpacity: showLyricText ? 1 : 0
    property real phase: 0

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

    // hover 判定覆盖整个岛：root 只有 380 宽，而形状本体是 root + 两侧各 16
    // （surface 的 hPadding）。用一块透明层单独吃 hover，几何比 root 大一圈。
    // Qt 的 HoverHandler 不参与 hit test 遮挡筛选，被上层内容盖住也照样收到 hover，
    // 所以这块可以放在 z:-1，不影响卡片里按钮/进度条的点击。
    Item {
        id: islandHoverArea

        x: -16
        y: 0
        width: root.width + 32
        height: root.height
        z: -1

        HoverHandler {
            id: hoverHandler

            onHoveredChanged: root.updatePointer()
        }
    }

    // 卡片内容区再挂一个：鼠标抓取（按下按钮、拖进度条）期间指针事件的归属会变，
    // 光靠外面那块判定容易在点击瞬间丢掉 hover，导致卡片收回。
    function updatePointer(): void {
        if (pointerInside) {
            closeTimer.stop();
            if (root.barState.mediaAvailable)
                openTimer.restart();
        } else {
            openTimer.stop();
            closeTimer.restart();
        }
    }

    // 交互期间强制保持：按下就停表，松手再看指针是不是还在岛里。
    function holdOpen(): void {
        closeTimer.stop();
    }

    function releaseHold(): void {
        if (!pointerInside)
            closeTimer.restart();
    }

    Timer {
        id: openTimer

        // 悬停意图确认时间：太长会有「停一下才长」的滞后感。
        interval: 160
        onTriggered: {
            if (root.pointerInside && root.barState.mediaAvailable)
                root.islandOpen = true;
        }
    }

    Timer {
        id: closeTimer

        // 从胶囊区移到卡片上沿要跨 160px，360ms 太紧；这里留出余量。
        interval: 520
        onTriggered: {
            if (!root.pointerInside)
                root.islandOpen = false;
        }
    }

    Timer {
        interval: 42
        running: root.barState.mediaAvailable
            && (root.barState.mediaPlaying || !root.showLyrics)
        repeat: true
        onTriggered: root.phase += root.barState.mediaPlaying ? 0.22 : 0.055
    }

    // IPC 调试入口：`qs -p <repo> ipc call omibar demoMediaCard`
    Connections {
        target: root.barState

        function onMediaCardPulseChanged(): void {
            root.islandOpen = !root.islandOpen;
        }
    }

    // ======== 收起态内容（固定 32 高，贴底） ========
    Item {
        id: compact

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.collapsedHeight
        opacity: root.expanded ? 0 : 1
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
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


        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 2
            radius: 1
            color: Qt.rgba(Theme.outlineVariant.r, Theme.outlineVariant.g, Theme.outlineVariant.b, 0.42)
            opacity: root.barState.mediaAvailable && !root.expanded ? 1 : 0

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
    }

    // ======== 展开态内容：和胶囊同一块 surface ========
    Item {
        id: card

        // 相对 surface 排布，才能吃到那 32px 的 padding：
        // 卡片内容区 = 外壳宽 - 32，两侧各 16。
        anchors.fill: surface
        anchors.margins: 16
        opacity: root.expanded ? 1 : 0
        visible: opacity > 0.01
        enabled: root.expanded

        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        HoverHandler {
            id: cardHover

            onHoveredChanged: root.updatePointer()
        }

        // ---- 封面 + 环形进度 ----
        Item {
            id: ringHost

            width: 92
            height: 92
            x: 0
            y: 0

            readonly property real strokeWidth: 3
            readonly property real ringRadius: width / 2 - strokeWidth / 2 - 0.5

            // 轨道：固定 270°，缺口朝下
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: Qt.rgba(Theme.outline.r, Theme.outline.g,
                        Theme.outline.b, 0.30)
                    fillColor: "transparent"
                    strokeWidth: ringHost.strokeWidth
                    capStyle: ShapePath.RoundCap

                    PathAngleArc {
                        centerX: ringHost.width / 2
                        centerY: ringHost.height / 2
                        radiusX: ringHost.ringRadius
                        radiusY: ringHost.ringRadius
                        startAngle: 90
                        sweepAngle: 359.9
                    }
                }
            }

            // 播放进度：同一缺口、同一方向，长度跟 mediaProgress
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: Theme.primary
                    fillColor: "transparent"
                    strokeWidth: ringHost.strokeWidth
                    capStyle: ShapePath.RoundCap

                    PathAngleArc {
                        centerX: ringHost.width / 2
                        centerY: ringHost.height / 2
                        radiusX: ringHost.ringRadius
                        radiusY: ringHost.ringRadius
                        startAngle: -45
                        sweepAngle: 359.9 * Math.max(0.001, root.barState.mediaProgress)
                    }
                }
            }

            Rectangle {
                id: coverFrame

                anchors.centerIn: parent
                width: 76
                height: 76
                radius: 15
                color: Theme.surfaceContainerHighest

                // Rectangle.clip 是矩形裁剪，不会跟随 radius：
                // 封面图必须走 mask，否则四个角会露出直角。
                Image {
                    id: coverArt

                    anchors.fill: parent
                    visible: false
                    source: root.hasArt ? root.barState.mediaArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                }

                MultiEffect {
                    anchors.fill: parent
                    visible: root.hasArt
                    source: coverArt
                    maskEnabled: true
                    maskSource: coverMask
                }

                Rectangle {
                    id: coverMask

                    anchors.fill: parent
                    radius: coverFrame.radius
                    visible: false
                    layer.enabled: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: !root.hasArt
                    text: "music_note"
                    color: Theme.outline
                    renderType: Text.NativeRendering
                    font.family: Theme.iconFont
                    font.pixelSize: 28
                    font.variableAxes: { "FILL": 1, "GRAD": -20 }
                }
            }
        }

        // ---- 标题 / 艺术家 / 歌词或专辑 ----
        Column {
            id: infoColumn

            anchors.left: ringHost.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.verticalCenter: ringHost.verticalCenter
            spacing: 3

            Text {
                width: parent.width
                text: root.cardTitle
                color: Theme.fg
                elide: Text.ElideRight
                renderType: Text.NativeRendering
                font.family: Theme.bodyFont
                font.pixelSize: 16
                font.weight: Font.Medium
            }

            Text {
                width: parent.width
                visible: root.cardSubtitle !== ""
                text: root.cardSubtitle
                color: Theme.fgVariant
                elide: Text.ElideRight
                renderType: Text.NativeRendering
                font.family: Theme.bodyFont
                font.pixelSize: 12
            }

            // 有歌词时占两行：当前行 + 下一行；没歌词就退化成专辑名。
            Text {
                width: parent.width
                visible: root.showLyrics || root.barState.mediaAlbum !== ""
                text: root.showLyrics ? root.barState.mediaLyric
                                      : root.barState.mediaAlbum
                color: root.showLyrics ? Theme.primary : Theme.outline
                elide: Text.ElideRight
                renderType: Text.NativeRendering
                font.family: Theme.bodyFont
                font.pixelSize: 11
                font.weight: root.showLyrics ? Font.Medium : Font.Normal
            }

            Text {
                width: parent.width
                visible: root.showLyrics && root.barState.mediaLyricNext !== ""
                text: root.showLyrics ? root.barState.mediaLyricNext : ""
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.72)
                elide: Text.ElideRight
                renderType: Text.NativeRendering
                font.family: Theme.bodyFont
                font.pixelSize: 11
            }
        }

        // ---- 播放器身份 ----
        Text {
            anchors.top: parent.top
            anchors.right: parent.right
            text: root.barState.mediaPlayerName
            visible: text !== ""
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.72)
            renderType: Text.NativeRendering
            font.family: Theme.monoFont
            font.pixelSize: 9
        }

        // ---- 进度：时间标签定宽防跳动，轨道可拖动 ----
        Item {
            id: progress

            anchors.top: ringHost.bottom
            anchors.topMargin: 6
            anchors.left: parent.left
            anchors.right: parent.right
            height: 16

            TextMetrics {
                id: timeMetrics

                font.family: Theme.monoFont
                font.pixelSize: 10
                text: "0:00"
            }

            Text {
                id: positionText

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.ceil(timeMetrics.width)
                text: root.timeText(progress.dragProgress >= 0
                    ? progress.dragProgress * root.barState.mediaLength
                    : root.barState.mediaPosition)
                color: progress.dragProgress >= 0 ? Theme.primary : Theme.outline
                renderType: Text.NativeRendering
                font.family: Theme.monoFont
                font.pixelSize: 10
                horizontalAlignment: Text.AlignLeft
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.ceil(timeMetrics.width)
                text: root.timeText(root.barState.mediaLength)
                color: Theme.outline
                renderType: Text.NativeRendering
                font.family: Theme.monoFont
                font.pixelSize: 10
                horizontalAlignment: Text.AlignRight
            }

            Item {
                id: progressTrack

                anchors.left: positionText.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 10 + Math.ceil(timeMetrics.width) + 10
                anchors.verticalCenter: parent.verticalCenter
                height: 4

                // 拖动预览：-1 表示未在交互
                property real dragProgress: -1
                readonly property real shownProgress: dragProgress >= 0
                    ? dragProgress : Math.max(0, Math.min(1, root.barState.mediaProgress))

                Rectangle {
                    anchors.fill: parent
                    radius: 2
                    color: Qt.rgba(Theme.outlineVariant.r, Theme.outlineVariant.g,
                        Theme.outlineVariant.b, 0.46)
                }

                Rectangle {
                    width: parent.width * progressTrack.shownProgress
                    height: parent.height
                    radius: 2
                    color: Theme.primary

                    Behavior on width {
                        enabled: progressTrack.dragProgress < 0
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }
                }

                Rectangle {
                    x: Math.max(0, Math.min(parent.width - width,
                        parent.width * progressTrack.shownProgress - width / 2))
                    anchors.verticalCenter: parent.verticalCenter
                    width: progressTrack.dragProgress >= 0 ? 10 : 0
                    height: 10
                    radius: width / 2
                    color: Theme.primary

                    Behavior on width {
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.topMargin: -6
                    anchors.bottomMargin: -6
                    enabled: root.barState.mediaCanSeek
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                    function ratioAt(xPos: real): real {
                        return Math.max(0, Math.min(1, xPos / width));
                    }

                    onPressed: mouse => {
                        root.holdOpen();
                        progressTrack.dragProgress = ratioAt(mouse.x);
                        MediaController.seek(progressTrack.dragProgress);
                    }
                    onPositionChanged: mouse => {
                        if (pressed)
                            progressTrack.dragProgress = ratioAt(mouse.x);
                    }
                    onReleased: {
                        progressTrack.dragProgress = -1;
                        root.releaseHold();
                    }
                    onCanceled: {
                        progressTrack.dragProgress = -1;
                        root.releaseHold();
                    }
                }
            }
        }

        // ---- 控制键：主播放键放大并反白 ----
        Row {
            id: cardControls

            anchors.top: progress.bottom
            anchors.topMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            CardButton {
                icon: root.playModeIcon
                active: root.playModeActive
                available: root.barState.mediaPlayModeAvailable
                onTapped: MediaController.cyclePlayMode()
            }

            CardButton {
                icon: "skip_previous"
                available: MediaController.active !== null && MediaController.active.canGoPrevious
                onTapped: MediaController.previous()
            }

            CardButton {
                icon: root.barState.mediaPlaying ? "pause" : "play_arrow"
                primary: true
                available: MediaController.active !== null && MediaController.active.canTogglePlaying
                onTapped: MediaController.toggle()
            }

            CardButton {
                icon: "skip_next"
                available: MediaController.active !== null && MediaController.active.canGoNext
                onTapped: MediaController.next()
            }
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

    // 卡片里的控制键：圆底、主键反白放大，材质与 caelestia 的 tonal IconButton 对齐。
    component CardButton: Item {
        id: btn

        required property string icon
        property bool primary: false
        property bool active: false
        property bool available: true
        signal tapped()

        implicitWidth: primary ? 40 : 30
        implicitHeight: primary ? 40 : 30
        width: implicitWidth
        height: implicitHeight
        opacity: available ? 1 : 0.32

        Behavior on opacity {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: btn.primary
                ? (btnMouse.containsMouse ? Qt.lighter(Theme.primary, 1.1) : Theme.primary)
                : btn.active
                ? Qt.rgba(Theme.secondaryContainer.r, Theme.secondaryContainer.g,
                    Theme.secondaryContainer.b, 0.72)
                : btnMouse.containsMouse
                ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.14)
                : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.06)

            Behavior on color {
                ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }

        Text {
            anchors.centerIn: parent
            text: btn.icon
            color: btn.primary ? Theme.surface : (btn.active ? Theme.primary : Theme.fg)
            renderType: Text.NativeRendering
            font.family: Theme.iconFont
            font.pixelSize: btn.primary ? 24 : 18
            font.variableAxes: { "FILL": 1, "GRAD": -20 }
        }

        MouseArea {
            id: btnMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: btn.available ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPressed: root.holdOpen()
            onReleased: root.releaseHold()
            onCanceled: root.releaseHold()
            onClicked: {
                if (btn.available)
                    btn.tapped();
            }
        }
    }

    component SideSpectrum: Item {
        id: sideRoot

        required property int side

        readonly property bool leftSide: side < 0

        x: leftSide ? 3 : compact.width - width - 3
        y: root.showMetadata ? 12 : 5
        width: 15
        height: compact.height - y - 5
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
