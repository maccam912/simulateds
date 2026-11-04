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

### Android cache disk pressure

The household checkpoint's Android job completed its native build, tests, export,
and artifact uploads, then the runner reported `No space left on device` while
saving caches. The workflow now removes extracted Godot export templates after
export, retaining their verified archive for the next run. A new cache key avoids
restoring the old duplicate archive/extraction cache. Cleanup is restricted to
generated template directories in disposable Actions checkouts; exports, engine
binaries, source, and signing settings remain intact. The result still needs a
completed workflow run to establish that runner disk pressure is resolved.

## 2026-11-03 · People worth visiting again

Completed, player-directed conversations now build a symmetric friendship when
both households are online. Progress is bounded to two catch-ups per pair per day;
there is no absence decay. Housemates start acquainted. Milestones appear in both
personal journals and in the HUD. The People tray shows portraits, bonds, location,
Visit/Chat actions, construction, and away status. A busy resident keeps their own
orders, queued chats wait, and overlapping reciprocal chats count only once.

Validation: fifteen local suites passed, followed by the real Iroh host/two-client
reconnect check and dedicated startup. The reconnect test now compares the entire
journal rather than assuming exactly one entry: chatting can fulfill another wish.
Peer failures also surface promptly instead of waiting out the host timeout.
Model checks cover reciprocal conversations, daily bounds, offline behavior,
milestones, old saves, JSON round-trips, and malformed bonds. Graphical mouse-input
playtests passed at 1440×900 and 1280×720/125% UI scale, including visit, chat,
friendship milestone, construction recall, and away states. Review caught a card
jumping above the scroll viewport when its score changed; the active card now
stays visible. These are agent playtests, not a human family session.

Fresh assessment: real-time visits now leave a lasting connection, but players at
different schedules still have little to leave for each other. Next: persistent
household postcards and small optional gifts, with a clear unread indicator,
bounded storage, and host-authoritative delivery that works while recipients are
away. Gifts must preserve exact funds through construction undo and save/reload.

## 2026-11-04 · Something in the mailbox

Households can leave a 120-character postcard for each neighbor once per game day,
optionally attaching §100 or §250. Delivery charges the sender; the recipient
explicitly collects the gift once. Mail waits while a household is disconnected.
The inbox holds 24 postcards, with unread HUD counts and read/collect/archive
actions. Full inboxes reject new mail without charging or dropping existing mail.
Mail persists in the shared world; it is not a private messaging service. Plain
postcards can be sent during construction, while sending money requires finishing
the draft. Collecting a gift updates live, undo/redo, and committed budgets.

Validation: sixteen model/application suites passed (the updated app-flow suite
was rerun after fixing its selection of an older, same-named test save). The real
Iroh host/two-client test passed with gifts sent by clients, repeat-send rejection,
host collection during construction, and postcards delivered during disconnect
waiting unread on reconnect. Dedicated startup also passed. Model checks cover
ownership, malformed input, capacity, per-recipient daily bounds, legacy saves,
JSON round-trips, gift collection through undo/redo/discard/save, and packet size.
Graphical mouse-input checks passed at 1440×900 and 1280×720/125% UI scale. Visual
review found Back could return to the main menu when Mail was opened before other
menus; the return destination is now explicit and asserted. The compact compose
layout now keeps the full form visible. No external messages were sent.

The cache-cleanup checkpoint and friendship checkpoint both completed all four CI
platform jobs successfully, including Android. Physical devices remain untested.

Fresh assessment: neighbors can now leave a personal reason to return. The central
household loop still gives little help deciding what to do when several needs are
low. Next: a readable resident mood and contextual care actions that take the
player directly to an appropriate reachable activity, while preserving manual
plans and respecting busy furniture. Reassess the balance through a longer live
household playtest before expanding careers or inventory.

## 2026-11-04 · A little care

The needs bars are now shortcuts to actual activities. The host selects a useful,
reachable furnishing or conversation on the resident's current lot, preferring
free options. Care preserves manual plan order, preempts unrelated autonomy, and
does not duplicate an activity already handling that need. A mood summary reflects
the lowest need without adding a separate simulated stat. The Care tray shows
suggestions, pending care, and explanations for missing or unreachable furniture.
Construction disables the controls along with other resident orders.

Validation: seventeen local suites, real Iroh host/two-client checks, and dedicated
startup passed. Added cases cover each need, instant-mutation prevention,
duplicate clicks, busy/free beds, blocked and missing objects, current-lot visits,
ownership, construction, and queue round-trips. Compact graphical input checks
at 1280×720/125% scale queued food, sleep, and hygiene, completed the plan, and
checked unavailable/building controls. A separate native 1440×900 mouse/keyboard
session used the developer console to start at low needs, then completed a meal,
sleep, shower, bathroom visit, recreation, social activity, and plant tending.
The other resident remained on autonomy. The plan cleared, needs recovered, and
the selected activities fulfilled all three wishes. The app saved and quit
cleanly through its menu. This was agent-operated, not a human family playtest.

An isolated four-household benchmark measured the full HUD refresh, including
care suggestions, at 0.778 ms median / 0.823 ms p95 over 200 refreshes on this Mac.
It is not an Android or maximum-furniture performance claim. The mailbox CI
checkpoint completed Linux, Windows, macOS, and Android successfully.

Fresh assessment: caring for the household is quick enough to leave room for
building and visits. The homes still share the same cream walls and oak floors,
which weakens the pleasure of making each lot one's own. Next: floor and wall
finishes with clear previews, per-tile costs, and the existing undo/save/network
boundaries, followed by a decorating playtest in differently shaped rooms.

## 2026-11-04 · A home with its own colors

Construction now includes six floor finishes and six wall paints. Two corners
select existing surfaces; the on-house preview shows the chosen texture/color,
changed tile count, and exact price. A floor tile costs §4 to refinish and a wall
tile §3. Unchanged tiles and empty ground add no cost. One Undo restores the whole
area. Finishes are sparse appearance data, independent of routing. Erasing a
surface or replacing a painted wall with a door removes the obsolete finish.
Draft, discard, undo/redo, and save behavior use deep copies of the finish maps.

Validation: eighteen local suites, the real Iroh host/two-client checks, and
dedicated startup passed. Model coverage includes reversed corners, furniture
under a finish, exact spending, atomic rejection, no-op paint, stale commands,
ownership, nested history independence, room doorway replacement, legacy saves,
JSON round-trips, and draft cleanup on disconnect. Multiplayer checks paint an
added room, reject a repeated stale request, and retain its finish on reconnect.

Graphical input checks passed at 1440×900 and 1280×720/125% UI scale. They previewed
and bought 21 slate floor tiles for §84, painted an elevated visible wall face,
repainted the perimeter, built an extension, and carpeted nine interior tiles for
§36 with exact undo/redo. The first wall fixture aimed at a neighboring top face;
the corrected point tests the intended visible side face. An area-selection
fixture was also moved onto unobstructed lawn so it selected the intended bounds.
Visual review prompted a two-column palette, reset scroll on entry, and removal
of redundant footer controls so all six finishes fit at compact size. Night tint
was reduced to keep selected hues recognizable while keeping interiors readable.

The preceding care checkpoint completed all four CI platform jobs. These are
agent playtests and build results, not physical Android or family playtests.

Fresh assessment: the household loop and decorating now offer useful choices,
but recreation still mostly ends when a need bar fills. Next: small persistent
hobby progress from deliberately completed activities, with readable milestones,
bounded rewards, and no loss from being away. Keep autonomy useful without making
an unattended household earn unlimited progress.

## 2026-11-04 · A little better at the things you love

Reading, gardening, and cooking now have five lasting ranks. Two deliberately
completed practices per hobby per game day count toward thresholds of 0, 2, 5,
9, and 14. Learned ranks improve primary need recovery by 10% each and add a
secondary comfort/fun benefit. The same ordinary activities count when chosen
through furniture, wishes, or care. Autonomy uses learned benefits without earning
practice. Reaching a daily cap leaves the activity available for enjoyment, and
absence neither earns nor removes personal progress. Rank changes add a bounded
journal memory and a small confirmation notice/sound.

Validation: all nineteen model/application suites passed, followed by real Iroh
host/two-client and dedicated-server checks. Hobby-specific coverage includes all
three real activities, exact novice/expert recovery differences, completed-only
practice, duplicate/canceled plans, manual takeover of autonomy, daily rollover,
maximum rank, ownership, construction, missing/blocked furnishings, exclusive
fridge reservations/free alternatives, resident-current-lot selection, old-save
defaults, corrupt-state rejection, JSON round-trips, and absence. Real clients
practice reading, see host-owned progress, and retain it on reconnect.

