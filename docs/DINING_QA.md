# Shared dining — issue #4, POSE-03

This change addresses the standing, bare-table meal in
[issue #4](https://github.com/maccam912/simulateds/issues/4). Keep the issue open:
TV seating, shower entry/exit, wider child contact, transitions, bedding,
crowded labels and emotion are separate findings.

## Implemented behavior

An arrived eater with a consumed portion sits on an authored oak stool, facing
the edge belonging to their accepted dining cell. Each cell keeps its lateral
lane, so even two diners on one side retain separate places. A plate carries
the current salad, sandwich or homegrown recipe. The right hand makes a small
plate-level gesture; pause freezes it and reduced motion holds it steady.

Seat height follows existing body proportions. Children have supported feet on
a footrest. Two articulated knees preserve the model's standing shape and keep
seated lower legs pointing down. The renderer resets them outside dining; the
existing bed/sofa poses are otherwise unchanged. Label anchors and triangle
picking follow the displayed body.

The props do not reserve another cell, become independent furniture, or add a
cost. Queued/walking diners cannot display consumed food. Active eaters retain
their plates after the shared platter is empty. Cancellation, completion,
construction, a changed meal batch and a missing/nonadjacent table clear the
pose and props. No world, save, command, path, need, portion, practice, friendship
or reservation fields are written by this presentation.

The table's baked decorative plates/napkins/cutlery hide while actual dining
places are shown, then return when dining ends. Solid geometry is generated
from the original editable sources `game/dining_pose.gd` and
`game/character_model.gd`; no binary or external asset is added.

## Scope and limits

POSE-03's authored places, facing, plate contact and separate diners are
implemented. POSE-04 is improved for the reviewed child dining pose only;
easel/other furniture contact remains open. Sit-down/stand-up choreography,
hand-to-mouth animation and garment draping remain future animation work.
The current immediate pose switch preserves immediate authoritative cancellation.
The stools are visual dining props, not a general chair-selection system.

## Reproduction and evidence

`tests/dining_pose.gd` is registered in `tools/check.py`. It prepares real meals
and uses ordinary eat/cancel commands. It checks four body profiles, four table
rotations, adjacent places, plate bounds and hand contact, exposed body picking,
snapshot equality, pause/reduced motion, natural completion and stale cleanup.
The existing meal suites retain the portion, autonomy, chosen-company and
friendship regression coverage.

Run native review with isolated absolute paths (add `--headless` for assertions):

```sh
python3 tools/godot.py --log-file /tmp/simulateds-dining.log \
  --script res://tests/dining_pose.gd -- \
  --save-path=/tmp/simulateds-dining-save.json \
  --profile-path=/tmp/simulateds-dining-profile.json \
  --settings-path=/tmp/simulateds-dining-settings.json
```

Native macOS Godot 4.7.2/OpenGL Compatibility captures use the furnished house
and actual camera at 1440×900 and 1280×720/125% UI, day/night, low/high scenery,
and a closer 1.8× view. Ignored evidence: `build/dining-*.png` and
`build/issue4-dining/native.log`. The existing native activity review also passed
(`build/issue4-dining/activities.log`, `build/activities-*.png`). These are local
artifacts, not assets available in a fresh clone. See `HANDOFF.md` for final
aggregate results. Hosted CI, exports, physical devices and human playtesting
are separate from this local review.
