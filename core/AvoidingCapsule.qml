// AvoidingCapsule - single capsule with launcher avoidance motion.
pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
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
    readonly property int travelDuration: 230
    readonly property int compressDuration: 90
    readonly property int reboundDuration: 120

    property real deformX: 1.0
    property real deformY: 1.0

    visible: width > 0
    x: neutralX + yieldOffset
    y: 0
    width: capsuleWidth
    height: parent.height
    radius: height / 2
    color: "#0a0a0c"

    function playDeform(): void {
        deformAnimation.stop();
        deformAnimation.start();
    }

    transform: Scale {
        xScale: root.deformX
        yScale: root.deformY
        origin.x: root.yieldDirection < 0 ? root.width : 0
        origin.y: root.height / 2
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

    SequentialAnimation {
        id: deformAnimation

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "deformX"
                to: 0.9
                duration: root.compressDuration
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "deformY"
                to: 1.06
                duration: root.compressDuration
                easing.type: Easing.OutQuad
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "deformX"
                to: 1.035
                duration: root.reboundDuration
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "deformY"
                to: 0.98
                duration: root.reboundDuration
                easing.type: Easing.OutCubic
            }
        }
        ParallelAnimation {
            SpringAnimation {
                target: root
                property: "deformX"
                to: 1.0
                spring: 4
                damping: 0.55
                mass: 0.8
                epsilon: 0.002
            }
            SpringAnimation {
                target: root
                property: "deformY"
                to: 1.0
                spring: 4
                damping: 0.55
                mass: 0.8
                epsilon: 0.002
            }
        }
    }

    Connections {
        target: BarState

        function onLauncherOpenChanged(): void {
            if (root.visible)
                root.playDeform();
        }

        function onDeformPulseChanged(): void {
            if (root.visible)
                root.playDeform();
        }
    }

    Row {
        id: row

        objectName: root.rowObjectName
        anchors.centerIn: parent
        spacing: root.moduleSpacing
    }
}
