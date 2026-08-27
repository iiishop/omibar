// AvoidingCapsule - module band with launcher avoidance motion.
pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    required property real neutralX
    required property real neutralScreenX
    required property real capsuleWidth
    required property real moduleGap
    required property real leftStackOffset
    required property real rightStackOffset
    required property string rowObjectName

    readonly property real leftX: neutralScreenX + neutralX
    readonly property real rightX: leftX + width
    readonly property real centerX: neutralScreenX + neutralX + width / 2
    readonly property real yieldDirection: centerX <= BarState.launcherCenterX ? -1 : 1
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
    readonly property real gapCompression: Math.min(3, moduleGap * 0.3)
    readonly property real gapRecoil: Math.min(1.5, moduleGap * 0.15)
    readonly property int travelDuration: BarState.launcherOpen ? 280 : 190

    property real deformX: 1.0
    property real deformY: 1.0
    property real bodyLag: 0.0
    property real gapOffset: 0.0

    visible: width > 0
    x: neutralX + yieldOffset
    y: 0
    width: capsuleWidth
    height: parent.height

    function playMotion(): void {
        jellyMotion.play();
        gapMotion.restart();
    }

    function syncBandItems(): void {
        const count = row.children.length;
        const centerIndex = (count - 1) / 2;
        for (let i = 0; i < count; ++i) {
            const itemIndex = i;
            row.children[i].gapImpulseOffset = Qt.binding(
                () => root.gapOffset * (itemIndex - centerIndex));
        }
    }

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
        stretchX: 1.12
        stretchY: 0.9
        recoilX: 0.96
        recoilY: 1.06
        settleSpring: 4.8
        settleDamping: 0.3
        settleMass: 0.72
        stretchDuration: 95
        recoilDuration: 150
        lagDuration: 90
        settleDuration: 220
    }

    SequentialAnimation {
        id: gapMotion

        NumberAnimation {
            target: root
            property: "gapOffset"
            to: -root.gapCompression
            duration: 85
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "gapOffset"
            to: root.gapRecoil
            duration: 130
            easing.type: Easing.OutCubic
        }
        SpringAnimation {
            target: root
            property: "gapOffset"
            to: 0.0
            spring: 5.2
            damping: 0.42
            mass: 0.72
            epsilon: 0.002
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
