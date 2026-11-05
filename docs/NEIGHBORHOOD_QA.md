# Neighborhood context review — November 5, 2026

Disposition of [QA issue #11](https://github.com/maccam912/simulateds/issues/11).

| Finding | Disposition | Result |
| --- | --- | --- |
| NEIGHBOR-01 | Deferred | Optional solo NPC households need a separate design for NPC ownership, reserved player capacity, persistence, and the transition from solo to shared play. This patch keeps all three vacant lots available for players. It does not promise populated solo neighbors. |
| NEIGHBOR-02 | Implemented | Vacant furnishing orders, contextual choices, ground previews, Visit and Travel together explain vacancy and point to Neighborhood or Find resident. Shared read-only availability preserves construction, ownership, baby and arrival-space restrictions. Single visits now reject blocked arrivals before clearing plans, matching group travel. Caretaker homes remain visitable. |
| NEIGHBOR-03 | Implemented | When the selected resident is elsewhere, the ordinary HUD says who is at which home, retains their activity/timing, and offers a labeled Find resident button. Pointer and keyboard activation recover their current lot/floor through the existing camera action, without changing positions or plans. Full saved names remain available on hover. |
| NEIGHBOR-04 | Deferred | Distinct starter floor plans, palettes and landmarks remain a content pass. Review proposed homes for entrance/furnishing access and domestic character in day/night and compact views, and version fresh-world generation without replacing existing saved homes. No new layouts or assets are introduced here. |

The two content proposals are explicitly deferred rather than implemented as an
implicit change to the four-player-lot ownership model. The Guide now explains
vacancy and the difference between viewing and visiting.

## Validation

- `tests/neighborhood.gd`: fresh solo vacancy across command and preview paths,
  read-only state, occupied/owner-away homes, construction, ownership and blocked
  arrivals. Existing household travel suites cover subsets, already-present
  residents, changed plans, stale reviews, capacity and unchanged companions.
- `tests/neighborhood_context_ui.gd`: real pointer and keyboard navigation,
  agreement between Visit and Travel together, both residents' plan/position
  invariance, visiting-resident recovery, and long saved names. Registered in
  `tools/check.py`.
- Native macOS Godot 4.7.2/OpenGL captures reviewed at 1440×900 and 1280×720
  with the UI setting at 125%, daylight/night. Local ignored evidence:
  `build/neighbor-context-*.png`, `build/issue11/native.log`, and
  `build/issue11/compact.log`.
- Aggregate regression and hosted CI results are recorded in `HANDOFF.md` and
  the pull request. Automated Iroh peers are distinct from a human second-player
  session. No local exports, physical-device play, or human playtest is claimed.
