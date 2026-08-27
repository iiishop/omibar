// LyricsProvider — LRCLIB lookup, candidate selection, and lyric parsing.
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    readonly property bool hasLyrics: entries.length > 0
    readonly property string clientHeader: "omibar/0.1"

    property string requestKey: ""
    property string phase: ""
    property string output: ""
    property string artist: ""
    property string title: ""
    property string album: ""
    property real duration: 0
    property bool loading: false
    property var entries: []
    property var cache: ({})

    function setTrack(key: string, nextArtist: string, nextTitle: string,
            nextAlbum: string, nextDuration: real): void {
        const cleanTitle = cleanText(nextTitle);
        if (key === requestKey && cleanTitle !== "" && (loading || hasLyrics))
            return;

        stopRequest();
        requestKey = key;
        artist = cleanText(nextArtist);
        title = cleanTitle;
        album = cleanText(nextAlbum);
        duration = Math.max(0, Number(nextDuration ?? 0));
        entries = [];
        loading = title !== "";

        if (title === "") {
            loading = false;
            return;
        }

        const cached = cache[requestKey];
        if (cached !== undefined) {
            entries = cached;
            loading = false;
            return;
        }

        startExactRequest();
    }

    function clearTrack(): void {
        stopRequest();
        requestKey = "";
        artist = "";
        title = "";
        album = "";
        duration = 0;
        entries = [];
        loading = false;
    }

    function cleanText(value): string {
        return String(value ?? "").replace(/\s+/g, " ").trim();
    }

    function cleanLyrics(value): string {
        return String(value ?? "").trim();
    }

    function normalized(value): string {
        return cleanText(value)
            .toLocaleLowerCase()
            .replace(/\s*[\(\[\{（【].*?[\)\]\}）】]\s*/g, " ")
            .replace(/[^\w\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]+/g, " ")
            .replace(/\s+/g, " ")
            .trim();
    }

    function stopRequest(): void {
        if (lyricsProc.running)
            lyricsProc.running = false;
        output = "";
        phase = "";
    }

    function requestCommand(endpoint: string, params: var): var {
        const command = [
            "curl", "-LsfG", "--max-time", "6",
            "-H", "Lrclib-Client: " + clientHeader
        ];
        for (const key of Object.keys(params)) {
            if (params[key] !== "")
                command.push("--data-urlencode", key + "=" + params[key]);
        }
        command.push("https://lrclib.net" + endpoint);
        return command;
    }

    function startExactRequest(): void {
        phase = "exact";
        output = "";
        lyricsProc.command = requestCommand("/api/get", {
            artist_name: artist,
            track_name: title,
            album_name: album,
            duration: duration > 0 ? String(Math.round(duration)) : ""
        });
        lyricsProc.running = true;
    }

    function startSearchRequest(): void {
        phase = "search";
        output = "";
        lyricsProc.command = requestCommand("/api/search", artist === "" ? {
            q: title
        } : {
            artist_name: artist,
            track_name: title
        });
        lyricsProc.running = true;
    }

    function handleResponse(code: int): void {
        const response = code === 0 ? output : "";
        const responsePhase = phase;
        output = "";

        if (requestKey === "")
            return;

        if (responsePhase === "exact") {
            const exact = recordFromJson(response);
            if (applyRecord(exact))
                return;
            startSearchRequest();
            return;
        }

        const candidate = bestCandidate(recordsFromJson(response));
        if (applyRecord(candidate))
            return;

        cache[requestKey] = [];
        entries = [];
        loading = false;
    }

    function recordFromJson(text: string): var {
        if (text.trim() === "")
            return null;

        try {
            return JSON.parse(text);
        } catch (e) {
            console.warn("[omibar] lyrics response parse failed:", e);
            return null;
        }
    }

    function recordsFromJson(text: string): var {
        const data = recordFromJson(text);
        return Array.isArray(data) ? data : [];
    }

    function applyRecord(record: var): bool {
        const nextEntries = entriesFromRecord(record);
        if (nextEntries.length === 0)
            return false;

        cache[requestKey] = nextEntries;
        entries = nextEntries;
        loading = false;
        return true;
    }

    function entriesFromRecord(record: var): var {
        if (record === null || record === undefined || record.instrumental)
            return [];

        const synced = cleanLyrics(record.syncedLyrics ?? "");
        const syncedEntries = synced === "" ? [] : parseLrc(synced);
        if (syncedEntries.length > 0)
            return syncedEntries;

        const plain = cleanLyrics(record.plainLyrics ?? "");
        return plain === "" ? [] : parsePlainLyrics(plain);
    }

    function bestCandidate(records: var): var {
        let best = null;
        let bestScore = 0;

        for (const record of records) {
            const score = candidateScore(record);
            if (score > bestScore) {
                best = record;
                bestScore = score;
            }
        }

        return bestScore >= 55 ? best : null;
    }

    function candidateScore(record: var): int {
        if (record === null || record === undefined || record.instrumental)
            return 0;

        const targetTitle = normalized(title);
        const targetArtist = normalized(artist);
        const targetAlbum = normalized(album);
        const recordTitle = normalized(record.trackName ?? record.name ?? "");
        const recordArtist = normalized(record.artistName ?? "");
        const recordAlbum = normalized(record.albumName ?? "");
        let score = 0;

        if (recordTitle === targetTitle)
            score += 70;
        else if (recordTitle.includes(targetTitle) || targetTitle.includes(recordTitle))
            score += 42;

        if (targetArtist !== "") {
            if (recordArtist === targetArtist)
                score += 36;
            else if (recordArtist.includes(targetArtist) || targetArtist.includes(recordArtist))
                score += 18;
        }

        if (targetAlbum !== "" && recordAlbum === targetAlbum)
            score += 10;

        const recordDuration = Number(record.duration ?? 0);
        const delta = Math.abs(recordDuration - duration);
        if (duration > 0 && recordDuration > 0) {
            if (delta <= 2)
                score += 24;
            else if (delta <= 6)
                score += 14;
            else if (delta > 20)
                score -= 16;
        }

        if (cleanLyrics(record.syncedLyrics ?? "") !== "")
            score += 20;
        else if (cleanLyrics(record.plainLyrics ?? "") !== "")
            score += 8;

        return score;
    }

    function parseLrc(text: string): var {
        const nextEntries = [];
        const lines = text.split("\n");
        const tagRe = /\[(\d+):(\d+(?:\.\d+)?)\]/g;

        for (const line of lines) {
            tagRe.lastIndex = 0;
            const lyricText = line.replace(tagRe, "").trim();
            let match = tagRe.exec(line);
            while (match !== null) {
                nextEntries.push({
                    time: Number(match[1]) * 60 + Number(match[2]),
                    text: lyricText
                });
                match = tagRe.exec(line);
            }
        }

        nextEntries.sort((a, b) => a.time - b.time);
        return nextEntries;
    }

    function parsePlainLyrics(text: string): var {
        const lines = text.split("\n")
            .map(line => line.trim())
            .filter(line => line !== "");
        if (lines.length === 0)
            return [];

        const total = duration > 0 ? duration : lines.length * 3;
        const step = Math.max(2.5, total / lines.length);
        return lines.map((line, index) => ({
            time: index * step,
            text: line
        }));
    }

    readonly property Process lyricsProc: Process {
        id: lyricsProc

        stdout: SplitParser {
            onRead: data => root.output += data
        }
        stderr: SplitParser {}
        onExited: (code, status) => root.handleResponse(code)
    }
}
