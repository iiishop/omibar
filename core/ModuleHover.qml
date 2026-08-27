// ModuleHover - hover shell applied by ModuleHost around each module.
pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    required property string hoverPreset
    readonly property alias hovered: hoverHandler.hovered
    readonly property real hPadding: 16
    property real gapImpulseOffset: 0
    property alias contentParent: contentSlot

    implicitWidth: contentSlot.childrenRect.width + hPadding * 2
    implicitHeight: BarState.moduleHeight
    width: implicitWidth
    height: implicitHeight
    z: hovered ? 1 : 0

    transform: Translate {
        x: root.gapImpulseOffset
    }

    Rectangle {
        x: 0
        y: 0
        width: parent.width
        height: parent.height
        radius: height / 2
        color: Theme.surfaceContainerHigh
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        radius: height / 2
        color: Theme.surfaceContainerHighest
        opacity: hoverMotion.surfaceOpacity
    }

    Item {
        id: contentSlot

        anchors.horizontalCenter: parent.horizontalCenter
        y: (parent.height - height) / 2 + hoverMotion.lift
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
