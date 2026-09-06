# Launcher Avoidance And Caelestia Sync

This document is the maintenance note for omibar's launcher avoidance behavior and
its optional caelestia integration.

## Ownership

- `core/BarState.qml` is the state source used by geometry and modules.
- `core/CaelestiaBridge.qml` is the only boundary that calls caelestia IPC.
- `core/HyprEvents.qml` translates Hyprland events into state refresh requests.
- `core/Theme.qml` adapts caelestia's generated Material 3 colour scheme into
  omibar's local semantic slots.
- `core/BarWindow.qml` owns the layer-shell window and outer vertical motion.
- `core/ModuleHost.qml` owns module placement and per-section avoidance bands.
- `core/AvoidingCapsule.qml` owns per-band launcher avoidance and inertial lag.
- `core/JellyMotion.qml` owns reusable squash, recoil, and inertial lag motion.
- `core/ModuleHost.qml` owns per-module static visual shells.
- `core/HoverMotion.qml` owns reusable hover response presets. It is separate
  from `JellyMotion`, which remains dedicated to travel/avoidance motion.

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
moving objects are the individual avoidance bands, not the layer-shell window
itself.

The shift is derived in `BarState`:

- `launcherWidth` is the expected launcher panel width.
- `launcherPadding` is the minimum gap between launcher and omibar.
- `avoidanceInset` is a conservative side inset based on the widest avoided
  side stack, so the `PanelWindow` remains wide enough for either side
  movement.

Each `AvoidingCapsule` receives an explicit `movementDirection` from
`ModuleHost`: left band is `-1`, right band is `1`. When `launcherOpen` is true,
the final position is edge based: a left-moving capsule places its right edge at
`launcherLeft - launcherPadding`, and a right-moving capsule places its left
edge at `launcherRight + launcherPadding`. When `launcherOpen` becomes false,
the same binding returns that capsule to its neutral x position.

## Animation

Avoidance animation stays inside the bar internals:

- `AvoidingCapsule.Behavior on x` gives each avoidance band a fixed-duration
  `OutCubic` travel animation. Leaving avoidance is shorter than entering it.
- `AvoidingCapsule.Behavior on width` smooths band width changes.
- `BarWindow.Behavior on y` smooths fullscreen vertical avoidance.
- `JellyMotion` gives the module row a 14 px inertial lag opposite the current
  travel direction, then returns it to zero. The row itself is not scaled:
  capsule surfaces must not stretch during avoidance.
- `AvoidingCapsule` treats movement as a band-local gap wave. Each gap gets a
  phase delay from its neutral distance to `movementOriginX`, then its larger
  compression/recoil delta contributes visual offsets to the modules on either
  side. Static row spacing stays equal to `BarState.moduleGap`, so movement
  geometry does not drift while moving. The visual compression may reduce a gap
  down to `AvoidingCapsule.minimumMotionGap` during the impulse; the current
  value is 1 px for a deliberately strong jelly effect.
- `AvoidingCapsule.bandItems` is the explicit band API for modules affected by
  the gap wave. `ModuleHost` registers each module shell; avoidance must not
  infer movable modules from arbitrary `row.children`.
- A registered shell with zero width is ignored by the active gap wave, so
  modules can hide by returning zero width without leaving a phantom gap.
- `ModuleHost` wraps every loaded module in a static shell. It does not
  read hover settings from the manifest and does not apply hover animation.
- `HoverMotion` is only a reusable library. A module that wants hover motion
  must instantiate it inside its own `Module.qml`, so hover behavior stays owned
  by the module instead of the host.

Do not animate `PanelWindow.visible` or move the `PanelWindow` itself. Layer-shell
animations and compositor layer transitions can otherwise combine in surprising
ways.

## Capsules

`ModuleHost` groups modules into left and right avoidance bands.
`ModuleHost` draws each module's own capsule surface, so `BarState.moduleGap`
creates transparent space between neighboring modules. The outer `panel` is
transparent and only provides the neutral coordinate space.

The content width reserves equal space for the wider side on both sides of the
middle gap. That keeps the split between left and right bands aligned with the
launcher center even when the two bands have different widths.

- `bar.json` assigns each module to a motion `band`: `left` or `right`.
- `leftCapsuleWidth` and `rightCapsuleWidth` come from the module row widths.
- `middleGap` is the actual gap between the two motion bands.
- `sideExtent` and `avoidanceSideWidth` are the wider avoided side stack.
- `BarState.moduleGap` is the single core gap used between modules and in
  section width reservation.
- `contentWidth` is `sideExtent * 2 + middleGap`.
- The updates module keeps a visible status label even when no updates are
  available. Its implicit width follows that label; the host owns capsule
  sizing and includes it in the normal band geometry.

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
