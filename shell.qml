pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "core" as Core

ShellRoot {
    id: root

    readonly property var hyprEvents: Core.HyprEvents
    readonly property var caelestiaBridge: Core.CaelestiaBridge

    IpcHandler {
        target: "omibar"

        function syncLauncher(): void {
            Core.CaelestiaBridge.refreshLauncher();
        }

        function demoDeform(): void {
            Core.BarState.deformPulse++;
        }

        function demoYield(): void {
            Core.BarState.launcherOpen = !Core.BarState.launcherOpen;
            Core.BarState.deformPulse++;
        }
    }

    Core.BarWindow {}
}
