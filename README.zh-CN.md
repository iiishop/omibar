<h1 align="center">omibar</h1>

<p align="center">为 Hyprland 设计的插件式 Quickshell 底部 bar。</p>

<p align="center">
  <a href="./README.md">English</a> | <a href="./README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <img src="https://img.shields.io/github/stars/iiishop/omibar?style=flat-square" alt="GitHub stars">
  <a href="https://github.com/iiishop/omibar/releases"><img src="https://img.shields.io/github/v/release/iiishop/omibar?style=flat-square" alt="Release"></a>
</p>

omibar 是基于 Quickshell 的模块化 Hyprland 状态栏。模块由清单装载，分布在左右分区，共享统一的状态机、主题与悬停系统。[caelestia-shell](https://github.com/caelestia-dots/shell) 为可选集成：存在时读取其 IPC 与配色文件，不存在时 omibar 独立运行。

## 亮点

| 亮点 | 为什么重要 |
|---|---|
| 清单驱动模块 | `bar.json` 是模块装载与位置的唯一事实来源 |
| 灵动岛式避让 | launcher 或全屏窗口出现时胶囊平滑让位，带果冻形变 |
| 每模块悬停效果 | 清单中可为每个模块选择 `lift`、`jelly`、`glow`、`none` |
| 可选 caelestia 集成 | 自动同步配色与抽屉状态，未运行时优雅降级 |
| Material 3 主题 | 完整语义色槽，跟随主题或 caelestia `scheme.json` |

## 架构

```text
┌──────────┐   bar.json   ┌─────────────────┐
│ modules/ │─────────────▶│   ModuleHost    │
│  media   │  loads into  │  (loader +      │
│  clock   │  bands       │   layout)       │
│ updates  │              └───┬─────┬───────┘
│ notif.   │                  │     │
└──────────┘          ┌───────▼─┐ ┌─▼────────┐
                      │BarState │ │  Theme   │
                      │ state   │ │colors/font│
                      └────┬────┘ └────┬─────┘
                           │           │
                  ┌────────▼───┐  ┌────▼────────┐
                  │HyprEvents  │  │Caelestia    │
                  │Hyprland IPC│  │Bridge (opt.)│
                  └────────────┘  └─────────────┘
```

## 安装

依赖 [Hyprland](https://hyprland.org) 与 Quickshell 0.3+（AUR：`quickshell-git`）。

```sh
git clone https://github.com/iiishop/omibar
cd omibar
```

## 快速开始

```sh
qs -c omibar -p .
```

启动后底部出现 bar：左侧是媒体与时钟胶囊，右侧是更新与通知。悬停胶囊查看配置的效果；打开 launcher 观察 bar 让位。

## 配置

### 模块清单

`bar.json` 声明装载哪些模块及其分区位置：

```json
{
  "modules": [
    { "name": "media", "band": "left" },
    { "name": "clock", "band": "left" },
    { "name": "updates", "band": "right" },
    { "name": "notifications", "band": "right" }
  ]
}
```

### 模块契约

每个模块提供 `modules/<name>/Module.qml`（内容渲染）与 `module.json`（name / align / description）。动画、间距与悬停由 `ModuleHost` 统一施加，模块不写自己的进出场动画。模块条目可设置 `hover`（`lift`、`jelly`、`glow`、`none`）。

## 文档

| 主题 | 内容 | 链接 |
|---|---|---|
| 避让与 caelestia | 胶囊避让动画规则与 caelestia IPC 集成 | [打开文档](./docs/avoidance-and-caelestia.md) |

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=iiishop%2Fomibar&type=Date&v=2)](https://star-history.com/#iiishop/omibar&Date)
