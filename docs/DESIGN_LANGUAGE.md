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
