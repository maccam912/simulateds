# Window preservation and release icons — November 6, 2026

- Issues #39/#40: creating neighborhoods and changing unrelated settings preserve
  native window size/position/maximize/fullscreen. SVG icon rasterization now runs
  outside assertions, so release templates produce the same icons as the editor.
- Added a registered window/creation regression, multi-size icon checks, and a
  required icon check in the exported native-runtime smoke. No binary assets,
  authoritative simulation, save schema or protocol changes.
- Original window failure reproduced against isolated baseline code. Fixed native
  window and compact icon suites passed on macOS/Apple Silicon; day/night/compact
  captures were inspected. Local macOS ZIP export, strict ad-hoc signing and
  release-native/icon smoke passed. Direct extracted-app UI review confirmed
  menu/guide icons and maximization retained after neighborhood creation.
- Full `python3 tools/check.py` exited 0: 144 gameplay/UI suites, both save
  continuity processes, eight real Iroh scenarios and dedicated-server smoke.
  Staged asset-storage and whitespace checks pass. Hosted CI is separate.
  No physical-device or other-platform UI playtest and no published release.
  Reproduction and evidence:
  `docs/RELEASE_UI_QA.md`; ignored `build/issues-39-40/`.

# World/build QA completion — November 5, 2026

- Issues #8 and #6 now have complete finding dispositions in
  `docs/WORLD_POLISH_QA.md` and `docs/BUILD_CATALOG_QA.md`. This supersedes the
  earlier keep-open notes below. Orbit, extra outdoor content and starter-room
  rezoning are explicitly deferred; the user explicitly deferred BUILD-10's
  human mouse/trackpad test. Automated native input is not physical verification.
- The orthographic shadow volume follows visible terrain, pan/zoom and all three
  storeys instead of a fixed 180 m range. Near/interior doorways meet low cutaway
  walls; rear/raised frames and hidden shadows remain. No binary assets, authority,
  commands, paths, save schema or protocol changed. Source/reproduction and
  matched native day/dusk/night/compact measurements are in the world QA document.
- Full `python3 tools/check.py` exited 0: 143 gameplay/UI suites, both save
  continuity processes, eight real Iroh scenarios and dedicated-server smoke.
  Final camera/storey refinements passed focused headless/native regressions.
  Native construction gestures, compact catalog, renderer, windows, artwork and
  floor/wall checks passed; staged asset-storage and whitespace checks passed.
  Local evidence: ignored `build/finish-qa/` and `build/world-polish-*.png`.
- Hosted CI remains separate; no local exports, physical-device play or human
  hardware test. Review branch: `codex/finish-world-build-qa`.
- Cleanup verified every local topic tip against a merged PR, removed 22 merged
  branches and two clean extra worktrees, and updated local main to `71491bf`.
  Recovery bundle and archived worktree evidence (excluding Godot caches) are in
  `../simulateds-cleanup-backups/20261105-222827/`. Remote topics were already
  deleted; stale tracking refs were pruned.

# Android first-connection replication — November 5, 2026

- Issue #30 networking follow-up: a fresh Android host sent its welcome but no
  snapshot chunks reached the client. Three baseline attempts timed out; a later
  connection and a forced-relay control worked. This matches the pinned Iroh
  1.4.1 GSO fallback problem documented in upstream issue #4555.
- Both native host/client endpoints now share a builder that disables QUIC
  segmentation offload on Android. Desktop defaults, direct discovery, relay
  fallback, protocol, validation and authority are preserved. No binary assets
  or dependencies changed. Revisit after the upstream fix reaches our pin.
- Rebuilt ARM64 Android/universal macOS libraries; Rust fmt and Clippy passed.
  Development APK export, signature verification and installation passed.
  Two fresh Android app processes each passed their first connection plus two
  reconnects, with accepted snapshots and acknowledged/replicated purchase,
  Undo and Finish. A separate forced-relay run passed. Android also joined a
  desktop host twice, performed the edits through actual emulator touch input,
  and retained its family/home. Native phone captures were inspected.
- `tests/android_peer.gd` provides the repeatable desktop companion in both
  directions; it requires isolated paths and a running APK, so is intentionally
  outside `tools/check.py`. Reproduction and evidence boundaries are in
  `docs/ANDROID_QA.md`; local logs/captures are ignored under
  `build/issue30-replication/`.
- Full `python3 tools/check.py` exited 0: all 142 gameplay/UI suites, both
  save-continuity processes, eight real desktop Iroh scenarios and dedicated-server
  smoke passed. Staged asset-storage and whitespace checks passed.
- Physical phones, Wi-Fi/mobile-data transitions, background hosting, throughput
  and battery cost remain untested. Hosted CI is separate from local checks.

# Android emulator playtest — November 5, 2026

- Issue #30: played the ARM64 APK on an isolated Pixel 7 Android 15 emulator.
  Fixed Back exiting the app, missing touch zoom, duplicate creator rotation,
  nonimmersive mobile preferences and landscape keyboards covering text inputs.
  Mobile defaults to 125% UI scale; existing scale preferences are preserved.
- Keyboard avoidance moves only the active UI layer and restores it on dismissal.
  Back reuses the existing draft/tray/menu priority. No authority, save schema,
  network protocol, model or binary asset changes. Touch instructions are in the
  Controls guide and the contract is in `docs/DESIGN_LANGUAGE.md`.
