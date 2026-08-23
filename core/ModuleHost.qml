// ModuleHost — 模块装载器。
// 职责：读 bar.json 清单 → 按顺序装载 modules/<name>/Module.qml →
//       按 manifest.align 分左/中/右三区 → 统一施加进出场动画与 hover。
// 铁律：本层是模块唯一的宿主环境；模块之间禁止互相 import。
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

Item {
    id: root

    required property string configDir

    readonly property url barConfigUrl: Qt.resolvedUrl(configDir + "/bar.json")
    property var manifest: []   // [{name, align}]

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
            manifest = (data.modules ?? []).map(m =>
                typeof m === "string" ? { name: m, align: "left" } : m);
        } catch (e) {
            console.warn("[omibar] bar.json parse failed:", e);
        }
    }
}
