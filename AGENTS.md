# Simulateds contribution rules

Read `DESIGN.md` and `docs/DESIGN_LANGUAGE.md` before changing gameplay or visual
direction. For any 3D asset work, also read `docs/ASSET_GUIDE.md`. Keep the warm,
practical Linden Grove domestic theme and review models in the actual game
camera, daylight, night and compact window before claiming visual completion.

- World furniture, residents and scenery use true geometry. Keep UI portraits,
  icons, floor-plan thumbnails and paintings as appropriate 2D surfaces.
- Keep editable sources and provenance with asset outputs. Re-export through the
  documented pipeline; use licensed CC0 sources only when the actual source and
  license have been verified. Do not silently replace a model with a billboard.
- Track every committed binary asset through Git LFS. Read `docs/LFS.md`; run
  `python3 tools/check_assets.py` after staging. Never commit Godot caches or builds.
- Rendering, interpolation, camera and animations cannot mutate authoritative
  world state, saves, commands or pathfinding. Use existing command interfaces.
- Inspect `git status` first and preserve concurrent changes. Run relevant tests
  and `python3 tools/check.py` for changes to shared rendering/interaction paths.
  Inspect native renders as well; headless tests cannot establish visual quality.
- Report local tests, hosted CI, exports and physical device play as separate
  results. Keep a concise `HANDOFF.md` after major checkpoints.
