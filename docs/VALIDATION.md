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
The current local suite contains 70 model/application suites, plus real Iroh
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

The tabletop checkpoint passed all four platform CI jobs. Game-discovery checks
cover read-only People options, malformed/foreign/self/stale joins, completed and
replacement activities, duplicate prevention, existing-plan preservation,
full-table waiting/release, full plans, inaccessible tables, and construction.
All 34 suites and Iroh/server checks passed. In the real Iroh test one client
discovered the other client's game, rejected stale/duplicate joins, and joined
through the same command used by People. Native standard/compact mouse and
keyboard checks covered discovery, visiting, joining, active status, full tables,
ending games, and construction recall. Focus survived snapshot replacement and
remained on the same person after joining. A compact screen review led to a
post-layout scroll correction that keeps the person's name with their focused
button when the card fits; the final compact native and related model/UI checks
passed. Human interaction and cross-device play remain separate gates.

The People-discovery checkpoint passed all four platform CI jobs. Construction
access shares a pure entrance flood with the host's commit check. Across 180
generated layouts, its decisions and per-object findings matched the ordinary
pathfinder, including rotations, occupied legacy starts, sealed rooms, and bad
gates. Model checks also cover exact blocked targets, read-only inspection,
atomic commit rejection, door repair, undo/redo, and replacement snapshots.
All 36 suites and real Iroh/server checks passed. Native standard/compact checks
covered automatic report opening, camera focus, marker clicks, visible-wall
doorway repair, reopening, Escape, and catalog-search recovery. The final compact
capture keeps twelve problem badges distinct in a sealed house. Related UI,
catalog, and finish checks passed after the presentation polish.
The extended real Iroh check then closed each client's front door, verified that
its locally derived report matched the host's rejected commit message, repaired
the doorway, and reopened successfully. This establishes actual command/snapshot
agreement; the native overlay captures are local graphical checks.

The construction-access checkpoint passed all four platform CI jobs. Room floor
finishing checks cover connected regions, doorway/wall/gap boundaries, diagonal
separation, floor beneath furniture, mixed existing finishes, exact pricing,
unchanged and unaffordable regions, malformed/foreign/stale requests, undo/redo,
discard, crash-save protection, and committed reload. All 38 suites and real
Iroh/server checks passed. Actual clients applied a 56-tile room for the previewed
§224, rejected a replay, undid/redid it without losing earlier decoration, and
retained the finish and door boundary after reconnect. Native standard/compact
checks covered the whole mouse flow, connected extensions, all six visible
swatches, over-budget previews, and returning through Access. The final preview
renders its boundary on the floor behind furniture. Final compact keyboard tests
and related catalog/help checks passed after adding focus retention. The older
compact rectangle/wall graphical workflow also passed.

Physical Android operation, cross-OS multiplayer, exported game packages,
production authentication, public matchmaking abuse resistance, long-term
balance, overnight simulation, packet impairment, release status,
and human family playtests require separate evidence. A local headless pass does
not prove any of those. macOS Intel, Windows, Linux, Android, and server export
presets/build infrastructure are inherited targets. CI exports establish package
creation; they do not establish device playability or cross-platform multiplayer.

See [ROADMAP.md](ROADMAP.md) for the next acceptance gates.


Resident-facing checks cover accepted cardinal movement, bounded animated turns,
retained idle direction, reconstructed corners around walls, initial client routes,
reduced motion, every approach side of eight furnishing kinds in all rotations,
seated rotation, reciprocal conversation attention, stale/departed/busy partners,
construction, travel, and replacement snapshots without authoritative mutation.
All 40 suites and real Iroh/server checks passed. These network checks exercise
the established gameplay flows; facing snapshot continuity is a local presentation
check, not a claim of a two-machine visual test. The room-finishing checkpoint
passed all four platform CI jobs.

Native standard/compact checks inspect an eight-facing appearance sheet, actual
rotated sleeping/seated activities and selection, reading/tea/gardening/meals/TV,
real chats, snapshot replacement, reduced motion, and departure. The final compact
check also clicks a four-leg walking circuit and verifies displayed position,
facing, and body selection while the authoritative snapshot stays unchanged
between explicit simulation steps. Need labels no longer cover a neighbor's
sleeping head, and shared conversation bubbles sit above both faces. The earlier
activity render check plus compact urgent-cue and tabletop flows passed again.
Captures are ignored `build/facing-*.png`. Human/device playtests remain open.


