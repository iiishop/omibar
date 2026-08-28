<h1 align="center">omibar</h1>

<p align="center">A plugin-based Quickshell bottom bar for Hyprland.</p>

<p align="center">
  <a href="./README.md">English</a> | <a href="./README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <img src="https://img.shields.io/github/stars/iiishop/omibar?style=flat-square" alt="GitHub stars">
  <a href="https://github.com/iiishop/omibar/releases"><img src="https://img.shields.io/github/v/release/iiishop/omibar?style=flat-square" alt="Release"></a>
</p>

omibar is a modular status bar for Hyprland, built on Quickshell. Modules are loaded from a manifest, placed into left/right bands, and share a unified state machine, theme, and hover system. [caelestia-shell](https://github.com/caelestia-dots/shell) integration is optional: when present, omibar reads its IPC and color scheme; when absent, omibar runs standalone.

## Highlights

| Highlight | Why it matters |
|---|---|
| Manifest-driven modules | `bar.json` is the single source of truth for which modules load and where they sit |
| Dynamic island avoidance | Capsules smoothly yield when the launcher or a fullscreen window appears, with springy jelly deformation |
| Per-module hover effects | Choose `lift`, `jelly`, `glow`, or `none` per module from the manifest |
| Optional caelestia integration | Auto-syncs color scheme and drawer state; degrades gracefully when caelestia is not running |
| Material 3 theming | Full semantic color slots that follow the active theme or a caelestia `scheme.json` |

## Architecture

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

## Quick Install

Requires [Hyprland](https://hyprland.org) and Quickshell 0.3+ (AUR: `quickshell-git`).

```sh
git clone https://github.com/iiishop/omibar
cd omibar
```

## Quick Start

Launch the bar with Quickshell:

```sh
qs -c omibar -p .
```

You should see the bottom bar appear with the media and clock capsules on the left, updates and notifications on the right. Hover a capsule to see its configured effect; open the launcher to watch the bar yield.

## Configuration

### Module manifest

`bar.json` lists which modules load and their band position:

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

### Module contract

Each module ships `modules/<name>/Module.qml` (content) plus `module.json` (name / align / description). Animation, spacing, and hover are applied uniformly by `ModuleHost`; modules do not write their own entry/exit animations. A module entry may set `hover` (`lift`, `jelly`, `glow`, `none`).

## Documentation

| Topic | What it covers | Link |
|---|---|---|
| Avoidance & caelestia | Capsule avoidance animation rules and caelestia IPC integration | [Open documentation](./docs/avoidance-and-caelestia.md) |

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=iiishop%2Fomibar&type=Date)](https://star-history.com/#iiishop/omibar&Date)
