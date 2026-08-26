// HoverMotion - reusable hover response presets for module content.
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root

    property bool hovered: false
    property string preset: "lift"

    property real scale: 1.0
    property real lift: 0.0
    property real surfaceOpacity: 0.0

    readonly property bool active: preset !== "none"

    onHoveredChanged: apply()
    onPresetChanged: apply()

    Component.onCompleted: apply()

    function apply(): void {
        if (!active) {
            scale = 1.0;
            lift = 0.0;
            surfaceOpacity = 0.0;
            return;
        }

        if (preset === "jelly") {
            scale = hovered ? 1.075 : 1.0;
            lift = hovered ? -1.0 : 0.0;
            surfaceOpacity = hovered ? 0.34 : 0.0;
            return;
        }

        if (preset === "glow") {
            scale = hovered ? 1.02 : 1.0;
            lift = 0.0;
            surfaceOpacity = hovered ? 0.48 : 0.0;
            return;
        }

        scale = hovered ? 1.045 : 1.0;
        lift = hovered ? -1.5 : 0.0;
        surfaceOpacity = hovered ? 0.28 : 0.0;
    }

    Behavior on scale {
        SpringAnimation { spring: 7; damping: 0.42; mass: 0.45; epsilon: 0.001 }
    }

    Behavior on lift {
        SpringAnimation { spring: 8; damping: 0.5; mass: 0.4; epsilon: 0.001 }
    }

    Behavior on surfaceOpacity {
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }
}
