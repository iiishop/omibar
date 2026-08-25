// JellyMotion - reusable squash, recoil, and inertial lag animation.
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root

    required property QtObject target
    required property real lagTarget

    property string xScaleProperty: "deformX"
    property string yScaleProperty: "deformY"
    property string lagProperty: "bodyLag"

    property real stretchX: 1.08
    property real stretchY: 0.94
    property real recoilX: 0.975
    property real recoilY: 1.035
    property real settleSpring: 5.0
    property real settleDamping: 0.42
    property real settleMass: 0.7
    property int stretchDuration: 90
    property int recoilDuration: 130
    property int lagDuration: 70
    property int settleDuration: 180

    function play(): void {
        deformAnimation.stop();
        lagAnimation.stop();
        deformAnimation.start();
        lagAnimation.start();
    }

    property SequentialAnimation deformAnimation: SequentialAnimation {
        ParallelAnimation {
            NumberAnimation {
                target: root.target
                property: root.xScaleProperty
                to: root.stretchX
                duration: root.stretchDuration
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root.target
                property: root.yScaleProperty
                to: root.stretchY
                duration: root.stretchDuration
                easing.type: Easing.OutQuad
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: root.target
                property: root.xScaleProperty
                to: root.recoilX
                duration: root.recoilDuration
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root.target
                property: root.yScaleProperty
                to: root.recoilY
                duration: root.recoilDuration
                easing.type: Easing.OutCubic
            }
        }
        ParallelAnimation {
            SpringAnimation {
                target: root.target
                property: root.xScaleProperty
                to: 1.0
                spring: root.settleSpring
                damping: root.settleDamping
                mass: root.settleMass
                epsilon: 0.002
            }
            SpringAnimation {
                target: root.target
                property: root.yScaleProperty
                to: 1.0
                spring: root.settleSpring
                damping: root.settleDamping
                mass: root.settleMass
                epsilon: 0.002
            }
        }
    }

    property SequentialAnimation lagAnimation: SequentialAnimation {
        NumberAnimation {
            target: root.target
            property: root.lagProperty
            to: root.lagTarget
            duration: root.lagDuration
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root.target
            property: root.lagProperty
            to: 0.0
            duration: root.settleDuration
            easing.type: Easing.OutCubic
        }
    }
}
