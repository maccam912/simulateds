# Development roadmap

These are increments with testable exits, not a promise that every feature is
already present. Keep the foundational boundary: host-owned simulation, commands
from clients, presentation derived from accepted state.

## Foundation — this slice

- Original isometric neighborhood presentation with four small lots.
- Separate player-owned households and construction rights.
- Starter homes, floors, walls, doors, furnishing, costs, and erasing.
- Resident selection, walking, object interactions, needs, and autonomy.
- Lot-local construction shelter and safe visitor ejection. Explicit entrance-side movement now makes space around
  paused home residents while preserving build selections and Undo/Discard.
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
lighting, two-corner room construction with a shared cost/obstruction preview,
household names/appearance, persistent friendships with a People panel, and
household postcards with optional gifts for asynchronous play. Needs now offer
care shortcuts and a derived mood summary, backed by host-selected activities.
Floor/wall finish palettes now support priced rectangle painting, room-aware
floor filling, preview, and whole-area undo alongside room construction. Reading, gardening, and cooking now
have five persistent ranks, bounded deliberate practice, activity bonuses, and a
Hobbies panel. The build catalog now offers categories, search by name/use,
selected-item details, and compact editing controls. An optional first-day guide
and live controls reference now lead into the existing systems without adding
permanent HUD clutter. Resident favorites now gently influence autonomous leisure
choices, with editable preferences and a visible daily-plan explanation. Mail now
includes durable return recaps of simulated absence, actual allowance, postcards,
and discarded construction drafts. Visible activity now has sparse positional
footsteps and domestic sounds with bounded voices and shared audio settings.
Resident names now stay in front of furniture, with quiet actionable thought
cues for unplanned pressing needs. Resident facing now follows accepted routes,
furnishing rotation, and live conversation partners, with front/side/rear poses
and labels that leave faces clear. Ground hover now explains reachability and
queued walks, and accepted destinations share numbering with the resident plan.
The checkered game table now supports solo puzzles and voluntary shared games
with separate places, fun/social restoration, and a tabletop pastime preference.
People cards discover ongoing games and let a visiting resident join or wait,
preserving their existing planned activities. Reusable household routines now
save one to six care/recreation activities, resolve current reachable furnishings,
and append to either resident’s existing plan. Three window styles now mount to
solid walls, with exact trade-in prices, construction history, and cutaway
presentation. Solo pause and 1×/2×/4× controls now advance needs, movement, and
activities through consistent fixed steps, with rebindable shortcuts and a
shared-clock lock when hosting or visiting a networked neighborhood.
Kitchen garden beds now support two crop choices, visible growth, deliberate
plant/water/harvest plans, visitor watering, gardening practice, and safe waits
when dry or ripe. Crop state follows furnishing moves, history, saves, and
reconnects; it does not create unattended income. Each resident’s Plan now also
retains eight recent deliberate outcomes, including completion, cancellation,
and interruption reasons, with game time and routine provenance. These persist
through saves and reconnects without filling up with autonomous care. Routines can
now start from the selected resident’s current plan, with an editable copy,
explicit omissions, and a review step for plans longer than six activities.
A little hi-fi now offers solo/shared dancing, up to four independently reserved spots,
People discovery/joining, a dancing preference, routine support, expressive poses,
and one original positional music source with background-score ducking. Shared
furnishings now show actual layout capacity, open/reserved/occupied places, and
specific waiting explanations. Completed shared recreation can include one safe,
interruptible courtesy step to let an already-waiting plan take its place.
Deliberate shared games and dancing now build symmetric friendship after 12 game
minutes together, sharing the two-catch-up daily budget with chats. People shows
the last encounter and remaining opportunities; explicit Join can replace an
automatic activity, and old saves retain their real chat history.
See [the playtest log](PLAYTEST_LOG.md) for evidence
and current usability priorities.

Daydream easels now support three deliberately painted subjects, persistent
partial work, shared household credit, staged original artwork, completion
journals, and explicit single-payment sales. Finished art can stay on the easel,
hang on a wall, or wait in the household collection. Free, undoable transfers
release the canvas for another picture; demolition safely stores mounted art.
Room duplication leaves earned artwork in place and creates blank easels.
Painting now has five lasting hobby ranks, bounded daily practice, shared
contribution credit, and better fun/comfort recovery. Hobbies opens the relevant
easel without choosing a subject; rank links show painting progress directly.