Graphical input playtests passed at 1440×900 and 1280×720/125% UI scale. They read
twice to earn Page turner, tend a plant, cook, switch to Robin's independent
progress, scroll the tray, inspect a missing shelf, close with Escape, and enter
construction. No clicks pass through the panel to the lot. The first standard
fixture expected the internal word "bookshelf" instead of the catalog's visible
"Story shelf"; its corrected rerun passed. Visual review added the explicit word
"Rank" to the card counter. The preceding decoration build passed all four CI
platform jobs. These are agent playtests, not a human balance verdict.

Fresh assessment: recreation now leaves something behind and the family loop has
several useful entry points. Building has accumulated a long flat list of tools,
furniture, and decorating options. Next, organize the catalog into readable
categories with search and clear item details, and playtest furnishing a room at
compact size. Keep the world visible and avoid adding permanent HUD clutter.

## 2026-11-04 · Find the thing, keep building

The build catalog now groups all fifteen tools/items into Build, Sleep, Kitchen,
Bath, Living, Garden, and Finishes, plus All. Search matches both names and uses,
including "sleep", "meal", "book", and "garden", within the selected category.
The field survives periodic world refreshes. Ctrl/Cmd+F focuses it, Enter selects
the first result, and Escape clears a query before using the normal close/cancel
behavior. Browsing keeps the selected tool and never purchases anything. Item
cards show price, footprint, and use; the fixed footer retains selected-item
details and two compact rows of editing controls. Over-budget items explain the
shortfall while remaining available for an honest placement preview.

Validation: all twenty model/application suites passed, followed by the real
Iroh host/two-client and dedicated-server checks. The new catalog input test
checks typed search (including gameplay-bound letters), persistent focus, empty
results, category filtering, Enter selection, rotated dimensions, Escape, missing
budget, finish-palette navigation, and every furnishing's discoverability. It
builds a usable addition, buys a bed, shelf, and plant for exactly §655 after the
room cost, checks undo/redo, and returns to live play. Graphical runs passed at
1440×900 and 1280×720/125% UI scale. The compact decorating regression also passed,
with all six swatches visible after the footer layout changes.

A native macOS mouse/keyboard playtest selected Kitchen, searched "meal", used
arrow keys to choose Living, searched "book", placed a shelf for §160, issued
undo/redo, finished construction, and saved/quit. Reloading retained the second
shelf and §11,840. Visual review found the category popup still using the engine's
default gray; it now uses the shared ink/cream/leaf theme, verified in the native
window after reload. Both native runs exited cleanly without engine errors.

The initial synthetic popup-navigation attempt did not exercise Godot's native
window input path and failed to select a category. The automated test now covers
its selection callback; actual popup mouse/keyboard routing was checked in the
native playtest. This distinction is intentional, not evidence of a broken menu.
The preceding hobby checkpoint passed all four CI platform jobs. No physical
Android or human family playtest is claimed.

Fresh assessment: the growing catalog is easier to use and the household now has
several meaningful activities. A newcomer still has to discover most of them by
opening panels. Next: an optional first-day guide with direct links into existing
controls, plus a clear controls reference that reflects key bindings. Keep it
reopenable and dismissible, with no forced tutorial or persistent extra HUD panel.

## 2026-11-04 · A first day without a compulsory tutorial

Main and pause menus now offer Guide & controls alongside Settings. Four pages
cover the first day, building, neighbors, and the current key bindings. Cards
open the ordinary family editor, care/wish/hobby trays, build tools, finishes,
People, Mail, saves, or connection choices. Opening help does not award progress
or alter a household. New-neighborhood setup includes a guide checkbox; opting
out starts directly in the world and is remembered on the device. Existing saves
continue normally, and help remains available regardless of that preference.

The controls page updates with changed bindings and names the Escape/F1 rescue
keys. Backtick is labeled plainly rather than as the engine's "QuoteLeft" name.
Editing bindings from help returns to the same Controls tab. Build links target
the player's own home and preserve an existing draft; care/visit links explain
construction restrictions. Guests cannot access host saves through help. Reading
the guide pauses solo play while the shared clock continues under host policy.

Validation: all twenty-one local suites passed, then real Iroh host/two-client
and dedicated-server checks passed. The guide-specific session clock check uses
simulated host/client roles, not a separate network guide playtest. Graphical
input runs passed at 1440×900 and 1280×720/125% UI scale. Coverage includes all
four tabs, every direct action, startup with no interruption, welcome dismissal,
new-world opt-out and preference reload, return navigation, live binding changes,
rescue labels, own-home routing while viewing a neighbor, existing construction,
and guest/joining restrictions. The first scrolling fixture clicked before the
new page had laid out; it now waits for layout and verifies that the target is
inside the scrolling viewport. Corrected runs passed. The preceding catalog
checkpoint passed all four CI platform jobs. These remain agent playtests.

Fresh assessment: the game's controls are now much easier to discover, and the
household/building/social loop is coherent. Residents still make very similar
leisure choices on their own. Next: distinct, editable leisure preferences that
influence autonomy while keeping urgent needs and explicit player plans first.
Make the difference visible in ordinary play, without unattended reward farming
or penalties for being away.


## 2026-11-04 · A favorite way to unwind

Residents now have editable favorites: reading, television, gardening, tea, or a
little of everything. New housemates start with distinct preferences; older saves
keep neutral choices. A favorite gives a small advantage among reachable useful
activities when needs are similar. Any available urgent care disables that bias.
Missing or blocked furniture still permits other care. Explicit orders and the
autonomy switch retain priority. Automatic favorites restore needs without earning
hobby practice, wish rewards, or extra funds, including while a household is away.

The household editor includes a pastime selector on each resident card. A shorter
portrait preview keeps every color and selector plus Apply/Cancel visible at
1280×720/125% UI scale. The daily plan shows “Unwinds with” and marks an automatic
favorite activity. Changes are atomic, owned, revision checked, saved, and
replicated. An older identity request that lacks the new field preserves the
current favorite instead of clearing it.

Validation: all twenty-two suites, real Iroh host/two-client identity replication
and reconnect, and dedicated-server startup passed. Focused checks cover all four
preferences, neutral choices, urgent care, modest preference strength, unreachable
favorites, an absent urgent furnishing, manual orders, disabled autonomy, live
idle selection, absence, old saves, malformed snapshots, and atomic invalid edits.
The maximum ordinary Unicode edit still fits the 1,024-byte packet. Graphical
household input runs passed at 1440×900 and 1280×720/125% UI scale; captured editor
and plan screens were inspected. An initial misplaced local-variable declaration
caused a compile error in the focused test, corrected before the passing suite.
The preceding guide checkpoint passed all four platform CI jobs. These are agent
checks; physical Android and human family playtests remain outstanding.

Fresh assessment: residents now have a small recognizable difference in everyday
behavior, and the preference is visible without growing the permanent HUD. The
next useful improvement is an accurate, dismissible return recap for asynchronous
play: how much neighborhood time passed, what allowance arrived, and which
postcards await. Record actual host simulation facts, avoid invented events or
wall-clock catch-up, and keep the recap from interrupting an active visit or build.


## 2026-11-04 · Something to come home to

Mail now includes Home news: an optional recap of actual neighborhood time spent
away, allowance credited, postcards delivered, gifts included in those postcards,
and unfinished building drafts discarded on departure. The existing Mail control
shows a badge; no popup interrupts startup, visits, or construction. Opening news
does not mark it read. An explicit read action clears its new badge and keeps the
history. Unread reports accumulate across meaningful absences so reconnecting
cannot erase earlier news. A quiet reconnect under thirty neighborhood minutes
creates no new report. The current unread-postcard and uncollected-gift counts are
separate from historical delivery totals.

The host records simulation steps and actual successful deliveries, never wall
clock time. Host downtime creates no elapsed time, income, or invented activity.
An ongoing absence survives save/restart. Old saves begin tracking prospectively.
Reviewing daily income exposed a pre-existing funds-cap overflow: allowance now
fits the most constrained live/draft/undo balance, and recaps record that exact
credit. Normal households still receive §600 per game day.

Validation: all twenty-four local model/application suites passed, followed by
real Iroh host/two-client reconnect and dedicated-server checks. Both clients
received a recap of a real postcard delivered while disconnected, acknowledged
it through the host, and retained the read state in the host's saved world after
disconnecting again. Focused checks cover ownership/revision guards, duplicate
acknowledgements, merged unread and replaced read reports, gift separation,
first arrival, short reconnects, repeated cleanup, restart continuity, corrupt and
legacy saves, and allowance limits including construction discard balances.

