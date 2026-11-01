"""Synthesised town sounds: scooter engine loop, horn and distant street bed."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
rng = random.Random(1975)
out = Path(__file__).resolve().parents[1] / "assets" / "audio"

def write(name, samples):
    data = b"".join(struct.pack("<h", int(max(-0.9, min(0.9, s)) * 32767)) for s in samples)
    with wave.open(str(out / f"{name}.wav"), "wb") as stream:
        stream.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        stream.writeframes(data)

def engine():
    # A single-cylinder thump at a whole number of cycles, so the loop has no seam.
    cycles = 48
    base = 40.0
    length = int(RATE * cycles / base)
    period = length / cycles
    low = 0.0
    samples = []
    for i in range(length):
        phase = (i % period) / period
        pulse = math.exp(-phase * 7.0) * (1.0 if int(i / period) % 2 == 0 else 0.72)
        low += (rng.uniform(-1, 1) - low) * 0.18
        samples.append(0.55 * pulse * math.sin(phase * 2 * math.pi * 3) + 0.2 * pulse * low + 0.05 * low)
    return samples

def horn():
    samples = []
    length = int(RATE * 0.42)
    for i in range(length):
        t = i / RATE
        gate = 0.0 if 0.19 < t < 0.25 else 1.0
        tone = sum(math.copysign(1.0, math.sin(2 * math.pi * f * t)) * 0.16 for f in (410, 505))
        samples.append(tone * gate * min(1.0, t / 0.01, (0.42 - t) / 0.02))
    return samples

def street():
    # Twelve seconds of far traffic: filtered noise that breathes, with faint passing bikes.
    length = RATE * 12
    samples = [0.0] * length
    low = 0.0
    for i in range(length):
        low += (rng.uniform(-1, 1) - low) * 0.025
        swell = 0.75 + 0.25 * math.sin(2 * math.pi * i / length * 3)
        samples[i] = low * 1.1 * swell
    for _ in range(9):
        start = rng.randrange(0, length)
        span = int(RATE * rng.uniform(1.6, 3.2))
        pitch = rng.uniform(70, 110)
        gain = rng.uniform(0.03, 0.07)
        for n in range(span):
            place = n / span
            value = math.sin(2 * math.pi * pitch * (1.0 - 0.1 * place) * n / RATE) * math.sin(math.pi * place) ** 2
            samples[(start + n) % length] += value * gain
    for _ in range(5):
        start = rng.randrange(0, length)
        span = int(RATE * 0.22)
        for n in range(span):
            value = math.copysign(1.0, math.sin(2 * math.pi * 620 * n / RATE)) * math.sin(math.pi * n / span)
            samples[(start + n) % length] += value * 0.012
    return samples

def phone_buzz():
    length = int(RATE * 0.62)
    samples = []
    for i in range(length):
        t = i / RATE
        gate = 1.0 if t < 0.24 or t > 0.36 else 0.0
        samples.append(0.5 * gate * math.sin(2 * math.pi * 148 * t) * (0.6 + 0.4 * math.sin(2 * math.pi * 31 * t)))
    return samples

def phone_ding():
    length = int(RATE * 0.3)
    return [0.3 * math.sin(2 * math.pi * (1046 if i < RATE * 0.09 else 1396) * i / RATE) * math.exp(-(i % int(RATE * 0.09)) / RATE * 22) for i in range(length)]

write("phone_buzz", phone_buzz())
write("phone_ding", phone_ding())
write("town_engine", engine())
write("town_horn", horn())
write("town_street", street())