- `docs/ANDROID_QA.md` records device/build, concrete playtest results, reproduction
  and limits. Native day/night and compact 1280×720/125% captures were inspected.
  Android APK export, signature verification, installation, solo play, building,
  named save/load, restart and text entry passed. No physical-device play.
- `tests/android_navigation.gd` covers Back priority, dirty-draft protection,
  focused fields, bounded zoom, duplicate touch/mouse rotation and stable keyboard
  offsets without changing world snapshots or camera framing. Local evidence is
  ignored `build/issue30/` and `build/android-navigation-*.png`.
- Full `python3 tools/check.py` exited 0: 142 gameplay/UI suites, both
  save-continuity processes, eight real desktop Iroh scenarios and dedicated-server
  smoke. The final keyboard-coordinate adjustment also passed focused navigation,
  creator, catalog and app-flow regressions plus native review. Staged asset and
  whitespace checks pass. Hosted CI is separate from these local results.
- Follow-up: Android room-code creation/desktop handshake succeeded, but the
  desktop probe timed out awaiting accepted snapshots from the Android host.
  An immediate rejoin also once reported an already-connected family. Root cause
  remains open; desktop Iroh test success does not establish Android replication.

# Legacy starter television — November 5, 2026

- Issue #33: old starter homes had a TV facing the south wall. Disk loading now
  turns it toward the sofa only when the original ten-object layout, architecture,
  terrain and revision 0 prove the home is untouched. Vacant homes are included.
  Edited homes remain unchanged; rejection explains turning the TV in Build.
- The repair follows validation/number normalization, changes only TV rotation
  and lot revision, and is idempotent. Network snapshots never run it. No schema,
  protocol, model or binary asset changes. Details: `docs/TELEVISION_QA.md`.
- `tests/starter_television.gd` reproduces rejection, verifies actual two-resident
  viewing, persistence, replication, earlier schemas, preservation guards and
  the ordinary Build workaround. The full `python3 tools/check.py` exited 0:
  141 gameplay/UI suites, both save-continuity processes, eight real Iroh
  scenarios and dedicated-server smoke. Final guard/test additions also pass
  the focused regression. Logs and coverage audit: ignored `build/issue33/`.
- Native macOS Godot 4.7.2/OpenGL review passed at 1440×900 and 1280×720/125% UI,
  daylight/night, using the restored old home. Reproduce with the existing
  `tests/television_pose.gd` runner and `--legacy-starter` after `--`, with isolated
  save/profile/settings paths. Captures: ignored `build/tv-legacy-*.png`.
- Asset-storage and whitespace checks pass. Hosted CI is separate; no local
  exports, physical-device play or human hardware playtest was performed.

# Seating occupancy — November 5, 2026

- Issue #32: sofas, armchairs, loveseats, long sofas, wooden chairs and garden
  benches reserve the whole furnishing during approach and use. A second
  deliberate user waits with the occupant's name; autonomy skips the busy seat.
  Ordinary relaxation and TV viewing share the existing host reservation rules.
  Cancellation, completion, travel, construction and disconnect release use.
- Independent cushion capacity remains deferred. This fixes shared-furnishing
  occupancy, not general walking collisions. No model, binary asset, command or
  save-schema change. Old overlapping solo activities are revalidated on load;
  one stops with the existing interruption notice and Recent entry.
- `tests/seat_occupancy.gd` reproduces the original failure and covers all six
  seat kinds/four rotations, waiting benefits, release, TV use in both orders,
  visitors, snapshots and continuation. Native macOS Godot 4.7.2/OpenGL review
  passed at 1440×900 and 1280×720/125% UI, day/night: one seated resident, a
  separate waiting resident and readable status. Rendering preserves state.
  Reproduce with `tools/godot.py --script res://tests/seat_occupancy.gd`, isolated
  save/profile/settings paths, and optional `--compact` after `--`.
- The full `python3 tools/check.py` exited 0: all 140 gameplay/UI suites, both
  save-continuity processes, eight real Iroh scenarios and dedicated-server
  smoke passed. Native logs, full local log and coverage audit: ignored
  `build/issue32/`; captures: `build/seat-occupancy-*.png`.
  Staged asset storage and whitespace checks pass.
- Hosted CI is separate; no local exports, physical-device play or human
  hardware playtest was performed.

# Crowded resident labels — November 5, 2026

- Issue #4 / POSE-07, label/selection scope: selected names get first choice of
  space; other need labels use stable identity order. Labels avoid posed bodies
  and HUD/trays. Noninteractive leaders draw behind all nameplates. Existing
  care/selection commands, world positions, paths and saves are unchanged.
- Native macOS Godot 4.7.2/OpenGL review passed at 1440×900 and compact
  1280×720/125% UI, day/night, eight residents on verified walkable cells, long
  names, Plan, selected children and reduced motion. Existing native cue input,
  queueing, double-click, sleeping and cleanup regression also passed. Scope and
  reproduction: `docs/RESIDENT_LABELS_QA.md`. Captures/logs are ignored under
  `build/resident-labels-*.png`, `build/resident-cues-*-compact.png` and
  `build/issue4-labels/`.
