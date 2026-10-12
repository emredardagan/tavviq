#!/usr/bin/env python3
"""Synthesises every Tavviq sound effect and the music loop into WAV files.

Usage: python3 tools/gen_audio.py <out_dir>
Then convert with afconvert (see tools/build_audio.sh).
"""
import math
import random
import struct
import sys
import wave

SR = 44100
random.seed(7)
TAU = math.pi * 2


def silence(sec):
    return [0.0] * int(SR * sec)


def write(path, samples, gain=0.9):
    peak = max(1e-6, max(abs(s) for s in samples))
    k = gain / peak
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * k)) * 32767)) for s in samples))


def mix(dst, src, at=0.0, vol=1.0):
    o = int(at * SR)
    need = o + len(src)
    if need > len(dst):
        dst.extend([0.0] * (need - len(dst)))
    for i, s in enumerate(src):
        dst[o + i] += s * vol
    return dst


def env_ad(n, attack, decay_tau):
    a = max(1, int(attack * SR))
    out = []
    for i in range(n):
        if i < a:
            out.append(i / a)
        else:
            out.append(math.exp(-(i - a) / (decay_tau * SR)))
    return out


def tone(freq, dur, kind="sine", attack=0.003, tau=0.2, f_end=None, vib=0.0, vib_rate=6.0):
    n = int(dur * SR)
    e = env_ad(n, attack, tau)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / n
        f = freq if f_end is None else freq * (f_end / freq) ** t
        if vib:
            f *= 1 + vib * math.sin(TAU * vib_rate * i / SR)
        ph += TAU * f / SR
        if kind == "sine":
            v = math.sin(ph)
        elif kind == "tri":
            v = 2 / math.pi * math.asin(math.sin(ph))
        elif kind == "square":
            v = math.tanh(3 * math.sin(ph))
        elif kind == "saw":
            v = ((ph / TAU) % 1.0) * 2 - 1
        else:
            v = math.sin(ph)
        # fade the last 4 ms to avoid clicks
        tail = min(1.0, (n - i) / (0.004 * SR))
        out.append(v * e[i] * tail)
    return out


def noise(dur, tau=0.1, attack=0.001, lp=0.5, hp=0.0):
    n = int(dur * SR)
    e = env_ad(n, attack, tau)
    out = []
    y = 0.0
    prev = 0.0
    hy = 0.0
    for i in range(n):
        x = random.uniform(-1, 1)
        y += lp * (x - y)              # one-pole low-pass
        hy = y - prev if hp else y      # crude high-pass (differentiator)
        prev = y
        tail = min(1.0, (n - i) / (0.004 * SR))
        out.append(hy * e[i] * tail)
    return out


def marimba(freq, dur=0.5, vol=1.0):
    a = tone(freq, dur, "sine", 0.002, 0.22)
    b = tone(freq * 4.0, dur, "sine", 0.001, 0.04)
    c = tone(freq * 9.8, dur, "sine", 0.001, 0.012)
    return [(x + 0.35 * y + 0.12 * z) * vol for x, y, z in zip(a, b, c)]


def pluck_bass(freq, dur=0.45, vol=1.0):
    a = tone(freq, dur, "tri", 0.003, 0.26)
    b = tone(freq * 2, dur, "sine", 0.002, 0.08)
    return [(x + 0.3 * y) * vol for x, y in zip(a, b)]


def bell(freq, dur=1.2, vol=1.0):
    parts = [(1.0, 1.0, 0.5), (2.76, 0.5, 0.25), (5.4, 0.25, 0.12), (8.93, 0.12, 0.06)]
    out = [0.0] * int(dur * SR)
    for ratio, amp, tau in parts:
        t = tone(freq * ratio, dur, "sine", 0.001, tau)
        for i, s in enumerate(t):
            out[i] += s * amp * vol
    return out