Walk-feedback validation compares the preview with actual host decisions for all
256 starter-lot tiles, including exact routes for accepted immediate walks.
Additional checks cover sealed thresholds, ownership, absent lots, remote views,
queue limits, direct orders interrupting autonomy, accepted identity, transient
queued confirmations, plan reordering/cancellation, snapshot replacement, travel,
construction, menus, and no authoritative mutation. All 42 suites and real Iroh
host/two-client/server checks passed. Both real clients reject a wall destination
without a marker, then derive three accepted walk markers and their reordered
numbers from received snapshots. The resident-facing checkpoint passed all four
platform CI jobs.

Native standard/compact checks exercise ground hover, actual clicks, immediate
and queued feedback, nameplate selection, Plan/cancel controls, hidden HUD,
unreachable/repaired routes, replaced snapshots, construction, travel, and reduced
motion. Final compact checks also inspect actual walking, combined numbers for
repeated destinations, and Plan-number correspondence. Captures are ignored
`build/walking-*.png`. These tests use native automated input; physical-device,
human family, and impaired-network visual playtests remain open.


Routine validation covers independent household libraries, all-or-nothing queue
capacity and reachability, current-lot target selection, duplicate prevention,
private-object waits, preserved manual work, interrupted autonomy, ordered need
recovery, stale/malformed/foreign edits, monotonic IDs, library limits, legacy
save defaults, strict restoration, and retained recipe tags after deletion.
All 44 suites and actual Iroh host/two-client/server checks passed. Both clients
save independent recipes, reject stale edits and duplicate runs, append behind
existing orders, retain ordered target/tag metadata, reject foreign residents,
and keep their recipes after reconnect. Every smoke-test command checks its
intent-correlated result. Protocol checks also cover mutable caller drafts,
malformed/duplicate/non-host replies, backpressure, oversized requests, and local
success/failure. The walking-feedback checkpoint passed all four CI platform jobs.

Native standard and compact/125% routine checks exercise actual mouse/keyboard
editing, activity-picker navigation, step ordering/removal, save/run, capacity,
missing furnishings, deleting a recipe without canceling accepted work, snapshot
focus retention, unrelated delayed replies, retry, stale edits, and completion.
Captures are ignored `build/routines-*.png`. Final compact navigation preserves a
six-step draft while another tray is open. Application checks cover Escape from
the focused name field and developer-console Escape priority. These are automated
native checks, not human family or physical-device playtests.


Windows validation compares shared previews with host decisions for all 256 lot
tiles and covers every style, exact net trade-in/removal prices, no-charge repeats,
unchanged routing and room-fill regions, wall direction, paint under a window,
ordinary doorway and extension-door replacement, undo/redo, discard, disconnect,
committed crash saves, live snapshots, old-save defaults, malformed restoration,
foreign/stale requests, invalid coordinates, and budget limits. All 46 suites and
actual Iroh host/two-client/server checks passed. Each real client buys a different
window style for the previewed price, rejects replay/foreign construction, undoes
and redoes the window, and retains it with its solid wall after reconnect. The
routine checkpoint passed all four platform CI jobs.

Native standard and compact/125% checks inspect starter windows, all styles,
raised-wall picking and previews, replacement pricing, undo/redo, removal without
wall deletion, missing walls, insufficient funds, access inspection, live
cutaways, night glass, and replacement snapshots. Final compact checks cover
catalog search/return, all palette controls fitting together, unrelated replies,
acknowledgement before the accepted snapshot, and price labels avoiding the HUD.
The compact room-finishing and catalog flows passed again after shared preview
label placement was polished, and the updated guide passed its native check.
Captures are ignored `build/windows-*.png`. Empty-lot test fixtures now clear their
mounted windows with their walls. These are automated/native checks; human family,
physical-device, and impaired-network visual playtests remain open.

## Solo clock controls

`PLAY_CLOCK_PASS` compares complete world snapshots after the same simulated time
at 1×, 2×, and 4× with 30/60/120 Hz input. Needs, movement, activities, rewards,
queues, and counters agree. Fixed 0.1-second steps preserve fractional time;
walking likewise preserves its 0.22-second tile interval. Checks cover paused
planning, resuming the previous pace, menu pause preservation, malformed rates,
bounded stalls, debug fractional/8× rates, shared/dedicated rejection, and pace
resets after leaving or a failed join. Save tests verify normal pace after loading
or creating a world. Preference migration reserves all existing keys before
assigning collision-free defaults for newly introduced actions.

All 48 local suites passed. The guide fixture now moves solo pause off P before
testing its existing custom menu binding, leaving T free for its rotation test;
conflicting bindings remain rejected. Real Iroh host/two-client/reconnect and
dedicated-server checks passed: hosting/joining resets a private fast/paused
clock, shared controls cannot mutate state or send a request, and a host menu
keeps simulation running. The windows checkpoint passed all four platform CI jobs.

