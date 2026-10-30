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

# The loop length is a whole number of drone cycles, so the seam stays silent.
LOOP = 19.2
TUNE = [(0.0, 440.0), (1.2, 523.25), (2.4, 493.88), (3.6, 329.63), (4.8, 349.23), (6.0, 440.0), (7.8, 415.3),
        (9.6, 440.0), (10.8, 523.25), (12.0, 659.25), (13.2, 622.25), (14.4, 493.88), (16.2, 415.3)]

def lullaby(t, noise):
    drone = 0.070 * math.sin(2 * math.pi * 55.0 * t) * (0.7 + 0.3 * math.sin(2 * math.pi * t / LOOP * 3))
    drone += 0.040 * math.sin(2 * math.pi * 55.625 * t)
    air = noise * 0.012 * (0.5 + 0.5 * math.sin(2 * math.pi * t / LOOP * 2))
    box = 0.0
    for start, pitch in TUNE:
        age = t - start
        if 0 <= age < 2.6:
            # Slightly flat, slowly drifting: a music box whose spring is failing.
            drift = pitch * (0.988 + 0.004 * math.sin(t * 0.9))
            box += 0.14 * math.exp(-age * 2.1) * (math.sin(2 * math.pi * drift * age) + 0.35 * math.sin(2 * math.pi * drift * 2.99 * age))
    return drone + air + box

write('eerie_lullaby', LOOP, lullaby)

def shriek(t, noise):
    envelope = min(1, t / 0.012) * math.exp(-max(0, t - 0.35) * 4.2)
    voice = sum(math.sin(2 * math.pi * (f * t + 240 * t * t)) for f in (620, 833, 1190)) / 3
    return envelope * (0.55 * voice + 0.34 * noise + 0.2 * math.copysign(1, voice))

write('ghost_shriek', 1.0, shriek)

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
