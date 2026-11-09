"""Synthesised sound of the night guard rattling a locker as he listens at it."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 24000
rng = random.Random(1721)
out = Path(__file__).resolve().parents[1] / "assets" / "audio"

def write(name, duration, synth):
    samples = []
    low = 0.0
    for i in range(int(RATE * duration)):
        t = i / RATE
        low += (rng.uniform(-1, 1) - low) * 0.05
        value = synth(t, low)
        fade = min(1.0, t / 0.002, (duration - t) / 0.03)
        samples.append(int(max(-0.95, min(0.95, value * fade)) * 32767))
    with wave.open(str(out / f"{name}.wav"), "wb") as stream:
        stream.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        stream.writeframes(struct.pack(f"<{len(samples)}h", *samples))

def rattle(t, low):
    knock = sum(math.exp(-max(t - s, 0) * 70) * (t >= s) for s in (0.05, 0.2, 0.33, 0.62, 0.71))
    return knock * (0.5 * math.sin(2 * math.pi * 170 * t) + 1.2 * low) + 0.12 * low

write("guard_rattle", 1.1, rattle)
