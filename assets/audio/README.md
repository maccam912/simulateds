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
