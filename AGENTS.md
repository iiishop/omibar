# omibar — agent 工作约束

只列可 grep 的硬约束与推断不出的事实。品味判断靠结构，不靠文档。

## 硬性规则

- `modules/**` 中禁止 import 其他模块路径（`import "../<other-module>"` 或绝对模块路径）。共享数据只能经 `core/BarState`。
- caelestia 是可选集成；全仓库唯一允许出现 `qs -c caelestia ipc` 字样的文件是 `core/CaelestiaBridge.qml`。
- `core/*.qml` 是单例（见 core/qmldir），禁止在其中创建第二个 PanelWindow。
- bar 的显隐/避让动画必须做在内部元素的 y/opacity 上；PanelWindow 自身的 visible 不得参与动画（合成器 layersIn/Out 会叠加）。
- 新模块必须在 `bar.json` 登记后才被装载；清单是唯一事实来源。
- 修改避让、launcher 状态同步、caelestia IPC、胶囊布局时，必须同步维护 `docs/avoidance-and-caelestia.md`。

## 环境

- Quickshell 0.3.0（quickshell-git, AUR）；Hyprland。
- 测试实例：`HYPRLAND_INSTANCE_SIGNATURE=$(hyprctl instances | awk 'NR==1{print $2; exit}') WAYLAND_DISPLAY=wayland-1 DISPLAY=:0 QT_QPA_PLATFORM=wayland qs --daemonize -p <项目路径>`（SSH 上下文可起但无输入焦点）。注意 `-c` 与 `-p` 互斥；实例签名用 `hyprctl instances` 第一行的 instance 名，不能用 `hyprctl version -j` 的 tag。
- 可选 caelestia IPC 探测：`qs -c caelestia ipc call drawers isOpen launcher` 返回 stdout "1"/"0"；caelestia 不在跑时命令失败，bridge 必须保持安静且不影响 bar。
- 可选配色源：~/.local/state/caelestia/scheme.json 的 colours 字段（tonalspot 输出，snake_case 键名）；文件不存在时使用内置主题。

## 已知坑

- FileView 读 JSON 用 try/catch 包 parse；清单损坏时保持上次成功状态，不清空 bar。
- launcher 状态优先由 Hyprland 窗口事件触发查询；允许 `BarState.launcherOpen` 为 true 期间的 bounded watcher，禁止 always-on Timer 轮询。
