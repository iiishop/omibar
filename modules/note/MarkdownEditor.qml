pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "MarkdownDocument.js" as Document

ScrollView {
    id: root
    property string source: ""
    property var blocks: Document.blocks(source)
    property int activeIndex: -1
    property int cursor: 0
    property string prefix: ""
    property string suffix: ""
    property int pendingOffset: 0
    readonly property int historyLimit: 100
    property var history: []
    property int historyIndex: -1
    property bool newHistoryEntry: true
    signal edited(string text)
    clip: true
    contentWidth: availableWidth

    function load(text: string): void {
        followCursor.stop();
        historyGroup.stop();
        activeIndex = -1;
        source = text;
        blocks = Document.blocks(text);
        history = [{ text, cursor: 0 }];
        historyIndex = 0;
        newHistoryEntry = true;
    }
    function activate(offset: int): void {
        followCursor.stop();
        newHistoryEntry = true;
        const next = Document.blocks(source);
        activeIndex = -1;
        blocks = next;
        const index = next.findIndex(block => offset >= block.start && offset < block.end);
        activeIndex = index < 0 ? next.length - 1 : index;
        const block = next[activeIndex];
        prefix = source.slice(0, block.start);
        suffix = source.slice(block.end);
        cursor = Math.max(0, offset - block.start);
        Qt.callLater(() => {
            const item = blockRepeater.itemAt(root.activeIndex);
            if (item) item.focusEditor();
        });
    }
    function finish(): void {
        activeIndex = -1;
        blocks = Document.blocks(source);
    }
    function replaceText(text: string, position: int): void {
        source = prefix + text + suffix;
        const snapshot = { text: source, cursor: prefix.length + position };
        const next = history.slice(0, historyIndex + 1);
        if (newHistoryEntry) next.push(snapshot);
        else next[next.length - 1] = snapshot;
        history = next.slice(-historyLimit);
        historyIndex = history.length - 1;
        newHistoryEntry = false;
        historyGroup.restart();
        edited(source);
    }
    function travelHistory(direction: int): void {
        const index = historyIndex + direction;
        if (index < 0 || index >= history.length) return;
        historyIndex = index;
        source = history[index].text;
        activate(history[index].cursor);
        edited(source);
    }
    Timer { id: historyGroup; interval: 350; onTriggered: root.newHistoryEntry = true }
    Timer {
        id: followCursor
        interval: 0
        onTriggered: {
            const block = Document.blocks(root.source).find(block =>
                root.pendingOffset >= block.start && root.pendingOffset < block.end);
            if (block && (block.start !== root.prefix.length
                || block.end !== root.source.length - root.suffix.length))
                root.activate(root.pendingOffset);
        }
    }

    Column {
        width: root.availableWidth
        Repeater {
            id: blockRepeater
            model: root.blocks
            MarkdownBlock {
                required property var modelData
                required property int index
                width: root.availableWidth
                block: modelData
                editing: index === root.activeIndex
                requestedCursor: root.cursor
                onActivated: offset => root.activate(offset)
                onEdited: (text, position) => root.replaceText(text, position)
                onHistoryRequested: direction => root.travelHistory(direction)
                onCursorVisible: (top, height) => {
                    const view = root.contentItem as Flickable;
                    if (!view) return;
                    const position = mapToItem(view.contentItem, 0, top);
                    const target = Math.min(position.y, Math.max(view.contentY, position.y + height - view.height));
                    view.contentY = Math.max(0, Math.min(target, view.contentHeight - view.height));
                }
                onCursorMoved: position => {
                    root.pendingOffset = root.prefix.length + position;
                    followCursor.restart();
                }
                onMoved: direction => {
                    const offset = direction < 0 ? Math.max(0, root.prefix.length - 1)
                        : Math.min(root.source.length, root.source.length - root.suffix.length);
                    root.activate(offset);
                }
            }
        }
        Item {
            width: parent.width
            height: 100
            TapHandler { onTapped: root.activate(root.source.length) }
        }
    }
}
