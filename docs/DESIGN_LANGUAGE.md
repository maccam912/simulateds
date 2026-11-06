# Simulateds design language

## Activity commitments and progress

Keep wish flavor titles, but show the concrete activity and target, selected
resident, queue commitment and game-time bound before activation. Meal wishes
state that they open a table or Build without buying food or furnishings.
Suggestions use the host's selection rules and reject a changed reviewed target.

Garden readiness uses game time with continued-watering, dry and pause qualifiers.
Meal portions distinguish available, reserved and taken, with named participants
and their actual plan status. These panels read accepted state; refresh cannot
consume food, reserve a place or advance growth.

Art originals use furnishing/collection locations and a camera-only Find action;
coordinates belong in optional details. After delivery, a modest recipient note
uses the actual receipt and artist credit. Preserve exact-original review and
the permanent-removal warning. See [the activity review](ACTIVITY_CLARITY_QA.md)
for findings, validation and explicitly deferred content/animation expansions.

## Painting at the canvas

Route deliberate painting and packing to the easel's open canvas side. The host
checks that side and construction access explains it; rotating or clearing space
repairs an inaccessible easel. Existing pictures and artist credit are retained.
Older active side approaches reroute on the host before adding work.

Arrived painters face the canvas with a held solid brush touching its surface.
Use an oak step for shorter residents, preserving their body proportions. Feet
and the step stay still while the wrist and brush make a small stroke driven by
game time; pause and reduced motion hold it steady. Props clear immediately on
cancellation, completion, packing, construction or stale targets. Rendering,
labels and picking follow the visible body without changing paths or canvas
progress. Step entry/exit choreography remains separate. See
[the painting contact review](PAINTING_CONTACT_QA.md).

## Watching television

Use a nearby reachable seat facing the screen when available. The host reserves
the seating furnishing while the viewer walks and watches; ordinary seat use
waits, and other viewers can stand at a clear front-side place. Name Seated or
Standing in the existing activity strip. If no viewing place exists, explain
that the television needs clear space in front and can be turned in Build.
New starter TVs face the sofa. Disk loading repairs the backward TV only in an
untouched original starter layout; any construction history protects the home.

After arrival, show the resident resting on the actual cushion/slats with bent
knees, unchanged body proportions and relaxed arms. Labels and mesh picking
follow the visible body. Cancellation clears the pose immediately, while world
positions, routing and task timing remain authoritative. Reduced motion holds
the same steady pose. See [the TV review](TELEVISION_QA.md) for reservation limits,
legacy-save behavior and the separate entry/exit choreography work.

Ordinary relaxation shares the same single-user seating reservation. A second
resident waits in place, with the current user's name and furnishing in their
activity strip and Plan. Cancellation or completion releases the furnishing;
waiting does not restore comfort. This applies to sofas, chairs and benches,
including wide furnishings until independent cushion positions are supported.
Existing overlapping saved activities are revalidated on solo load, with the
interrupted activity explained through the normal load notice and Recent history.

## Places at the dining table

Accepted eaters use a small oak stool at their reserved dining cell, facing its
table edge. Each has a plate with the served recipe and a quiet hand-to-plate
gesture. Child-height seats and footrests support the existing body proportions;
do not scale a resident to fit the table. Stools and settings appear only after
arrival and consumption of a portion, including when no servings remain on the
shared platter. They are activity props, not purchased or independently usable
furnishings. Cancellation clears them immediately. The simulation still owns
places, portions, paths and timing; reduced motion holds a steady dining pose.
See [the dining review](DINING_QA.md) for scope and validation.

## Shower occupancy

During an accepted shower activity, the clothed resident stands in the tray and
faces the mixer. Lower the opaque enclosure like the house's cutaway walls so
the occupant remains visible and selectable, including children. Restore the
full enclosure when use ends. Sparse water geometry and a small washing gesture
follow simulation time; reduced motion keeps a steady cue. Positions used for
pathfinding and reservations remain authoritative approach cells. Entry/exit
choreography is still open; see [the shower review](SHOWER_QA.md).

## 3D asset production

The world is rendered with mesh models, a true orthographic 3D camera, depth and
lighting. [ASSET_GUIDE.md](ASSET_GUIDE.md) defines the current geometry, scale,
material, provenance and review requirements. Its 3D instructions supersede
older implementation references below to drawing world shapes or silhouettes.
The UI palette, interaction rules and domestic theme still apply.

## A lived-in neighborhood

Linden Grove should feel like an early-2000s neighborhood seen through a sunny
window: small houses, practical furniture, people with ordinary routines, and
room for domestic comedy. The camera and sound establish a place. Interface
controls help the player inhabit it.

The game world fills the viewport edge to edge, including wide displays. HUD
controls float over it. A menu, catalog, or conversation must not shrink the world
into a dashboard panel. Keep the ordinary play view quiet: household, current
activity, mood, time, money, and a few actions. Needs expand on request. Open neighborhood navigation and
the catalog only when requested. Menu copy names an action or explains a state;
avoid promotional taglines inside the game.

Solo time controls sit beside the clock: pause and three explicit rates. Brass
marks a deliberate pause; leaf marks the selected running pace. The clock also
says “Paused,” and the status line names the key that resumes it. Menus preserve
the chosen pace. Residents' movement and activity animations follow simulation
time, while camera, interface transitions, and music remain responsive at their
usual rate. Shared play disables these controls with an explanation and labels
the common clock. No extra frame or permanent modal layer is needed to pause.

This is original game content. The period reference is an approach to readability,
pace, and domestic life, not permission to copy another game's art, audio, or UI.

## Palette and surfaces

The implementation's shared tokens live in `game/style.gd`.

| Role | Starting token | Use |
| --- | --- | --- |
| Ink | `#142329` | Deep background, field interiors, high-contrast lettering on light controls |
| Slate | `#1b2d34` | Control surfaces and secondary actions |
| Edge | `#30444a` | Quiet dividers and recessed borders |
| Paper | `#f4f0df` | Main text; warm enough to sit with wood and sunlight |
| Muted | `#a4b8b8` | Labels and secondary information, never essential low-contrast errors |
| Leaf | `#b9dc8e` | Healthy needs, accepted actions, primary control accents |
| Brass | `#edc98b` | Money, selection, caution, and construction |
| Terracotta | `#df9785` | Rejected actions and low needs, always paired with text |

Controls use compact rectangular surfaces, thin borders, small corners, and
subtle depth. Translucency can preserve the landscape behind the HUD, but text
surfaces must remain dark enough to read over pale floors. Do not place text
straight over animated grass without a backing or a dependable shadow.

Needs are inspection controls: hovering explains the proposed care action, and
activation opens Care without issuing an order. The tray names the resident and
activity; choosing that named activity adds it to Plan. Unavailable choices explain
what is missing. The mood summary comes from current needs rather than an extra hidden
meter. Low moods use explicit text with terracotta/brass, never flashing alarms.

Use the world for richer color: oak, worn painted wood, cream plaster, terracotta,
green planting, and soft blue upholstery. Increase detail around objects that
residents use. Avoid decorative UI noise that competes with those objects.

The decorating palette uses nine floor finishes and nine wall treatments. Woods use
board seams, tiles use grout/checkers, and carpet uses restrained flecks. Swatches
show names as well as colors. Preview surfaces directly on the house before
purchase, with an exact price and an area outline. Night lighting warms finishes
gently enough to preserve the player's chosen hues.

Floor finishing offers Area and Room beside the per-tile price. Room previews
the actual floor with a boundary at floor level, behind the furnishings. Avoid
drawing a grid over the furniture. An unaffordable room keeps its original finish
and shows the selected extent with a warm warning and exact shortfall. Matching
finishes get a quiet no-charge response. Walls, doorways, and missing floor bound
the room; furniture and residents do not. Keep all nine swatches visible at the
compact size, and retain keyboard focus when selecting a mode or finish.

Hobby cards name an interest, its current title/rank, practices toward the next
rank, and the actual benefit. Buttons describe activities rather than XP farming.
At the daily limit they still allow recreation; the card says more practice is
available tomorrow. Rank changes use one modest confirmation sound and a short
notice, plus a saved journal memory. No streaks, expiry, or recurring reminders.

