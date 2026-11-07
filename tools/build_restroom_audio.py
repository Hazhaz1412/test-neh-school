"""Original synthesized SFX for the prologue restroom: the mirror crash, the leak and the insects.

Run: python3 tools/build_restroom_audio.py
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parents[1] / 'assets/audio'
rng = random.Random(2031)


def save(name, samples, gain=1.0):
    peak = max(1e-6, max(abs(v) for v in samples))
    scale = gain * 0.9 / peak
    data = [round(max(-1.0, min(1.0, v * scale)) * 32767) for v in samples]
    with wave.open(str(OUT / (name + '.wav')), 'wb') as f:
        f.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        f.writeframes(struct.pack('<%dh' % len(data), *data))


def silence(seconds):
    return [0.0] * round(seconds * RATE)


def lowpass(samples, cutoff):
    a = 1 - math.exp(-2 * math.pi * cutoff / RATE)
    out, y = [], 0.0
    for v in samples:
        y += a * (v - y)
        out.append(y)
    return out


def highpass(samples, cutoff):
    low = lowpass(samples, cutoff)
    return [v - l for v, l in zip(samples, low)]


def mix(target, source, at, gain=1.0):
    start = round(at * RATE)
    for i, v in enumerate(source):
        if start + i < len(target):
            target[start + i] += v * gain


def ping(freq, seconds, decay, partials=((1.0, 1.0), (2.76, 0.45), (5.4, 0.22))):
    """A small glass or ceramic shard ringing: inharmonic partials with fast decay."""
    n = round(seconds * RATE)
    phase = [rng.uniform(0, math.tau) for _ in partials]
    return [sum(a * math.sin(math.tau * freq * r * i / RATE + p) * math.exp(-i / RATE * decay * (1 + r * 0.6))
                for (r, a), p in zip(partials, phase)) for i in range(n)]


def noise_burst(seconds, decay):
    n = round(seconds * RATE)
    return [rng.uniform(-1, 1) * math.exp(-i / RATE * decay) for i in range(n)]


def glass_crash():
    out = silence(2.6)
    # The mirror lets go of the wall and lands on the basin: a dull body hit first.
    thud = [math.sin(math.tau * (70 + 50 * math.exp(-i / RATE * 30)) * i / RATE) * math.exp(-i / RATE * 14)
            for i in range(round(0.5 * RATE))]
    mix(out, thud, 0.0, 0.9)
    mix(out, lowpass(noise_burst(0.35, 18), 900), 0.0, 0.7)
    # The sheet itself fractures: a bright broadband crack, then a spray of shards.
    mix(out, highpass(noise_burst(0.5, 9), 2500), 0.012, 0.85)
    for k in range(150):
        at = 0.02 + rng.random() ** 2.2 * 2.2
        freq = rng.uniform(2200, 7800)
        gain = rng.uniform(0.08, 0.32) * math.exp(-at * 1.1)
        mix(out, ping(freq, 0.35, rng.uniform(16, 40)), at, gain)
    # A few heavier pieces bounce on the ceramic and the tiles.
    for at in (0.21, 0.37, 0.58, 0.9, 1.3):
        mix(out, ping(rng.uniform(900, 1600), 0.4, 22, ((1, 1), (2.4, 0.6), (4.1, 0.3))), at, 0.35)
        mix(out, highpass(noise_burst(0.06, 60), 1800), at, 0.3)
    return out


def water_gush():
    seconds = 3.0
    n = round(seconds * RATE)
    hiss = highpass(lowpass([rng.uniform(-1, 1) for _ in range(n + RATE)], 5200), 380)
    body = lowpass([rng.uniform(-1, 1) for _ in range(n + RATE)], 650)
    out = []
    for i in range(n + RATE):
        t = i / RATE
        bubble = 0.75 + 0.25 * math.sin(math.tau * 5.3 * t) * math.sin(math.tau * 0.7 * t)
        out.append(hiss[i] * 0.55 * bubble + body[i] * 0.9)
    # Random plinks of water hitting water.
    for _ in range(40):
        at = rng.uniform(0, seconds + 0.9)
        mix(out, ping(rng.uniform(500, 1400), 0.12, 45, ((1, 1),)), at, 0.12)
    # Cross-fade the tail into the head so the loop has no seam.
    fade = RATE
    looped = out[:n]
    for i in range(fade):
        w = i / fade
        looped[i] = out[n + i] * (1 - w) + out[i] * w
    return looped


def drip():
    n = round(0.32 * RATE)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        freq = 700 + 1400 * min(1, t / 0.035)
        phase += math.tau * freq / RATE
        out.append(math.sin(phase) * math.exp(-t * 26) * min(1, t / 0.002))
    mix(out, lowpass(noise_burst(0.02, 200), 3000), 0, 0.25)
    return out


def skitter(seconds, density, wings):
    n = round(seconds * RATE)
    out = [0.0] * n
    # Hundreds of chitin legs ticking on wood and tile.
    for _ in range(int(seconds * density)):
        at = rng.uniform(0, seconds - 0.01)
        click = highpass(noise_burst(0.006, 900), 3000)
        mix(out, click, at, rng.uniform(0.15, 0.6))
    if wings:
        # Cockroaches take off: a ragged low flutter.
        buzz = lowpass([rng.uniform(-1, 1) for _ in range(n)], 1100)
        for i in range(n):
            t = i / RATE
            flutter = 0.5 + 0.5 * math.sin(math.tau * (52 + 9 * math.sin(t * 3.1)) * t)
            out[i] += buzz[i] * flutter * 0.55 * wings(t)
    return out


def insect_burst():
    out = silence(2.8)
    # The cabinet door slaps back against its hinge.
    slap = [math.sin(math.tau * 140 * i / RATE) * math.exp(-i / RATE * 30) for i in range(round(0.25 * RATE))]
    mix(out, slap, 0.0, 0.8)
    mix(out, lowpass(noise_burst(0.18, 30), 2200), 0.0, 0.8)
    swarm = skitter(2.75, 2600, lambda t: min(1, t / 0.06) * math.exp(-max(0, t - 0.5) * 1.6))
    for i in range(len(swarm)):
        t = i / RATE
        swarm[i] *= min(1, t / 0.03) * (1.0 if t < 1.0 else math.exp(-(t - 1.0) * 1.5))
    mix(out, swarm, 0.02, 1.0)
    return out


def skitter_loop():
    seconds = 2.0
    body = skitter(seconds, 900, None)
    return [v * (0.7 + 0.3 * math.sin(math.tau * i / RATE / seconds * 3)) for i, v in enumerate(body)]


save('mirror_crash', glass_crash())
save('mirror_crash_muffled', lowpass(lowpass(glass_crash(), 1400), 1800), 0.8)
save('water_leak', water_gush(), 0.7)
save('water_drip', drip(), 0.8)
save('insect_burst', insect_burst())
save('insect_skitter', skitter_loop(), 0.6)
print('wrote mirror_crash, mirror_crash_muffled, water_leak, water_drip, insect_burst, insect_skitter')
