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
    // 多播放器共存时（浏览器 + 音乐播放器）优先正在播放的那个，
    // 否则回落到第一个，避免 bar 停在无曲目的播放器上显示空白。
    readonly property MprisPlayer active: players.find(player => player.isPlaying)
        ?? (players.length > 0 ? players[0] : null)
    readonly property bool hasLyrics: lyricEntries.length > 0
    readonly property bool shouldRunCava: BarState.mediaAvailable
        && BarState.mediaPlaying
        && !BarState.mediaLyricsAvailable
    readonly property string cavaCommand: "printf '%s\\n' '[general]' 'bars = 18' '[output]' 'method = raw' 'raw_target = /dev/stdout' 'data_format = ascii' 'ascii_max_range = 1000' > /tmp/omibar-cava.conf && exec cava -p /tmp/omibar-cava.conf"
    readonly property real lyricLeadSeconds: 0.2
    readonly property int lyricLineOffset: 1

    property string trackKey: ""
    property real positionAnchor: 0
    property real positionAnchorMs: 0
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
            LyricsProvider.clearTrack();
            positionAnchor = 0;
            positionAnchorMs = 0;
            BarState.mediaAvailable = false;
            BarState.mediaPlaying = false;
            BarState.mediaTitle = "";
            BarState.mediaArtist = "";
            BarState.mediaAlbum = "";
            BarState.mediaArtUrl = "";
            BarState.mediaPosition = 0;
            BarState.mediaLength = 0;
            BarState.mediaLyricsLoading = false;
            BarState.mediaLyricsAvailable = false;
            BarState.mediaLyric = "";
            BarState.mediaSpectrum = [];
            BarState.mediaPlayMode = "sequential";
            BarState.mediaPlayModeAvailable = false;
            return;
        }

        BarState.mediaAvailable = true;
        BarState.mediaPlaying = player.isPlaying;
        BarState.mediaTitle = textValue(player.trackTitle);
        BarState.mediaArtist = textValue(player.trackArtist);
        BarState.mediaAlbum = textValue(player.trackAlbum);
        BarState.mediaArtUrl = textValue(player.trackArtUrl);
        BarState.mediaLength = secondsValue(player.length);
        syncPosition(player);
        refreshPlayMode();

        const nextKey = currentKey(player);
        if (nextKey !== trackKey) {
            trackKey = nextKey;
            requestLyrics(player);
        }
        updateLyric();
    }

    function syncPosition(player: MprisPlayer): void {
        positionAnchor = secondsValue(player.position);
        positionAnchorMs = Date.now();
        BarState.mediaPosition = projectedPosition();
    }

    function projectedPosition(): real {
        if (active === null)
            return 0;

        const elapsed = BarState.mediaPlaying
            ? Math.max(0, (Date.now() - positionAnchorMs) / 1000) : 0;
        const projected = positionAnchor + elapsed;
        return BarState.mediaLength > 0
            ? Math.min(BarState.mediaLength, projected)
            : projected;
    }

    function refreshPosition(): void {
        BarState.mediaPosition = projectedPosition();
        updateLyric();
    }

    function requestLyrics(player: MprisPlayer): void {
        LyricsProvider.setTrack(
            trackKey,
            textValue(player.trackArtist),
            textValue(player.trackTitle),
            textValue(player.trackAlbum),
            secondsValue(player.length)
        );
        syncLyrics();
    }

    function syncLyrics(): void {
        if (LyricsProvider.requestKey !== trackKey)
            return;

        lyricEntries = LyricsProvider.entries;
        BarState.mediaLyricsLoading = LyricsProvider.loading;
        BarState.mediaLyricsAvailable = false;
        BarState.mediaLyric = "";

        if (hasLyrics) {
            BarState.mediaLyricsAvailable = true;
            updateLyric();
        }
    }

    function updateLyric(): void {
        if (!hasLyrics) {
            BarState.mediaLyric = "";
            return;
        }

        const position = BarState.mediaPosition + lyricLeadSeconds;
        let currentIndex = 0;
        for (let i = 0; i < lyricEntries.length; ++i) {
            if (lyricEntries[i].time > position)
                break;
            currentIndex = i;
        }

        const displayIndex = Math.min(lyricEntries.length - 1,
            currentIndex + lyricLineOffset);
        const current = lyricEntries[displayIndex];
        BarState.mediaLyric = current.text === "" ? "♪" : current.text;
    }

    function refreshPlayMode(): void {
        const player = active;
        if (player === null) {
            BarState.mediaPlayMode = "sequential";
            BarState.mediaPlayModeAvailable = false;
            return;
        }

        if (player.shuffleSupported && player.shuffle) {
            BarState.mediaPlayMode = "shuffle";
        } else if (player.loopSupported && player.loopState === MprisLoopState.Track) {
            BarState.mediaPlayMode = "repeatTrack";
        } else {
            BarState.mediaPlayMode = "sequential";
        }
        BarState.mediaPlayModeAvailable = availablePlayModes().length > 1;
    }

    function availablePlayModes(): var {
        const player = active;
        if (player === null || !player.canControl)
            return [];

        const modes = ["sequential"];
        if (player.loopSupported)
            modes.push("repeatTrack");
        if (player.shuffleSupported)
            modes.push("shuffle");
        return modes;
    }

    function cyclePlayMode(): void {
        const modes = availablePlayModes();
        if (modes.length < 2)
            return;

        const current = modes.indexOf(BarState.mediaPlayMode);
        applyPlayMode(modes[(current + 1) % modes.length]);
    }

    function applyPlayMode(mode: string): void {
        const player = active;
        if (player === null || !player.canControl)
            return;

        if (player.shuffleSupported)
            player.shuffle = mode === "shuffle";
        if (player.loopSupported)
            player.loopState = mode === "repeatTrack"
                ? MprisLoopState.Track : MprisLoopState.None;
        refreshPlayMode();
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
        function onTrackArtUrlChanged(): void { root.refreshPlayer(); }
        function onLengthChanged(): void { root.refreshPlayer(); }
        function onCanControlChanged(): void { root.refreshPlayMode(); }
        function onLoopStateChanged(): void { root.refreshPlayMode(); }
        function onLoopSupportedChanged(): void { root.refreshPlayMode(); }
        function onShuffleChanged(): void { root.refreshPlayMode(); }
        function onShuffleSupportedChanged(): void { root.refreshPlayMode(); }
        function onPositionChanged(): void {
            if (root.active !== null) {
                root.syncPosition(root.active);
                root.updateLyric();
            }
        }
    }

    readonly property Connections lyricsConnections: Connections {
        target: LyricsProvider

        function onEntriesChanged(): void { root.syncLyrics(); }
        function onLoadingChanged(): void { root.syncLyrics(); }
    }

    readonly property Timer positionTimer: Timer {
        interval: 300
        running: root.active !== null
        repeat: true
        onTriggered: root.refreshPosition()
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
