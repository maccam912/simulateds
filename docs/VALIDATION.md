# Validation record

Checked locally on November 3–4, 2026. This record describes **Simulateds**, not the
upstream template demo. Template validation does not establish that this game's
changed simulation, protocol, saves, interface, or exported builds work.

## Observed local results

| Check | Result and boundary |
| --- | --- |
| Native transport | Built the macOS ARM64 host library with pinned Rust 1.98.1 and Iroh 1.4.1; application ALPN is `simulateds/1`. |
| Pinned engine | `python3 tools/check.py` completed with Godot 4.7.2 (`ed1daf0bf`); editor import and scripts parsed without errors. |
| World model | `WORLD_PASS`: starter reachability, ownership, need-restoring interactions, costs/refunds, construction, visitor recall, JSON save round-trip, caretaker bounds, and malformed input. |
| Independent integration | `INTEGRATION_WORLD_PASS`: two independent households, local construction freeze while neighbors continue, purchases, collision rejection, unsafe layout rejection, commit/discard/disconnect behavior, live snapshot flags, caretaker simulation, save atomicity, and full-neighborhood capacity. |
| Protocol/persistence | `PROTOCOL_PASS`: unknown sender rejection, request deduplication including evicted IDs, host-only bounded atomic snapshot assembly, malformed snapshot rejection, and file save/restore. |
| Recovery | `PERSISTENCE_PASS`: corrupt primary save recovers from a validated backup; two damaged saves remain protected; recovered profile credentials remain stable across reloads. |
| HUD interactions | `UI_FLOW_PASS`: actual UI callbacks for construction, floor/furniture placement, furnishing use, conversations, visits, return home, discard, rename, connection dialog, and truthful save-error reporting. Overlay input checks verify uncovered world clicks arrive and HUD clicks do not pass through. |
| Real Iroh session | `IROH_SMOKE_PASS`: one host and two clients in separate processes; independent households, construction, ownership rejection, visitor recall, replicated construction state, disconnect and reconnect retaining the same family/lot/funds/layout, and caretaker cleanup. Automatic Iroh route selection was used. |
| Live codes and forced relay | `python3 tools/check.py --codes --relay-only` passed all model, persistence, protocol, and UI checks plus `IROH_CODE_SMOKE_PASS`. Three real processes used the configured room-code service and forced public Iroh relays, including reconnect and code revocation. |
| Preferences and audio | `PREFERENCES_PASS`: settings persistence, key conflicts/recovery keys, named-bus levels/mute, and headless silence. Original WAVs have no clipped samples. The expanded graphical save/console capture passed twice with no audio-object leaks after explicit mixer-drain shutdown; application quit is covered by APP_FLOW_PASS. |
| Save library and cheats | `SAVE_DEBUG_PASS`: slot round-trips/overwrite/backup recovery, corrupt and invalid IDs, recovery before switching worlds, pause policy, bounded cheat arguments and client mutation rejection. |
| Console | `CONSOLE_PASS`: history, completion, bounded literal output, actual `rosebud` dispatch, client rejection, modal input, and Escape handling. |
| Application flow | `APP_FLOW_PASS`: startup/continue/pause, settings/rebinding into gameplay, console pause/close, and named save/load through the menu. `APP_RENDER_PASS` captures startup, main, pause, settings, save/load, and console screens on pinned Godot. Settings and bindings also fit a 1280×720 window at 125% interface scale. |
| Dedicated host | `SERVER_SMOKE_PASS`: headless `--server` starts Iroh, prints its ticket, advances and saves the world, and keeps its reserved household in caretaker mode. This tests the editor runtime, not an exported Linux server. |
| Graphical rendering | `GAME_RENDER_PASS` on pinned Godot 4.7.2; live and construction screenshots inspected at 1440×900 and 1280×720 after the overlay HUD rework. The world fills the viewport, including wide aspect ratios; controls and optional trays overlay it. This is visual inspection, not a human playtest. |

The model integration test advances 2,400 quarter-second ticks with absent
households. This exercises more than one simulated day, not an overnight
wall-clock soak. Need bounds and serializability remained valid.

## Reproduce

```sh
python3 tools/setup.py
python3 tools/check.py
python3 tools/check.py --codes --relay-only
```

For model/protocol checks without live peers:

```sh
python3 tools/check.py --unit-only
```

An explicitly supplied Godot executable can be used with
`--engine /absolute/path/to/godot`; that changes the engine being validated.
Default checks use the pinned project engine. Test processes use separate world
and profile files under ignored `build/`, not the player's neighborhood.

A graphical capture can be generated from a display-capable session:

```sh
python3 tools/godot.py --script res://tests/render_game.gd -- \
  --save-path=/absolute/path/render-world.json \
  --profile-path=/absolute/path/render-profile.json
```

