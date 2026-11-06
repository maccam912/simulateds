# Simulateds

A small, persistent neighborhood life simulation inspired by the readable houses,
expressive needs, and domestic comedy of early life-simulation games. The first
neighborhood is **Linden Grove**. Its characters, art, names, and objects are
original; this is not a recreation of an existing game's assets or stories.

## The promise

Build a home worth living in, help a household find its rhythm, and share a
neighborhood without needing everyone to play at the same time. Two people may
be doing completely different things: one rearranges a kitchen while the other
makes dinner, reads, or visits an available neighbor.

The foundation prioritizes four things:

- **A legible dollhouse.** An isometric grid, cutaway walls, recognizable
  furnishings, and visible resident intentions make domestic life easy to read.
  The world fills the viewport edge to edge. Compact controls overlay the scene;
  opening a catalog never shrinks the camera into a panel.
- **Needs create choices.** Food, rest, hygiene, bladder, fun, company, and comfort
  compete for time. Objects are useful, not merely decorative.
- **Separate households, shared time.** Every player controls their own family
  and builds only their own lot. The host owns the authoritative neighborhood.
- **Kind persistence.** Absent players keep their homes and families. Being away
  must not become a punishment or an obligation to log in every day.

## First playable loop

1. Enter the neighborhood and receive a lot, starter funds, a furnished starter
   home, and two residents.
2. Select a resident. Inspect their needs and current intention.
3. Right-click (or touch and hold) furniture or a resident for contextual choices.
   Left-click remains a quick way to walk, select someone, or use furniture.
   The quiet HUD expands needs and secondary controls only on request. A resident travels to a
   reachable interaction position before receiving an object's benefit.
4. Let autonomy handle ordinary needs or give a more interesting instruction.
5. Enter construction, add floors and walls, make doorways, buy furnishings, and
   reopen the home.
6. Visit another household when its lot is open. Return home whenever desired.
7. Leave and return to the same household while the host keeps the world alive.

New starter homes include a movable linen floor lamp beside the sofa. It uses
the ordinary catalog fixture and leaves the §12,000 starting funds intact;
loading an existing neighborhood never adds or replaces its furnishings.

Life stages and family ties are chosen in the household creator. There is no
automatic aging, death, wedding, career simulation, or elaborate economy in this slice. Initial funds, a $600 per simulated day household allowance, and
modest object costs make building possible. The allowance also accrues for absent
households while the host runs; it is prototype funding, not a balanced economy.
Jobs and maintenance systems need their own balancing pass.

## World and ownership

The initial world has four 16-by-16 lots. Each household has one home lot, starts with two residents, and can grow to
eight through the household creator. Persistent household identity is separate from the temporary numeric
connection IDs assigned by Iroh. A reconnect must recover the existing household
rather than allocate a new one.

A player may direct their own residents on any open lot. They may not direct a
neighbor's family or edit a neighbor's home. Inspecting a lot is distinct from
sending a resident to visit it. All commands are checked by the host, including
ownership, coordinates, object existence, construction state, and available money.

The host can play a household too, or run headlessly. Host migration is out of
scope. One host owns a save; independently edited copies cannot be merged.

## Construction is a lot-local state

Construction is an explicit host-accepted state transition:

1. The owner requests construction on their home lot.
2. Visitors are returned to their own home lots and their visit actions stop.
3. Residents of the home being edited are sheltered while it is under construction.
   They remain visible in place, never veto edits, and the host relocates anyone
   displaced or cut off by an accepted edit to clear space by the street.
4. New visits and ordinary interactions on that lot are rejected.
5. The owner places or removes floors, walls, doors, and objects using validated
   transactions. Placement checks bounds, occupancy, footprint, and funds.
6. Reopening returns the lot to live simulation; any unusable position must be
   repaired or rejected safely.

Build & buy offers a visual furniture catalog, room/use categories and search,
drag placement, movement and quarter-turn rotation. Surfaces include flooring,
wallpaper and paneling. Windows admit daylight through actual wall openings;
placeable fixtures cast local light and shadows. Interior walls and doorways
include 45-degree segments. A house may have three floors, connected by straight
stairs with clear landings. Floor editing shares the lot's budget, revision and
undo history; residents use stairs explicitly before interacting upstairs.

Landscaping includes trees, shrubs, flowers, benches, fences, rocks and outdoor
lights, rectangular pools, and round terrain raise/lower/flatten/material
brushes. Pools block walking; swimming is not an activity yet. Terrain protects
foundations and the entrance, with heights bounded from -0.75 to 1.5 tiles.

