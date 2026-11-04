# Simulateds

A 3D shared-neighborhood life simulation with an orthographic dollhouse camera, inspired
by the homebuilding and household management of the early life-sim era. Build a
home, look after two residents, and visit a neighbor. Each player owns a separate
lot and family; one can build while the other keeps playing.

![Linden Grove, the first playable neighborhood](docs/preview.png)

The working neighborhood is **Linden Grove**. The presentation and game content
are original. Networking and build infrastructure start from
[maccam912/godot-iroh-template](https://github.com/maccam912/godot-iroh-template):
Godot 4.7.2 and the Rust Iroh 1.4.1 GDExtension, with direct connections and relay
fallback.

Read [DESIGN.md](DESIGN.md) for the game plan,
[docs/DESIGN_LANGUAGE.md](docs/DESIGN_LANGUAGE.md) for visual, motion, and audio direction,
[docs/ASSET_GUIDE.md](docs/ASSET_GUIDE.md) for the 3D art standards and source workflow,
[docs/LFS.md](docs/LFS.md) for binary assets and migration instructions,
[docs/ROADMAP.md](docs/ROADMAP.md) for follow-up milestones, and
[docs/VALIDATION.md](docs/VALIDATION.md) for tested behavior and remaining gaps.

## Run

Each push to `main` builds the tip commit and publishes a development
prerelease if all builds and tests pass. Packages include Windows, macOS,
Linux, Android, and the Linux dedicated server, with a SHA-256 checksum for
each download. Push a `v*` tag to publish a stable release.
[GitHub Releases](https://github.com/maccam912/simulateds/releases)

CI caches the Android development signing key. If the key changes, installing
the new APK requires uninstalling the old one, which clears its local saves.

Install Git LFS (`git lfs install` and `git lfs pull` in this checkout),
Python 3.11+, Rust via rustup, and your platform's compiler (Xcode Command
Line Tools on macOS, Visual Studio C++ tools on Windows, or the usual C/C++ build
tools on Linux), then:

```sh
python3 tools/setup.py
python3 tools/godot.py
```

Setup downloads the pinned Godot engine into `.tools/`, builds the native Iroh
library for your machine, and imports the project. It does not replace your
system Godot. The first Rust build takes a few minutes. Use
`python3 tools/godot.py --editor` to open the editor. Without the native library,
the game can still run locally; hosting and joining require the extension.

## Menus, settings, and saves

Startup opens the main menu over the neighborhood. **Continue** enters play;
**Escape** opens the game menu (or closes an open tray first). Menus and the
console pause solo simulation; a hosted neighborhood keeps running for everyone.

The clock also offers **Pause, 1×, 2×, and 4×** for solo play. **P** pauses or
resumes your previous pace; **1 / 2 / 3** select normal, double, or quadruple speed.
You can plan activities and build while paused. Closing a menu preserves your
chosen pace. These shortcuts are rebindable. Hosting, joining, leaving a session,
loading, or starting a neighborhood resets to 1×; ordinary clock controls are
unavailable in shared play so one household cannot pause everyone else.

**Settings** persists separate Master/Music/Effects/Ambience volumes, fullscreen,
VSync, frame cap, scenery detail, UI scale, reduced motion, and key bindings.
Conflicting bindings are rejected. Escape and F1 remain recovery shortcuts.
Original menu/live/build music, garden ambience, UI cues, and quiet positional
footsteps and household activity sounds are included. Effects volume controls
household sounds too; menus, construction, offscreen sources, and stopped play
keep them quiet. Reduced motion preserves audio feedback;
see [the sound palette](assets/audio/README.md).

**Save neighborhood** creates named copies or explicitly overwrites a selected
slot. **Load neighborhood** displays the current autosave and named saves, with
simulation time and saved timestamps. Invalid saves stay visible. A valid backup
can recover a damaged slot; loading or starting a new world preserves the current
world in a recovery slot first. Switching worlds requires leaving multiplayer.
The host alone saves a shared world. **F5** quick-saves the active world.

Named slots default to a directory beside the active autosave. `--slots-path=`
and `--settings-path=` can override their locations for development. Settings
are separate from world saves. `--play` skips the front end; `--skip-splash`
skips only the startup identity moment.

## Developer console and cheats

Open the terminal with **F1** or the backtick key. Enter runs a command, Up/Down
browse history, Tab completes commands, and Escape closes it.

| Command | Effect |
| --- | --- |
| `help` / `stats` | Commands and current simulation/network diagnostics |
| `rosebud` | Add 1,000 household funds |
| `motherlode` | Add 50,000 household funds |
| `money 25000` | Set household funds |
| `needs all 100` / `needs fun 80` | Set your family's needs |
| `time 08:00` | Set the current day's clock |
| `speed 2` / `speed 0` | Change simulation speed / pause simulation; networking continues |
| `teleport 8 7` | Move the selected resident to a free tile on their current lot |
| `cancel` | Clear your household's action queues |
| `construction cancel` | Discard the current construction draft |
| `save` | Save the active world |

Shared-world changes require the host; clients can inspect help and statistics.
Cheat changes to money and needs are part of the saved world. Speed returns to
normal when changing worlds. The console accepts explicit commands, not scripts
or shell expressions.

## Play

- Select a resident in the household list or click their visible body. Click a floor or lawn tile to walk;
  click a furnishing to use it. Their needs and current action appear in the UI.
  Hover empty ground to preview a reachable route or see why it is unavailable.
  Gold destinations mean a walk will follow existing plans. **Plan** reveals the
  accepted route and numbered queued destinations; numbers follow the Plan rows.
  Newly accepted queued walks show briefly, and rejected requests add no marker.
- Click a **need bar** to add a suitable care activity on the resident’s current
  lot. The host finds a reachable option, prefers free furnishings, and keeps
  existing player orders in sequence. **Care** beside the resident’s mood shows
  suggestions, planned activities, and explanations for unavailable furnishings.
- Open **Neighborhood** to choose a lot. Its cards show who is there now,
  whether the owner is playing or away, active visiting players, and construction
  closures. Hover for the full resident list, household names, and where absent
  residents are visiting. Viewing a lot does not move anyone. **Visit lot** sends the
  selected resident there; **Go home** returns them to their own lot.
  **Together…** opens a travel roster for the viewed lot. Choose one or both
  household residents, review their current locations and planned activity
  counts, then **Visit** or **Go home** together. Travel stops the chosen
  residents' current actions and clears their plans. Anyone already there keeps
  their plan, and unchecked housemates stay put. Arrivals use separate clear
  spaces near the entrance; stale plans or a closed destination reject the group
  before anyone moves.
- On your home lot, choose **Build & buy**, choose a tool or furnishing, then click a
  tile. **Sell** removes something; **R** rotates placement. **Move** rearranges
  furniture for free. Choose
  **Finish building** to resume life on the lot.
- **Move family** in the construction controls makes space around paused
  residents. Household members on this lot move to distinct clear spaces near
  the entrance; anyone visiting another lot stays there. It is free and preserves
  the selected tool, saved design, and Undo history. The host avoids spaces that
  older edits or **Discard draft** could fill again. If there is no safe space,
  finish a reachable layout and reopen **Build & buy**.
- Placement, Move, and Room previews warn in amber when an edit would cut off
  furniture or residents. The label names the new problem, badges locate it, and
  newly disconnected floor is highlighted. Draft placement is still allowed;
  restore access before finishing. Repair previews turn green when the home is
  ready. Existing problems are identified separately from problems the edit adds.
- **Access** in the construction controls shows connected floor in green and cut
  off floor in coral. Numbered markers and Find buttons locate trapped residents
  or inaccessible furniture. Add a door, move furniture, or remove an obstruction;
  the report updates after each edit and undo. A rejected Finish building opens
  the report automatically. Inspection cannot place items accidentally; Escape
  leaves the access view. Door and Sell tools can target the visible wall surface.
- **Room** builds floors, perimeter walls, and a doorway from two opposite corners.
  The preview shows the full price; **R** changes the doorway side. Existing
  floors, walls, and doors are preserved where possible and only new pieces cost
  money. **Escape** cancels the first corner. Rooms need at least 3 × 3 tiles.
- **Copy room** selects an enclosed room with a doorway, then previews its design
  in clear space on your lot. **R** rotates the whole copy, including furnishings,
  finishes, and windows. The preview itemizes the full price and checks access;
  click to place everything as one undoable edit. Existing empty floor is reused.
  Existing walls and furniture stay in place. Garden beds start empty, and
  residents and crops stay in the original room. **Escape** cancels selection.
- **Saved rooms** keeps up to four named designs for your household. Select an
  enclosed room with **Copy room**, then **Save room…**. The library shows small
  floor plans and offers Place, Rename, and Remove. Saving is free and survives
  discarding a building draft; placing charges the previewed cost as one undoable
  edit. Designs retain furniture colors, finishes, and windows. Food, crops,
  residents, and original artwork are left behind; new furnishings start fresh.
  Removing a design leaves built rooms untouched. Libraries travel with the
  neighborhood save and your household when reconnecting.
- **Clear lot…** opens a review of everything removed, the exact 60% per-piece
  refund, and any food or crops that would be lost. Finished paintings move safely
  into the collection; unfinished canvases or a full collection block clearing.
  Confirming makes one undoable edit. **Discard draft** restores the committed
  home, and saved designs remain available for rebuilding. Ordinary lot clicks do
  nothing during the review; a changed lot requires a fresh review.
- The build **Catalog** groups items by room/use. Search within a category by
  name or activity (for example, "sleep", "meal", or "book"). **Ctrl/Cmd+F** focuses
  search, **Enter** selects the first result, and **Escape** clears a search before
  closing the tray. Selected item cost, footprint, and use stay above the edit
  controls. Over-budget items can still be selected for a placement preview.
- **Windows** in the build catalog offers Cottage panes (§60), Picture window
  (§80), and Garden shutters (§90). Choose a style and click an existing wall;
  the preview shows the exact cost, including 60% trade-in for a replaced window.
  **Remove window** keeps the wall and refunds 60%; Sell removes a window before
  its wall. A new doorway also credits and removes its window. One Undo restores
  the window and budget. Windows follow the wall direction and keep it solid.
  Near windows use a low sill during live play, with full walls while fitting.
  New starter homes include windows; existing saved homes keep their own layout.
- **Floor finishes** and **Wall finishes** in the catalog offer wood, tile, carpet,
  and paint palettes. Choose a finish and two corners to decorate an area; click
  the same tile twice for a single tile. The preview shows the look and exact
  price. Only changed existing surfaces cost money (§4 per floor tile, §3 per
  wall tile), and one Undo restores the whole area. Finishes have no resale bonus.
  Floors also offer **Room** mode: hover to preview connected floor and its exact
  price, then click once to finish it. Walls, doorways, and gaps mark the edges;
  furniture stays in place and floor beneath it is included. **Area** keeps the
  two-corner workflow. A room already using the finish costs nothing.
- **Furniture colors** offers Original, Sage, Sky, Rose, Honey, and Ink for free.
  Choose a swatch and hover furniture to preview its bedding, upholstery, enamel,
  woodwork, pot, or frame. Click to apply; **Undo** restores the previous color.
  **Original** restores the furnishing's original materials. Details such as
  foliage and glass keep their own colors. Choices survive moves, room copies,
  saves, and reconnect, without changing the object, its crops, or its resale value.
- **Daydream easel** (§220, Living in the catalog) lets residents paint a meadow,
  harbor, or flowers. Hover or focus a subject to preview it. Painting takes about
  72 game minutes and restores fun and comfort, even if those needs fill first.
  Canceling keeps the unfinished canvas; either housemate can continue it, with
  both artists credited. Finished pictures stay on the easel and appear in the
  finisher's journal. **Sell painting** queues packing and pays §60 once it finishes,
  leaving a fresh canvas. Visitors can inspect art; only its household can paint
  or sell it. Artwork survives saves, reconnects, moves, colors, and Undo. Copied
  easels start blank. Painting is deliberate: autonomy and routines do not create
  or sell artwork. Finished canvases build a lasting painting hobby: each housemate
  who contributes at least 12 game minutes earns one practice when it finishes.
  Interrupted contributions keep; two practices per day count toward five ranks.
  Higher ranks restore more fun and comfort, with the same painting time and sale
  value. The rank link at an easel opens progress; Hobbies opens the easel for your
  chosen resident without selecting a subject for you.
- **Activities → Art commissions** offers an optional household request for one
  painting subject, paying §180. Accept it, then paint at your own pace: requests
  have no fee or deadline. The easel link remembers the requested subject. Review
  a matching finished original from an easel, wall, or collection before choosing
  **Deliver original**. Delivery removes that particular painting and pays once;
  it cannot be undone. Existing art and received gifts qualify, with the actual
  artist credited. Finish construction and cancel any planned painting/sale first.
  One delivery is available per household per game day; the next request waits
  until tomorrow. **Put commission aside** is free and keeps the same offer.
  The last four deliveries remain in the commission book through saves/reconnects.
  A newly ready request gives one quiet **Review originals** notice. It opens the
  list without choosing a painting or moving either resident, even while visiting
  a neighbor. A gold dot on **Activities** and a **Ready** menu entry keep eligible
  originals discoverable after the notice fades. Loading/reconnecting stays quiet.
- **Hang on wall** takes a finished painting into build mode. Choose a solid wall
  without a window or another picture; the transfer is free and leaves a blank
  easel. **Wall art** in the catalog lets you move pictures, store them in the
  collection, or return one to an empty easel for later sale. Undo restores the
  entire transfer. Removing a wall or fitting a window stores its painting safely.
  Up to 64 pictures retain their subject, completion day, and artists through
  saves and reconnects. Room copies leave earned art with the original household.
- Click a mounted picture, then **Admire painting** to queue a quiet 18 game
  minutes for the selected resident. They walk to the visible side, face the art,
  and regain fun and comfort. This works at home and on visits; the picture stays
  with its household. Leave a clear viewing space in front of the wall. Stored
  pictures must be hung first. Gifting or moving the original interrupts the
  activity politely, and construction recalls visitors as usual.
- **Gathering dining table** (Kitchen, §280, 2×2) makes shared meals possible.
  Click it to prepare four portions of garden salad (§12) or sandwiches (§20)
  using a reachable fridge. Your resident carries the food to the table before
  ingredients are charged; cancellation before serving costs nothing. Cooking
  earns bounded cooking practice, and ready food shows its cook and day.
  **Eat a portion** or **People → Join meal** reserves one serving and one of up
  to four separate places. Eating restores hunger and comfort; eating together
  also restores social and can build friendship when both diners are chosen.
  With autonomy on, hungry housemates eat available portions at home before
  taking fridge snacks. Urgent needs and your orders still take priority.
  Automatic eating earns no wishes, friendship, or cooking practice; it never
  prepares food or spends ingredients. Caretakers preserve portions while you
  are away. Click **Choose this meal** at the table, or **People → Join meal**,
  to make an ongoing automatic meal chosen shared time. It keeps the current
  serving, place, and remaining eating time, even when no portions remain.
  Friendship counts only shared time after both residents choose; a late choice
  does not prolong the meal to earn a catch-up. Hunger care can choose a ready meal. Visitors choose to eat served food,
  including while its household is away, but cannot spend its money or clear it.
  Leftovers keep until eaten or explicitly removed with **Clear leftovers**.
  A portion is consumed when eating starts; cancelling before arrival frees the
  reservation. Moving/undoing a table preserves food; room copies start empty.
- **Call household** at a served table calls your own residents on that lot in
  one choice. Hover or focus it to preview who joins now, joins after their plan,
  keeps a current automatic portion, or stays away. The selected resident gets
  priority when food is limited. Existing chosen meals stay untouched, and busy
  residents keep their plans first, so arrival together is not guaranteed.
  It also works while visiting with your own household; neighbors choose for
  themselves. Changed plans or portions require a fresh call instead of applying
  half the request.
- Later wish sets can include **Something homemade** (serve a meal) and
  **Share a meal** (both diners choose twelve game minutes together). They use
  the usual §40 reward and once-per-set bonus. Click a meal wish to inspect a
  table or open Kitchen with its §280 table selected; placement and ingredients
  remain your choices. Cooking pays only after serving. Shared dining pays each
  participant's own household, even if that pair has used today's friendship
  catch-ups. Starter sets keep their familiar activities, and saved wishes stay
  unchanged until you finish and renew them on a later day.
- Residents with a pressing need show a small thought cue above the house. Click
  it to select that resident and plan useful care. Needs already being handled
  or queued stay quiet, and cues belong only to your household. The selected
  resident's name remains readable over furniture, including while asleep.
- **Plan** shows the selected resident's actions, individual cancel buttons, and
  autonomy switch. **Wishes** gives optional activities, rewards, and a saved
  personal journal. **Hobbies** tracks reading, gardening, cooking, and painting, with five
  lasting ranks and useful activity bonuses. Wishes never expire; completed sets can renew on a later day.
- **Plan → Recent** shows the selected resident’s last eight deliberately planned
  activities: Done, Cancelled, or Interrupted, with a reason and game time. It
  retains routine names and completed results across saves and reconnects.
  Autonomous care stays out of the list. Loading a saved neighborhood explains
  any unfinished plans it clears; use **Upcoming** to return to the live plan.
- **Plan → Routines** keeps up to four named care/recreation sequences shared by
  your two residents. Start with Morning care or Wind down, or arrange one to six
  activities of your own. **Add to plan** finds reachable furnishings on the
  resident's current lot and appends the whole sequence after existing orders.
  Busy furnishings keep their normal waiting rules; missing furnishings or a
  full plan explain why the routine cannot be added. Editing/removing a saved
  routine leaves activities already in a plan intact. Routines persist through
  saves and reconnects; they run when you choose, without a repeating schedule.
  **Use current plan** copies care and recreation into an editable draft. It keeps
  repeated activities and explains omitted walking, conversations, garden work,
  and automatic care. Long plans keep every reusable step for you to trim to six.
  Review, name, and save the recipe; the current plan keeps running unchanged.
- **Edit** beside Household (or **Household** in the game menu) changes the
  household name, both resident names, clothing/skin/hair colors, hair style, and
  favorite pastimes (reading, television, gardening, tea, tabletop games, music and dancing, or a little of everything).
  Preview your choices, then Apply changes; Cancel or Escape leaves them alone.
  Choices belong to this neighborhood and persist through saves and reconnects.
  Favorites gently influence autonomous choices when needs are similar; urgent
  care and your orders come first. Plan shows the selected resident’s preference.
  Existing saves start neutral, and automatic leisure earns no wish or hobby progress.
- **People** shows the selected resident’s relationships and offers Visit or Chat.
  Up to two catch-ups per pair per day build friendship when both households
  are online: finish a chosen chat, or spend 12 game minutes in deliberately
  chosen shared games, dancing, or meals. Milestones appear in both journals. Busy residents finish
  their own plans first, and friendships never decay while someone is away.
  Earned catch-ups now show a brief notice naming the residents and their activity;
  its **People ›** button opens the relevant relationship. Group gains share one
  notice and soft cue. Loading, reconnecting, and time spent in menus stay quiet,
  and Effects volume controls the cue without hiding the text.
  Ongoing tabletop games show their occupied places. Visit the home, then use
  **Join game** to add it after your resident's planned activities, or **Queue
  game** to wait at a full table. The card distinguishes planned and active
  participation. A changed or finished game gets a clear response to stale clicks.
- **Mail** leaves a postcard for another household, even while they are away.
  Send one per household per game day, with an optional §100, §250, or finished
  painting. Money is charged on delivery; a painting leaves its easel, wall, or
  collection and waits safely in the postcard. Preview its subject and artist
  before sending. Recipients collect the original once, then **Hang this painting**
  opens build mode with it selected. Full collections and construction keep art
  gifts waiting safely; finish a draft before sending or collecting one. You can
  give a collected picture onward without changing its artist credit. The inbox holds
  24 postcards; read them and collect gifts before archiving to make room. The
  host saves mail with the shared neighborhood. Postcards are shared world data,
  not private messages outside the game.
- **Mail → Home news** keeps a return recap: actual neighborhood time spent away,
  allowance already credited, postcards delivered, and any discarded building
  draft. Unread recaps combine across absences. Mark one as read when ready; its
  history remains available, and uncollected gifts stay in the Inbox. A badge
  appears on Mail without interrupting play. Host downtime creates no catch-up.
- The world fills the window behind the HUD. **Activities** opens the optional
  action tray; construction opens the catalog. **Escape** closes either tray.
- Scroll to zoom and middle-drag to pan. **F** finds the selected resident;
  click their household name again or use **Plan → Find resident** for the same
  action. Selecting someone offscreen brings them into view. **Center** resets
  pan and zoom. **F11** toggles fullscreen. Key bindings are editable in Settings.
- **Guide & controls** is available from the main and pause menus. Its First day,
  Building, Neighbors, and Controls pages open the relevant game controls and
  reflect your current key bindings. New neighborhoods can show the guide first;
  uncheck that option to start directly in the world. The choice is saved on this
  device and can also be changed in Settings → Comfort.
- Idle residents can meet their own needs. There is no death in this foundation.

Construction shelters that home's residents, sends visitors home, and closes the
lot to new visits. Other lots continue normally. The first build tools edit the
visible construction draft. Finish construction commits it; disconnecting or
restarting restores the last committed layout. **Discard draft** restores it
explicitly. **Undo/Redo** reverses up to 32 edits, with exact prices restored;
a whole room counts as one edit. **Ctrl/Cmd+Z** undoes, **Ctrl/Cmd+Shift+Z** or
**Ctrl+Y** redoes. Each
household receives a prototype $600 allowance per simulated day.

## Share a neighborhood

1. One player opens the connection panel and chooses **Host**.
2. Share the displayed four-character code. The other player enters it and joins.
3. Each player receives their own household and lot. Returning with the same
   local profile reconnects to the same household.
4. If the code service is unavailable, use **Copy ticket** and join with the full
   ticket. Room codes expire; existing connections can continue, and the host
   can request a fresh code.

The host must keep running for shared-world time to pass. Disconnected households
remain in the world with forgiving caretaker behavior. When the entire host is
offline, saved time waits; this version does not simulate missed wall-clock time.
Clients do not become hosts automatically when a connection is lost.

A local profile contains the household recovery credential. Keep it private and
back it up if that household matters. Room codes are discovery conveniences, not
passwords. This is currently intended for a small trusted group, not open public
matchmaking or account-secured hosting.

For an always-on host:

The prototype has four household slots. A dedicated host currently reserves one,
leaving three remote households.

```sh
python3 tools/godot.py --headless -- --server --save-path=/absolute/path/neighborhood.json --profile-path=/absolute/path/host-profile.json
```

Default files are `user://neighborhood.json` and `user://profile.json` in Godot's
Simulateds user-data directory. The host keeps a `.bak` world backup. A damaged
primary world is recovered from a valid backup when possible; if neither is valid,
the original is protected and automatic saving is disabled.

For separate local test instances, use different `--profile-path` and `--save-path`
values after Godot's `--` separator. `--family-name=Name` selects the displayed
household name. Reuse a profile to reconnect to its household.
The host owns its save; a client does not overwrite its local neighborhood with
remote snapshots. Save schema changes will require explicit migrations.

## Develop and check

```sh
python3 tools/check.py
```

This is the repeatable check entry point; consult
[docs/VALIDATION.md](docs/VALIDATION.md) for the current suite and optional live
service checks. Export/build details are in [docs/BUILDING.md](docs/BUILDING.md).
The supported template targets are desktop, Android ARM64, and Linux dedicated
server; this game's device and release readiness must be tested separately.

The main extension points are the data-driven furnishing catalog, the pure world
model and command dispatcher, the Iroh session/persistence layer, and the separate
3D presentation (`lot_scene_3d.gd`) and camera/interaction bridge
(`lot_projection.gd`, `lot_view.gd`). Add game rules to the model, not the renderer or Rust
transport. Clients send intentions; the host validates and applies them.

See [THIRD_PARTY.md](THIRD_PARTY.md) for upstream transport attribution and
[LICENSE](LICENSE) for the project license.

## Everyday controls added during playtesting

Open **Plan** beside a resident's needs to see and cancel individual activities.
Use **↑ / ↓** to move upcoming activities earlier or later. The current activity
continues, and occupied furniture keeps its reservation. You can move another
activity ahead of a wait without canceling either one. Keyboard focus follows
the edited row; delayed multiplayer edits are rejected if the plan has changed.
The active row shows travel, who is keeping a furnishing busy, or activity
progress with an estimated time in neighborhood-clock minutes. Estimates account
for needs filling early and hobby bonuses. Progress waits with a paused world.
Autonomy is saved separately for each resident. Direct orders take priority over
automatic activities. Beds and bathroom fixtures allow one user at a time;
waiting residents keep their place in their own plan.

Buy the **Checkered game table** from Living for §340 (2×2 tiles). Click it to
inspect recreation, then **Play** for the selected resident or **Call household**
for eligible housemates on this lot. Up to four residents can join through their own plans.
Playing restores fun; two or more participants also restore social. Each gets
a separate place, and a fifth waits in their plan. Leaving the game preserves
everyone else's activity. Construction sends visitors safely home as usual.
The hover shows occupancy, and Plan explains when the game is shared.
Multiplayer uses protocol 2 for this new furnishing; all peers must update
together. Existing neighborhood saves still load.

Residents turn toward their accepted routes, furnishings, and conversation
partners. Seated poses follow the sofa's rotation; reduced motion keeps the
correct facing without animated turns. Shared chat bubbles and need labels leave
faces clear, and existing saved households need no conversion.

Click the visible furniture or resident body, and hover to see an object's use
and occupancy. In construction, **Undo** and **Redo** restore exact purchases
and sales within the current draft (up to 32 edits). Use Ctrl/Cmd+Z to undo,
Ctrl/Cmd+Shift+Z or Ctrl+Y to redo. **Discard building changes** still restores
the entire committed house. The neighborhood allowance survives these actions.

See [the playtest log](docs/PLAYTEST_LOG.md) for tested checkpoints and the next
usability priorities.

In construction, choose **Move**, click existing furniture, rotate if desired,
and click its new location. Moves are free and support undo. Green/red placement
footprints explain whether the position is valid before you commit; **Sell**
shows its refund. Escape releases an unplaced move selection.

**Wishes** gives each resident three optional activities and a personal journal.
Completing an activity yourself earns §40; finishing the set adds §80. Wishes
never expire while you are away. After completing a set, a new one is available
on a later game day. Autonomous activities still tend needs but do not earn wish
rewards. Completed and queued wishes cannot be claimed repeatedly.

**Hobbies** grow when a resident completes reading, gardening, or cooking that you
chose, whether through the hobby panel, care, wishes, or a furnishing. Each hobby
can gain two practices per game day; the five ranks require 0, 2, 5, 9, and 14 total
practices. Each rank above the first adds 10% primary need recovery and a small
secondary benefit (comfort from reading/cooking, fun from gardening). You can
keep enjoying an activity after the daily practice limit. Milestones appear in
the personal journal. Autonomy uses learned benefits without earning practice,
and being away never removes progress.

**Kitchen garden beds** cost §180 and fit on grass or floor. In live mode, click a
bed and choose radishes (§10 seeds, §45 harvest) or tomatoes (§20 seeds, §95
harvest). They need 4½ or 9 game hours of watered growth. Planting, watering, and
harvesting are deliberate resident activities; one resident reserves a bed while
it is in their plan. Full needs do not skip the work. Seeds are paid for and
harvest income is awarded only when the work finishes.

At a ripe bed, choose **Harvest & sell** for the listed funds or **Keep harvest**
for four vegetables. Each household’s pantry holds twelve radishes and twelve
tomatoes, with no spoilage while away. Planned kept harvests reserve room; a full
pantry leaves the crop available to sell or keep later. **Homegrown meals ›**
opens your dining table without choosing a recipe or moving anyone. If you have
no table, the button explicitly offers to enter construction with one selected.

**Garden ›** in either the dining-table or garden tray opens **Your kitchen
garden**, also available from Activities. It lists your own beds, their crops,
water and current plans, plus free pantry stock and possible homegrown bowls.
Choose a bed to inspect and center it; your resident stays where they are and
keeps their plan. The overview also offers explicit priced build actions and a
link back to homegrown meals.

A **Homegrown bowl** uses two radishes and two tomatoes for four portions, with
no additional currency cost. It restores hunger and comfort and supports the
same shared dining and cooking practice as purchased recipes. The pantry count
shows stock free after existing meal plans reserve their ingredients. Produce
is consumed only when food reaches the table; cancellation or construction
releases reservations. Stored produce belongs to the household, so construction
Undo/Discard cannot create or refund it. Older saves start with an empty pantry.

Dry crops stop growing without dying; ripe crops wait indefinitely. Growth
continues while you are away if the host is running and the bed has water.
Construction freezes the crop, and moving, undoing, discarding, saving, and
reconnecting preserve it. Visitors can help water, but only the lot's household
can plant or harvest. Completed work restores comfort and uses the existing
gardening hobby/wish rewards; autonomy never buys seeds or harvests crops.

## Music and dancing

Build a **Little hi-fi** (§260, Living), click it, then choose **Dance** or
**Call household**. Up to four residents
reserve distinct walkable spots beside it when the layout has room. Solo dancing restores fun; actual
participants also restore social while dancing together. A fifth resident waits
for a place. Each resident keeps their own plan, so cancellation, travel, or a
visitor leaving does not stop the others. **People → Join dance** discovers a
resident's current activity and adds it after your existing plans.

Both recreation trays show the household members who can join, who are already
playing or planned, and who are away, unreachable, or have a full plan. Calls only
affect your own household here, even when visiting a neighbor. Existing deliberate
plans stay first; different arrival times can mean playing separately. Inspecting
a furnishing does not issue an order. The Activities list offers each game table
and stereo separately so you can choose which gathering to use.

A full fun bar no longer cuts a chosen gathering short before its brief shared
moment. Residents already playing or walking to that same game or stereo allow
12 game minutes together, within each activity's usual duration. **Plan** explains
this as **Time for company** and keeps the next planned activity. You can still
cancel or travel freely. Automatic participation, a queued activity, or an absent
player does not keep anyone waiting.

**Choose current game/dance**, or a household call, can turn automatic participation
into chosen recreation while keeping the same place and remaining time. Earlier
automatic time earns no friendship, and the activity is not extended past its
natural finish. Other players continue to direct their own residents. A changed
household plan rejects the call before anyone is affected.

Dancing can be a favorite pastime and a step in household routines. The hi-fi
has a visible playing note and residents use a raised-arm dance pose; Reduced
motion keeps a still, recognizable pose. One visible stereo plays an original
music loop at a time, favoring the selected dancer's stereo. It lowers the
background score, follows the Music slider, and stops with pause/menus,
construction, or when offscreen. Effects mute still leaves music audible.

## Making room for company

Hover over a stereo or game table to inspect the places around it. Open rings
show clear floor, solid gold dots mark reservations (including residents still
walking there), dashes show someone standing there, and crosses show blocked or
unreachable tiles. The count reflects the actual room, with a maximum of four
participants. **People** offers **Queue dance/game** when no place is free and
explains whether the room is too tight, places are reserved, or someone is in
the way. A waiting order stays in your plan.

While buying or moving shared furniture, the preview shows how many people the
proposed layout can hold. **Solo only** is useful for a small music corner; leave
more reachable floor around it to enjoy company. These hints do not spend money
or change the house. Construction ignores the temporarily sheltered residents
when counting usable space. The existing Access check still decides whether the
whole house is ready to reopen.


When someone finishes a game or dance and another resident is waiting for that
place, they can take one clear step aside. **Plan** shows **Making room for …**
and lets you cancel it; a new direct order interrupts it immediately. Your queued
activities always come first. This small finishing movement works with autonomy
off, does not earn rewards, and is excluded from saved routines and Recent.
It avoids occupied tiles, walking routes, doorways, the waiting resident's approach,
and places around other shared furniture. If there is no safe nearby step, the
resident stays put and the waiting explanation remains available. Canceling an
activity yourself does not trigger a courtesy step.


## Friendship through shared play

Games, dancing, and shared meals build the same lasting relationships as chats. Both residents
must choose their participation and spend at least **12 game minutes together**
at the same game table, stereo, or dining table. Time walking there, taking part alone, or watching nearby
does not count. Automatic leisure still restores needs, but does not farm
friendship. If your resident is participating automatically, **People → Join**
lets you explicitly choose that activity.

Chats, games, dances, and meals share **two catch-ups per pair each game day**, with the
same bounded relationship gain. Repeated snapshots, both participants observing
the result, and continuing the same encounter past midnight do not award it again.
People shows the last chat/game/dance/meal and today's remaining catch-ups; milestones
enter both residents' journals. Friendship and these memories survive saving and
reconnecting, without decaying or growing while a household is away.
