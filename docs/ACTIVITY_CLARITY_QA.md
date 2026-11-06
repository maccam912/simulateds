# Activity clarity — issue #10

Wishes now preview the concrete activity, furnishing or conversation partner,
selected resident, free queue commitment and maximum activity time in game
minutes. Travel and waiting are additional. The host and card share target
selection; the card submits its reviewed target and the host rejects a changed
suggestion. Meal wishes retain their navigation flow and explicitly say whether
they open Build or inspect a table without ordering or spending.

Garden beds show remaining **game time**, derived from crop growth, with either
enough water, a continued-watering condition, or an explicit dry-growth stop.
Local pause and construction are marked. Changing play speed does not change
the remaining game-time estimate; no wall-clock deadline or unattended growth
is promised. Existing safe dry/ripe waits and harvest choices remain.

Meal panels distinguish available, reserved and taken portions. Taken includes
diners still eating and people who have left; it does not claim that all four
finished their food. A scrollable roster names accepted diners, queued/walking/
waiting/eating status, reservation versus taken portion, and automatic orders.
It derives from the current table batch and recipe and disappears on cancellation
or stale plans. It does not reserve seats or consume portions.

Commissions name the easel, wall or collection instead of putting tile coordinates
in the primary copy. Coordinates remain in optional hover details. Find original
centers the camera without selecting/moving a resident or delivering anything;
the original's identity is checked again before finding it. Current commission
sources remain the ground-floor home easels, walls and household collection;
this does not add upstairs commission custody. Delivery keeps its exact-original
review, permanent-removal warning and one-time payment. A short recipient note
and the saved artist credit appear after delivery, derived from that receipt's
offer rather than tomorrow's request.

## Finding dispositions

| Finding | Disposition |
| --- | --- |
| HOBBY-01 | Implemented: visible activity/target, actor, commitment, game-time bound and navigation-only copy; changed suggestions reject. |
| HOBBY-02 | Deferred: retain existing personal titles, completion notice and Little moments journal. More resident reactions need authored content and playtesting; cash/set rewards and no-expiry rules stay intact. |
| HOBBY-03 | Implemented: conditional game-time readiness and explicit dry/paused state. |
| HOBBY-04 | Deferred: keep individual bed choices and the existing garden overview. A multi-bed plan needs a reviewed price/route design; no implicit selling or crop spending. |
| HOBBY-05 | Implemented: portion accounting plus named accepted participant status, including autonomy, queued work and cancellation. |
| HOBBY-06 | Deferred: existing dining props remain. Carrying/setting transitions need separate animation contact work; this change does not alter serving timing or portions. |
| HOBBY-07 | Implemented: easel, commission, hobby, guide and routine copy no longer assumes two household members. Painting copy explicitly requires a household member old enough to paint. Pairwise friendship/meal rules still correctly refer to two participants. |
| HOBBY-08 | Implemented: furnishing/collection location, optional coordinate detail, and read-only Find for placed originals. |
| HOBBY-09 | Deferred: artist/stage visual variants require original art and an identity-preserving preview design. Existing subjects and contributor credits remain. |
| HOBBY-10 | Implemented: modest recipient-specific note paired with the delivered original's saved artist credit. No new modal, fee or deadline. |

The four deferred preferences are explicit design dispositions, not implemented
features or claims of subjective playtest acceptance.

## Reproduction and validation

1. Open Wishes for an adult with television, chat and reading wishes. Inspect
   the full cards before clicking; scroll at compact sizes. Complete one and
   verify the reward occurs only on completion. Remove a suggested furnishing
   before submitting its old target and verify rejection without changing plans.
2. Plant tomatoes. Observe the conditional nine-game-hour estimate, let water
   run out, pause/resume and change speed. Water, ripen and keep the crop. Repeat
   with radishes, then prepare a homegrown bowl from the pantry.
3. Call three residents with different arrival times. Inspect available/reserved/
   taken counts and the named roster. Cancel a walking diner and see their
   reservation return. Observe automatic diners and the final taken portions.
4. Accept a commission, paint with multiple contributors, inspect the original
   on an easel/wall/in collection, and use Find without changing plans. Deliver
   once; check the recipient note, attribution, permanent removal and payment.
5. Repeat at 1440×900 and 1280×720 with 125% UI, in daylight and at night. Scroll
   long wish cards and diner lists; keep footer navigation reachable.

Focused authority coverage is in `tests/wishes.gd`, `tests/gardens.gd`,
`tests/meal_call.gd` and `tests/art_commissions.gd`. The new
`tests/activity_clarity_ui.gd` covers read-only previews, actor/target text,
paused/dry estimates, pace-independent game time and three staggered diners.
`tests/art_commissions_ui.gd` checks Find, optional coordinates, receipt notes,
stale originals and duplicate-payment rejection. Existing pantry, meal-wish,
painting, gift, wall-art and commission suites retain the broader lifecycle
coverage. Run through `python3 tools/check.py` with its isolated paths.

Native review runners also accept `--compact`; use isolated save/profile/settings
paths under ignored `build/issue10/`. Captures stay under ignored
`build/activity-clarity-*.png`, `build/commissions-*.png`, `build/pantry-*.png`
and `build/meal-wishes-*.png`. Local validation outcomes are recorded in
`HANDOFF.md`; hosted CI, exports and physical-device play are separate results.