Inspect both images; a successful capture does not establish correct input or
play balance. Forced-relay and live room-code checks are separate optional modes
of `tools/check.py` (`--relay-only`, `--codes`) and depend on external services.

## Evidence files

Generated and ignored by Git:

- `build/checks/world-engine.log`, `integration_world-engine.log`, and
  `protocol-engine.log`, `persistence-engine.log`, and `ui_flow-engine.log` contain
  the corresponding pass markers.
- `build/smoke/host0.log`, `client1.log`, and `client2.log` contain one `HOST_PASS`
  and two `CLIENT_PASS` markers from the pinned-engine Iroh test.
- `build/neighborhood.png` and `build/construction.png` contain actual game renders.
- `build/smoke-codes/` contains host/two-client logs for the live code and forced
  relay test. Reviewed screenshots are also retained in `docs/preview.png` and
  `docs/construction.png`.
- Test saves and profiles under `build/checks/` and `build/smoke/` are disposable
  test data. Do not reuse their credentials for a personal household.

The full `python3 tools/check.py` suite passed again after the application/menu
integration, including real Iroh host/two-client reconnect and dedicated startup.
The earlier forced-relay/code result predates this menu work; that optional live
service mode was not repeated for this update.

## Still open

The subsequent feature checks are recorded in [PLAYTEST_LOG.md](PLAYTEST_LOG.md).
The current local suite contains thirty-two model/application suites, plus real Iroh
host/two-client reconnect and dedicated-server startup. The room-construction
checkpoint passed Linux, Windows, macOS, and Android CI builds/exports. The later
household checkpoint passed the three desktop jobs; Android built, tested,
exported, and uploaded artifacts but failed when the runner ran out of disk during
cache saving. The cache-size fix and subsequent friendship checkpoint both passed
all four platform jobs. Mailbox validation adds real delivery while clients are
disconnected, reconnect retention, and gift collection/replay coverage.
The mailbox checkpoint also passed all four CI platform jobs. Care validation
adds authoritative target selection, busy/missing/blocked furnishings, duplicate
prevention, and needs recovery through actual activities. A native mouse/keyboard
playtest completed all seven care activities while the other resident used
autonomy; graphical captures cover the compact layout and construction state.
The care checkpoint passed all four CI platform jobs. Decoration validation covers
host-priced areas, nested undo snapshots, old-save defaults, wall-to-door cleanup,
draft/committed persistence, and real Iroh replication/reconnect of floor finishes.
The decoration checkpoint passed all four CI platform jobs. Hobby validation adds
actual primary/secondary need bonuses, completed-only practice, daily caps,
autonomy/absence behavior, reservations, blocked targets, legacy/corrupt saves,
and real Iroh progress/reconnect. Graphical input checks at 1440×900 and
1280×720/125% UI scale cover all three practices, rank feedback, individual
resident progress, scrolling, missing furniture, Escape, and construction.
The hobby checkpoint passed all four CI platform jobs. Catalog checks add typed
search, stable focus, category callbacks, filtered/empty results, selected-item
footprints and affordability, construction purchase/undo, and compact palette
regression coverage. A native mouse/keyboard playtest separately verified the
actual category popup, search, bookshelf purchase, undo/redo commands, and
save/reload; its saved world retained two bookshelves and the exact §160 purchase.
The catalog checkpoint passed all four CI platform jobs. Guide checks cover
main/pause/new-world navigation, every direct action, construction and guest-save
restrictions, own-home routing, live binding updates and rescue keys, persistent
opt-out, and compact/standard layouts. The guide-specific shared-clock assertion
uses the local session path with simulated roles; real Iroh checks also passed.

The guide checkpoint passed all four CI platform jobs. Pastime checks cover all
four activity choices, neutral legacy saves, malformed-state atomicity, urgent
care, bounded preference strength, blocked/missing furnishings, disabled autonomy,
manual plans, and no unattended wish/hobby rewards. Household edits preserve
preferences when older clients omit them; the maximum Unicode editor request
still fits one transport packet. Graphical household input checks passed at
1440×900 and 1280×720/125% UI scale, including selector bounds and visible favorite
activities. Real Iroh identity replication and reconnect retain both preferences.

The favorite-pastime checkpoint passed all four CI platform jobs. Home-news checks
cover actual simulated absence, first visits and quick reconnects, accumulating
unread reports, exact credited allowance, separate gift escrow, stale/foreign read
commands, host restarts, legacy saves, malformed data, and discarded drafts. Daily
allowance now respects the funds limit across all reversible build balances.
The real Iroh test replicated offline postcard recaps and read acknowledgements;
the host's saved world retained both clients' read states after disconnect.
Graphical input checks passed at standard and compact desktop sizes. They cover
optional entry, fixed action footer, current-versus-historical gift totals, Escape,
construction continuity, and immediately persisted read state without a manual save.

