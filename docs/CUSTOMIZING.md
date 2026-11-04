# Extending Simulateds

The foundation separates game rules, content, presentation, persistence, and
transport. Read [DESIGN.md](../DESIGN.md) before adding systems that affect another
household or an absent player.

| File | Responsibility |
| --- | --- |
| `game/catalog.gd` | Furniture prices, footprints, need effects, duration, labels, and color hints |
| `game/room_copy.gd` | Pure enclosed-room capture, rotation, price/access inspection, and surface application; authority allocates fresh furnishing IDs |
| `game/furniture_colors.gd` | Named material palette, optional validated object color, and pure recoloring preview; missing metadata preserves legacy art |
| `game/build_impact.gd` | Pure before/after access forecasts for validated placement, movement, and room drafts; reports new problems and repairs without changing authority rules |
| `game/paintings.gd` | Bounded canvas state, subjects, credit, activity validation, and sale value; the world's `painting` command owns progress and payment |
| `game/painting_art.gd` | Original vector miniatures rendered in stages on the easel and in its inspection tray |
| `game/painting_panel.gd` | Subject previews, progress/credit, resumable activity controls, and correlated host feedback |
| `game/wall_art.gd` | Bounded household collection, pure transfer previews, save validation, and safe storage when a wall changes |
| `game/wall_art_panel.gd` | Collection selection, wall display, storage, empty-easel return, and visitor inspection |
| `game/world.gd` | Serializable neighborhood state; ownership, construction, pathfinding, actions, autonomy, and needs |
| `game/main.gd` | Main scene UI, selection, tool catalog, connection panel, and command submission |
| `game/lot_view.gd` | Isometric rendering, tile picking, placement preview, pan, and zoom |
| `game/style.gd` | Shared UI theme |
| `game/persistence.gd` | Bounded JSON reads and temporary-file replacement with backups |
| `network/session.gd` | Host tick, persistent identity, command IDs/acks, snapshots, saving, and reconnect lifecycle |
| `network/rooms.gd` | Short-code lifecycle and asynchronous cancellation |
| `network/rendezvous.gd` | Short-code HTTP API |
| `native/iroh/src/` | Encrypted Iroh transport; no game rules |
| `tools/` | Pinned setup, checks, builds, exports, and packaging |

## Add a furnishing

1. Add a stable key and definition to `Catalog.ITEMS`. Provide a readable name,
   cost, footprint, visual color, need, rate, duration, and description.
2. Add its drawing to `lot_view.gd` (the fallback block is useful while prototyping)
   and expose it in the appropriate palette group in `main.gd`.
   Name its recolorable material in `FurnitureColors.MATERIALS` and use
   `FurnitureColors.material` for that material in its renderer. Keep the original
   color as the fallback and leave distinct details such as foliage unchanged.
3. Add a readable activity label in the model when it needs one. Ordinary
   single-need furniture uses the existing interaction machinery.
4. Check rotation, collision, placement cost/refund, reachable interaction cells,
   autonomy selection, and save round-trip.

Existing saves keep the item's stable key. Renaming or deleting a key requires a
save migration; changing a footprint may invalidate an old home's layout.

## Add a game system

Start with a serializable state definition and a host command. Validate identity,
ownership, range, timing, and capacity before changing state. Return a clear
accepted/rejected result. Keep animation and UI derived from accepted state.

Define what the feature does while its household is absent, while its home is
under construction, and while the host is stopped. A feature that changes another
player's household also needs explicit permission rules. Give irreversible life
events a clear player consent model before implementing them.

`World` is a `RefCounted` model with no scene-tree, network, or filesystem
requirements. It is suitable for fast deterministic tests. `snapshot()` includes
live runtime state for replication; `snapshot_for_save()` excludes uncommitted
construction layouts. `restore(data, true)` preserves validated runtime state for
network snapshots; normal save restore resets transient presence and actions.
Do not accidentally use save-load normalization on every network update.

## Protocol and state changes

Clients send intentions; the host owns authority. Keep request IDs, duplicate
protection, acknowledgement, bounded queues, and atomic snapshot reassembly.
Do not assign the Iroh peer to `multiplayer.multiplayer_peer` while this session
also polls packets directly. Godot high-level RPC is not a drop-in replacement
for this template's explicit protocol.

For an incompatible application protocol, change the version/namespace in
`network/session.gd`, `project.godot`, and Rust's ALPN together, then rebuild native
libraries. See [NETWORKING.md](NETWORKING.md) for the current wire contract.
For a save schema change, add an explicit migration and old-version fixtures.
Never silently reinterpret an unknown future save or overwrite it with a new world.

Full snapshots are intentionally bounded for four small lots. Measure bandwidth,
CPU time, and memory before expanding capacity. Introduce lot interest, revisioned
deltas, and full-state repair when needed rather than merely raising packet limits.

## Validate the changed boundary

Run `python3 tools/check.py` for model, integration, protocol, and real Iroh process
checks. Add focused cases for meaningful new rules. Use `tests/render_game.gd`
for a graphical capture and inspect the resulting live/construction screenshots;
a headless test cannot prove the interface fits or controls are understandable.

Cross-platform exports, physical Android operation, suspend/resume, long host
sessions, network impairment, and family playtesting are separate acceptance
steps. Keep [VALIDATION.md](VALIDATION.md) accurate about which were exercised.
