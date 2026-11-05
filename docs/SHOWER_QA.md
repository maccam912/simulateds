# Shower occupancy — issue #4, POSE-02

This is a focused first change for [issue #4](https://github.com/maccam912/simulateds/issues/4),
not completion of the eight-finding batch.

An accepted, started shower activity now places the visible resident inside the
tray, facing the mixer, with feet on its inset surface. The resident remains
clothed. Opaque panels lower during use using the existing dollhouse cutaway
language, so a child or adult remains visible and pickable from every rotation.
The original solid meshes, colors and tall shower hardware remain; no billboard,
transparent sorting trick, new wardrobe state, or external asset is introduced.

Small solid water drops and a restrained arm gesture follow simulation time.
Pause freezes them; reduced motion uses a steady cue. Cancellation, completion,
construction and removal of the target clear the pose/water and restore the
enclosure. Waiting and walking residents never occupy another resident's shower.
The selected name/need anchor follows the visible occupant.

All of this is presentation. Authoritative approach cells, exclusive reservations,
routes, timing, needs, commands and saves retain their existing behavior. In
particular, the renderer does not route anyone through an occupied footprint.

## Remaining issue scope

POSE-02 remains **partially addressed**: the outside-the-tray defect, facing,
water cue, cutaway visibility and cancellation cleanup are fixed. Entry/exit
still switches directly between the accepted approach cell and the tray, as the
existing bed/sofa presentation does. Convincing choreography needs a separate
review of approach sides and the shower's solid back/side panels; interpolating
through them would create a new visual defect. Do not close the issue from this PR.

POSE-01 and POSE-03–08 (TV seating, dining, broader child contact, transitions,
bedding, crowded silhouettes and emotion) remain open and unchanged.

## Reproduction and evidence

`tests/shower_pose.gd`, included in `tools/check.py`, uses isolated test saves and
real interaction/cancel commands. It checks walking/waiting, four body profiles
through all four rotations, tray height, facing, anchors, snapshot equality,
pause/reduced motion, natural completion, cancellation, construction and missing
targets. The native path additionally checks exposed body mesh picking.

For a native review, substitute absolute scratch paths in this command:

```sh
python3 tools/godot.py --log-file /tmp/simulateds-shower.log \
  --script res://tests/shower_pose.gd -- \
  --save-path=/tmp/simulateds-shower-save.json \
  --profile-path=/tmp/simulateds-shower-profile.json \
  --settings-path=/tmp/simulateds-shower-settings.json
```

Native macOS Godot 4.7.2/OpenGL Compatibility review used the actual game camera
at 1440×900 and 1280×720 with 125% UI, day/night, plus a closer 1.8× camera view.
Captures are ignored `build/shower-*.png`; the native log is
`build/issue4/native-final.log`. The existing `tests/render_activities.gd` review
also passed in the furnished starter house (`build/issue4/activities.log`); its
fixture relocation now clears stale interpolation before paused captures. These
are local evidence, not fresh-clone assets.
The editable water geometry and cutaway transforms live in
`game/lot_scene_3d.gd` and regenerate at runtime; existing GLBs are unchanged.

Hosted CI, exports, other operating systems, physical devices and human playtesting
are separate from these local checks. See `HANDOFF.md` for the final suite result.
