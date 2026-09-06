// SourceCard - current attempt, last successful count, and recovery information.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import "../../core"

Rectangle {
    id: root

    required property QtObject source
    required property string title
    required property string missingHint

    readonly property int padding: 14
    readonly property bool successful: source.status === "success"
    readonly property bool failed: source.status === "error" || source.status === "missing"
    readonly property var statuses: ({
        unchecked: qsTr("未检查"), checking: qsTr("检查中"),
        busy: qsTr("暂缓检查"), missing: qsTr("缺少工具"), error: qsTr("检查失败"),
        success: source.count > 0 ? qsTr("%1 项可更新").arg(source.count) : qsTr("已是最新")
    })
    readonly property var explanations: ({
        unchecked: qsTr("尚无检查记录"),
        checking: qsTr("正在获取可用更新…"),
        busy: qsTr("数据库被占用，将自动重试；无法据此判断安装进度。"),
        missing: missingHint,
        error: source.error === "timeout"
            ? qsTr("检查超时，请确认网络连接后重试。")
            : qsTr("未能完成检查，请确认网络和软件源配置后重试。"),
        success: qsTr("检查完成 · %1").arg(formatTime(source.lastSuccess))
    })

    height: content.implicitHeight + padding * 2
    radius: 14
    color: Theme.surfaceContainerHigh

    function formatTime(timestamp: double): string {
        return Qt.formatDateTime(new Date(timestamp), "MM-dd hh:mm");
    }

    Column {
        id: content
        x: root.padding
        y: root.padding
        width: root.width - root.padding * 2
        spacing: 7

        Text {
            width: parent.width
            text: root.title
            color: Theme.fgVariant
            font.family: Theme.bodyFont
            font.pixelSize: 11
        }

        Text {
            width: parent.width
            text: root.statuses[root.source.status]
            color: root.failed ? Theme.tertiary : Theme.fg
            font.family: Theme.bodyFont
            font.pixelSize: 17
            font.weight: Font.DemiBold
            wrapMode: Text.Wrap
        }

        Text {
            width: parent.width
            text: root.explanations[root.source.status]
            color: Theme.fgVariant
            font.family: Theme.bodyFont
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        Text {
            width: parent.width
            visible: !root.successful && root.source.lastSuccess > 0
            text: qsTr("上次成功：%1 · %2 项（旧结果）")
                .arg(root.formatTime(root.source.lastSuccess)).arg(root.source.count)
            color: Theme.fgVariant
            font.family: Theme.bodyFont
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        Text {
            width: parent.width
            visible: root.failed && root.source.lastAttempt > 0
            text: qsTr("本次尝试：%1").arg(root.formatTime(root.source.lastAttempt))
            color: Theme.fgVariant
            font.family: Theme.bodyFont
            font.pixelSize: 10
        }

        Button {
            id: diagnosticToggle
            visible: root.source.diagnostic !== ""
            checkable: true
            text: checked ? qsTr("收起诊断信息") : qsTr("查看诊断信息")
            padding: 0
            contentItem: Text {
                text: diagnosticToggle.text
                color: Theme.primary
                font.family: Theme.bodyFont
                font.pixelSize: 11
                font.underline: diagnosticToggle.hovered || diagnosticToggle.visualFocus
            }
            background: Item {}
        }

        Flickable {
            width: parent.width
            height: Math.min(diagnosticText.implicitHeight, 100)
            visible: diagnosticToggle.visible && diagnosticToggle.checked
            contentHeight: diagnosticText.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            Text {
                id: diagnosticText
                width: parent.width - 12
                text: root.source.diagnostic
                textFormat: Text.PlainText
                color: Theme.fgVariant
                font.family: Theme.monoFont
                font.pixelSize: 10
                wrapMode: Text.WrapAnywhere
            }
        }
    }
}
