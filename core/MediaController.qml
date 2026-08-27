// MediaController — local MPRIS/lyrics/spectrum controller for the media module.
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

QtObject {
    id: root

    readonly property list<MprisPlayer> players: Mpris.players.values
    readonly property MprisPlayer active: players.length > 0 ? players[0] : null
    readonly property bool hasLyrics: lyricEntries.length > 0
    readonly property bool shouldRunCava: BarState.mediaAvailable
        && BarState.mediaPlaying
        && !BarState.mediaLyricsAvailable
    readonly property string cavaCommand: "printf '%s\\n' '[general]' 'bars = 18' '[output]' 'method = raw' 'raw_target = /dev/stdout' 'data_format = ascii' 'ascii_max_range = 1000' > /tmp/omibar-cava.conf && exec cava -p /tmp/omibar-cava.conf"

    property string trackKey: ""
    property string lyricRequestKey: ""
    property string lyricOutput: ""
    property var lyricEntries: []

    function textValue(value): string {
        if (Array.isArray(value))
            return value.join(", ");
        return value ?? "";
    }

    function secondsValue(value): real {
        const raw = Number(value ?? 0);
        return raw > 100000 ? raw / 1000000 : raw;
    }

    function currentKey(player: MprisPlayer): string {
        if (player === null)
            return "";
        return [
            textValue(player.trackArtist),
            textValue(player.trackTitle),
            textValue(player.trackAlbum),
            Math.round(secondsValue(player.length))
        ].join("\u0000");
    }

    function refreshPlayer(): void {
        const player = active;
        if (player === null) {
            trackKey = "";
            lyricEntries = [];
            BarState.mediaAvailable = false;
            BarState.mediaPlaying = false;
            BarState.mediaTitle = "";
            BarState.mediaArtist = "";
            BarState.mediaAlbum = "";
            BarState.mediaPosition = 0;
            BarState.mediaLength = 0;
            BarState.mediaLyricsLoading = false;
            BarState.mediaLyricsAvailable = false;
            BarState.mediaLyric = "";
            BarState.mediaSpectrum = [];
            return;
        }

        BarState.mediaAvailable = true;
        BarState.mediaPlaying = player.isPlaying;
        BarState.mediaTitle = textValue(player.trackTitle);
        BarState.mediaArtist = textValue(player.trackArtist);
        BarState.mediaAlbum = textValue(player.trackAlbum);
        BarState.mediaLength = secondsValue(player.length);
        BarState.mediaPosition = secondsValue(player.position);

        const nextKey = currentKey(player);
        if (nextKey !== trackKey) {
            trackKey = nextKey;
            fetchLyrics(player);
        }
        updateLyric();
    }

    function fetchLyrics(player: MprisPlayer): void {
        lyricEntries = [];
        lyricOutput = "";
        lyricRequestKey = trackKey;
        BarState.mediaLyricsAvailable = false;
        BarState.mediaLyric = "";
        BarState.mediaLyricsLoading = BarState.mediaTitle !== "";

        if (BarState.mediaTitle === "") {
            BarState.mediaLyricsLoading = false;
            return;
        }

        if (lyricsProc.running)
            lyricsProc.running = false;

        lyricsProc.command = [
            "curl", "-LsfG", "--max-time", "6",
            "--data-urlencode", "artist_name=" + BarState.mediaArtist,
            "--data-urlencode", "track_name=" + BarState.mediaTitle,
            "--data-urlencode", "album_name=" + BarState.mediaAlbum,
            "--data-urlencode", "duration=" + String(Math.round(BarState.mediaLength)),
            "https://lrclib.net/api/get"
        ];
        lyricsProc.running = true;
    }

    function applyLyrics(output: string): void {
        if (lyricRequestKey !== trackKey)
            return;

        BarState.mediaLyricsLoading = false;
        if (output.trim() === "") {
            lyricEntries = [];
            BarState.mediaLyricsAvailable = false;
            BarState.mediaLyric = "";
            return;
        }

        try {
            const data = JSON.parse(output);
            lyricEntries = parseLrc(data.syncedLyrics ?? "");
            BarState.mediaLyricsAvailable = hasLyrics;
            updateLyric();
        } catch (e) {
            console.warn("[omibar] lyrics parse failed:", e);
            lyricEntries = [];
            BarState.mediaLyricsAvailable = false;
            BarState.mediaLyric = "";
        }
    }

    function parseLrc(text: string): var {
        const entries = [];
        const lines = text.split("\n");
        const tagRe = /\[(\d+):(\d+(?:\.\d+)?)\]/g;

        for (const line of lines) {
            tagRe.lastIndex = 0;
            const lyricText = line.replace(tagRe, "").trim();
            let match = tagRe.exec(line);
            while (match !== null) {
                entries.push({
                    time: Number(match[1]) * 60 + Number(match[2]),
                    text: lyricText
                });
                match = tagRe.exec(line);
            }
        }

        entries.sort((a, b) => a.time - b.time);
        return entries;
    }

    function updateLyric(): void {
        if (!hasLyrics) {
            BarState.mediaLyric = "";
            return;
        }

        const position = BarState.mediaPosition + 0.12;
        let current = lyricEntries[0];
        for (const entry of lyricEntries) {
            if (entry.time > position)
                break;
            current = entry;
        }
        BarState.mediaLyric = current.text === "" ? "♪" : current.text;
    }

    function applySpectrum(line: string): void {
        const values = line.trim().split(/[;,\s]+/)
            .map(value => Math.max(0, Math.min(1, Number(value) / 1000)))
            .filter(value => !Number.isNaN(value));
        if (values.length > 0)
            BarState.mediaSpectrum = values;
    }

    function toggle(): void {
        if (active !== null && active.canTogglePlaying)
            active.togglePlaying();
    }

    function previous(): void {
        if (active !== null && active.canGoPrevious)
            active.previous();
    }

    function next(): void {
        if (active !== null && active.canGoNext)
            active.next();
    }

    onActiveChanged: refreshPlayer()

    readonly property Connections activeConnections: Connections {
        target: root.active

        function onIsPlayingChanged(): void { root.refreshPlayer(); }
        function onTrackTitleChanged(): void { root.refreshPlayer(); }
        function onTrackArtistChanged(): void { root.refreshPlayer(); }
        function onTrackAlbumChanged(): void { root.refreshPlayer(); }
        function onLengthChanged(): void { root.refreshPlayer(); }
        function onPositionChanged(): void {
            BarState.mediaPosition = root.secondsValue(root.active.position);
            root.updateLyric();
        }
    }

    readonly property Timer positionTimer: Timer {
        interval: 300
        running: root.active !== null
        repeat: true
        onTriggered: {
            BarState.mediaPosition = root.secondsValue(root.active.position);
            root.updateLyric();
        }
    }

    readonly property Process lyricsProc: Process {
        id: lyricsProc

        stdout: SplitParser {
            onRead: data => root.lyricOutput += data
        }
        stderr: SplitParser {}
        onExited: (code, status) => {
            root.applyLyrics(code === 0 ? root.lyricOutput : "");
        }
    }

    readonly property Process cavaProc: Process {
        running: root.shouldRunCava
        command: ["sh", "-c", root.cavaCommand]

        stdout: SplitParser {
            onRead: data => root.applySpectrum(data)
        }
        stderr: SplitParser {}
        onExited: (code, status) => {
            if (code !== 0)
                BarState.mediaSpectrum = [];
        }
    }

    Component.onCompleted: refreshPlayer()
}