`PLAY_CLOCK_UI_PASS` exercises actual mouse/key input, the real physics scheduler,
paused ground-click planning, all rates, menu return, mid-step animation freeze,
household-audio silence, Space activation, typing protection, live rebinding,
and shared-clock locks. Native 1440×900 and 1280×720/125% flows passed. Compact
guide and directional-resident captures passed with the revised bindings/time
semantics. Manual-step presentation fixtures disable automatic physics while
leaving presentation time active; deliberate player pause freezes both. Final
clock hover styling keeps the selected pace readable under the pointer. Captures
are ignored `build/clock-*.png`; these remain automated native checks, not human
family, physical Android, or cross-platform visual playtests.

## Kitchen gardens

`GARDENS_PASS` covers lawn placement, shared read-only activity previews, exact
seed/harvest amounts, full-duration work at full needs, cancellation without
spending or practice, one resident reserving a bed, malformed/stale/replayed
commands, safe dry/ripe waits, growth during simulated absence, visitor watering,
ownership, bounded hobby practice, budget changes, and no autonomous spending or
harvesting. Crops survive moves, undo, discard, JSON saves, and runtime snapshots;
disk load clears unfinished work. Malformed crop/task data rejects restoration
atomically, and worlds without garden beds still load.

All 50 local suites passed, followed by real Iroh host/two-client/reconnect and
dedicated startup. Each actual client grows a different crop with its second
resident while its first resident completes the existing care, plans, hobbies,
conversation, and visiting flow. Crop choice, revision, growth, and dry bounds
survive reconnect. An older catalog assertion now expects both the Cloud bed and
garden bed for “bed”; typing protections and first-result selection stay covered.
The preceding clock checkpoint passed all four platform CI builds/exports.

Native standard and compact/125% checks use actual placement, bed picking, seed
and care buttons, unaffordable seed feedback, accepted plans, planting/watering/
harvest props, growth stages, dry/ripe states, snapshots, visitor restrictions,
and live planting/harvest rustle and water cues. The compact guide and catalog
checks passed with the new entry. Final panel polish names the resident doing
the work and clears completed acknowledgements; failures remain actionable, and
an acknowledgement alone cannot invent accepted work. Captures are ignored
`build/garden-*.png`. These are automated native checks, not human family,
physical-device, overnight-host, or impaired-network visual playtests.
Final compact checks also cover all four bed rotations with a ripe crop, visible
surface picking, the full-duration Plan tooltip, failure recovery, and mixer cues.

## Recent activity outcomes

All 52 local suites passed, followed by actual Iroh host/two-client/reconnect and
dedicated startup checks. `tests/activity_log.gd` covers completion, fulfilled-need
completion, individual and batch cancellation, bounded ordering, autonomous care
exclusion, repeated/rejected commands, missing furnishings, blocked paths,
conversation departure/completion, travel, construction recall, absence, runtime
snapshots, disk-load interruption, routine provenance, legacy migration, and
atomic rejection of corrupt history. Existing garden checks also verify actual
planting and harvest outcomes. Both real clients receive one cancellation entry
after a rejected repeat and preserve their gardener's completed history across
reconnects.

Native Godot input playtests passed at 1440×900 and at 1280×720 with 125% UI scale.
They use actual injected mouse events to open Recent, cancel an upcoming action,
switch residents, and return to Upcoming. The flow completes care, exercises an
interrupted furnishing activity, scrolls a full eight-entry list, preserves focus
and rows on refresh, and replaces the full replicated state. Captures are ignored
`build/activity-log-*.png`. Visual inspection confirmed readable status/reason/
time rows within the original floating Plan tray; no added HUD island or world
frame. A final compact run passed after scroll/title polish. These are automated
native playtests, not evidence of human family or physical-device play.

The preceding garden commit passed all four platform CI jobs. CI for this
checkpoint is tracked separately after push.

## Routines copied from current plans

All 54 local suites passed, followed by real Iroh host/two-client/reconnect and
dedicated startup checks. `tests/routine_capture.gd` covers exact active/upcoming
order, repeated steps, autonomous exclusion, position-specific omissions for
walking/conversation/crop/missing-target work, read-only capture, draft isolation,
nine-step capture without truncation, host rejection of an oversized recipe,
reviewed saving without altering current work, use by the second resident on a
neighbor's furnishings, runtime snapshots, and disk saves. Both real clients
copy their accepted mixed plan into a recipe, save via the normal authority
command, reject a duplicate stale save, and retain the copy across reconnects.