Graphical input playtests passed at 1440×900 and 1280×720/125% UI scale. The initial
compact review showed recap actions below the fold; they now remain in a fixed
footer. Corrected runs verified immediate persistence without an extra manual
save, inbox navigation and gift collection, current versus historical totals,
Escape, and reading during construction without discarding it. The initial model
run found a misplaced legacy normalization hook; it was corrected before the full
passing checks. The preceding pastime checkpoint passed all four platform CI
jobs. These remain agent playtests, not physical Android or human family testing.

Fresh assessment: returning players can now understand why their funds changed
and discover waiting mail without losing control of the game. The household
loop is functional, but ordinary life is still visually and aurally quiet between
menu clicks. Next: subtle spatial footsteps and furnishing/activity sounds that
follow visible accepted actions, respect audio settings and pause/menu state,
and stay bounded when several residents are active. Reassess the mix in the
running game so it adds life without turning into repetitive noise.


## 2026-11-04 · A house that sounds inhabited

Visible residents now produce quiet wood/grass footsteps and domestic activity
accents. Ten original procedural mono textures cover pages, watering/bathroom
water, ceramic/cutlery, fabric settling, showers, and abstract conversation and
television. They follow actual task progress and displayed movement, rather than
running independent appliance loops. Changing lots, resuming a menu, teleporting,
or receiving the same snapshot again creates no catch-up sound. A sparse shared
rate limit and four positional voices keep crowded houses bounded; the existing
UI voice pool remains independent. Sources follow camera movement and stop when
offscreen or canceled. Menus/console, construction, effects/master mute, and zero
simulation speed stop household playback. Reduced motion retains footsteps.

Validation: all twenty-five suites passed, followed by real Iroh host/two-client
reconnect and dedicated-server checks. Pure scheduling checks include every
activity, start/periodic timing, unchanged snapshots, repeated resumes, teleports,
source removal, fair representation of simultaneous residents, and eight walkers
bounded to at most 56 cues over ten seconds. During integration review, the quiet
gaps between accepted walking steps were found to reset stride accumulation;
tracking the outstanding walking path now preserves normal and reduced-motion
footsteps across those gaps.

A graphical playtest recorded the actual Godot Master output. Left/right probes
produced greater energy on the expected channel; effects mute produced exactly
zero samples. Four overlapping household textures plus a UI confirmation peaked
at 0.158 full scale, without clipping. A 6.3-second ordinary play excerpt included
wood/grass walking, reading, watering, and tea with music/ambience, peaking at
0.116. The playtest verified that host-role simulation advances behind a menu
while household sounds stop, offscreen panning stops current voices, zero speed
is quiet, and reduced motion keeps footsteps. The host-role audio assertion is
local; it does not claim a separate network audio session. Shutdown was clean.
All ten source textures were checked for nonzero signal, bounded amplitude, and
quiet endpoints. This is objective mixer and agent-playtest evidence, not a human
listening assessment or physical speaker/headphone validation. The previous Home
news checkpoint passed all four platform CI jobs.

Fresh assessment: movement and recreation now have audible presence, but the
capture still shows the selected name partly hidden behind a bookshelf, and an
unselected resident gives little indication of needing attention. Next: improve
resident readability with labels above furniture and small actionable need cues,
keeping the world readable without adding another permanent HUD panel. Preserve
quiet play by showing cues only when they are useful, and verify clustered
residents, occlusion, compact layout, and direct care through the real command path.


## 2026-11-04 · Residents you can read

The selected resident's name and marker now draw after furnishings, so a shelf
or appliance cannot cover the label. Sleeping residents keep the same selectable
name. A small cream thought cue identifies each owned resident's most pressing
uncovered need below 30, using a drawn icon and plain words. Clicking it selects
that resident and uses the existing care command. Active or queued care—including
automatic care and sleep's secondary comfort—hides that need's cue. Other players'
residents receive no actionable care controls. Quiet residents add no extra
labels beyond the current selection.

Label placement separates nearby cues and clamps them inside the viewport. Long
names truncate, with full names on hover, and the palette remains readable at
night. Cues do not animate or flash. They disappear in construction, menu
backgrounds, and when their resident leaves the viewport. A double-click guard
prevents a cue disappearing between clicks from issuing an unrelated second
world order. Missing or blocked furniture follows the existing useful care
feedback rather than claiming an action succeeded.

Validation: all twenty-six model/application suites, real Iroh reconnect, and
dedicated-server checks passed. Focused tests cover every need, derivation without
world mutation, covered/queued/secondary care, missing furnishings, crowded edge
placement, owner/stale-target guards, and preserving an existing manual plan.
Graphical input runs passed at 1440×900 and 1280×720/125% UI scale. They exercised
clustered residents, exact cue hit targets above furniture, food/sleep through the
real care path, no double-click fallthrough, sleeping/settled labels, long names,
night and viewport edges, missing furniture, construction, hidden HUD, and
panning actors offscreen. The first edge fixture used the previous displayed
position immediately after relocating test residents; it now waits for the
presentation frame before calculating the camera offset. Corrected runs passed.
The preceding spatial-audio checkpoint passed all four platform CI jobs. These
are agent checks, with human family and physical Android playtests still open.

Fresh assessment: a household now communicates urgent needs in the world, and
selection is readable around tall furniture. The edge-layout exercise makes the
remaining navigation gap clear: after panning away, selecting a household member
can leave them outside the useful view. Next: a discoverable camera focus action
and sensible resident/lot framing, preserving manual camera control, existing key
bindings, reduced motion, and the full-screen world.

## 2026-11-04 · Find your resident

F, a repeated click on a selected household name, and Plan's Find resident button
center the selected resident without resetting zoom. Selecting an offscreen
household member also brings them into view; selecting a visible one preserves
the composition. The camera moves for 200 ms, snaps with reduced motion, and
yields immediately to pan or zoom input. Lot changes reset pan but retain zoom;
Center resets both. Current member lookup handles replacement snapshots and
visiting residents. The camera changes no simulation state or orders.

Older custom key maps migrate without losing swaps or existing F bindings; a
free alternative is assigned and shown in controls. The first regression exposed
JSON's floating-point key codes defeating a strict array collision check; codes
are now normalized before migration. Rendered standard and compact checks cover
actual input, long-name Plan layout, visiting, menus, and typing. The headless
fixture also needed complete wheel events and a frame for mouse routing before
a button press. All 27 local suites, real Iroh host/two-client reconnect, and
dedicated-server startup passed. The final compact graphical rerun passed too.
The preceding resident-cue checkpoint passed all four platform
CI jobs. These remain agent checks, not human family or physical Android tests.

Fresh assessment: finding a household member is now easy without disturbing the
camera every time selection changes. The Plan tray exposes the next useful gap:
changing the order of upcoming activities requires canceling and recreating
orders. Next: let players rearrange their queued plans while preserving the
current activity, stable action identities, and host ownership/stale-request
checks, then test it during a busy two-resident morning.

## 2026-11-04 · Revise the morning plan

Upcoming activities now have earlier/later arrows. An edit swaps the exact
adjacent pair of stable action IDs shown to the player. The current task,
elapsed progress, reservations, and all other residents remain unchanged.
Repeated, stale, nonadjacent, foreign, and malformed requests fail without
mutation. Even a full eight-action queue can be rearranged. The ordinary
scheduler then executes the new order, including moving a useful activity ahead
of an occupied fixture without canceling the waiting order.

The Plan tray preserves focus and useful scroll position through its row rebuild;
at a boundary it focuses the available reverse arrow. Actual mouse and keyboard
checks also cancel the intended action after multiple moves. A two-resident
morning moved the bathroom earlier for Alex and reading ahead of an occupied
fridge for Robin, then completed both residents' care/recreation plans in order.
Compact visual inspection exposed notices covering the lower plan rows; they
now sit beside the tray and grow upward above the household controls.

Validation: all 29 suites, real Iroh host/two-client plan reordering, stale and
foreign rejection, reconnect, and dedicated-server startup passed. Standard and
compact rendered input checks passed, including notice layout. The affected
plan/HUD/camera/application suites passed again after the layout adjustment.
The camera checkpoint passed all four platform CI jobs. Human family and
physical-device playtests remain separate work.

