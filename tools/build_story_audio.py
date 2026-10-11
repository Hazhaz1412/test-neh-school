"""Original synthesized soundtrack and SFX for the gate/corridor sequence."""
import math
import random
import struct
import wave
import subprocess
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
write('gate_static', 1.4, lambda t, n: 0.19*n*(0.35+0.65*math.sin(t*47)**2) + 0.10*math.sin(2*math.pi*63*t) + 0.07*math.sin(2*math.pi*1420*t)*(math.sin(t*27)>0.6))
write('strange_knock', 2.4, lambda t, n: sum(0.25*math.sin(2*math.pi*93*(t-a))*math.exp(-(t-a)*38) if 0<=t-a<0.2 else 0 for a in [0.05,0.26,1.45]) + 0.04*math.sin(2*math.pi*528*t)*math.sin(math.pi*t/2.4)**2)
write('door_jumpscare', 0.85, lambda t, n: (0.4*n + 0.3*math.sin(2*math.pi*(77*t+88*t*t)))*math.exp(-t*5)*min(1,t/0.008))
print('Built corridor music, strange repeating sound, gate interference and jumpscare')

# Use the CC0 human chuckle already attributed by teasing_giggle-source.json.
# Keep recognizable laughter, with staggered low voices and a reversed breath
# in the gaps, rather than simply looping the short cheerful original.
subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', str(OUT / 'teasing_giggle.ogg'),
    '-filter_complex',
    '[0:a]asplit=3[a][b][c];'
    '[a]asetrate=18000,aresample=22050,lowpass=f=3600,aecho=0.8:0.7:480|930:0.38|0.22,apad,atrim=0:12[a1];'
    '[b]asetrate=14500,aresample=22050,adelay=1650,lowpass=f=2200,volume=0.6,apad,atrim=0:12[b1];'
    '[c]areverse,asetrate=20000,aresample=22050,adelay=6200,volume=0.32,apad,atrim=0:12[c1];'
    '[a1][b1][c1]amix=inputs=3:normalize=0,alimiter=limit=0.85,afade=t=in:d=0.04,afade=t=out:st=11.4:d=0.6[out]',
    '-map', '[out]', '-ac', '1', '-ar', '22050', str(OUT / 'haunting_laughter.wav')], check=True)
subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', str(OUT / 'ghost_snarl.wav'),
    '-af', 'asetrate=17000,aresample=22050,lowpass=f=4100,aecho=0.8:0.7:85|240:0.4|0.18,alimiter=limit=0.9',
    '-ac', '1', '-ar', '22050', str(OUT / 'pursuer_snarl.wav')], check=True)
print('Built layered haunted human laughter and distorted pursuer snarl')
