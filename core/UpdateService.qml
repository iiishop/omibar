// UpdateService - read-only checks; each source owns its result and history.
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    readonly property int checkIntervalMs: 30 * 60 * 1000
    readonly property int busyRetryMs: 10 * 1000
    readonly property int timeoutSeconds: 120
    readonly property int missingExit: 127
    readonly property int busyExit: 75
    readonly property int timeoutExit: 124
    readonly property bool checking: BarState.updateState === "checking"
    property bool started: false

    function ensureStarted(): void {
        if (!started)
            refresh();
    }

    function refresh(): void {
        // Multiple bar instances and repeated clicks share one in-flight check.
        if (checking)
            return;
        started = true;
        for (const source of BarState.updateSources) {
            source.status = "checking";
            source.error = "";
            source.diagnostic = "";
        }
        repoProc.running = true;
        aurProc.running = true;
    }

    component SourceCheck: Process {
        id: check

        required property QtObject source
        required property string script
        required property int emptyExit

        command: ["timeout", "--kill-after=5", String(root.timeoutSeconds), "sh", "-c",
            'db_path=$(pacman-conf DBPath) || exit 1; '
            + 'if test -e "${db_path%/}/db.lck"; then exit '
            + root.busyExit + '; fi; ' + script]
        environment: ({ LC_ALL: "C", NO_COLOR: "1" })
        stdout: StdioCollector { id: output }
        stderr: StdioCollector { id: errors }

        onExited: (code, exitStatus) => {
            source.lastAttempt = Date.now();
            source.diagnostic = errors.text.trim();
            const lines = output.text.trim();
            // AUR helpers use 1 for both empty results and failures. Only a
            // clean, empty response can mean "no updates" in that case.
            const empty = code === emptyExit && lines === ""
                && source.diagnostic === "";
            if (exitStatus === 0 && (code === 0 || empty)) {
                source.count = lines === "" ? 0 : lines.split("\n").length;
                source.lastSuccess = source.lastAttempt;
                source.status = "success";
                return;
            }
            if (code === root.busyExit) {
                source.status = "busy";
                source.error = "database_busy";
                return;
            }
            if (code === root.missingExit) {
                source.status = "missing";
                source.error = "tool_missing";
                return;
            }
            source.status = "error";
            source.error = code === root.timeoutExit ? "timeout" : "check_failed";
        }
    }

    readonly property SourceCheck repoProc: SourceCheck {
        source: BarState.updateRepo
        emptyExit: 2
        script: "command -v checkupdates >/dev/null || exit 127; exec checkupdates --nocolor"
    }

    readonly property SourceCheck aurProc: SourceCheck {
        source: BarState.updateAur
        emptyExit: 1
        script: "if command -v paru >/dev/null; then exec paru -Quaq --color never; "
            + "elif command -v yay >/dev/null; then exec yay -Quaq --color never; "
            + "else exit 127; fi"
    }

    readonly property Timer refreshTimer: Timer {
        interval: BarState.updateState === "busy" ? root.busyRetryMs : root.checkIntervalMs
        running: root.started && !root.checking
        repeat: true
        onTriggered: root.refresh()
    }
}
