# Development roadmap

These are increments with testable exits, not a promise that every feature is
already present. Keep the foundational boundary: host-owned simulation, commands
from clients, presentation derived from accepted state.

## Foundation — this slice

- Original isometric neighborhood presentation with four small lots.
- Separate player-owned households and construction rights.
- Starter homes, floors, walls, doors, furnishing, costs, and erasing.
- Resident selection, walking, object interactions, needs, and autonomy.
- Lot-local construction shelter and safe visitor ejection.
- Persistent host world and reconnectable local player credentials.
- Iroh hosting/joining, room codes/tickets, and bounded state replication.
- Gentle absent-family behavior while the host keeps running.

Exit: a host and two clients can keep separate families, edit only their own lots,
visit an open neighbor, survive that neighbor entering construction, disconnect,
reconnect to the same family, and reload a valid saved world. Record separately
which of these were verified by model tests, live processes, or human play.

Recent implemented increments include editable resident plans and autonomy,
exclusive private furnishings, shape-based picking, free furniture moves,
placement validation previews, 32-edit construction undo/redo, and persistent
personal wishes/journals, resident movement/activity presentation, day/night
lighting, and two-corner room construction with a shared cost/obstruction preview.
See [the playtest log](PLAYTEST_LOG.md) for evidence
and current usability priorities.

## 1. Make homebuilding dependable

- Edge-based walls, room detection, window and door orientation, and roofs.
- Drag painting and richer selection; placement previews, furniture moves,
  two-corner rooms, undo/redo, and exact undo refunds are implemented.
- Room blueprints and reusable layouts on the existing draft/commit boundary.
- Stronger routing checks and helpful "cannot reach this" presentation.
- Camera pan/zoom/rotation and a clear cutaway-wall policy.

Exit: construct a small home from an empty lot; every essential object is usable;
undo a room edit without losing money or objects; an inaccessible object gives an
understandable result. Fuzz placement and reopening around residents/visitors.

## 2. Make families expressive

- Household creation, names and appearance, traits, and preferences.
- Visible action queues, interruption rules, autonomy controls, and thought icons.
- Object reservations, shared activities, conversations, and basic relationships.
- Sound and animation for each important action; original art pass.

Exit: two residents can use a busy home without occupying the same object;
player-directed actions beat autonomy predictably; a visitor and resident can
complete a shared activity without either player controlling the other's family.

## 3. Make asynchronous life rewarding

- Player-selected caretaker schedules and a bounded activity journal.
- Simple employment/activity income, bills, and affordable upgrades.
- Host-approved invitations and household guest/privacy settings.
- Profile backup/recovery and world administration.
- Optional durable messages or gifts that do not require both people online.

Exit: a household can remain absent for several real days without irreversible
harm; returning players get a concise accurate summary; no absent family earns
unbounded resources; a lost client connection cannot lock construction or repeat
a purchase.

## 4. Establish release reliability

- Save migration fixtures and recovery UX, long-run saves, and interruption tests.
- Reconnect during joins/edits, slow snapshots, loss, latency, and queue pressure.
- Cross-platform CI artifacts and real exported desktop/Android sessions.
- Mobile touch layout, suspend/resume, thermal/frame-time and memory checks.
- Host administration, backup/restore guide, telemetry opt-in if ever needed.

Exit: independently verified Windows/Linux/macOS builds and physical Android
cross-play; documented performance budget; overnight host soak; validated recovery
from a corrupt primary save; no inherited template results counted as game tests.

## 5. Expand only after the loop holds up

Candidate additions: skills and hobbies, aspirations, jobs with choices, community
lots, weather/seasons, pets, ages and family growth, neighborhood events, and
content packs. Decide each feature's multiplayer ownership, absent-player
behavior, save migration, and authority checks before implementing its UI.

Mod support should start with validated data definitions. Executable scripting,
content distribution, permissions, and trust are separate projects. Larger worlds
need measured replication interest and simulation budgets before raising caps.