The build catalog keeps one compact category selector and one persistent search
field above the scrolling results. Two-column cards show a studio picture of the
actual model, its name and price. Footprints and use stay in the selected-item
details and tooltips. Room/use categories include Seating and Lighting, with all
chairs and sofas together. Selected-item details and edit controls stay below the
results, so scrolling never hides Undo or the chosen item's cost. Search refreshes
must retain focus and caret; empty results offer an explicit way back to All.
Popup menus use the same ink, cream, and leaf colors as the rest of the HUD.

Drag a furniture card onto the lot to purchase; Move lets the player drag an
existing piece. Right-drag horizontally rotates a pending piece in quarter turns,
with the existing rotation button/keyboard option retained. Residents remain
visible while paused and move to the street only when construction displaces
them. They never make a placement preview invalid.

The View row selects among three storeys with minus/plus, without issuing an
order. A separate live Travel group names the selected resident and their floor;
Go downstairs/upstairs adds an explicit order, with host-shared availability
reasons. The location heading always names the viewed floor. Accepted Finish or
Discard returns to the selected resident’s floor, reframing when the floor or lot
changes and otherwise preserving the player’s camera. Higher-floor views
retain lower geometry and a real stair opening. Pools, 45-degree walls and round
terrain brushes use the same warm preview/cost/undo language as room building.
Brushes follow the pointer stroke and preserve level foundations. Windows have
real openings and daylight-scaled interior lighting; lamps cast warm local light
and shadows. Verify actual day/night and compact-window scenes before describing
the lighting or new model library as visually reviewed.

## Typography and layout

Use one legible interface family and a system monospace face for development
output, falling back to the engine font where necessary. No downloaded font is
required by the foundation. Favor sentence case for actions and names; use small
uppercase labels sparingly to identify groups.

| Element | Baseline size | Behavior |
| --- | --- | --- |
| Screen title | 28–36 px | One per menu, short and specific |
| Panel title | 18–22 px | Distinguish panels without oversized branding |
| Body / buttons | 14–16 px | Enough room for localization and rebinding labels |
| Secondary labels | 11–13 px | Supporting detail, not the sole source of critical information |
| Console | 14 px monospace | Literal output, selectable, consistent command alignment |

Use a 4 px spacing rhythm: 8 between related controls, 12–16 inside groups, 24
between sections. Menus need a strong default focus and visible keyboard focus.
Settings should show their current value, not just a slider position. Controls
must remain usable at the supported UI scales; scroll long content instead of
shrinking its text.

Independent text enlargement is deferred pending shared text-size tokens and
catalog/HUD reflow; the current whole-interface scale is not a text-only option.
See [the accessibility review](ACCESSIBILITY_REVIEW.md) for the decision and
remaining screen-reader/listening verification. Settings starts at its tab bar,
names sliders and pickers for assistive technology, and scrolls to keyboard focus.

## Construction access

Construction access is an optional view of the home. Tint connected floor green
and disconnected floor coral, with a warm entrance marker. Numbered problems link
the world to a scrollable list, so color alone never carries the diagnosis. Keep
badges separate and connect displaced markers to their objects. Find centers the
camera without changing resident selection; reduced motion makes it immediate.
The report shares the host's reachability rules and updates with accepted edits.
It checks all three floors, while tint and markers belong to the viewed floor.
Find names and switches to the problem’s floor. Untouched upper levels say
Unbuilt, with no entrance defect; stair openings and landings have their own
locations. Sheltered residents are moved safely aside on Finish and do not block
a valid draft. The optional Guide → Building checklist explains flooring, stair
openings, landings and access without purchasing or creating an example home.
Inspection absorbs placement clicks, while repair tools return to editing with
the overlay still visible. Escape or the close button leaves inspection. A
rejected Finish building opens the same report instead of leaving a text-only
error for the player to decipher.

## Motion

Gardens show the result of a resident's effort in the world: raised wooden beds,
dark watered soil, small shoots, taller foliage, and visibly ripe vegetables.
Dry soil lightens without making the plant look dead. A small brass exclamation
or check marks water needs or readiness, with explicit text in hover and the
garden panel. Growth and water use separate bars; neither requires interpreting
color alone. Planting uses a hand trowel, watering a can, and harvesting a basket.
The panel keeps controls stable while growth updates and names the resident who
has reserved the bed. Crop ownership is explained directly when visiting.

Motion acknowledges a change and lets the player track it. It must not delay an
action or make the player wait through repeated introductions.

- Hover/focus feedback: immediate color change or a 70–100 ms transition.
- Opening a tray/dialog: 120–180 ms fade with a very small displacement if useful.
- Closing: 100–140 ms or immediate when input ownership changes.
- Main-menu transition: 220–300 ms fade; the background remains a place.
- Save feedback: brief confirmation, then return to normal. No false progress bar.
- Resident movement and interaction express the active task and stop when the
  task changes. Walking follows accepted routes; resting uses the furnishing;
  simple props distinguish everyday activities. No bouncing of the whole HUD.

Reduced motion removes slides, scale pulses, and camera flourishes. Essential
state changes remain immediate. Splash screens are skippable; loading indicators
report real work rather than holding the player for a fixed presentation beat.
The foundation console uses a short fade and immediate safe close. Reduced
motion also bypasses movement interpolation and freezes decorative activity
motion. Accepted simulation positions and activity state remain authoritative.
The Comfort label is **Reduced motion**, with visible copy explaining menu fades,
camera focus, resident motion/turning and shorter audio crossfades. Manual camera
control, time-driven lighting, static activity poses, cues and simulation timing
remain available; reduced motion is not a pause or a sound-mute setting.
Facing follows each displayed route leg, then the furnishing or actual conversation
partner. Turn briefly (up to about 150 ms for a right angle), preserving the last
idle direction. Reduced motion sets the same direction immediately. Front, side,
and rear silhouettes use the shared appearance palette, with directional strides,
arm depth, collars, hair, eyes, and props. Seated residents face the sofa's open
side in every rotation; sleeping poses remain aligned with the bed. No facing
fields belong in saved worlds or network commands.

A conversation uses one small bubble above the pair. Reserve resident heads and
bodies before fitting bubbles and labels, keeping faces visible and clickable.
Resolve partners from live accepted activity state; stale action text must never
keep a departed partner in a conversation pose. Offscreen residents do not produce
activity bubbles at the viewport edge.

The shared clock drives a smooth dawn/evening palette and a cool night exterior.
Warm automatic home lights keep the cutaway interior readable. Street lamps add
small pools of light. Construction brightens the property grid at night, while
HUD controls and placement feedback retain their normal contrast. Lighting is
presentation only; it does not create an electricity or visibility mechanic.

New starter homes have a linen floor lamp beside the sofa, giving the sitting
area a warm focal light at night. Keep the existing cool ambient balance and
automatic readability fill; the actual movable fixture supplies the local pool
and shadows. Its fabric shade has a restrained glow in its chosen material color,
without recoloring neighboring furnishings or shared model materials. Low scenery
retains indoor fixtures. Existing saved layouts remain the player's own; no lamp
is silently inserted on load. See [the starter-light review](STARTER_LIGHTING_QA.md).

## Sound and music

Sound should make the house feel inhabited without making prolonged play tiring.
The first implementation uses original generated instrumental loops and sound
effects, with source generation retained for iteration. These are a starting
sound palette, not a claim of finished recorded instrument quality.

Music direction: soft plucked/piano-like notes, restrained warm chords, modest
bass, and ample silence. A gentle menu motif can share harmony with live play;
build mode may be slightly more regular and focused. Avoid constant busy melody,
large volume jumps, or recognizable quotations from existing game soundtracks.
Ambience should sit behind music: a little air, occasional birds, and eventually
room-specific domestic sounds. The world must remain comfortable with music off.

| Event | Sound role |
| --- | --- |
| Hover / focus | Very quiet short tick; rate-limited to avoid a spray of notes |
| Click / open | Soft tactile tap, shorter than the visual transition |
| Accepted action | Small warm interval, low emphasis |
| Rejected action | Gentle lower cue, not an alarm; accompany it with a useful message |
| Place furnishing | Soft wooden placement / rounded knock |
| Save succeeds | Brief resolving chime, only after a successful write |
| Menu / live / build context | Context loop changes with a short fade, preserving level |

Provide independent Master, Background music, Household stereos, Effects, and
Ambience levels. A zero slider
must be silent. Headless hosts do not create audio playback. Important
information is never conveyed only through sound. Later recordings and richer
ambience should retain these bus boundaries and comparable loudness.

