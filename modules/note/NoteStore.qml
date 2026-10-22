pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../../core"
import "NoteLogic.js" as Logic

Item {
    id: root
    objectName: "noteStore"

    required property BarState barState
    property string storagePath: Quickshell.statePath("notes.json")
    property var notes: []
    property var alertIds: []
    property bool ready: false
    property bool dirty: false
    property bool saving: false
    property bool retrying: false
    property string error: ""
    property double now: Date.now()
    readonly property var shelf: Logic.shelfNotes(notes)
    readonly property var dueNotes: notes.filter(note => alertIds.includes(note.id) && Logic.isDue(note, now))
    readonly property int saveDelayMs: 350
    signal alerted()

    function get(id: string): var { return notes.find(note => note.id === id) ?? null; }

    function create(todo: bool): string {
        if (!ready) return ""; // Storage must load successfully before user edits can replace it.
        const note = Logic.createNote(Date.now(), todo);
        notes = notes.concat([note]);
        changed();
        return note.id;
    }

    function update(id: string, values: var): void {
        if (!ready) return;
        notes = notes.map(note => note.id === id
            ? Object.assign({}, note, values, { updatedAt: Date.now() }) : note);
        changed();
    }

    function changed(): void {
        dirty = true;
        saveDelay.restart();
        checkDue(Date.now());
    }

    function acknowledge(id: string): void {
        alertIds = alertIds.filter(value => value !== id);
    }

    function toggleCompleted(id: string): void {
        const note = get(id);
        if (note === null || !note.todo) return; // The selected note can be removed by a filter or reload.
        update(id, { completedAt: note.completedAt === null ? Date.now() : null });
    }

    function snooze(id: string): void {
        acknowledge(id);
        update(id, { snoozedUntil: Date.now() + 10 * Logic.minuteMs });
    }

    function checkDue(timestamp: double): void {
        now = timestamp;
        if (!ready) return;
        const summary = Logic.summarize(notes, now);
        barState.todoCountByDate = summary.todos;
        barState.overdueCountByDate = summary.overdue;
        const fresh = notes.filter(note => Logic.needsAlert(note, now)).map(note => note.id);
        alertIds = alertIds.filter(id => notes.some(note => note.id === id && Logic.isDue(note, now)));
        if (!fresh.length) return; // No new deadline crossed this minute.
        alertIds = Array.from(new Set(alertIds.concat(fresh)));
        notes = notes.map(note => fresh.includes(note.id)
            ? Object.assign({}, note, { lastAlertedAt: now }) : note);
        dirty = true;
        saveDelay.restart();
        alerted();
    }

    function flush(blocking: bool): void {
        saveDelay.stop();
        // FileView 0.3 can discard a pending async payload when saveSync cancels it.
        if (blocking) file.waitForJob();
        if (!ready || !dirty) return;
        if (error !== "") return; // A failed FileView write must reload its cache before retrying.
        const serialized = JSON.stringify({ version: 1, notes }, null, 2);
        if (error === "" && file.text() === serialized) {
            dirty = false;
            return;
        }
        file.blockWrites = blocking;
        dirty = false;
        saving = true;
        file.setText(serialized);
    }

    function retrySave(): void {
        // Reload FileView's failed-write cache, preserving the unsaved in-memory document.
        retrying = true;
        file.reload();
    }

    function reload(): void {
        if (dirty) return; // Never replace unsaved user input with disk contents.
        file.waitForJob();
        ready = false;
        file.reload();
    }

    Timer { id: saveDelay; interval: root.saveDelayMs; onTriggered: root.flush(false) }
    SystemClock {
        precision: SystemClock.Minutes
        onDateChanged: root.checkDue(Date.now())
    }
    Connections {
        target: Qt.application
        function onStateChanged(): void { root.checkDue(Date.now()); }
    }
    FileView {
        id: file
        path: root.storagePath
        printErrors: false
        atomicWrites: true
        onLoaded: {
            if (root.retrying) {
                root.retrying = false;
                root.error = "";
                Qt.callLater(() => root.flush(false));
                return;
            }
            try {
                root.notes = Logic.decode(text());
                root.error = "";
                root.ready = true;
                root.barState.noteAvailable = true;
                root.checkDue(Date.now());
            } catch (failure) {
                root.error = qsTr("笔记文件损坏或版本不兼容：%1").arg(failure.message);
                root.ready = false;
                root.barState.noteAvailable = false;
                console.warn("[note]", root.error);
            }
        }
        onLoadFailed: failure => {
            if (root.retrying) {
                root.retrying = false;
                root.error = "";
                Qt.callLater(() => root.flush(false));
                return;
            }
            root.ready = failure === FileViewError.FileNotFound;
            root.barState.noteAvailable = root.ready;
            root.error = root.ready ? "" : qsTr("无法读取笔记文件：%1").arg(failure);
            root.checkDue(Date.now());
        }
        onSaveFailed: failure => {
            root.saving = false;
            root.dirty = true;
            root.error = qsTr("保存失败，内容仍在内存中：%1").arg(failure);
            console.warn("[note]", root.error);
        }
        onSaved: { root.saving = false; root.error = ""; }
    }
    Component.onDestruction: {
        flush(true);
        barState.noteAvailable = false;
        barState.todoCountByDate = ({});
        barState.overdueCountByDate = ({});
    }
}
