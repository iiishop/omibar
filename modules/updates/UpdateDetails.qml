// UpdateDetails - source results and an explicit check action.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import "../../core"

Rectangle {
    id: root

    required property BarState barState
    required property string title
    required property string description
    required property color accent
    required property bool checking
    signal refreshRequested()
    signal closeRequested()

    readonly property int padding: 20
    readonly property int panelWidth: 360
    readonly property var sourceTitles: [qsTr("官方仓库（pacman）"), qsTr("AUR 社区仓库")]
    readonly property var missingHints: [
        qsTr("缺少 checkupdates，请安装 pacman-contrib 后重试。"),
        qsTr("未找到 paru 或 yay，暂时无法检查 AUR。安装其中一个后重试。")
    ]

    width: panelWidth
    height: content.implicitHeight + padding * 2
    radius: 22
    color: Theme.surfaceContainer
    border.width: 1
    border.color: Qt.alpha(Theme.outline, 0.3)

    Column {
        id: content
        x: root.padding
        y: root.padding
        width: root.width - root.padding * 2
        spacing: 14

        Item {
            width: parent.width
            height: 30

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("系统更新")
                color: Theme.fgVariant
                font.family: Theme.bodyFont
                font.pixelSize: 12
            }

            Button {
                anchors.right: parent.right
                width: 30
                height: 30
                text: "close"
                Accessible.name: qsTr("关闭更新详情")
                onClicked: root.closeRequested()
                contentItem: Text {
                    text: parent.text
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: Theme.iconFont
                    font.pixelSize: 18
                    color: Theme.fgVariant
                }
                background: Rectangle {
                    radius: 15
                    color: parent.down || parent.hovered || parent.visualFocus
                        ? Theme.surfaceContainerHighest : "transparent"
                }
            }
        }

        Column {
            width: parent.width
            spacing: 7

            Text {
                width: parent.width
                text: root.title
                color: root.accent
                font.family: Theme.bodyFont
                font.pixelSize: 24
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width
                text: root.description
                color: Theme.fgVariant
                font.family: Theme.bodyFont
                font.pixelSize: 12
                wrapMode: Text.Wrap
                lineHeight: 1.2
            }
        }

        Repeater {
            model: root.barState.updateSources

            SourceCard {
                required property QtObject modelData
                required property int index
                width: content.width
                source: modelData
                title: root.sourceTitles[index]
                missingHint: root.missingHints[index]
            }
        }

        Button {
            id: refreshButton
            width: parent.width
            height: 38
            enabled: !root.checking
            text: root.checking ? qsTr("正在检查…") : qsTr("重新检查")
            onClicked: root.refreshRequested()
            contentItem: Text {
                text: refreshButton.text
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: refreshButton.enabled ? Theme.surface : Theme.fgVariant
                font.family: Theme.bodyFont
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
            background: Rectangle {
                radius: 12
                color: !refreshButton.enabled ? Theme.surfaceContainerHigh
                    : refreshButton.down ? Theme.secondary : Theme.primary
                border.width: refreshButton.hovered || refreshButton.visualFocus ? 2 : 0
                border.color: Theme.fg
            }
        }

        Text {
            width: parent.width
            text: qsTr("每 %1 分钟自动检查 · 仅检查，不安装更新")
                .arg(UpdateService.checkIntervalMs / 60000)
            color: Theme.fgVariant
            font.family: Theme.bodyFont
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
    }
}