`tests/routine_capture_ui.gd` passed through native injected mouse/keyboard input
at 1440×900 and at 1280×720 with 125% UI scale. The flow clicks actual fridge,
shower, and bookshelf surfaces; copies and edits their order; names/saves the
recipe; reviews mixed-plan omissions; changes residents while retaining the
source draft; trims nine steps to six; handles a full library; and retains a
copied draft after an actual stale revision rejection. The first harness pass
tried scrolling a freshly rebuilt control before layout had settled; waiting for
layout before targeting the control fixed the test. Both final native passes
completed. Visual inspection of ignored `build/routine-capture-*.png` confirmed
readable omissions, original positions, and disabled-save limit guidance within
the existing routine panel. This remains automated native validation, not human
family or physical-device testing.

The preceding activity-history checkpoint passed macOS, Linux, Windows, and
Android CI. This checkpoint's platform build result is tracked after push.

## Music corners and shared dancing

All 56 local suites passed, followed by actual Iroh host/two-client/reconnect and
dedicated startup checks. `tests/dancing.gd` covers stereo purchasing, solo fun,
participant-only social restoration, People discovery, ownership, stale/repeated
joins, distinct approach destinations, four places plus a waiting fifth,
construction recall, cancellation/disconnect, routine capture, runtime/disk
restore, visible music-source choice, and reservations across adjacent shared
furnishings. Existing tabletop/join tests pass against the extracted shared
leisure behavior. Both real clients first share a tabletop game, then join one
another's dance, observe separate spots and social restoration, and get recalled
when the host enters construction.

Native injected-input dancing playtests passed at 1440×900 and at 1280×720 with
125% UI scale. They purchase the hi-fi, inspect all four rotations and click
surfaces, start solo dancing, join a visitor through People, verify three separate
places and Plan feedback, and inspect the reduced-motion pose. Actual mixer
recordings prove audible unclipped stereo output with Effects muted, silent
output with Music muted, score ducking, no restart on repeated snapshots, and
stopping on solo pause, menus, offscreen camera movement, and construction.
Ignored captures/recordings are `build/dancing-*.png` and `build/dancing-*.wav`.
The generated 19.2-second mono asset was regenerated independently and matched
byte for byte.

The broader native household-audio check exposed an onset lost inside the short
mix gap after a footstep. Added a regression and a single still-active onset
retry, discarded on cancellation/context change. Both model audio/dancing checks
and the actual household mixer recording passed afterward, followed by a final
compact dancing run. This preserves sparse bounded textures without replaying
old activity sounds. The final settings label explicitly says Music & stereos.
These are automated native and mixer checks; human listening, family play,
physical Android/cross-OS play, and overnight hosting are still open.

The preceding routine-capture checkpoint passed all four platform CI jobs.


## Shared places and layout capacity

All 58 local suites passed across the full run and its resumed remainder. The
first run stopped on a legacy `1/4` text assertion in the People test; updating
that test to the new explicit count and running it plus every remaining suite
passed. Final shared-place/tabletop model checks and a compact native rerun
passed after the last polish. The actual Iroh host, two clients, reconnect, and
dedicated startup passed. Both real clients derived three usable dance places
and two reservations from the accepted host snapshot.

`shared_spaces.gd` covers a one-place corner, queued joining, reservation release
with an idle resident still occupying the place, resumption after that resident
moves, unreachable floor, all shared-object rotations, nonmutation, snapshot
replacement, and future reservations across neighboring furnishings. The access
suite still compares 180 layouts with ordinary pathfinding. No new persisted
fields or protocol messages were added.

`shared_spaces_ui.gd` uses injected input in the real macOS renderer at 1440×900
and 1280×720 / 125% UI scale. It buys a stereo in a tight corner, queues a second
dancer through People, inspects the reserved place, moves the stereo to an open
area, and joins two dancers. Preview reads leave the world/funds unchanged.
The final compact pass confirms cancellation changes markers while the simulation
tick stays fixed. Screenshots were inspected for the count, markers, and tooltip
placement clear of the activity. Captures: `build/shared-spaces-*.png` (ignored).
The preceding dancing checkpoint passed all four platform CI jobs. Human family
play, physical device checks, and overnight hosting remain open.


## Courtesy after shared recreation

All 60 local suites passed, followed by the expanded courtesy-model suite.
`courtesy.gd` covers one-place stereo/table handoff, exact pending action IDs,
no movement without a current waiter, deliberate queue priority, direct-order and
cancel interruption, blocked exits, doorways, conflicting accepted routes,
simultaneous finishes with separate destinations, runtime replacement, disk reload,
invalid courtesy fields, and construction recall. The completed activity is
recorded once; the finishing step produces no reward or false manual result.

