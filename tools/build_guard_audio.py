"""Original synthesized SFX for the night guard: whistle, key ring, the thud on the third floor.

Run: python3 tools/build_guard_audio.py
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parents[1] / 'assets/audio'
rng = random.Random(1611)


def save(name, samples, gain=0.9):
    peak = max(1e-6, max(abs(v) for v in samples))
    data = [round(max(-1.0, min(1.0, v * gain / peak)) * 32767) for v in samples]
    with wave.open(str(OUT / (name + '.wav')), 'wb') as f:
        f.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        f.writeframes(struct.pack('<%dh' % len(data), *data))


def lowpass(samples, cutoff):
    a = 1 - math.exp(-2 * math.pi * cutoff / RATE)
    out, y = [], 0.0
    for v in samples:
        y += a * (v - y)
        out.append(y)
    return out


def mix(target, source, at, gain=1.0):
    start = round(at * RATE)
    for i, v in enumerate(source):
        if 0 <= start + i < len(target):
            target[start + i] += v * gain


def whistle():
    # A pea whistle: a bright tone warbled by the pea, two short blasts and a long one.
    out = [0.0] * round(1.9 * RATE)
    for at, length in ((0.0, 0.22), (0.32, 0.22), (0.66, 1.1)):
        phase = 0.0
        blast = []
        for i in range(round(length * RATE)):
            t = i / RATE
            trill = 1 + 0.035 * math.sin(math.tau * 31 * t)
            phase += math.tau * 2750 * trill / RATE
            env = min(1, t / 0.015) * min(1, (length - t) / 0.04)
            blast.append((math.sin(phase) + 0.25 * math.sin(phase * 2) + 0.15 * rng.uniform(-1, 1)) * env)
        mix(out, blast, at)
    return out


def keys():
    # Two seconds of a key ring jingling at walking pace; loops cleanly.
    seconds = 2.0
    out = [0.0] * round(seconds * RATE)
    for step in range(4):
        base = step * 0.5 + 0.02
        for _ in range(7):
            at = base + rng.uniform(0, 0.12)
            freq = rng.uniform(3200, 6800)
            n = round(0.09 * RATE)
            ping = [math.sin(math.tau * freq * i / RATE) * math.exp(-i / RATE * 55) for i in range(n)]
            mix(out, ping, at, rng.uniform(0.2, 0.5))
    return out


def thud():
    # Something heavy tipping over two floors away: mostly low end, a wooden clatter after.
    out = [0.0] * round(1.6 * RATE)
    body = [math.sin(math.tau * (55 + 40 * math.exp(-i / RATE * 25)) * i / RATE) * math.exp(-i / RATE * 7) for i in range(round(1.0 * RATE))]
    mix(out, body, 0.0, 1.0)
    for at in (0.0, 0.18, 0.31, 0.5):
        knock = lowpass([rng.uniform(-1, 1) * math.exp(-i / RATE * 40) for i in range(round(0.12 * RATE))], 700)
        mix(out, knock, at, 1.4)
    return lowpass(out, 900)


save('guard_whistle', whistle(), 0.8)
save('guard_keys', keys(), 0.6)
save('floor_thud', thud(), 0.9)
print('wrote guard_whistle, guard_keys, floor_thud')