The rest of the neighborhood continues to run. There is no shared pause or
player-controlled global fast-forward. A disconnect releases construction so a
forgotten editing session cannot leave a lot locked indefinitely. This first
version applies edits visibly while construction is active but retains the last
committed layout. Successful reopening commits the work. Disconnecting or loading
a save rolls unfinished construction back, including its money changes. The owner
can discard the draft explicitly, undo/redo transactions, and save room designs.

## Residents and needs

Each resident carries seven needs on a 0–100 scale: hunger, energy, hygiene,
bladder, fun, social, and comfort. Need definitions and object affordances belong
to the simulation layer, not to the renderer or network transport.

Movement uses the lot's walkable grid. Walls and furniture footprints block
travel; doors provide walkable passages. An interaction targets a reachable
adjacent cell. Television use instead prefers an available seat facing the screen,
reserving that furnishing and a front approach cell on the host. Without suitable
seating, choose a clear standing place in front of the screen. Each TV viewer
reserves a whole seating furnishing; independent cushion capacity is deferred. Actions consume simulated time and improve relevant needs only
when actually performed. A queue and explicit cancellation provide a place to
add richer behavior later. Autonomy chooses useful reachable objects when the
player has not supplied an action. Failed routes must finish with a clear result,
not leave a resident permanently busy.

This is a foundation for personality rather than a finished personality system.
Future traits can weight actions and relationships without changing the ownership
or transport model. Animations, reactions, sounds, and thought bubbles can all
read the same action state.

## Playing together and at different times

| Situation | Intended behavior |
| --- | --- |
| Both players manage families | Both households advance in the same authoritative world; visits are possible. |
| One player builds | Only that lot is sheltered and closed to visitors; other lots continue. |
| One player disconnects | Their identity, family, home, furniture, and funds remain. The family uses caretaker behavior. |
| A player reconnects | Their saved local credential identifies the existing family; the host sends a fresh world snapshot. |
| Host remains running overnight | The simulation continues with bounded needs for absent households. |
| Host is shut down | Saved state waits. No wall-clock catch-up is applied on restart in this foundation. |
| Host disconnects unexpectedly | Clients stop issuing accepted actions; they must rejoin the host. They do not become new authorities. |

Caretaker mode is deliberately forgiving. It preserves the household and avoids
catastrophic neglect while someone is absent. The current daily allowance applies to absent families too; a future economy
should bound offline gains. Caretaker behavior must not resolve major life events
without the player's consent. Later versions can introduce
player-selected schedules and a short "while you were away" journal. Offline
visitors may interact with the environment, but future relationship and gifting
systems need explicit household privacy rules.

A room code is convenient discovery, not an account password. The initial
persistent credential is intended for a small trusted group. Losing a profile
file loses its recovery credential; copying that credential copies access to the
household. Account login, invitations, recovery, and moderation are separate
milestones.

## Architecture and extension points

| Layer | Responsibility | Extension path |
| --- | --- | --- |
| `game/catalog.gd` | Furniture definitions, cost, footprint, visual hint, and need affordance | Add object kinds without writing networking code. |
| `game/world.gd` | Authoritative serializable state, commands, routing, needs, and autonomy | Add action/need/trait systems behind the same command boundary. |
| `network/session.gd` | Identity binding, command acknowledgement, snapshot replication, host tick, and lifecycle | Add interest management and permissions without moving simulation rules into clients. |
| `network/rooms.gd` and `network/rendezvous.gd` | Join-code discovery and cancellation | Replace the code service without changing game rules. |
| `native/iroh/` | Encrypted peer transport and relay fallback | Keep game-specific rules out of Rust transport. |
| Presentation | Isometric rendering, controls, selection, needs, build palette | Replace prototype art or introduce richer scenes without changing saves. |
| Persistence | Versioned host saves and separate client profile | Add explicit migrations when the state schema changes. |

