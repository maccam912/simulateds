# Household creator review — issue #5

The November 4 playtest combines usability defects and optional art proposals.
This pass protects edits and improves inspection. It does not replace resident
geometry or silently change existing households. Every finding has a disposition.

| Finding | Disposition |
| --- | --- |
| CREATE-01 | Adopted previous/next controls for hair, tops, bottoms, shoes and accessories, beside the named keyboard-operable pickers and actual live model. Browsing edits only the current draft and outfit occasion. A thumbnail gallery is deferred: the existing full-size model provides the accurate preview without another model cache. |
| CREATE-02 | Entering Face & hair resets to a front face view; Body & voice and Outfits reset to a front full-body view. Front / reset and explicit zoom buttons remain available. These controls affect only the private studio camera. |
| CREATE-03 | Deferred distinct starter/new-resident presets and randomization. Palette, face and trait combinations need a coordinated cast/content review in the ordinary game camera; automatic variation should not conceal personality choices. Existing saved profiles and new-resident defaults remain unchanged. |
| CREATE-04 | Deferred stage-specific geometry, clothing fit and mannerisms to the character/interaction art pass, together with issue #4's child reach/contact work. Changing proportions independently would require checking furniture poses, picking and all wardrobes. Chosen ages, physical models, collisions and family rules remain unchanged. |
| CREATE-05 | Deferred the side-part nape refinement to the same art pass. The present silhouette remains; there is no claim that its shape was corrected. |
| CREATE-06 | Deferred shoulder/sleeve/cuff geometry changes until the garment/body/pose matrix can be reviewed together. Preview camera improvements do not establish improved clothing contact. |
| CREATE-07 | Deferred new facial presets/expressions with cast differentiation. Keep the existing sculpted style; do not add detail that is only visible in the studio. |
| CREATE-08 | Tightened full-body framing from 1.27× to 1.14× the resident's estimated height, retaining the separate infant framing. Added labeled reset and explicit zoom controls in a wrapping row. Forms scroll while Save/Cancel remain fixed. Native compact review covers full body, face, child, infant and elder previews. |
| CREATE-09 | Cancel and Escape review a changed draft in the existing footer. Keep editing or Escape returns to the same draft; only Discard changes exits. Clean cancellation needs no prompt, and restoring an edit to its initial value is clean. Save submission remains locked until acceptance/rejection; rejected edits remain dirty. Changed sessions cannot apply an old draft, including after dismissing discard review. |
| CREATE-10 | Family choices disable impossible age/tie combinations and explain the exact named pair in tooltips. A visible directional sentence follows each pair. Proposed links are checked against the same whole-family validator used by the host; removing a link stays possible to repair an invalid draft. A later age edit can leave a tie invalid; its pair shows the reason and host Save still rejects atomically without losing edits. |
| CREATE-11 | First-entry customization says Customize household; subsequent entry says Edit household. A persistent footer distinguishes Unsaved changes from No unsaved changes. |
| CREATE-12 | Trait hover text and selection feedback describe the actual autonomous activity preference, with plans and urgent care taking priority. Creative explicitly says painting still needs a deliberate choice. The scrolling Personality section includes each resident's draft traits for comparison; there is no new simulation effect. |

## Reproducible checks

Run scripts with isolated save, profile and settings paths; the aggregate runner
is `python3 tools/check.py`. Never use a normal player's save for this review.

- `tests/character_creator_ui.gd`: native pointer browsing/reset, clean cancel,
  edit/revert, private preview state, independent outfit occasions, trait summary,
  child/adult pair rejection and direction, invalidation by later age edits,
  atomic rejected Save, multiple residents and family links, accepted Save,
  Cancel/Escape/Keep editing/Discard, pending replies and session-change guards.
- `tests/app_flow.gd`: edited-draft Escape confirmation, explicit discard,
  accepted and rejected household edits, and the surrounding app/menu flows.
- `tests/hud_discovery.gd`: fresh-entry Customize household title, clean
  cancellation, and returning navigation without replacing the world.
- Existing `character_creator`, `household`, `character_models` and real
  `creator_peer` suites retain profile validation, eight-person editing,
  multiplayer/reconnect and model compatibility coverage.

Native runs use `tests/character_creator_ui.gd`, adding `--compact` after `--`
for 1280×720 with the UI setting at 125%; default is 1440×900. Captures include
studio daylight/evening, face/back/outfits, family warnings and discard review,
plus actual gameplay camera day/night. Logs are in ignored `build/issue5/`;
captures are ignored `build/creator-*.png`. They are local evidence, not artifacts
available in a fresh clone. Headless tests alone do not establish visual quality.

No assets, saves, protocol fields, chosen ages, autonomy behavior or authoritative
family rules change. The five deferred art proposals require their own future
implementation and native visual review; they are not completed fixes.

## Validation result

The required `python3 tools/check.py` exited 0: all 127 gameplay/UI suites,
both save-continuity restart processes, eight real Iroh scenarios and the
dedicated-server smoke passed. Final focused creator/app/household checks and
native normal/compact runs passed after the last refinements. The staged asset
checker reports 81 hydrated LFS assets; no assets changed. Whitespace checks pass.
Hosted CI is separate. No local exports, physical-device tests or human playtest
were performed for this change.