- All four final `tools/check.py --shard N/4` runs exited 0: 139 gameplay/UI
  suites, both save-continuity processes, eight real Iroh scenarios and dedicated
  server smoke passed. Audit: `build/issue4-labels/validation.json`. Staged asset
  storage and whitespace checks passed.
- Keep #4 open: body spacing, furniture/foliage occlusion and other activity
  findings remain. No models or binary assets changed. Hosted CI is separate;
  no exports, physical-device play, human hardware playtest or frame-time
  benchmarks were performed.

# Starter interior light — November 5, 2026

- Issue #8 / WORLD-04: new starter homes include the existing Linen floor lamp
  beside the sofa with unchanged §12,000 funds and reachable care furnishings.
  Existing saves are never refurnished. The actual movable fixture supplies the
  warm local pool; ambient balance stays unchanged. Its shade has a restrained,
  color-preserving glow on an instance-local material. No binary assets changed.
- Native macOS Godot 4.7.2/OpenGL review passed at 1440×900 and 1280×720/125% UI,
  matched day/dusk/night, low scenery, fabric colors and fixture movement. Tests
  cover old/new save layouts, read-only rendering, source-material isolation,
  move/sell/Undo/Discard. Scope/reproduction: `docs/STARTER_LIGHTING_QA.md`.
- All four final `tools/check.py --shard N/4` runs exited 0: 138 gameplay/UI
  suites, both save-continuity processes, eight real Iroh scenarios and dedicated
  server smoke. Earlier failures exposed starter-count/refund assumptions, a
  decorative-item access oracle and an overlapping pantry fixture; final reruns
  supersede them. Audit/logs: ignored `build/issue8-lighting/validation.json` and
  its four named logs. Native captures: ignored `build/starter-light-*.png`.
- Staged asset storage (81 hydrated LFS assets) and whitespace checks pass.
  Keep #8 open for its remaining findings. Hosted CI is separate; exports,
  physical-device and human family playtests, and frame-time benchmarks were not
  performed.

# Home overview — November 5, 2026

- Issue #8 / WORLD-01: fresh entry and loads without camera metadata fit the
  home's architectural footprint. More → Home overview returns the camera to the
  home ground floor without moving residents. Find resident preserves zoom and
  resolves the resident's actual lot/floor; existing saved zoom/pan takes priority.
- Native macOS Godot 4.7.2/OpenGL review passed at 1440×900 and compact
  1280×720/125% UI, with matched noon/dusk/night views and the labeled More action.
  New regression coverage checks read-only overview, saved framing, visiting
  upstairs residents, off-center/full-lot homes, empty homes and ground picking.
  Compact native area dragging also passes. Evidence: ignored
  `build/home-framing-*.png`, `build/issue8/native.log`, `compact.log`, `area-native.log`.
- The required aggregate run exposed three input fixtures that assumed the old
  fixed camera. Area dragging (including simulated world replacement), lawn
  walking and multi-lot meals now choose an explicit whole-lot view. All 137
  gameplay/UI suites, both save-continuity processes, eight real Iroh scenarios
  and dedicated-server smoke passed; all four final shards exited 0. Audit:
  `build/issue8/validation.json`. Staged asset-storage and whitespace checks pass.
- Scope and reproduction: `docs/HOME_FRAMING_QA.md`. Keep issue #8 open for its
  other findings. No models, binary assets, save schema or protocol changed.
  Hosted CI is separate; exports, physical-device and human family playtests
  were not performed.

# Optional daily rhythm — November 5, 2026

- Issue #9: Plan offers a time-of-day review of an existing saved routine. It
  follows edited steps/names, preserves private drafts, and displays unavailable
  recipes without issuing an order. Add to plan remains the explicit host command.
  Automatic Plan rows name matching favorites, traits and likes/dislikes.
- Twelve full-day observations cover 2/3/8 residents with autonomy on/off, one
  chosen evening routine, and absence. Final measurements exactly match the
  baseline; simulation, need decay, rewards, saves and protocol are unchanged.
  Scope, measurements, reproduction and all five finding dispositions are in
  `docs/DAILY_RHYTHM_QA.md`. Scheduling, budget scenarios, new family interactions
  and a combined daily recap are explicitly deferred.
- Native macOS Godot 4.7.2/OpenGL review passed in the actual camera, day/night,
  1440×900 and 1280×720/125% UI. Focused headless and native tests pass; the full
  `python3 tools/check.py` exited 0: all 136 gameplay/UI suites, both save-continuity
  processes, eight real Iroh scenarios and dedicated-server smoke passed.
  Logs, measured JSON, captures and `validation.json` are ignored under
  `build/issue9/`. Final focused headless/native checks cover the helper cleanup.
- Staged asset storage (81 hydrated LFS assets) and whitespace checks pass.
- Hosted CI is separate. No exports, physical-device or human family playtests
  were performed. No models or binary assets changed.

# Painting contact — November 5, 2026

- Issue #4 / POSE-04, easel scope: the host routes painting/packing to the clear
  canvas side. Blocked approaches explain the required space; construction
  diagnosis and catalog copy agree. Legacy active side approaches reroute before
  adding work, preserving the original canvas. No save/protocol fields changed.
