"""Génère les petits sons de l'application (assets/sounds/*.wav) — synthèse, aucun droit d'auteur."""
import math, os, random, struct, wave

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'sounds')
os.makedirs(OUT, exist_ok=True)
SR = 22050


def write(name, samples):
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', max(-32767, min(32767, int(s * 32767)))) for s in samples))


def tone(f0, f1, dur, vol=0.5, attack=0.004, noise=0.0):
    n = int(SR * dur)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * t
        ph += 2 * math.pi * f / SR
        env = min(1.0, i / (attack * SR)) * (1 - t) ** 2
        out.append((math.sin(ph) * (1 - noise) + (random.random() * 2 - 1) * noise) * env * vol)
    return out


def seq(*parts, gap=0.0):
    out = []
    for p in parts:
        out += p + [0.0] * int(SR * gap)
    return out


random.seed(7)
write('click', tone(1400, 900, 0.045, 0.45, noise=0.25))
write('tick', tone(1000, 1000, 0.03, 0.35))
write('pop', tone(260, 620, 0.09, 0.5))
write('whoosh', tone(300, 1200, 0.16, 0.25, attack=0.04, noise=0.8))
write('success', seq(tone(660, 660, 0.09, 0.45), tone(880, 880, 0.16, 0.45), gap=0.01))
write('mic_start', seq(tone(520, 700, 0.08, 0.45), tone(700, 980, 0.12, 0.45)))
write('mic_stop', seq(tone(900, 700, 0.08, 0.45), tone(700, 480, 0.12, 0.45)))
print('sons générés dans', os.path.abspath(OUT))
