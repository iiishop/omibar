// Theme — 从 caelestia scheme.json 同步配色。
// 换壁纸 → caelestia smartScheme 重新生成配色 → 本文件轮询跟进。
// scheme.json 不可用时回落到内置的暗色基线，bar 永远可用。
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string schemePath: Quickshell.env("HOME") + "/.local/state/caelestia/scheme.json"

    // M3 语义槽（暗色基线）；胶囊本体固定近黑，这些色只用于内容
    property color surface: "#1b1b1f"
    property color surfaceContainer: "#1e1e22"
    property color fg: "#e4e2e6"
    property color fgVariant: "#8f8c94"
    property color primary: "#aecbff"
    property color outline: "#48494e"

    function apply(data: var): void {
        const colours = data.colours;
        if (colours === undefined)
            return;
        if (colours.surface !== undefined) root.surface = colours.surface;
        if (colours.surface_container !== undefined) root.surfaceContainer = colours.surface_container;
        if (colours.on_surface !== undefined) root.fg = colours.on_surface;
        if (colours.on_surface_variant !== undefined) root.fgVariant = colours.on_surface_variant;
        if (colours.primary !== undefined) root.primary = colours.primary;
        if (colours.outline !== undefined) root.outline = colours.outline;
    }

    function refresh(): void {
        schemeFile.reload();
    }

    readonly property FileView schemeFile: FileView {
        path: root.schemePath
        watchChanges: true

        onLoaded: {
            try {
                root.apply(JSON.parse(text()));
            } catch (e) {
                console.warn("[omibar] scheme.json parse failed:", e);
            }
        }
        onFileChanged: root.refresh()
        onLoadFailed: err => console.warn("[omibar] scheme.json unavailable:", err)
    }

    Component.onCompleted: refresh()
}
