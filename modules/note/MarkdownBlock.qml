pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import "../../core"

Item {
    id: root
    required property var block
    required property bool editing
    property int requestedCursor: 0
    signal activated(int offset)
    signal edited(string text, int cursor)
    signal moved(int direction)
    signal cursorMoved(int cursor)
    signal historyRequested(int direction)
    signal cursorVisible(real top, real height)
    implicitHeight: Math.max(28, (content.item as Item)?.implicitHeight ?? 0)

    function focusEditor(): void {
        const input = content.item as TextEdit;
        if (content.status !== Loader.Ready || !editing || !input) return;
        input.forceActiveFocus();
        input.cursorPosition = Math.min(requestedCursor, input.length);
    }

    Loader {
        id: content
        width: parent.width
        sourceComponent: root.editing ? editor : preview
        onLoaded: { if (root.editing) Qt.callLater(root.focusEditor); }
    }
    Component {
        id: preview
        Text {
            width: root.width
            text: root.block.text
            textFormat: Text.MarkdownText
            wrapMode: Text.Wrap
            color: Theme.fg
            linkColor: Theme.primary
            font.family: Theme.bodyFont
            font.pixelSize: 15
            topPadding: 3
            bottomPadding: 3
            Accessible.role: Accessible.EditableText
            Accessible.name: text
            activeFocusOnTab: true
            Keys.onReturnPressed: root.activated(root.block.start)
            TapHandler { onTapped: root.activated(root.block.start) }
        }
    }
    Component {
        id: editor
        TextArea {
            id: input
            objectName: "markdownSource"
            property bool initialized: false
            width: root.width
            text: root.block.text
            textFormat: TextEdit.PlainText
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            color: Theme.fg
            selectionColor: Theme.secondaryContainer
            selectedTextColor: Theme.fg
            font.family: Theme.monoFont
            font.pixelSize: 14
            padding: 3
            background: Rectangle {
                radius: 5
                color: Qt.alpha(Theme.primary, 0.045)
                border.width: input.activeFocus ? 1 : 0
                border.color: Qt.alpha(Theme.primary, 0.35)
            }
            Accessible.name: qsTr("Markdown 源码")
            Component.onCompleted: initialized = true
            onTextChanged: { if (initialized) root.edited(text, cursorPosition); }
            onCursorPositionChanged: {
                if (initialized && !inputMethodComposing) root.cursorMoved(cursorPosition);
            }
            onCursorRectangleChanged: {
                if (activeFocus) root.cursorVisible(cursorRectangle.y, cursorRectangle.height);
            }
            onActiveFocusChanged: {
                if (activeFocus) root.cursorVisible(cursorRectangle.y, cursorRectangle.height);
            }
            Keys.onPressed: event => {
                if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Z) {
                    root.historyRequested(event.modifiers & Qt.ShiftModifier ? 1 : -1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up && cursorPosition === 0) {
                    root.moved(-1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down && cursorPosition === length) {
                    root.moved(1);
                    event.accepted = true;
                }
            }
        }
    }
}
