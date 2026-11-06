# House framing, shadows and cutaways (issue #8)

Review date: November 5, 2026. Every finding now has an implementation or an
explicit design disposition. This closes the QA batch's scope; deferred features
below are not claims of completed art or interaction work.

| Finding | Disposition |
| --- | --- |
| WORLD-01 | Implemented in PR #28: fresh entry fits the home, saved framing wins, Home overview changes only the camera, and Find resident preserves zoom while selecting the actual lot/floor. See [home framing QA](HOME_FRAMING_QA.md). Rechecked with this batch's normal/compact captures and regression suite. |
| WORLD-02 | Quarter-turn orbit is explicitly deferred. The current projection, screen-space feedback, cutaway classification and activity-facing review all assume one viewing direction. Adding orbit needs a coordinated four-view interaction pass; it is not a broken existing control. Retain pan, zoom, Home overview and Find resident. |
| WORLD-03 | Implemented here: fit the orthographic camera's far plane to the visible terrain with margin and use one directional shadow map. Matched native captures isolate the oversized camera depth as the main source of coarse wall/tree edges. No larger shadow texture, mesh replacement, bias increase or ambient recoloring. See diagnosis and measurements below. |
| WORLD-04 | Implemented in PR #29: movable starter linen lamp, preserved hues, existing night ambient balance, unchanged starting money and accessible needs. Existing saves are not refurnished. See [starter lighting QA](STARTER_LIGHTING_QA.md). Day/dusk/night and low scenery rechecked here. |
| WORLD-05 | Further planting/path/domestic-prop variation is explicitly deferred to a coordinated neighborhood content pass. Current trees already vary in scale/rotation; the repeated shrub and flower groups remain intentional placeholders. Keep boundaries and editable lawn clear. No claim that the repetition has been removed. |
| WORLD-06 | Starter bathroom/bedroom partitions and kitchen rezoning are explicitly deferred. Keep the current accessible teaching layout and player-owned saved layouts. A replacement plan should cover every need, two/eight residents, the tutorial, visitor entry and old/new saves together; this batch introduces no silent remodel. |
| WORLD-07 | Implemented here: near/interior doorway jambs end at the adjacent low cutaway wall, with an open threshold and no floating lintel/leaf. Rear doors and raised-wall construction tools retain the full original model. Hidden geometry retains its real shadows. Windows, artwork, furniture heights and resident picking remain intact. |

## Shadow diagnosis

The baseline was `71491bf`, macOS Apple M5 Pro, Godot 4.7.2/OpenGL Compatibility.
The camera had a 180 m far plane and two directional shadow splits for a 16 m
lot. The existing sun distance of 55 m does not bound an orthographic camera's
shadow volume; Godot documents that it uses the camera far plane instead.
See [DirectionalLight3D](https://docs.godotengine.org/en/stable/classes/class_directionallight3d.html)
and [upstream issue #58332](https://github.com/godotengine/godot/issues/58332).

A same-process diagnostic compared unchanged 180 m/two splits, 75 m/two splits,
and 75/90/180 m with one map. Reducing depth cleaned the edges without altering
models. One map further improves detail allocation in this fixed orthographic
view. The final camera uses the deepest visible ground at Y=-1 m (below allowed
terrain), shifted down by the viewed storey height, an 8 m margin, an eight-metre step and a 64 m minimum. It expands for
zooming out, panning and resizing instead of clipping the far edge to a fixed
short distance. Camera position, projection scale and picking rays are unchanged.
Desktop/mobile shadow texture sizes remain 4096/2048. Existing bias and light
colors are unchanged. Faceted canopy silhouettes remain actual geometry.

## Doorway source and regeneration

`game/lot_scene_3d.gd` is the original editable procedural source, under the
repository MIT license. It reuses the unmodified `door_frame.glb` for full doors
and hidden shadow casters, adding three solid boxes for the low jambs/threshold.
The shared rear-wall predicate keeps wall and doorway cutaways consistent.
Reopen the scene to regenerate; no Blender export, new external source or binary
asset is needed. Near doors are restored when editing walls, doors, windows or
wall art. Lower-storey shells retain full-height doors. No world data, money,
pathfinding, commands, save schema or network protocol changes.

## Reproduction

Use isolated paths, never a player's regular save:

```sh
python3 tools/godot.py --script res://tests/world_polish.gd -- \
  --benchmark --save-path=build/polish-save.json \
  --profile-path=build/polish-profile.json --settings-path=build/polish-settings.json
```

Add `--compact` after `--` for 1280×720/125% UI; default is 1440×900/100%.
The runner produces day/dusk/night, low scenery, wide zoom, full/cutaway Build
and rear/side/diagonal doorway captures. It checks terrain coverage across zoom
and pan on all three storeys, ground picking, doorway geometry and unchanged authoritative snapshots.
`--baseline` labels captures and skips new-door assertions when running the
unchanged baseline renderer; it does not turn production behavior off.

Ignored local evidence is `build/world-polish-{before,after}-*.png` and
`build/finish-qa/`. Captures/logs are local review artifacts, not fresh-clone
assets. The baseline/final runs use the same paused fresh household and camera.
Native visual inspection is separate from the headless assertions. Optional
uncapped measurements warm up 60 frames, then sample 180 frame intervals;
these are desktop observations, not GPU timings or mobile performance claims.

## Native measurements

Same machine, paused household, uncapped VSync-off sample; milliseconds per frame:

| View | Before median / p95 | After median / p95 |
| --- | --- | --- |
| 1440×900 day | 4.820 / 5.970 | 4.834 / 6.200 |
| 1440×900 night | 4.798 / 5.917 | 4.820 / 6.302 |
| 1280×720 day, 125% UI | 4.749 / 6.147 | 4.728 / 6.114 |
| 1280×720 night, 125% UI | 4.631 / 5.969 | 4.733 / 5.934 |
| 1280×720 night, low scenery | 4.310 / 5.549 | 4.266 / 5.738 |

Normal high-scenery engine-reported video memory was 73,392,003 → 73,394,235
bytes; static memory was about 75.51 → 75.56 MB. Reported draw calls were unchanged
at 1,223 (normal) / 1,228 (compact). These short samples show comparable desktop
cost, not a proven speedup or a physical Android result. Day/dusk/night images
show cleaner edges without new wall gaps, detached trunk contacts or changed
material/light colors. The full raised doorway and low near doorway were reviewed
in the actual camera, including compact and low-scenery views.

## Final validation

- Full `python3 tools/check.py` exited 0: 143 gameplay/UI suites, both
  save-continuity processes, eight real desktop Iroh scenarios and dedicated-server
  smoke. The final camera/storey adjustment also passed focused headless and
  native world-polish and floor/wall regressions, including all three floors.
- Native construction feedback (normal/compact), catalog/Move/right-drag,
  compact area dragging and creator rotation, renderer picking, windows,
  wall artwork and floor/wall suites passed. Captures were visually inspected.
- Staged asset-storage and whitespace checks passed; no binary assets changed.
- Full log and marker audit: ignored `build/finish-qa/check.log` and
  `validation.json`. Final focused logs use `final-*` and `upper-final-native.log`.
- Hosted CI is separate. No local exports, physical-device play, human hardware
  test, other-OS visual review or mobile performance measurements were performed.
