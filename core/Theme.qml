// Theme — 内置暗色基线，可选同步 caelestia scheme.json。
// scheme.json 不可用是正常状态，bar 继续使用内置配色。
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string schemePath: Quickshell.env("HOME") + "/.local/state/caelestia/scheme.json"

    property color surface: "#191114"
    property color surfaceContainer: "#261d20"
    property color surfaceContainerHigh: "#31282a"
    property color surfaceContainerHighest: "#3c3235"
    property color fg: "#efdfe2"
    property color fgVariant: "#d5c2c6"
    property color primary: "#ffb0ca"
    property color secondary: "#e2bdc7"
    property color secondaryContainer: "#5a3f48"
    property color tertiary: "#f0bc95"
    property color tertiaryContainer: "#b58763"
    property color outline: "#9e8c91"
    property color outlineVariant: "#514347"
    property color error: "#ffb4ab"
    property color errorContainer: "#93000a"
    property color errorForeground: "#690005"

    readonly property string bodyFont: "GoogleSansFlex"
    readonly property string monoFont: "CaskaydiaCove NF"
    readonly property string iconFont: "Material Symbols Rounded"

    function colorValue(colours: var, snakeName: string, camelName: string,
                        fallback: color): color {
        const value = colours[snakeName] ?? colours[camelName];
        if (value === undefined)
            return fallback;
        const text = String(value);
        return text.startsWith("#") ? text : "#" + text;
    }

    function apply(data: var): void {
        const colours = data.colours;
        if (colours === undefined)
            return;
        root.surface = colorValue(colours, "surface", "surface", root.surface);
        root.surfaceContainer = colorValue(colours, "surface_container",
                                           "surfaceContainer", root.surfaceContainer);
        root.surfaceContainerHigh = colorValue(colours, "surface_container_high",
                                               "surfaceContainerHigh",
                                               root.surfaceContainerHigh);
        root.surfaceContainerHighest = colorValue(colours,
                                                  "surface_container_highest",
                                                  "surfaceContainerHighest",
                                                  root.surfaceContainerHighest);
        root.fg = colorValue(colours, "on_surface", "onSurface", root.fg);
        root.fgVariant = colorValue(colours, "on_surface_variant",
                                    "onSurfaceVariant", root.fgVariant);
        root.primary = colorValue(colours, "primary", "primary", root.primary);
        root.secondary = colorValue(colours, "secondary", "secondary",
                                    root.secondary);
        root.secondaryContainer = colorValue(colours, "secondary_container",
                                             "secondaryContainer",
                                             root.secondaryContainer);
        root.tertiary = colorValue(colours, "tertiary", "tertiary",
                                   root.tertiary);
        root.tertiaryContainer = colorValue(colours, "tertiary_container",
                                            "tertiaryContainer",
                                            root.tertiaryContainer);
        root.outline = colorValue(colours, "outline", "outline", root.outline);
        root.outlineVariant = colorValue(colours, "outline_variant",
                                         "outlineVariant", root.outlineVariant);
        root.error = colorValue(colours, "error", "error", root.error);
        root.errorContainer = colorValue(colours, "error_container", "errorContainer", root.errorContainer);
        root.errorForeground = colorValue(colours, "on_error", "onError", root.errorForeground);
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
        onLoadFailed: err => {}
    }

    Component.onCompleted: refresh()
}
