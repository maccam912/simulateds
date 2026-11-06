# Android emulator playtest — November 5, 2026

Issue #30 was exercised on a fresh, isolated Android emulator. This change fixes
five observed input/layout problems and records the remaining networking failure.
It is not a physical-device or performance certification.

## Environment and reproduction

- Base: `662b8f8` on `main`; Godot 4.7.2, native ARM64 Iroh extension.
- AVD `simulateds_issue30`: Pixel 7, Android 15/API 35 Google APIs ARM64 image,
  landscape 2400×1080, host GPU. Renderer reports OpenGL ES 3.0 through the Android
  Emulator OpenGL ES Translator on Apple M5 Pro.
- Build: `ANDROID_HOME` points to the local Android SDK, `JAVA_HOME` to Temurin 21;
  `python3 tools/export.py android` produces `build/artifacts/simulateds-android.apk`.
  APK signature verification passed. Later script-only iterations used `--skip-build`.
- Install with `adb -s <serial> install -r build/android/simulateds.apk`, then launch
  `dev.maccam912.simulateds/com.godot.game.GodotAppLauncher`. Use a dedicated AVD;
  do not clear an existing player's application data.
- Exercise through `adb shell input tap`, `swipe`, `text` and `keyevent 4`;
  inspect actual `adb exec-out screencap -p` captures. The ignored local evidence
  directory is `build/issue30/` (captures, actions, export, logcat and test logs).

## Observed problems and fixes

| Before | After |
| --- | --- |
| Android Back immediately exited to the launcher. | Back follows the existing Escape priority, closes choices/trays, opens/resumes the menu, and preserves household draft review. Explicit Quit remains available. |
| The desktop windowed preference restored permanent Android system bars; default text was small on the phone. | Mobile stays immersive; new/reset settings use 125% UI scale. Existing scale settings are preserved. The in-app fullscreen toggle is desktop-only. |
| World zoom required a mouse wheel. | The lot header has 44px minus/plus controls using the same bounded camera operation. |
| Resident preview handled both touch drag and emulated mouse motion, doubling rotation. | Preview consumes the native touch once and ignores duplicate emulated mouse events. |
| Landscape keyboard covered active fields, especially the room-code input. | Only the active UI layer pans above the keyboard, accounting for viewport stretch and embedded windows; dismissal restores its layout. Camera and authoritative world remain unchanged. |

The Controls guide now describes touch holds, panning, zoom, construction and Back.

## Emulator observations

| Flow | Result |
| --- | --- |
| Launch, main menu, Continue, pause/resume, More and Plan dismissal | Passed; Back no longer quits unexpectedly. |
| Day and night world, tap resident, tap to walk, one-finger pan, minus/plus zoom | Passed; real geometry remains visible and camera operations do not enqueue actions. |
| Hold furniture, release, then choose an action | Passed; opening release does not select a choice. |
| Needs → hunger → Have a bite → Plan | Accepted refrigerator activity and observed completion at accelerated time. |
| Build: four-tile floor drag, Undo | Charged 48; Undo restored funds from 11,952 to 12,000. |
| Catalog search, garden bench rotation/placement, Move, Finish | Placed one bench for 140; moving it incurred no second charge; result survived restart. |
| Household preview, name draft, Android keyboard/Back, keep/discard | Draft review preserved the original name when discarded; preview input has a duplicate-event regression. |
| Room-code, household name, catalog search and save-name typing | Active field visible with keyboard open; Back dismisses keyboard and restores controls. |
| Named save/load and restart | Created and loaded `Linden Grove · Day 2QA`, restoring day 2 at 04:21, funds 12,460, original names and the placed bench. Save survived APK replacement/restart. |
| Multiplayer room creation | Android generated a four-character room code through the configured discovery service. |
| Android host → macOS headless client | **Failed** snapshot replication after successful handshake; see below. |

## Networking follow-up

A separate headless desktop probe joined the Android host by its displayed room
code. It reached `Connected · your family is ready`, but the final run never
received an accepted snapshot (`snapshots_received` stayed zero), then reported
`Connection stopped updating. Rejoin to resume your family.` An earlier immediate
rejoin also returned `This family is already connected on another device.` A
fresh host process reproduced the snapshot timeout. Both offline and runtime
restore of the emulator's extracted saved world succeeded on desktop; this alone
does not establish validity of the transmitted runtime snapshot.

The probe used the ordinary `Rooms.join(code)` interface and waited for a snapshot
containing `Session.profile_id` before issuing commands. Local diagnostic logs are
`build/issue30/android-peer-final.log`; its temporary script is
`build/issue30/android_peer.gd`. Root cause remains undetermined. No network,
protocol, identity or save-validation rules were changed as part of these UI
fixes. Do not infer Android multiplayer success from the passing desktop Iroh
suite. Follow up with snapshot assembly/validation diagnostics on an Android host,
then verify join, acknowledged command, leave and reconnect on both platforms.

## Regression and visual boundaries

`tests/android_navigation.gd`, registered in `tools/check.py`, checks Back priority,
focused fields, draft protection, duplicate touch/mouse rotation, zoom bounds and
actual zoom-button activation. It exercises text-field avoidance repeatedly
without drift and asserts world snapshots and saved camera framing stay unchanged.
The native runner captures day/night at 1440×900 and 1280×720 with 125% UI scale:
`build/android-navigation-{normal,compact}-{day,night}.png`.

Run it with isolated save/profile/settings paths:

```sh
python3 tools/godot.py --script res://tests/android_navigation.gd -- \
  --save-path=build/android-qa-world.json \
  --profile-path=build/android-qa-profile.json \
  --settings-path=build/android-qa-settings.json
```

Add `--headless` before `--script` for assertions without native captures.

The full `python3 tools/check.py` exited 0: all 142 gameplay/UI suites, both
save-continuity processes, eight real desktop Iroh scenarios and dedicated-server
smoke passed (`build/issue30/check-final.log`). The final keyboard-coordinate
adjustment additionally passed navigation, creator, catalog and app-flow
regressions and native review. `python3 tools/check_assets.py` passed after staging
(81 hydrated LFS assets); no binary assets were added. The final APK logcat had no
Godot script, parse or error markers during the checked solo flows.

Native macOS renders and Android emulator captures were inspected. Physical
Android finger comfort, hardware GPU behavior, sustained performance/battery,
background hosting and audio listening were not tested. Compact layout renders
are macOS evidence, not a second Android device. Hosted CI and other platform
exports are separate from this local run.
