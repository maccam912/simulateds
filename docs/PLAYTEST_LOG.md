# Feature and playtest checkpoints

## 2026-11-03 · Resident plans

Added an optional floating plan panel, individual action cancellation, and a saved
per-resident autonomy toggle. Direct orders still interrupt autonomous tasks and
preserve existing player orders. Stable action IDs make stale multiplayer cancel
requests harmless. Older saves receive defaults on load.

Validation: all nine local suites; two real Iroh clients issuing queue commands,
stale cancellation and reconnect; dedicated server startup; graphical capture at
1280×720. The plan stays out of the center of the house, and actual mouse input
opens it, changes autonomy, and removes a single row without clicking the world.

Fresh assessment: planning is understandable now, but residents can still share
one bathroom fixture or bed simultaneously. Next: exclusive-use reservations
with readable waiting, release on interruption, and sensible autonomous choices.

## 2026-11-03 · A busy household

Beds, fridges, showers, and toilets now have one active user, including their
walk to the object. A second directed resident waits in their plan; autonomous
residents choose another available furnishing. Reservations derive from active
actions, so cancellation, travel, disconnect, and construction release them.

Validation: nine suites passed, with explicit tests for waiting snapshots,
cancellation handoff, alternative autonomous choices, and reservation cleanup.
Interactive UI playtest of the preceding plan checkpoint covered opening the
plan, changing autonomy, ordering sleep/TV/reading, Escape navigation, and saving
on quit. No human/family playtest is claimed.

Fresh assessment: clicking tall furniture currently uses its floor tile, which
makes upper surfaces unreliable targets. Next: use the drawn furniture shapes
for picking, show a name and affordance on hover, and select residents by their
visible bodies. This improves ordinary play before adding more objects.

## 2026-11-03 · Click what you see

Furniture picking now follows its rendered polygons in reverse paint order;
resident bodies can be clicked for selection or conversation. A small hover
label names the furnishing, the need it serves, and whether it is occupied.
Demolition also targets the visible furnishing instead of a tile behind it.

Validation: nine suites passed; added mouse-input assertions for the upper fridge
face, resident bodies, and demolition followed by rollback. A graphical compact
capture confirms the hover label, footprint highlight, and correct target.

Fresh assessment: everyday control now reads more clearly. Building still makes
small mistakes expensive: only discarding the entire draft restores the original
purchase price. Next: bounded undo/redo inside construction, preserving the safe
commit/discard boundary and ownership rules. The Linux and macOS CI jobs for the
planning checkpoint passed; its Windows tests passed before that run was
superseded during export. Android export remains unverified.

## 2026-11-03 · Construction undo and redo

Construction keeps 32 reversible edits, with exact furniture identities and
prices. Undo/redo buttons and Ctrl/Cmd+Z, Ctrl/Cmd+Shift+Z, or Ctrl+Y stay within
the current draft. A new accepted edit clears redo; rejected edits do not. Host
revision checks reject stale undo requests, and only the lot owner can use them.
Discard still restores the entire draft even after the undo history fills.

Validation: ten suites, real two-client Iroh undo/redo and reconnect, dedicated
server startup, and compact graphical construction capture all passed. Tests
cover sale reversal, stale/foreign commands, branching and bounded history,
published-house boundaries, committed crash saves, and midnight allowances.
The allowance now survives undo, redo, discard, and a save during construction.

Fresh assessment: experimentation is safer, but rearranging a room still requires
selling and rebuying. Next: moving owned furniture at no cost, with rotation and
clear valid/invalid placement previews that use the same rules as the host.
After that, add an enjoyable purpose to daily play beyond refilling needs.

## 2026-11-03 · Rearrange a room

Existing furniture can move and rotate for free, preserving object identity and
participating in undo/redo. Local placement previews and authoritative commands
share one pure rule module. Green/red footprints explain missing floors,
obstructions, residents, doors, bounds, and budget before a click. Selling shows
the actual furnishing footprint and refund. A successful replicated move releases
the selection; a rejected move leaves it available to correct.

Validation: all ten suites, two Iroh clients moving furnishings and reconnecting,
and server startup passed. Mouse-driven UI checks cover picking a tall furnishing,
placing it, releasing the selection, and undo. Graphical playtesting at 1280×720
with 125% UI scale exposed an overly compressed catalog; paired edit controls now
keep at least 80 logical pixels available for catalog scrolling. Valid and invalid
preview captures passed and were inspected.

Fresh assessment: building now supports affordable experimentation and clear
feedback. The next biggest playability gap is purpose: residents mostly refill
bars. Next: small personal daily wishes with visible progress, modest rewards,
and a saved journal, keeping absent households protected from missed deadlines.

## 2026-11-03 · Little wishes and a personal journal

Each resident has three optional wishes chosen from six everyday activities.
Directed activity completion pays §40 per wish, plus §80 for a complete set;
autonomy and absent households cannot farm these rewards. Wishes never expire,
and a completed set can be renewed on a later day. The bounded journal, progress,
and rewards persist and replicate. Older saves receive a first set automatically.
Cards show completed/active/planned status and reject duplicate activity orders.
Idle conversation partners stay engaged, while their own directed orders win.

