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

    // 内容总宽度：三区之和 + 区间距。供胶囊 implicitWidth 链使用，
    // 不用 childrenRect（会与 anchors.fill 形成循环依赖）。
    readonly property real contentWidth: leftRow.implicitWidth + centerRow.implicitWidth
        + rightRow.implicitWidth + moduleSpacing * 2

    // 三区水平排布：左区贴左、中区居中、右区贴右，垂直统一居中。
    Row {
        id: leftRow
        objectName: "moduleRowLeft"
        anchors.left: parent.left
        anchors.leftMargin: root.hPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.moduleSpacing
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
    }

    readonly property real hPadding: 16

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
            // required 属性必须在创建时初始化；options 属于模块配置，创建后注入。
            const instance = component.createObject(
                rowFor(entry.align), { barState: BarState });
            if (!instance) {
                console.warn("[omibar] create failed:", entry.name);
                continue;
            }
            const options = entry.options ?? {};
            for (const key in options)
                instance[key] = options[key];
            console.log("[omibar] loaded:", entry.name, "align:", entry.align,
                        "status:", component.status, "w:", instance.width);
        }
    }

    function getComponent(name): Component {
        if (!(name in componentCache)) {
            componentCache[name] = Qt.createComponent(Qt.resolvedUrl(
                // 相对本文件（core/）：模块目录与 core 平级。
                "../modules/" + name + "/Module.qml"));
        }
        return componentCache[name];
    }

    // align 只认三个已知值；未知值归入左区而不是静默丢模块。
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
            // 内容一致时不触发重建（FileView 首次 loaded + onCompleted 会来两次）
            if (JSON.stringify(next) !== JSON.stringify(manifest))
                manifest = next;
        } catch (e) {
            // 解析失败保留上次成功的 manifest，避免清空整条 bar。
            console.warn("[omibar] bar.json parse failed:", e);
        }
    }
}