## Reading the residents

Draw the selected resident's name and marker after furnishings so a tall shelf
cannot hide who is selected. Small cream thought cues appear only for a pressing
unmet need in the player's own household. Each uses a name, a simple drawn icon,
and plain words; color is supplementary. Covered or queued care stays quiet.
Cues can request the ordinary care command, preserving the player's existing
plan and explaining unavailable furniture through the existing care tray.

Nearby labels separate rather than overlap, long names truncate with the full
name on hover, and night colors keep readable contrast. Cues do not blink or
bounce. Construction, menus, and offscreen actors leave no floating controls.
A double click on a disappearing cue must never fall through into an extra order.

Finding a resident uses one brief 200 ms camera move, preserving the player's
zoom. Reduced motion snaps immediately. Selecting someone already visible keeps
the composition; clicking the selected household name again explicitly centers
them. The Plan tray and a rebindable shortcut provide the same action. Panning or
zooming cancels the movement immediately. Changing lots resets the pan while
retaining zoom. More → Home overview returns the camera to the home's ground
floor and fits its floors/walls between the fixed HUD rows, without moving the
selected resident. Fresh entry and saves without camera framing use this fit;
saved zoom/pan take priority. Empty homes use the whole-lot fallback. The fit is
explicit, never a continuous follow or a reframe on ordinary snapshot updates.
Resolve current snapshot positions
when finding a visiting resident; camera actions never issue simulation orders.

Plan arrows revise only upcoming activities. Keep the current activity visually
distinct and never offer to reorder it. Retain focus on the edited action and
keep it in the scroll view, including when a boundary disables one arrow. Host
confirmation controls the visible order; a changed plan gets a useful rejection.
Confirmation messages sit beside an open Plan tray and grow upward above the
household controls, so feedback cannot cover the next edit.

Within the active Plan row, travel and waiting use plain status text. Only an
activity in progress gets a thin determinate bar and an approximate remaining
time in neighborhood-clock minutes. Derive progress from accepted state and
shared restoration rules; no local timer can run ahead of a paused world or
stale snapshot. Update existing labels and bars so focus and scroll stay put.
An idle conversation partner is still participating and should be described as
chatting rather than free. Keep all of this inside the optional Plan tray.

## Familiar routines

Plan may offer one optional time-of-day idea from the household's saved recipes.
Morning care, a daytime favorite pastime and evening/night wind-down are reasons
to review an existing sequence, never an automatic schedule. Use the actual
edited name and steps, omit an idea when no recipe fits, and let the library
explain missing furnishings or a full plan. Review sends no command; only Add to
plan starts work. Preserve an open draft and keyboard focus. Keep suggestions
out of Recent and retain the selected resident's ordinary autonomy control.

Automatic Plan rows may name matching favorites, traits and likes/dislikes from
the saved profile. These describe affinities, not a claim about why a particular
choice won: urgency, useful needs and available furnishings still matter. Keep
full text on hover and avoid inventing relationship consequences. See
[the daily rhythm review](DAILY_RHYTHM_QA.md) for measured full-day behavior and
the deferred scheduling, economy, family-interaction and recap proposals.

Recent outcomes belong inside the existing Plan tray. A **Recent / Upcoming**
switch keeps the live queue as the default and adds no persistent HUD panel.
Show eight deliberate actions at most, newest first, with plain status words,
a concrete reason, and neighborhood day/time. Green means done, muted means
cancelled, and gold means interrupted; the words carry the meaning independently.
Keep reasons wrapped, full titles in tooltips, and routine provenance beside the
time. Switching residents starts at their newest result. Ordinary snapshot
refreshes preserve rows, scroll, and keyboard focus. Automatic care never fills
the history, and reading it never reissues an action or spends household money.

**Use current plan** starts a draft from accepted activities on the selected
resident's current lot. Include the active deliberate activity and upcoming
care/recreation in order, including repeats. Explain every omitted walking,
conversation, crop, automatic, or missing-target action by its original plan
position. Never silently trim a long plan: retain all reusable steps locally and
require the player to reduce it to six before Save becomes available. Show who
the draft came from and make clear that the live plan keeps running. Changing
residents or receiving a new snapshot cannot rewrite an open draft. Use the
existing name, reorder, remove, Back, and host-confirmed Save controls.

Keep reusable care and leisure sequences inside **Plan → Routines**, in one
floating library/editor over the live world. Warm names such as Morning care and
Wind down describe a familiar part of the day. Show the ordered activities and
current availability before Add to plan. The library belongs to the household;
the selected resident receives the orders. Do not introduce another permanent HUD
island, automatic schedule, or separate activity executor.

Four saved recipes of one to six activities are enough for this slice. Save a
local named draft explicitly, with up/down arrows and keyboard activity pickers.
Opening another tray preserves the draft; Escape from editing returns to the
library, then Escape returns to Plan. Normal UI audio and the existing brief tray
fade apply. Typing and clicking the exposed world must not issue gameplay orders.
Keep pending changes locked to their own command reply, retain drafts on rejection,
and show a stale-library explanation rather than replacing typed work.

Choose reachable furnishings afresh on the resident's current lot. Add every step
in order after existing manual work, or add none if a furnishing is missing or
capacity is insufficient. Busy private objects use ordinary waiting. Keep accepted
activities independent of later recipe edits/removal, with their original routine
name available in the Plan tooltip. Both residents can use a recipe independently;
a resident cannot add the same one again while it remains in their plan.

## Everyday personality

A favorite pastime is a preference, not a level or a reward multiplier. Reading,
television, gardening, tea, and tabletop games influence choices only among useful reachable
activities. Urgent needs and deliberate plans take priority; “A little of
everything” keeps neutral choices. Edit the preference alongside names and looks.
Show it in the daily plan and explain autonomous favorite activities there, rather
than adding another persistent HUD panel. Existing saves remain neutral until
edited, and residents do not lose progress or earn unattended wish/hobby rewards.

The checkered game table is a recognizable wood surface with cream/teal squares
and warm wooden pieces. A small hand motion and sparse wooden click suggest play;
reduced motion holds the pose still. Hover gives the number of reserved places,
and the existing Plan row describes solo or shared enjoyment. A participant's
social thought quiets while they are actually playing with someone. Every player
chooses their own resident's participation, and leaving never cancels a companion.
Keep the shared activity in the house rather than opening a separate minigame.

People cards expose ongoing games with their place count. Keep Visit and joining
as distinct choices: a visit changes location, while joining appends a personal
activity. Use Join game, Queue game, In your plan, and Playing here to describe
the accepted state. A stale card reports that the game changed. Preserve keyboard
focus on the same person as their card updates, and reveal their name together
with the focused action when the card fits in the scroll area.

## Coming home

Return news belongs with postcards in Mail. A small badge offers an invitation;
no forced popup interrupts a visit, building draft, or startup. Recaps describe
recorded simulation time and actual credited allowance, separating gifts delivered
then from gifts still waiting now. Unread recaps combine; an explicit read action
clears the badge but keeps the history. Keep Open Inbox and Mark recap as read in
a fixed footer, with longer details scrolling above them. The host stopping means
the world waits, not an excuse to invent events or grant offline catch-up rewards.

## Screen and state grammar

| Screen | Purpose and behavior |
| --- | --- |
| Startup | A short, skippable identity moment over a neighborhood backdrop; reveal actual initialization errors plainly. |
| Main menu | Continue the current neighborhood, start a new one, browse saved games, change settings, or quit. The background is still the game world. |
| Pause / Escape | Resume, save, load, settings, return to the main menu, quit. Offline simulation may pause; shared hosting must continue and say so. |
| Settings | Clear Audio, Display, Controls, and Accessibility groups; immediate preview where safe; persisted values, reset defaults, and key-conflict feedback. |
| Save | Give a save a readable name, show the current world context, and report success only when the write succeeds. Overwriting is an explicit choice. |
| Load | Show the save name, in-game day and time, and local date and time with its UTC offset. Keep the exact UTC instant and full names in the tooltip. Unreadable saves remain visible with a reason; they do not replace the current world. |