Native injected-input runs at 1440×900 and 1280×720 / 125% UI scale let the dance
finish naturally, inspect the visible Making room for Robin plan row and its
cancel control, follow the accepted one-tile walk, and verify Robin takes the
same waiting plan into the freed spot. Reduced motion reflects the accepted
position. Screenshots were inspected; ignored captures are `build/courtesy-*.png`.

The real Iroh host fills the three-place music corner, queues its fourth dancer,
and finishes one participant. Both independent clients observe the one-step
position change and the same waiting action arriving. Construction recall,
reconnect, and dedicated startup then pass. The initial observer assertion used
integer-array equality against JSON floats; an isolated engine check confirmed
that comparison is false, and explicit coordinate normalization fixed the test.
The complete real-peer scenario was rerun successfully after the correction.

The previous shared-place checkpoint passed macOS, Android, Linux, and Windows
CI. These automated native/real-process checks do not establish human family
play, physical Android or cross-OS play, or overnight host reliability.


## Shared recreation and friendship

All 62 local suites passed. `shared_friendships.gd` checks both furnishings at the
12-minute boundary, simultaneous completion in either family order, late arrivals,
short interrupted sessions, repeated encounters, midnight, mixed chat/play daily
limits, three-person pair accounting, autonomous/absent/separate-object exclusions,
explicit replacement of automatic participation, runtime snapshot replay, disk
reload, legacy chat history, and malformed encounter metadata. The same bounded
relationship recorder supplies chat and play gains and journal milestones.

Native injected-input tests passed at 1440×900 and 1280×720 / 125% UI scale.
`shared_friendships_ui.gd` turns Robin's accepted automatic dance into chosen
participation through People, verifies the first catch-up, starts a second chosen
encounter, and reaches Friends. Cards show Danced together, game day, one catch-up
left, then Caught up today. Both journals, the existing milestone notice, and
saved encounter metadata are checked. Inspected captures are ignored under
`build/shared-friendships-*.png`.

The actual Iroh scenario now requires both clients to observe a 12-point shared
game and then a 24-point total after dancing, with two catch-ups and stereo as the
last encounter. A final real-peer rerun additionally compares each resident’s
relationship records before and after reconnect, retaining exact gains, daily
limits, and last-encounter metadata. The courtesy handoff, construction recall, reconnect, and dedicated
startup also pass. The preceding courtesy checkpoint passed all four platform CI
jobs. Automated native/real-process evidence does not establish human family play,
physical Android or cross-OS play, or overnight host reliability.

## Copying furnished rooms

All 64 local suites passed, including new room-copy model and UI checks. The
model covers four rotations, exact component pricing, sparse/irregular room
shapes, reuse of existing floor, fresh furnishing IDs, fresh empty garden beds,
source preservation, access/occupancy/budget failures, malformed and stale
requests, ownership, atomic undo/redo, and save restoration. The host recaptures
the accepted source; clients cannot supply copied object state.

Native injected-input runs passed at 1440×900 and 1280×720 / 125% UI scale.
They select a furnished, painted room with a window, preview all rotations,
reject occupied/out-of-bounds destinations, place it for the displayed price,
undo/redo, cancel selection, and invalidate selection after a source edit.
Inspected captures are under ignored `build/room-copy-*.png`. An additional UI
pass verifies that unrelated failures cannot clear a pending placement and that
acceptance waits for its authoritative snapshot. The Building guide explains
copying alongside the existing catalog workflow.

The actual Iroh host/two-client scenario passed with independent decorated-room
copies, new replicated object identities, stale-request rejection, whole-copy
undo/redo, and exact design/identity retention across reconnect. Dedicated startup
passed as well. Initial test layouts either sealed a later walking destination
or pointed a doorway into an inaccessible strip; the final fixture uses a clear
location and accessible rotation. These fixture corrections did not relax the
game's access checks. The preceding shared-friendship checkpoint passed all four
platform CI jobs. Human family play and physical-device checks remain open.

## Furnishing material colors

All 66 local suites passed. The initial run stopped at a catalog assertion that
expected only two bed search results; Furniture colors now legitimately matches
bedding. After updating that expectation, the catalog and all remaining suites
passed. The compact native catalog flow passed again, retaining the bed as the
first result and the usual Enter-to-select behavior.

New model coverage checks every furnishing and all six material choices,
unchanged/no-op behavior, free application with zero funds, exact undo/redo,
identity and planted-garden preservation, malformed/stale/foreign commands,
legacy and invalid save metadata, draft versus committed persistence, moves,
discard, and all four rotations of a colored room copy. Missing color metadata
retains the exact original rendering. Room copies carry the chosen design onto
fresh objects without copying crop state.

