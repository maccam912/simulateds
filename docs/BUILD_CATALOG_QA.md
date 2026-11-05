# Construction browsing and feedback (issue #6)

Review date: November 5, 2026. Implements BUILD-01 through BUILD-09. Keep
[issue #6](https://github.com/maccam912/simulateds/issues/6) open for BUILD-10's
physical mouse/trackpad review; automated native gestures are separate evidence.

| Finding | Disposition |
| --- | --- |
| BUILD-01 | After a matching accepted purchase, hide the duplicate ghost and show the item name with “placed.” Pointer movement, another command, rotation, lot/floor/session changes, or a later draft revision ends this local feedback. Preview validity remains false over occupied furniture; repeated clicks still reach host validation and cannot double-charge. |
| BUILD-02 | A wider floating construction tray uses two columns of 60px cards with actual-model miniatures, names and prices. Four complete choices fit at 1280×720 with 125% UI. Move, Sell, Rotate, Move family and Access share one row, leaving Undo/Redo/Discard fixed below. The world retains the full viewport. |
| BUILD-03 | Whole item names and category words rank ahead of incidental description matches. Floor construction and finishes lead floor searches; tables lead table searches. Related-result tooltips identify the matching word, including “table” inside “vegetable.” Search retains its field, caret, category scope and empty-result recovery. |
| BUILD-04 | The selected-item summary states floor coverage, outdoor placement, or stair landing/opening requirements before a purchase attempt. A combined paid floor helper is not adopted: the existing floor tool and exact host price remain explicit separate purchases. |
| BUILD-05 | A persistent brass “Using: item · price” heading stays visible when search/category results change. Browsing never selects a tool or issues an edit. |
| BUILD-06 | Paired ink/cream lot edges and thicker outlined active footprints improve contrast on the reviewed lawn and floor surfaces in day/night. Leaving the lot has an explicit boundary hint; existing host-shared obstruction, funds and access text remains. |
| BUILD-07 | Selected-item text is larger and wraps use, rotated footprint, angle and requirements in the fixed footer. Cards retain visible prices; exact budget shortfalls remain text. |
| BUILD-08 | Adopted an optional Daylight switch in the construction View row. The construction banner explicitly identifies the preview; switching it off restores actual night lighting. It changes only renderer lighting, resets on leaving construction or changing session/lot, and never changes clock, commands, snapshots or saves. |
| BUILD-09 | Host-generated bounded Undo/Redo hints name the accepted transaction and affected furnishings/tiles/finishes/windows/art/ground changes, with the exact next cost/refund. They replicate as optional runtime text, remain compatible with older snapshots, and are omitted from committed saves. Undo/Redo still use the existing revision-checked transaction. |
| BUILD-10 | Outstanding: a human must test physical mouse and trackpad card drag, furniture Move drag, floor rectangle drag, right-drag rotation and creator rotation. No physical-device or human-input claim is made here. Existing click/keyboard paths and automated native gestures remain available. |

## Reproducible review

Use isolated save/profile/settings paths as in `tools/check.py`. Never use the
player's normal profile for these tests.

- `tests/build_feedback_ui.gd`: actual pointer purchases of table/easel/garden
  bed; stationary success; duplicate rejection; repeat valid destinations; Undo;
  stale/delayed acknowledgements; world/rotation/revision invalidation; search
  ranking; four complete compact cards; selected-item requirements; unchanged
  authoritative snapshots during night/daylight comparison.
- `tests/catalog_ui.gd`: keyboard search and selection, scope/empty recovery,
  actual purchases, budget feedback, Undo/Redo and finish palette. “Plant” now
  selects the plant explicitly; the broad “garden” query correctly ranks names
  containing Garden ahead of incidental garden keywords.
- `tests/build_history.gd`: transaction hints, exact money after sale/midnight,
  compound area/finish counts, malformed/oversized hint rejection, older
  snapshot compatibility, and omission from disk saves.
- `tests/build_overhaul_peer.gd`: two actual Iroh clients receive upstairs lamp
  Undo/Redo descriptions and exact refunds/costs before finishing/reconnecting.
- `tests/build_area_ui.gd`: pans the work area clear of the wider tray before
  dragging. It retains cancellation on HUD release, touch, Escape and replaced
  worlds, and atomic budget/compound-edit checks.

Native macOS Godot 4.7.2/OpenGL review uses the real game camera at 1440×900/100%
and 1280×720/125%, including daylight, actual night, the optional daylight view,
selected-item search and stationary accepted purchases. Captures live in ignored
`build/build-feedback-*.png`; logs are in `build/issue6/`. These are local evidence,
not downloadable artifacts from a fresh clone. `tests/build_overhaul_ui.gd` also
passed automated native card purchase, furniture Move and right-drag rotation.
The compact native area test passed floor/wall rectangle dragging and cancellation.
Headless assertions do not establish visual quality or physical drag behavior.

The required `python3 tools/check.py` run initially stopped at an area-drag test
whose old screen coordinates fell under the wider tray. The fixture was corrected
to pan first; the same runner's remaining suites passed separately. All 127
gameplay/UI suites, both save-continuity processes, eight real Iroh scenarios
and dedicated-server smoke passed. `build/issue6/validation.json` audits suite
coverage. Staged asset-storage and whitespace checks passed. Hosted CI, exports,
physical devices and human playtests are separate validation boundaries.