Save rows show the saved neighborhood and, when it contains this profile, its
household name, resident count and funds. Clip long names in the row and keep
them in its details. House thumbnails and a recent-activity preview are deferred;
the saved identity works for older slots without any captured image. A new
named copy stays highlighted and keeps its name in the field. An overwrite
confirmation names the slot it will replace; rejection leaves the draft and
selection in place. After replacing a world, the ordinary notice links to the
previous neighborhood's recovery save, which also has a shortcut in Load.
| Guide & controls | Optional, reopenable pages for the first day, building, neighbors, and current key bindings. Links enter real controls; reading help never grants progress or rewards. |
| Developer console | Literal command input, help, bounded history, Tab completion, readable results. It blocks gameplay input while open. |

The first-day guide offers suggestions in any order. New-neighborhood setup has
an explicit opt-out, remembered on the device; existing saves never open help
unexpectedly. Guide links explain unavailable actions during construction or
joining, and opening a catalog preserves a draft already in progress. Controls
show both rebound keys and the Escape/F1 rescue bindings. Keep help in the menus,
not as another permanent panel over the house.

The developer console intentionally exposes cheats such as `rosebud` during
iteration. It invokes a bounded command registry rather than evaluating scripts
or shell commands. In a shared world, simulation-changing commands go through
the authoritative host; a client must not silently edit its local replica.

## Implemented foundation

- `game/app.gd` owns startup, main/pause/settings menus, save/load browsing,
  confirmation screens, and transitions. `game/main.gd` owns the overlay HUD and
  optional trays. Menu panels fade in over 180 ms; trays and the console use
  140 ms. Reduced motion bypasses those fades.
- `game/preferences.gd` persists Audio, Display, Controls, and Comfort choices
  separately from neighborhood saves. Current display controls affect fullscreen,
  vertical sync, frame cap, interface scale, and scenery detail; low detail omits
  peripheral trees. Escape and F1 remain menu/console recovery keys even after
  rebinding their primary actions.
  Creating a neighborhood and changing unrelated preferences preserve the current
  window size, position and native maximize/fullscreen state. Apply window mode
  only when loading/resetting preferences or changing the Fullscreen choice.
- `game/audio_director.gd` selects original 24-second menu, live, and build loops,
  with a garden ambience track. Normal context crossfades take 1.1 seconds. Five
  effect voices allow overlapping short cues; hover cues are limited to one per
  100 ms. The generator and asset notes live in `tools/generate_audio.py` and
  `assets/audio/README.md`.
- Button hover/click, command confirmation/error, saves, and authoritative
  furnishing placement have sound hooks. Visible walking and activities now add
  sparse positional accents: wood/grass footsteps, pages, water, tea/cutlery,
  fabric, game pieces, and abstract conversation/television textures. A four-voice pool keeps
  them separate from UI cues. They follow accepted task progress and displayed
  movement, stop offscreen or behind menus, and respect Effects/Master mute.
  Reduced motion retains audio. Actual room acoustics, continuous appliances,
  and recorded voice/instrument performances remain future work.
- `game/debug_console.gd` provides literal selectable output, a 50-command
  history, 180 retained log entries, completion, and a 256-character command
  limit. `game/debug_commands.gd` owns the explicit command registry and
  host/local mutation checks. Opening a menu or console pauses local simulation;
  it leaves host simulation and network polling running.

## Foundation and next art pass

The current work establishes tokens, edge-to-edge presentation, menu/settings
scaffolding, audio buses and original prototype sounds, and development tools.
The visual style of existing furniture remains intentionally simple. Subsequent
passes can add character poses, object-specific animations, richer materials,
room ambience, recorded instruments, and title illustration. Each addition should
serve a readable action or a sense of place, and use the same settings and
accessibility controls rather than adding a separate presentation system.

## Current visual reference

Screenshots captured from the running Godot application are in `docs/screenshots/`:
[startup](screenshots/startup.png), [main menu](screenshots/main-menu.png),
[pause](screenshots/pause.png), [audio](screenshots/settings.png),
[display](screenshots/display.png), [bindings](screenshots/controls.png),
[save](screenshots/save.png), [load](screenshots/load.png), and
[console](screenshots/console.png). These are the implemented foundation, not mockups.


## Movement intent

Hovering exposed ground shows a thin floor-level route for an immediate walk,
a destination ring, and the step count. A queued walk uses gold and explains how
many planned activities precede it; it does not invent a route from an unknown
future starting position. Occupied, disconnected, full-plan, and visit-first
cases explain the same constraints that the host enforces. Hovering a resident's
name or an object retains its selection/use feedback instead of offering a walk.

Accepted manual walks own their destination markers. A current destination stays
visible, a new queued destination appears for three seconds, and opening Plan
reveals queued stops with numbers matching its rows. Multiple orders at one tile
share a marker with combined numbers. Paths draw beneath furniture/walls and
include any still-interpolating accepted steps before joining the remaining route.
The plain watching view hides paths and expired queued confirmations. Cancellation,
travel, construction, menus, and selection changes clear irrelevant feedback.
Reduced motion keeps this static information. Request acknowledgements alone do
not create markers: each one must exist in the accepted world snapshot.


## Windows belong to the house

Windows are mounted on existing walls, with three readable silhouettes: pale
cottage crossbars, a wood-framed picture pane, and garden-green shutters. Use
muted blue glass, a small upper reflection, a beveled frame, and a slim sill.
Night softly warms the glass with the existing domestic palette; this is
presentation, not a new room-lighting or simulation system.

Fit direction to the current wall run, including neighboring doors. Raise the
walls while the Windows tool is active so near-side placement remains visible.
During normal life and access inspection, near windows reduce to a glass sill
along with the existing cutaway wall. Avoid obscuring residents with full-height
near frames. Wall-face picking must select the mounted tile, even where that
face projects above a different floor tile.

Use a small catalog palette with all three priced styles and Remove window
visible together at compact size. Hover previews the actual style on the wall
and the exact net price. Replacing credits 60% of the previous window's cost;
removal keeps the wall. Door conversions and extension doorways also trade in
their window, and one Undo restores every layer and the exact budget. Missing
walls, insufficient funds, and unchanged styles have plain explanations and
cannot partly apply. Windows do not create passages or change room filling.
Keep the current style while waiting for a command; accepted snapshots determine
the fitted house. Use the established construction sound, with no extra ambient
loop or persistent HUD control.

### A music corner

The little hi-fi uses a low wooden cabinet, two dark speaker cones, and a small
sage display. A gold music note identifies accepted dancing nearby. Residents
stay in their reserved floor positions, facing the music, with bent raised arms,
a small alternating step, and restrained body motion. Reduced motion preserves
the raised-arm silhouette without rhythmic movement. Keep faces and the existing
name/need overlays legible.

Music is one positional source per viewed lot, not one track per dancer. Prefer
the selected resident's playing stereo, then a stable visible source. Keep its
original 100-BPM groove on Stereos, lower the background score beneath it, and keep
household textures on Effects. Changing or replaying a state snapshot must not
restart the song. People offers Join dance using the same voluntary, independently
owned participation as tabletop games; its label and occupancy explain the shared
activity without a separate social-game screen.

Background music and Household stereos have independent persisted levels, both
under Master. Legacy combined Music values initialize both controls, including
mute. Muting the score leaves the stereo playing; muting the stereo releases score
ducking. These preferences cannot stop a resident's accepted dancing activity.

### Places for company

Shared recreation reveals its space only while inspecting or arranging it. Draw
small floor diamonds with a ring for open floor, a solid gold dot for a reserved
place, a dash for a resident standing there, and a cross for blocked or unreachable
space. Pair these shapes with a short legend and a count based on reachability.
The physical layout and temporary reservations are separate: a stereo in a tight
corner can truthfully say Room for 1 / Solo only, without rejecting that choice.
A game table may have several possible floor positions but still hosts at most
four residents.

During placement and moves, inspect a copied candidate layout from the entrance.
In live play, use the selected resident's reachable area and accepted task
reservations. Approaching residents already reserve their destinations, including
places shared by adjacent furnishings. People, waiting feedback, and the world
markers use the same calculation as activity assignment. Paused command changes
must update markers without waiting for a simulation tick. Keep explanations
clear of the HUD and, where space permits, the activity and its floor markers.


### A small courtesy after play