Validation: eleven local suites passed, plus two actual Iroh clients fulfilling
wishes, rejecting duplicate payouts, and retaining journals after reconnect.
Graphical captures at 1280×720/125% scale passed. An interactive desktop playtest
completed conversation, relaxation, and reading wishes, verified §200 total and
three journal entries, used the debug terminal to cross midnight, renewed the
set without losing the journal, and saved/quit cleanly. This is agent playtesting,
not a family playtest.

Fresh assessment: activities now have a small, understandable purpose. Watching
them still reveals stiff movement and almost identical poses, and midnight looks
like midday. Next: resident movement/activity presentation and day/night lighting,
while preserving authoritative positions and reduced-motion preferences.

### Build iteration reliability

Repeated feature pushes were canceling Windows/Android jobs before native builds
and exports finished. Push workflows now let an active run finish while retaining
the newest pending run; pull-request revisions still cancel superseded work.
This follows [GitHub's documented concurrency behavior](https://docs.github.com/en/actions/concepts/workflows-and-actions/concurrency).
The change also gives completed builds a chance to save their native caches.

## 2026-11-03 · Residents look busy

Residents interpolate along walkable routes between accepted positions, including
corners omitted by sparse network snapshots. Walking has a small stride, sofas
and beds have resting poses, and reading, tea, gardening, showers, television,
and conversations have distinct props. Reduced motion makes these effects still.
Furnishing details now rotate with their footprints; sleeping residents remain
clickable at the visible head and blanket in all four orientations.

Validation: twelve local suites passed, including interpolation around a wall,
teleports, lot changes, and preservation of authoritative state. Graphical activity
captures passed for every bed rotation, conversations, other activity props, and
reduced motion. The earlier furniture-moving checkpoint also completed all four
CI build/export jobs: Linux, macOS, Windows, and Android. These are build results,
not device playtests.

Fresh assessment: residents communicate what they are doing more clearly, but
the neighborhood still looks identical at midnight and noon. Next: restrained
day/night lighting with warm home lights and a readable construction workspace.

## 2026-11-03 · A neighborhood after dark

The shared clock now changes the exterior through dawn, day, evening, and night.
Automatic home lights keep interiors warm and readable, street lamps light the
pavement, and construction retains a visible property grid after dark. Time-of-day
changes affect the world drawing, not HUD controls or placement feedback.

Validation: twelve local suites passed, including midnight wrapping and continuous
light transitions. Graphical captures passed at four times of day, with assertions
for darker exterior pixels, readable interiors, and unchanged HUD control colors.
Night construction was inspected at 1440×900 and at 1280×720 with 125% UI scale and
low scenery detail. The initial HUD comparison sampled a translucent panel, which
naturally reflects the changed background; the corrected check samples an opaque
control. No simulation, save-format, or protocol changes were needed.

Fresh assessment: the world now conveys both activity and time. The largest
remaining friction in the core loop is construction speed: extending a house
requires many isolated tile clicks. Next: room-sized construction with an upfront
price and one undo step, preserving authoritative placement validation.

## 2026-11-03 · Build a room in two clicks

The Room tool previews a rectangle of floors, perimeter walls, and a doorway.
Rotate changes the door side; Escape cancels the first corner. The quoted price
charges only for new pieces and existing doors remain in place. Host revision
checks reject stale room requests. The complete edit is atomic and one undo
restores every piece and the exact budget. Cutaway walls now follow the actual
floor layout rather than assuming the starter home's coordinates.

Validation: thirteen local suites and the real Iroh host/two-client checks passed.
Coverage includes malformed/obstructed/unaffordable rooms without partial edits,
reversed corners, all four doorway sides, ownership, stale requests, single-step
undo/redo, save round-trips, and reconnect. Mouse-driven HUD checks exercise the
catalog, both corners, Escape, and undo. Graphical playtesting at 1440×900 and
1280×720/125% UI scale built an extension, rotated its door into the existing house,
moved a bed inside, and sent a resident through the doorway to sleep. The preview
quoted §505 and the accepted extension charged exactly that amount. Red previews
explain obstructed edges. This is automated agent playtesting, not a family test.

Fresh assessment: building an extra usable bedroom is now quick and affordable.
The household itself still feels generic: the second resident is always Robin,
and there are no appearance choices. Next: an in-game household editor for names
and a small set of visible appearance choices, saved and synchronized normally.

## 2026-11-03 · Make the household your own

A household editor changes the household name, both resident names, and a small
palette of skin, hair, clothing, and hair styles. Portraits share their head art
with world residents. Preview changes stay local until Apply; Cancel and Escape
discard them. Names remain readable in the compact HUD through truncation and
tooltips. Existing saves receive appearance defaults, and changing a profile name
no longer overwrites a custom household name.

Validation: fourteen local suites and the real Iroh host/two-client checks passed.
Tests cover atomic rejection of malformed/foreign/duplicate residents, stale
editor revisions, palette bounds, old-save defaults, JSON round-trips, maximum
request size, and reconnect preservation. App-flow tests cover preview, cancel,
apply, and invalid input. They exposed LineEdit consuming Escape; the editor now
handles that recovery key before field input. Graphical tests clicked Edit, color
swatches, and Apply at standard size and 1280×720/125% scale, checking all palette
choices and Apply remain on screen. The room-building checkpoint's Linux, macOS,
Windows, and Android CI jobs also passed.

Fresh assessment: the house and its residents can now feel personally chosen.
Social play still has little memory: a visit mostly refills a bar. Next: simple
friendships and a readable social panel so conversations and return visits build
something lasting without penalizing absent players.
