"""Original synthesized cues for the Night 1 jumpscare, ascent and escape."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / 'assets/audio'
rng = random.Random(1031)

def write(name, seconds, signal):
    samples = []
    for i in range(round(seconds * RATE)):
        t = i / RATE
        samples.append(round(max(-0.92, min(0.92, signal(t, rng.uniform(-1, 1)))) * 32767))
    with wave.open(str(OUT / (name + '.wav')), 'wb') as f:
        f.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        f.writeframes(struct.pack('<%dh' % len(samples), *samples))

def bang(t, noise):
    body = 0.85 * math.sin(2 * math.pi * 62 * t) * math.exp(-t * 15)
    wood = 0.35 * math.sin(2 * math.pi * 188 * t) * math.exp(-t * 34)
    return body + wood + noise * 0.34 * math.exp(-t * 70)

write('door_bang', 0.55, bang)

def heartbeat(t, noise):
    thump = 0.0
    for start, level in ((0.0, 0.85), (0.21, 0.58)):
        age = t - start
        if age >= 0:
            thump += level * math.sin(2 * math.pi * (46 - 14 * age) * age) * math.exp(-age * 21)
    return thump

write('heartbeat_single', 0.5, heartbeat)
print('Built lullaby, shriek, door bang and single heartbeat')