Finishing shared recreation may include one visible step to make room for someone
already waiting. Treat it as a short, interruptible conclusion to the activity,
including when autonomous choices are off. Use the accepted ordinary walking
pose and footsteps; show Making room for [name] in the resident's status and Plan,
with a quiet courtesy label and the usual cancel control. Do not add a dialog,
a separate movement system, repeated retries, or a persistent request queue.
Explicit plans win, participating residents remain where they are, and a blocked
exit means no movement. Keep the completed activity in Recent exactly once;
the courtesy itself is neither a deliberate outcome nor a reusable routine step.


### Shared play builds a bond

Let voluntary play have a lasting social result. A chosen shared game or dance
qualifies after 12 game minutes actually spent together; both residents need
active deliberate participation. Use the same two-catch-up daily budget as chats,
one symmetric relationship, and the established milestone sound and journal
entry. Autonomous leisure, bystanders, travel time, and absent households earn
nothing. Choosing Join while already playing automatically turns it into a
new deliberate activity rather than trapping the player behind a disabled button.

People names the latest encounter (Last chat / Played together / Danced together),
its game day, and the remaining daily catch-ups. Keep those details on the person
card and explain the threshold in the existing footer; no separate friendship
currency or HUD gauge is needed. A shared activity can continue after it qualifies.
Repeated snapshots and the two participants' views must never duplicate its gain.

Ordinary catch-ups now use the existing floating notice above the household HUD.
Name the people and activity, then say that friendship grew. Its temporary
**People ›** button opens the primary relationship without issuing an order;
hovering shows all relationships in a grouped notice. Keep full names readable,
including with Plan open and enlarged text. The button disappears with the
notice, leaving no permanent HUD addition.

Collect simultaneous gains for 600 ms, prefer larger milestones and the selected
resident, and leave at least 2.5 seconds between notices. Protect recent command
feedback for two seconds and discard announcements older than eight seconds.
Use one existing confirmation cue per group, 6 dB quieter for ordinary catch-ups;
new acquaintances and larger milestones retain the normal confirmation level.
Effects mute leaves the text available. Menus, load/reconnect baselines, repeated
snapshots, absent-player progress, and the exhausted daily reward budget produce
no new celebration. Presentation never grants rewards or changes simulation.

### Repeat a room's design

Room copying uses the same world and catalog. Hover an enclosed interior to
highlight its extent; select it, then show the actual rotated floors, low walls,
doorway, windows, and furnishings at the destination. Keep the source visibly
highlighted. The preview label gives the complete total and separate structure,
furniture, finish, and window costs. Use the established green/red placement
colors and build sound, with no separate blueprint editor or modal confirmation.

The destination needs clear space and a usable route through the resulting lot.
Existing empty floor can be reused; walls and furniture cannot be overwritten.
Escape cancels selection, and one Undo restores the entire purchase. Source
revisions invalidate an old selection. The authoritative snapshot completes the
pending preview; unrelated acknowledgements cannot dismiss it. New furnishings
receive new identities, and garden beds begin empty, with that limitation named
in the preview when applicable. Saved designs and cross-lot copying remain future
work.

### Furnishing materials

Use one restrained palette across the home's furnishings: Original, Sage
(`#8fa985`), Sky (`#88a9bc`), Rose (`#c58f8d`), Honey (`#c9a363`), and Ink
(`#596d78`). Apply it to a named material, such as bedding or upholstery, with
small tonal differences between cushions and frames. Keep glass, foliage,
electronics, book spines, game pieces, and crop state distinct. Sleeping bedding
uses the same choice as the unoccupied bed. Original preserves the precise
existing rendering rather than approximating it with a shared neutral tint.

The catalog's Furniture colors tray shows all six labeled swatches together.
Hover an object to preview the actual material in the world, with a small outline
and a readable Free / Click to apply label. Apply with one click and use the
normal build sound and Undo. An unchanged choice creates no edit. This is a
personalization choice, with no purchase, resale premium, or care effect.
Previews must not mutate accepted state, and the pending appearance waits for
the matching host snapshot. Store only a bounded optional style name on the
furnishing, preserving it through moves, room copies, and persistence.


### Construction consequences

Show access consequences in the existing placement preview before purchase.
Green means the proposed layout retains access; amber means a valid draft edit
leaves a problem to repair; red still means the edit itself is unavailable.
Name a newly blocked furnishing or resident, then give a count for additional
problems. Say when a problem already existed, and recognize full or partial
repairs. Keep the flexible draft workflow and authoritative Finish building gate.

Tint newly disconnected floor amber and use at most six small exclamation
badges to locate affected furnishings or residents. These badges are visual
only: they must not consume placement clicks. Keep badges and explanations
clear of the HUD and each other. Draw the explanation after the placement
outline so geometry cannot strike through its text. When Access is open, show
the proposed layout's reachability, including a repair's restored route.

Forecast from a copied, validated layout using the same access rules as the
host. Hovering changes no funds, history, identities, or simulation. Invalidate
forecasts on layout, resident, tool, rotation, and world changes. The guide
explains all three placement colors in plain language.


### Building with a rectangle

Drag across the lot to fill a rectangle with flooring, draw its wall perimeter,
or sell and demolish its contents. A straight wall drag makes one run. Keep
existing doors when drawing walls. Show the price or refund before release and
record one undo step for the entire edit. A regular click still acts on one
tile or item. Room construction and finishes also accept a drag or two corner
clicks.

Use a ground outline for the extent, low wall ghosts for new walls, and coral
footprints for furniture in a sale. A furnishing touched by the selection sells
whole. Bulk sales protect unfinished canvases and store finished originals,
following the whole-lot clearing rules. Escape or release over the HUD cancels
the drag.

Perpendicular walls and their trim meet at one physical corner in both cutaway
and raised views. Match wall picking to the visible pieces. Preserve the
supporting face where a window or painting is mounted.

### A little studio at home

The Daydream easel uses the same warm wood and material palette as other
furnishings. Its original miniatures share muted colors with the neighborhood:
a green morning meadow, a blue harbor, and flowers in a teal vase. Draw a wash,
then broad shapes, then details as accepted progress advances; add a small
signature only when finished. The in-world canvas and tray preview use the same
art renderer. Recoloring changes the easel's wood, never the resident's picture.

Opening the easel starts at the top of the tray. Keep all three named subjects
visible together, with a smaller canvas preview in the compact layout. Hover or
keyboard focus previews a finished subject without changing accepted state.
Once work starts, show its actual progress and the names of contributing
housemates. Let unfinished work wait, and retain the finished piece on the easel.
A journal entry marks completion without requiring a popup or a reward claim.

Painting uses a small brush-and-palette pose and the sparse existing paper cue.
Packing a sold picture uses a wrapped-frame pose and fabric cue instead. Reduced
motion keeps the pose legible without moving strokes. A sale requires a deliberate
plan and completes before paying; its UI says that it frees the canvas. Selling
the whole easel in construction explicitly includes its canvas, and Undo restores
both. Copied easels are clearly described as blank.

Finished work can become part of the house: Hang on wall enters construction,
raises the walls, and previews the exact picture in its warm wooden frame. Use
the same miniature in the easel, frame, and inspection tray. Keep artist credit
and completion day visible; no invented rarity or appraisal score. When walls
cut away, the small framed picture remains visible and inspectable.

Wall art uses a household collection rather than a purchasable art catalog.
Hanging frees the easel, moving preserves the picture, and returning requires
an empty canvas. These transfers are free and undoable. A demolished wall or
new window moves its picture into storage, with a plain explanation in the
preview and result. Pending controls wait for the actual accepted placement.
Visitors can inspect a picture and its credit without seeing ownership controls.
Use the existing quiet construction cue; do not interrupt arranging with a
celebration.

The easel’s small rank link sits below creative actions, keeping subject choices
visible together in compact layouts. It opens the Painting hobby card directly;
that card returns to the selected resident’s easel without starting work. Show
rank, title, progress, remaining daily practice, and the benefit in plain words.
Both housemates can earn practice on a shared canvas: require 12 game minutes
of contribution and a finished picture. Interruptions preserve measured work,
while sales and arranging earn no practice. Improve fun and comfort as skill
grows; keep painting duration and sale value stable. Use the existing quiet
rank notice and journal entry instead of a modal reward screen.


### A picture in the post

Postcards can carry one finished painting from an easel, a wall, or the household
collection. The gift selector names its subject and current location. Show the
same miniature and artist credit before sending, plus a fixed explanation that
the original leaves the sender's home. If the selected canvas changes, require a
new choice; never substitute another picture or silently switch to a plain card.

