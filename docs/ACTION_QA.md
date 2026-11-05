# Action feedback review — issue #3

[QA batch 03/12](https://github.com/maccam912/simulateds/issues/3), implemented
against main after the issue #2 HUD changes, November 5, 2026.

| Finding | Disposition | Implementation and evidence |
| --- | --- | --- |
| ACTION-01 | Implemented | One to three choices use a 252px list beside the target, with 56px actions and a 44px Cancel. Four or more retain the ring and existing pagination. Text labels remain visible. Context-menu tests cover all four corners, pages, keyboard, dismissal and synthetic held touch. |
| ACTION-02 | Implemented; optional inspect-first mode deferred | World hover says click/tap starts an activity or adds to the actor's plan, versus inspect choices with no order. Busy furnishings say add to plan. Menu focus/touch hints distinguish Order from Inspect; arrangement explicitly names build mode. Details, outside clicks and Escape remain read-only. Existing quick-click behavior is preserved rather than adding another interaction preference. |
| ACTION-03 | Implemented; retain Plan cancellation | Host-generated single-order replies name the actor/activity and say Starting or Queued based on the accepted action ID. Care and join-game/dance preserve that reply. Immediate start failures retain their reason. Existing batch-specific replies remain. Every order points to Plan; cancellation still targets an accepted ID, so no new last-order shortcut can accidentally clear later work. Plan, care, context and activity tests exercise accepted/rejected state. |
| ACTION-04 | Implemented | The ordinary strip exposes approximate remaining game minutes and a thin progress track from the same ActivityStatus sample used by Plan. Walking/waiting/idle remain plain text. No local timer or new authoritative state. Activity-status tests cover progress, paused snapshots, selection, waiting and cancellation. |
| ACTION-05 | Reviewed; deferred | Keep manual solo pause and the persistent clock controls. Automatic pause-on-choice would require a single ownership model for nested trays, console, menus and multiplayer transitions; adding another independent pause flag is not justified by this preference. Trays retain the current default and never change shared pace. No new setting is claimed. |
| ACTION-06 | Implemented | Painting buttons capture the exact context at button-down and validate it on activation. Canvas revision/phase, resident, target, session and world replacement invalidate a held press. Buttons retain their action identity; a disappearing focused action falls back to the hobby link. Tests hold a real pointer across completion and Space across generation replacement, then verify no sale/order, with stable navigation focus. |
| ACTION-07 | Reviewed; deferred | Retain existing saved Little Moments, Plan → Recent, hobby progress and People history, plus current quiet notices. A combined feed needs an explicit event-retention schema; current activity history is bounded and does not cover all four proposed milestone types. No new feed, reward duplication or replay-on-load behavior is introduced. |

## Validation

Focused model/UI suites and native reviews are recorded in HANDOFF.md. Local
screenshots and runtime logs are ignored build artifacts, not required to
reproduce the changes. Test scripts construct isolated neighborhoods with explicit
save/profile/settings paths; the aggregate runner now also isolates per-suite
settings instead of resetting a player's display/audio preferences.

Native checks use the actual Godot macOS game camera at 1440×900 and 1280×720
with 125% UI, including day/night menus, short and paged choices, painting
transitions and the HUD alongside Plan. Synthetic touch checks do not establish
physical Android behavior. Hosted CI, exports, physical devices, other operating
systems and human playtests must be reported separately from local checks.