- Arrived painters hold a solid brush at the canvas. Height-aware oak steps
  support shorter residents without rescaling bodies; feet remain still through
  strokes. Paused/reduced-motion poses are steady, and cancellation/completion,
  packing, construction and stale targets clear props. Picking/labels follow the
  body; render updates preserve authoritative state. Original editable source:
  `game/painting_pose.gd`; no binary assets. Keep issue #4 open for its other work.
- Native macOS Godot 4.7.2/OpenGL review passed at 1440×900 and 1280×720/125%,
  all four rotations, varied ages/builds, every playable age's height endpoints,
  daylight/night, low scenery and furnished starter-home painting. Captures:
  ignored `build/painting-*.png`; log: `build/issue4-painting/native.log`.
- All four `python3 tools/check.py --shard N/4` runs exited 0: 135 gameplay/UI
  suites, both save-continuity processes, eight real Iroh peer scenarios and
  dedicated-server smoke. Audit/logs: `build/issue4-painting/validation.json` and
  `shard-*.log`. The initial run caught a second commission easel facing into
  the tea table; that fixture now faces its clear side. Exact-progress painting
  assertions begin at the proper front cell. The clean rerun supersedes that run.
- Staged asset storage (81 hydrated LFS assets) and whitespace checks pass.
  Preserved concurrent MCP documentation and incorporated its published main
  commit `6acdc68`. Hosted CI is separate; no local exports, physical-device or
  human family playtests were performed. Scope and reproduction:
  `docs/PAINTING_CONTACT_QA.md`.

# MCP design — November 5, 2026

- Added `docs/MCP_SERVER_DESIGN.md` and a README link. Proposal covers a managed
  MCP companion, local/remote access, command receipts, permissions, screenshots,
  construction ownership and implementation/validation stages. No runtime code.
- Rechecked headless rendering: local Godot 4.7.2 help lists only the dummy
  renderer for `headless`; upstream source agrees. Linux Xvfb plus Mesa is a
  proposed no-monitor rendering route, not yet tested for this game. Native
  offscreen support remains an upstream proposal/draft at review time.
- Documentation whitespace and local reference checks passed. No gameplay tests,
  native renders, hosted CI, exports or physical-device checks run for this work.

# Activity clarity — November 5, 2026

- Issue #10: wish cards preview the actor, activity/target, queue commitment,
  free cost and game-time bound. The host shares the suggestion logic and
  rejects a changed reviewed target. Meal wishes identify navigation-only
  actions. Existing wish rewards and deliberate plan priority remain.
- Garden status shows conditional game-time readiness, dry stops and pause.
  Meals name current diners with queued/walking/waiting/eating status and
  distinguish available, reserved and taken portions without consuming food.
- Easel/commission/hobby/guide/routine copy supports larger households and
  preserves painting eligibility. Art locations use furnishing/collection names,
  optional coordinates and camera-only Find. Delivery shows a recipient note
  and original artist credit, keeping exact-original removal/payment checks.
- All ten dispositions: `docs/ACTIVITY_CLARITY_QA.md`. Personal wish reactions,
  multi-bed tending, serving choreography and artist/stage visual variants are
  explicitly deferred. No model, binary asset, save-schema or protocol change.
- Native macOS Godot 4.7.2/OpenGL review passed at 1440×900 and 1280×720/125%,
  day/night, dry/paused/watered crops, three staggered diners and compact art
  review/delivery. Native compact pantry and meal-wish loops also passed.
  Logs: ignored `build/issue10/native.log`, `native-reviews.log`; captures:
  `build/activity-clarity-*.png`, `commissions-*.png`, `pantry-*.png` and
  `meal-wishes-*.png`. New UI review is registered in `tools/check.py`.
- Full local `python3 tools/check.py` exited 0: all 133 gameplay/UI suites,
  both save-continuity processes, eight real Iroh peer scenarios and dedicated
  server smoke. Logs/audit: ignored `build/issue10/check.log`, `validation.json`.
  Staged asset storage and whitespace checks pass (81 hydrated LFS assets).
- Hosted CI is separate. Exports, physical-device and human playtests were not
  performed for this change.

# Floor and wall joins — November 5, 2026

- Isolated branch `codex/floor-wall-shadow-review`, based on `main` at `1293bd4`.
  Worktree: `/private/tmp/simulateds-floor-wall-shadow-review`. Parallel TV work
  in the original checkout was not edited or staged by this task.
- Confirmed in matched native day renders: floors reached the walls but extended
  0.38 m beyond exterior faces; lower walls stopped 0.388 m below the upper slab;
  an undersized/high hidden ceiling caused the first-floor daylight stripe too.
- Renderer clips exterior wall-cell floors/finishes to wall footprints, extends
  lower shells/headers to the next slab, shares joined corners and closes ceiling
  shadow seams. Decks and diagonal support tiles retain their existing bounds.
  Stairwell changes invalidate the render cache, preserving newly added openings.
  Commands, world state, navigation and saves are unchanged. No binary assets.
- Native macOS Godot 4.7.2/OpenGL review covers matched first/second floors,
  day/night, 1440×900 and compact 1280×720/125%, plus an accepted stair placement.
  Final focused native/headless runs pass: `build/floor-wall-final3-native.log`,
  `build/floor-wall-final-headless.log`. Existing native renderer suite passes:
  `build/floor-renderer-native.log`. Screenshots stay in ignored `build/floor-wall-*`.