Native injected-input checks passed at 1440×900 and 1280×720 / 125% UI scale.
They exercise palette visibility, keyboard focus, preview purity, click-to-apply,
Original, undo/redo, all furnishing materials, catalog search, empty-ground
rejection, access inspection, pending-command correlation, and colored bedding
while sleeping. Inspected captures are in ignored
`build/furniture-colors-*.png`. Early test setups placed the extra game table on
a resident or blocked the fridge; the final setup explicitly checks access before
the color workflow. A mistaken test call to `tick` was corrected to `step`.

The actual Iroh host/two-client scenario passed recoloring, unchanged budget,
stale-request rejection, undo/redo, movement of a colored fridge, independent pot
colors, colored room duplication, and reconnect retention. It waits for the
accepted construction snapshot before submitting the next revision-bound color
command. Dedicated startup passed. The room-copy checkpoint passed all four
platform CI jobs; physical-device and human-family evidence remains open.


## Construction access forecasts

All 68 local suites passed, followed by the actual Iroh host/two-client/reconnect
scenario and dedicated startup. New model checks compare complete forecast
reports with the authoritative result of accepted draft edits, including 160
seeded placement/movement trials, all four room doorway orientations, gate
obstructions, newly inaccessible furnishings, old problems, partial repairs,
invalid placement, and unchanged source state. Warnings do not reject drafts;
Finish building still rejects inaccessible homes.

Native injected-input flows passed at 1440×900 and 1280×720 / 125% UI scale.
They place a table that blocks the fridge, inspect the warning, reject Finish,
move the table to repair access, undo/redo, close and reopen the entrance, and
rotate a kitchen divider from blocked to clear. Assertions check preview purity,
exact accepted reports, budget, capped badges, and text/badge/HUD separation.
Reviewed captures are in ignored `build/build-impact-*.png`. Screenshot review
caught footprint lines drawing across the explanation; the final draw order
keeps the label on top. The native test aligns the OS pointer with injected input
to avoid unrelated mouse-exit events clearing its hover.

Final targeted standard/compact native runs also replace the active world with
a different layout at the same lot ID, revision, funds, and resident positions.
The cached forecast correctly refreshes; the updated Building guide check passes.

The multiplayer scenario computes both the entrance-blocking forecast and its
repair on the client, then compares each with the host's replicated report.
No protocol or save fields changed. The furnishing-colors checkpoint passed all
four CI platform jobs. Human-family, physical-device, and overnight hosting
checks remain open.


## Paintings and persistent creative work

The 70 local model/application suites pass. New model coverage checks all three
subjects, need restoration without early completion, cancel/resume with shared
credit, paid sales versus canceled sales, duplicate and stale requests,
construction and visitor restrictions, exact artwork retention through moves,
recoloring, history, discard, save/load, and absence. Corrupt canvas/task data is
rejected. All four rotations of an actual room copy retain the original work
and create a new blank, colored easel; undo/redo cannot duplicate finished art.
Legacy homes without easels still load. Packing a picture does not claim care
coverage or suppress an unmet-need cue.

Native injected-input flows passed at 1440×900 and 1280×720 / 125% UI scale.
They buy an easel, preview subjects without mutation, paint all three miniatures,
inspect accepted progress and Plan timing, cancel/resume, rotate through all
orientations, sell and undo the whole easel, pack individual pictures, restore a
snapshot, inspect a neighbor's easel, and verify exact pending-command feedback.
The final compact layout keeps its heading and all three subject buttons visible
together. Both native layouts check painting and packing events through the live
mixer, with separate poses and cues. Reviewed captures are in ignored
`build/paintings-*.png`; no human listening assessment is implied.

The added real Iroh host/two-client scenario passed independently, including
parallel household canvases, partial and finished reconnect retention, duplicate
and stale rejection, author credit, journals, and exactly one payment per sale.
The complete regression run passed both the original multiplayer scenario and
this painting scenario, followed by dedicated-server startup. The preceding construction-access checkpoint passed
all four platform CI jobs. Physical-device, human-family, and overnight-hosting
checks remain open.


## Household wall art and safe transfers

All 72 local suites passed. The new model suite checks owner/build/revision
permissions, solid-wall placement, occupied walls and windows, exact picture
retention, free transfers, history, discard, committed versus draft saves,
legacy collection defaults, and JSON restoration. Demolition, doorway placement,
and fitting a window move mounted art into storage. Return requires an empty
easel and advances its canvas revision. Full collections allow existing pictures
to move; new entries stop at 64. Malformed, duplicate-position, unfinished, and
oversized saved collections are rejected atomically. Actual room copies in all
four rotations leave earned art in place and make blank easels.

