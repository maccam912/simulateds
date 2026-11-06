# Starter interior light — issue #8 / WORLD-04

Review date: November 5, 2026. Addresses WORLD-04 from
[issue #8](https://github.com/maccam912/simulateds/issues/8). Keep that batch open
for its remaining orbit, shadow, outdoor, zoning and cutaway findings. WORLD-01
was addressed separately in `HOME_FRAMING_QA.md`.

## Decision and behavior

New neighborhoods include one existing Linen floor lamp at (4, 7), behind the
sofa, in each starter home. It is ordinary solid catalog furniture: it occupies
one floor tile, moves, recolors, sells for §57, and participates in Undo/Discard
and room designs. Starting funds remain §12,000. The starter home's existing
need activities and entrance remain reachable. The lamp provides no need bonus.

The existing shadow-casting fixture supplies the warm pool; its position, range,
energy and color still come from the catalog. The renderer gives the linen shade
a subtle emission matching its current fabric color, on a private material copy.
Imported source materials and other furniture remain unchanged. No new models,
textures, binary assets, save fields or network commands were introduced.

Matched native review favored the local source over changing the whole scene's
ambient balance. Cool night ambient, automatic home fill and daylight energy are
retained. The sitting area/window become a warm focal point, with the other
furniture and residents still readable. Low scenery retains the light. Daytime
shadows remain outside this change; this does not claim to resolve WORLD-03.

Loading an existing save never inserts a lamp, including in vacant homes or when
the player has deliberately sold one. Existing lamps receive the shade treatment.
Moving/selling updates the actual light; Undo restores it without stale pools.

## Reproduction and local evidence

`tests/starter_lighting.gd` is registered in `tools/check.py`. It covers all four
starter homes' access/budget, save round trips with and without lamps, render-only
state isolation, imported-material isolation, all six fabric colors, low scenery,
and accepted move/sell/Undo/Discard. Existing construction fixtures now account
for eleven furnishings and the additional §57 resale value.

Run with isolated files:

```sh
mkdir -p build/issue8-lighting
python3 tools/godot.py --script res://tests/starter_lighting.gd \
  --log-file build/issue8-lighting/native-engine.log -- \
  --save-path=build/issue8-lighting/native-save.json \
  --profile-path=build/issue8-lighting/native-profile.json \
  --settings-path=build/issue8-lighting/native-settings.json
```

Use `--headless` before `--script` for behavioral checks. Append `--compact`
after `--` for 1280×720 with 125% UI; normal review is 1440×900 with 100% UI.
The native runner captures the same camera at noon, dusk and midnight, with the
fixture light hidden and visible, plus low scenery, fabric colors and a move.
Images are ignored `build/starter-light-*.png`; they are reproducible local
artifacts rather than fresh-clone attachments.

Native macOS Godot 4.7.2/OpenGL Compatibility on Apple M5 Pro passed the normal
and compact runners. Matched day/dusk/night, low scenery and fabric color views
were visually inspected. This is renderer evidence, not a physical-device export
or a human family playtest. No frame-time benchmark was performed.

Aggregate results are recorded in `HANDOFF.md`; logs remain in ignored
`build/issue8-lighting/`. Hosted CI, exports and physical-device testing are
separate results.
