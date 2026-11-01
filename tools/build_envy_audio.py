"""Synthesised Envy demon sounds: footfall, medal clink, listening at a locker."""
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

def step(t, low):
    drop = 58 - 26 * min(t / 0.25, 1.0)
    return 0.9 * math.sin(2 * math.pi * drop * t) * math.exp(-t * 6.0) + 1.4 * low * math.exp(-t * 16.0) + 0.3 * math.sin(2 * math.pi * 31 * t) * math.exp(-t * 3.0)

def clink(t, low):
    tone = 0.0
    for start, pitch in ((0.0, 2310), (0.07, 2870), (0.15, 1980)):
        if t >= start:
            age = t - start
            tone += math.sin(2 * math.pi * pitch * age) * math.exp(-age * 34) + 0.5 * math.sin(2 * math.pi * pitch * 2.63 * age) * math.exp(-age * 60)
    return tone * 0.2

def rattle(t, low):
    knock = sum(math.exp(-max(t - s, 0) * 70) * (t >= s) for s in (0.05, 0.2, 0.33, 0.62, 0.71))
    return knock * (0.5 * math.sin(2 * math.pi * 170 * t) + 1.2 * low) + 0.12 * low

write("envy_step", 0.95, step)
write("envy_clink", 0.5, clink)
write("envy_rattle", 1.1, rattle)
