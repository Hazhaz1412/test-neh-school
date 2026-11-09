"""Small mechanical one-shots: a lamp popping and a chair scraping and falling."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 24000
rng = random.Random(426)
out = Path(__file__).resolve().parents[1] / "assets" / "audio"

def write(name, duration, synth):
    samples = []
    previous = 0.0
    for i in range(int(RATE * duration)):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        high = noise - previous
        previous = noise
        value = synth(t, noise, high)
        fade = min(1.0, t / 0.004, (duration - t) / 0.025)
        samples.append(int(max(-0.85, min(0.85, value * fade)) * 32767))
    with wave.open(str(out / f"{name}.wav"), "wb") as stream:
        stream.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        stream.writeframes(struct.pack(f"<{len(samples)}h", *samples))

write("lamp_pop", 0.65, lambda t,n,h: 0.50*h*math.exp(-t*32) + 0.23*n*math.exp(-t*10)*(0.3+0.7*math.sin(t*2700)**2))
write("chair_scrape", 0.5, lambda t,n,h: 0.16*n*math.sin(math.pi*t/0.5)**2 + 0.09*math.sin(t*2*math.pi*(420+110*math.sin(t*26)))*math.sin(math.pi*t/0.5))
write("chair_impact", 0.55, lambda t,n,h: 0.40*math.sin(t*2*math.pi*95)*math.exp(-t*20) + 0.24*n*math.exp(-t*14) + 0.08*math.sin(t*2*math.pi*1150)*math.exp(-t*18))
print("Built 4 mono mechanical scare SFX")
