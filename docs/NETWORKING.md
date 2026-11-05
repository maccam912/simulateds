# Persistent neighborhood networking

Simulateds uses the source and native transport from
[maccam912/godot-iroh-template](https://github.com/maccam912/godot-iroh-template).
The Rust extension keeps Iroh 1.4.1, direct connections, relay fallback, bounded
queues and explicit `MultiplayerPeer` packets. The application ALPN and room-code
namespace are both `simulateds/1`. The transport does not use high-level Godot RPCs.

## Authority and time

The host owns one `game/world.gd` model, advances it at 10 Hz, and saves it every
10 seconds and after accepted construction commands. A client submits a command;
the host binds it to that connection's family, validates it in the model and sends
an acknowledgement. Clients never author funds, needs, ownership or positions.
There are four persistent lots, one family per lot, and at most four simultaneous
connections including the host. An allocated lot stays allocated after logout.

Each player can build or control their own family independently. Construction is
a lot-local transaction: visitors return home, residents freeze, other lots keep
running. Finishing commits the layout after walkability checks. Disconnect rolls
back the unfinished transaction and enables caretaker behavior. Saved snapshots
contain the last committed layout, so a crash also cancels unfinished construction.
Visitors cannot enter a lot under construction. The host remains required for
asynchronous play; no simulation catchup runs while the host process is stopped.
There is no host migration or offline merge.

## Identity

`user://profile.json` stores a randomly generated 256-bit bearer credential and
family display name. The host derives the persistent family ID from its SHA-256
hash, never from a client-supplied family ID. Reconnecting with that credential
reclaims the same household. Two simultaneous connections with the same identity
are rejected. The local host reserves its profile's family; a dedicated server
keeps that family in caretaker mode.

The profile file is a credential: keep it private and copy it deliberately if
moving a family to another device. Losing it loses automatic access to that
family; account recovery, invitations, host moderation and lot reassignment are
future work. Display names are labels, not login identities. A four-letter room
code is discovery, not authentication; anyone with a valid code/ticket can claim
a free lot. The trusted host can inspect or modify the world. This foundation is
intended for small trusted family sessions, not public adversarial servers.

## Wire format and limits

Protocol version 1 uses reliable, ordered channel 0. All packets are JSON encoded
as UTF-8 and limited to 1,024 bytes, below the native 1,200-byte reliable ceiling.

| Message | Direction | Purpose |
| --- | --- | --- |
| `hello` / `welcome` / `reject` | Both | Version, credential and household admission |
| `command` / `ack` | Client / host | Validated intent, monotonic request ID and result |
| `chunk` | Host | Bounded compressed full-world snapshots |
| `chat` | Both | Optional 160-character room messages |

Commands carry a per-connection increasing request ID. The host caches 64 replies
and rejects older evicted IDs using a high-water mark, so replay cannot repeat a
purchase. It accepts at most 30 new commands per peer per second. Clients allow
16 pending actions, retry at 1.5-second intervals, and disconnect after four
unsuccessful attempts rather than guessing whether an action happened.

Twice per second the host serializes a snapshot, compresses it with DEFLATE, and
splits it into chunks of at most 600 bytes before base64 encoding. Snapshots are
capped at 512 KiB uncompressed / 75 KiB compressed / 128 chunks. Sending is paced
at eight packets per frame total, round robin across peers. A peer already
receiving a snapshot waits for the next one rather than accumulating an unbounded
backlog. The client requires host ID 1, consistent snapshot ID/count/size and
sequential chunk indices; a validated complete world replaces the visible state
atomically. Partial, stale, oversized and malformed snapshots are ignored. A
client disconnects after 20 seconds without an accepted snapshot.

Full snapshots are deliberately simple for four small lots. Larger worlds will
need interest subscriptions and deltas. These bounds are not an Internet-scale
abuse-resistance claim. `tests/protocol.gd` exercises packet, replay and authority
boundaries. `tests/smoke_peer.gd` runs real host/two-client building, visitor recall,
and reconnect through Iroh.

## Persistence

`user://neighborhood.json` holds the authoritative world. Saving writes a temporary
file then renames it, retaining the previous validated state as `.bak`. A corrupted
primary save falls back to its valid backup. If neither can load, a temporary
world opens with saving disabled, preserving the damaged files for recovery.
The disk schema is validated before adopting state. World data is plain JSON;
no executable Godot objects are deserialized.

Joining saves and retains the local world separately. Received host state is not
written to the client's local save. Leaving restores the local neighborhood.
Network snapshots preserve online/construction/action state, whereas disk restores
normalize sessions, release construction and resume caretaking.

CLI arguments (after Godot's `--`) allow isolated profiles and servers:

```sh
python3 tools/godot.py --headless -- --server \
  --save-path=/absolute/path/neighborhood.json \
  --profile-path=/absolute/path/host-profile.json \
  '--family-name=Host family'
```

The server prints `SIMULATEDS_SERVER_READY ticket=...` after starting. Keep the
process running and share a current ticket. The graphical Host flow also obtains
four-character codes through the template's existing owner-managed rendezvous
service; it is discovery only, not the simulation server. Codes expire after ten
minutes, can be refreshed, and are revoked on normal leave when the network is
available. Existing Iroh connections outlive code expiry. See `network/rooms.gd`
for cancellation and stale-HTTP-response handling inherited from the template.

## API for presentation

`Session.state` is read-only by convention and supplies the current world's
dictionaries. Use `Session.profile_id`, `display_name`, `home_lot()`,
`is_authority()`, `command(intent)` and `save_world()`; subscribe to
`world_changed`, `status_changed(message)`, and `action_result(message)`.
`Rooms.host()` / `Rooms.join(code_or_ticket)` handle discovery, while
`Session.host()` / `join(ticket)` bypass it. `Session.leave()` restores local play.
The model is transport-independent and can be tested without Iroh.

## Front-end menus, named saves, and developer commands

`Session.menu_paused` suspends simulation only in local offline play. The scene
tree itself is never paused: room requests, network polling, snapshots and a
hosting player's shared simulation continue while menus are open. Dedicated
servers do not depend on the front end.

The save menu calls `list_saves()`, `save_slot(name, id="")`, `load_slot(id)`, and
`new_world(name)`. Named saves contain a versioned metadata envelope and the
committed world, use validated opaque IDs rather than caller-supplied paths, and
keep the previous valid version as a backup on explicit overwrite. The default
library is `user://saves`; custom `--save-path` values receive a separate
`<save-basename>-slots` library. `--slots-path` overrides that directory. The
special read-only listing ID `autosave` represents the current active world.

Loading and starting a new world require an offline session. A candidate world
is fully validated, including room for the local profile, before any switch.
The current world is saved both to its autosave and to a named recovery copy;
then the candidate autosave is written before the live model is replaced. A
failed validation or write leaves the active model intact. Corrupt named saves
are listed with an error, or recover their previous valid backup when available.
An unrecoverably damaged active autosave stays protected: save a named copy and
restart with a new `--save-path` before switching worlds.

`Session.execute_debug(line, selected_member_id="")` uses an explicit command
registry; it does not evaluate GDScript, shell commands, paths, or arbitrary RPCs.
`help` and `stats` work on clients. World mutations are accepted only on the host
or offline authority. Console text is not sent through the command protocol.

| Command | Behavior |
| --- | --- |
| `rosebud`, `motherlode` | Add 1,000 or 50,000 to the local authority's household. |
| `money <amount>` | Set household funds, bounded to 0–10,000,000. |
| `needs [all\|need] [value]` | Set the local household's needs, bounded to 0–100; no arguments restores all to 100. |
| `time HH:MM` | Set time of day without changing the day count or paying an allowance. |
| `speed <0..8>` | Adjust authority simulation speed; zero pauses simulation while networking remains live. |
| `teleport <x> <y>` | Move the selected owned resident to a reachable, unoccupied tile. |
| `cancel` | Clear the local household's action queues. |
| `construction cancel` | Discard the local household's construction draft. |
| `save` | Write the active autosave and report success or failure. |

Money commands are rejected during construction to preserve the draft's budget
transaction. Gameplay changes pass through bounded domain checks and appear in
the neighborhood event history; normal snapshots replicate them. Speed is a
runtime control, reset when changing worlds or leaving a session, and is not
saved. This development console is intentionally available in the foundation;
it is not a public-server moderation or privilege system.


## Household art commissions

`commission_accept`, `commission_cancel`, and `commission_deliver` are authority
commands scoped to the authenticated household. Each carries `offer` and an exact
`commission_revision`. Delivery additionally identifies the own-home lot revision,
`art_source`, and `art_id`; its review never selects a replacement original.
`WallArt.transfer_option` and `detach` now share custody rules between gifts and
commissions. A delivery checks construction, current/queued painting plans, subject,
original identity, and budget capacity before crediting §180 and removing the art.
The accepted command is immediately saved by the authority. Replies remain
correlated to the exact submitted intent; clients also wait for the newer board.

The optional `family.commissions` field stores a revision, current acceptance,
completion count/day, and four recent receipts. Old saves acquire an empty board
without payment. Versioned offer terms are immutable. Add new IDs if terms change;
never rewrite a published ID's subject or reward. Offers rotate only on delivery,
not on cancel or reconnect. There is no expiry and at most one delivery per game
day. Recent receipt IDs cannot also exist as held art or unclaimed mail escrow;
claimed postcard receipts are historical and may retain the artist's picture.
No schema or transport version change is required for this additive state.


## Kept harvests and homegrown cooking

The existing `garden` command accepts `action: keep` with the exact garden
revision. Completing it adds four of that crop to the authenticated household’s
pantry and resets the bed, with no currency payment. Cash harvests keep their
existing action. The existing `meal` command accepts `recipe: homegrown`; serving
consumes two radishes and two tomatoes and creates four portions in one simulation
step. Validation repeats immediately before either resource change.

`family.pantry` contains bounded integer radish/tomato counts (0–12 each). Older
saves acquire zero stock. Accepted current and queued preparation tasks reserve
ingredients; accepted kept harvests reserve pantry capacity. Reservations derive
from stable action IDs and current garden/table revisions, so cancellation,
construction, and stale plans release them. Incoming crops cannot fund a recipe
before they are harvested, and ingredients reserved for cooking still occupy
storage until served. Invalid totals or malformed reservation IDs reject a save
atomically. Runtime snapshots retain reservations; ordinary loading clears plans
without consuming their ingredients.

Pantry stock belongs to the family, outside reversible construction fields.
Existing room-copy rules create empty beds and tables. Host autosaves and normal
snapshots retain the authoritative stock; clients never submit a stock amount.
Caretakers and autonomy do not harvest or prepare food, and neither stored
produce nor leftovers spoil while the household is absent.


## Detailed household edits

Construction uses protocol 4 and world schema 3. Explicit schema-1/2 migrations
retain old ground-floor homes and add empty upper-storey storage. A lot holds one
budget and revision; `level` selects a validated layer for build commands. Floors,
stairs, terrain, pools and resident displacement are host transactions included
in draft rollback and undo/redo. The renderer only projects the selected floor.
Terrain strokes encode each bounded tile as two hexadecimal digits so even a
256-point stroke fits the unchanged 1,024-byte command packet limit. Clients
must match protocol 4; no older reader is allowed to discard the extra floors.

Creator profiles use an atomic `household_edit` with an exact identity revision,
up to eight members, and bounded family links. The schema-1 migration preserves
legacy residents before adopting the creator schema; subsequent storey migration
is separate. Profiles validate every enum, numeric range, outfit, trait, interest
and relationship before applying any name, membership or appearance change.
New members receive deterministic household-scoped IDs and host-created needs,
positions, wishes and hobbies. Renderers and voice previews cannot write state.

Large creator requests use `household_part`, introduced in protocol 3 and retained
by protocol 4's construction expansion. The ordinary 1,024-byte packet limit is
unchanged: each part carries at most 540 compressed bytes (720 base64 characters).
One assembly per authenticated peer allows at most 61 parts, 32 KiB compressed
and 48 KiB expanded, with a ten-second expiry and exact size/SHA-256 checks.
Only a complete `household_edit` enters ordinary command validation and replay
protection. Partial, expired, foreign-peer or malformed transfers never edit the
world. Retries resend the same parts/request ID; the normal acknowledgement names
the original intent, and the UI waits for the matching authoritative profile.
