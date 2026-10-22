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

启动后底部出现 bar：左侧是媒体、时钟与笔记胶囊，右侧是更新与通知。悬停胶囊查看配置的效果；打开 launcher 观察 bar 让位。

## 配置

### 模块清单

`bar.json` 声明装载哪些模块及其分区位置：

```json
{
  "modules": [
    { "name": "media", "band": "left" },
    { "name": "clock", "band": "left" },
    { "name": "note", "band": "left" },
    { "name": "updates", "band": "right" },
    { "name": "notifications", "band": "right" }
  ]
}
```

### 模块契约

每个模块提供 `modules/<name>/Module.qml`（内容渲染）与 `module.json`（name / align / description）。动画、间距与悬停由 `ModuleHost` 统一施加，模块不写自己的进出场动画。模块条目可设置 `hover`（`lift`、`jelly`、`glow`、`none`）。

### 笔记与提醒

悬停 **note** 显示「新增一条」，滚动一格开始浏览已有笔记，点击打开浮动编辑器。
Shelf 最多保留七张卡片，按创建时间排列，新笔记靠近胶囊。侧栏支持搜索、Todo／今日／已完成筛选、置顶、归档与回收站。
正文只有当前行显示源码；代码围栏、表格、引用等跨行内容按块编辑，其余由 Qt 渲染 Markdown。

在属性栏开启 Todo，填写本地日期 `YYYY-MM-DD` 与时间 `HH:mm` 后点「设定」。
正文 checkbox 不参与提醒。新到期任务短闪三次并播放一次可选提示音；右键可完成或延迟十分钟。
多条到期任务显示数量，可滚轮切换；打开只确认提醒，不自动完成。
日历每天最多显示五个 Todo 点，点击有待办的日期会打开对应日期筛选。

快捷键：`Ctrl+N` 新笔记，`Ctrl+Shift+N` 新 Todo，`Ctrl+F` 搜索，
`Ctrl+Enter` 完成／取消完成，`Esc` 关闭；Markdown 可用 `Ctrl+Z`／`Ctrl+Shift+Z` 跨块撤销／重做。
标题留空时使用正文首个非空行；删除进入回收站，可以恢复。

数据存于 `Quickshell.stateDir/notes.json`，350ms 防抖、原子写入，关闭前等待保存完成。
损坏文件不覆盖，保存失败保留内存内容并显示重试操作。备份此文件即可备份笔记。
每份清单只登记一个 note，每个存储文件只运行一个实例。

可选清单配置：

```json
{ "name": "note", "band": "left", "options": { "soundEnabled": true, "respectDnd": true } }
```

`storagePath` 可指定其他数据文件。声音依次探测 `pw-play`、`canberra-gtk-play`、`aplay`；
都不存在则只显示视觉提醒。默认遵守 DND，只抑制声音。clock 和 caelestia 均可缺席。
运行 `sh tests/run-note-tests.sh` 可执行隔离的数据、QML 与存储恢复测试（需要 Node.js 和 Quickshell）。

## 文档

| 主题 | 内容 | 链接 |
|---|---|---|
| 避让与 caelestia | 胶囊避让动画规则与 caelestia IPC 集成 | [打开文档](./docs/avoidance-and-caelestia.md) |

## Star History

<a href="https://www.star-history.com/?type=date&repos=iiishop%2Fomibar">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=iiishop/omibar&type=date&theme=dark&legend=top-left&sealed_token=MMCxquqAlbV9fQrbpHCinyXd73kFEZGJWo_Sw-FywlMyQxcGt40t9lAzY10jk0yXi6bc6c7xnGpnlpsWza0HAMd0NwMQiPIvYv-_P53Ebrpk2GPhvmPiCw" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=iiishop/omibar&type=date&legend=top-left&sealed_token=MMCxquqAlbV9fQrbpHCinyXd73kFEZGJWo_Sw-FywlMyQxcGt40t9lAzY10jk0yXi6bc6c7xnGpnlpsWza0HAMd0NwMQiPIvYv-_P53Ebrpk2GPhvmPiCw" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=iiishop/omibar&type=date&legend=top-left&sealed_token=MMCxquqAlbV9fQrbpHCinyXd73kFEZGJWo_Sw-FywlMyQxcGt40t9lAzY10jk0yXi6bc6c7xnGpnlpsWza0HAMd0NwMQiPIvYv-_P53Ebrpk2GPhvmPiCw" />
 </picture>
</a>
