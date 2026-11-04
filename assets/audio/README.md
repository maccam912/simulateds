# Simulateds sound palette

All WAV files here are original procedural compositions generated for this
project by `python3 tools/generate_audio.py`. No samples, music, or instrument
recordings from The Sims or another game were used. These assets follow the
project's MIT license.

The musical language is small, domestic, and unhurried: soft electric-keyboard
chords, muted wooden/plucked notes, and a light bass voice at 80 BPM. Three
24-second stereo loops share one harmonic vocabulary: the main menu has a sparse
melody, live mode makes room for household sounds, and construction adds a gentle
arpeggio. This is a first musical sketch, intended to be replaced or extended
with longer variations as the game develops.

`garden.wav` supplies a quiet wind bed and occasional synthetic birds. Short UI
cues distinguish focus, click, confirmation, an unavailable action, successful
save, and placement. They route through separate Music, Ambience, and Effects
buses under Master. At zero volume a bus is muted.

`game/audio_director.gd` crossfades contexts and limits hover sounds. Headless
servers and native smoke checks do not start audio playback. Settings persist
separately from world saves.


Eleven short mono household textures now accompany visible accepted actions:
`step_wood`, `step_grass`, `page`, `water`, `tea`, `meal`, `fabric`, `shower`,
`chat`, `television`, and `game_piece`. They are original filtered-noise/resonance sketches,
including abstract syllables rather than a sampled or imitated voice. Quiet cloth
settling covers beds/sofas; liquid textures cover watering and bathroom activity.
Textures are sparse accents, not appliance loops or simulated room acoustics.
The game table uses a short, damped wooden click for moving a piece, sampled
from accepted activity progress every five simulation seconds.
Garden planting/harvesting reuse the quiet papery rustle as a seed/leaf accent;
watering uses the existing liquid texture. These follow the accepted garden task,
with the same positional voices, mute behavior, and overall rate limits.

A presentation sampler follows displayed walking and actual task progress.
Repeated snapshots produce no repeated sounds, teleports produce no footsteps,
and resuming/changing lots never replays a backlog. Four separate positional
voices share the Effects bus with UI sounds but never steal UI voices. Activity
cues take priority over footsteps; per-resident and overall rate limits keep a
crowded house from chattering. Sources follow the camera and stop when offscreen
or canceled. Menus, the console, construction, effects/master mute, and a stopped
simulation stop household playback. Reduced motion changes visuals, not hearing.

`tests/render_activity_audio.gd` records the actual Godot output bus into ignored
`build/activity-audio-*.wav` artifacts. It checks left/right placement, zero output
with effects muted, bounded overlapping voices, clean shutdown, and normal live
walking/reading/gardening/tea. These mixer measurements are not a human listening
or device-speaker assessment; that remains part of family playtesting.
The graphical tabletop check also records its actual positional voice in
`build/tabletop-mix*.wav`, with nonzero output and no clipping in both window sizes.

`dance.wav` is a separate original 19.2-second, 100-BPM mono groove: eight bars
of soft bass, offbeat wooden keys, and synthesized drums. It comes from the same
standard-library generator. One visible stereo with an arrived dancer plays at a
time, preferring the selected resident's source and otherwise using stable object
order. Camera changes update its position; identical snapshots and additional
dancers do not restart or stack it. The Music slider controls both stereo and
background score. An internal Score bus lowers the background by 18 dB while the
stereo plays, independently of context crossfades. Effects mute affects household
textures and UI, while Music mute stops the stereo. Pause, menus, construction,
source departure, and offscreen speakers stop it; shutdown releases its stream.

A short household activity now retains one onset cue through the 180-ms mix gap
following a footstep. It is discarded immediately if that exact activity stops,
changes, leaves view, or is paused; this is not a queue of past sounds. Repeated
snapshots still cannot replay an already-emitted onset.

The native dancing playtest records `build/dancing-music*.wav` and
`build/dancing-muted*.wav`, verifying audible unclipped output and music mute in
standard and compact windows. Mixer measurements do not replace listening on
family devices.


Painting reuses the quiet `page` texture at onset and at most once every five
activity seconds. Packing a sold painting uses one `fabric` onset. Both follow
the existing position, visibility, pause, Effects volume, and onset-deduplication
rules. The native painting flows check that both cues reach the live mixer;
this is event-level coverage, not a new recording or listening assessment.

Commission readiness reuses `confirm.wav` under the `ready` UI event, 6 dB quieter
than the normal confirmation cue. It plays once per newly ready accepted request;
loaded state and menu-time changes remain quiet. Effects volume/mute applies.
