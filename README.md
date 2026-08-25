# omibar

插件式 Quickshell 底部 bar，为 Hyprland 环境设计。

caelestia-shell 是可选集成：存在时，omibar 可读取它的公开 IPC 和配色文件；不存在时，omibar 继续按 Hyprland bar 运行。

## 架构

- **core/** — 框架层。BarState（统一状态机）、HyprEvents（Hyprland 事件入口）、CaelestiaBridge（可选 caelestia IPC 查询器）、ModuleHost（模块装载器）、Theme（内置主题 + 可选 scheme.json 同步）。
- **modules/** — 插件区，一个模块一个文件夹，入口 `Module.qml`，元信息 `module.json`。
- **bar.json** — 模块清单，唯一事实来源：列出装载哪些模块及对齐位置。

## 模块契约

每个模块提供 `modules/<name>/Module.qml`（内容渲染）+ `module.json`（声明 name / align / description）。动画、间距、hover 由 ModuleHost 统一施加，模块不写自己的进出场动画。

## 运行

```sh
qs -c omibar -p ~/Projects/omibar
```

## 状态

早期骨架阶段，模块清单待扩充。
