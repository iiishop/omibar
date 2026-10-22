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

You should see the bottom bar appear with the media, clock and note capsules on the left, updates and notifications on the right. Hover a capsule to see its configured effect; open the launcher to watch the bar yield.

## Configuration

### Module manifest

`bar.json` lists which modules load and their band position:

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

### Module contract

Each module ships `modules/<name>/Module.qml` (content) plus `module.json` (name / align / description). Animation, spacing, and hover are applied uniformly by `ModuleHost`; modules do not write their own entry/exit animations. A module entry may set `hover` (`lift`, `jelly`, `glow`, `none`).

### Notes and reminders

Hover **note** to capture a new note; scroll one notch to browse existing notes.
The shelf displays up to seven cards, ordered by creation time, with newer notes
nearest the capsule. Click to open the floating editor. Its sidebar supports
search, Todo/today/completed filters, pinning, archives and a recoverable trash.
Only the active Markdown line is source; fences, tables and quotes edit as blocks.

Enable Todo and set a local `YYYY-MM-DD` / `HH:mm` deadline in the property bar.
Markdown checkboxes never schedule reminders. New deadlines produce three short
flashes and one optional sound; right-click to complete or snooze for ten minutes.
Multiple due notes show a count and can be browsed with the wheel. Opening a note
acknowledges its alert without completing it. Calendar dots represent active Todos
(at most five per date); clicking a date filters the editor to that day.

Editor shortcuts: `Ctrl+N` new note, `Ctrl+Shift+N` new Todo, `Ctrl+F` search,
`Ctrl+Enter` toggle completion, `Esc` close. Markdown supports `Ctrl+Z` undo and
`Ctrl+Shift+Z` redo across block changes. Clearing the title derives it from the
first nonempty body line. Deletion moves a note to Trash, where it can be restored.

Notes are atomically saved to `Quickshell.stateDir/notes.json`, with a 350 ms debounce
and a write barrier on close. Corrupt files are kept intact; write errors keep the
document in memory and show a retry action. Back up this file to preserve notes.
Use one note entry per bar manifest and one running instance per storage file.

Optional manifest settings:

```json
{ "name": "note", "band": "left", "options": { "soundEnabled": true, "respectDnd": true } }
```

`storagePath` can override the notes file location. Audio probes `pw-play`, then
`canberra-gtk-play`, then `aplay`; absent audio tools mean visual-only reminders.
DND suppresses sound, while visual reminders remain active. Neither clock nor
caelestia is required. Run `sh tests/run-note-tests.sh` for isolated data, QML and
storage recovery tests (Node.js and Quickshell required).

## Documentation

| Topic | What it covers | Link |
|---|---|---|
| Avoidance & caelestia | Capsule avoidance animation rules and caelestia IPC integration | [Open documentation](./docs/avoidance-and-caelestia.md) |

## Star History

<a href="https://www.star-history.com/?type=date&repos=iiishop%2Fomibar">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=iiishop/omibar&type=date&theme=dark&legend=top-left&sealed_token=MMCxquqAlbV9fQrbpHCinyXd73kFEZGJWo_Sw-FywlMyQxcGt40t9lAzY10jk0yXi6bc6c7xnGpnlpsWza0HAMd0NwMQiPIvYv-_P53Ebrpk2GPhvmPiCw" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=iiishop/omibar&type=date&legend=top-left&sealed_token=MMCxquqAlbV9fQrbpHCinyXd73kFEZGJWo_Sw-FywlMyQxcGt40t9lAzY10jk0yXi6bc6c7xnGpnlpsWza0HAMd0NwMQiPIvYv-_P53Ebrpk2GPhvmPiCw" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=iiishop/omibar&type=date&legend=top-left&sealed_token=MMCxquqAlbV9fQrbpHCinyXd73kFEZGJWo_Sw-FywlMyQxcGt40t9lAzY10jk0yXi6bc6c7xnGpnlpsWza0HAMd0NwMQiPIvYv-_P53Ebrpk2GPhvmPiCw" />
 </picture>
</a>
