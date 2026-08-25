// ModuleHost — 模块装载器。
// 职责：读 bar.json 清单 → 按顺序装载 modules/<name>/Module.qml →
//       按 manifest.align 分左/中/右三区 → 输出 implicitWidth 供胶囊定宽。
// 铁律：本层是模块唯一的宿主环境；模块之间禁止互相 import。
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

    readonly property real leftCapsuleWidth: capsuleWidthFor(leftRow)
    readonly property real centerCapsuleWidth: capsuleWidthFor(centerRow)
    readonly property real rightCapsuleWidth: capsuleWidthFor(rightRow)
    readonly property real sideWidth: Math.max(leftCapsuleWidth, rightCapsuleWidth)
    readonly property real centerBandWidth: centerCapsuleWidth
        + (sideWidth > 0 ? (sideWidth + moduleSpacing) * 2 : 0)
    readonly property real sideBandWidth: leftCapsuleWidth + rightCapsuleWidth
        + (leftCapsuleWidth > 0 && rightCapsuleWidth > 0 ? moduleSpacing : 0)

    // 内容总宽度：中区要保持视觉居中，因此左右按较宽侧对称预留。
    // 不用 childrenRect（会与 anchors.fill 形成循环依赖）。
    readonly property real contentWidth: hPadding * 2
        + Math.max(centerBandWidth, sideBandWidth)

    // 三区水平排布：每个非空区都是独立胶囊。
    Rectangle {
        id: leftCapsule

        visible: leftCapsuleWidth > 0
        width: leftCapsuleWidth
        height: parent.height
        radius: height / 2
        color: "#0a0a0c"
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        Row {
            id: leftRow
            objectName: "moduleRowLeft"
            anchors.centerIn: parent
            spacing: root.moduleSpacing
        }
    }

    Rectangle {
        id: centerCapsule

        visible: centerCapsuleWidth > 0
        width: centerCapsuleWidth
        height: parent.height
        radius: height / 2
        color: "#0a0a0c"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        Row {
            id: centerRow
            objectName: "moduleRowCenter"
            anchors.centerIn: parent
            spacing: root.moduleSpacing
        }
    }

    Rectangle {
        id: rightCapsule

        visible: rightCapsuleWidth > 0
        width: rightCapsuleWidth
        height: parent.height
        radius: height / 2
        color: "#0a0a0c"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        Row {
            id: rightRow
            objectName: "moduleRowRight"
            anchors.centerIn: parent
            spacing: root.moduleSpacing
        }
    }

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

    function capsuleWidthFor(row): real {
        return row.implicitWidth > 0 ? row.implicitWidth + hPadding * 2 : 0;
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
