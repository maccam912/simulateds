# Television viewing — issue #4 / POSE-01

New TV orders choose a reachable place on the screen's front side. The host
prefers a nearby sofa, armchair, loveseat, family sofa, spindle chair or garden
bench facing the screen, with a clear tile sight line. An active task reserves
the whole furnishing and one front approach cell while walking and watching.
Ordinary use waits for that TV reservation; another viewer chooses another seat
or a distinct standing place. The activity strip names Seated or Standing.
If no clear place exists, the command explains the problem without changing plans.

The resident walks to the accepted approach cell. After arrival, presentation
places the body on the existing cushion/slats with bent knees and relaxed arms.
Body scale stays unchanged; children can dangle their feet. Standing viewers
face the TV. Picking and resident labels follow the visible body. No new models,
binary assets, external sources or draw groups were added.

Cancellation, completion, travel, disconnect and construction release reservations
through ordinary task lifecycle. A moved/removed furnishing invalidates the place;
rendering cannot move authoritative residents or edit paths, timing, needs or rewards.
Save/snapshot fields are optional and validated. Solo reload revalidates routes and
reservations; stale saved places stop with a load explanation. Legacy TV tasks
without viewing metadata retain their old route until completion or cancellation.
New starter televisions face their sofas. The issue #33 repair below also fixes
untouched original starter homes on disk load; edited layouts are not rotated.

## Deliberate limits

- One TV viewer reserves the whole seating furnishing, including a wide sofa.
  Independent cushion capacity and shared-TV social rewards are separate work.
- Sight checks conservatively use blocked tiles, including other furnishings;
  they do not infer visibility through low furniture from mesh geometry.
- Sit/stand choreography, head tracking, garment draping and general crowd/label
  polish remain outside POSE-01. Reduced motion uses the same steady TV pose.
- Keep issue #4 open for its remaining findings. This implements POSE-01 only.

## Reproduction and evidence

Use a new starter household, turn off autonomy and order Watch television for
Alex. The sofa is used; order Robin to use that sofa and observe waiting. Cancel
Alex's order to release it. Alternatively, order both residents to watch: the
second gets an available standing place. Rotate the TV away from all clear
front tiles to see rejection. Edited old saves may need a deliberate TV rotation
in construction to face their seating; the rejection now explains this.

`tests/television.gd` covers host selection, occupied/absent/backward/blocked seats,
all rotations, late viewers, completion/cancellation, construction/disconnect,
visitor ownership, forged client fields, upstairs places, JSON snapshots, malformed
reservations and solo continuation. `tests/television_pose.gd` exercises six seating
models through four rotations with adult, child, elder and tall/full profiles,
native mesh picking, stationary reduced motion, stale targets and state immutability.

Native macOS Godot 4.7.2/OpenGL review uses the actual camera: furnished starter
day/night, 1440×900 and 1280×720 at 125% UI, and closer rotation views. Screenshots
and logs are ignored local evidence under `build/tv-*.png` and `build/issue4-tv/`;
they are not available from a fresh clone. Regenerate with:

```sh
python3 tools/godot.py --script res://tests/television_pose.gd -- \
  --save-path=build/issue4-tv/review-save.json \
  --profile-path=build/issue4-tv/review-profile.json \
  --settings-path=build/issue4-tv/review-settings.json
python3 tools/check.py
```

All 131 gameplay/UI suites and both save-continuity processes passed across
`tools/check.py` and resumed checks. Two legacy review/estimate fixtures assumed
TV use started at an arbitrary adjacent cell; they now use the accepted viewing
place or wait for arrival. Final native TV and existing activity reviews pass.
All eight real Iroh scenarios and dedicated-server smoke passed as well.
Staged asset storage and whitespace checks pass. The local coverage audit is
`build/issue4-tv/validation.json` (ignored).

Hosted CI is separate from local checks. No exports, physical-device play or
human hardware playtest were performed for this change.

## Legacy starter repair — issue #33

The original starter TV at (4,10) used rotation 0, facing the south wall at y=11.
Front-side viewing correctly rejected that layout after seating was introduced.
New neighborhoods already use rotation 2; the missing path was loading old homes.

After disk validation and numeric normalization, the host repairs only a lot
with revision 0, no construction in progress or upper floors, the original ten
furnishings at their original positions/rotations, and the original floors,
walls and entrance. Only the TV rotation and lot revision change. This includes
vacant starter homes in old neighborhoods, without adding a lamp or replacing
objects, changing funds, or resetting residents and plans. Earlier schema
migrations reach the same repair. No schema/protocol fields were added.

Any construction history, moved/removed furnishing, changed architecture or
newer starter layout prevents repair. Network snapshot restoration never
repairs content on a client. The caller's input remains unchanged, invalid
saves reject atomically, and a second load makes no additional layout change.
For edited homes, use Build → Move to turn the TV toward clear room space.

`tests/starter_television.gd` reproduces the rejection before disk loading,
then verifies two viewers actually reach distinct places and gain fun, repeated
save/load and replication, all four lots, schemas 1/2/3, the preservation guards,
new starters and corruption rejection. It is included in `tools/check.py`.
Run the existing native review with `--legacy-starter` after `--` to load the old
fixture before ordering viewers; its normal/compact day/night captures use
`build/tv-legacy-*.png`. Use isolated save/profile/settings paths as above.

The issue #33 full local aggregate exited 0: 141 gameplay/UI suites, both
save-continuity processes, eight real Iroh scenarios and dedicated-server smoke.
The final preservation guards also pass the focused regression. Native macOS
Godot 4.7.2/OpenGL restored-home review passed at 1440×900 and 1280×720/125% UI,
daylight/night. Logs and coverage audit: ignored `build/issue33/`. Asset-storage
and whitespace checks pass. Hosted CI is separate; no exports, physical-device
play or human hardware playtest were performed for this repair.
