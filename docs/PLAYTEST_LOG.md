# Feature and playtest checkpoints

## 2026-11-03 · Resident plans

Added an optional floating plan panel, individual action cancellation, and a saved
per-resident autonomy toggle. Direct orders still interrupt autonomous tasks and
preserve existing player orders. Stable action IDs make stale multiplayer cancel
requests harmless. Older saves receive defaults on load.

Validation: all nine local suites; two real Iroh clients issuing queue commands,
stale cancellation and reconnect; dedicated server startup; graphical capture at
1280×720. The plan stays out of the center of the house, and actual mouse input
opens it, changes autonomy, and removes a single row without clicking the world.

Fresh assessment: planning is understandable now, but residents can still share
one bathroom fixture or bed simultaneously. Next: exclusive-use reservations
with readable waiting, release on interruption, and sensible autonomous choices.