Fresh assessment: a busy household's upcoming day is easier to change, including
when another resident occupies the desired fixture. Watching the revised plan
reveals the next usability gap: the active row says what is happening but does
not distinguish travel, waiting, and progress toward finishing well enough.
Next: clear, quiet activity feedback based on accepted state, without stealing
focus or adding another permanent world panel.

## 2026-11-04 · See how the day is going

The Plan tray now distinguishes travel, arrival, waiting for another resident,
and an activity in progress. Activities get a quiet progress bar and approximate
remaining time in neighborhood-clock minutes. The estimate accounts for needs
filling early, directed activity minimums, and hobby bonuses. The simulation
and estimate share personal restoration rates after the first completion check
exposed the sofa's extra comfort gain. Nearby social effects can still change an
estimate as play continues. Conversation partners with no task of their own are
described as chatting, rather than falsely shown as free.

Labels and bars update in place from accepted state, preserving button identity,
focus, and scroll through travel-to-activity changes and replacement snapshots.
No local animation advances progress during pause or between snapshots. Travel
and waiting have plain text without a misleading progress bar. The optional
tray remains the only home for this extra detail.

Validation: all 30 local suites, real Iroh host/two-client reconnect, and server
startup passed. Completion comparisons covered nine furnishings at three need
levels with both automatic and directed timing, plus hobby bonuses. Standard
and compact graphical checks passed for travel, activity, waiting, and passive
conversation. The compact household/favorite-pastime rendering regression also
passed with the updated Plan rows. Captures wait for displayed movement to settle after manually
advancing the fixture. The prior plan-editing checkpoint passed all four
platform CI jobs. Human and physical-device playtests remain open.

Fresh assessment: care and planning are now legible enough to watch a household
work through a day. The next opportunity for fun is a reason to spend time with a
visitor beyond a chat. Next: a tabletop recreation activity that can be enjoyed
alone or together, with voluntary participation, clear shared benefits, and no
takeover of another player's resident or existing plans.

## 2026-11-04 · A game around the table

The §340 checkered game table gives residents a solo puzzle and a voluntary game
for up to four. All participants restore fun; actual company adds social. Each
resident joins through their own ordinary plan and reserves a separate approach
destination. A fifth keeps their queued order until a place opens. Cancellation,
travel, disconnect, and construction release participation without a separate
saved lock. Leaving lets companions continue their own activity.

The Living catalog explains the shared benefit and footprint. The board has
cream/teal squares, warm pieces, a small hand pose, and an original damped wooden
click; reduced motion holds the pose still. Hover shows occupancy and Plan
distinguishes solo/shared enjoyment. Tabletop games is an editable favorite,
with ordinary fallback when no reachable place is available. Existing saves
load unchanged; multiplayer protocol 2 prevents older clients reading an unknown
furnishing kind.

Validation: all 32 local suites, real Iroh host/two-client play/reconnect, and
server startup passed. Model checks cover capacity, separate destinations,
owned commands, replication, release, save loading, and full-table care/autonomy.
Both actual clients observed shared social restoration and separate places
before the host began construction and recalled them. Native graphical checks
at 1440×900 and 1280×720/125% UI passed purchasing, undo/redo, all four rotations,
solo/shared play, leaving, and recall. Actual positional mixer captures were
nonzero and unclipped in both sizes; human listening remains open. The preceding
activity-feedback checkpoint passed all four platform CI jobs.

The first UI check found a missing care-action label; catalog additions now have
a safe label fallback. The visual review caught a duplicate “missing company”
thought during shared play. It now quiets only while a real companion is playing,
and reappears when solo if still needed. A native fixture also needed to target
an uncovered board square instead of clicking a thought cue overlapping its
center. These fixes passed the final model/application and graphical checks.

Fresh assessment: visiting now offers an activity beyond conversation, but its
discovery depends on spotting and clicking the table. Next: help a visiting
player find and join an ongoing game from People, using their selected resident
and preserving each household's ownership and existing plans.

## 2026-11-04 · Find company through People

People now shows ongoing tabletop games and their occupied places. A remote card
explains that you can visit to join. Once there, Join game adds the table to your
selected resident's plan; Queue game offers an explicit wait when all four places
are reserved. Cards distinguish In your plan from Playing here. Existing directed
work stays ahead of the game, and companion plans remain untouched. The tooltip
explains that a companion may finish before you arrive.

The host checks the particular companion activity shown on the card. A delayed
click on a completed/replaced game is rejected without changing any resident;
malformed, foreign, duplicate, inaccessible, and full-plan requests are also
rejected. Accepted joins use the existing activity scheduler and derived place
reservations, with no additional saved state.

Validation: all 34 local suites, real Iroh host/two-client checks, and server
startup passed. The second actual client discovered the first client's game,
exercised stale/duplicate rejection, and joined before construction recalled
them. Native checks at standard and compact/125% UI sizes covered mouse/keyboard
discovery, visiting, joining behind current work, active participation, a full
table, releasing a waiting place, ending games, and construction. Snapshot
replacement preserved focused controls. Related checks passed after final label
polish. The preceding tabletop checkpoint passed all four platform CI jobs.

The screen review caught focused action buttons remaining visible while their
person's name scrolled out of view after card reordering. Focus restoration now
waits for layout and reveals the whole card when it fits. The final compact
native check asserts that visibility and passed. An initial blocked-table test
used the wrong wall fixture representation; correcting the fixture exercised
the intended rejection without changing product behavior.

Fresh assessment: shared recreation is now discoverable and can be planned
without taking over a companion. Housebuilding is the next usability opportunity:
Finish building rejects inaccessible furniture, but identifies the problem only
in text. Next: a construction access view that locates unreachable furnishings
and trapped residents, so a player can repair a layout before reopening the lot.

## 2026-11-04 · See what a home needs to reopen

Construction now offers Access: an optional floor overlay and a list of numbered
problems. Green floor connects to the entrance; coral floor is cut off. Trapped
residents and unreachable furniture get separate markers and Find controls that
center the camera without changing the selected resident. Door, Move, and Sell
return directly to editing while leaving access visible. The report updates
after accepted edits, undo, and redo, and disappears when construction ends.
A rejected Finish building opens the report automatically.

The host's commit decision and the display share a pure entrance flood. It
replaces repeated entrance path searches while retaining their rules, including
an occupied legacy starting cell that can step out to a clear route. Inspection
does not mutate a draft or place the previously selected item. Escape/close exit
inspection, and Ctrl/Cmd+F returns to catalog search. Door and Sell can target a
wall's visible surface, making repairs easier than locating its ground cell.

Validation: all 36 local suites, real Iroh host/two-client checks, and server
startup passed. The diagnostic matched the ordinary pathfinder across 180 varied
layouts and every furnishing in them. Model checks cover exact targets, pure
inspection, atomic commit failure, repair, history, and replacement snapshots.
The extended real Iroh check then closed each client's doorway, compared its
derived report with the actual host rejection, repaired the doorway, and reopened
successfully. The People-discovery checkpoint passed all four platform CI jobs.

Native standard and compact/125% UI checks exercised the complete repair loop:
rejected finish, Find, badge click, visible-wall door placement, undo/redo, and
successful reopening. The screen review found crowded issue badges overlapping;
they now fit separately and connect to their targets. The final compact check
asserts all twelve badges remain distinct in a sealed home. It also verifies
Escape and catalog-search recovery. Related UI/catalog/finish checks passed
again after these presentation changes. Human/device playtesting remains open.

Fresh assessment: layouts now explain their own problems and the repair tools
are immediately available. Decorating an enclosed room still requires carefully
choosing rectangle corners. Next: room-aware floor finishing with a whole-room
preview, an exact price, doorway boundaries, and one-step undo, making it easier
to give each household a coherent home.

## 2026-11-04 · Finish a room in one gesture

Floor finishes now offer Area and Room. Room selects connected floor, bounded by
walls, doorways, and missing floor. Hover previews the actual finish and exact
price; one click applies it, and one Undo restores every changed tile and its
cost. Floor under furniture is included, while the furnishing and residents stay
put. Removing a threshold connects adjacent floor regions, making an open plan
visible in the preview. Area remains the default and the wall-painting workflow.

The host derives the region from the seed and accepted geometry, validates the
draft revision, and uses the existing sparse finish storage and construction
history. Only changed tiles cost money. Matching rooms report no charge and make
no history entry; unaffordable rooms keep their original appearance and show the
whole selected extent and exact shortfall. Mode changes cancel an uncommitted
rectangle, and keyboard focus follows both mode and swatch selections.

