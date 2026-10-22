pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "core"
import "modules/note" as Note

ShellRoot {
    id: suite
    property string noteId: ""
    function check(condition: bool, message: string): void {
        if (!condition) { console.error("FAIL: " + message); Qt.exit(1); }
    }
    Note.NoteStore {
        id: corrupt
        barState: BarState
        storagePath: Quickshell.env("NOTE_TEST_PATH") + ".bad"
    }
    Note.NoteStore {
        id: writable
        barState: BarState
        storagePath: Quickshell.env("NOTE_TEST_PATH") + ".failure"
    }
    Process {
        id: obstruct
        command: ["mkdir", writable.storagePath]
        onExited: code => {
            suite.check(code === 0, "Test obstruction directory created");
            suite.noteId = writable.create(false);
            writable.update(suite.noteId, { body: "Unsaved content must survive" });
            writable.flush(true);
            suite.check(writable.dirty && writable.error !== "", "IO failure remains visible and dirty");
            writable.flush(true);
            suite.check(writable.dirty && writable.error !== "", "Close cannot mark a failed cached write as saved");
            unblock.running = true;
        }
    }
    Process {
        id: unblock
        command: ["rmdir", writable.storagePath]
        onExited: code => {
            suite.check(code === 0, "Test obstruction removed");
            writable.retrySave();
            verify.restart();
        }
    }
    Timer {
        interval: 200
        running: true
        onTriggered: {
            suite.check(!corrupt.ready && corrupt.error !== "", "Malformed JSON blocks writes");
            suite.check(corrupt.create(false) === "", "Malformed JSON cannot be silently replaced");
            suite.check(writable.ready, "Missing file starts editable store");
            obstruct.running = true;
        }
    }
    Timer {
        id: verify
        interval: 400
        onTriggered: {
            suite.check(!writable.dirty && !writable.saving && writable.error === "", "Retry saves after IO recovers");
            suite.check(writable.get(suite.noteId).body === "Unsaved content must survive", "Retry preserves in-memory edits");
            writable.reload();
            roundtrip.restart();
        }
    }
    Timer {
        id: roundtrip
        interval: 200
        onTriggered: {
            suite.check(writable.ready && writable.get(suite.noteId).body === "Unsaved content must survive", "Retried write survives reload");
            console.info("PASS: corrupted storage, failed write, explicit retry and recovery");
            Qt.quit();
        }
    }
    Timer { interval: 5000; running: true; onTriggered: { console.error("FAIL: storage test timed out"); Qt.exit(1); } }
}
