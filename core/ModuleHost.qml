// ModuleHost — 模块装载器。
// 职责：读 bar.json 清单 → 按顺序装载 modules/<name>/Module.qml →
//       按 manifest.band 分左右避让区 → 输出 implicitWidth 供胶囊定宽。
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
    property var manifest: []   // [{name, band, options}]
    // 组件缓存按模块名共享；同一模块出现多次时只编译一份，实例各自独立。
    property var componentCache: ({})
    property Component shellComponent: Component {
        Item {
            id: shell

            readonly property real hPadding: 16
            readonly property real contentWidth: contentSlot.childrenRect.width
            property real gapImpulseOffset: 0
            property alias contentParent: contentSlot

            implicitWidth: contentWidth > 0 ? contentWidth + hPadding * 2 : 0
            implicitHeight: BarState.moduleHeight
            width: implicitWidth
            height: implicitHeight
            visible: width > 0

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
    readonly property real rightCapsuleWidth: rightCapsule.moduleRow
        ? rightCapsule.moduleRow.implicitWidth : 0
    readonly property real middleGap: leftCapsuleWidth > 0 && rightCapsuleWidth > 0
        ? moduleGap : 0
    readonly property real sideExtent: Math.max(leftCapsuleWidth, rightCapsuleWidth)
    readonly property real avoidanceSideWidth: sideExtent
    readonly property real contentWidth: sideExtent * 2 + middleGap
    readonly property real leftCapsuleX: sideExtent - leftCapsuleWidth
    readonly property real rightCapsuleX: sideExtent + middleGap

    // 两个避让 band：launcher 左侧和右侧。
    AvoidingCapsule {
        id: leftCapsule

        neutralX: root.leftCapsuleX
        neutralScreenX: root.neutralScreenX
        movementOriginX: root.movementOriginX
        movementDirection: -1
        capsuleWidth: root.leftCapsuleWidth
        moduleGap: root.moduleGap
        leftStackOffset: 0
        rightStackOffset: 0
        rowObjectName: "moduleRowLeft"
    }

    AvoidingCapsule {
        id: rightCapsule

        neutralX: root.rightCapsuleX
        neutralScreenX: root.neutralScreenX
        movementOriginX: root.movementOriginX
        movementDirection: 1
        capsuleWidth: root.rightCapsuleWidth
        moduleGap: root.moduleGap
        leftStackOffset: 0
        rightStackOffset: 0
        rowObjectName: "moduleRowRight"
    }

    onManifestChanged: rebuild()

    // 清单变化时全量重建；模块数量少，重建比增量 diff 更简单可靠。
    function rebuild(): void {
        for (const capsule of [leftCapsule, rightCapsule]) {
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
            const capsule = capsuleFor(bandFor(entry));
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
        for (const capsule of [leftCapsule, rightCapsule])
            capsule.syncBandItems();
    }

    function getComponent(name): Component {
        if (!(name in componentCache)) {
            componentCache[name] = Qt.createComponent(Qt.resolvedUrl(
                "../modules/" + name + "/Module.qml"));
        }
        return componentCache[name];
    }

    function capsuleFor(band) {
        if (band === "right") return rightCapsule;
        return leftCapsule;
    }

    function bandFor(entry): string {
        return entry.band === "right" ? "right" : "left";
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
                typeof m === "string" ? { name: m, band: "left" } : m);
            if (JSON.stringify(next) !== JSON.stringify(manifest))
                manifest = next;
        } catch (e) {
            console.warn("[omibar] bar.json parse failed:", e);
        }
    }
}
