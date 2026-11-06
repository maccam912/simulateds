# Crowded resident labels — issue #4 / POSE-07

This addresses the label and selection portion of
[issue #4](https://github.com/maccam912/simulateds/issues/4). The selected resident
gets first choice of label space, followed by other household need cues in stable
identity order. Optional chat/TV bubbles yield to those controls. Labels avoid
the visible HUD/trays and the projected bounds of actual posed bodies, including
children, sleeping and seated residents. A bounded search considers more nearby
positions in a crowd. Thin, noninteractive leaders connect names to heads; all
leaders draw behind all nameplates. The selected name has a brass border.

Ordinary content residents still have no extra label unless selected. Need cues
retain their existing care action, full hover name, ownership checks and queued
plan behavior. Only visible label rectangles add click targets. Menus,
construction and offscreen residents clear them as before. The renderer never
changes world positions, paths, reservations, plans, saves or needs.

POSE-07 remains partially addressed: this makes identity/selectable labels readable
when bodies cluster or furniture obscures a resident. It does not change physical
spacing, fade furniture/foliage, reveal hidden body geometry, or add idle-facing
behavior. Labels can be omitted when no clear space remains; the household roster
and Find resident remain available. Keep #4 open for those broader silhouette
questions and its other contact, transition, sleep and emotion findings.

## Reproduction and validation

`tests/resident_labels.gd` exercises eight adults/children/elders at the furnished
starter kitchen and entrance, on verified walkable cells, with simultaneous urgent needs, long names, day/night,
1440×900 and 1280×720/125% UI, the open Plan tray, a content selected child,
reduced motion, panning, offscreen cleanup, construction and menu suppression.
Assertions check label/body/HUD separation, label picking, deterministic paused
layout and unchanged authoritative snapshots. The crowded search also checks
complete occlusion and the absence of an invalid fallback rectangle.

The existing `tests/render_resident_cues.gd -- --compact` native review checks
actual input delivery, care queueing, double-click suppression, sleeping labels,
edge clipping, missing furnishings, construction and menu/offscreen cleanup.

Run against isolated scratch paths (never a player's save):

```sh
python3 tools/godot.py --log-file /tmp/resident-labels.log \
  --script res://tests/resident_labels.gd -- \
  --save-path=/tmp/resident-labels-save.json \
  --profile-path=/tmp/resident-labels-profile.json \
  --settings-path=/tmp/resident-labels-settings.json
python3 tools/check.py
```

Native macOS Godot 4.7.2/OpenGL Compatibility captures were inspected on Apple
M5 Pro, in the actual game camera at both sizes, daylight/night and reduced
motion. The first inspection caught leaders crossing other nameplates; the final
two-pass drawing fixes that. Both native review scripts pass. Local evidence is
ignored under `build/resident-labels-*.png`, `build/resident-cues-*-compact.png`
and `build/issue4-labels/`; regenerate it on a fresh clone.

All four final `tools/check.py --shard N/4` runs exited 0: 139 gameplay/UI suites,
both save-continuity processes, eight real Iroh scenarios and dedicated-server
smoke passed. Staged asset storage and whitespace checks passed. The ignored
`build/issue4-labels/validation.json` audits coverage. Hosted CI is separate.
No exports, physical-device play, human hardware playtest or frame-time benchmark
was performed. No models, binary assets, protocol or save schema changed.
