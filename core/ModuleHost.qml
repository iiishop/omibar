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
    required property real neutralScreenX
    required property real movementOriginX

    readonly property url barConfigUrl: Qt.resolvedUrl(configDir + "/bar.json")
    property var manifest: []   // [{name, align, options}]
    // 组件缓存按模块名共享；同一模块出现多次时只编译一份，实例各自独立。
    property var componentCache: ({})
    property Component hoverComponent: Component { ModuleHover {} }
    readonly property real moduleGap: BarState.moduleGap

    readonly property real leftCapsuleWidth: capsuleWidthFor(leftCapsule.moduleRow)
    readonly property real centerCapsuleWidth: capsuleWidthFor(centerCapsule.moduleRow)
    readonly property real rightCapsuleWidth: capsuleWidthFor(rightCapsule.moduleRow)
    readonly property real sideWidth: Math.max(leftCapsuleWidth, rightCapsuleWidth)
    readonly property real leftAvoidanceWidth: leftCapsuleWidth + centerCapsuleWidth
        + (leftCapsuleWidth > 0 && centerCapsuleWidth > 0 ? moduleGap : 0)
    readonly property real rightAvoidanceWidth: rightCapsuleWidth
    readonly property real avoidanceSideWidth: Math.max(leftAvoidanceWidth, rightAvoidanceWidth)
    readonly property real centerBandWidth: centerCapsuleWidth
        + (sideWidth > 0 ? (sideWidth + moduleGap) * 2 : 0)
    readonly property real sideBandWidth: leftCapsuleWidth + rightCapsuleWidth
        + (leftCapsuleWidth > 0 && rightCapsuleWidth > 0 ? moduleGap : 0)

    // 内容总宽度：中区要保持视觉居中，因此左右按较宽侧对称预留。
    // 不用 childrenRect（会与 anchors.fill 形成循环依赖）。
    readonly property real contentWidth: Math.max(centerBandWidth, sideBandWidth)
    readonly property real centerCapsuleX: (width - centerCapsuleWidth) / 2
    readonly property real rightCapsuleX: width - rightCapsuleWidth

    // 三区水平排布：每个非空区都是独立胶囊。
    AvoidingCapsule {
        id: leftCapsule

        neutralX: 0
        neutralScreenX: root.neutralScreenX
        movementOriginX: root.movementOriginX
        capsuleWidth: root.leftCapsuleWidth
        moduleGap: root.moduleGap
        leftStackOffset: root.centerCapsuleWidth > 0
            ? root.centerCapsuleWidth + root.moduleGap : 0
        rightStackOffset: 0
        rowObjectName: "moduleRowLeft"
    }

    AvoidingCapsule {
        id: centerCapsule

        neutralX: root.centerCapsuleX
        neutralScreenX: root.neutralScreenX
        movementOriginX: root.movementOriginX
        capsuleWidth: root.centerCapsuleWidth
        moduleGap: root.moduleGap
        leftStackOffset: 0
        rightStackOffset: 0
        rowObjectName: "moduleRowCenter"
    }

    AvoidingCapsule {
        id: rightCapsule

        neutralX: root.rightCapsuleX
        neutralScreenX: root.neutralScreenX
        movementOriginX: root.movementOriginX
        capsuleWidth: root.rightCapsuleWidth
        moduleGap: root.moduleGap
        leftStackOffset: 0
        rightStackOffset: 0
        rowObjectName: "moduleRowRight"
    }

    onManifestChanged: rebuild()

    // 清单变化时全量重建；模块数量少，重建比增量 diff 更简单可靠。
    function rebuild(): void {
        for (const row of [leftCapsule.moduleRow, centerCapsule.moduleRow,
                           rightCapsule.moduleRow]) {
            for (let i = row.children.length - 1; i >= 0; --i)
                row.children[i].destroy();
        }
        for (const entry of manifest) {
            const component = getComponent(entry.name);
            if (!component || component.status === Component.Error) {
                console.warn("[omibar] skip module:", entry.name);
                continue;
            }
            const wrapper = hoverComponent.createObject(
                rowFor(entry.align), { hoverPreset: hoverPresetFor(entry) });
            if (!wrapper) {
                console.warn("[omibar] create hover wrapper failed:", entry.name);
                continue;
            }
            const instance = component.createObject(
                wrapper.contentParent, { barState: BarState });
            if (!instance) {
                console.warn("[omibar] create failed:", entry.name);
                wrapper.destroy();
                continue;
            }
            const options = entry.options ?? {};
            for (const key in options)
                instance[key] = options[key];
        }
        for (const capsule of [leftCapsule, centerCapsule, rightCapsule])
            capsule.syncBandItems();
    }

    function getComponent(name): Component {
        if (!(name in componentCache)) {
            componentCache[name] = Qt.createComponent(Qt.resolvedUrl(
                "../modules/" + name + "/Module.qml"));
        }
        return componentCache[name];
    }

    function rowFor(align): Item {
        if (align === "center") return centerCapsule.moduleRow;
        if (align === "right") return rightCapsule.moduleRow;
        return leftCapsule.moduleRow;
    }

    function hoverPresetFor(entry): string {
        const preset = entry.hover ?? entry.hoverAnimation ?? "lift";
        return typeof preset === "string" ? preset : "lift";
    }

    function capsuleWidthFor(row): real {
        return row.implicitWidth;
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