Validation: all 38 local suites, actual Iroh host/two-client checks, and server
startup passed. Tests cover topology, under-furniture decoration, mixed finishes,
malformed/foreign/stale input, prices, history, discard, crash saves, and reload.
Both actual clients filled 56 tiles for the previewed §224, rejected the replay,
undid/redid the room independently of earlier paint, and retained it after
reconnecting. The access-view checkpoint passed all four platform CI jobs.

Native standard/compact checks exercised room preview, single-click application,
repeated no-charge clicks, undo/redo, a separately decorated extension, mode
changes, Access, over-budget rejection, and reopening. All six floor swatches fit
at 1280×720/125% UI. The established compact rectangle/wall flow also passed.
The first visual review found per-tile preview lines drawing over furniture;
the final preview uses only the region boundary, drawn on the floor behind the
objects. Final compact keyboard and related catalog/help checks passed after
focus polish. These are automated/native checks, not human family playtests.

Fresh assessment: constructing, repairing, and decorating a personal home now
requires fewer corrective clicks. Watching the household exposes the next visual
weakness: residents use activity props but mostly keep the same facing. Next:
derive their facing from accepted routes, furniture, and conversation partners,
so movement and shared activities feel connected to the room around them.


## 2026-11-04 · Residents face their lives

Residents now turn along each accepted route leg and toward the furniture they
use. Directional strides, arm depth, collars, hair, eyes, and held props distinguish
front, side, and rear views without enlarging the characters. Seated residents
face the sofa's open side in all four rotations. Reduced motion uses the same
facing immediately; resting residents retain their last idle direction. Saved
worlds, movement authority, and protocol fields are unchanged.

Conversation partners turn toward each other using actual live activity state,
including the idle recipient. Busy or departing partners lose the chat pose;
stale action text cannot keep it alive. Screen review found that independently
mirrored chat bubbles could cover a face, so each pair now shares one bubble above
them. A separate inspection found need labels covering a rotated sleeper's head.
Bubble and label placement now reserves every visible resident's head/body first.
Offscreen activities do not generate bubbles at the edge of the viewport.

Validation: all 40 local suites, real Iroh host/two-client checks, and server
startup passed. Model checks cover four directions, bounded turns, sparse-snapshot
corners, immediate reduced motion, initial client facing, all rotated furnishing
approaches, reciprocal chats, stale/busy/remote partners, construction, travel,
and replacement snapshots without mutating world state. The previous whole-room
finishing checkpoint passed all four platform CI jobs.

Native standard and compact/125% checks inspected the eight-facing appearance
sheet, actual everyday activities, four rotated sleeping/seated poses, selection,
chats, replaced snapshots, and reduced motion. The final compact check clicked a
four-leg walking circuit, verified facing and displayed positions, and checked
body selection. The established activity render plus compact urgent-cue and shared
tabletop flows passed again. This is automated native evidence, not a human family
playtest or physical-device cross-play result.

Fresh assessment: residents now visibly connect to the activity and people around
them. Directing movement still has weak feedback: a nearby nameplate may receive
an intended ground click, and accepted walking lacks a clear destination cue.
Next: show movement intent and accepted destinations in the world, with reachable
previews and useful feedback that stays quiet when the player is simply watching.


## 2026-11-04 · Show where a walk will lead

Ground hover now previews immediate walks with a reachable route, destination,
and step count. A queued walk instead shows a gold destination and how many
activities come first, explaining that its route will be chosen when it starts.
Occupied/unreachable spots, full plans, and viewing a lot before visiting have
clear feedback. The host and preview use the same read-only movement inspection;
no new saved state, commands, or protocol fields are needed.

Accepted manual walks show a current destination. A newly accepted queued walk
shows briefly; opening Plan reveals its route and numbered queued destinations.
Numbers match the Plan rows and change after reordering. Repeated destinations
share a combined number label. The rendered route includes still-interpolating
accepted steps before the remaining route, keeping corners connected to the
moving resident. Lines stay behind furnishings and walls. Nameplate hover keeps
selection feedback and offers no misleading ground action. Quiet watching hides
route lines and expired queued confirmations.

Validation: all 42 local suites, actual Iroh host/two-client checks, and server
startup passed. The model compared previews with host decisions for all 256
starter-lot tiles and exercised obstruction, ownership, queue limits, autonomy,
reordering, cancellation, snapshots, construction, and travel. Real clients
rejected a wall destination without a marker, received three accepted walks, and
updated marker numbers after the host reordered their plan. The previous facing
checkpoint passed all four platform CI jobs.

Native standard and compact checks exercised the preview/click/queue/cancel loop,
nameplate hover, hidden HUD, blocked/repaired entrances, snapshot replacement,
reduced motion, construction, and neighbor travel. Final compact captures include
actual walking, repeated destinations, and matching Plan numbers. Markers are
derived from accepted tasks, not acknowledgements or a local click prediction.
Human family and physical-device playtesting remain open.

Fresh assessment: individual orders now communicate their intent and sequence in
the world. Rebuilding a useful care/leisure sequence each day is still repetitive.
Next: reusable household routines, so a player can prepare a familiar plan with
fewer clicks and spend more time decorating or visiting. Routine execution must
resolve current reachable furnishings and preserve the player's existing plan.


## 2026-11-04 · Familiar household routines

Plan now opens a shared household library with Morning care and Wind down presets.
Players can save four named recipes of one to six care/recreation activities,
reorder their steps, and add one to either resident's existing plan. The host
resolves reachable furnishings on the resident's current lot, validates the whole
sequence and available capacity before mutating anything, and enqueues ordinary
activities. Manual work stays first; autonomous work yields as usual. Private
furnishings keep their existing waits, and a routine already in a resident's plan
cannot be added again. Editing/removing a recipe leaves accepted activities alone.
Old saves gain the starter library; custom recipes survive saves and reconnects.

The editor uses the existing floating panels, tray fade, and UI sounds. Keyboard
pickers and reorder controls retain focus, and a six-step draft scrolls at compact
size. Opening another gameplay tray tucks the editor away without losing its
draft. Escape backs out of a draft and then returns to Plan; console Escape keeps
priority. Uncovered world clicks are inert during editing. Pending results are
matched to the submitted command rather than a generic action notification;
rejected/stale edits retain typed work. A success reply arriving before its library
snapshot leaves the editor locked until the updated library arrives.

Validation: all 44 local suites, actual Iroh host/two-client checks, and dedicated
startup passed. Model tests cover exact ordered execution and need recovery,
independent residents, busy/missing furnishings, current-lot targeting, whole-plan
capacity, autonomy, preserved manual work, ownership, malformed/stale edits,
legacy saves, and atomic restoration. Real clients save independent recipes,
append them behind their walks, reject duplicates/foreign orders, and retain the
library after reconnect. Every real-peer command checks its intent-correlated
result. Protocol checks cover bad/non-host/repeated replies, local outcomes,
backpressure, oversized requests, and caller draft mutation. The walking-feedback
checkpoint passed all four platform CI jobs.

Native standard and compact/125% checks exercise typing, actual activity-picker
keys, step editing, save/run/removal, missing-furnishing explanations, snapshot
focus retention, unrelated delayed replies, retries, stale drafts, and eventual
activity completion. Final compact checks cover draft-preserving tray changes and
acknowledgement-before-snapshot behavior; related app, Plan, and guide checks pass.
These are automated native checks, not human family or physical-device playtests.

Fresh assessment: reusable sequences reduce repetitive care clicks and free the
player to spend time on the home. The visible architecture remains a plain wall
ring, making independently decorated lots look too similar. Next: placeable
windows that give houses character while retaining solid-wall routing, explicit
prices, construction history, and clear previews.


## 2026-11-04 · Windows give a home its face

The build catalog now offers Cottage panes (§60), Picture window (§80), and Garden
shutters (§90), fitted to existing solid walls. The host and preview share the
same inspection and exact price, including 60% trade-in when changing styles.
Remove window leaves the wall; Sell removes its window first. Placing a doorway,
including an extension doorway, removes and credits the window in that same edit.
One Undo restores every layer and the exact budget. Windows stay on construction
history, committed saves, discard, and reconnect boundaries. Existing saved homes
gain no purchases; new starter homes include three cottage windows.

Frames follow the wall run automatically. Pale crossbars, a wood picture frame,
and green shutters give the small house distinct silhouettes, with quiet glass
reflections and warm night tones. Windows never create a passage or change a room
boundary. Walls rise while fitting windows so near-side placement is visible;
normal life and Access restore the low cutaway sill. Raised wall-face clicks
select the wall they visibly touch, not an underlying floor tile.

