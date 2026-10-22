// Run with isolated XDG_STATE_HOME and QT_QPA_PLATFORM=offscreen.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "core"
import "modules/note" as Note

ShellRoot {
    id: suite
    property int alerts: 0
    property string noteId: ""
    property var markdown: null
    property var sourceInput: null
    property var capsuleStore: null
    property var shelfWindow: null
    property bool shelfCaptured: false
    function find(item: Item, name: string): var {
        if (item.objectName === name) return item;
        for (const child of item.children) {
            const result = find(child, name);
            if (result) return result;
        }
        return null;
    }
    function check(condition: bool, message: string): void {
        if (!condition) { console.error("FAIL: " + message); Qt.exit(1); }
    }
    Note.NoteStore {
        id: store
        barState: BarState
        storagePath: Quickshell.env("NOTE_TEST_PATH")
        onAlerted: suite.alerts++
    }
    FloatingWindow {
        visible: true
        implicitWidth: 600
        implicitHeight: 100
        Note.Module {
            id: capsule
            barState: BarState
            storagePath: Quickshell.env("NOTE_TEST_PATH") + ".capsule"
            soundEnabled: false
        }
    }
    Note.NoteEditorWindow {
        id: editor
        store: store
    }
    Timer {
        interval: 10000
        running: true
        onTriggered: { console.error("FAIL: note test timed out"); Qt.exit(1); }
    }
    SequentialAnimation {
        running: true
        PauseAnimation { duration: 350 }
        ScriptAction {
            script: {
                suite.check(store.ready, "Missing notes file starts an empty store");
                suite.noteId = store.create(true);
                store.update(suite.noteId, { body: "# Test\n\n- [ ] prose only", dueAt: Date.now() - 1000 });
                suite.check(suite.alerts === 1 && store.dueNotes.length === 1, "Due todo alerts once");
                store.checkDue(Date.now());
                suite.check(suite.alerts === 1, "Minute check does not repeat sound");
                store.snooze(suite.noteId);
                suite.check(store.dueNotes.length === 0, "Snooze hides active alert");
                store.checkDue(Date.now() + 11 * 60000);
                suite.check(suite.alerts === 2, "Snooze triggers once at its deadline");
                store.acknowledge(suite.noteId);
                suite.check(store.dueNotes.length === 0, "Open acknowledges without completing");
                suite.check(store.get(suite.noteId).completedAt === null, "Open does not complete");
                editor.select(suite.noteId, "");
                store.toggleCompleted(suite.noteId);
                suite.check(store.shelf.length === 0, "Completed todo leaves shelf");
                store.flush(true);
                suite.check(!store.dirty && !store.error, "Atomic save succeeds");
                store.reload();
                capsule.enter();
                suite.check(capsule.mode === "create", "Hover always starts create");
                capsule.leave();
            }
        }
        PauseAnimation { duration: 300 }
        ScriptAction {
            script: {
                suite.check(store.ready && store.notes.length === 1, "Saved note reloads");
                suite.check(store.get(suite.noteId).body === "# Test\n\n- [ ] prose only", "Markdown persists exactly");
                suite.capsuleStore = suite.find(capsule, "noteStore");
                for (let i = 0; i < 30; ++i) suite.capsuleStore.create(false);
                capsule.enter();
                suite.check(capsule.mode === "create", "A populated shelf still opens in create mode");
                capsule.wheel({ pixelDelta: {y: 0}, angleDelta: {y: -60} });
                suite.check(capsule.selectedIndex === -1, "Half notch accumulates without changing note");
                capsule.wheel({ pixelDelta: {y: 0}, angleDelta: {y: -60} });
                suite.check(capsule.selectedIndex === 0 && capsule.mode === "browse", "Full notch selects newest note");
                for (let i = 0; i < 35; ++i) capsule.step(1);
                suite.check(capsule.selectedIndex === 29, "Wheel never passes oldest note");
                capsule.step(-1);
                suite.check(capsule.selectedIndex === 28, "Reverse wheel moves back toward newer notes");
                for (let i = 0; i < 24; ++i) capsule.step(-1);
                const sidebar = suite.find(editor.contentItem, "noteSidebar");
                sidebar.filter = "trash";
                store.toggleCompleted(suite.noteId);
                const day = Qt.formatDateTime(new Date(store.get(suite.noteId).dueAt), "yyyy-MM-dd");
                editor.select("", day);
                suite.check(sidebar.filter === "all" && sidebar.filtered.length === 1,
                    "Calendar date requests replace stale sidebar filters");
                editor.create(false);
                suite.markdown = suite.find(editor.contentItem, "markdownEditor");
                suite.markdown.load("# Heading\n\nParagraph\n");
                suite.markdown.activate(0);
            }
        }
        PauseAnimation { duration: 300 }
        ScriptAction {
            script: {
                suite.sourceInput = suite.find(editor.contentItem, "markdownSource");
                suite.check(suite.sourceInput !== null, "Active Markdown line is editable");
                for (const resource of capsule.resources) {
                    if (resource.objectName === "noteShelf") suite.shelfWindow = resource;
                }
                suite.check(suite.shelfWindow !== null, "Shelf is a separate popup window");
                const shelfSurface = suite.find(suite.shelfWindow.contentItem, "noteShelfSurface");
                suite.check(shelfSurface.children.filter(child => child instanceof Note.NoteShelfCard).length === 7,
                    "Shelf retains only seven card delegates for thirty notes");
                shelfSurface.grabToImage(result => {
                    result.saveToFile(Quickshell.env("NOTE_TEST_PATH") + ".shelf.png");
                    suite.shelfCaptured = true;
                });
                suite.sourceInput.insert(2, "Live ");
                suite.check(suite.markdown.source === "# Live Heading\n\nParagraph\n", "Typing changes exact source only");
                suite.markdown.activate(suite.markdown.source.indexOf("Paragraph"));
            }
        }
        PauseAnimation { duration: 100 }
        ScriptAction {
            script: {
                suite.check(suite.shelfCaptured, "Shelf preview finishes before the popup is closed");
                capsule.openEditor("", "");
                suite.check(capsule.mode === "editor", "Opening editor collapses capsule");
                capsule.editorOpen = false;
                const firstDue = suite.capsuleStore.notes[0].id;
                const secondDue = suite.capsuleStore.notes[1].id;
                suite.capsuleStore.update(firstDue, { todo: true, dueAt: Date.now() - 1000 });
                suite.capsuleStore.update(secondDue, { todo: true, dueAt: Date.now() - 1000 });
                capsule.leave();
                capsule.enter();
                suite.check(capsule.mode === "due", "Hover preserves a pending reminder for direct action");
                const previousDue = capsule.currentNote.id;
                capsule.step(1);
                suite.check(capsule.currentNote.id !== previousDue, "Wheel rotates multiple due notes");
            }
        }
        PauseAnimation { duration: 100 }
        ScriptAction {
            script: {
                suite.sourceInput = suite.find(editor.contentItem, "markdownSource");
                suite.check(suite.sourceInput.text === "Paragraph\n", "Moving focus renders previous line and edits new line");
                suite.sourceInput.insert(0, "New line\n");
                suite.sourceInput.cursorPosition = 10;
            }
        }
        PauseAnimation { duration: 100 }
        ScriptAction {
            script: {
                suite.sourceInput = suite.find(editor.contentItem, "markdownSource");
                suite.check(suite.sourceInput.text === "Paragraph\n", "Multiline edits follow the current cursor line");
                const beforeUndo = suite.markdown.source;
                suite.markdown.travelHistory(-1);
                suite.check(!suite.markdown.source.includes("New line"), "Undo survives a block focus transition");
                suite.markdown.travelHistory(1);
                suite.check(suite.markdown.source === beforeUndo, "Redo restores the exact Markdown document");
                store.update(editor.selectedId, {
                    title: "灵感收纳 · Quick Capture", todo: true, dueAt: Date.now() + 3600000,
                    body: "# 把想法留住\n\n需要的时候，展开成一个完整工具。\n\n- [x] 快速记录想法\n- [ ] 把重要的事情设为 Todo\n\n> 正文里的 checkbox 只属于 Markdown。\n> 提醒由上方的 Todo 属性管理。\n\n| 功能 | 状态 |\n| --- | --- |\n| 自动保存 | 就绪 |\n| 日历联动 | 就绪 |\n\n```js\nconst idea = capture();\n```"
                });
                editor.select(editor.selectedId, "");
            }
        }
        PauseAnimation { duration: 200 }
        ScriptAction {
            script: {
                store.flush(true);
                suite.find(editor.contentItem, "editorSurface").grabToImage(result => {
                    result.saveToFile(Quickshell.env("NOTE_TEST_PATH") + ".png");
                    editor.dismiss();
                    suite.check(!editor.visible && !store.dirty && !store.saving, "Closing waits for saved content");
                    console.info("PASS: note persistence, reminders, snooze, live Markdown, editor and capsule");
                    Qt.quit();
                });
            }
        }
    }
}
