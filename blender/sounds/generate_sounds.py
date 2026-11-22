"""Procedural SFX for the VotV Signal Console. Stdlib only (wave/math/random).
Run: python blender/sounds/generate_sounds.py
"""
import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.dirname(os.path.abspath(__file__))
TAU = 2.0 * math.pi


def write_wav(name, samples):
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples))
    print(f"{name:28s} {len(samples)/SR:6.3f}s  {os.path.getsize(path):8d} bytes")


def fade(samples, a=0.02, r=0.05):
    n = len(samples)
    ai, ri = int(n * a), int(n * r)
    for i in range(n):
        if i < ai:
            samples[i] *= i / max(1, ai)
        elif i > n - ri:
            samples[i] *= max(0, n - i) / max(1, ri)
    return samples


def static_filtered(dur=3.0):
    n = int(SR * dur)
    out = [0.0] * n
    lp = hp = x_prev = hp_prev = 0.0
    for i in range(n):
        white = random.uniform(-1, 1)
        lp += 0.09 * (white - lp)
        hp = 0.96 * (hp_prev + lp - x_prev)
        x_prev, hp_prev = lp, hp
        env = 0.55 + 0.45 * math.sin(TAU * 3.3 * i / SR) ** 2
        out[i] = 0.55 * hp * env
    return fade(out, 0.02, 0.06)


def transformer_hum(dur=4.0):
    n = int(SR * dur)
    out = [0.0] * n
    lp = 0.0
    for i in range(n):
        t = i / SR
        wob = 1.0 + 0.04 * math.sin(TAU * 0.8 * t)
        v = (0.42 * math.sin(TAU * 50 * t)
             + 0.19 * math.sin(TAU * 100 * t + 0.3)
             + 0.10 * math.sin(TAU * 150 * t)
             + 0.05 * math.sin(TAU * 250 * t + 1.1))
        lp += 0.02 * (random.uniform(-1, 1) - lp)
        out[i] = 0.85 * v * wob + 0.06 * lp
    return fade(out, 0.12, 0.18)


def crt_whine(dur=4.0):
    n = int(SR * dur)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        out[i] = 0.055 * math.sin(TAU * 15700 * t) + 0.012 * math.sin(TAU * 15640 * t + 0.4)
    return fade(out, 0.15, 0.2)


def relay_click(dur=0.14):
    n = int(SR * dur)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        burst = random.uniform(-1, 1)
        v = 0.85 * math.exp(-t * 170) * burst
        v += 0.35 * math.exp(-t * 260) * math.sin(TAU * 1450 * t)
        t2 = t - 0.045
        if t2 > 0:
            v += 0.5 * math.exp(-t2 * 300) * random.uniform(-1, 1)
            v += 0.18 * math.exp(-t2 * 350) * math.sin(TAU * 2100 * t2)
        out[i] = v
    return fade(out, 0.001, 0.02)


def beep_880(dur=0.24):
    n = int(SR * dur)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        env = min(1.0, t / 0.004) * math.exp(-t * 3.2)
        out[i] = 0.42 * env * (math.sin(TAU * 880 * t) + 0.18 * math.sin(TAU * 1760 * t))
    return fade(out, 0.002, 0.03)


def alarm_two_tone(dur=2.4):
    n = int(SR * dur)
    out = [0.0] * n
    step = 0.25
    for i in range(n):
        t = i / SR
        seg = int(t / step)
        f = 600.0 if seg % 2 == 0 else 900.0
        local = t - seg * step
        env = min(1.0, local / 0.008) * min(1.0, (step - local) / 0.025)
        out[i] = 0.34 * env * (math.sin(TAU * f * t) + 0.28 * math.sin(TAU * 2 * f * t))
    return fade(out, 0.01, 0.02)


def station_turnoff(dur=1.4):
    n = int(SR * dur)
    out = [0.0] * n
    phase = 0.0
    lp = 0.0
    for i in range(n):
        t = i / SR
        pitch = 1200.0 * math.exp(-t * 2.4) + 38.0
        phase += TAU * pitch / SR
        lp += 0.05 * (random.uniform(-1, 1) - lp)
        out[i] = 0.36 * math.exp(-t * 1.9) * math.sin(phase) + 0.12 * math.exp(-t * 7.0) * lp
    return fade(out, 0.002, 0.05)


if __name__ == "__main__":
    random.seed(2601)
    write_wav("sig_static_filtered.wav", static_filtered())
    write_wav("sig_transformer_hum.wav", transformer_hum())
    write_wav("sig_crt_whine.wav", crt_whine())
    write_wav("sig_relay_click.wav", relay_click())
    write_wav("sig_beep_880.wav", beep_880())
    write_wav("sig_alarm_two_tone.wav", alarm_two_tone())
    write_wav("sig_station_turnoff.wav", station_turnoff())
    print("Done ->", OUT)