Keep Send, Collect, Hang, and Archive outside the scrolling content. A received
painting sits beside its title and artist credit on the warm postcard paper,
ahead of the personal note. Collection is explicit; the next action takes the
player directly to wall arrangement in their own home. The receipt keeps a
preview after collection, but it is not another copy of the artwork. Home news
counts pictures waiting now without pretending they are money gifts.

Use the existing soft confirmation cue. Construction and full collections explain
why the original will wait safely; they do not discard it. Pending controls wait
for the exact reply and accepted state. Repeated collection never creates another
picture, and giving it onward preserves its creators.


## Enjoying a picture

Mounted artwork is an activity as well as an object to inspect. Keep the subject,
original credit, preview, Admire painting, and the selected resident's benefit
visible together. In the compact live tray, shorten the preview and redundant
ownership note so Arrange artwork remains visible too. Admiring is available to
visitors who have actually arrived; camera travel alone does not move a resident.

Use a quiet hand-to-chin pose, attention toward the visible wall face, and the
existing walking and UI audio. There is no applause or extra reward fanfare.
Reduced motion keeps the pose legible without animation. The plan names the
specific picture and shows fun, comfort, and remaining neighborhood minutes.
Completion appears in Recent; it does not interrupt with a modal or grant money
or painting practice. Full needs do not instantly dismiss the chosen activity.

Explain a blocked viewing spot, an existing plan, a required visit, and a changed
picture inline. Bind the order to the original and its mounted coordinates.
Losing the picture ends this activity, preserving later plans and the artwork's
actual owner. A construction notice explains why visitors returned home.


## Food made for company

The Gathering dining table uses warm wood, pale linen, individual plates, and a
small shared platter. The same original salad or sandwich art appears in the
inspection tray. Hover or focus a recipe to preview it; an active preparation
shows the recipe actually being made. Prepared meals retain their cook and day.
Show available and reserved portions separately so four diners never appear to
have claimed the same last plate.

A chosen cook works at the fridge, carries a bowl to the table, and serves it
before payment. Existing kitchen and tea sounds provide sparse texture. Eating
uses a bowl/utensil pose facing the table, distinct reserved places, and the
existing shared-activity overlays. Preparation and eating keep their named plan
and remaining time. Company is visible as Eating together and Shared a meal in
People; the existing daily friendship limits still apply.

Keep both recipe choices and the payment explanation visible at compact size.
Once food is ready, Eat a portion and Clear leftovers stay visible alongside the
count and benefit. Clearing means removing remaining food, never implied fridge
storage. A queued eater reserves food; arrival consumes the serving. Cancellation
before arrival releases the reservation. Guests choose their own residents and
cannot prepare with another household's funds or clear their leftovers. Food
keeps during absence, and room copying creates an empty table.

Hungry housemates with autonomy on can use available prepared food at home. The
same place and portion reservations apply, and the plan carries the existing
“auto” suffix. The ready-food tray explains this in two short lines alongside
its benefits. Guests still choose a portion explicitly; caretakers leave stored
food alone during absence. People → Join meal lets this resident choose an ongoing automatic meal without
claiming another portion. A player's next order or autonomy toggle interrupts
automatic dining normally; an already taken portion stays consumed. Ordinary spontaneous dining
restores needs without earning deliberate-play rewards.


## Choosing company at the table

An autonomous meal can become an intentional moment through Choose this meal on
the table or Join meal in People. The table explains “Keep your portion and
remaining time. Chosen company starts now.” Use the existing plan and progress
presentation, removing its auto suffix after the accepted choice. Do not restart
walking or eating, take another serving, or control the companion. Keep this
choice visible after the platter is empty while diners have its last portions;
do not prematurely replace it with recipe buttons.

The action binds to the current meal and resident activity. Stale or repeated
choices reject politely, and early acknowledgements wait for accepted state.
Friendship uses only newly chosen overlap; a late choice may simply finish the
meal without a catch-up. Meal wishes also require enough newly chosen time, including the final
qualifying step when a meal ends. No retroactive cooking practice
is granted for eating.


## Small wishes around meals

Keep the first wish set on starter-home activities. Later sets can ask for
Something homemade or Share a meal; existing sets and journals remain intact.
Both use the ordinary reward, set bonus, and later-day renewal. Cooking must
reach serving, not merely start. Shared company needs both diners to choose
participation for twelve game minutes; each reward belongs to that resident's
own household, independent of the pair's friendship budget.

Meal wish cards are navigation. Show Build table when equipment is missing,
then open Kitchen with the table selected and its real price visible. Otherwise
open the relevant table and frame it in the world. Cooking points to the owner's
home; sharing can use a visited table. Never select a recipe, spend ingredients,
or direct a companion just because a wish card was clicked. The card remains
usable to inspect an ongoing meal. At the table, show the unfinished meal wish's
rule beside its controls: serving for the cooking wish, and chosen company for
the shared wish. Completed cards, the HUD count, and the existing Little Moments
journal provide the reward feedback.

## Room design library

Saved rooms use small top-down floor-plan swatches beside their names. Floor
finishes, windows and material colors make the layouts recognizable without a
second live viewport. The catalog and library share the same floating tray;
placement stays directly on the full-size lot with its existing price and access
preview. Save forms collapse after acceptance. Rename and remove are local
review forms; remove explicitly says that built rooms remain. Undo, redo, rotation
and return to Catalog stay in a fixed footer above the household HUD. Long lists
scroll inside the tray, including at 720p with enlarged interface text.

Whole-lot clearing uses a distinct review in that same tray, with a coral lot
outline and furnishing footprints. The world stays visible and receives no edits
from pointer clicks during review. Counts and the refund name the consequence;
protected paintings and lost consumables are explicit. Keep the confirm/back and
history controls fixed at the bottom. A stale review asks for a new review and
scrolls back to its updated quote, instead of silently accepting different
contents. After acceptance, the tray offers Saved rooms and Build room.


Move family belongs in the fixed construction footer, beside Access; the saved
room footer keeps it beside Catalog and Rotate. Use an ordinary quiet action,
with the resident names and free effect in its tooltip. Keep the active tool and
selection visible. After acceptance, the same world view shows the residents
beside the entrance and the normal notice explains that building can continue.
Moving… disables only the pending button until the accepted state arrives. When
everyone is visiting, disable it with an explicit explanation instead of recalling
the family. Do not add a confirmation modal or another permanent HUD panel.


## Choosing household recreation

Game tables and stereos open a quiet activity tray before directing a resident.
Show the furnishing name, actual reserved places, and each own housemate's
eligibility. Keep the selected-resident choice and Call household together, with
brief visible copy explaining that plans stay first and arrival times may differ.
Current automatic players can choose the activity without restarting it; explain
that their place/time stay and only newly chosen company builds friendship.

Keep the tray stable while tasks, reservations, and names update. Use the same
native controls, sounds, and floating placement as other activity trays. Clip the
one-line participant list with full names on hover so four long names cannot
push the action/timing explanation below the compact viewport. Inspection itself
never queues an action, while the Activities list offers each furnishing at its
own location. Other players remain responsible for their own participants.

Full fun should not make a chosen companion leave just before the group shares
its brief moment. Accepted participants already playing or on their way can keep
one another there within the activity's usual duration. Plan says **Time for
company** and includes that time in its estimate; the activity tray explains that
leaving is still free and existing plans come next. Queued, automatic, or absent
participants do not hold a place open. Keep the same poses, music and world view,
with no extra prompt, locked controls, or separate shared-activity timer.


## Optional art commissions

Use the existing floating Activities tray and original painting miniatures.
The request names a small community recipient, one subject, and §180 payment.
Show “No deadline · No fee” before acceptance. Reading an offer, finding an easel,
or opening its catalog entry must never choose a painting or deliver artwork.
The easel's commission link repeats the requested subject while work is active.

A delivery review shows one exact original, its full artist credit and current
location, and the fact that it leaves the home permanently. Keep Deliver and
Keep this painting in the fixed footer. Escape backs out of that review before
closing the tray. A changed original invalidates the review rather than silently
substituting another one. Failed commands keep the reviewed picture available
with an explanation. A successful reply waits for the authoritative board revision.

