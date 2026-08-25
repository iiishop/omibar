// ModuleHost — 模块装载器。
// 职责：读 bar.json 清单 → 按顺序装载 modules/<name>/Module.qml →
//       按 manifest.align 分左/中/右三区 → 输出 implicitWidth 供胶囊定宽。
// 铁律：本层是模块唯一的宿主环境；模块之间禁止互相 import。
//
// 集体避让：可选外部 launcher 打开时，左区向左挤、右区向左收拢；
// 空间不足时最外侧组件旋转 + 斜向下渐隐（见 edgeEscape 动画）。
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    required property string configDir

    readonly property url barConfigUrl: Qt.resolvedUrl(configDir + "/bar.json")
    property var manifest: []   // [{name, align, options}]
    // 组件缓存按模块名共享；同一模块出现多次时只编译一份，实例各自独立。
    property var componentCache: ({})
    readonly property real moduleSpacing: 10
    readonly property real hPadding: 16

    // 内容总宽度：三区之和 + 区间距。供胶囊 implicitWidth 链使用，
    // 不用 childrenRect（会与 anchors.fill 形成循环依赖）。
    readonly property real contentWidth: leftRow.implicitWidth + centerRow.implicitWidth
        + rightRow.implicitWidth + moduleSpacing * 2

    // 避让强度：0 = 原位；1 = 完全避让。由可选 launcher 状态驱动，弹簧动画在 Row 上。
    readonly property real yieldAmount: BarState.launcherOpen ? 1 : 0

    // 三区水平排布：左区贴左、中区居中、右区贴右，垂直统一居中。
    Row {
        id: leftRow
        objectName: "moduleRowLeft"
        anchors.left: parent.left
        anchors.leftMargin: root.hPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.moduleSpacing

        // 集体避让：左区向左挤出（弹簧）
        transform: Translate {
            id: leftTranslate

            x: -root.yieldAmount * (leftRow.implicitWidth * 0.6)

            Behavior on x {
                SpringAnimation { spring: 4; damping: 0.6; mass: 0.9 }
            }
        }
    }

    Row {
        id: centerRow
        objectName: "moduleRowCenter"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.moduleSpacing
    }

    Row {
        id: rightRow
        objectName: "moduleRowRight"
        anchors.right: parent.right
        anchors.rightMargin: root.hPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.moduleSpacing

        // 集体避让：右区向左收拢，给外部浮层让出视觉空间。
        transform: Translate {
            id: rightTranslate

            x: -root.yieldAmount * 30

            Behavior on x {
                SpringAnimation { spring: 4; damping: 0.6; mass: 0.9 }
            }
        }
    }

    // ---- 边缘逃逸：空间不足时最外侧组件旋转 + 斜向下渐隐 ----
    // 触发条件：胶囊压缩后内容仍溢出（当前单模块场景不会触发，为多模块预留）。
    // 判定：yieldAmount > 0 且 contentWidth > 可用宽度。
    readonly property bool edgeEscapeActive: root.yieldAmount > 0.5
        && contentWidth > panelAvailableWidth

    // 避让后胶囊可用宽度：胶囊目标宽 - 形变压缩量（由宿主传入）
    property real capsuleTargetWidth: 0
    readonly property real escapeReserve: 40
    readonly property real panelAvailableWidth: capsuleTargetWidth - escapeReserve

    onManifestChanged: rebuild()

    // 清单变化时全量重建；模块数量少，重建比增量 diff 更简单可靠。
    function rebuild(): void {
        for (const row of [leftRow, centerRow, rightRow]) {
            for (let i = row.children.length - 1; i >= 0; --i)
                row.children[i].destroy();
        }
        for (const entry of manifest) {
            const component = getComponent(entry.name);
            if (!component || component.status === Component.Error) {
                console.warn("[omibar] skip module:", entry.name);
                continue;
            }
            const instance = component.createObject(
                rowFor(entry.align), { barState: BarState });
            if (!instance) {
                console.warn("[omibar] create failed:", entry.name);
                continue;
            }
            const options = entry.options ?? {};
            for (const key in options)
                instance[key] = options[key];
        }
    }

    function getComponent(name): Component {
        if (!(name in componentCache)) {
            componentCache[name] = Qt.createComponent(Qt.resolvedUrl(
                "../modules/" + name + "/Module.qml"));
        }
        return componentCache[name];
    }

    function rowFor(align): Row {
        if (align === "center") return centerRow;
        if (align === "right") return rightRow;
        return leftRow;
    }

    // ---- 清单加载 ----
    FileView {
        id: configFile
        path: root.barConfigUrl.toString().replace("file://", "")
        watchChanges: true
        onFileChanged: root.load()
        onLoaded: root.load()
    }

    function load(): void {
        try {
            const data = JSON.parse(configFile.text());
            const next = (data.modules ?? []).map(m =>
                typeof m === "string" ? { name: m, align: "left" } : m);
            if (JSON.stringify(next) !== JSON.stringify(manifest))
                manifest = next;
        } catch (e) {
            console.warn("[omibar] bar.json parse failed:", e);
        }
    }
}
