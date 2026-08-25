pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "core" as Core

ShellRoot {
    id: root

    readonly property var hyprEvents: Core.HyprEvents
    readonly property var caelestiaBridge: Core.CaelestiaBridge

    Core.BarWindow {}
}