def reverb(x, wet=0.22):
    delays = [int(SR * d) for d in (0.0297, 0.0371, 0.0411, 0.0437)]
    out = list(x) + [0.0] * int(SR * 1.2)
    bufs = [[0.0] * d for d in delays]
    idx = [0] * len(delays)
    fb = 0.78
    for i in range(len(out)):
        dry = out[i] if i < len(x) else 0.0
        acc = 0.0
        for k, d in enumerate(delays):
            b = bufs[k]
            y = b[idx[k]]
            b[idx[k]] = dry + y * fb
            idx[k] = (idx[k] + 1) % d
            acc += y
        out[i] = (x[i] if i < len(x) else 0.0) + acc * wet / len(delays)
    return out


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


# ---------------- sound effects ----------------

def sfx_hop(pitch):
    a = tone(300 * pitch, 0.09, "sine", 0.002, 0.04, f_end=620 * pitch)
    b = tone(600 * pitch, 0.06, "tri", 0.001, 0.02, f_end=900 * pitch)
    return [x + 0.25 * y for x, y in zip(a, b + [0.0] * (len(a) - len(b)))]


def sfx_coin():
    out = []
    mix(out, tone(midi(83), 0.12, "square", 0.001, 0.05), 0)
    mix(out, tone(midi(88), 0.32, "square", 0.001, 0.12), 0.07)
    mix(out, tone(midi(100), 0.25, "sine", 0.001, 0.06), 0.07, 0.3)
    return reverb(out, 0.12)


def sfx_squash():
    out = []
    mix(out, noise(0.25, 0.06, lp=0.25), 0)
    mix(out, tone(220, 0.25, "square", 0.002, 0.08, f_end=60), 0, 0.7)
    mix(out, tone(900, 0.12, "sine", 0.001, 0.03, f_end=300), 0, 0.3)
    return out


def sfx_splash():
    out = []
    mix(out, noise(0.6, 0.18, attack=0.004, lp=0.35), 0)
    for k in range(7):
        f = random.uniform(500, 1300)
        mix(out, tone(f, 0.07, "sine", 0.002, 0.025, f_end=f * 1.9), 0.05 + k * 0.045, 0.35)
    return reverb(out, 0.15)


def sfx_honk():
    out = []
    a = tone(392, 0.32, "square", 0.01, 0.6)
    b = tone(494, 0.32, "square", 0.01, 0.6)
    mix(out, [x + y for x, y in zip(a, b)], 0)
    # low-pass by averaging
    sm = []
    y = 0.0
    for s in out:
        y += 0.18 * (s - y)
        sm.append(y)
    return sm


def sfx_bell():
    out = []
    for k in range(3):
        mix(out, bell(1320, 0.5), k * 0.28, 0.9)
    return reverb(out, 0.1)


def sfx_train():
    out = []
    mix(out, noise(1.4, 0.8, attack=0.25, lp=0.06), 0, 1.0)
    for k in range(6):
        mix(out, noise(0.08, 0.03, lp=0.4), 0.1 + k * 0.2, 0.6)
    horn = []
    for f in (311, 370, 466):
        mix(horn, tone(f, 0.7, "saw", 0.03, 0.9), 0, 0.3)
    sm = []
    y = 0.0
    for s in horn:
        y += 0.12 * (s - y)
        sm.append(y)
    mix(out, sm, 0.0, 1.4)
    return out


def sfx_eagle():
    out = []
    mix(out, tone(2100, 0.55, "saw", 0.02, 0.35, f_end=1100, vib=0.03, vib_rate=28), 0, 0.5)
    mix(out, noise(0.5, 0.25, lp=0.6, hp=1), 0, 0.25)
    sm = []
    y = 0.0
    for s in out:
        y += 0.35 * (s - y)
        sm.append(y)
    return reverb(sm, 0.2)


def sfx_tap():
    return tone(620, 0.07, "sine", 0.001, 0.025, f_end=980)


def sfx_bump():
    out = []
    mix(out, tone(160, 0.14, "sine", 0.001, 0.05, f_end=90), 0)
    mix(out, noise(0.06, 0.02, lp=0.2), 0, 0.4)
    return out


def sfx_whoosh():
    n = noise(0.45, 0.3, attack=0.18, lp=0.12)
    return n


