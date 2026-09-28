#!/usr/bin/env python3
"""Synthesises the game's sound effects and music loops into assets/sounds/.

Pure standard library (no numpy) so it runs anywhere:
    python3 tool/sounds/make_sounds.py
All sounds are original, generated from simple waveforms.
"""

import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parents[2] / 'assets' / 'sounds'


def write(name, samples, peak=0.85):
    m = max(1e-9, max(abs(s) for s in samples))
    k = peak / m
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f'{name}.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(s * k * 32767)) for s in samples))


def silence(sec):
    return [0.0] * int(sec * RATE)


def tone(freq, sec, vol=1.0, attack=0.005, release=0.08, shape='sine', vibrato=0.0):
    n = int(sec * RATE)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = freq * (1 + vibrato * math.sin(2 * math.pi * 5 * t))
        phase += 2 * math.pi * f / RATE
        if shape == 'sine':
            v = math.sin(phase)
        elif shape == 'square':
            v = 0.6 if math.sin(phase) >= 0 else -0.6
        elif shape == 'saw':
            v = 0.7 * (((phase / (2 * math.pi)) % 1.0) * 2 - 1)
        else:  # soft: sine + harmonics
            v = math.sin(phase) + 0.3 * math.sin(2 * phase) + 0.15 * math.sin(3 * phase)
        env = min(1.0, t / attack) if attack > 0 else 1.0
        env *= min(1.0, (sec - t) / release) if release > 0 else 1.0
        out.append(v * env * vol)
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def seq(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def place(base, clip, at):
    start = int(at * RATE)
    for i, v in enumerate(clip):
        if start + i < len(base):
            base[start + i] += v


# ---------------------------------------------------------------- effects
write('click', tone(1200, 0.05, release=0.04, shape='soft'), peak=0.5)

write('tick', mix(tone(1800, 0.03, release=0.025), tone(900, 0.03, release=0.025, vol=0.5)),
      peak=0.45)

# Final-answer lock: a low dramatic hit with a rising shimmer.
lock = mix(tone(110, 0.9, release=0.7, shape='soft'),
           tone(55, 0.9, release=0.7, vol=0.8),
           seq(silence(0.05), tone(880, 0.5, vol=0.15, release=0.4, vibrato=0.01)))
write('lock', lock, peak=0.8)

correct = seq(*[tone(f, 0.13, shape='soft', release=0.06) for f in (523, 659, 784)],
              tone(1047, 0.45, shape='soft', release=0.35, vibrato=0.004))
write('correct', correct, peak=0.7)

wrong = mix(seq(tone(311, 0.25, shape='saw', release=0.05), tone(233, 0.6, shape='saw', release=0.4)),
            seq(tone(155, 0.25, release=0.05), tone(116, 0.6, release=0.4)))
write('wrong', wrong, peak=0.6)

life = []
for i in range(14):
    life = seq(life, tone(600 + i * 90, 0.035, vol=0.8, release=0.02))
write('lifeline', mix(life, seq(silence(0.3), tone(1400, 0.35, vol=0.4, release=0.3))), peak=0.55)

coin = seq(tone(988, 0.07, shape='square', release=0.03), tone(1319, 0.28, shape='square', release=0.22))
write('coin', coin, peak=0.4)

fan = seq(tone(523, 0.14, shape='soft'), tone(523, 0.14, shape='soft'), tone(523, 0.14, shape='soft'),
          tone(659, 0.35, shape='soft'), tone(587, 0.14, shape='soft'), tone(659, 0.14, shape='soft'),
          tone(784, 0.9, shape='soft', release=0.6, vibrato=0.006))
bass = seq(tone(131, 0.77, release=0.1), tone(196, 1.2, release=0.8))
write('win', mix(fan, [v * 0.6 for v in bass]), peak=0.75)

# ------------------------------------------------------------ music loops
def loop_tension(sec=8.0):
    """Low drone + heartbeat pulse + suspended high note; loops seamlessly."""
    n = int(sec * RATE)
    base = [0.0] * n
    # Drone: frequencies chosen so an integer number of cycles fits the loop.
    for f, vol in ((55.0, 0.35), (82.5, 0.18), (110.0, 0.12)):
        for i in range(n):
            base[i] += vol * math.sin(2 * math.pi * f * i / RATE)
    # Slow tremolo on the drone.
    for i in range(n):
        base[i] *= 0.75 + 0.25 * math.sin(2 * math.pi * 0.25 * i / RATE)
    beat = mix(tone(60, 0.12, vol=0.9, release=0.1), seq(silence(0.18), tone(55, 0.12, vol=0.7, release=0.1)))
    for k in range(8):  # 60 bpm heartbeat
        place(base, beat, k * 1.0)
    # Eerie high pad fading in/out over the loop.
    for i in range(n):
        t = i / RATE
        env = 0.5 - 0.5 * math.cos(2 * math.pi * t / sec)
        base[i] += 0.05 * env * math.sin(2 * math.pi * 880 * t) + 0.04 * env * math.sin(2 * math.pi * 932.5 * t)
    return base


def loop_menu(sec=8.0):
    """Calm pad alternating two chords, 4 s each; loops seamlessly."""
    n = int(sec * RATE)
    base = [0.0] * n
    chords = [(220.0, 277.5, 330.0), (196.0, 247.5, 293.75)]
    half = n // 2
    for c, chord in enumerate(chords):
        for i in range(half):
            t = i / RATE
            env = math.sin(math.pi * i / half) ** 0.6
            v = sum(math.sin(2 * math.pi * f * t) + 0.2 * math.sin(4 * math.pi * f * t) for f in chord)
            base[c * half + i] += 0.2 * env * v
    rnd = random.Random(7)
    for k in range(16):  # sparse soft bells
        f = rnd.choice((660.0, 740.0, 880.0, 990.0))
        place(base, tone(f, 0.6, vol=0.12, release=0.55), k * 0.5 + 0.05)
    return base


write('tension', loop_tension(), peak=0.6)
write('menu', loop_menu(), peak=0.45)
print('sounds written to', OUT)