Validation: all 46 local suites, actual Iroh host/two-client checks, and dedicated
startup passed. Model coverage includes every lot tile, all styles, net prices,
missing walls, unchanged and unaffordable work, malformed/foreign/stale input,
solid routing and room filling, paint, door conversion, extension pricing,
history/discard/disconnect, strict restore, and old saves. Both real clients buy
independent styles for the previewed amount, undo/redo them, reject replay/foreign
construction, and retain windows and solid walls after reconnect. The routine
checkpoint passed all four platform CI jobs.

Native standard and compact/125% checks exercise the palette, actual wall picking,
style preview and replacement, removal, undo/redo, errors, Access, day/night,
cutaways, and replacement snapshots. Final review shortened palette copy so every
control and its explanation fit together. Ctrl/Cmd+F now leaves the palette for
catalog search, and returning resets its scroll. Intent-matched replies preserve
pending work until accepted state arrives. A compact screenshot found the price
label beneath the catalog; construction labels now find visible space beside HUD
panels. The final compact windows, room-finishing, catalog, and guide checks pass.
These are automated native checks, not human family or physical-device playtests.

Fresh assessment: decorating now changes the home's architecture as well as its
colors and furniture. In the life loop, the player still lacks normal controls
for pausing to plan or moving through an uneventful solo stretch; speed is exposed
only through the developer console. Next: clear solo pause/speed controls, with
movement, activities, and needs advancing consistently, while shared neighborhoods
retain their common running clock.

## 2026-11-04 · Time to plan, time to play

The ordinary clock now offers Pause, 1×, 2×, and 4×. P toggles pause and resumes
the previous pace; 1/2/3 choose the running rates. All are rebindable, and older
key maps keep their choices even when they already use P or the number keys.
Pause is brass and explicitly labeled; the current running pace is leaf green.
The active highlight survives hovering. Settings uses descriptive action names,
and the guide explains the new controls. The wider clock panel still overlays
the full-viewport world and fits the compact layout.

Paused play accepts plans and construction without advancing needs or residents.
Opening and closing a menu preserves deliberate pause or a chosen fast pace.
Movement, turning, activity animation, and household sound stop with solo time;
camera/interface response and music retain their ordinary pace. Hosting, joining,
leaving, loading, and new worlds reset to 1×. Shared play labels its common clock
and disables ordinary time controls. The host's explicit debug override remains.

The old debug multiplier enlarged simulation steps, which made walking accelerate
differently from needs. Time now accumulates into fixed 0.1-second steps, with
bounded stall work and no discarded sub-tick time. Walking retains the fractional
part of its tile interval too. Complete snapshots agree at equivalent simulated
time across three speeds and three input cadences.

Validation: all 48 local suites, real Iroh host/two-client/reconnect, and dedicated
startup passed. Native standard and compact checks cover actual controls,
real physics pace, paused planning, menu behavior, mid-step visual freeze, audio
silence, settings/rebinding, and shared locks. The guide and facing presentation
checks also pass. One older guide fixture attempted to reuse a newly occupied
key; it now frees that key before testing the existing rebind flow. No conflict
validation was weakened. The previous windows checkpoint passed all four platform
builds. Automated native checks do not replace human family/device playtesting.

Fresh assessment: solo play now has useful control over quiet stretches, but
recreation mostly changes meters and journals. Watering the existing houseplant
never visibly changes it. Next: a small gardening loop with planting, visible
growth, tending, and harvesting, giving residents a lasting project and a reason
to return while keeping absent households forgiving and host-owned.

## 2026-11-04 · A garden that grows

A §180 kitchen garden bed now fits on the lawn or on a floor. Radishes cost §10
to plant and yield §45 after 4½ game hours of watered growth; tomatoes cost §20
and yield §95 after 9 hours. Residents plant, water, and harvest through their
ordinary plans. One resident reserves the bed while queued or working, and full
needs do not skip the work. Seed costs and harvest funds apply only on completion;
cancelling before completion does not spend seeds or award practice.

Soil darkens when watered, shoots grow into distinct crops, and a small brass
marker flags dryness or readiness. Hover and the stable garden panel explain the
same state in words. Gardening has trowel, watering-can, and basket props with
quiet seed/leaf rustle and watering cues. The panel names the active gardener and
clears old queue acknowledgements. The guide opens the real garden-bed catalog
entry, and the live Plan shows the specific work and its full remaining time.

Dry plants stop growing but never die; ripe crops wait. Growth continues while
an owner is absent and the host runs, until the bed needs water. Visitors can
water, while planting and harvesting belong to the owner. Construction freezes
the crop; moving, undoing, discarding, saving, and reconnecting preserve it.
Successful work uses existing bounded gardening practice and wish rewards.
Autonomy does not buy seeds or create unattended harvest income.

Validation: all 50 local suites, actual Iroh host/two-client/reconnect checks, and
dedicated startup passed. Model tests cover budgets, cancellation, duplicate and
malformed commands, exclusive plans, stale saved tasks, growth, safe absence,
visitor help, strict save validation, and construction history. Each real client
grows a distinct crop with its second resident while its first keeps playing.
Native standard and compact flows cover placement, all crop stages, real buttons,
full-duration plans, budget feedback, props/audio, state replacement, visitor
restrictions, and pending replies. Catalog search now correctly returns both
kinds of bed; its former single-result test was updated. The guide/catalog native
checks pass, and the previous clock checkpoint passed all four platform builds.
Human family/device play and overnight hosting remain open.

Fresh assessment: gardening gives ordinary recreation a visible, lasting result.
It also makes an existing feedback gap more noticeable: a planned activity can
finish, be cancelled, or become unavailable while the player watches another
resident, and then simply disappear from Plan. Next: a compact recent-outcomes
view in the resident plan, including clear completion/cancellation/failure
reasons, so managing both residents remains understandable.

## Recent results in each resident’s Plan

The previous garden playtest exposed how a completed or interrupted order simply
vanished from Plan. Added **Plan → Recent**: eight deliberate outcomes per resident,
with Done/Cancelled/Interrupted, a concrete reason, and neighborhood day/time.
Routine names stay attached even after the recipe changes. Completed history
survives saving and reconnecting; loading explicitly explains unfinished work
that the existing load policy clears. Automatic care does not crowd out deliberate
plans. Batch cancellations show the active order before its upcoming steps.

Native standard and compact playtests completed a meal for Alex while Robin
walked independently, cancelled a new order through the existing Plan controls,
and inspected a furnishing interruption. Recent shows the correct resident's
history, keeps keyboard focus and scroll stable on ordinary refresh, and returns
to Upcoming without changing the simulation. The compact screenshot kept the
result, reason, and timestamp readable inside the existing tray. Polished resident
switching to start at the newest entry. Live task labels retain their existing
lookup behavior; stored titles give missing targets a meaningful history entry.

All 52 local suites, real Iroh host/two-client/reconnect, and dedicated startup
passed. Native 1440×900 and compact 1280×720 at 125% passed, with a final compact
rerun after polish. Both real clients observed exactly one cancelled result after
a repeated rejected packet and retained completed gardening history on reconnect.
The prior garden checkpoint passed macOS, Linux, Windows, and Android CI. Human
family sessions, physical devices, and overnight hosting remain unverified.

Fresh assessment: seeing finished care makes the resident plan easier to trust.
Building a useful morning sequence directly by clicking furnishings is already
natural, but saving that sequence for later requires recreating it in the routine
editor. Next: an explicit **Use current plan** draft in Routines, with a reviewable
list and clear handling of movement, garden work, and other unsupported steps.
It should save through the existing routine command and leave current activities
running unchanged.

## Turn a live household plan into a routine

Clicking the fridge, shower, and bookshelf is a natural way to arrange a morning,
but saving that plan previously meant entering its steps again in Routines.
Added **Use current plan** beside New routine. It opens an ordinary editable draft
from the active deliberate activity and queued reusable activities, in order and
with repeats preserved. Walking, conversations, crop work, automatic care, and
missing targets are listed as omitted with original positions and reasons.
A long plan keeps all its reusable steps; the player chooses which to remove to
reach the six-step save limit. The source plan keeps running, and switching
residents or receiving snapshots cannot rewrite the open draft.

Native playtests clicked actual furnishings, captured their three-step sequence,
changed its order, and saved it without altering accepted tasks. A mixed plan
clearly explained its omitted walk and chat. A nine-step draft required three
explicit removals, and a full library explained how to make space. A stale save
kept both the copied steps and their source explanation for review. The compact
125% layout left the omission details, step controls, and limit guidance readable;
all controls remained reachable by scrolling and keyboard focus. The automation
needed to wait for freshly rebuilt controls to finish layout before targeting
them; final standard and compact native passes both succeeded.

