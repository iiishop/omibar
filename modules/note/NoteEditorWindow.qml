pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import "../../core"
import "NoteLogic.js" as Logic

FloatingWindow {
    id: root
    required property NoteStore store
    property string initialNoteId: ""
    property string initialDate: ""
    property string selectedId: ""
    readonly property var note: store.get(selectedId)
    signal dismissed
    title: qsTr("omibar · Notes")
    color: "transparent"
    implicitWidth: 1000
    implicitHeight: 680
    minimumSize: Qt.size(900, 500)
    visible: true

    function select(id: string, day: string): void {
        store.flush(false);
        if (!id) sidebar.resetFilters(day);
        else sidebar.dateFilter = day;
        const candidates = Logic.filterNotes(store.notes, "", "all", day, store.now);
        selectedId = id || candidates[0]?.id || "";
        markdown.load(note ? note.body : "");
        store.acknowledge(selectedId);
    }
    function create(todo: bool): void {
        const id = store.create(todo);
        if (!id)
            return;
        sidebar.resetFilters("");
        select(id, "");
        markdown.activate(0);
    }
    function dismiss(): void {
        store.flush(true);
        if (store.error && store.dirty)
            return; // Keep unsaved content recoverable after a failed close-time write.
        visible = false;
    }

    Component.onCompleted: select(initialNoteId, initialDate)
    onVisibleChanged: {
        if (!visible) {
            store.flush(true);
            if (store.error && store.dirty)
                visible = true;
            else
                dismissed();
        }
    }
    Shortcut {
        sequence: "Ctrl+N"
        onActivated: root.create(false)
    }
    Shortcut {
        sequence: "Ctrl+Shift+N"
        onActivated: root.create(true)
    }
    Shortcut {
        sequence: "Ctrl+F"
        onActivated: sidebar.focusSearch()
    }
    Shortcut {
        sequence: "Ctrl+Return"
        onActivated: root.store.toggleCompleted(root.selectedId)
    }
    Shortcut {
        sequence: "Escape"
        onActivated: root.dismiss()
    }

    Pane {
        objectName: "editorSurface"
        anchors.fill: parent
        padding: 0
        background: Item {}
        palette.window: Theme.surfaceContainer
        palette.windowText: Theme.fg
        palette.base: Theme.surfaceContainerHigh
        palette.text: Theme.fg
        palette.button: Theme.surfaceContainerHigh
        palette.buttonText: Theme.fg
        palette.highlight: Theme.secondaryContainer
        palette.highlightedText: Theme.fg
        palette.placeholderText: Theme.fgVariant
        contentItem: RowLayout {
            spacing: 14
            NoteSidebar {
                id: sidebar
                Layout.preferredWidth: Math.max(220, Math.min(260, root.width * 0.28))
                Layout.fillHeight: true
                store: root.store
                selectedId: root.selectedId
                onSelected: id => root.select(id, dateFilter)
                onCreated: todo => root.create(todo)
            }
            Rectangle {
                Layout.fillHeight: true
                Layout.fillWidth: true
                radius: 24
                color: Theme.surfaceContainer
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 12
                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: qsTr("MARKDOWN")
                            color: Theme.fgVariant
                            font.pixelSize: 11
                            Layout.fillWidth: true
                            DragHandler {
                                target: null
                                onActiveChanged: { if (active) root.startSystemMove(); }
                            }
                        }
                        Label {
                            text: root.store.dirty || root.store.saving ? qsTr("保存中…") : qsTr("已保存")
                            color: Theme.fgVariant
                            font.pixelSize: 11
                        }
                        Button {
                            text: qsTr("关闭")
                            onClicked: root.dismiss()
                        }
                    }
                    Label {
                        visible: root.store.error !== ""
                        text: root.store.error
                        color: Theme.error
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                    Button {
                        visible: root.store.error !== ""
                        text: root.store.dirty ? qsTr("重试保存") : qsTr("重新读取")
                        onClicked: {
                            if (root.store.dirty)
                                root.store.retrySave();
                            else
                                root.store.reload();
                        }
                    }
                    TextField {
                        id: titleInput
                        visible: root.note !== null
                        enabled: root.store.ready
                        Layout.fillWidth: true
                        text: root.note ? root.note.title : ""
                        placeholderText: root.note ? Logic.title(root.note) || qsTr("未命名") : qsTr("未命名")
                        Accessible.name: qsTr("笔记标题，留空则使用正文首行")
                        font.family: Theme.bodyFont
                        font.pixelSize: 24
                        color: Theme.fg
                        onTextEdited: root.store.update(root.selectedId, {
                            title: text
                        })
                    }
                    Loader {
                        Layout.fillWidth: true
                        active: root.note !== null
                        sourceComponent: TodoProperties {
                            note: root.note
                            onPatched: values => root.store.update(root.selectedId, values)
                            onCompleted: root.store.toggleCompleted(root.selectedId)
                        }
                    }
                    RowLayout {
                        visible: root.note !== null
                        Button {
                            text: root.note?.pinned ? qsTr("取消置顶") : qsTr("置顶")
                            onClicked: root.store.update(root.selectedId, {
                                pinned: !root.note.pinned
                            })
                        }
                        Button {
                            text: root.note?.archived ? qsTr("取消归档") : qsTr("归档")
                            onClicked: root.store.update(root.selectedId, {
                                archived: !root.note.archived
                            })
                        }
                        Button {
                            text: root.note?.deletedAt ? qsTr("恢复") : qsTr("移入回收站")
                            onClicked: root.store.update(root.selectedId, {
                                deletedAt: root.note.deletedAt === null ? Date.now() : null
                            })
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Theme.outlineVariant
                    }
                    MarkdownEditor {
                        id: markdown
                        objectName: "markdownEditor"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: root.note !== null
                        enabled: root.store.ready
                        onEdited: text => root.store.update(root.selectedId, {
                                body: text
                            })
                    }
                    Label {
                        visible: root.note === null
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: qsTr("捕捉一个想法\n\nCtrl+N 新建笔记 · Ctrl+Shift+N 新建 Todo")
                        color: Theme.fgVariant
                    }
                }
            }
        }
    }
}
