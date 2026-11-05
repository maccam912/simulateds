# Build & buy overhaul — November 4, 2026

- Residents stay visible and paused in construction. Neither placement validation
  nor mesh picking lets them obstruct an edit. The host moves displaced or
  disconnected residents to clear street-side space; Undo/redo also rechecks them.
- Shopping uses two-column photos rendered from the actual GLBs, icon categories
  (including all seating and lighting), search and prices. Drag a card to buy;
  Move allows dragging an existing object. Right-drag rotates pending furniture
  in quarter turns. The existing rotation button and keyboard controls remain.
- Added 17 original Blender models: five seats, six lights, five landscape pieces
  and stairs. The complete library has 47 models and 31 catalog furnishings.
  Six fixture types cast real local light/shadows. Windows have transparent panes,
  actual wall openings and daylight-scaled interior illumination. Nine floor and
  nine wall treatments include tiles, wallpaper and wainscoting.
- Build supports 45-degree walls/doorways, three storeys with separate occupancy,
  clear stair openings/landings, and explicit resident stair travel. Lower floors
  remain visible beneath the selected floor. Use floor −/+ to edit and ↓/↑ to
  direct a resident in live mode. Floor layouts share funds, revisions and history.
- Garden tools include pools, trees, hedges, flowers, fences, rocks and lighting;
  round raise/lower/flatten and grass/dirt/sand/gravel brushes follow pointer
  strokes. Foundations and the street remain protected. A complete 256-point
  stroke fits the unchanged 1,024-byte peer packet using bounded hex coordinates.
- World schema 3 and protocol 4 include explicit legacy-save migrations. New
  scenery, floors, light, thumbnails and cameras never mutate simulation state.
  Editable geometry/provenance lives in `tools/generate_models.py` and the model
  manifest. All new binaries match existing LFS attributes; nothing was staged.
- Current bounds: three floors; 45-degree walls; quarter-turn furnishings;
  terrain −0.75 to +1.5 tiles. Pools block walking but have no swimming activity.
  Stair travel approaches the landing and changes floors; authored climbing
  animation is not included. Existing 16×16 lot size remains.
- Preserved concurrent icon, rectangle-building, character-creator and release
  work. The old icon-checkpoint recoloring failure and server-shutdown leak are
  resolved: new furniture has color metadata, and servers never allocate the
  catalog thumbnail Node. The new drag test also caught/fixed source-card
  destruction during pickup.

# Detailed household creator checkpoint — November 4, 2026

- **Create a household** (main menu or More) now opens a dedicated, full-window
  3D dressing room. Large true-geometry residents breathe, glance and blink;
  rotate/zoom, full-body/face framing, daylight/evening and reduced motion work.
- Customize skin/hair/eyes, ten hairstyles, body and face proportions, pronouns,
  seven life stages, four synthesized voice timbres/pitch, three traits and
  likes/dislikes. Seven independent outfits combine tops/bottoms/shoes,
  accessories, colors and patterns. Explicitly choose the world outfit.
- Add residents up to eight and define family ties. Private drafts apply through
  one validated, revision-checked host command; bad/stale edits preserve the
  draft. Bounded multipart transport retains the 1024-byte packet limit. Current
  shared worktree protocol 4 / save schema 3 also includes concurrent storeys.
- Creator models are original editable runtime geometry in
  `game/character_model.gd`; voices are original synthesis in
  `game/character_voice.gd`. No binary assets were authored for this work.
  Existing GLBs remain legacy-save fallback. All other asset/build/icon changes
  in this shared worktree belong to concurrent work and were preserved.
- Deliberate limits: ages stay fixed; babies rest at home with comfortable needs
  in a bassinet, without active care simulation. Automatic event outfit changes,
  pregnancy, school/careers, moving out and deletion of established residents
  remain separate work. New draft residents can be removed before saving.
- Focused model/profile/UI/household/protocol/app checks pass. Native macOS
  1440×900 and 1280×720 at 125% UI scale pass, with studio and actual neighborhood
  day/night review. Evidence: `build/creator-focused-final.log`,
  `build/creator-final-acceptance.log`, `build/creator-native.log`,
  `build/creator-compact.log`, and `build/creator-*.png`.
- Real host + two clients each submitted eight-person profiles, rejected stale/
  invalid edits, reconnected and recovered saved family data:
  `build/creator-peer-final.log` and `build/creator_peer/`.
- Full regression overlapped concurrent work; follow the later recheck results
  recorded in `docs/VALIDATION.md`. Accumulated evidence covers 120/121 local
  suites and seven real-Iroh scenarios. Remaining failures: furniture-thumbnail
  drag in `build_overhaul_ui:72`, and dedicated-server resource cleanup at exit.
  Asset storage passes (81 hydrated LFS assets).
  Hosted CI, exports and physical-device play were not run for this change.

