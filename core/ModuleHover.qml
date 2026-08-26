// ModuleHover - hover shell applied by ModuleHost around each module.
pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    required property string hoverPreset
    readonly property alias hovered: hoverHandler.hovered
    property alias contentParent: contentSlot

    implicitWidth: contentSlot.childrenRect.width
    implicitHeight: contentSlot.childrenRect.height
    width: implicitWidth
    height: implicitHeight
    z: hovered ? 1 : 0

    Rectangle {
        anchors.centerIn: parent
        width: parent.width + 12
        height: parent.height + 8
        radius: height / 2
        color: Theme.surfaceContainerHighest
        opacity: hoverMotion.surfaceOpacity
    }

    Item {
        id: contentSlot

        x: 0
        y: hoverMotion.lift
        width: childrenRect.width
        height: childrenRect.height
        scale: hoverMotion.scale
        transformOrigin: Item.Center
    }

    HoverHandler {
        id: hoverHandler
    }

    HoverMotion {
        id: hoverMotion

        hovered: root.hovered
        preset: root.hoverPreset
    }
}
