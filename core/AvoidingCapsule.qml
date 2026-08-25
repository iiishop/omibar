// AvoidingCapsule - single capsule with launcher avoidance motion.
pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    required property real neutralX
    required property real neutralScreenX
    required property real capsuleWidth
    required property real moduleSpacing
    required property string rowObjectName

    readonly property real leftX: neutralScreenX + neutralX
    readonly property real rightX: leftX + width
    readonly property real centerX: neutralScreenX + neutralX + width / 2
    readonly property real yieldDirection: centerX <= BarState.launcherCenterX ? -1 : 1
    readonly property real leftYieldOffset: BarState.launcherLeft
        - BarState.launcherPadding - rightX
    readonly property real rightYieldOffset: BarState.launcherRight
        + BarState.launcherPadding - leftX
    readonly property real yieldOffset: BarState.launcherOpen
        ? (yieldDirection < 0 ? leftYieldOffset : rightYieldOffset) : 0
    readonly property Item moduleRow: row
    readonly property real motionDirection: BarState.launcherOpen
        ? yieldDirection : -yieldDirection
    readonly property real jellyLag: 14
    readonly property real contentLagRatio: 0.65
    readonly property real lagTarget: -motionDirection * jellyLag
    readonly property int travelDuration: BarState.launcherOpen ? 280 : 190

    property real deformX: 1.0
    property real deformY: 1.0
    property real bodyLag: 0.0

    visible: width > 0
    x: neutralX + yieldOffset
    y: 0
    width: capsuleWidth
    height: parent.height

    function playMotion(): void {
        jellyMotion.play();
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

    Rectangle {
        id: body

        x: 0
        y: 0
        width: parent.width
        height: parent.height
        radius: height / 2
        color: Theme.surfaceContainer
    }

    Rectangle {
        id: gelSurface

        x: 0
        y: 1
        width: parent.width
        height: parent.height - 2
        radius: height / 2
        color: Theme.surfaceContainerHigh

        transform: Scale {
            xScale: root.deformX
            yScale: root.deformY
            origin.x: root.motionDirection < 0 ? gelSurface.width : 0
            origin.y: gelSurface.height / 2
        }
    }

    Row {
        id: row

        objectName: root.rowObjectName
        anchors.centerIn: parent
        spacing: root.moduleSpacing

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
