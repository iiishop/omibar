pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

Item {
    id: root
    property string soundPath: Qt.resolvedUrl("assets/alert.wav").toString().replace("file://", "")
    property string player: ""
    property bool probing: true
    property bool pending: false

    function play(): void {
        if (!enabled) return;
        if (probing) { pending = true; return; }
        if (!player || playback.running) return; // Optional executable may be unavailable; merge overlapping alerts.
        playback.command = player === "canberra-gtk-play"
            ? [player, "-f", soundPath] : [player, soundPath];
        playback.running = true;
    }

    Process {
        command: ["sh", "-c", "for p in pw-play canberra-gtk-play aplay; do if command -v \"$p\" >/dev/null 2>&1; then printf '%s' \"$p\"; break; fi; done"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.player = text.trim();
                root.probing = false;
                if (root.pending) { root.pending = false; root.play(); }
            }
        }
    }
    Process {
        id: playback
        // Audio is an optional enhancement: playback failure means visual-only alerts.
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }
}
