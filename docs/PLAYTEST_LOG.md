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

## 2026-11-03 · A busy household

Beds, fridges, showers, and toilets now have one active user, including their
walk to the object. A second directed resident waits in their plan; autonomous
residents choose another available furnishing. Reservations derive from active
actions, so cancellation, travel, disconnect, and construction release them.

Validation: nine suites passed, with explicit tests for waiting snapshots,
cancellation handoff, alternative autonomous choices, and reservation cleanup.
Interactive UI playtest of the preceding plan checkpoint covered opening the
plan, changing autonomy, ordering sleep/TV/reading, Escape navigation, and saving
on quit. No human/family playtest is claimed.

Fresh assessment: clicking tall furniture currently uses its floor tile, which
makes upper surfaces unreliable targets. Next: use the drawn furniture shapes
for picking, show a name and affordance on hover, and select residents by their
visible bodies. This improves ordinary play before adding more objects.