- Full local `python3 tools/check.py` exited 0: 130 gameplay/UI suites, both
  save-continuity processes, eight real Iroh scenarios and dedicated-server smoke.
  Evidence: `build/floor-wall-check.log`. Final cache/header changes also passed
  focused native/headless floor, renderer and storey UI checks. Staged asset and
  whitespace checks pass (81 hydrated LFS assets).
- Optional legacy daylight pixel assertion fails on both this branch and the
  unchanged main renderer; see `docs/FLOOR_WALL_QA.md` and
  `build/baseline-daylight-clean.log`. Do not describe that suite as passing.
- Hosted CI, exports and physical-device play were not run for this change.
- PR #24 integration: merged `main` at `cb56697`, preserving the TV checkpoint
  and both sets of registered tests. Seven focused headless suites and the native
  floor review pass after resolution (`build/floor-wall-merge-check.log`,
  `build/merge-floor-native.log`). The full-suite results above precede this merge.

# Television seating — November 5, 2026

- Issue #4 / POSE-01: the host chooses an available screen-facing seat and
  reserves it while walking/watching, or selects a distinct standing place.
  Ordinary seat use waits for the viewer. The existing activity strip names
  Seated/Standing; no clear front place rejects without changing plans.
- Cancellation, completion, travel, construction and disconnect release the
  task reservation. Optional snapshot/save fields validate and normalize;
  solo continuation revalidates the route and place. New starter TVs face their
  sofa. Existing saved furniture and legacy active TV routes are preserved.
- The renderer poses arrived viewers on existing cushions/slats with bent knees,
  following the host's choice. Native picking and labels follow the visible body.
  No binary/model geometry changes; no rendering writes to world state.
- Native macOS Godot 4.7.2/OpenGL review passed at normal/compact sizes, starter
  day/night, six seating models through four rotations, adult/child/elder/body
  variations and frontal child contact checks. Evidence: ignored `build/tv-*.png`
  and `build/issue4-tv/native-final.log`. Focused authority tests pass.
- All 131 local gameplay/UI suites and both save-continuity processes passed
  across `tools/check.py` and resumed checks. The existing facing/timing fixtures
  now use the accepted TV destination. All eight real Iroh peer scenarios and
  dedicated-server smoke also pass. Staged LFS/whitespace audits pass. Local logs
  and the coverage audit are in ignored `build/issue4-tv/` (`check.log`,
  `resumed.log`, `resumed-final.log`, `validation.json`).
- Keep issue #4 open. Each furnishing currently seats one TV viewer; cushion
  capacity, shared-TV social rewards and entry/exit choreography remain separate.
  See `docs/TELEVISION_QA.md`. Hosted CI, exports and physical-device play are
  separate; no exports or physical-device/human playtests were run here.

# Shared dining places — November 5, 2026

- Issue #4 / POSE-03: arrived diners sit at their accepted places, face the
  table edge and reach individual plates. Child-height stools/footrests and
  articulated knees support the unchanged body proportions. Props follow the
  consumed portion, remain after the platter empties, and clear on cancellation,
  completion, construction or stale targets. Simulation and save rules are unchanged.
- Original editable geometry lives in `game/dining_pose.gd` and
  `game/character_model.gd`; no binary assets or external sources. Character
  triangle counts stay at 32,268 studio / 12,732 world, with two extra knee
  mesh groups. Each dining stool/plate is batched to two groups.
- Keep issue #4 open. Other findings, general child contact, garment draping and
  entry/exit choreography remain separate; see `docs/DINING_QA.md`.
- Native macOS Godot 4.7.2/OpenGL review passed: four body profiles through four
  table rotations, adjacent diners, mesh picking, day/night, 1440×900 and
  1280×720/125% UI, low scenery and a closer view. Existing activity renders pass.
  Evidence: ignored `build/dining-*.png`, `build/issue4-dining/native.log`,
  `activities.log`. Final focused assertions include the batched props.
- Local `python3 tools/check.py` exited 0: all 129 gameplay/UI suites, both
  save-continuity processes, eight real Iroh scenarios and dedicated-server smoke.
  Final native dining checks also pass after prop batching. Logs/audit: ignored
  `build/issue4-dining/check.log` and `validation.json`.
- Staged asset-storage and whitespace checks pass. Hosted CI is separate and
  unverified at this checkpoint. No exports, physical-device or human playtests.

# Shower occupancy — November 5, 2026

- Focused issue #4 / POSE-02 fix: visible occupants stand inside the tray, face
  the mixer and remain selectable through an active cutaway enclosure. Sparse
  water and arm motion follow simulation time; reduced motion is steady.
- Rendering and the shower label anchor only: approach cells, reservations,
  pathfinding, task timing, commands and saves are unchanged. No binary assets.
  Cancellation/completion/building/missing targets clear the presentation.
- Issue #4 remains open. POSE-02 entry/exit choreography and the other seven
  findings remain pending; scope and reproduction are in `docs/SHOWER_QA.md`.
- Local `python3 tools/check.py` exited 0: 128 gameplay/UI suites, both save
  continuity processes, eight real Iroh scenarios and dedicated-server smoke.
  Final focused headless and native shower checks also passed. Logs/audit:
  ignored `build/issue4/check.log`, `final-focused.log`, `validation.json`.