The Home news checkpoint passed all four platform CI jobs. Activity-audio checks
cover every activity mapping, unchanged snapshots, periodic progress, teleport
silence, resume/lot transitions, headless silence, eight-walker fairness, and rate
bounds. A graphical mixer playtest recorded real left/right positional output,
zero effects-mute output, four household voices plus an independent UI cue, and
ordinary walking/reading/gardening/tea. Live sources stop when panned offscreen,
paused, canceled, or under construction; reduced motion retains footsteps.
The host-menu check uses the host role locally, not a network audio playtest.
The captured busy mix peaked at 0.158 and the ordinary mix at 0.116 full scale,
with no clipped samples. Source files have quiet endpoints and no clipping.
These objective checks do not establish subjective mix quality on user devices.

The spatial-audio checkpoint passed all four platform CI jobs. Resident-cue
checks cover all seven needs, non-mutating derivation, thresholds, automatic and
queued care, secondary comfort, missing targets, overlapping/edge labels, and
owned care-command routing without disrupting manual plans. Graphical input
playtests passed at 1440×900 and 1280×720/125% scale: clustered cues, selection and
actual care, double-click protection, sleeping labels, settled residents, long
names, night/edge layouts, unavailable furniture, construction, menus, and
offscreen removal. The initial edge fixture framed an old displayed position;
it now waits for presentation to update before positioning the camera.

The resident-cue checkpoint passed all four platform CI jobs. Camera checks
exercise actual keyboard/mouse input, visible versus offscreen selection,
repeat-click focus, Plan controls, preservation of zoom, interruption by manual
pan/zoom, Center, reduced motion, current locations after snapshot replacement,
lot changes, custom bindings, menu suppression, and catalog typing. Graphical
checks cover standard and compact windows with long names and a visiting
resident. These snapshot checks use local replacement, not a network camera test.
Settings checks migrate the older nine-action map, preserving custom swaps and
choosing an unused focus key when F is already bound. Invalid maps still fall
back atomically. Headless mouse checks allow a frame for pointer routing before
pressing a control, as native rendering already does.

The camera checkpoint passed all four platform CI jobs. Plan-editing checks cover
full queues, exact mutation of an adjacent pair, preserved current progress and
action IDs, malformed/foreign/stale/repeated requests, complete reordered
execution, snapshot round trips, and moving a useful activity ahead of a busy
fixture without stealing its reservation. Both real Iroh clients edited plans,
observed the new order while their current action continued, and received
rejections for stale and foreign edits. All 29 local suites and dedicated-server
startup passed. Actual mouse/keyboard playtests cover focus, scroll, cancellation
after reordering, boundaries, and completed two-resident morning plans. Standard
and compact graphical checks passed; plan confirmations were moved beside the
tray after visual inspection exposed an overlap. Follow-up plan, HUD, camera,
and application checks passed after that layout polish.

The plan-editing checkpoint passed all four platform CI jobs. Activity-feedback
checks compare estimated and actual completion for all nine furnishings at low,
high, and full needs, with automatic/player-directed timing and hobby bonuses.
They cover travel, arrival, waiting, missing furnishings, construction,
conversation timing and passive participation, non-mutating derivation,
monotonic ordinary progress, pause, and replacement snapshots. The first
comparison exposed the sofa's extra comfort; the simulation and estimate now
share personal restoration rates. All 30 suites and real Iroh/server checks
passed. Standard/compact graphical feedback checks passed, including control
identity and focus through the travel-to-activity transition. Remaining time is
an estimate: nearby social effects or changed needs can change it. The UI
snapshot-replacement check is local, not a multiplayer visual playtest.

The activity-feedback checkpoint passed all four platform CI jobs. Tabletop
checks cover solo fun, social restoration only for actual participants, separate
reserved destinations, four places plus a waiting fifth, cancellation, ownership,
snapshot replication, disconnect, construction recall, and legacy save loading.
Tabletop favorites fall back to other recreation if the table is absent or full;
care shortcuts favor available furniture. Shared play quiets social thoughts and
duplicate care until the companion leaves. All 32 suites and real Iroh/server
checks passed. Both real clients observed shared games and separate places before
construction recalled them. Native standard/compact mouse-input checks passed
for purchasing, undo/redo, four rotations, joining, leaving, and recall. Actual
mixer recordings included the new wooden piece texture with nonzero, unclipped
output (peak about 0.015); this is not a human listening assessment. Protocol 2
rejects old peers before adding their household; world schema 1 remains readable.

Physical Android operation, cross-OS multiplayer, exported game packages,
production authentication, public matchmaking abuse resistance, long-term
balance, overnight simulation, packet impairment, release status,
and human family playtests require separate evidence. A local headless pass does
not prove any of those. macOS Intel, Windows, Linux, Android, and server export
presets/build infrastructure are inherited targets. CI exports establish package
creation; they do not establish device playability or cross-platform multiplayer.

See [ROADMAP.md](ROADMAP.md) for the next acceptance gates.