Mounted art now supports queued admiration at home and on visits. A Gathering
dining table supports preparation at the fridge, carrying and serving four
portions, distinct dining places, per-resident reservations, guest participation,
shared needs/friendship, saved leftovers, and explicit clearing. Construction and
room copies preserve the distinction between an existing meal and a new table.
Hungry household members now use available prepared food autonomously at home,
with ordinary urgency, reservation, and player-order rules. Guests choose their
own meals; absent caretakers preserve stored portions. Automatic eating cannot
prepare food, spend ingredients, or earn deliberate-play rewards. An ongoing
automatic meal can become chosen shared time from the table or People without
using another serving or restarting its timer. Friendship counts only newly
chosen time together. Later optional wish sets now include serving homemade food
and sharing chosen meal time, using the existing bounded rewards. Wish navigation
finds a relevant table or its Kitchen catalog entry without choosing ingredients
or controlling other diners. Starter sets and existing saved wishes are preserved.

A household meal call now previews and directs eligible residents together,
keeping existing plans, reusing current automatic portions, skipping absent
residents, and reserving food atomically. It works on visits without directing
another player's family.

Households can now travel together through an explicit resident roster. The
preview shows locations and planned counts, cancels only chosen travellers' work,
keeps residents already at the destination untouched, and uses separate entrance
spaces. Changed plans or a closed destination reject the complete group.

Neighborhood cards now show current occupants, owner availability, active guest
players, and construction closure. Full resident/household details and locations
of household members visiting elsewhere appear on hover. Updates retain keyboard
focus, and browsing never moves residents.

## 1. Make homebuilding dependable

- Edge-based walls, room detection, door orientation, and roofs. Wall-mounted
  windows with automatic direction, three styles, and cutaway presentation are
  implemented.
- Drag painting and richer selection; placement previews, furniture moves,
  two-corner rooms, rectangle decoration, room-aware floor fill, undo/redo, and
  exact undo refunds are implemented. Add broader architectural options.
- Room duplication now copies an enclosed design with rotated furnishings,
  finishes, windows, full cost/access preview, and one undoable placement. A bounded
  household library now saves named designs through remodeling, saves and
  reconnects. Reviewed whole-lot clearing now opens space with exact resale,
  original-art protection and one-step undo. Add reviewed cross-household design
  sharing later.
- Furniture material colors now offer six named choices, in-world preview, free
  recoloring, undo/redo, and preservation through moves, copies, and saves.
- Shared entrance routing checks and an access overlay now locate blocked
  furnishings and residents, with camera focus and direct repair tools. Placement,
  movement, and room previews now name access consequences before applying an
  edit, distinguishing new problems, existing problems, and repairs. Extend routing
  as architectural options become richer.
- Camera pan/zoom/rotation and a clear cutaway-wall policy.

Exit: construct a small home from an empty lot; every essential object is usable;
undo a room edit without losing money or objects; an inaccessible object gives an
understandable result. Fuzz placement and reopening around residents/visitors.

## 2. Make families expressive

- Household creation, traits, and preferences. Names and a palette-based
  appearance editor and favorite pastimes are implemented for both residents.
- Visible plans with queued activity reordering, interruption rules, autonomy
  controls, actionable need thoughts, and resident camera focus are implemented.
  Travel/waiting feedback and estimated activity progress are implemented.
- Object reservations, shared activities, conversations, basic relationships,
  voluntary tabletop games, and discovery/joining from People are implemented. Game/music
  inspection now also offers explicit one-resident and household choices, with
  plan preservation and adoption of ongoing automatic play.
  Add richer recreation and shared activities.
- Activity poses, directional facing, thoughtful need cues, and sparse positional
  sounds are implemented, along with movement previews and accepted destination
  feedback. Reusable household routines are implemented. Add richer animation
  and the original art pass.

Exit: two residents can use a busy home without occupying the same object;
player-directed actions beat autonomy predictably; a visitor and resident can
complete a shared activity without either player controlling the other's family.

## 3. Make asynchronous life rewarding

- Accurate return recaps are implemented. Add player-selected caretaker schedules
  and extend the bounded activity journal.
- Simple employment/activity income, bills, and affordable upgrades.
- Host-approved invitations and household guest/privacy settings.
- Profile backup/recovery and world administration.
- Durable household postcards, money gifts, and original painting gifts are
  implemented. A picture can wait for an absent household, retain its creators,
  then become part of the recipient’s home. Extend the asynchronous loop with
  meaningful household activities and return summaries.

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

Candidate additions: deeper hobby choices, aspirations, jobs with choices, community
lots, weather/seasons, pets, ages and family growth, neighborhood events, and
content packs. Decide each feature's multiplayer ownership, absent-player
behavior, save migration, and authority checks before implementing its UI.

Mod support should start with validated data definitions. Executable scripting,
content distribution, permissions, and trust are separate projects. Larger worlds
need measured replication interest and simulation budgets before raising caps.
