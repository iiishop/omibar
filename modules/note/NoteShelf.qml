pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

PopupWindow {
    id: root
    objectName: "noteShelf"
    required property Item anchorItem
    required property var notes
    required property int selectedIndex
    required property real cardWidth
    property bool open: false
    property real reveal: open ? 1 : 0
    readonly property bool hovered: hover.hovered
    readonly property int capacity: 7
    readonly property int cardStep: 27
    readonly property int margin: 28
    readonly property int firstIndex: Math.max(0, selectedIndex)
    readonly property int count: Math.min(capacity, notes.length - firstIndex)
    signal selected(string id)
    signal scrolled(var event)

    implicitWidth: cardWidth + margin * 2
    implicitHeight: capacity * cardStep + margin * 2
    visible: open || reveal > 0
    color: "transparent"
    anchor.item: anchorItem
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    anchor.margins.top: 10
    onOpenChanged: { if (open) anchor.updateAnchor(); }
    Behavior on reveal { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }

    Item {
        objectName: "noteShelfSurface"
        anchors.fill: parent
        HoverHandler { id: hover }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: event => root.scrolled(event)
        }
        Repeater {
            model: root.capacity
            NoteShelfCard {
                required property int index
                readonly property int noteIndex: root.firstIndex
                    + (index - root.firstIndex % root.capacity + root.capacity) % root.capacity
                readonly property int distance: noteIndex - root.selectedIndex - 1
                visible: noteIndex < root.notes.length
                note: root.notes[noteIndex] ?? ({ title: "", body: "", todo: false })
                width: root.cardWidth
                x: root.margin - distance * 4
                y: root.height - root.margin - height - distance * root.cardStep
                rotation: -Math.max(0, distance) * 1.1
                scale: 1 - Math.max(0, distance) * 0.025
                opacity: (distance < 0 ? 0 : 1 - distance * 0.07) * root.reveal
                transform: Translate { x: -12 * (1 - root.reveal); y: 24 * (1 - root.reveal) }
                enabled: opacity > 0
                z: root.capacity - distance
                Behavior on y { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 190 } }
                onClicked: root.selected(note.id)
            }
        }
    }
}
