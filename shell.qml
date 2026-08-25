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
        }

        function debugNotifications(): string {
            return JSON.stringify({
                ready: Core.BarState.notificationStateReady,
                count: Core.BarState.notificationCount,
                dnd: Core.BarState.notificationDnd,
                available: Core.BarState.caelestiaAvailable
            });
        }

        function debugLauncher(): string {
            return JSON.stringify({
                launcherOpen: Core.BarState.launcherOpen,
                fullscreen: Core.BarState.fullscreen,
                avoidanceInset: Core.BarState.avoidanceInset,
                launcherCenterX: Core.BarState.launcherCenterX
            });
        }
    }

    Core.BarWindow {}
}
