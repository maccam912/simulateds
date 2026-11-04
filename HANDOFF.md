# Contextual UI checkpoint — November 4, 2026

- Live HUD now keeps compact location/clock, household selection, current action,
  mood, Plan, Needs toggle, and Build/More controls. More contains secondary
  household/world controls; care bars expand only on request.
- Right-click or hold touch for 0.5 seconds on furniture, residents, wall art or
  ground opens the contextual action wheel. Shift+F10/Menu opens the selected
  resident's choices. Actions use existing host commands, revalidate on selection,
  and retain the reviewed target/revision/batch. Opening/dismissing is read-only.
- `game/context_actions.gd` owns read-only choices; `game/radial_menu.gd` owns the
  wheel; `game/lot_view.gd` owns pointer gestures; `game/main.gd` connects them.
- New focused tests cover gestures, choice validity and actual HUD input. Existing
  UI tests now open More/Needs through actual mouse navigation using
  `tests/hud_navigation.gd`.
- Shower entry, couch seating while watching TV, and related physical interaction
  animation are **deferred**, recorded in `docs/ROADMAP.md` and
  `docs/DESIGN_LANGUAGE.md`. No model, animation, save or protocol change here.
- Local validation: all 114 registered gameplay/UI suites, six real Iroh peer
  scenarios and dedicated-server smoke passed. Required `tools/check.py` runs
  exposed two old test navigation/timing assumptions; these were corrected and
  the failed/remaining checks resumed successfully. Evidence:
  `build/radial-final-regression.log`, `build/radial-remaining-regression.log`,
  `build/context-validation.json`. Final session-lifetime changes separately pass
  `build/context_input-final.log` and `build/context_menu_ui-final.log`.
- Native macOS Godot 4.7.2 day/night renders at 1440×900 and compact 1280×720
  were inspected. Both native context-menu runs pass; images/logs are in
  `build/context-*`. Mouse, keyboard and simulated touch are covered.
- Asset-storage validation and `git diff --check` pass; no binary assets changed.
- Concurrent release-workflow and README edits appeared during validation; they
  were left untouched and are outside this UI checkpoint.
- Hosted CI, new exports and physical mobile testing were not run for this UI
  change. The prior export and renderer evidence below predates this checkpoint.

## Previous 3D renderer checkpoint — November 4, 2026

The default game now uses a real 3D scene with an orthographic isometric-style
camera. The tile simulation, command protocol, saves and gameplay rules were
retained. There is no second demo scene or opt-in renderer toggle.

## Where to continue

- `game/lot_scene_3d.gd`: imported models, batched architecture, scenery, lighting,
  resident poses/appearance, crops, food, art, recoloring and placement ghosts.
- `game/lot_projection.gd`: SubViewport/Camera3D, matching tile projection and
  cached triangle-BVH picking. Mesh picking respects physical occlusion.
- `game/ground_feedback_3d.gd`: depth-tested build/access/route ground geometry.
- `game/lot_view.gd`: existing HUD interaction, camera controls and screen labels.
- `tools/generate_models.py`, `assets/models/manifest.json`: editable Blender
  master and original model provenance. All 14 furnishings are covered by the
  30-model library. `docs/ASSET_GUIDE.md` is the art contract.
- `tools/check_models.py`: hashes, embedded GLB geometry, catalog footprints,
  bounds, pivots, appearance materials and budgets; invoked by `tools/check.py`.
- `docs/LFS.md`: binary storage, clone recovery and contribution instructions.
  `tools/check_assets.py` checks LFS coverage, staging and hydration in CI.

## Evidence and boundaries

The complete `python3 tools/check.py` run exits 0: 111 local gameplay/UI suites,
six real Iroh scenarios and dedicated-server smoke (118 pass markers), with no
engine errors. Evidence: `build/3d-final-regression.log`. Model-library validation
passes separately. Forced-relay/code-service behavior was not rerun.

Native `renderer_3d`, application screens and activity renders pass on Apple
M5 Pro with Godot 4.7.2/OpenGL Compatibility. Day/night, construction, placement,
compact 1280×720 and normal 1440×900 captures were visually inspected. Updated
`docs/preview.png` and `docs/construction.png` show actual game renders; the asset
gallery is a separate Blender studio render.

The macOS package passes universal ARM64/Intel signature/plist checks, native
Iroh startup, all 30 packaged model mappings and a 120-frame exported GUI smoke
on Apple Silicon. It is development/ad-hoc signed, not notarized. Local artifact:
`build/artifacts/simulateds-macos.zip`, SHA-256
`b5a5a812506ef5018df8bc3a5936d7834e8af120f65e793d84956a8a8a61a4b7`.
`build/macos-3d-pack-audit.json` and `build/macos-3d-game-smoke.log` retain evidence.

Physical Android, Intel runtime, Windows/Linux rendering and human family play
remain unverified for this renderer. Hosted CI is a separate check. The current
camera remains fixed in isometric orientation; ordinary pan/zoom/find work.
Movement and construction remain tile-based. Resident animation uses articulated
model parts; richer authored skeletal animation and handheld activity props are
future polish. Do not describe those as completed.

## LFS rewrite and recovery

71 commits were migrated and audited; all 33 historical raw binary versions
preserve their original bytes and all 75 historical LFS objects verify. Audit
and commit-map records are in `docs/lfs-migration/`. The old remote main was
`a1e8fba57e5a68d6f7ba8772ee10410acf82d0b8`. Clone fresh with Git LFS after the
rewrite; do not merge old history into the new main.

Local recovery directory (not committed or required to build):
`/Users/maccam912/dev/simulateds-lfs-backup-20261104T221928Z/`.
It contains the original bundle, the bundle including the 3D work, LFS bytes,
remote-ref snapshots, original binary hashes and the migration audit/map.
