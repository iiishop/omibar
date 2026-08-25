# Launcher Avoidance And Caelestia Sync

This document is the maintenance note for omibar's launcher avoidance behavior and
its optional caelestia integration.

## Ownership

- `core/BarState.qml` is the state source used by geometry and modules.
- `core/CaelestiaBridge.qml` is the only boundary that calls caelestia IPC.
- `core/HyprEvents.qml` translates Hyprland events into state refresh requests.
- `core/BarWindow.qml` owns the layer-shell window and outer vertical motion.
- `core/ModuleHost.qml` owns module placement and per-section capsules.
- `core/AvoidingCapsule.qml` owns per-capsule launcher avoidance and deformation.

Modules should not query caelestia directly. They read `BarState` and call bridge
methods.

## Launcher State

Caelestia exposes launcher state through:

```sh
qs -c caelestia ipc call drawers isOpen launcher
```

The command returns `1` when the launcher is open and `0` when it is closed.
Because caelestia is optional, command failure must keep omibar quiet and reset
launcher avoidance to closed.

`CaelestiaBridge.refreshLauncher()` performs the actual query. If a query is
already running, it records `refreshPending` and runs one more query after the
current process exits.

## Why There Is A Watcher

Opening the launcher goes through the Hyprland Super bind, which also calls:

```sh
qs -p /home/iiishop/Projects/omibar ipc call omibar syncLauncher
```

Closing is different. Escape, selecting an app, or clicking outside may only
change caelestia's internal `ShellState`; the `caelestia-drawers` layer can stay
mapped, so Hyprland may not emit a useful close event. In that state caelestia
returns `0`, but omibar can still have `BarState.launcherOpen === true`.

For that reason `CaelestiaBridge.launcherOpenWatcher` runs only while
`BarState.launcherOpen` is true. It checks caelestia every 350 ms and stops as
soon as the bridge reads `0`. This is not an always-on poller; it is bounded by
the launcher-open state and exists to repair missed close signals.

`HyprEvents` also calls `refreshLauncherSoon()` for `activewindow`, `openwindow`,
`closewindow`, `openlayer`, and `closelayer`. That delayed check covers event
ordering where Hyprland fires before caelestia has finished flipping drawer
state.

## Avoidance Geometry

`BarWindow` keeps the `PanelWindow` visible and transparent. The horizontal
moving objects are the individual capsule items, not the layer-shell window
itself.

The shift is derived in `BarState`:

- `launcherWidth` is the expected launcher panel width.
- `launcherPadding` is the minimum gap between launcher and omibar.
- `avoidanceInset` is a conservative side inset based on the full panel width,
so the `PanelWindow` remains wide enough for either side movement.

Each `AvoidingCapsule` derives its own neutral screen center from
`ModuleHost.neutralScreenX + neutralX + width / 2`. When `launcherOpen` is true,
the capsule moves left if its neutral center is at or left of launcher center,
and right otherwise. Its shift is `(launcherWidth + width) / 2 + launcherPadding`.
When `launcherOpen` becomes false, the same binding returns that capsule to its
neutral x position.

## Animation

Avoidance animation stays inside the bar internals:

- `AvoidingCapsule.Behavior on x` gives each capsule its spring movement.
- `AvoidingCapsule.Behavior on width` smooths capsule width changes.
- `BarWindow.Behavior on y` smooths fullscreen vertical avoidance.
- `AvoidingCapsule.deformAnimation` applies a short squeeze and rebound through
  `Scale`.

Do not animate `PanelWindow.visible` or move the `PanelWindow` itself. Layer-shell
animations and compositor layer transitions can otherwise combine in surprising
ways.

## Capsules

`ModuleHost` draws separate capsules for non-empty left, center, and right
sections. The outer `panel` is transparent and only provides the neutral
coordinate space.

The content width keeps the center section visually centered by reserving equal
space for the wider side:

- `leftCapsuleWidth`, `centerCapsuleWidth`, `rightCapsuleWidth` include section
  padding.
- `sideWidth` is the max of left and right capsule widths.
- `centerBandWidth` is center plus symmetric side reservation.
- `contentWidth` is the max of center-band width and side-only width.

If a module root is an `Item`, it must set real `width` and `height`, not only
`implicitWidth` and `implicitHeight`, because `Row` placement depends on actual
geometry.

## Debugging

Useful read-only checks:

```sh
qs -c caelestia ipc call drawers isOpen launcher
qs -p /home/iiishop/Projects/omibar ipc call omibar debugLauncher
qs -p /home/iiishop/Projects/omibar ipc call omibar debugNotifications
hyprctl layers -j
```

Expected stuck-state diagnosis before the active watcher fix:

- caelestia returned `0`.
- `debugLauncher` returned `launcherOpen: true`.
- omibar stayed shifted because its internal state missed the close.

After the fix, when caelestia returns `0`, `debugLauncher` should report
`launcherOpen: false` within the watcher interval.

Each capsule's neutral center should be derived before launcher offset is
applied. If the moved x position feeds back into direction, the capsule can flip
directions or jitter while avoiding.
