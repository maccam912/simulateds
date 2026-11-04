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

- Select a resident with their portrait. Click a floor or lawn tile to walk;
  click a furnishing to use it. Their needs and current action appear in the UI.
- Open **Neighborhood** to choose a lot. **Visit lot** sends the
  selected resident there; **Go home** returns them to their own lot.
- On your home lot, choose **Build & buy**, choose a tool or furnishing, then click a
  tile. **Demolish** removes something; **R** rotates placement. Choose
  **Finish building** to resume life on the lot.
- The world fills the window behind the HUD. **Activities** opens the optional
  action tray; construction opens the catalog. **Escape** closes either tray.
- Scroll to zoom and middle-drag to pan. **F11** toggles fullscreen.
- Idle residents can meet their own needs. There is no death in this foundation.

Construction shelters that home's residents, sends visitors home, and closes the
lot to new visits. Other lots continue normally. The first build tools edit the
visible construction draft. Finish construction commits it; disconnecting or
restarting restores the last committed layout. **Discard changes** restores it
explicitly. There is no per-action undo tool yet. Each
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