- Final local validation: all four `python3 tools/check.py --shard N/4` runs
  exit 0, covering all 121 gameplay/UI suites, eight real Iroh peer scenarios
  (including new upstairs/terrain/save/reconnect coverage), and dedicated-server
  smoke. No script/engine errors. Evidence: `build/build-overhaul-final-shard-*.log`
  and `build/build-overhaul-validation.json`. This supersedes the earlier full
  run's resolved shutdown failure; it is not a hosted-CI result.
- Native macOS Godot review passes in the actual camera at 1440×900 and 1280×720,
  daylight and night, including every new model, real catalog drag/drop,
  furniture dragging, rotation, wallpaper, windows, pool and two-floor rendering.
  Evidence: `build/build-overhaul-native.log` and `build/overhaul-*.png`.
  Model hashes/geometry/budgets, asset-storage checks and whitespace checks pass.
- Hosted CI, fresh exports and physical-device play were not run. Existing
  release/export evidence farther down this file predates this overhaul.

# Icon navigation checkpoint — November 4, 2026

- Main/pause menus and secondary household controls use icon grids. The stable
  bottom dock has build/finish, catalog/activities, and more icons. Needs,
  playback, plans, common context actions and building tools use pictograms.
  Names, prices, counts, detailed choices and destructive explanations remain.
- `game/ui_icons.gd` contains original editable SVG paths, cached runtime
  textures, accessible names and a safe fallback for new catalog entries.
  Navigation keeps 44px targets, keyboard activation, tooltips and focus hints.
  No binary assets were authored or staged for this UI work.
- Preserved concurrent catalog thumbnails and new categories; consolidated
  category navigation into the persistent icon selector to leave room for cards.
  Four explicit float annotations in the concurrently added character model/
  voice scripts unblock their compilation; no model or audio design was changed.
- Final headless icon, catalog, context-menu and plan-layout checks pass:
  `build/icons-last/*-complete.log`. The UI flow and affected activity UI suites
  pass in `build/icons-last/ui_flow.log` and `build/icons-rechecked/`.
- Native macOS normal 1440×900 and compact 1280×720 icon checks passed, with
  day/night inspection. Compact context gestures, care and plan notices also
  passed. Evidence: `build/icons-complete-*-engine.log`,
  `build/icons-reviewed-*.log`, `build/icons-care.log`, `build/icons-*.png`.
- Required `tools/check.py` was run; failed/remaining checks were resumed.
  Concurrent changes landed throughout validation, so this is **not** a clean
  full-suite result. Remaining observed failures: `tests/furniture_colors.gd:31`
  requires recoloring metadata for newly added furnishings; dedicated-server
  smoke reached ready but reported resources still in use at shutdown. Six real
  Iroh peer scenarios passed. See `build/icons-full-check.log`,
  `build/icons-remaining-checks.log`, and `build/icons-verify.log`; later targeted
  logs supersede their resolved icon, catalog, compilation and layout failures.
- Asset storage passes (81 hydrated LFS assets); scoped whitespace checks pass.
  Hosted CI, new exports and physical-device play were not run for this change.

# Rectangle building and wall corners checkpoint — November 4, 2026

- Build & buy accepts a drag for floor fill, wall perimeter, and Sell.
  Release applies the previewed edit in one Undo step. Wall drags keep doors.
  Sell clears every selected structure and any furnishing whose footprint
  intersects the rectangle. Existing single clicks still act on one tile or
  furnishing. Room and finish Area tools also accept a drag or two clicks.
- `game/build_area.gd` shares the floor/wall plan between preview and authority.
  `game/clear_lot.gd` shares quotes and painting protection with whole-lot
  clearing. Each area edit uses a revision-checked command and draft history.
- Wall geometry joins along both directions at corners, including the baseboard
  and cap. Picking follows the joined pieces. Existing windows and artwork keep
  their mounting face. The renderer test covers all four turns in normal,
  cutaway and raised-wall views.
- `tools/check.py` passed all local suites, six Iroh scenarios and the dedicated
  server smoke after the drag changes. The Iroh smoke exercises both area commands.
  Native captures at 1440×900 and 1280×720 are in `build/area-*.png` and
  `build/3d-*.png`. After the corner change, the renderer, area gestures,
  building access and impact, windows, wall art, and radial-menu checks passed.
  The broader rerun encountered unrelated HUD assertions during concurrent UI
  edits. See `build/area-check.log` and `build/corner-gameplay-current.log`.
- Hosted CI, exports, and physical device play were not run.

## Contextual UI checkpoint — November 4, 2026

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
