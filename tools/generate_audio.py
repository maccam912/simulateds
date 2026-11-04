#!/usr/bin/env python3
"""Generate original Simulateds music/ambience/UI assets. Python standard library only.
No samples, recordings, melodies, or instrument assets from another game are used.
"""
from array import array
import math
from pathlib import Path
import random
import wave

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/audio"
RATE = 22050
TAU = math.tau


def midi(note):
    return 440.0 * 2.0 ** ((note - 69) / 12)


def write(name, channels, peak=0.62, normalize=False):
    maximum = max(max(abs(v) for v in channel) for channel in channels) or 1
    scale = (peak / maximum if normalize else min(1.0, peak / maximum)) * 32767
    out = array("h")
    for frame in zip(*channels):
        out.extend(max(-32767, min(32767, round(v * scale))) for v in frame)
    with wave.open(str(DEST / name), "wb") as target:
        target.setnchannels(len(channels))
        target.setsampwidth(2)
        target.setframerate(RATE)
        target.writeframes(out.tobytes())


def note(track, start, duration, pitch, gain, pan=0.0, kind="tine"):
    length = len(track[0])
    offset = round(start * RATE)
    frequency = midi(pitch)
    for i in range(round(duration * RATE)):
        t = i / RATE
        attack = min(1.0, t / (0.025 if kind == "pad" else 0.006))
        tail = min(1.0, (duration - t) / 0.15)
        if kind == "pad":
            envelope = attack * tail * math.exp(-t * 0.6)
            tone = (math.sin(TAU * frequency * t) + 0.25 * math.sin(TAU * frequency * 1.003 * t) + 0.12 * math.sin(TAU * frequency * 2 * t)) / 1.37
        elif kind == "bass":
            envelope = attack * tail * math.exp(-t * 2.0)
            tone = math.sin(TAU * frequency * t) + 0.2 * math.sin(TAU * frequency * 2 * t)
        else:
            envelope = attack * tail * math.exp(-t * (3.4 if kind == "wood" else 2.4))
            tone = math.sin(TAU * frequency * t) + 0.22 * math.sin(TAU * frequency * 2 * t) * math.exp(-t * 5) + 0.07 * math.sin(TAU * frequency * 3 * t) * math.exp(-t * 10)
        sample = tone * envelope * gain
        index = (offset + i) % length
        track[0][index] += sample * math.sqrt((1 - pan) / 2)
        track[1][index] += sample * math.sqrt((1 + pan) / 2)


def music(name, style):
    duration = 24
    track = [array("f", [0]) * (duration * RATE) for _ in range(2)]
    chords = [[60, 64, 67, 71], [57, 60, 64, 67], [53, 57, 60, 64], [55, 60, 62, 67],
              [52, 55, 59, 62], [57, 60, 64, 67], [50, 53, 57, 60], [55, 59, 62, 65]]
    melody = [[76, 74], [72, 71], [69, 72], [74, 67], [71, 74], [76, 72], [69, 65], [67, 71]]
    for bar, chord in enumerate(chords):
        base = bar * 3.0
        note(track, base, 2.7, chord[0] - 12, .12, kind="bass")
        if style == "menu":
            for index, pitch in enumerate(chord):
                note(track, base + index * .08, 3.3, pitch, .055, (index - 1.5) / 3, "pad")
            note(track, base + .75, 2.0, melody[bar][0], .095, .12)
            if bar % 2:
                note(track, base + 2.25, 1.7, melody[bar][1], .065, -.12)
        elif style == "live":
            for index, pitch in enumerate(chord):
                note(track, base + .1 + index * .11, 2.7, pitch, .045, (index - 1.5) / 4, "pad")
            if bar % 2 == 0:
                note(track, base + 1.5, 1.6, melody[bar][1], .07, .2)
        else:
            for beat, index in enumerate([0, 2, 1, 3]):
                note(track, base + beat * .75, 1.6, chord[index] + 12, .07, (index - 1.5) / 4, "wood")
            note(track, base + 1.5, 2.0, chord[0], .05, -.2)
    write(name, track, normalize=True)


def ambience():
    rng = random.Random(7319)
    length = 24 * RATE
    channel = array("f", [0]) * length
    smooth = 0.0
    for i in range(length):
        smooth = smooth * .985 + rng.uniform(-1, 1) * .015
        channel[i] = smooth * .28 * (.8 + .2 * math.sin(TAU * i / length))
    for start in [2.2, 8.9, 14.6, 20.5]:
        for chirp in range(2):
            offset = round((start + chirp * .21) * RATE)
            phase = 0.0
            for i in range(round(.14 * RATE)):
                t = i / RATE
                frequency = 2000 + 800 * math.sin(math.pi * t / .14)
                phase += TAU * frequency / RATE
                envelope = math.sin(math.pi * t / .14) ** 2
                channel[(offset + i) % length] += math.sin(phase) * envelope * .025
    # Fade the low noise bed to zero at the loop seam; birds do not overlap it.
    fade = RATE // 8
    for i in range(fade):
        envelope = math.sin(math.pi * 0.5 * i / fade) ** 2
        channel[i] *= envelope
        channel[length - 1 - i] *= envelope
    write("garden.wav", [channel], .25)


def ui(name, notes, duration=.32, gain=.22):
    track = [array("f", [0]) * round(duration * RATE) for _ in range(2)]
    for start, pitch in notes:
        note(track, start, max(.05, duration - start), pitch, gain, kind="wood")
    write(name + ".wav", track, .45)


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    for style in ["menu", "live", "build"]:
        music(style + ".wav", style)
    ambience()
    ui("hover", [(0, 79)], .09, .06)
    ui("click", [(0, 64)], .13, .15)
    ui("confirm", [(0, 72), (.10, 79)], .40, .18)
    ui("error", [(0, 55), (.10, 53)], .32, .13)
    ui("save", [(0, 67), (.10, 72), (.20, 76)], .58, .15)
    ui("place", [(0, 60), (.055, 67)], .24, .17)
    print("Generated original music, garden ambience, and six UI sounds in", DEST)


if __name__ == "__main__":
    main()
