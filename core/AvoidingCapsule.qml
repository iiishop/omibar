// AvoidingCapsule - module band with launcher avoidance motion.
pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    required property real neutralX
    required property real neutralScreenX
    required property real movementOriginX
    required property real movementDirection
    required property real capsuleWidth
    required property real moduleGap
    required property real leftStackOffset
    required property real rightStackOffset
    required property string rowObjectName

    readonly property real leftX: neutralScreenX + neutralX
    readonly property real rightX: leftX + width
    readonly property real centerX: neutralScreenX + neutralX + width / 2
    readonly property real yieldDirection: movementDirection
    readonly property real leftYieldOffset: BarState.launcherLeft
        - BarState.launcherPadding - leftStackOffset - rightX
    readonly property real rightYieldOffset: BarState.launcherRight
        + BarState.launcherPadding + rightStackOffset - leftX
    readonly property real yieldOffset: BarState.launcherOpen
        ? (yieldDirection < 0 ? leftYieldOffset : rightYieldOffset) : 0
    readonly property Item moduleRow: row
    readonly property real motionDirection: BarState.launcherOpen
        ? yieldDirection : -yieldDirection
    readonly property real jellyLag: 14
    readonly property real contentLagRatio: 0.65
    readonly property real lagTarget: -motionDirection * jellyLag
    readonly property real minimumMotionGap: 1
    readonly property real gapCompression: Math.max(0, moduleGap - minimumMotionGap)
    readonly property real gapRecoil: Math.min(6, moduleGap * 0.55)
    readonly property real gapWaveDelayPx: 520
    readonly property real gapWaveMaxDelay: 0.36
    readonly property int travelDuration: BarState.launcherOpen ? 280 : 190

    property real deformX: 1.0
    property real deformY: 1.0
    property real bodyLag: 0.0
    property real gapWaveProgress: 0.0
    property var bandItems: []

    visible: width > 0
    x: neutralX + yieldOffset
    y: 0
    width: capsuleWidth
    height: parent.height

    function playMotion(): void {
        jellyMotion.play();
        gapWave.restart();
    }

    function syncBandItems(): void {
        applyGapWave();
    }

    function clearBandItems(): void {
        bandItems = [];
    }

    function registerBandItem(item): void {
        const nextItems = bandItems.slice();
        nextItems.push(item);
        bandItems = nextItems;
        applyGapWave();
    }

    function visibleBandItems(): var {
        return bandItems.filter(item => item.visible && item.width > 0);
    }

    function applyGapWave(): void {
        const items = visibleBandItems();
        for (const item of bandItems)
            item.gapImpulseOffset = 0;
        for (let i = 0; i < items.length; ++i)
            items[i].gapImpulseOffset = itemImpulseOffset(items, i);
    }

    function itemImpulseOffset(items: var, itemIndex: int): real {
        let offset = 0;
        for (let gapIndex = 0; gapIndex < items.length - 1; ++gapIndex) {
            const delta = gapDelta(items, gapIndex);
            offset += itemIndex <= gapIndex ? -delta / 2 : delta / 2;
        }
        return offset;
    }

    function gapDelta(items: var, gapIndex: int): real {
        const phase = gapWaveProgress - gapDelay(items, gapIndex);
        if (phase < 0 || phase > 1)
            return 0;
        if (phase < 0.22)
            return -gapCompression * easeOutQuad(phase / 0.22);
        if (phase < 0.56)
            return -gapCompression
                + (gapCompression + gapRecoil)
                * easeOutCubic((phase - 0.22) / 0.34);
        return gapRecoil * (1 - easeOutCubic((phase - 0.56) / 0.44));
    }

    function gapDelay(items: var, gapIndex: int): real {
        const leftItem = items[gapIndex];
        const gapCenterX = neutralScreenX + neutralX + row.x + leftItem.x
            + leftItem.width + moduleGap / 2;
        const distance = Math.abs(gapCenterX - movementOriginX);
        return Math.min(gapWaveMaxDelay, distance / gapWaveDelayPx);
    }

    function easeOutQuad(t: real): real {
        return 1 - (1 - t) * (1 - t);
    }

    function easeOutCubic(t: real): real {
        return 1 - Math.pow(1 - t, 3);
    }

    onGapWaveProgressChanged: applyGapWave()

    Behavior on width {
        SpringAnimation { spring: 3; damping: 0.62; mass: 0.8 }
    }
    Behavior on x {
        NumberAnimation {
            duration: root.travelDuration
            easing.type: Easing.OutCubic
        }
    }

    Row {
        id: row

        objectName: root.rowObjectName
        anchors.centerIn: parent
        spacing: root.moduleGap

        transform: Translate {
            x: root.bodyLag * root.contentLagRatio
        }
    }

    JellyMotion {
        id: jellyMotion

        target: root
        lagTarget: root.lagTarget
        stretchX: 1.0
        stretchY: 1.0
        recoilX: 1.0
        recoilY: 1.0
        settleSpring: 5.2
        settleDamping: 0.26
        settleMass: 0.72
        stretchDuration: 105
        recoilDuration: 170
        lagDuration: 105
        settleDuration: 260
    }

    NumberAnimation {
        id: gapWave

        target: root
        property: "gapWaveProgress"
        from: 0.0
        to: 1.0 + root.gapWaveMaxDelay
        duration: 640
        easing.type: Easing.Linear

        onStopped: {
            root.gapWaveProgress = 0.0;
            root.applyGapWave();
        }
    }

    Connections {
        target: BarState

        function onLauncherOpenChanged(): void {
            if (root.visible)
                root.playMotion();
        }

        function onDeformPulseChanged(): void {
            if (root.visible)
                root.playMotion();
        }
    }

}
