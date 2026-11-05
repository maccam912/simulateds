# Storey access and navigation — issue #7

All four findings in [QA batch 07](https://github.com/maccam912/simulateds/issues/7)
are adopted. The optional onboarding direction is a checklist in the existing
Guide, rather than a new house purchase or tutorial state machine.

| Finding | Disposition | Evidence |
| --- | --- | --- |
| FLOOR-01 | Implemented. Empty upper levels are unbuilt, not broken entrances. Access and Finish use the same whole-home report. Missing connections, stair openings and both landings have floor-specific targets. Find switches floors; overlay badges remain on their actual floor. | `storey_access`, `storey_access_ui`, existing `build_access` and `build_access_ui` |
| FLOOR-02 | Implemented. Accepted Finish and Discard return to the selected resident's floor, reframing when changing floors or lots. The location heading retains the viewed floor even with trays closed. Find resident remains available. | `storey_access_ui`, existing camera and save-continuity tests |
| FLOOR-03 | Implemented. View −/+ is one labeled row; live resident travel has its own named group with explicit Go downstairs/upstairs buttons. Availability uses the same read-only stair option as the host command. | Actual pointer input and unchanged-world assertions in `storey_access_ui`; explicit stair orders, persistence and peer coverage |
| FLOOR-04 | Adopted and implemented as Guide → Building → Your first upstairs. Covers flooring beneath furnishings, rotation, both landings, automatic openings, access repair, Undo/Discard and explicit stair travel. It accurately states that this prototype does not require lower supporting walls. Reading has no command or purchase. | Guide read-only assertions in `storey_access_ui`, existing `guide_ui` |

The authoritative construction policy stays forgiving: edits and Finish move
stranded residents to safe street-side space. Access checks the house layout
without making sheltered residents veto a valid home. A direct per-floor resident
diagnostic remains available and covered, including a trapped upstairs resident.
Connectivity follows stairs in both directions, including homes where an upper
corridor reconnects two downstairs regions. No saved UI fields or protocol change.

## Validation

Local regression and native review results are recorded in `HANDOFF.md`. Review
artifacts under `build/issue7/` and `build/storey-*.png` are ignored local outputs;
a fresh clone can reproduce them with `tests/storey_access_ui.gd`, using isolated
`--save-path`, `--profile-path`, and `--settings-path` arguments and `--compact`
for 1280×720 / 125% UI. Hosted CI, exports, physical devices, and human playtests
are separate evidence categories.
