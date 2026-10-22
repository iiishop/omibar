#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
layout_test_root=$(mktemp -d /tmp/omibar-layout-tests.XXXXXX)
export LAYOUT_TEST_CONFIG="$layout_test_root"
export XDG_STATE_HOME="$layout_test_root/state"
export XDG_CACHE_HOME="$layout_test_root/cache"
export QT_QPA_PLATFORM=offscreen
export QT_QUICK_BACKEND=software
unset WAYLAND_DISPLAY
mkdir -p "$XDG_STATE_HOME" "$XDG_CACHE_HOME"
printf '%s' '{"modules":[]}' > "$layout_test_root/bar.json"
qs -p capsule-layout-test.qml