def sfx_unlock():
    out = []
    for k, m in enumerate([72, 76, 79, 84, 88]):
        mix(out, marimba(midi(m), 0.6), k * 0.075, 0.9)
    mix(out, bell(midi(96), 1.0), 0.38, 0.25)
    return reverb(out, 0.25)


def sfx_record():
    out = []
    for k, m in enumerate([67, 72, 76, 79]):
        mix(out, tone(midi(m), 0.25, "square", 0.004, 0.12), k * 0.09, 0.5)
    mix(out, tone(midi(84), 0.7, "square", 0.004, 0.35, vib=0.01), 0.36, 0.55)
    mix(out, tone(midi(79), 0.7, "square", 0.004, 0.35), 0.36, 0.35)
    return reverb(out, 0.2)


def sfx_cluck():
    """A cartoon 'bok-bok-baGAWK': buzzy formant blips."""
    out = []

    def blip(f0, f1, dur):
        a = tone(f0, dur, "saw", 0.004, dur * 0.6, f_end=f1)
        b = tone(f0 * 2.02, dur, "square", 0.004, dur * 0.5, f_end=f1 * 2)
        y = 0.0
        res = []
        for x, z in zip(a, b):
            y += 0.3 * ((x * 0.6 + z * 0.4) - y)
            res.append(y)
        return res

    mix(out, blip(520, 420, 0.07), 0.0)
    mix(out, blip(540, 430, 0.07), 0.12)
    mix(out, blip(480, 760, 0.08), 0.26)
    mix(out, blip(780, 560, 0.2), 0.33)
    return out


def sfx_pop():
    out = []
    mix(out, tone(400, 0.12, "sine", 0.001, 0.04, f_end=1200), 0)
    mix(out, tone(1600, 0.05, "sine", 0.001, 0.015), 0.02, 0.2)
    return out


def sfx_crack():
    out = []
    for k in range(4):
        mix(out, noise(0.05, 0.012, lp=0.8, hp=1), k * 0.035 + random.uniform(0, 0.01), 0.8)
    mix(out, tone(300, 0.1, "sine", 0.001, 0.03, f_end=150), 0, 0.5)
    return out


def sfx_gift():
    out = []
    for k in range(9):
        mix(out, tone(midi(84 + (k * 5) % 12) * 2, 0.25, "sine", 0.001, 0.08), k * 0.05, 0.5)
    mix(out, sfx_unlock(), 0.1, 0.7)
    return out


def sfx_gameover():
    out = []
    for k, m in enumerate([72, 71, 70, 67]):
        mix(out, marimba(midi(m), 0.5 if k < 3 else 0.9), k * 0.16, 0.9)
    return reverb(out, 0.25)


# ---------------- music loop ----------------

