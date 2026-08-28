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
    property Component shellComponent: Component {
        Item {
            id: shell

            readonly property real hPadding: 16
            property real gapImpulseOffset: 0
            property alias contentParent: contentSlot

            implicitWidth: contentSlot.childrenRect.width + hPadding * 2
            implicitHeight: BarState.moduleHeight
            width: implicitWidth
            height: implicitHeight

            transform: Translate {
                x: shell.gapImpulseOffset
            }

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.surfaceContainerHigh
            }

            Item {
                id: contentSlot

                anchors.horizontalCenter: parent.horizontalCenter
                y: (parent.height - height) / 2
                width: childrenRect.width
                height: childrenRect.height
            }
        }
    }
    readonly property real moduleGap: BarState.moduleGap

    readonly property real leftCapsuleWidth: leftCapsule.moduleRow
        ? leftCapsule.moduleRow.implicitWidth : 0
    readonly property real centerCapsuleWidth: centerCapsule.moduleRow
        ? centerCapsule.moduleRow.implicitWidth : 0
    readonly property real rightCapsuleWidth: rightCapsule.moduleRow
        ? rightCapsule.moduleRow.implicitWidth : 0
    readonly property real leftCenterGap: leftCapsuleWidth > 0 && centerCapsuleWidth > 0
        ? moduleGap : 0
    readonly property real centerRightGap: centerCapsuleWidth > 0 && rightCapsuleWidth > 0
        ? moduleGap : 0
    readonly property real sideGap: leftCapsuleWidth > 0 && rightCapsuleWidth > 0
        ? moduleGap : 0
    readonly property real leftExtent: leftCapsuleWidth + leftCenterGap
    readonly property real rightExtent: rightCapsuleWidth + centerRightGap
    readonly property real sideExtent: Math.max(leftExtent, rightExtent)
    readonly property real leftAvoidanceWidth: leftCapsuleWidth + centerCapsuleWidth
        + leftCenterGap
    readonly property real rightAvoidanceWidth: rightCapsuleWidth
    readonly property real avoidanceSideWidth: Math.max(leftAvoidanceWidth, rightAvoidanceWidth)
    readonly property real centerBandWidth: centerCapsuleWidth + sideExtent * 2
    readonly property real sideBandWidth: leftCapsuleWidth + rightCapsuleWidth + sideGap

    // 内容总宽度保留对称留白；左右 band 的实际 x 贴着 center，而不是贴边。
    // 不用 childrenRect（会与 anchors.fill 形成循环依赖）。
    readonly property real contentWidth: Math.max(centerBandWidth, sideBandWidth)
    readonly property real centerCapsuleX: (width - centerCapsuleWidth) / 2
    readonly property real leftCapsuleX: centerCapsuleWidth > 0
        ? centerCapsuleX - leftCenterGap - leftCapsuleWidth : 0
    readonly property real rightCapsuleX: centerCapsuleWidth > 0
        ? centerCapsuleX + centerCapsuleWidth + centerRightGap
        : width - rightCapsuleWidth

    // 三区水平排布：每个非空区都是独立胶囊。
    AvoidingCapsule {
        id: leftCapsule

        neutralX: root.leftCapsuleX
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
        for (const capsule of [leftCapsule, centerCapsule, rightCapsule]) {
            const row = capsule.moduleRow;
            for (let i = row.children.length - 1; i >= 0; --i)
                row.children[i].destroy();
            capsule.clearBandItems();
        }
        for (const entry of manifest) {
            const component = getComponent(entry.name);
            if (!component || component.status === Component.Error) {
                console.warn("[omibar] skip module:", entry.name,
                             component ? component.errorString() : "missing component");
                continue;
            }
            const capsule = capsuleFor(entry.align);
            const shell = shellComponent.createObject(capsule.moduleRow);
            if (!shell) {
                console.warn("[omibar] create module shell failed:", entry.name);
                continue;
            }
            const instance = component.createObject(
                shell.contentParent, { barState: BarState });
            if (!instance) {
                console.warn("[omibar] create failed:", entry.name);
                shell.destroy();
                continue;
            }
            capsule.registerBandItem(shell);
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

    function capsuleFor(align) {
        if (align === "center") return centerCapsule;
        if (align === "right") return rightCapsule;
        return leftCapsule;
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
