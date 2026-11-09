"""Original synthesized chase music for the escape and the service tunnels."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / 'assets/audio'
rng = random.Random(1030)

def write(name, seconds, signal):
    samples = []
    for i in range(round(seconds * RATE)):
        t = i / RATE
        value = signal(t, rng.uniform(-1, 1))
        samples.append(round(max(-0.92, min(0.92, value)) * 32767))
    with wave.open(str(OUT / (name + '.wav')), 'wb') as f:
        f.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        f.writeframes(struct.pack('<%dh' % len(samples), *samples))

beat = 60 / 128
notes = [82.4069, 73.4162, 65.4064, 61.7354]
def chase(t, noise):
    phase = t % beat
    kick = 0.32 * math.sin(2 * math.pi * (48 * phase + 2.1 * (1 - math.exp(-phase * 38)))) * math.exp(-phase * 17)
    hat = noise * 0.09 * math.exp(-(t % (beat / 2)) * 110)
    bar = int(t / (beat * 4)) % 4
    bass = notes[bar]
    pulse = math.sin(2 * math.pi * bass * t) * 0.13
    pulse += math.sin(2 * math.pi * bass * 2 * t) * 0.035
    arp = [1, 1.5, 2, 1.1892][int(t / (beat / 2)) % 4]
    strings = math.sin(2 * math.pi * bass * 4 * arp * t) * 0.09 * math.exp(-(t % (beat / 2)) * 8)
    tension = 0.025 * math.sin(2 * math.pi * 659.255 * t) + 0.018 * math.sin(2 * math.pi * 698.456 * t)
    return kick + hat + pulse + strings + tension
write('corridor_chase', beat * 16, chase)
print('Built the tunnel chase music')
