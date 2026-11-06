# Android emulator playtest — November 5, 2026

Issue #30 was exercised on a fresh, isolated Android emulator. This change fixes
five observed input/layout problems. The networking follow-up below resolves the
subsequently reproduced first-connection snapshot failure.
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
| Android host → macOS headless client | Failed in the original UI pass; passed after the transport workaround below. |

## Original networking failure

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
`build/issue30/android_peer.gd`. At the end of that UI pass, the cause was still
undetermined, and no network, protocol, identity or save-validation rules had
changed. The passing desktop Iroh suite did not establish Android multiplayer
success. The follow-up below investigates that gap with the actual APK.

## First-connection transport fix — November 5, 2026

Reproduced on base `6764379` using the same isolated AVD and saved neighborhood.
Three default-transport first connections received the welcome packet but no
snapshot chunks before the 20-second stale-connection timeout. Temporary host
diagnostics showed bounded snapshots being queued and their sends returning OK;
client diagnostics saw only the welcome packet. A later connection to the same
host worked, as did a fresh connection with the desktop client forced to relay.
This places the observed failure before snapshot assembly or world validation.
Diagnostic packet logging and captured world data are not shipped.

The pattern matches Iroh's [cached GSO capability failure](https://github.com/n0-computer/iroh/issues/4555)
and its [Android upload report](https://github.com/n0-computer/iroh/issues/4647):
small packets arrive, burst traffic stalls, and later connections can recover
after the socket disables segmentation offload. These upstream reports are
supporting evidence, not a physical-phone reproduction of our emulator result.

The shared native endpoint builder disables QUIC segmentation offload on Android
for both hosting and joining. Desktop defaults, direct-path discovery, relay
fallback, MTU discovery, packet bounds, protocol, snapshot validation and identity
rules remain unchanged. No dependency upgrade or relay-only mobile policy is
introduced. Revisit this workaround after the upstream fix reaches the pinned
Iroh version. Extra send calls may cost CPU under heavy traffic; throughput and
battery impact have not been measured.

### Repeatable APK / desktop check

Rebuild the Android native library before exporting; `--skip-build` alone cannot
pick up a Rust change. Install the resulting development-signed APK on a dedicated
AVD. Restart its app process before testing its **first** connection, because
reconnecting to an already-used endpoint masked the original failure.

```sh
python3 tools/build_native.py android
python3 tools/export.py android --skip-build
```

`tests/android_peer.gd` is a desktop companion to the actual APK. It is excluded
from exports and intentionally not registered in `tools/check.py`, which cannot
claim emulator coverage. Start Android hosting through Play together, then run:

```sh
python3 tools/godot.py --headless --script res://tests/android_peer.gd -- \
  --join-code=CODE \
  --save-path=build/android-client-world.json \
  --profile-path=build/android-client-profile.json \
  --settings-path=build/android-client-settings.json
```

Use a test household with a clear tile at (0,0). The companion waits for accepted
snapshots, disables one resident's autonomy, enters construction, purchases that
floor tile, undoes it and finishes. Every command must be acknowledged and its
result must replicate. It leaves and reconnects twice, checking the same home,
resident identities and family count; success prints
`ANDROID_HOST_DESKTOP_CLIENT_PASS`. Add `--relay-only` to test the relay separately.

For the reverse direction, use fresh desktop paths and replace `--join-code=CODE`
with `--host-code-path=build/android-host-code.txt`. Join that code on Android,
perform at least two commands, leave, and repeat. The host checks accepted
commands, disconnect cleanup and stable identity/home across both joins, then
prints `DESKTOP_HOST_ANDROID_CLIENT_PASS`. On-device review must additionally
confirm that the phone displays replicated edits; a host acknowledgement alone
does not prove the receiving UI updated.

### Transport validation

- Rebuilt Android ARM64 and universal macOS extensions; Rust formatting and
  Clippy with warnings denied passed. Android APK export/signature verification
  and installation passed.
- First fixed Android host: initial snapshot in 1,004 ms; both reconnects in about
  one second. All three rounds acknowledged and replicated construction,
  purchase, Undo and Finish, with 5–6 snapshots per round and no duplicate family.
- A second fresh Android app process also passed all three rounds with the default
  transport; its first snapshot arrived in 1,002 ms (reconnects: 836 and 1,036 ms).
- A separate forced-relay desktop client passed all three rounds against the fixed
  Android host (`fixed-relay-client.log`). Default-transport success does not by
  itself measure which Iroh path was selected.
- Android client → fresh macOS host: two joins restored Willow House and the same
  identity. Actual Android taps purchased a §12 floor tile, displayed §11,988,
  undid it back to §12,000, and finished. Host logs confirmed all eight commands
  and both disconnects. Native Android captures were inspected.
- Full `python3 tools/check.py` exited 0 against the rebuilt desktop extension:
  142 gameplay/UI suites, both save-continuity processes, eight real desktop Iroh
  scenarios and dedicated-server smoke (`check.log`). Staged asset-storage and
  whitespace checks passed; no binary assets were added.
- Evidence remains ignored under `build/issue30-replication/`: baseline and
  diagnostic logs, `fixed-client.log`, `fixed-second-client.log`,
  `desktop-host.log`, build/export logs and `phone-*.png`. These files are local
  evidence, not required fresh-clone inputs.
- Physical Android, mobile-data/Wi-Fi transitions, background hosting, sustained
  performance/battery and other desktop runtimes remain untested. Hosted CI is
  separate from local build, regression and emulator results.

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
