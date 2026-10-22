pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import "../../core"
import "NoteLogic.js" as Logic

Button {
    id: root
    required property var note
    implicitHeight: 32
    text: Logic.title(note) || qsTr("未命名")
    background: Rectangle {
        radius: 11
        color: root.hovered ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
        border.width: 1
        border.color: root.activeFocus ? Theme.primary : Qt.alpha(Theme.outline, 0.3)
    }
    contentItem: Text {
        text: root.text
        color: root.note.todo ? Theme.tertiary : Theme.fg
        font.family: Theme.bodyFont
        font.pixelSize: 12
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
        leftPadding: 12
        rightPadding: 12
    }
}
