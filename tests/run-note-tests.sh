#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
test_root=$(mktemp -d /tmp/omibar-note-tests.XXXXXX)
export XDG_STATE_HOME="$test_root/state"
export XDG_CACHE_HOME="$test_root/cache"
export NOTE_TEST_PATH="$test_root/notes.json"
export QT_QPA_PLATFORM=offscreen
export QT_QUICK_BACKEND=software
unset WAYLAND_DISPLAY
mkdir -p "$XDG_STATE_HOME" "$XDG_CACHE_HOME"
printf '%s' 'malformed JSON kept for recovery' > "$NOTE_TEST_PATH.bad"
node tests/note-logic.test.cjs
qs -p clock-test.qml
qs -p note-test.qml
qs -p note-storage-test.qml
test "$(cat "$NOTE_TEST_PATH.bad")" = 'malformed JSON kept for recovery'
printf 'Test data and editor preview: %s\n' "$test_root"
