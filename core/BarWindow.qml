// BarWindow — 底部 bar 的 layer-shell 宿主窗口。
// 常驻 visible（layer 不做进出动画，避让靠内部容器位移——见 quickshell-panels skill 坑1：
// 合成器对 layer surface 有全局 layersIn/Out 动画，窗口级显隐会跟 QML 动画叠加打架）。
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "."

PanelWindow {
    id: root

    anchors {
        top: false
        left: true
        right: true
        bottom: true
    }

    exclusiveZone: -1   // 不预留空间，浮在内容上；避让策略定了再改
    color: "transparent"

    implicitHeight: 52

    Item {
        anchors.fill: parent

        Rectangle {
            id: panel

            // 避让：整体下滑出屏。位移做在内部元素上，合成器无感。
            readonly property int slideTarget: BarState.yieldOffset

            x: (root.screen?.width ?? 0) / 2 - width / 2
            y: root.implicitHeight - height + slideTarget

            width: root.screen?.width ?? 0
            height: root.implicitHeight

            radius: 14
            color: Theme.surfaceContainer
            opacity: BarState.shouldYield ? 0.0 : 1.0

            // M3 曲线：进 emphasizedDecel(0.05,0.7,0.1,1.0) / 出 emphasizedAccel(0.3,0,0.8,0.15)
            Behavior on y {
                NumberAnimation {
                    duration: BarState.shouldYield ? 250 : 350
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: BarState.shouldYield
                        ? [0.3, 0, 0.8, 0.15]
                        : [0.05, 0.7, 0.1, 1.0]
                }
            }

            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }
        }
    }
}