Native injected-input flows passed at 1440×900 and 1280×720 / 125% UI scale.
They paint, enter construction from the easel, preview valid and window-blocked
walls, hang, move, store, undo/redo, replace a picture's wall with a window,
return art to an empty easel, and begin another canvas. Pictures remain pickable
on cutaway front walls. Visitors see art and creator credit without ownership
controls. Exact command correlation keeps unrelated failures and early success
replies from clearing pending edits; unrelated revision changes do not fabricate
a successful transfer. Reviewed captures are in ignored `build/wall-art-*.png`.
The compact layout initially hid collection actions below the fold; the final
native passes verify both Store and Return to easel remain visible together.

The expanded real Iroh painting scenario passed with two independent clients.
Each hangs, undoes/redoes, stores, rehangs, and reconnects with the exact mounted
picture and blank easel. Returning and selling then pays once. The full regression
run also passed the original Iroh scenario, this expanded painting scenario,
and dedicated-server startup. The preceding painting checkpoint passed all four platform CI jobs. Human-family,
physical-device, and overnight-hosting checks remain open.


## Painting as a lasting hobby

All 74 local suites passed. The painting-hobby model suite checks shared
completion credit, cumulative work
across cancel/resume, a short contribution that earns no practice, daily caps,
new-day renewal, rank journals, and actual novice/expert need recovery. Artwork
duration and the §60 sale remain unchanged. Hanging, returning, and selling do
not award practice again. Old three-hobby boards retain every existing value
and acquire a zero-progress painting entry; old artist credit remains valid
without inventing measured contribution time. Malformed contribution amounts,
unknown or incomplete hobby boards, and oversized totals are rejected atomically.
Absence neither advances nor removes hobby progress.

Native injected-input flows pass at 1440×900 and 1280×720 / 125% UI scale. They
open the relevant easel from Hobbies without mutating the world, interrupt a
canvas, switch housemates, finish shared work, inspect both progress entries,
reach rank two, and open painting progress directly from the easel. A camera
viewing another lot still opens the selected resident's actual easel. Visitors
receive an ownership explanation. The first compact attempt exposed subject
buttons pushed below the fold by the new rank link; moving it below creative
actions preserves all three subjects together. Final captures also show the
unfinished-canvas contribution hint and focused painting card. Reviewed images
are in ignored `build/painting-hobby-*.png`.

The expanded real Iroh test passes two independent households, each with two
qualifying contributors. Contribution time survives the partial-work reconnect;
both practice entries survive finished-work reconnects, wall transfers, and sale.
The complete regression also passed the original Iroh scenario, this expanded
painting scenario, and dedicated-server startup. The preceding wall-art checkpoint passed all four platform CI jobs. Physical
devices, human-family playtesting, and overnight hosting remain unverified.


## Original paintings through the mailbox

All 76 local suites passed. The new model suite checks delivery from a finished
easel, onward gifts from a
mounted collection entry, original creator/content retention, exact once-only
collection, and save/load at both escrow and collected stages. Full mailboxes,
full collections, construction, stale canvas identities, stale lot revisions,
foreign sources, malformed choices, queued sales, and duplicate sends all reject
without consuming art or postcard allowance. Collection waits safely during
construction. Existing money-gift behavior remains covered separately.

Save validation now checks physical artwork custody across finished easels,
collections, and unclaimed gifts. A picture cannot occupy two places. Collected
postcards retain a receipt preview that cannot be claimed again, including after
onward gifts. Invalid payloads and duplicated custody reject the whole candidate
save. The longest bounded postcard plus painting references fits the existing
1024-byte command limit; clients never submit an authoritative picture payload.

Native injected-input flows passed at 1440×900 and 1280×720 / 125% UI scale.
They preview a gift, reject a stale selection, deliver to an absent household,
read home news, defer collection through construction, collect, hang through
the receipt's direct action, and send the original onward. Exact acknowledgements
ignore unrelated failures and wait for accepted state after an early success.
Screenshot review moved Send/Collect/Hang/Archive into a fixed footer, then put
recipient and gift choices side by side so the compact composer shows its
preview and credit before sending. Native assertions check these visible bounds.
Captures are in ignored `build/art-gifts-*.png`.

The expanded actual Iroh scenario passes two households exchanging finished
pictures, with the first disconnected when delivery occurs. Unclaimed art
survives another reconnect, both clients collect once, retain the other family's
artist credit, arrange the gift, reconnect with mounted art, and eventually sell
it once. Hobby practice is unchanged by the exchange. The complete regression
also passed the original Iroh scenario, the expanded painting scenario, and
dedicated-server startup. The preceding painting-hobby
checkpoint passed all four platform CI jobs. Human-family, physical-device, and
overnight-hosting checks remain open.

## Admiring mounted artwork

