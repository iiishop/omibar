// clock 模块 — 种子模块，验证装载链路。
pragma ComponentBehavior: Bound

import QtQuick
import "../../core"

Text {
    required property BarState barState

    property string format: "HH:mm:ss"

    text: Qt.formatDateTime(new Date(), format)
    color: Theme.fg
    font.family: "monospace"
    font.pixelSize: 14

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: parent.text = Qt.formatDateTime(new Date(), parent.format)
    }
}
