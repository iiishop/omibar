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
- `core/ModuleHost.qml` owns per-module shells and elastic width transitions.
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

`BarWindow` keeps the `PanelWindow` visible and transparent, anchored across the
screen as a thin bottom strip. Its width stays fixed during capsule animation.
An input mask follows the two module rows, allowing pointer events outside the
bands to pass through. Vertical padding accommodates the maximum surface bulge
without changing the normal capsule bottom gap or explicit exclusive zone.

The shift is derived in `BarState`:

- `launcherWidth` is the expected launcher panel width.
- `launcherPadding` is the minimum gap between launcher and omibar.
- `avoidanceInset` describes conservative avoidance space based on the widest
  side stack; it does not drive the layer-shell window width.

Each `AvoidingCapsule` receives an explicit `movementDirection` from
`ModuleHost`: left band is `-1`, right band is `1`. When `launcherOpen` is true,
the final position is edge based: a left-moving capsule places its right edge at
`launcherLeft - launcherPadding`, and a right-moving capsule places its left
edge at `launcherRight + launcherPadding`. When `launcherOpen` becomes false,
the same binding returns that capsule to its neutral x position.

## Animation

Avoidance animation stays inside the bar internals:

- `AvoidingCapsule.Behavior on yieldProgress` gives each avoidance band a
  fixed-duration `OutCubic` travel animation. Leaving avoidance is shorter than
  entering it. Neutral x follows layout immediately; it has no separate animation
  that could lag behind a width change.
- `ModuleHost` animates each module shell's width with a 520 ms `OutBack` curve
  and overshoot 1.6. The width passes its target once, then settles without
  repeated oscillation. Band and inner panel widths follow the animated module
  widths directly; the native window width remains fixed.
- The signed width overshoot drives surface height: expansion beyond the target
  compresses it, and contraction below the target makes it taller. Height changes
  use a gain of 1.8, are limited to 10%, and return to normal with width, without an independent height
  animation. Resizing applies no horizontal content lag; text is not scaled.
  Content overflow is clipped while the shell is narrower than its target; the
  background can bulge vertically. Initial loading and zero-width hiding are
  immediate; ordinary size changes can reverse mid-flight from their current width.
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
- `ModuleHost` wraps every loaded module in a shell. It does not
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

The occupied span of both bands is centered as a whole. A capsule growing by a
width delta shifts the span's start left by half that delta, cancelling the
capsule center's own half-width increase. Its center stays fixed during expansion,
contraction and reversal; neighbors move outward by half the delta. The band split
may move away from the screen center when band widths differ. Launcher avoidance
still places each band's inner edge outside the launcher independently.

The inner bar is anchored to the fixed window content's horizontal center, with
fractional center alignment enabled. Native window resizing and integer center
rounding must not introduce horizontal movement during width interpolation.
Both the capsule surface and its content expand about their center without an
additional horizontal translation from the resize animation.

- `bar.json` assigns each module to a motion `band`: `left` or `right`.
- `leftCapsuleWidth` and `rightCapsuleWidth` come from the module row widths.
- `middleGap` is the actual gap between the two motion bands.
- `sideExtent` and `avoidanceSideWidth` are the wider avoided side stack.
- `BarState.moduleGap` is the single core gap used between modules and in
  section width reservation.
- `contentWidth` is `leftCapsuleWidth + middleGap + rightCapsuleWidth`.
- `sideExtent` is used for conservative avoidance space, not neutral alignment.
- The updates module keeps a visible status label even when no updates are
  available. Its implicit width follows that label; the host owns capsule
  sizing and includes it in the normal band geometry.

If a module root is an `Item`, it must set real `width` and `height`, not only
`implicitWidth` and `implicitHeight`, because `Row` placement depends on actual
geometry.

Run `sh tests/run-layout-tests.sh` to sample capsule centers throughout expansion,
contraction and reversal in both bands, and verify launcher avoidance endpoints.

## Island Expansion

A module may grow taller than the capsule without changing the bar's height. The
media module uses this to morph its own capsule into a card: one surface, one
animation, no second window.

The rules that make it work:

- `AvoidingCapsule.row` has a locked `height: BarState.moduleHeight`. Neighbour
  capsules therefore never move vertically and the bar strip keeps its height.
- `ModuleHost`'s module shell takes
  `implicitHeight: Math.max(BarState.moduleHeight, contentSlot.childrenRect.height)`
  and positions itself with `y: parent.height - height`, so growth goes upward
  out of the row instead of pushing the row taller.
- `BarWindow` reserves `BarState.islandExpandExtent` in its own `implicitHeight`
  and pins `panel` to the window's bottom edge with `anchors.bottomMargin`. The
  window grows upward; the capsule row stays where it is. `exclusiveZone` is not
  touched, so the desktop work area is unchanged while expanded.
- `ModuleHost` drops the host-drawn capsule background
  (`opacity: contentHeight > moduleHeight ? 0 : 1`) whenever a module exceeds the
  capsule height. The module draws its own shape, so there is exactly one
  visible surface at every frame of the transition.
- `ModuleHost.inputRegion` extends each band upward by `islandExpandExtent` so the
  expanded area can still receive pointer events; the collapsed strip keeps the
  original capsule rectangle.

The module drives the whole transition from its own `width`/`height` plus a
`radius` animation, and cross-fades the collapsed and expanded content instead of
swapping windows. Collapsed content is pinned to a fixed-height item at the
bottom, so it never stretches while the shape grows.

## Debugging

### Note windows and optional integration

The note capsule measures fifteen CJK glyphs with `TextMetrics` in `Theme.bodyFont`.
Its content width participates in the existing `ModuleHost` shell animation. The
seven-card shelf lives in a transparent anchored `PopupWindow`, and the editor in
one transparent `FloatingWindow`; neither adds children to the bar's layout or a
second layer-shell panel. The shelf shares the clock's 140 ms hover grace period.

Note owns its store and minute-precision reminder clock. It publishes only
`todoCountByDate`, `overdueCountByDate` and `noteAvailable` through `BarState`.
Clock sends `noteDateRequest` plus an incrementing serial, so clicking the same date
twice still delivers two requests. Unloading note clears its summaries. Neither
module imports the other.

Note reads DND exclusively from `BarState.notificationDnd`; it never probes
caelestia. The optional audio process probes local players once, and missing players
or playback failures mean visual-only alerts. `Theme.error`, `errorContainer` and
`errorForeground` map the scheme's `error`, `error_container` and `on_error` slots.
The last property avoids QML's reserved `onError` handler spelling.

Autosave uses atomic `FileView` writes. Close and unload wait for any asynchronous
write before a synchronous flush: this ordering prevents Quickshell 0.3's pending
write cancellation from dropping the next payload. Parse failures disable editing
without overwriting the file; failed saves retain the in-memory document for retry.

### Launcher checks

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
