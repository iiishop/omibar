pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../core"
import "NoteLogic.js" as Logic

ColumnLayout {
    id: root
    required property var note
    signal patched(var values)
    signal completed()
    property string dateError: ""

    function applyDue(): void {
        const value = Logic.parseDue(day.text, time.text);
        if (value === null) {
            dateError = qsTr("请输入有效的本地日期 YYYY-MM-DD 和时间 HH:mm");
            return;
        }
        dateError = "";
        patched({ dueAt: value, snoozedUntil: null, lastAlertedAt: null });
    }

    RowLayout {
        Layout.fillWidth: true
        CheckBox {
            text: qsTr("Todo")
            checked: root.note.todo
            onToggled: root.patched({ todo: checked })
        }
        TextField {
            id: day
            Layout.preferredWidth: 132
            visible: root.note.todo
            text: root.note.dueAt === null ? "" : Logic.dateKey(root.note.dueAt)
            placeholderText: qsTr("YYYY-MM-DD")
            Accessible.name: qsTr("到期日期 YYYY-MM-DD")
            onAccepted: root.applyDue()
        }
        TextField {
            id: time
            Layout.preferredWidth: 82
            visible: root.note.todo
            text: root.note.dueAt === null ? "" : Qt.formatDateTime(new Date(root.note.dueAt), "HH:mm")
            placeholderText: qsTr("HH:mm")
            Accessible.name: qsTr("到期时间 HH:mm")
            onAccepted: root.applyDue()
        }
        Button { visible: root.note.todo; text: qsTr("设定"); onClicked: root.applyDue() }
        Button {
            visible: root.note.todo
            text: root.note.completedAt === null ? qsTr("完成") : qsTr("取消完成")
            onClicked: root.completed()
        }
        Item { Layout.fillWidth: true }
    }
    Label { visible: root.dateError !== ""; text: root.dateError; color: Theme.error; Layout.fillWidth: true; wrapMode: Text.Wrap }
}
