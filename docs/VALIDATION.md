# Validation record

Checked locally on November 3, 2026. This record describes **Simulateds**, not the
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

Physical Android operation, cross-OS multiplayer, exported game packages,
production authentication, public matchmaking abuse resistance, long-term
balance, overnight simulation, packet impairment, GitHub Actions/release status,
and human family playtests require separate evidence. A local headless pass does
not prove any of those. macOS Intel, Windows, Linux, Android, and server export
presets/build infrastructure are inherited targets; they were not exported or
validated as this game by the checks above.

See [ROADMAP.md](ROADMAP.md) for the next acceptance gates.
