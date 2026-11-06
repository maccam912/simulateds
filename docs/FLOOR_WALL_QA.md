# Floor, wall and ceiling joins — November 5, 2026

## Diagnosis

Native screenshots of matching first- and second-floor architecture reproduce
three independent defects on `main` at `1293bd4`:

- A wall is 0.24 m thick and centered in its one-metre simulation cell. The floor
  covered the entire cell, leaving a 0.38 m flooring ledge beyond exterior walls.
  The flooring did reach underneath the walls; it was not too short.
- Lower-storey walls stopped at 2.2 m, while the next slab underside was at
  2.588 m. This left a 0.388 m horizontal opening beneath the upstairs floor.
  Windowed pieces stopped even lower, at 2.1 m.
- The invisible cutaway ceiling cast shadows only over interior cells at 2.48 m.
  It stopped short of perimeter wall cells and sat above their 2.1 m tops.
  The resulting bright strip also appeared on the first floor in daylight,
  making the floor/wall contact misleading.

## Correction

`game/lot_scene_3d.gd` is the editable procedural source. Floor substrates and all
finish patterns now clip exposed perimeter wall cells to their supporting wall
footprint. Joined corners, straight wall ends, mounted surfaces and door cells
share the existing wall-footprint convention. Bare floor/deck tiles and floors
continuing beyond a wall retain their area. Diagonal-wall tiles retain their
existing full supporting tile; polygonal diagonal floor clipping is not added.

The hidden ceiling reaches the perimeter wall faces and meets the window-wall
tops. Real window openings and open doors still admit daylight; ordinary wall
heights and the cutaway camera are unchanged. This is a shadow-only cutaway
ceiling, not a new roof-building system.

Lower-storey shells use the same joined corner footprint and meet the underside
of the next slab. Window headers extend to that height, and door headers start
at the actual frame top (2.11 m model plus 0.04 m placement offset). Lower floor
slabs use matching bounds and retain stair openings. Stairwell changes also
invalidate the architecture cache: adding stairs beneath an already-viewed
upper floor must rebuild its slab immediately.

All changes are presentation-only. Commands, floor occupancy, routes, saves,
furniture footprints and budgets are unchanged. No imported model or binary
asset changes; screenshots and logs stay in ignored `build/`.

## Reproduction and checks

Run with separate local save/profile/settings paths when other work is active:

```sh
python3 tools/godot.py --script res://tests/floor_wall_render.gd -- \
  --capture-tag=after --save-path=build/floor-review-save.json \
  --profile-path=build/floor-review-profile.json \
  --settings-path=build/floor-review-settings.json
python3 tools/check.py
```

The fixture deliberately duplicates the starter shell upstairs to compare the
same geometry. It is a test neighborhood, not a capture of a personal save.
Native assertions inspect actual floor box instances at wall faces, corners
and beyond exterior edges. Headless Godot discards MultiMesh transforms, so
that backend checks authored footprint bounds instead. Both check lower-wall
support, ceiling coverage and snapshot immutability; an accepted stair command
checks that the upstairs opening remains clear.

Reviewed captures: `build/floor-wall-floor{1,2}-{day,night}-{before,after}.png`,
`build/floor-wall-floor2-compact-{before,after}.png`, and the final stair view.
Native review uses macOS Apple M5 Pro, Godot 4.7.2, OpenGL Compatibility,
1440×900 and 1280×720/125% UI. The existing native `renderer_3d.gd` suite also
passes, including full/cutaway wall picking and unchanged joined corners.

The older optional `render_daylight.gd` stops at its single-pixel “Home stays
readable against the night lawn” assertion with both the changed renderer and
an isolated copy of the unchanged `main` renderer. This is a reproduced baseline
failure, not a passing daylight suite. Logs: `build/floor-daylight-native.log`
and `build/baseline-daylight-clean.log`. Day/night review for this fix uses the
matched fixture above and native images, not that failed assertion.

Full local regression results are recorded in `HANDOFF.md` after completion.
Hosted CI, exports and physical-device play are separate and have not been run
for this branch.