Clients submit intent, never authoritative world edits. The host applies a
command once and returns an accepted/rejected result. World snapshots are
bounded and reassembled atomically; a partial snapshot must never become the
visible world. Clients do not save a remote host's snapshot over their own local
neighborhood. The native transport remains the one supplied by the
[Godot Iroh template](https://github.com/maccam912/godot-iroh-template).

Whole-world snapshots are a reasonable starting point for four small lots.
Before expanding population or lot size, measure bandwidth and move to revisioned
lot snapshots or deltas, with periodic full-state repair. Do not silently raise
packet limits or let queues grow without bounds.

## Save policy

The host periodically saves accepted state and saves during an orderly shutdown.
World files have a schema version and must be validated before activation. A
backup should remain available if the current save is invalid. Temporary writes
and replacement reduce the risk of losing the prior save during interruption.
Failed saves must be reported; they are not evidence that data is durable.

A save migration is an explicit function from one schema version to the next,
with a fixture test. Unknown future versions must not be silently overwritten.
Player display names are presentation; they are not ownership credentials.

Continuing an autosave or loading a named slot in solo play starts paused before
the first tick. The saved 1×, 2×, or 4× pace is restored on resume. A save keeps
the selected resident, lot, floor and camera framing as optional local metadata
for the saving profile. Older saves use the default framing and resume at 1×.
New neighborhoods start at 1×. Without saved camera framing, the view fits the
home's floor plan. More → Home overview repeats that camera-only framing on the
home's ground floor; Find resident keeps zoom and shows their actual lot/floor.
Shared sessions retain their own clock and
disconnect rules.

The local household keeps walkable positions, including upstairs and on visits.
An unsafe position returns its resident to the home entrance. Ordinary walks
and single-furnishing plans continue with their route, timing and active
reservation after revalidation. Conversations, shared recreation, stair
orders, meals, painting, gardening, artwork admiration and courtesy movement
stop on load. Completed effects and already saved work remain. The load notice
summarizes interruptions, with details on hover and deliberate plans recorded
in Recent activity. Absent households start caretaker behavior at their saved
positions. Unfinished construction still rolls back.

Replacing an active world first saves a named recovery copy. The load notice
links to that exact copy, and the Load menu offers it again while that world is
open. Recovering the previous world leaves the original named slot intact.

## Next design decisions

The immediate playtest should answer whether ordinary home life is enjoyable,
not how many systems can be added. Test one parent and one child playing together:
one builds, the other runs a family, they visit, one leaves, and later reconnects.
Watch whether object use is understandable, whether paths fail politely, and
whether the household feels safe to leave alone.

After that, decide the following in order:

1. **Building grammar:** multi-tile rooms, wall edges versus blocked tiles,
   roofing, camera rotation, and a clear undo model.
2. **Family agency:** customization, traits, action queue UI, and predictable
   autonomy overrides.
3. **A sustainable day:** simple jobs or activities, bills, income, and explicit
   grace periods for absent players.
4. **Social rules:** relationship ownership, invitations, guest permissions,
   shared objects, and consent for changes involving another household.
5. **Long-term life:** skills, aspirations, ages, pets, and neighborhood events.

See [ROADMAP.md](docs/ROADMAP.md) for milestone exit criteria and
[VALIDATION.md](docs/VALIDATION.md) for what has actually been checked.

## Character creation

**Edit household** opens a dedicated dressing room with a large, rotatable
3D resident, idle breathing, glances and blinks. The studio shares its parametric
geometry with the neighborhood; all previews are private drafts. Save household
submits one revision-checked command. Cancel/Escape discards an unsent draft;
while saving, wait for the host response before leaving the creator.
Offline life pauses; a shared neighborhood keeps running.

Residents have names, pronouns, a chosen life stage from baby to elder, skin/hair/
eye colors, ten hairstyles, height, fullness, shoulders, hips, face/nose controls,
and a voiced nonverbal greeting with four timbres and adjustable pitch. Seven
independent wardrobe slots cover casual, formal, sleep, swim, athletic, party and
outdoor clothing. Each combines a top, bottom, shoes, accessory, colors and fabric
detail; the selected wearing slot is used in the neighborhood. Automatic outfit
changes by event are not implemented.

Pick up to three traits and neutral/like/dislike interests. Supported interests
and traits gently weight ordinary autonomous choices without overriding urgent
care or deliberate orders. Creative/painting preferences are retained for future
autonomous art behavior; artwork still requires an explicit plan. Family links
include partners, spouses, siblings, parents/children and grandparents. They are
separate from earned friendship and visible in People. Family editing is confined
to the owner's residents and validates age/ancestry constraints atomically.

Add residents up to eight; newly added draft residents can be removed before
saving. Established residents are retained: moving out/deleting them needs a
separate flow that preserves their history. Age stages stay fixed until edited.
Babies rest in a solid-geometry bassinet at home with stable needs and cannot be
sent on ordinary activities or batch travel. Pregnancy, autonomous aging, hands-on
infant care and age-specific careers/school are future simulation work.