- Native macOS Godot 4.7.2/OpenGL review passed: four body profiles × four
  rotations, actual camera, day/night, 1440×900 and 1280×720/125% UI, and the
  furnished starter-house activity review. Captures: `build/shower-*.png`,
  `build/activities-*.png`; logs: `build/issue4/native-final.log`, `activities.log`.
  The older review fixture now clears interpolation after direct relocation.
- Staged asset-storage and whitespace checks pass. Hosted CI is separate and
  unverified at this checkpoint. No exports, physical-device or human playtests.

# Household creator safety and usability — November 5, 2026

- Issue #5: dirty drafts now require explicit discard; Keep editing and Escape
  retain all choices. Clean cancellation stays direct. Pending/rejected saves
  and session changes preserve the existing authoritative boundaries.
- Named family rows disable invalid choices using the host's whole-family
  validator, explain age constraints and show relationship direction. Host Save
  still rejects invalid drafts atomically, including ties invalidated by age edits.
- Hair/clothing have previous/next browsing; sections reset front framing;
  Front / reset and zoom controls stay visible. Full-body framing is tighter.
  Entry titles, unsaved state, actual trait effects and household trait summaries
  clarify the draft. No model, binary asset, save or protocol changes.
- All 12 dispositions are in `docs/CREATOR_QA.md`. Cast defaults, stage proportions,
  hair/sleeve refinements and facial variants are explicitly deferred art work.
- Local `python3 tools/check.py` exited 0: all 127 gameplay/UI suites, both
  save-continuity processes, eight real Iroh scenarios and dedicated-server smoke.
  Final focused creator/app/household checks also passed. Logs and coverage audit:
  ignored `build/issue5/check.log`, `final-focused.log`, `validation.json`.
- Native macOS Godot 4.7.2/OpenGL review passed at 1440×900 and 1280×720 with
  125% UI, studio daylight/evening and actual gameplay day/night. Pointer controls,
  Escape recovery, family warnings, child/infant/elder framing and outfit browsing
  passed. Captures: ignored `build/creator-*.png`; logs: `build/issue5/final-*.log`.
- Staged asset-storage and whitespace checks pass. Hosted CI is separate and
  unverified at this checkpoint. No local exports, physical-device tests or
  human playtest were performed.

# Construction catalog and feedback — November 5, 2026

- Issue #6: BUILD-01–09 implemented; BUILD-10's human mouse/trackpad drag
  verification remains outstanding. Keep the issue open. Full dispositions and
  reproducible checks: `docs/BUILD_CATALOG_QA.md`.
- Accepted stationary purchases show success without a duplicate obstruction
  ghost. Local feedback expires on pointer/context/revision changes; host
  occupancy, funds and transaction validation remain authoritative.
- Compact catalog shows four complete choices with model miniatures and prices,
  ranked search, an explicit active-item summary and support requirements.
  Optional construction daylight changes rendering only and resets on exit.
- Undo/Redo descriptions come from accepted host transactions, including affected
  counts and exact next costs/refunds. Optional bounded runtime snapshot strings
  are absent from disk saves; no save-schema or asset changes.
- Native macOS Godot 4.7.2/OpenGL review passed at 1440×900/100% and
  1280×720/125%, day/night/daylight preview, purchases and compact search.
  Automated native catalog/Move/right-rotation drags passed. Evidence:
  ignored `build/build-feedback-*.png`, `build/issue6/native-*.log`,
  `build/issue6/final-native.log`. Human hardware is not established by automation.
- Local validation: all 127 gameplay/UI suites, both save-continuity processes,
  eight real Iroh scenarios and dedicated-server smoke passed across the required
  `tools/check.py` run and resumed checks. One old drag test hit the wider tray;
  panning its work area fixed it. Final focused checks and compact native area
  dragging passed. Logs: `build/issue6/check*.log`, `final-focused.log`,
  `native-area.log`; coverage audit: `build/issue6/validation.json`.
- Staged asset-storage and whitespace checks pass. Hosted CI is separate and
  unverified at this checkpoint. No local exports, physical-device tests or
  human playtest were performed.

# Neighborhood context — November 5, 2026

- Issue #11: vacant-lot feedback and off-lot resident context implemented;
  optional NPC households and distinct starter layouts explicitly deferred.
  All four dispositions are in `docs/NEIGHBORHOOD_QA.md`.
- Visit, household travel and remote interaction feedback share read-only
  destination availability. Single visits reject blocked arrivals before
  cancelling plans; forced construction/disconnect returns keep their fallback.
  Occupied caretaker homes remain open. No save schema, protocol or asset change.
- The HUD names the selected resident's real location while viewing another lot,
  retains activity/timing, and offers a labeled Find resident action. It uses
  existing camera navigation and preserves both residents' positions and plans.
- Native macOS Godot 4.7.2/OpenGL pointer/keyboard checks and visual review passed
  at 1440×900 and 1280×720 with the UI setting at 125%, day/night and long names.
  Evidence: ignored `build/neighbor-context-*.png`, `build/issue11/native.log`,
  and `build/issue11/compact.log`. Staged asset-storage and whitespace checks pass.
