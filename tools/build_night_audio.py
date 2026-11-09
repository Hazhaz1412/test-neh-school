"""Small procedural ambience/heartbeat loops; no external recordings."""
from pathlib import Path
import math
import random
import struct
import wave

RATE = 16000
TARGET = Path(__file__).resolve().parents[1] / "assets" / "audio"
TARGET.mkdir(exist_ok=True)


def save(name, values):
    with wave.open(str(TARGET / name), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(b"".join(struct.pack("<h", round(max(-1, min(1, v)) * 32767)) for v in values))


rng = random.Random(47)
heartbeat = []
for i in range(RATE):
    t = i / RATE
    value = 0
    for start, weight in [(0.04, 0.65), (0.27, 0.45)]:
        age = t - start
        if 0 <= age < 0.18:
            value += math.sin(age * math.tau * 53) * math.exp(-age * 24) * min(1, age * 250) * weight
    heartbeat.append(value)
save("threat_heartbeat.wav", heartbeat)
bell = []
for i in range(RATE * 2):
    t = i / RATE
    value = 0.0
    for start in [0, 0.65]:
        age = t - start
        if age >= 0:
            tone = sum(math.sin(age * math.tau * f) * w for f, w in [(660, 0.25), (1032, 0.13), (1789, 0.05)])
            value += tone * math.exp(-age * 3) * min(1, age * 400)
    bell.append(value * min(1, (2 - t) * 25))
save("school_bell.wav", bell)
breathing = []
low = 0.0
for i in range(RATE * 3):
    t = i / RATE
    noise = rng.uniform(-1, 1)
    low = low * 0.93 + noise * 0.07
    envelope = max(0, math.sin(t * math.tau / 3)) ** 2 + max(0, -math.sin(t * math.tau / 3)) ** 2 * 0.7
    breathing.append((noise - low) * envelope * 0.19 * min(1, t * 25, (3 - t) * 25))
save("player_breath.wav", breathing)
print("Built ambience, heartbeat, entity cues and school bell in", TARGET)

# Four distinct alternating chimes: ding-dong, ding-dong at midnight.
midnight = []
for i in range(RATE * 5):
    t = i / RATE
    value = 0.0
    for start, fundamental in [(0.0, 784), (0.8, 587), (1.8, 784), (2.6, 587)]:
        age = t - start
        if age >= 0:
            partials = sum(math.sin(age * math.tau * fundamental * ratio) * weight
                           for ratio, weight in [(1, .27), (2.01, .09), (2.75, .045)])
            value += partials * math.exp(-age * 1.8) * min(1, age * 300)
    midnight.append(value * min(1, (5 - t) * 10))
save('midnight_bell.wav', midnight)

engine = []
for i in range(RATE * 2):
    t = i / RATE
    engine.append((math.sin(t * math.tau * 45) * .18 +
                   math.sin(t * math.tau * 90) * .08 + rng.uniform(-1, 1) * .022)
                  * (.75 + .25 * math.sin(t * math.tau * 12)))
save('arrival_engine.wav', engine)

climb = []
filtered = 0.0
for i in range(round(RATE * .55)):
    t = i / RATE
    filtered = filtered * .7 + rng.uniform(-1, 1) * .3
    envelope = math.exp(-t * 8) * min(1, t * 300)
    climb.append((filtered * .33 + math.sin(t * math.tau * 95) * .18) * envelope)
save('arrival_climb.wav', climb)

# Original deterministic foley for player actions and memory discovery.
for name, duration, frequency, roughness in [('footstep', .20, 110, .32), ('torch', .10, 1700, .12), ('door', .65, 130, .25), ('lock', .25, 980, .18), ('pickup', .35, 720, .03), ('paper', .45, 250, .40), ('hurt', .55, 72, .22), ('memory', 1.6, 440, .01)]:
    samples, filtered = [], 0.
    for i in range(round(RATE * duration)):
        t = i / RATE
        filtered = filtered * .65 + rng.uniform(-1, 1) * .35
        envelope = min(1, t * 150) * math.exp(-t * (5 if name != 'memory' else 1.7)) * min(1, (duration-t)*30)
        tone = math.sin(t * math.tau * frequency) * .2
        if name == 'memory':
            tone = sum(math.sin(t * math.tau * frequency * ratio) * .10 for ratio in (1, 1.5, 2))
        samples.append((tone + filtered * roughness) * envelope)
    save(name + '.wav', samples)

# Mechanical shutter snap followed by the flash capacitor charging again.
shutter = []
for i in range(round(RATE * .65)):
    t = i / RATE
    value = 0.
    for start, decay, weight in [(0., 85, .55), (.045, 105, .35), (.10, 60, .25)]:
        age = t - start
        if age >= 0:
            value += (rng.uniform(-1, 1) + math.sin(age * math.tau * 1500) * .3) * math.exp(-age * decay) * weight
    if t > .16:
        age = t - .16
        value += math.sin(math.tau * (1100 * age + 1200 * age * age)) * .04 * min(1, age * 40) * min(1, (.65 - t) * 12)
    shutter.append(value)
save('camera.wav', shutter)
