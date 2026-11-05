# HUD navigation review — issue #2

Dispositions for [QA batch 02/12](https://github.com/maccam912/simulateds/issues/2).

| Finding | Disposition | Implementation / evidence |
| --- | --- | --- |
| HUD-01 | Implemented | Default labels in main/pause menus, More, Needs/Plan and the dock; Display offers compact icons. Accessible names and keyboard operation remain. |
| HUD-02 | Implemented | Roster grows through four full 44px rows. Eight residents have count, Scroll cue and scrollbar; ID-bound selection and in-place status updates preserve focus. Regression covers 2/3/4/8 residents, long names, scroll and reorder. |
| HUD-03 | Partly adopted; portraits and activity icons deferred | Text identifies urgent need or current activity; full name and both states appear on hover. Existing 2D portraits describe legacy appearance fields, not current sculpted faces, ten hairstyles and seven wardrobes. Reusing them would misrepresent residents. Accurate portraits and activity-specific icons need a separate art review; this change does not introduce misleading stand-ins. |
| HUD-04 | Implemented | Missing autosave offers Play starter household and Customize household. Entering returns to Continue; loaded/corrupt saves do not count as fresh. Editing/cancelling uses the existing household flow without replacing the world. |
| HUD-05 | Implemented | Edit household matches menu, More, guide and editor title. Guide includes actual icon examples, Needs → care review → activity, Plan, and distinct visit/group/home routes. |
| HUD-06 | Implemented | Needs expands above an anchored row. Plan retains its exact pointer rectangle; keyboard focus stays on Needs. Plan closes expanded needs, and care/Plan do not stack. |
| HUD-07 | Implemented | Labeled need meters, pointing cursor, initial instruction and actor/activity tooltip open read-only Care. Only an explicit named activity queues care; actor remains in the fixed footer. Existing host replies report results. |
| HUD-08 | Adopted | More sits above its trigger with the acting resident in its heading. Command feedback avoids roster and open trays. No permanent extra panel. |
| HUD-09 | Implemented | Persistent Solo · Paused / 1× / 2× / 4× and Shared time; construction adds Lot sheltered independently. Shared controls remain disabled. |
| HUD-10 | Adopted | Garden, painting, meals, wishes, hobbies, care, people, travel and art commission trays reuse subject-specific existing icons. Titles remain readable and icon accessibility names describe the subject. |

## Validation

`tests/hud_discovery.gd` exercises real mouse/keyboard input, unchanged command
and snapshot state during inspection, one explicit care command, roster identity,
labels and compact icons, menu entry, all clock states and native capture. It is
registered in `tools/check.py`. Existing UI count assertions now accept visible
labels alongside their badges; care render checks require explicit care selection.
Native captures remain ignored under `build/hud-*.png`, with isolated profiles,
saves and settings. They are local evidence, not files required by a fresh clone.

Final check results are recorded in `HANDOFF.md`. No exports or physical-device
playtest are part of this checkpoint. Scripted native review is not a human
first-time-player study, a screen-reader audit, or a physical touch-device test.
