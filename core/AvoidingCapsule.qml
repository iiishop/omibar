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

    readonly property real centerX: neutralScreenX + neutralX + width / 2
    readonly property real yieldDirection: centerX <= BarState.launcherCenterX ? -1 : 1
    readonly property real yieldShift: (BarState.launcherWidth + width) / 2
        + BarState.launcherPadding
    readonly property real yieldOffset: BarState.launcherOpen
        ? yieldDirection * yieldShift : 0
    readonly property Item moduleRow: row

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
        deformX = 1.0;
        deformY = 1.0;
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
        SpringAnimation { spring: 4; damping: 0.6; mass: 1.0 }
    }

    SequentialAnimation {
        id: deformAnimation

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "deformX"
                to: 0.72
                duration: 130
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "deformY"
                to: 1.18
                duration: 130
                easing.type: Easing.OutQuad
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "deformX"
                to: 1.14
                duration: 115
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "deformY"
                to: 0.92
                duration: 115
                easing.type: Easing.OutCubic
            }
        }
        ParallelAnimation {
            SpringAnimation {
                target: root
                property: "deformX"
                to: 1.0
                spring: 4
                damping: 0.28
                mass: 0.8
                epsilon: 0.002
            }
            SpringAnimation {
                target: root
                property: "deformY"
                to: 1.0
                spring: 4
                damping: 0.28
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
