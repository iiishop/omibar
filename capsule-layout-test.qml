pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "core"

ShellRoot {
    id: suite
    readonly property real tolerance: 0.6
    property var shells: []
    property var contents: []
    property var tracked: null
    property real initialCenter: 0
    property real initialWidth: 0
    property int samples: 0
    property bool sampling: false

    function check(condition: bool, message: string): void {
        if (!condition) { console.error("FAIL: " + message); Qt.exit(1); }
    }

    function center(item: Item): real {
        return item.mapToItem(window.contentItem, item.width / 2, 0).x;
    }

    function resize(index: int, width: real): void {
        tracked = shells[index];
        initialCenter = center(tracked);
        initialWidth = tracked.width;
        samples = 0;
        sampling = true;
        contents[index].width = width;
    }

    function verify(): void {
        check(samples > 10, "Width animation was sampled across frames");
        check(Math.abs(tracked.width - initialWidth) > 10, "The capsule actually resized");
        check(Math.abs(center(tracked) - initialCenter) < tolerance, "Settled capsule center stays fixed");
        sampling = false;
    }

    function sample(): void {
        if (!sampling) return;
        // FrameAnimation runs before positioner polish; measure the layout of this frame.
        for (const band of ["left", "right"])
            (host.capsuleFor(band).moduleRow as Row).forceLayout();
        ++samples;
        const current = center(tracked);
        check(Math.abs(current - initialCenter) < tolerance,
            "Resizing center drifted by " + (current - initialCenter) + " px");
    }

    Component {
        id: content
        Item { height: 24 }
    }

    FloatingWindow {
        id: window
        implicitWidth: 2000
        implicitHeight: 100
        visible: true
        ModuleHost {
            id: host
            configDir: Quickshell.env("LAYOUT_TEST_CONFIG")
            neutralScreenX: window.width / 2 - contentWidth / 2
            movementOriginX: window.width / 2
            x: neutralScreenX
            width: contentWidth
            height: 32
        }
    }

    FrameAnimation { running: suite.sampling; onTriggered: Qt.callLater(suite.sample) }
    Timer { interval: 12000; running: true; onTriggered: { console.error("FAIL: layout test timed out"); Qt.exit(1); } }
    SequentialAnimation {
        running: true
        PauseAnimation { duration: 200 }
        ScriptAction {
            script: {
                BarState.screenWidth = window.width;
                for (const [band, width] of [["left", 80], ["left", 120], ["right", 100], ["right", 60]]) {
                    const capsule = host.capsuleFor(band);
                    const shell = host.shellComponent.createObject(capsule.moduleRow);
                    const item = content.createObject(shell.contentParent, { width });
                    capsule.registerBandItem(shell);
                    suite.shells.push(shell);
                    suite.contents.push(item);
                    shell.resizeReady = true;
                }
            }
        }
        PauseAnimation { duration: 600 }
        ScriptAction { script: suite.resize(1, 300) }
        PauseAnimation { duration: 800 }
        ScriptAction { script: { suite.verify(); suite.resize(1, 120); } }
        PauseAnimation { duration: 800 }
        ScriptAction { script: { suite.verify(); suite.resize(2, 320); } }
        PauseAnimation { duration: 800 }
        ScriptAction { script: { suite.verify(); suite.resize(2, 100); } }
        PauseAnimation { duration: 800 }
        ScriptAction { script: { suite.verify(); suite.resize(0, 200); } }
        PauseAnimation { duration: 100 }
        ScriptAction { script: suite.contents[0].width = 110 }
        PauseAnimation { duration: 800 }
        ScriptAction {
            script: {
                suite.verify();
                BarState.launcherOpen = true;
            }
        }
        PauseAnimation { duration: 900 }
        ScriptAction {
            script: {
                const left = host.capsuleFor("left");
                const right = host.capsuleFor("right");
                suite.check(Math.abs(left.mapToItem(window.contentItem, left.width, 0).x
                    - (BarState.launcherLeft - BarState.launcherPadding)) < suite.tolerance,
                    "Left avoidance edge remains correct");
                suite.check(Math.abs(right.mapToItem(window.contentItem, 0, 0).x
                    - (BarState.launcherRight + BarState.launcherPadding)) < suite.tolerance,
                    "Right avoidance edge remains correct");
                BarState.launcherOpen = false;
            }
        }
        PauseAnimation { duration: 900 }
        ScriptAction {
            script: {
                suite.check(Math.abs(suite.center(suite.tracked) - suite.initialCenter) < suite.tolerance,
                    "Avoidance returns to the same neutral center");
                console.info("PASS: center-preserving resize, reversal, both bands and launcher avoidance");
                Qt.quit();
            }
        }
    }
}
