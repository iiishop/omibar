// Run with QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software qs -p clock-test.qml.
import QtQuick
import Quickshell
import "modules/clock" as Clock

ShellRoot {
    id: suite

    function check(condition: bool, message: string): void {
        if (!condition) {
            console.error("FAIL: " + message);
            Qt.exit(1);
        }
    }

    FloatingWindow {
        implicitWidth: calendar.width
        implicitHeight: calendar.height
        visible: true
        color: "transparent"

        Clock.MonthCalendar {
            id: calendar
            now: new Date(2024, 1, 29)
        }
    }

    SequentialAnimation {
        running: true
        PauseAnimation { duration: 50 }
        ScriptAction {
            script: {
                suite.check(calendar.daysInMonth === 29, "Leap February has 29 days");
                suite.check(calendar.dayAt(0) === 0, "Leading cells stay empty");
                suite.check(calendar.dayAt(3) === 1, "Month starts on Thursday");
                suite.check(calendar.dayAt(31) === 29, "Leap day is present");
                suite.check(calendar.dayAt(32) === 0, "Trailing cells stay empty");
                calendar.now = new Date(2026, 2, 1);
                suite.check(calendar.dayAt(6) === 1, "Sunday uses the last column");
                suite.check(calendar.dayAt(36) === 31, "Sixth week remains visible");
                calendar.open = true;
            }
        }
        PauseAnimation { duration: 100 }
        ScriptAction {
            script: {
                suite.check(calendar.reveal > 0 && calendar.reveal < 1,
                            "Opening animates through intermediate values");
                calendar.open = false;
            }
        }
        PauseAnimation { duration: 60 }
        ScriptAction { script: calendar.open = true }
        PauseAnimation { duration: calendar.enterDuration + 100 }
        ScriptAction {
            script: {
                suite.check(calendar.reveal === 1, "Interrupted close can fully reopen");
                suite.check(calendar.x === 0 && calendar.y === 0,
                            "Hover target stays stationary");
                calendar.open = false;
            }
        }
        PauseAnimation { duration: calendar.exitDuration + 100 }
        ScriptAction {
            script: {
                suite.check(calendar.reveal === 0, "Closing completes within its duration");
                console.info("PASS: clock dates, animation reversal, hover bounds, closing");
                Qt.quit();
            }
        }
    }
}