Completion names the recipient and earned payment, keeps a short receipt, and
says another request is available tomorrow. Avoid duplicating success notices
inside the tray; the ordinary game notice already acknowledges the action.
There is no countdown, penalty, new currency, or demand to log back in. Reuse the
ordinary UI cues and existing painting activity sound; this small goal does not
need another persistent HUD badge or music layer.


## Discovering a ready commission

Use a small gold mark on the existing Activities button and a Ready suffix on
its art-commission entry. Both describe current delivery eligibility, including
planned-sale, construction, and budget checks. They remain discoverable after
loading without another permanent HUD panel. The tooltip names the subject,
payment, and number of eligible originals.

The first ready original for an accepted request creates one quiet notice and
**Review originals ›** action. It opens the list, preserving the selected resident,
viewed lot, and both plans. It never selects an original, enters construction, or
issues a delivery. Keep the first original's Review button visible at compact
sizes by shortening the already-accepted request introduction. Full request
wording remains on the recipient heading's tooltip.

Wait 400 ms for readiness to settle, then let any previous seven-second notice
finish. Expire a pending discovery after 20 seconds. Do not repeat for another
canvas or for construction/sale toggles on the same acceptance. Initial state,
loading, reconnecting, menus, and an already-open commission tray are quiet;
the ready mark still reflects current originals. Invalidate the displayed action
when the request changes or no original is eligible. Use the existing confirmation
sample 6 dB quieter on Effects; mute preserves all text and navigation.


## A harvest for the table

Ripe garden beds offer two equally visible choices: sell for the exact currency
amount, or keep four vegetables for the pantry. Growing plants show watering;
empty beds show seeds. Keep both harvest choices visible at compact sizes. The
small pantry line reports free ingredients, with stored/reserved/incoming counts
and capacity in its tooltip. Homegrown meals opens the home dining table without
choosing a recipe or moving a resident. When no table exists, label the action
explicitly as construction and show its price.

The homegrown bowl reuses the shared meal presentation, adding radish rings and
tomatoes to its platter. Recipe text says two of each; the nearby pantry names
both crops. When stock is missing, show the garden hint beside the recipes; keep
exact shortfalls and reservation details in the tooltip rather than a clipped
paragraph below the tray. Reuse the harvest basket pose and quiet garden sound.
No additional HUD panel, spoilage timer, or reminder sound is needed.


## Finding garden work from a meal

Use the existing tray footer for a small Garden link beside Activities, so recipe
choices retain their space. Your kitchen garden is a household overview, including
when the selected resident is visiting. Each bed is a stable button with a crop
name, bed number, and a concise state: needs water, growing with water percentage,
ready to sell/keep, or already planned by a named resident. Put detailed actions,
capacity constraints, and full names in tooltips. Refresh text in place so growth
does not disturb keyboard focus.

Keep two starter beds visible at compact size by shortening the possible-bowls
caption. Truncate long house names with a full tooltip. A removed focused bed
returns keyboard focus to Activities. Selecting a bed centers and inspects it;
only its existing activity controls issue orders. Explicit priced build buttons
enter construction; the overview itself never places a bed or orders tending.
Use ordinary interface sounds and existing transitions.


## Contextual actions and a quieter HUD

Ordinary play keeps compact location/clock controls and a lower household/status
strip. Needs expands the seven care bars; More holds activities, wishes, hobbies,
People, household editing, travel, Mail, saving, camera centering and shared play.
The More mark carries unread mail/news and ready art commissions without adding
a separate permanent badge. Mood and the selected resident's current action stay
visible, so hiding the bars does not hide a pressing care problem.

Right-click furniture, a resident, artwork or ground to open a radial menu. Touch
and hold for half a second offers the same choices; moving the finger cancels the
hold and pans. Releasing the opening hold does not choose an action. A quick tap
keeps the existing primary action. Shift+F10 or the Menu key opens the selected
resident's choices; Tab/arrows navigate and Enter/Space chooses. Escape, Cancel,
right-click or an outside click closes the wheel without issuing a world order.

Use native text buttons around a quiet ring, clamped within the viewport, with
44px or larger touch targets. Long menus use explicit More/Back pages. Keep the
target name and acting resident in the center. Disabled choices explain their
reason in the tooltip; Details opens the existing richer activity tray. Menus
do not pause shared life or mutate simulation state. Revalidate choices at
activation without replacing a reviewed meal, original painting, activity or
household batch. Changing sessions or replacing a world cancels open wheels and
pending touch gestures, even when target IDs are reused. The host remains the
authority. Construction retains its tools.

### Android navigation and typing

Android Back follows Escape's existing console, draft, choice, tray and menu
priority. It must never silently quit or apply an edited household. Back dismisses
the system keyboard first; the next Back leaves the current screen. Keep explicit
Quit in the menu. Mobile uses immersive fullscreen and defaults to 125% UI scale;
saved scale preferences still win. The lot header includes 44px minus/plus zoom
buttons, sharing the mouse-wheel camera limits without issuing world commands.

When the landscape keyboard covers the active text field or caret, pan only its
UI layer upward and restore it when the keyboard closes. Account for embedded
popup coordinates and viewport scaling. This cannot move the world camera, change
simulation state or commit a draft. Resident preview drags process native touch
once, ignoring the duplicate emulated mouse events. The Controls guide explains
touch selection, holds, panning, zoom, building and Back.

### Deferred physical activity polish

The November 4 request now has shower occupancy, authored dining places and TV
seating implementations described above. Entry/exit transitions and contact polish
for other activities remain separate work. Keep rendered poses separate from
authoritative positions, routing and reservations; gameplay seating choices use
the command/simulation layer. Review in the real camera, daylight, night and a
compact window before claiming further physical interaction polish is complete.


## Icons first — November 4, 2026 (superseded by the navigation review below)

Navigation uses original drawn pictograms from `game/ui_icons.gd`, with no emoji
or installed-font dependency. The main/pause menus and secondary household tray
use compact icon grids. A stable bottom dock provides build/finish, catalog or
activities, and more options. The open book always opens the building catalog;
the hammer enters construction and the check reopens the home.

Use familiar silhouettes for needs, furniture, travel, mail, playback and editing.
Keep item names, prices, counts and footprint dimensions; put secondary catalog
uses and instructions in tooltips. Specific recipes, relationship descriptions,
errors and destructive confirmations retain words when a pictogram would be
ambiguous. This reduces dependence on reading; it is not a completed translation
system or a claim that every icon is universally understood.

Icon navigation retains 44px minimum targets, keyboard focus, accessible names,
hover explanations and a focus hint. Catalog categories show pictograms in the
closed selector and names beside them in the optional popup. Needs use the same
pictograms as their furnishings; an urgent need appears as its own shape in the
mood control. Badges retain counts and unread marks. Pause and pace use familiar
playback symbols, with the exact rate in the tooltip. State cannot rely on color
alone. Keep original SVG paths editable in source; raster textures are generated
and cached only at runtime, with no committed binary icon assets.


## Household dressing room — November 4, 2026

Character creation occupies its own full-window mode. The left side is a large
lit domestic studio with cream plaster, sage paneling, an oak floor and a rug;
the right side has a scrolling editor. Identity, Face & hair, Body & voice,
Outfits, Personality and Family share the same resident selector and fixed Save
household/Cancel footer. Show full body or face, drag to turn, scroll to zoom,
and offer explicit turn buttons and daylight/evening choices. Idle animation
uses breathing, blinks and small glances; reduced motion keeps a steady pose.

Keep named skin, hair, eye and clothing swatches beside the actual preview.
Each occasion owns its own outfit. Copy requires an explicit source and action;
merely browsing an occasion never changes the chosen everyday outfit. Voice
preview is optional, original nonverbal synthesis on Effects, and respects mute.
The same timbre and pitch are used for neighborhood conversation sounds.

Long forms and the resident roster scroll; model rotation never moves a resident
or changes a saved camera. Adding someone remains local until the entire household
is accepted. Explain that ages are chosen stages, babies rest with comfortable
needs, and hands-on infant care is not yet simulated. Family cards in People show
the chosen tie separately from earned friendship. Drafts preserve edits after
rejection, ignore unrelated acknowledgements, and cannot apply across a changed
session/world generation. Existing residents are never deleted by this mode.

Cancel or Escape reviews real unsaved edits in the fixed footer. Keep editing
returns to the same draft; only Discard changes exits. Clean drafts close directly.
Show the pending-edit state beside Save household, and use Customize household
only at fresh entry. Family rows name both people and the direction of their tie;
unavailable choices explain ages or conflicting ties before Save. Host validation
remains authoritative, including when a later age change invalidates a family tie.

