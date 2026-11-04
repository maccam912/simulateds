# Simulateds design language

## A lived-in neighborhood

Linden Grove should feel like an early-2000s neighborhood seen through a sunny
window: small houses, practical furniture, people with ordinary routines, and
room for domestic comedy. The camera and sound establish a place. Interface
controls help the player inhabit it.

The game world fills the viewport edge to edge, including wide displays. HUD
controls float over it. A menu, catalog, or conversation must not shrink the world
into a dashboard panel. Keep the ordinary play view quiet: household, current
activity, needs, time, money, and a few actions. Open neighborhood navigation and
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

Needs are also controls: hovering explains the proposed care action, clicking
adds it to the resident's plan, and an optional Care tray explains unavailable
activities. The mood summary comes from current needs rather than an extra hidden
meter. Low moods use explicit text with terracotta/brass, never flashing alarms.

Use the world for richer color: oak, worn painted wood, cream plaster, terracotta,
green planting, and soft blue upholstery. Increase detail around objects that
residents use. Avoid decorative UI noise that competes with those objects.

The decorating palette uses six floor finishes and six wall paints. Woods use
board seams, tiles use grout/checkers, and carpet uses restrained flecks. Swatches
show names as well as colors. Preview surfaces directly on the house before
purchase, with an exact price and an area outline. Night lighting warms finishes
gently enough to preserve the player's chosen hues.

Floor finishing offers Area and Room beside the per-tile price. Room previews
the actual floor with a boundary at floor level, behind the furnishings. Avoid
drawing a grid over the furniture. An unaffordable room keeps its original finish
and shows the selected extent with a warm warning and exact shortfall. Matching
finishes get a quiet no-charge response. Walls, doorways, and missing floor bound
the room; furniture and residents do not. Keep all six swatches visible at the
compact size, and retain keyboard focus when selecting a mode or finish.

Hobby cards name an interest, its current title/rank, practices toward the next
rank, and the actual benefit. Buttons describe activities rather than XP farming.
At the daily limit they still allow recreation; the card says more practice is
available tomorrow. Rank changes use one modest confirmation sound and a short
notice, plus a saved journal memory. No streaks, expiry, or recurring reminders.

The build catalog keeps one compact category selector and one persistent search
field above the scrolling results. Item cards show name, price, footprint, and
use. Selected-item details and two small rows of edit controls stay below the
results, so scrolling never hides Undo or the chosen item's cost. Search refreshes
must retain focus and caret; empty results offer an explicit way back to All.
Popup menus use the same ink, cream, and leaf colors as the rest of the HUD.

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

## Construction access

Construction access is an optional view of the home. Tint connected floor green
and disconnected floor coral, with a warm entrance marker. Numbered problems link
the world to a scrollable list, so color alone never carries the diagnosis. Keep
badges separate and connect displaced markers to their objects. Find centers the
camera without changing resident selection; reduced motion makes it immediate.
The report shares the host's reachability rules and updates with accepted edits.
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

Provide independent Master, Music, Effects, and Ambience levels. A zero slider
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
retaining zoom, and Center restores both. Resolve current snapshot positions
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
| Load | Show names, time/day, and saved date. Unreadable saves remain visible with a reason; they do not replace the current world. |
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
original 100-BPM groove on Music, lower the background score beneath it, and keep
household textures on Effects. Changing or replaying a state snapshot must not
restart the song. People offers Join dance using the same voluntary, independently
owned participation as tabletop games; its label and occupancy explain the shared
activity without a separate social-game screen.

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
food alone during absence. Never suggest Join meal when this resident is already
eating it automatically. A player's next order or autonomy toggle interrupts
normally; an already taken portion stays consumed. Ordinary spontaneous dining
restores needs without earning deliberate-play rewards.