`tests/art_admiration.gd` checks real front-facing viewing paths on both wall
orientations, obstruction, full and duplicate plans, stored and missing art,
owned-resident authorization, malformed coordinates and task fields, bounded
need recovery, full-need duration, unchanged ownership/funds/hobbies, and
ordinary cancellation. Runtime snapshots validate and complete after JSON
round-trip; malformed snapshots reject atomically. Gifting an original ends a
walking viewer's current action and a later queued viewer's action without
substituting a different painting. Construction recalls visiting viewers safely.

The native `art_admiration_ui` flow passed at 1440×900 and at 1280×720 with the
compact preference profile. It checks actual wall and button clicks, the named
plan, activity feedback, Recent, visit-first explanation, visiting recreation,
construction recall, and a blocked-view explanation. Pending state ignores an
unrelated rejection and remains pending after an early matching success until
accepted state arrives. Screenshot review led to a shorter compact live preview
and note; both actions and their benefit now fit without scrolling. Both final
layouts passed again. `build/art-admiration-*.png` contains the ignored captures.
These are native automated playtests, not human-family observation.

The full run passed all 78 local suites, both real Iroh scenarios, and dedicated
startup. `paintings_peer` now coordinates two open homes, reciprocal visits,
queued admiration and duplicate rejection, host-confirmed completion, preserved
art ownership, and return home before the existing arrangement/reconnect/sale
checks. The preceding original-art gift checkpoint passed all four CI jobs.
Physical-device, human-family, and overnight-soak evidence remains open.

## Shared meals and reserved portions

`tests/meals.gd` checks authoritative preparation, carrying, serving, single
payment and cooking credit, cancellation before serving, runtime snapshots at
both preparation stages, and saved leftovers. It rejects malformed recipes,
commands, table references/batches, task durations, portion counts, and inconsistent
claimed portions. Four diners reserve four portions before arrival; a fifth
cannot overbook. Cancellation releases an unclaimed portion. Diners occupy
separate places, recover hunger/comfort/social, and record shared-meal
friendship without earning cooking practice for eating. Hunger care can choose
ready food. Visitors cannot prepare or clear another home's meal. Leftovers
survive absence, construction recalls visitors, stale batches reject, and table
sale/Undo restores food. Actual room copying creates an empty table.

The `meals_ui` native flow passed at 1440×900 and 1280×720. It buys and places a
dining table, previews recipes, prepares food, shows a named plan, checks the
served platter/count, joins a meal through People, eats together, clears
leftovers, visits a neighbor's table, and is recalled during construction. It
also tests unrelated and early acknowledgements. The final runs include the
actual preparation recipe in the preview and the Clear leftovers wording.
Bounds checks keep recipe/payment information and both ready-food controls
visible. Captures in ignored `build/meals-*.png` were visually reviewed.

The separate-process `meals_peer` scenario passed a real host and two clients:
four residents from two owned families reserve and finish one meal at distinct
places. Guest preparation/clearing and duplicate eating reject. Another meal
is served; its owner disconnects, the visitor eats one portion, and the owner
reconnects to the preserved three portions with the original cook credit.

Final regression evidence covers all 80 local suites across the initial run and
its focused continuations, plus the original Iroh scenario, painting/gifting/
visiting scenario, new meal scenario, and dedicated-server startup. The final
model check includes stable action identity and portion consistency, and the
focused friendship checks pass with the new Shared a meal history. The preceding
art-admiration checkpoint passed all four CI jobs. Native screenshots and
injected-input tests do not replace human-family play, device certification,
listening assessment, or an overnight persistence soak.


## Autonomous use of prepared food

All 81 local suites pass, including `meals_autonomy`: household-only selection,
prepared-food preference within hunger care, more urgent needs, reserved last
portions, occupied/unreachable places, manual interruption, autonomy off,
construction, disconnection, guests, caretaker preservation, and no automatic
rewards or ingredient spending. Walking and consumed-portion snapshots round-trip;
saved worlds clear unfinished plans without returning already eaten food.
Valid deliberate preparation cannot be relabeled as automatic in a snapshot.
The final focused test and editor import pass.

The standard and compact native meal playthroughs pass with real injected mouse
input. They prepare food, toggle both housemates' autonomy through Plan, observe
shared eating and portion counts, and stop one diner without returning a used
serving. The two captures in `build/meals-autonomy*.png` were visually reviewed.

The extended real Iroh meal test passes on one host and two clients. After the
existing visit/absence/reconnect sequence, hunger is seeded on the authoritative
host; clients toggle their own autonomy through acknowledged commands. Both
clients see two automatic diners and the same single remaining portion. Stopping
them neither consumes another serving nor changes funds. This adds network
coverage for the new automatic task validation; it does not establish physical
Android cross-play or overnight persistence.
