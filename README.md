# Simulateds

A playable foundation for a small shared-neighborhood life simulation, inspired
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
[docs/ROADMAP.md](docs/ROADMAP.md) for follow-up milestones, and
[docs/VALIDATION.md](docs/VALIDATION.md) for tested behavior and remaining gaps.

## Run

Install Python 3.11+, Rust via rustup, and your platform's compiler (Xcode Command
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

**Settings** persists separate Master/Music/Effects/Ambience volumes, fullscreen,
VSync, frame cap, scenery detail, UI scale, reduced motion, and key bindings.
Conflicting bindings are rejected. Escape and F1 remain recovery shortcuts.
Original menu/live/build music, garden ambience, and UI sounds are included;
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
- Click a **need bar** to add a suitable care activity on the resident’s current
  lot. The host finds a reachable option, prefers free furnishings, and keeps
  existing player orders in sequence. **Care** beside the resident’s mood shows
  suggestions, planned activities, and explanations for unavailable furnishings.
- Open **Neighborhood** to choose a lot. **Visit lot** sends the
  selected resident there; **Go home** returns them to their own lot.
- On your home lot, choose **Build & buy**, choose a tool or furnishing, then click a
  tile. **Sell** removes something; **R** rotates placement. **Move** rearranges
  furniture for free. Choose
  **Finish building** to resume life on the lot.
- **Room** builds floors, perimeter walls, and a doorway from two opposite corners.
  The preview shows the full price; **R** changes the doorway side. Existing
  floors, walls, and doors are preserved where possible and only new pieces cost
  money. **Escape** cancels the first corner. Rooms need at least 3 × 3 tiles.
- The build **Catalog** groups items by room/use. Search within a category by
  name or activity (for example, "sleep", "meal", or "book"). **Ctrl/Cmd+F** focuses
  search, **Enter** selects the first result, and **Escape** clears a search before
  closing the tray. Selected item cost, footprint, and use stay above the edit
  controls. Over-budget items can still be selected for a placement preview.
- **Floor finishes** and **Wall finishes** in the catalog offer wood, tile, carpet,
  and paint palettes. Choose a finish and two corners to decorate an area; click
  the same tile twice for a single tile. The preview shows the look and exact
  price. Only changed existing surfaces cost money (§4 per floor tile, §3 per
  wall tile), and one Undo restores the whole area. Finishes have no resale bonus.
- **Plan** shows the selected resident's actions, individual cancel buttons, and
  autonomy switch. **Wishes** gives optional activities, rewards, and a saved
  personal journal. **Hobbies** tracks reading, gardening, and cooking, with five
  lasting ranks and useful activity bonuses. Wishes never expire; completed sets can renew on a later day.
- **Edit** beside Household (or **Household** in the game menu) changes the
  household name, both resident names, clothing/skin/hair colors, and hair style.
  Preview your choices, then Apply changes; Cancel or Escape leaves them alone.
  Choices belong to this neighborhood and persist through saves and reconnects.
- **People** shows the selected resident’s relationships and offers Visit or Chat.
  Two completed catch-ups per pair per day build a shared friendship when both
  households are online. Milestones appear in both journals. Busy residents finish
  their own plans first, and friendships never decay while someone is away.
- **Mail** leaves a postcard for another household, even while they are away.
  Send one per household per game day, with an optional §100 or §250 gift. Gifts
  are charged on delivery and collected once by the recipient. The inbox holds
  24 postcards; read them and collect gifts before archiving to make room. The
  host saves mail with the shared neighborhood. Postcards are shared world data,
  not private messages outside the game.
- The world fills the window behind the HUD. **Activities** opens the optional
  action tray; construction opens the catalog. **Escape** closes either tray.
- Scroll to zoom and middle-drag to pan. **F11** toggles fullscreen.
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
isometric presentation. Add game rules to the model, not the renderer or Rust
transport. Clients send intentions; the host validates and applies them.

See [THIRD_PARTY.md](THIRD_PARTY.md) for upstream transport attribution and
[LICENSE](LICENSE) for the project license.

## Everyday controls added during playtesting

Open **Plan** beside a resident's needs to see and cancel individual activities.
Autonomy is saved separately for each resident. Direct orders take priority over
automatic activities. Beds and bathroom fixtures allow one user at a time;
waiting residents keep their place in their own plan.

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
