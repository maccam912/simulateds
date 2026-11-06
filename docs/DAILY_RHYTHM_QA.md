# Daily rhythm review — issue #9

Review date: November 5, 2026. This batch adopts optional, time-aware discovery
of existing household routines and visible descriptions of existing preferences.
The full-day observations below support keeping the forgiving simulation intact.

| Finding | Disposition |
| --- | --- |
| LIFE-01 | Adopted an optional idea inside Plan. It opens a saved routine for review; only the existing Add to plan command orders activities. No popup, recurring prompt, automatic purchase or reward is added. Resident-led social invitations are deferred until companion consent, availability and interruption have their own design. |
| LIFE-02 | Adopted time-of-day suggestions for existing routine presets and edited recipes. Morning favors care, daytime can offer a saved favorite-pastime recipe, and evening/night can offer a recipe ending in sleep. Choose or ignore these at any time. Automatic schedules and circadian weighting are deferred: the audit confirms substantial idle time and short need-driven naps, so a clock bias alone would not create believable overnight sleep. Need decay, urgency, restoration and deliberate-order priority remain unchanged. |
| LIFE-03 | Deferred optional budget scenarios and larger purchases to a separate economy comparison. The audit retains the §600 allowance; autonomous households earned no extra money. The selected routine earned existing deliberate wish rewards. No new upkeep, spending pressure or absence penalty is introduced. |
| LIFE-04 | Plan now names the favorite, matching traits and applicable likes/dislikes alongside accepted automatic activities. This exposes existing differences without claiming a trait caused an urgent choice. Family-specific greetings, topics and interactions are deferred; chosen family ties remain separate from earned friendship. |
| LIFE-05 | Deferred a combined daily recap. The bounded journal, activity outcomes and relationship records do not retain every proposed home change or time together. A recap needs an explicit event-retention/attribution design before it can promise a complete saved day. Existing history remains; this pass creates no new history or rewards. |

## Measured full-day behavior

`tests/daily_rhythm_audit.gd` observes twelve isolated 24-hour simulations, from
Day 1 at 08:00 to Day 2 at 08:00, with fixed 0.1-second steps. It covers 2, 3
and 8 residents, each with autonomy on, autonomy off, one explicitly chosen
Wind down routine at 20:00, and an absent household. Residents alternate reading/
Bookworm, tea/Outgoing and television/Homebody preferences. The starter home and
its two beds are retained; added residents use ordinary creator starting needs.

These are automated simulation observations, not a human full-day playtest or
a balance study. Idle means no active task; minutes below are per resident.
Activity starts include travel to the furnishing, not just time performing it.

| Residents | Autonomous starts, whole household | Mean idle minutes | Lowest need | Bed starts / fridge starts |
| --- | ---: | ---: | ---: | ---: |
| 2 | 38 | 1208.1 | 66.9 | 4 / 6 |
| 3 | 53 | 1224.6 | 66.9 | 6 / 9 |
| 8 | 125 | 1252.5 | 66.9 | 16 / 24 |

The two starter residents slept around 09:48/09:54 and 23:36/23:42; larger
households also had daytime bed starts around 12:24–13:18. Choosing Wind down
moved Alex's later bed start to about 20:30 in every household size, using the
ordinary tea → book → bed sequence. It did not add a recurring bedtime. Mean
idle time with that one routine was 1199.2, 1217.3 and 1251.1 minutes respectively.

With autonomy off and no orders, all three households remained idle for the full
day and needs could reach zero, as before. Absent households stayed above 65.9
in these fixtures; their existing 55-point caretaker floor remains unchanged.
All non-routine runs ended at §12,600; the chosen-routine runs at §12,680 through
existing wish rewards. Reading and tea preferences already produced different
leisure choices. No decay/reward/authority code was changed in this pass.

The runner writes complete activity-start timelines only when passed `--report`.
The clean final report matched the initial measurement exactly. The initial
sandboxed run logged a macOS certificate-service error; it is superseded by the
clean unrestricted-runtime observation, not counted as a passing engine check.

## Interaction contract and reproduction

- Suggestions inspect the actual saved steps, independent of editable names and
  IDs. They never create a new recipe or recreate a deleted one. Babies and
  periods without a matching saved recipe receive no suggestion.
- Review opens the correct card, including an unavailable card's reason.
  Add to plan retains the existing ownership, current-lot reachability, capacity,
  revision and duplicate-plan checks. Current private drafts and pending commands
  are preserved. Autonomy off still permits deliberate routine choices.
- Changing the clock or snapshot refreshes advice without mutating the world.
  Recent outcomes remain free of suggestions and automatic activity entries.
  A suggestion disappearing while focused returns keyboard focus to Routines.
- Preference copy names saved affinities, including dislikes; it does not infer
  why a past decision won. Full text remains in tooltips when rows truncate.
  It adds no simulation effect or family relationship behavior.

Run with isolated save, profile and settings paths, as in `tools/check.py`:

```sh
mkdir -p build/issue9
python3 tools/godot.py --headless --script res://tests/daily_rhythm_audit.gd \
  --log-file build/issue9/audit-engine.log -- \
  --report=res://build/issue9/audit.json \
  --save-path=build/issue9/audit-save.json \
  --profile-path=build/issue9/audit-profile.json \
  --settings-path=build/issue9/audit-settings.json
python3 tools/godot.py --script res://tests/daily_rhythm_ui.gd \
  --log-file build/issue9/native-engine.log -- \
  --save-path=build/issue9/native-save.json \
  --profile-path=build/issue9/native-profile.json \
  --settings-path=build/issue9/native-settings.json
```

Add `--compact` after `--` for 1280×720 with the UI setting at 125%; the default
native review is 1440×900. Use separate paths for simultaneous runs. The new UI
suite is registered in `tools/check.py`; the longer observational audit is an
explicit review runner. Existing pastimes, care, routines, creator, meals,
save-continuity and Iroh checks cover the unchanged simulation contracts.

Native macOS Godot 4.7.2/OpenGL Compatibility review passed in the actual camera,
daylight/night and normal/compact sizes. Plan, focused routine review, unavailable
bedtime review, preference text and Recent were inspected. Logs and captures are
ignored local artifacts under `build/issue9/`, not downloadable from a fresh clone.
No model or binary assets changed. Exports, physical-device testing and human
family playtests were not performed; hosted CI is separate.

The required `python3 tools/check.py` exited 0: all 136 gameplay/UI suites,
both save-continuity processes, eight real Iroh peer scenarios and dedicated-server
smoke passed without script/engine errors. Final focused headless and compact
native runs cover the subsequent helper cleanup. Staged asset storage passes
(81 hydrated LFS assets), as does whitespace validation. Local evidence:
`build/issue9/check.log`, `validation.json`, `ui-final.log`, `native-final.log`.