Face & hair starts at a front close-up; Body & voice and Outfits start at a front
full-body view. Keep Front / reset and explicit zoom controls visible, with tighter
full-body framing at compact sizes. Hair and garment pickers have previous/next
buttons beside their names, previewing only the current occasion in the private
studio. Traits explain implemented preferences, including that Creative does not
start painting automatically. A scrolling household summary compares draft traits.
See [issue #5 dispositions](CREATOR_QA.md) for the deferred cast/model proposals.


### Residents as an illustrated cast — November 4, 2026

Residents use a warm, sculpted illustration style. A shaped jaw and cheek contour,
an integrated nose, fitted almond eyelids and curved brows give the face its
expression. Keep the mouth understated. Hair uses coherent swept masses and
recognizable cuts; clothing uses a deliberate shoulder line, open neckline,
cuffs, hems and small practical details. Smooth shading supports those shapes.
Avoid the assembled-toy appearance of separate eyeballs, nose beads, elbow balls
and floating sleeves. Match this direction in the creator and neighborhood,
including households loaded from older saves.

Keep the existing skin, hair and wardrobe palette. The creator's daylight must
retain detail in pale swatches; evening is a comparison, not a recoloring. Review
full bodies and faces, side/back views, children and elders, all outfits, and the
normal gameplay camera before accepting a model change. Faces stay readable
without photoreal textures or a new visual effect imposed on the whole world.


## Discoverable HUD — November 5, 2026

Navigation labels are on by default in menus, More, Needs, Plan and beneath the
three dock icons. Display → Show navigation labels retains a compact icon option.
Keep accessible names, keyboard activation and useful hover/focus descriptions in
both modes. Guide examples use the same pictograms and Edit household terminology.
Fresh entry offers Play starter household and Customize household; entering the
world changes that local entry state to Continue. An existing or damaged autosave
never takes the fresh-entry path, and neither choice replaces a neighborhood.

Needs and Plan stay in one fixed lower row. Needs opens a separate panel above it;
Plan and care trays are mutually exclusive. A need bar names its need and value,
uses an action cursor and opens a read-only care review. The fixed care footer
names the actor; only a named activity button sends the existing care command.
Keep accepted/rejected feedback above the roster and clear of open trays.

Show up to four complete 44px household rows, growing with household size. Larger
families use a persistent resident count, explicit Scroll cue, scrollbar and
keyboard-following scroll. Row callbacks bind resident IDs; refresh text in place
so changing activity or selection retains focus and scroll. Each row names an
urgent need or its current activity, with full names and both states on hover.
Portraits and bespoke activity icons are deferred until they can represent all
current creator choices faithfully; legacy appearance swatches are insufficient.

More opens directly above its dock, with the acting resident in its heading.
The clock persistently says Solo · Paused, Solo · exact rate, or Shared time;
Lot sheltered separately identifies construction. Context trays use the existing
need, garden, palette, meal, wish, hobby, people and travel pictograms. These are
UI surfaces and do not change world geometry, saves, routing or simulation rules.
See [the issue #2 dispositions](HUD_QA.md) for validation and remaining boundaries.


## Choosing actions safely — November 5, 2026

One to three contextual choices use a compact list beside the target. Longer
menus keep the paged ring. Keep text labels on these actions, including Cancel,
and retain the target and acting resident while showing Order or Inspect hints.
Click/tap hover copy distinguishes an activity order from opening choices; the
existing right-click/hold route always permits review without a primary order.
Quick-click behavior remains unchanged; a separate inspect-first mode is deferred.

The ordinary resident strip shares Plan's accepted-state timing: a thin progress
track and approximate neighborhood minutes for timed activities, plain travel,
waiting or idle text otherwise. It never advances on a presentation timer.
Accepted single orders name the resident/activity and distinguish Starting from
Queued, including busy furnishings. Plan remains the recovery control: its cancel
buttons bind to individual accepted action IDs, without a new ambiguous undo.

Painting controls retain their action identities. Capture the canvas revision,
resident and world/session at press-down; release must match that review before
ordering or navigating. Completion can update the available actions, but a held
mouse/touch/keyboard activation cannot become another action or sell a replacement
canvas. When the focused action disappears, move focus to the Painting hobby link.
A fresh press is required for the new choice.

Pause-on-choice and a combined recent-moments feed are explicitly deferred.
Keep the visible solo clock controls and existing manual pause binding, with no
implicit pace changes from trays. Shared simulation continues. Retain the saved
Little Moments journal, Plan → Recent, hobby cards and People records; do not
introduce another notification stream or invent saved milestone history.
See [issue #3 dispositions](ACTION_QA.md) for scope and validation boundaries.


## Viewing a neighbor's home — November 5, 2026

Viewing a lot never sends anyone there. When the selected resident is elsewhere,
the ordinary resident strip names their real home location and retains their
current activity and timing. Offer a labeled **Find resident** beside the care
control; it restores the resident's actual lot/floor and camera without changing
positions or plans. Keep full long names in hover text.

Vacant homes explain that nobody lives there yet, then point to an occupied home
in Neighborhood or Find resident. Visit, Travel together and furnishing choices
share destination availability, with specific construction and arrival-space
reasons. An owner being away does not close their occupied home.

Optional solo NPC households and distinct starter-house layouts are deferred to
separate ownership/save and content reviews. Preserve vacant player capacity and
existing saved homes. See [issue #11 dispositions](NEIGHBORHOOD_QA.md).


## Construction catalog feedback — November 5, 2026

Construction uses a wider floating tray with short two-column catalog cards.
Keep actual-model miniatures, names and prices; show four complete choices at
720p/125% UI. The fixed footer names the active tool with “Using,” its price,
rotated footprint, angle, use and essential support requirement. Searching never
changes that tool. Whole-name/category matches lead incidental text matches;
related-result tooltips explain the matching word. Keep keyboard search and
empty-result recovery intact.

After host-accepted placement, remove the duplicate ghost and acknowledge the
placed item at the stationary pointer. Moving the pointer resumes ordinary
validation. This success feedback cannot make an occupied position valid or
replace a host reply. Ink/cream perimeter lines and strong active footprint
edges distinguish usable space in day and night, with explicit error text.

Daylight in the construction View row is an optional presentation setting. Its
banner says Daylight preview; the clock retains the actual time. Switch it off to
compare real lighting. Leave simulation, saves and networking unchanged, and
reset the setting when leaving construction or changing the viewed lot/session.
Undo/Redo tooltips identify the accepted transaction and the next exact cost or
refund from bounded host-provided runtime descriptions. See
[issue #6 dispositions](BUILD_CATALOG_QA.md), including the explicitly deferred human
mouse/trackpad check.


## Resident identity in a crowd — November 5, 2026

Give the selected resident's name first choice of clear space, then place other
household need cues in stable identity order. Keep labels outside visible HUD
panels and actual posed body bounds; optional chat/TV bubbles yield to them.
Thin leaders connect labels to heads and draw behind every nameplate. Brass
identifies the selected name. Content residents otherwise keep the world quiet.

Retain existing care actions and full names on hover. Only label rectangles are
interactive; leader lines never capture input. If no clear label position exists,
keep the roster and Find resident available. This presentation cannot rearrange
residents, change reservations or make hidden geometry selectable. See
[the crowded-label review](RESIDENT_LABELS_QA.md) for validation and the remaining
POSE-07 silhouette/spacing work.


## House shadows and cutaway doorways — November 5, 2026

Fit directional shadows to the visible orthographic view, including terrain and
pan/zoom margins. Keep one shadow map and the existing texture budget, colors
and contact bias. A tall doorway should not float above a cutaway front wall:
near/interior jamb ends meet that low wall, while their real hidden frame retains
its shadow. Keep the threshold open; never squash a lintel across the passage.
Rear doors and raised-wall construction tools retain complete frames.

Quarter-turn orbit, additional neighborhood planting/props and starter-room
rezoning are explicitly deferred to coordinated interaction/content reviews.
Preserve the current camera controls, editable lawn, reachable starter layout
and existing saved homes. See [issue #8 dispositions](WORLD_POLISH_QA.md) for the
complete batch, reproduction, native comparisons and validation boundaries.
