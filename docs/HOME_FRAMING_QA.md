# House framing — issue #8 / WORLD-01

Review date: November 5, 2026. This change addresses WORLD-01 only. Keep
[issue #8](https://github.com/maccam912/simulateds/issues/8) open for the separate
orbit, shadow, lighting, outdoor detail, starter zoning and cutaway reviews.

Fresh entry, and loaded worlds without camera metadata, fit the viewed home's
architectural footprint between the fixed location/clock and household HUD rows.
The calculation projects the floor/wall/door envelope through the actual camera,
allows room for full-height walls, and stays within the existing zoom limits.
Off-center and expanded homes use their actual layout; empty homes retain the
whole-lot fallback. Garden scenery and temporary resident positions do not drive
the fit. Optional trays may overlap the world as before.

More → **Home overview** replaces Center view. It selects the household's home
and ground floor, then fits the house. It preserves resident selection and sends
no travel, building or activity command. **Find resident** remains a one-time
camera focus on the selected resident's actual lot/floor and preserves zoom;
continuous following is not introduced. Both permit ordinary manual pan/zoom.
The Guide describes the distinction, and the overview button names its behavior
in its tooltip even with navigation labels disabled.

Existing saved framing takes priority over fitting. No save schema, authoritative
world fields, pathfinding, protocol, model, material or lighting changes are
included. Ordinary snapshots and manual resize do not continually refit the home.

## Reproduction and evidence

`tests/home_framing.gd`, registered in `tools/check.py`, covers fresh framing,
retained manual zoom/pan, stationary snapshot updates, the actual More/overview
button path, visiting upstairs residents, read-only world state, off-center and
full-lot footprints, empty-home fallback and ground picking. Existing camera and
save-continuity suites cover focus cancellation and real save/restart restoration.

Run with the repository's pinned engine and isolated paths, for example:

```sh
python3 tools/godot.py --log-file "$PWD/build/issue8/review-engine.log" \
  --script res://tests/home_framing.gd -- --compact \
  --save-path=build/issue8/review-save.json \
  --profile-path=build/issue8/review-profile.json \
  --settings-path=build/issue8/review-settings.json
```

Omit `--compact` for 1440×900/100% UI; compact uses 1280×720 and the 125% UI
setting with the game's canvas scaling. The runner captures matched old and new
framing at noon, dusk and midnight. Native macOS Godot 4.7.2/OpenGL Compatibility
on Apple M5 Pro was visually reviewed: the house and residents are larger, the
floor plan fits above the household controls, and the day/night appearance is
unchanged. Captures are ignored local `build/home-framing-*.png`; logs are in
`build/issue8/`. They are reproducible evidence, not fresh-clone attachments.

The required aggregate run found three input fixtures tied to the old default
camera: area dragging (also after simulated world replacement), far-lawn walking,
and multi-lot meal clicks. Those fixtures now choose an explicit whole-lot view.
The final shard runs cover all 137 gameplay/UI suites and both real save-continuity
processes, eight real Iroh peer scenarios and dedicated-server smoke. All four
final shards exited 0, with coverage recorded in `build/issue8/validation.json`.
The native compact area-drag check also passes. Earlier failed logs are
retained separately under `build/issue8/`.

Hosted CI, exports, physical Android/other-device play and human family playtests
are separate from this local review.
