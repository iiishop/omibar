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

    readonly property int resizeDuration: 520
    readonly property real resizeOvershoot: 1.6
    readonly property real resizeHeightGain: 1.8
    readonly property real resizeHeightLimit: 0.10
    readonly property Region inputRegion: Region {
        // item 模式跟随实际几何；手写坐标是窗口坐标系，会和模块的父坐标系错位。
        Region { item: leftCapsule.inputProxy }
        Region { item: rightCapsule.inputProxy }
    }

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
            property bool resizeReady: false
            property real resizeStartWidth: 0
            readonly property real resizeDirection: Math.sign(implicitWidth - resizeStartWidth)
            readonly property real widthOvershoot: resizeDirection
                * Math.max(0, resizeDirection * (width - implicitWidth))
            readonly property real heightScale: 1 - Math.max(-root.resizeHeightLimit,
                Math.min(root.resizeHeightLimit,
                    widthOvershoot / Math.max(1, implicitWidth) * root.resizeHeightGain))
            property alias contentParent: contentSlot

            implicitWidth: contentWidth > 0 ? contentWidth + hPadding * 2 : 0
            // 高度连续跟随内容：模块自身的 width/height 才是做动画的那一层，
            // 壳跟着走就不会在展开瞬间整体跳一截。
            readonly property real contentHeight: contentSlot.childrenRect.height
            implicitHeight: Math.max(BarState.moduleHeight, contentHeight)

            // 显式驱动宽度。Behavior on width 在这里不生效（shell 是运行时
            // createObject 出来的，且 visible 依赖 width），媒体胶囊变宽时
            // 就表现为瞬移。用属性 + NumberAnimation 是可靠的写法。
            // 尺寸动画的归属：默认由外壳做宽度动画（note/updates 那套）。
            // 模块若自己驱动 width+height（灵动岛形变），置 selfDriven 后外壳纯跟随，
            // 避免两条不同曲线同时跑导致形状在中间态被拉扯。
            property bool selfDriven: false
            property real animatedWidth: 0
            width: selfDriven ? implicitWidth : animatedWidth
            height: implicitHeight
            y: parent.height - height
            visible: width > 0
            Component.onCompleted: animatedWidth = implicitWidth
            onImplicitWidthChanged: {
                resizeStartWidth = width;
                if (selfDriven || !resizeReady || implicitWidth <= 0) {
                    animatedWidth = implicitWidth;
                    return;
                }
                widthAnim.stop();
                widthAnim.to = implicitWidth;
                widthAnim.restart();
            }

            NumberAnimation {
                id: widthAnim

                target: shell
                property: "animatedWidth"
                duration: root.resizeDuration
                easing.type: Easing.OutBack
                easing.overshoot: root.resizeOvershoot
            }

            transform: Translate {
                x: shell.gapImpulseOffset
            }

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.surfaceContainerHigh
                // 模块展开时由模块自绘形状接管；按自身内容高度判断，
                // 一个模块展开不能让其他胶囊跟着失去底色。
                opacity: shell.contentHeight > BarState.moduleHeight + 0.5 ? 0 : 1
                transform: Scale {
                    origin.x: shell.width / 2
                    origin.y: shell.height / 2
                    yScale: shell.heightScale
                }

                Behavior on opacity {
                    NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
                }
            }

            Item {
                anchors.fill: parent
                clip: shell.width < shell.implicitWidth

                Item {
                    id: contentSlot

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.alignWhenCentered: false
                    // 内容高于胶囊时才底部对齐（灵动岛向上长）；
                    // 普通模块内容比胶囊矮，必须保持垂直居中。
                    y: height > parent.height - 0.5
                        ? parent.height - height
                        : (parent.height - height) / 2
                    width: childrenRect.width
                    height: childrenRect.height
                }
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
    // Center the occupied span so a shell's own width cancels out of its center.
    readonly property real contentWidth: leftCapsuleWidth + middleGap + rightCapsuleWidth
    readonly property real leftCapsuleX: 0
    readonly property real rightCapsuleX: leftCapsuleWidth + middleGap

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
            // 模块自带尺寸动画时，外壳不再插手宽度，避免双曲线打架。
            shell.selfDriven = instance.drivesOwnSize === true;
            shell.resizeReady = true;
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
