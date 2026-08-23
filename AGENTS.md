# omibar — agent 工作约束

只列可 grep 的硬约束与推断不出的事实。品味判断靠结构，不靠文档。

## 硬性规则

- `modules/**` 中禁止 import 其他模块路径（`import "../<other-module>"` 或绝对模块路径）。共享数据只能经 `core/BarState`。
- 全仓库唯一允许出现 `qs -c caelestia ipc` 字样的文件是 `core/CaelestiaBridge.qml`。
- `core/*.qml` 是单例（见 core/qmldir），禁止在其中创建第二个 PanelWindow。
- bar 的显隐/避让动画必须做在内部元素的 y/opacity 上；PanelWindow 自身的 visible 不得参与动画（合成器 layersIn/Out 会叠加）。
- 新模块必须在 `bar.json` 登记后才被装载；清单是唯一事实来源。

## 环境

- Quickshell 0.3.0（quickshell-git, AUR）；Hyprland；caelestia-shell 2.3.0 并行运行于 `qs -c caelestia`。
- 测试实例：`WAYLAND_DISPLAY=wayland-1 DISPLAY=:0 QT_QPA_PLATFORM=wayland HYPRLAND_INSTANCE_SIGNATURE=$(hyprctl version -j | jq -r .tag) qs -c omibar -p <项目路径>`（SSH 上下文可起但无输入焦点）。
- caelestia IPC 探测：`qs -c caelestia ipc call drawers isOpen launcher` 返回 stdout "1"/"0"；caelestia 不在跑时命令失败，bridge 必须优雅降级。
- 配色源：~/.local/state/caelestia/scheme.json 的 colours 字段（tonalspot 输出，snake_case 键名）。

## 已知坑

- FileView 读 JSON 用 try/catch 包 parse；清单损坏时保持上次成功状态，不清空 bar。
- Timer 轮询间隔改动需同步 README 的"800ms"描述。
