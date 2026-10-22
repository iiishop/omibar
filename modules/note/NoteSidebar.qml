pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../../core"
import "NoteLogic.js" as Logic

Rectangle {
    id: root
    objectName: "noteSidebar"
    required property NoteStore store
    required property string selectedId
    property string dateFilter: ""
    property string filter: "all"
    readonly property var filtered: Logic.filterNotes(store.notes, search.text, filter, dateFilter, store.now)
    signal selected(string id)
    signal created(bool todo)
    color: Theme.surfaceContainer
    radius: 24

    function focusSearch(): void { search.forceActiveFocus(); search.selectAll(); }
    function resetFilters(day: string): void {
        dateFilter = day;
        filter = "all";
        search.clear();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12
        RowLayout {
            Label { text: qsTr("Notes"); color: Theme.fg; font.family: Theme.bodyFont; font.pixelSize: 22; Layout.fillWidth: true }
            Button { text: "+"; Accessible.name: qsTr("新增笔记"); enabled: root.store.ready; onClicked: root.created(false) }
        }
        TextField {
            id: search
            Layout.fillWidth: true
            placeholderText: qsTr("搜索笔记…")
            Accessible.name: qsTr("搜索笔记")
            color: Theme.fg
        }
        ComboBox {
            Layout.fillWidth: true
            textRole: "label"
            valueRole: "value"
            currentIndex: model.findIndex(entry => entry.value === root.filter)
            model: [
                { label: qsTr("全部"), value: "all" }, { label: qsTr("Todo"), value: "todo" },
                { label: qsTr("今日"), value: "today" }, { label: qsTr("已完成"), value: "completed" },
                { label: qsTr("已归档"), value: "archived" }, { label: qsTr("回收站"), value: "trash" }
            ]
            onActivated: root.filter = currentValue
            Accessible.name: qsTr("笔记筛选")
        }
        Button {
            visible: root.dateFilter !== ""
            Layout.fillWidth: true
            text: qsTr("%1 × 清除日期").arg(root.dateFilter)
            onClicked: root.dateFilter = ""
        }
        ListView {
            id: list
            Layout.fillHeight: true
            Layout.fillWidth: true
            clip: true
            reuseItems: true
            spacing: 6
            model: root.filtered
            ScrollBar.vertical: ScrollBar {}
            delegate: ItemDelegate {
                id: entry
                required property var modelData
                width: list.width
                height: 64
                text: Logic.title(modelData) || qsTr("未命名")
                onClicked: root.selected(modelData.id)
                background: Rectangle {
                    radius: 12
                    color: entry.modelData.id === root.selectedId ? Theme.secondaryContainer
                        : entry.hovered ? Theme.surfaceContainerHigh : "transparent"
                    border.width: entry.activeFocus ? 1 : 0
                    border.color: Theme.primary
                }
                contentItem: Column {
                    spacing: 6
                    Text {
                        width: parent.width
                        text: entry.text
                        elide: Text.ElideRight
                        color: entry.modelData.completedAt !== null ? Theme.fgVariant : Theme.fg
                        font.family: Theme.bodyFont
                        font.pixelSize: 13
                        font.strikeout: entry.modelData.todo && entry.modelData.completedAt !== null
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: entry.modelData.todo && entry.modelData.dueAt !== null
                            ? (Logic.activeTodo(entry.modelData) && entry.modelData.dueAt <= root.store.now ? qsTr("已到期 · ") : "")
                                + Qt.formatDateTime(new Date(entry.modelData.dueAt), "MM-dd HH:mm")
                            : entry.modelData.pinned ? qsTr("已置顶") : qsTr("笔记")
                        color: Logic.activeTodo(entry.modelData) && entry.modelData.dueAt <= root.store.now ? Theme.error : Theme.fgVariant
                        font.pixelSize: 11
                    }
                }
            }
            Label {
                anchors.centerIn: parent
                visible: list.count === 0
                text: qsTr("这里还没有笔记")
                color: Theme.fgVariant
            }
        }
        Label {
            Layout.fillWidth: true
            text: qsTr("%1 条 · Ctrl+N 新建").arg(root.filtered.length)
            color: Theme.fgVariant
            font.pixelSize: 11
        }
    }
}
