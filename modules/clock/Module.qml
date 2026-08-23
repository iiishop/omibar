// clock 模块 — 种子模块，验证装载链路。
pragma ComponentBehavior: Bound

import QtQuick

Text {
    required property BarState barState

    text: Qt.formatDateTime(new Date(), "HH:mm:ss")
    color: Theme.fg
    font.family: "monospace"
    font.pixelSize: 14

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: parent.text = Qt.formatDateTime(new Date(), "HH:mm:ss")
    }
}