All 54 local suites, actual Iroh host/two-client/reconnect, and dedicated startup
passed. Both clients saved their own copied routine and retained it after
reconnect. The preceding history checkpoint passed all four platform builds.
Human family sessions, physical devices, and an overnight shared-host soak remain
open validation work.

Fresh assessment: routine editing now connects directly to ordinary play, and
recent results make completed care understandable. Another menu refinement would
add less than a new visible leisure activity. Next: a music corner with dancing,
so residents can enjoy the house alone or alongside willing visitors. Keep
participation in each resident's own plan, use distinct available floor positions,
and make sound obey the established mixer and reduced-motion settings. This is
the next proposed increment, not an implemented feature of this checkpoint.

## A little hi-fi and dancing together

Added a §260 stereo with a low wooden cabinet, two visible speakers, a sage
display, and a small playing note. Clicking it starts a deliberate dance. Residents
use separate adjacent walkable places and a small raised-arm/alternating-step pose;
Reduced motion preserves the pose without rhythmic motion. Solo dancing restores
fun. Actual participants receive social restoration while dancing together; each
keeps their own queue and can leave independently. People discovers a current
dance and offers Join dance. Dancing is also a favorite pastime and routine step.
Shared reservation logic now serves both tabletop games and music corners, with
future places protected across adjacent shared furnishings.

The native playtest bought and rotated the stereo, clicked it for solo dancing,
and had Robin join Violet through People while Alex kept dancing. Three residents
occupied visibly distinct spots; Plan described fun and social together. The music
is an original 100-BPM, eight-bar procedural groove. One visible stereo plays at a
time, favoring the selected dancer, while the background score becomes quieter.
Music & stereos controls its volume independently of Effects. Actual mix captures
were audible without clipping and silent when muted. Repeated snapshots did not
restart the track. Pause, menus, construction, and offscreen speakers stopped it.

The wider native audio pass caught a short-activity onset being discarded after
a footstep. Retaining one cue only while its exact activity remains current fixed
reading/tea playback; cancelling the task discards the pending cue. Both its new
regression and the original household mixer flow passed after the fix. The final
compact dancing rerun also passed. All 56 local suites, actual host/two-client/
reconnect, and dedicated startup passed. Both clients shared the table and then
danced together before construction recalled them. The preceding routine-copy
checkpoint passed all four platform jobs. Human listening/family sessions,
physical devices, and an overnight host soak remain unverified.

Fresh assessment: dancing adds visible, social recreation to the house, and the
separate spots make participation understandable. The remaining weak point is
space feedback: a stereo can be usable by one resident while nearby furniture
leaves too little room for company, yet the UI mostly advertises the four-person
maximum. Next: show usable/reserved shared-activity places and explain waiting,
so players can arrange a music corner or game area that fits their plans.


## Making space for company

Shared furniture now reports actual reachable capacity, capped at four. The
construction preview distinguishes a one-place music corner from a place for
company, while a live hover shows reservations and temporary occupation with
separate shapes. People offers Queue dance/game when no reachable place is free.
Waiting feedback distinguishes a tight reserved corner, full shared activity,
nearby reservations, and a resident simply standing in the available space.
The simulation and presentation use the same calculation; no UI reservations
or extra save fields are introduced.

The native playtest bought a stereo with just one usable place, queued Robin
behind Alex, then moved it and joined them together. During testing, an apparently
empty neighboring tile was actually isolated from the entrance; the preview
correctly excluded it. A genuinely open placement provided four places. Standard
and compact runs passed. Screenshot review prompted moving inspection tooltips
away from the activity and markers where space permits. A paused cancellation
regression verifies immediate reservation refresh without advancing a tick.

All 58 local suites passed (the old People count-text assertions were updated,
then the remainder resumed). Final targeted model and compact native checks also
passed. Actual host/two-client/reconnect and dedicated startup passed; the clients
correctly counted the test room's three reachable dance places. The preceding
dancing checkpoint passed macOS, Android, Linux, and Windows CI. Native playtests
are automated input, not human family sessions or physical-device evidence.

Fresh assessment: space and waiting are now understandable, but explaining a wait
exposes the next friction. After finishing shared recreation, a resident can keep
standing in a place that someone else wants. Next, investigate a small, polite
step aside when an activity ends and another plan is waiting. Preserve deliberate
orders and independent family control, keep anyone still participating in place,
and avoid creating new collisions or hidden activity queues. This is proposed
next work, not implemented behavior in this checkpoint.


## A small step aside after play

Completed shared games and dances now make room for an already-waiting plan when
one safe adjacent step is available. The finisher's own queued orders take
priority; canceling an activity explicitly does not move them. The step avoids
residents, accepted walking routes, waiting approaches, doors, the entrance, and
other shared furniture's places. A fresh traffic check before moving handles a
new direct order using that space. No safe destination means staying put.

The native flow let Alex dance until fun was fulfilled, with Robin already
waiting for the only place. Plan showed Making room for Robin, a courtesy label,
a short explanation, and the normal cancel control. Alex visibly stepped aside
and Robin's original action ID took the freed place. Standard and compact native
runs passed, including reduced-motion positioning. Courtesy is interruptible even
with autonomy off, gives no reward, and is excluded from Recent and captured
routines; the completed dance remains in Recent exactly once.

Model checks cover both shared furnishings, queued/direct orders, cancellation,
blocked exits, doorways, a newly accepted conflicting route, simultaneous finishes,
snapshot replacement, disk reload, and construction recall. All 60 local suites
passed, followed by an expanded courtesy-model pass. The previous shared-space
checkpoint passed all four platform CI jobs. The actual host/two-client handoff,
construction recall, reconnect, and dedicated startup passed. The first network
assertion compared integer positions with JSON float arrays and failed despite
replicated movement; normalizing the expected coordinates fixed the test, and the
entire real-peer scenario passed on rerun.

Fresh assessment: the room now explains its usable space and can hand it over
without extra micromanagement. The next gap is the meaning of spending time
together: dancing and tabletop games restore social, but only conversations
currently build friendship. Next, make deliberate shared recreation contribute to
bounded relationship progress, with honest People feedback, minimum time actually
together, and protection against double-counting or autonomous/absent farming.
This is proposed next work, not a feature of this checkpoint.


## Friendship through chosen games and dancing

Shared recreation now builds the same symmetric relationship as chats after two
online residents spend 12 game minutes actually participating through deliberate
orders. The pair shares the existing two-catch-up daily budget across chatting,
games, and dancing. Solo time, walking, bystanders, autonomous participation,
absent households, repeated snapshots, and continuing the same encounter over
midnight add no extra progress. Pair sampling happens before either resident's
activity ticks, so both finishing on the qualifying step still count equally.

People now names the last encounter and its day, shows catch-ups left today, and
explains the threshold. A control issue surfaced during implementation: an
already-automatic participant had a disabled Join button. Explicit Join now
replaces that automatic activity with a fresh deliberate plan. Other queued
orders and ownership rules remain unchanged.

The native flow began with Robin dancing automatically, verified no bond gain,
then used People to choose participation. The first catch-up showed Danced together
and one left today; a second chosen encounter reached Friends, appeared in both
journals, and showed the daily limit. Standard and compact native runs passed;
the screenshots showed readable cards and the existing milestone notification.
All 62 local suites and actual host/two-client/reconnect plus dedicated startup
passed. A final real-peer rerun also retained the exact relationship records
across reconnect. The previous courtesy checkpoint passed all four platform CI jobs.

Fresh assessment: visits now have an enduring social result, and the activity
loop has enough variety to support purposeful play. Homebuilding is the next
high-impact area: repeating a furnished room still means reconstructing its
walls, finishes, windows, and furniture item by item. Next, add room duplication
with a complete cost/access preview and a single undoable placement, so extending
a family home is quicker without making construction unpredictable. This is
proposed next work, not implemented behavior in this checkpoint.

## Repeat a furnished room

Copy room now selects an enclosed room with a doorway and repeats its actual
shape on the same lot. The world preview rotates floors, walls, doors, furniture,
finishes, and windows together, with a complete component price breakdown. Empty
floor can be reused; existing walls and furnishings cannot be overwritten. The
whole resulting lot must retain access to its residents and furnishings. A copy
is one purchase and one Undo step. Furnishings receive fresh IDs and garden beds
start empty; the original room, crops, residents, and activities are preserved.