def music():
    bpm = 112
    beat = 60 / bpm
    bars = 8
    total = bars * 4 * beat
    out = [0.0] * int(total * SR)

    chords = [  # root midi, triad (relative)
        (48, [0, 4, 7]),   # C
        (43, [0, 4, 7]),   # G
        (45, [0, 3, 7]),   # Am
        (41, [0, 4, 7]),   # F
        (48, [0, 4, 7]),   # C
        (43, [0, 4, 7]),   # G
        (41, [0, 4, 7]),   # F
        (43, [0, 4, 7]),   # G
    ]
    # melody: (beat offset within the 32-beat loop, midi, length in beats)
    mel = [
        (0, 76, .5), (.5, 79, .5), (1, 81, .5), (1.5, 79, .5), (2, 76, 1), (3, 72, .5), (3.5, 74, .5),
        (4, 74, .5), (4.5, 76, .5), (5, 79, 1), (6, 74, .5), (6.5, 71, .5), (7, 74, 1),
        (8, 72, .5), (8.5, 76, .5), (9, 81, .5), (9.5, 84, .5), (10, 83, 1), (11, 81, .5), (11.5, 79, .5),
        (12, 77, .5), (12.5, 76, .5), (13, 77, .5), (13.5, 81, .5), (14, 79, 2),
        (16, 76, .5), (16.5, 79, .5), (17, 81, .5), (17.5, 79, .5), (18, 76, 1), (19, 84, .5), (19.5, 83, .5),
        (20, 81, .5), (20.5, 79, .5), (21, 76, .5), (21.5, 74, .5), (22, 79, 2),
        (24, 77, .5), (24.5, 81, .5), (25, 84, 1), (26, 81, .5), (26.5, 77, .5), (27, 76, 1),
        (28, 74, .5), (28.5, 76, .5), (29, 79, .5), (29.5, 83, .5), (30, 86, .75), (31, 83, .5), (31.5, 79, .5),
    ]

    lead = []
    for b, m, ln in mel:
        mix(lead, marimba(midi(m), max(0.35, ln * beat + 0.25), 0.55), b * beat)
        mix(lead, tone(midi(m + 12), 0.18, "sine", 0.002, 0.06), b * beat, 0.08)

    bass = []
    comp = []
    for bar, (root, tri) in enumerate(chords):
        t0 = bar * 4 * beat
        for k, off in enumerate([0, 1.5, 2, 3.5]):
            note = root if k % 2 == 0 else root + 7
            mix(bass, pluck_bass(midi(note - 12 + 12), 0.42, 0.9), t0 + off * beat)
        for off in [0.5, 1.5, 2.5, 3.5]:   # off-beat chord stabs
            for iv in tri:
                mix(comp, marimba(midi(root + 12 + iv), 0.3, 0.18), t0 + off * beat)

    drums = []
    for b in range(bars * 4):
        t = b * beat
        mix(drums, tone(130, 0.22, "sine", 0.001, 0.07, f_end=48), t, 0.85)  # kick
        if b % 2 == 1:
            mix(drums, noise(0.18, 0.06, lp=0.6, hp=1), t, 0.45)               # clap
            mix(drums, tone(220, 0.08, "tri", 0.001, 0.03), t, 0.15)
        for h in (0.5,):
            mix(drums, noise(0.04, 0.012, lp=0.9, hp=1), t + h * beat, 0.22)   # hat
        mix(drums, noise(0.03, 0.008, lp=0.9, hp=1), t, 0.1)

    for src, vol in ((lead, 0.9), (bass, 0.75), (comp, 0.8), (drums, 0.8)):
        for i in range(len(src)):
            j = i % len(out)          # wrap tails for a seamless loop
            out[j] += src[i] * vol
    wet = reverb(out, 0.18)
    n = len(out)
    res = wet[:n]
    for i in range(n, len(wet)):       # wrap reverb tail too
        res[i - n] += wet[i]
    return res


def main():
    d = sys.argv[1]
    for i, p in enumerate((0.95, 1.0, 1.08)):
        write(f"{d}/hop{i}.wav", sfx_hop(p), 0.5)
    write(f"{d}/coin.wav", sfx_coin(), 0.6)
    write(f"{d}/squash.wav", sfx_squash(), 0.8)
    write(f"{d}/splash.wav", sfx_splash(), 0.8)
    write(f"{d}/honk.wav", sfx_honk(), 0.45)
    write(f"{d}/bell.wav", sfx_bell(), 0.45)
    write(f"{d}/train.wav", sfx_train(), 0.8)
    write(f"{d}/eagle.wav", sfx_eagle(), 0.7)
    write(f"{d}/tap.wav", sfx_tap(), 0.45)
    write(f"{d}/bump.wav", sfx_bump(), 0.6)
    write(f"{d}/whoosh.wav", sfx_whoosh(), 0.45)
    write(f"{d}/unlock.wav", sfx_unlock(), 0.7)
    write(f"{d}/record.wav", sfx_record(), 0.6)
    write(f"{d}/cluck.wav", sfx_cluck(), 0.7)
    write(f"{d}/pop.wav", sfx_pop(), 0.5)
    write(f"{d}/crack.wav", sfx_crack(), 0.7)
    write(f"{d}/gift.wav", sfx_gift(), 0.7)
    write(f"{d}/gameover.wav", sfx_gameover(), 0.6)
    write(f"{d}/music.wav", music(), 0.75)


if __name__ == "__main__":
    main()