- Local regression: all 126 gameplay/UI suites, save-continuity restart checks,
  eight real Iroh scenarios and dedicated-server smoke passed across the required
  `tools/check.py` run and resumed checks. An initial meal-call assertion caught
  a lost Away status label; the compact label was restored and the failed and
  remaining suites passed. Logs: `build/issue11/check.log`, `check-resumed.log`,
  `final-focused.log`; coverage audit: `build/issue11/validation.json`.
- Hosted CI is separate. No local exports, physical-device tests or human
  second-player playtest were performed.

# Storey access and floor context — November 5, 2026

- Issue #7: all four findings implemented; dispositions in `docs/STOREY_QA.md`.
  Empty upper levels are unbuilt. Access/Finish share whole-home connectivity,
  stair/landing targets and floor-aware Find; overlays stay on their own level.
- Finish/Discard returns to the selected resident’s floor and lot, reframing only
  when that context changes. The location heading retains the viewed floor.
  Separate View and Travel groups use read-only host-shared stair availability.
  Guide → Building has an optional upstairs checklist, with no purchase actions.
- Native macOS Godot 4.7.2/OpenGL review passed at 1440×900 and 1280×720/125% UI,
  day/night, plus the compact Guide. Captures: `build/storey-*.png` and
  `build/guide-upstairs-checklist-compact.png`; logs: `build/issue7/` (ignored).
- Local validation: all 125 gameplay/UI suites, save-continuity restart checks,
  eight real Iroh scenarios and dedicated-server smoke passed across the required
  `tools/check.py` run and resumed failed/remaining checks. Final focused checks,
  staged asset-storage and whitespace checks pass. Logs: `build/issue7/check.log`,
  `check-remaining.log`, `check-resumed.log`, `final-focused.log`, and
  `final-floor-ui.log`. Earlier failures exposed assumptions about Finish framing;
  same-floor framing is now preserved, and the visiting-resident construction
  test explicitly navigates home before building again.
- Hosted CI is separate from local evidence. No local exports, physical-device
  testing or human playtest were performed. No binary assets or protocol changes.

# Context action feedback — November 5, 2026 (issue #3)

- Short context menus use a compact list beside the target; long menus retain
  paging and viewport clamping. Action labels, acting resident and Order/Inspect
  hints clarify quick clicks, keyboard choices and held-touch review.
- Accepted single orders name the resident/activity and distinguish Starting from
  Queued. Care and join-game/dance retain the host's precise reply. The ordinary
  HUD shares Plan's accepted-state remaining time and thin progress indicator.
  Plan's existing action-ID cancellation remains the recovery path.
- Painting buttons bind held presses to the reviewed canvas, resident and world
  generation. Completion/replacement cannot turn an in-progress click or key
  into a new action. Disappearing focus returns to the hobby link.
- All seven dispositions are in `docs/ACTION_QA.md`. Optional inspect-first,
  automatic pause-on-choice and a combined recent-moments feed are deferred;
  existing quick clicks, manual pause and saved journals remain available.
- Local validation: required `python3 tools/check.py` exited 0, with all 123
  gameplay/UI suites, both save-continuity processes, eight real Iroh peer
  scenarios and dedicated-server smoke passing (`build/issue3-check.log`). Final
  edits also passed six focused headless and six native runs (`build/issue3-final`).
  The runner now isolates each gameplay suite's settings as well as saves/profiles.
- Native macOS Godot 4.7.2/OpenGL review: actual-camera 1440×900 and 1280×720
  with 125% UI, day/night, short/paged menus at every edge, primary hover,
  HUD/Plan timing, painting completion and held-pointer/Space safety. Captures
  are ignored `build/context-*.png`, `build/activity-status-*.png` and
  `build/paintings-*.png`. Earlier compact test picking failures were corrected;
  final logs have no script/engine errors. Synthetic touch is not device proof.
- Staged asset storage and whitespace checks pass. No assets, save schema,
  simulation rules or protocol changes; authoritative changes are reply wording.
  Hosted CI is unverified at this checkpoint. No local exports, physical-device,
  other-OS or human playtests were performed.

# HUD navigation — November 5, 2026 (issue #2)

- Labels are on by default, with a persisted compact-icon option. More opens above
  its dock; guide icons/terms and Edit household agree. Fresh entry offers the
  starter household or customization; returning saves keep Continue.
- Needs/Plan keep fixed targets. Need inspection is read-only; the care tray names
  the actor/activity before an explicit order. Plan/activity trays are exclusive.
  Notices avoid the roster and open tray. Clock state and construction shelter
  have persistent text; activity trays reuse subject-specific icons.
- Roster grows through four complete rows, with explicit overflow for eight and
  ID-bound selection. Urgent need/current activity text updates without losing
  focus. Portraits and bespoke activity icons are deferred because legacy portrait
  fields do not faithfully represent the current creator. All ten dispositions:
  `docs/HUD_QA.md`.
- Local validation: all 123 registered gameplay/UI suites, eight real Iroh peer
  scenarios, dedicated-server smoke and both save-continuity processes passed.
  Required `tools/check.py` ran; shards 1/2/4 exit 0. Shard 3's old navigation
  assumptions were fixed and its remaining checks resumed through the same runner
  with exit 0. Logs: `build/hud-final-shard-*.log`; coverage audit:
  `build/hud-validation.json`. Earlier failing runs are superseded by these results.
