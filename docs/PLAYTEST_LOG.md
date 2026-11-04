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
