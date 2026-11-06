# Window preservation and release icons — November 6, 2026

Fixes [issue #39](https://github.com/maccam912/simulateds/issues/39) and
[issue #40](https://github.com/maccam912/simulateds/issues/40).

## Causes and fixes

- New neighborhood saves the first-day guide choice. Previously every preference
  write reapplied windowed mode when Fullscreen was off, restoring a maximized
  window to its smaller size. Ordinary preference writes now leave window mode
  alone. Loading/resetting preferences and changing Fullscreen still apply it;
  Android retains its immersive-mode choice.
- Icon SVG rasterization was inside an `assert` expression. Release templates
  strip that expression, leaving an empty image. Rasterization now runs normally,
  with an explicit error path. The original vector paths and texture cache stay
  intact; no new assets, world changes or save migration are required.
- The exported native-runtime smoke now requests every icon and checks its
  dimensions without assertions. Desktop/server export packaging requires the
  icon pass marker as well as the native-extension marker, so editor tests alone
  can no longer conceal this release-only failure. Android's APK export still
  uses its existing packaging checks; it is not a runtime icon test.

## Reproduction and checks

`tests/window_preferences.gd` creates neighborhoods with the guide enabled and
disabled. Native runs cover a resized 1280×720 window, maximized mode and native
fullscreen, checking size/position/mode after creation and unrelated audio,
interface, motion, quality and vsync changes. It also checks explicit Fullscreen
on/off and that preferences do not mutate the world. Headless runs cover the
creation flow and world-state boundary; they cannot verify a window manager.

Run with isolated data (never use a player's save for this test):

```sh
python3 tools/godot.py --script res://tests/window_preferences.gd \
  --log-file /tmp/simulateds-window.log -- \
  --save-path=/tmp/simulateds-window/world.json \
  --profile-path=/tmp/simulateds-window/profile.json
python3 tools/export.py macos --skip-build
```

Add `--capture-dir=/absolute/existing/folder` after `--` for native images.
The test is registered in `tools/check.py`. `tests/icons_ui.gd` also checks every
icon at 20, 28 and 40 pixels and verifies cache reuse. Use the editor runner for
these scripts: release templates ignore `--script`. The release's built-in
`--native-smoke` uses explicit checks and runs from the extracted app bundle.

## Evidence and limits

- Native macOS/Apple Silicon, Godot 4.7.2/OpenGL: window regression passed.
  An isolated copy of the original preferences reproduced maximize → windowed
  on saving the guide setting. The fixed native regression and compact icon UI
  suite passed. Day/night captures at 1280×720 and 125% UI, plus the compact menu
  and catalog, were visually inspected.
- Local macOS release ZIP: universal library, bundle plist, strict ad-hoc signature,
  native extension and all release icons passed. The extracted app's menu and
  guide icons were inspected; clicking New neighborhood → Create with the guide
  enabled retained the macOS zoomed/maximized window.
- Local logs and captures: ignored `build/issues-39-40/`, with the standalone native
  window log at `/tmp/simulateds-39-native.log`. The release UI used isolated
  `/tmp/simulateds-39-release/` data. No player's neighborhood was replaced.
- Full local regression and hosted CI are tracked separately in `HANDOFF.md`.
  No physical-device, Intel Mac, Windows/Linux native UI or Android runtime
  playtest was performed for these fixes. No new release has been published.