The native standard/compact flows selected a blue bedroom, inspected all four
rotations, rejected occupied and out-of-bounds positions, placed the copy,
undid/redid it, and returned to live play. The rotated bed, doorway, low walls,
window, source highlight, and price breakdown remained readable over the world.
Escape cancels selection. Source edits require a new selection, and an unrelated
command failure cannot dismiss a copy waiting for the host.

All 64 local suites passed, plus a final pending-request UI check. The real Iroh
host/two-client scenario and dedicated startup passed after correcting a test
layout that sealed a later walking destination and then a doorway orientation.
Both clients copied their own decorated room for the exact price, observed new
object IDs, undid/redid the whole edit, and retained the design and identities
after reconnect. The previous friendship checkpoint passed all four CI platforms.
These are automated native input/rendering and separate-process network checks,
not human family or physical-device playtests.

Fresh assessment: extending a home is now much quicker, but repeated bedrooms
and living spaces still share identical furnishing colors. The next useful
step is a small, coherent furnishing palette with in-world previews and undo,
so households can give their rooms distinct looks without buying replacement
furniture. Preserve those choices through moves, room copies, saves, and remote
play. This is proposed next work, not implemented behavior in this checkpoint.

## Give furnishings their own colors

Furniture colors adds Original, Sage, Sky, Rose, Honey, and Ink as free material
choices. The same six labeled swatches fit in the compact tray. Hover previews
the actual furnishing, and one click applies the choice with normal build sound
and Undo. Bedding, upholstery, enamel, woodwork, pots, and garden frames change;
foliage, glass, books, electronics, game pieces, and crops retain their details.
Original restores the precise old art. No-op clicks create no history, and
colors neither replace objects nor change budget or resale value.

Standard and compact native input flows colored every furnishing, restored
Original, undid/redid, opened catalog search and access inspection, and checked
pending host feedback. The two beds read as distinct Sky and Rose bedding, the
palette remained legible, and the sleeping pose retained its bed's material.
Model checks cover all materials, malformed requests, fresh room-copy identities,
legacy saves, committed-save boundaries, and preservation of living crops.

All 66 local suites passed after updating the bed-search expectation to include
bedding colors; the compact native catalog check passed too. The actual Iroh
host/two-client scenario retained colored furniture through undo/redo, movement,
room duplication, and reconnect, with no change in funds. Dedicated startup
passed. The preceding room-copy checkpoint passed all four CI platform jobs.
These remain automated rendering/input and separate-process checks, not human
family or physical-device playtests.

Fresh assessment: the palette makes repeated furniture feel personal, and
decorating is quick enough to experiment with. The setup exposed a more pressing
building usability gap: a valid game-table placement could seal access to the
fridge, only becoming obvious at Finish building or in Access. Next, warn about
that consequence in the placement preview, naming the affected furnishing and
showing the route problem before purchase. Keep draft editing flexible while
making the consequence visible. This is proposed next work, not implemented
behavior in this checkpoint.


## See access problems before placing an edit

Placement, Move, and Room previews now identify the access consequence of the
proposed layout. Amber text names a newly blocked furnishing or resident, small
badges locate it, and newly cut-off floor is tinted. Existing problems and repairs
have distinct wording. A green repair explains when the home is ready to finish.
Draft edits stay flexible, with the same authoritative Finish building gate.

All 68 local suites, the real Iroh host/two-client/reconnect scenario, and dedicated
startup passed. Standard and compact native input flows exercised blocking the
fridge with a game table, repairing it with Move, undo/redo, closing and reopening
the entrance, and changing a room's doorway side. Predicted reports matched the
accepted layouts and hover changed no world state. The warning did not consume
placement clicks. Screenshot inspection found an outline crossing warning text;
drawing the label last fixed it. A test's real OS pointer needed to follow its
injected hover, and a supposedly clear furniture destination actually blocked
the television; the final fixture uses a genuinely accessible location without
relaxing routing checks. These are automated native and network checks, not
human-family playtests.

Final review found that a loaded world could reuse a preview when its lot ID and
revision matched the previous world. Preview keys now include the active model
identity, and both native layouts passed a replacement-world regression check.
The updated Building guide passed as well.

Fresh assessment: building now gives useful feedback at the moment of a decision,
and decorating has enough range to make households distinct. The next impactful
work should return to the residents: a creative recreation activity such as
painting, with visible progress and something personal to keep in the home.
Start with a small complete loop, preserve ownership and always-on safety, and
avoid making it an unattended income source. This is proposed next work, not
implemented behavior in this checkpoint.


## A canvas that belongs to the household

Daydream easels add a deliberate creative loop: choose Morning meadow, Quiet
harbor, or Flowers for home; work on the canvas; keep the finished picture on the
easel or pack it for sale. Free supplies and a fixed 24 seconds of simulation
work restore fun and comfort. The image develops from a wash to broad shapes to
details, with a small signature on completion. A housemate can resume unfinished
work and receive shared credit. Completion leaves a journal entry. Selling pays
§60 only after packing finishes and leaves a fresh canvas.

The first model run exposed a command-name collision with architectural paint;
the creative command is now `painting`, keeping decoration's `paint` behavior.
Other fixture corrections moved a test easel away from a resident, supplied
required undo revisions, and used approximate comparison for JSON floating-point
progress. Headless checks exercise subject focus; native tests exercise actual mouse hover
too.

Standard and compact native input flows painted all three subjects, canceled and
resumed work, checked Plan timing, rotated the easel through all orientations,
sold/undid the whole furnishing with its artwork intact, and packed individual
pictures. The sparse painting/packing cues reached the live mixer. Screenshot
review caught the compact tray inheriting the catalog's scroll position; it now
opens at the top with all subjects visible together and a smaller preview.
Packing has its own wrapped-frame pose and does not claim to restore needs.

The new real Iroh scenario uses two independent households, each with its own
canvas. Partial work and completed art survive reconnects, duplicate/stale orders
are rejected, and sales pay once. All 70 local suites, both actual Iroh scenarios,
and dedicated-server startup passed. The preceding construction-access checkpoint
passed all four platform CI jobs. Native input and separate-process tests remain
automated evidence, not human-family or physical-device playtesting.

Fresh assessment: making a picture gives residents a visible result beyond
refilling a need bar. Keeping a favorite picture currently occupies its easel,
so the strongest next improvement is wall display: keep the artwork in the home
while freeing the easel for another canvas. Preserve its artist credit and avoid
copying earned art with room duplication. A painting hobby can follow once
keeping and arranging finished work feels natural. This is proposed next work,
not implemented behavior in this checkpoint.


## Pictures become part of the home

Finished paintings can now move from the easel onto a solid wall, freeing the
canvas for another subject. Wall art in the catalog selects finished canvases
and the household collection. Move, Store, and Return to easel preserve the
picture, completion day, and artist credit. Transfers are free and undoable.
Removing the wall, making a doorway, or fitting a window safely stores its art.
Room duplication cannot multiply earned pictures. Front-wall pictures remain
visible and inspectable when the architecture cuts away during live play.

The first native flow reached its final new-canvas assertion; its expected
picture needed to account for the deliberate revision change when returning
art to an easel. The model also needed integer-coordinate comparison for raw
JSON validation. These fixes kept content retention and canvas identity separate.
The finished easel's Hang action no longer depends on the selected resident's
walking route, queue capacity, or current lot; an already planned painting sale
still keeps it unavailable.

Both native layouts passed the complete keep-and-paint-again flow, ownership
inspection, exact pending acknowledgements, history, window replacement, and
front-wall picking. Fresh screenshot review caught a compact-layout problem
that successful clicks alone had missed: collection actions required scrolling.
A smaller preview, concise location text, and a shared action row now keep Store
and Return to easel visible together. Multiple empty easels still provide a
specific destination picker. The existing quiet building cue confirms edits.

All 72 local suites and the expanded separate-process Iroh painting scenario
passed, including two households, mounted-art reconnect retention, empty-canvas
retention, and a single eventual sale payment. The complete regression also
passed the original Iroh scenario and dedicated-server startup. The previous easel checkpoint
passed all four CI platform jobs. These are automated native and network checks,
not human playtesting or physical-device certification.

Fresh assessment: keeping a picture now feels like decorating a lived-in home,
and the easel remains usable afterward. The next useful work is a painting hobby:
connect deliberate creative effort to a resident's lasting interests and visible
progress, while keeping subject choice and sales deliberate. That should reuse
the existing bounded hobby system and preserve older saves. It is proposed next
work, not implemented behavior in this checkpoint.
