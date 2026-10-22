pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../../core"
import "NoteLogic.js" as Logic

Item {
    id: root
    required property BarState barState
    property bool respectDnd: true
    property bool soundEnabled: true
    property alias storagePath: store.storagePath
    readonly property int iconSize: 18
    readonly property int labelSize: 12
    readonly property int gap: 8
    readonly property int hoverGraceMs: 140
    readonly property int wheelAngleStep: 120
    readonly property int wheelPixelStep: 40
    property string interaction: "idle"
    property int selectedIndex: -1
    property int dueIndex: 0
    property real wheelRemainder: 0
    property real bounce: 0
    property bool editorOpen: false
    property string editorNoteId: ""
    property string editorDate: ""
    readonly property var currentNote: interaction === "browse" ? store.shelf[selectedIndex] ?? null
        : store.dueNotes[dueIndex % Math.max(1, store.dueNotes.length)] ?? null
    readonly property string mode: editorOpen ? "editor" : interaction !== "idle" ? interaction
        : store.dueNotes.length ? "due" : "idle"
    readonly property bool expanded: ["create", "browse", "due"].includes(mode)
    readonly property string label: store.error ? qsTr("笔记存储错误") : mode === "create" ? qsTr("新增一条")
        : expanded && currentNote ? (Logic.title(currentNote) || qsTr("未命名")) : qsTr("note")
    implicitWidth: iconSize + gap + (expanded ? chinese.width : idleText.width)
    implicitHeight: 24
    width: implicitWidth
    height: implicitHeight
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.onPressAction: activate()
    Keys.onReturnPressed: activate()
    Keys.onSpacePressed: activate()
    Keys.onDownPressed: step(1)
    Keys.onUpPressed: step(-1)
    Keys.onEscapePressed: leave()

    function enter(): void {
        hideShelf.stop();
        if (editorOpen || interaction !== "idle") return;
        selectedIndex = -1;
        wheelRemainder = 0;
        interaction = store.dueNotes.length > 0 ? "due" : "create";
    }
    function leave(): void { interaction = "idle"; selectedIndex = -1; }
    function activate(): void {
        const id = mode === "create" || mode === "idle" ? store.create(false) : currentNote?.id ?? "";
        openEditor(id, "");
    }
    function openEditor(id: string, day: string): void {
        store.acknowledge(id);
        flash.stop();
        highlight.opacity = 0;
        leave();
        editorNoteId = id;
        editorDate = day;
        editorOpen = true;
        if (editorLoader.status === Loader.Ready)
            (editorLoader.item as NoteEditorWindow).select(id, day);
    }
    function step(direction: int): void {
        if (mode === "due") {
            dueIndex = (dueIndex + direction + store.dueNotes.length) % store.dueNotes.length;
            shine.restart();
            return;
        }
        const next = Math.max(-1, Math.min(store.shelf.length - 1, selectedIndex + direction));
        if (next === selectedIndex) {
            bounce = direction * 4;
            recoil.restart();
            return;
        }
        selectedIndex = next;
        interaction = next < 0 ? "create" : "browse";
        shine.restart();
    }
    function wheel(event: var): void {
        const pixels = event.pixelDelta.y;
        wheelRemainder -= pixels !== 0 ? pixels / wheelPixelStep : event.angleDelta.y / wheelAngleStep;
        const steps = Math.trunc(wheelRemainder);
        wheelRemainder -= steps;
        for (let i = 0; i < Math.abs(steps); ++i) step(Math.sign(steps));
        event.accepted = true;
    }

    TextMetrics { id: chinese; font.family: Theme.bodyFont; font.pixelSize: root.labelSize; text: "测测测测测测测测测测测测测测测" }
    TextMetrics { id: idleText; font.family: Theme.bodyFont; font.pixelSize: root.labelSize; text: qsTr("note") }
    Row {
        anchors.centerIn: parent
        spacing: root.gap
        transform: Translate { y: root.bounce }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.mode === "due" || store.error ? "notification_important" : root.mode === "create" ? "add" : "edit_note"
            color: root.mode === "due" || store.error ? Theme.error : Theme.tertiary
            font.family: Theme.iconFont
            font.pixelSize: root.iconSize
        }
        Item {
            width: root.expanded ? chinese.width : idleText.width
            height: root.implicitHeight
            Text {
                id: titleText
                anchors.fill: parent
                rightPadding: dueCount.visible ? dueCount.width + root.gap : 0
                text: root.label
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                color: Theme.fg
                font.family: Theme.bodyFont
                font.pixelSize: root.labelSize
            }
            Text {
                id: highlight
                anchors.fill: parent
                rightPadding: titleText.rightPadding
                text: titleText.text
                font: titleText.font
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                color: Theme.primary
                opacity: 0
            }
            Text {
                id: dueCount
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.mode === "due" && store.dueNotes.length > 1
                text: "+" + (store.dueNotes.length - 1)
                color: Theme.error
                font.pixelSize: root.labelSize
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: 6
        color: "transparent"
        border.width: root.activeFocus ? 1 : 0
        border.color: Theme.primary
    }
    HoverHandler { id: hover; onHoveredChanged: { if (hovered) root.enter(); else hideShelf.restart(); } }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: event => { if (event.button === Qt.RightButton) actions.popup(); else root.activate(); }
        onWheel: event => root.wheel(event)
    }
    Menu {
        id: actions
        MenuItem { text: qsTr("打开"); onTriggered: root.openEditor(root.currentNote?.id ?? "", "") }
        MenuItem { text: qsTr("完成"); enabled: root.currentNote?.todo ?? false; onTriggered: store.toggleCompleted(root.currentNote.id) }
        MenuItem { text: qsTr("10 分钟后提醒"); enabled: root.currentNote?.todo ?? false; onTriggered: store.snooze(root.currentNote.id) }
    }
    Timer {
        id: hideShelf
        interval: root.hoverGraceMs
        onTriggered: { if (!hover.hovered && !shelf.hovered) root.leave(); }
    }
    NumberAnimation { id: recoil; target: root; property: "bounce"; to: 0; duration: 190; easing.type: Easing.OutBack }
    SequentialAnimation {
        id: shine
        PropertyAction { target: highlight; property: "opacity"; value: 1 }
        NumberAnimation { target: highlight; property: "opacity"; to: 0; duration: 220 }
    }
    SequentialAnimation {
        id: flash
        loops: 3
        PropertyAction { target: highlight; property: "opacity"; value: 1 }
        NumberAnimation { target: highlight; property: "opacity"; to: 0; duration: 180 }
        PauseAnimation { duration: 120 }
    }
    NoteStore {
        id: store
        barState: root.barState
        onShelfChanged: {
            if (root.interaction === "browse" && root.selectedIndex >= store.shelf.length) {
                root.selectedIndex = store.shelf.length - 1;
                root.interaction = root.selectedIndex < 0 ? "create" : "browse";
            }
        }
        onDueNotesChanged: {
            if (root.interaction === "due" && dueNotes.length === 0)
                root.interaction = hover.hovered || shelf.hovered ? "create" : "idle";
        }
        onAlerted: {
            root.dueIndex = 0;
            if (!root.editorOpen) {
                root.interaction = "due";
                flash.restart();
            }
            sound.play();
        }
    }
    NoteSound { id: sound; enabled: root.soundEnabled && !(root.respectDnd && root.barState.notificationDnd) }
    NoteShelf {
        id: shelf
        anchorItem: root
        notes: store.shelf
        selectedIndex: root.selectedIndex
        cardWidth: chinese.width + root.iconSize + root.gap
        open: !root.editorOpen && (root.mode === "create" || root.mode === "browse"
            || root.mode === "due" && (hover.hovered || hovered)) && notes.length > 0
        onHoveredChanged: { if (hovered) hideShelf.stop(); else hideShelf.restart(); }
        onSelected: id => root.openEditor(id, "")
        onScrolled: event => root.wheel(event)
    }
    Loader {
        id: editorLoader
        active: root.editorOpen
        sourceComponent: NoteEditorWindow {
            store: store
            initialNoteId: root.editorNoteId
            initialDate: root.editorDate
            onDismissed: root.editorOpen = false
        }
    }
    Connections {
        target: root.barState
        function onNoteDateRequestSerialChanged(): void {
            root.openEditor("", root.barState.noteDateRequest);
        }
    }
}
