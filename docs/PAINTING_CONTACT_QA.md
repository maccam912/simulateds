# Painting contact — issue #4 / POSE-04

## Scope and disposition

Implemented the easel portion of POSE-04: arrived painters face the actual canvas,
hold a solid brush against it, and use a solid oak step when needed for height.
The resident's proportions are unchanged. A small game-time stroke moves the arm
and brush while feet and support stay stationary. The existing dining fix covers
table reach; this is not a claim that every furnishing's child contact is done.
Keep issue #4 open for the remaining contact, transition, crowding, sleep and
emotion findings. Step climbing and picking up/putting down the brush are deferred
with POSE-05; cancellation remains immediate.

The old pose was a generic low arm gesture at any adjacent tile, including the
back of the easel. Painting and packing now use the rotated canvas-side cell.
The host computes this route through existing commands. An obstructed front
rejects with a specific explanation; construction diagnosis and catalog copy
identify the same requirement. Existing homes/pictures are not moved or erased:
a backward-facing or blocked easel may need rotation or a clear path to resume.

Older active side-on snapshots remain structurally valid. The host reroutes before
adding work, or ends a blocked plan with the original canvas unchanged. Solo saves
retain their existing painting interruption policy. No new save or protocol fields,
prices, rewards, need rates, deadlines, or automatic painting behavior were added.

Presentation reads only an arrived start/resume task with its matching canvas
revision and front cell. It clears props for cancellation, completion, selling,
construction, a removed/moved target, or a changed revision. Labels and mesh
picking follow the visible body. New props are original runtime geometry in
`game/painting_pose.gd`; no binary assets or external sources were added.

## Reproduction and checks

Use isolated save, profile and settings paths under ignored `build/`. For example:

```sh
mkdir -p build/painting-review
python3 tools/godot.py --script res://tests/painting_pose.gd \
  --log-file build/painting-review/engine.log -- \
  --save-path=build/painting-review/save.json \
  --profile-path=build/painting-review/profile.json \
  --settings-path=build/painting-review/settings.json
python3 tools/check.py
```

`tests/painting_access.gd` covers all four approach rotations, rejected blocked
fronts without state changes, matching construction warnings, blocked arrival,
legacy active snapshot rerouting, cancellation, lot edges and upper-floor support.
The real Iroh painting scenario also checks the replicated canvas-side arrival.
The existing exact-progress fixture now begins at the proper front cell.

`tests/painting_pose.gd` checks actual canvas contact and held-brush attachment,
foot support, stationary feet during strokes, bounded prop draw groups, paused
and reduced-motion poses, cancellation/completion/packing, stale state cleanup,
mesh picking and authoritative snapshot equality across rendering. It covers four
furnishing rotations with child, short adult, tall broad elder and toddler bodies,
plus both height endpoints of every playable age. Babies remain in bassinets.

Native macOS Godot 4.7.2/OpenGL Compatibility review on Apple M5 Pro passed at
1440×900 and 1280×720 with 125% UI, daylight/night and low scenery. Reviewed the
actual house camera and closer framing. Logs are in ignored
`build/issue4-painting/native.log`; captures are `build/painting-day-turn-*.png`,
`painting-close.png`, `painting-night.png`, `painting-compact-night.png` and
`painting-compact-day-low.png` and `painting-furnished-*.png`. These local artifacts are not in a fresh clone;
the runner regenerates them. Rear views correctly occlude parts of the body behind
the canvas, with an exposed body surface still selectable.

All four local `tools/check.py --shard N/4` runs exited 0: 135 gameplay/UI suites,
both save-continuity processes, eight Iroh peer scenarios and server smoke.
The initial run exposed a commission fixture facing into the tea table; it now
faces its clear side. See `HANDOFF.md` and ignored
`build/issue4-painting/validation.json` for the final coverage audit.
Hosted CI belongs to the PR and is separate from local evidence. No exports,
physical-device checks, or human family playtests were performed for this change.