- Native macOS Godot 4.7.2/OpenGL review passed at 1440×900/100% and
  1280×720/125%, including actual-camera day/night, 2/3/4/8 residents, long names,
  mouse/keyboard activation, first/returning menus, care, More and pause layouts.
  Native care review also passed queued care, missing furniture and construction.
  Evidence: `build/hud-native*.log`, `build/hud-care-native.log`, `build/hud-*.png`.
- No binary assets, save schema, protocol or authoritative simulation changes.
  Hosted CI is not yet verified; exports, physical devices, screen-reader testing
  and human first-time-player study were not performed for this change.

# Accessibility settings (QA #12) — November 4, 2026

- Added settings control names, action/key descriptions, tab-bar entry focus and
  scroll-to-focus. Native macOS AX exposes labels, roles, values and checked/tab
  states with `--accessibility always`; default Auto behavior is retained.
- Reduced motion now explains its wider effects. Dancers retain the static
  raised-arm pose when motion is reduced. No authoritative state or assets changed.
- Background music and Household stereos have independent persisted levels and
  buses under Master. Old combined levels initialize both, including mute.
- `docs/ACCESSIBILITY_REVIEW.md` records every finding's disposition. Independent
  larger text/reflow is deferred. Actual VoiceOver reading/announcements and an
  actual audio listening pass remain outstanding; do not auto-close issue #12.
- Native settings and dancing checks passed at 1440×900 and 1280×720/125%, day
  and night, including keyboard scrolling, static-pose/state invariance, and
  measured independent score/stereo/master mute. Captures/recordings are ignored
  `build/accessibility-*.png` and `build/dancing-*.{png,wav}`. No exports, physical
  Android, other OS or human playtests were performed locally.
- The first aggregate run encountered an old commission test save restoring the
  second resident. A fresh-profile rerun passed that test. Old `build/checks`
  artifacts were preserved under `build/accessibility-review/checks-before-fresh-run`.
- The fresh `python3 tools/check.py` run exited 0: all 122 gameplay/UI suites,
  save-continuity restart checks, eight Iroh scenarios and dedicated-server smoke.
  Log: `build/accessibility-review/check-fresh.log`. Staged asset-storage and diff
  checks pass. Hosted CI status belongs to the PR, separately from these results.

# Solo save continuity — November 4, 2026

- Solo restart and named loads start paused, keep safe resident positions and
  validated ordinary activities, and restore the saved resident, lot, floor,
  camera and last regular pace. Unsupported activities and unsafe spots have
  an on-screen recovery summary. Actual shared disconnects retain caretaker
  cleanup. Unfinished construction still rolls back.
- The save browser highlights a new named copy, identifies the overwrite
  target, shows local time and saved household details, and links to the exact
  recovery copy after replacing a world. House thumbnails and recent activity
  previews are deferred in the design guide.
- Regression coverage: `tests/save_continuity.gd` runs a real F5, normal quit
  and restart, then a named-slot and recovery round trip. It uses isolated
  paths and checks Reading, a bed reservation, a queued walk, both kinds of
  visitor, an upstairs position, art, pantry, and a stale target.
- Native review captures are under `build/save-continuity-*.png` (ignored):
  1440×900 and 1280×720 with the UI setting at 125%, at night and in daylight.
  Exports, physical-device and human playtests were not performed locally.

# Sculpted character art — November 4, 2026

- Reworked creator and world residents toward a warm illustrated cast: continuous
  jaw/cheeks/nose, fitted almond eyes, curved brows, swept/fitted hair, smooth
  arms and shoulders, tailored hems/collars/pockets and shaped shoes. Existing
  households use the same generator without rewriting saved profiles or colors.
- Editable original geometry remains `game/character_model.gd`; lighting is in
  `game/character_studio.gd`. No binary assets or external art were added. Old
  Blender resident GLBs remain archived and unchanged. Design/provenance and
  regeneration instructions are updated in the two design/asset guides.
- Checked matrix: 32,268 creator / 12,732 world triangles; both levels preserve
  animation pivots, picking and read-only state projection. Regression coverage
  now checks both levels and legacy-profile rendering. New native contact-sheet
  runner: `tests/character_art_review.gd`.
- Local validation: `python3 tools/check.py` exited 0 (all 121 gameplay/UI suites,
  eight Iroh peer scenarios and dedicated-server smoke). Final geometry/budget,
  renderer and creator checks also passed after the last visual refinements.
  Log: `build/character-style-check.log`. Asset-storage and diff checks pass.
- Native macOS Godot 4.7.2/OpenGL review passed at 1440×900 and 1280×720/125% UI,
  including low scenery, day/night, all hair cuts and outfit occasions, age/body
  variation, eight facings, walking, furniture poses and mesh selection.
  Evidence: `build/character-art-*.png`, `build/creator-*.png`, `build/facing-*.png`;
  same-light native comparison: `build/character-before-after.png`.
- Hosted CI: not run. Exports: not produced. Physical Android/other-device and
  family play: not performed. Animation rigs and activity placements retain their
  existing limits. Captures and build outputs remain ignored.

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
