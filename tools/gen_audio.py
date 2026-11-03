#!/usr/bin/env python3
"""Synthèse de tous les sons et musiques du jeu (originaux, déterministes).

- SFX : WAV 16 bits mono 44,1 kHz, 3 à 5 variantes par son (`<id>_<n>.wav`), dans audio/sfx/.
- Musique : boucles OGG Vorbis à 3 couches synchronisées (`<piste>_<couche>.ogg`) dans audio/music/ :
  couche 0 = base (rythme, basse, accords), 1 = mélodie, 2 = renfort (cuivres, percussions)
  — les couches 1 et 2 montent avec le Mult (AudioBus.set_intensity).
- Stingers : victoire, défaite, jackpot.

Dépendances : numpy, ffmpeg (encodage OGG). Usage : python3 tools/gen_audio.py [--only sfx|music]
"""
from __future__ import annotations

import argparse
import pathlib
import subprocess
import tempfile
import wave

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent
SFX_DIR = ROOT / "audio" / "sfx"
MUSIC_DIR = ROOT / "audio" / "music"
SR = 44100
RNG = np.random.default_rng(1931)


# --------------------------------------------------------------------------- primitives

def t_axis(dur: float) -> np.ndarray:
    return np.arange(int(dur * SR)) / SR


def midi(m: float) -> float:
    return 440.0 * 2 ** ((m - 69) / 12)


def env_adsr(n: int, a: float, d: float, s: float, r: float, sus_time: float | None = None) -> np.ndarray:
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    sus_n = max(n - a_n - d_n - r_n, 0) if sus_time is None else int(sus_time * SR)
    e = np.concatenate([
        np.linspace(0, 1, max(a_n, 1), endpoint=False),
        np.linspace(1, s, max(d_n, 1), endpoint=False),
        np.full(sus_n, s),
        np.linspace(s, 0, max(r_n, 1)),
    ])
    if len(e) < n:
        e = np.pad(e, (0, n - len(e)))
    return e[:n]


def env_exp(n: int, decay: float, attack: float = 0.002) -> np.ndarray:
    t = np.arange(n) / SR
    e = np.exp(-t / max(decay, 1e-4))
    a = int(attack * SR)
    if a > 0:
        e[:a] *= np.linspace(0, 1, a)
    return e


def sine(f, t, phase=0.0):
    return np.sin(2 * np.pi * f * t + phase)


def saw(f, t):
    return 2 * ((f * t) % 1.0) - 1


def square(f, t, duty=0.5):
    return np.where((f * t) % 1.0 < duty, 1.0, -1.0)


def noise(n):
    return RNG.uniform(-1, 1, n)


def fft_filter(x: np.ndarray, lo: float = 0.0, hi: float = SR / 2, q: float = 1.0) -> np.ndarray:
    """Passe-bande doux par FFT (pentes cosinus)."""
    n = len(x)
    if n < 8:
        return x
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(n, 1 / SR)
    g = np.ones_like(freqs)
    if lo > 0:
        g *= np.clip((freqs / lo) ** (2 * q), 0, 1)
    if hi < SR / 2:
        g *= 1 / (1 + (freqs / hi) ** (4 * q))
    return np.fft.irfft(spec * g, n)


def fm(fc, ratio, index, t, idx_env=None):
    mod = sine(fc * ratio, t) * index * (idx_env if idx_env is not None else 1.0)
    return np.sin(2 * np.pi * fc * t + mod)


def reverb(x: np.ndarray, decay: float = 1.2, mix: float = 0.25) -> np.ndarray:
    n_ir = int(decay * SR)
    ir = noise(n_ir) * np.exp(-np.arange(n_ir) / (decay * SR / 5))
    ir = fft_filter(ir, 200, 6000)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    n = len(x) + n_ir
    wet = np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)[: len(x) + n_ir]
    out = np.concatenate([x, np.zeros(n_ir)]) * (1 - mix) + wet * mix
    return out


def addpad(*xs: np.ndarray) -> np.ndarray:
    """Somme de signaux de longueurs différentes."""
    n = max(len(x) for x in xs)
    return sum(np.pad(x, (0, n - len(x))) for x in xs)


def normalize(x: np.ndarray, peak: float = 0.9) -> np.ndarray:
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def softclip(x: np.ndarray) -> np.ndarray:
    return np.tanh(x)


def write_wav(path: pathlib.Path, x: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def write_ogg(path: pathlib.Path, x: np.ndarray, quality: int = 4) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        tmp = pathlib.Path(td) / "t.wav"
        write_wav(tmp, x)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(tmp), "-c:a", "libvorbis", "-q:a", str(quality), str(path)], check=True)


# --------------------------------------------------------------------------- instruments

def inst_click(f=2200.0, dur=0.03):
    t = t_axis(dur)
    return sine(f, t) * env_exp(len(t), 0.006) + fft_filter(noise(len(t)), 2000, 9000) * env_exp(len(t), 0.003) * 0.5


def inst_clack(f=1800.0, dur=0.09):
    """Jeton qui claque : transitoire + résonance de céramique."""
    t = t_axis(dur)
    body = sine(f, t) * 0.5 + sine(f * 2.76, t) * 0.25 + sine(f * 5.4, t) * 0.1
    return body * env_exp(len(t), 0.02) + fft_filter(noise(len(t)), 1500, 8000) * env_exp(len(t), 0.004)


def inst_coin(f=2600.0, dur=0.35):
    t = t_axis(dur)
    x = sine(f, t) * 0.6 + sine(f * 2.32, t) * 0.3 + sine(f * 4.1, t) * 0.15
    return x * env_exp(len(t), 0.12)


def inst_bell(f=440.0, dur=2.0, index=4.0, ratio=1.4):
    t = t_axis(dur)
    e = env_exp(len(t), dur / 3)
    return fm(f, ratio, index, t, e) * e


def inst_ep(f, dur=0.8, vel=1.0):
    """Piano électrique FM."""
    t = t_axis(dur)
    e = env_exp(len(t), 0.6) * vel
    x = fm(f, 1.0, 2.2, t, env_exp(len(t), 0.15)) * 0.7 + sine(f * 2, t) * 0.1
    return x * e * env_adsr(len(t), 0.003, 0.05, 1, 0.08)


def inst_vibe(f, dur=0.9, vel=1.0):
    t = t_axis(dur)
    trem = 1 + 0.25 * sine(5.5, t)
    x = sine(f, t) + 0.25 * sine(f * 4, t) * env_exp(len(t), 0.08)
    return x * env_exp(len(t), 0.5) * trem * vel


def inst_bass(f, dur=0.4, vel=1.0):
    t = t_axis(dur)
    x = sine(f, t) * 0.8 + fft_filter(saw(f, t), 0, f * 4) * 0.35
    return x * env_adsr(len(t), 0.005, 0.12, 0.6, 0.06) * vel


def inst_pluck(f, dur=0.35, vel=1.0):
    t = t_axis(dur)
    x = fft_filter(saw(f, t), 0, f * 6)
    return x * env_exp(len(t), 0.12) * vel


def inst_pad(f, dur=2.0, vel=1.0):
    t = t_axis(dur)
    x = sum(saw(f * (1 + d), t) for d in (-0.006, 0.0, 0.007)) / 3
    x = fft_filter(x, 0, f * 3)
    return x * env_adsr(len(t), 0.4, 0.3, 0.7, 0.6) * vel


def inst_lead(f, dur=0.5, vel=1.0, kind="clarinet"):
    t = t_axis(dur)
    vib = 1 + 0.004 * sine(5.0, t) * np.clip(t / 0.25, 0, 1)
    if kind == "clarinet":
        x = fft_filter(square(f * vib, t, 0.5), 0, f * 5)
    elif kind == "brass":
        x = fft_filter(saw(f * vib, t), 0, f * (3 + 4 * np.mean(env_exp(len(t), 0.2))))
    else:
        x = sine(f * vib, t) + 0.3 * sine(2 * f * vib, t)
    return x * env_adsr(len(t), 0.02, 0.1, 0.75, 0.08) * vel


def inst_kick(dur=0.35):
    t = t_axis(dur)
    f = 45 + 110 * np.exp(-t / 0.04)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * env_exp(len(t), 0.18)


def inst_brush(dur=0.18):
    n = int(dur * SR)
    return fft_filter(noise(n), 1500, 7000) * env_adsr(n, 0.02, 0.05, 0.3, 0.1) * 0.6


def inst_snare(dur=0.2):
    t = t_axis(dur)
    return (fft_filter(noise(len(t)), 1200, 8000) * 0.7 + sine(190, t) * 0.4) * env_exp(len(t), 0.07)


def inst_hat(dur=0.06, open_=False):
    n = int((0.25 if open_ else dur) * SR)
    return fft_filter(noise(n), 7000, 16000) * env_exp(n, 0.12 if open_ else 0.018) * 0.5


def inst_ride(dur=0.6):
    t = t_axis(dur)
    x = fm(520, 2.71, 6, t) * 0.4 + fft_filter(noise(len(t)), 6000, 14000) * 0.3
    return x * env_exp(len(t), 0.35) * 0.4


def inst_gong(f=80.0, dur=3.0):
    t = t_axis(dur)
    e = env_exp(len(t), 1.0, 0.01)
    x = fm(f, 1.41, 5 * env_exp(len(t), 0.6), t) + 0.5 * fm(f * 2.2, 1.7, 3, t)
    return x * e


def mix_at(buf: np.ndarray, x: np.ndarray, start: int, gain: float = 1.0, wrap: bool = True) -> None:
    end = start + len(x)
    if end <= len(buf):
        buf[start:end] += x * gain
    elif wrap:
        k = len(buf) - start
        buf[start:] += x[:k] * gain
        rest = x[k:]
        buf[: len(rest)] += rest[: len(buf)] * gain
    else:
        buf[start:] += x[: len(buf) - start] * gain


# --------------------------------------------------------------------------- SFX

# --------------------------------------------------------------------------- modèles physiques (1.1)
# Synthèse modale : chaque objet = quelques modes de vibration inharmoniques amortis, excités
# par une courte impulsion de bruit. Générateur aléatoire propre à chaque son (variantes
# reproductibles sans perturber les autres sons).

def modal(rng, freqs, decays, amps, dur, exc_ms=1.5, exc_band=(1500, 9000), exc_gain=0.6):
    t = t_axis(dur)
    x = np.zeros(len(t))
    for f, d, a in zip(freqs, decays, amps):
        f = f * (1 + rng.uniform(-0.015, 0.015))
        x += a * np.sin(2 * np.pi * f * t + rng.uniform(0, 2 * np.pi)) * np.exp(-t / d)
    n_exc = max(int(exc_ms / 1000 * SR), 8)
    exc = fft_filter(rng.standard_normal(n_exc), *exc_band) * np.linspace(1, 0, n_exc) ** 2
    x[:n_exc] += exc * exc_gain
    att = min(int(0.0008 * SR), len(x))
    x[:att] *= np.linspace(0, 1, att)
    rel = min(int(0.012 * SR), len(x) // 3)
    x[-rel:] *= np.linspace(1, 0, rel) ** 2
    return x


def felt_thud(rng, dur=0.05, f=170.0):
    t = t_axis(dur)
    return np.sin(2 * np.pi * f * (1 + rng.uniform(-0.05, 0.05)) * t) * np.exp(-t / 0.012) * 0.5 + \
        fft_filter(rng.standard_normal(len(t)), 80, 900) * np.exp(-t / 0.006) * 0.4


def chip_click(rng, f0=2400.0, dur=0.07, gain=1.0):
    """Jeton en argile composite contre un autre jeton : clic sec, modes aigus inharmoniques."""
    ratios = [1.0, 1.47, 2.09, 2.83, 3.71]
    decays = [0.018, 0.012, 0.009, 0.006, 0.004]
    amps = [0.55, 0.35, 0.25, 0.15, 0.1]
    return modal(rng, [f0 * r for r in ratios], decays, amps, dur, 1.2, (2500, 12000), 0.9) * gain


def chip_place_v(seed):
    """Pose d'un jeton : petit choc mat sur le tapis puis un ou deux clics jeton contre jeton."""
    rng = np.random.default_rng(seed)
    buf = np.zeros(int(0.16 * SR))
    mix_at(buf, felt_thud(rng), 0, 0.8, wrap=False)
    hits = 1 + int(rng.integers(0, 2))
    at = 0.004
    for h in range(hits):
        mix_at(buf, chip_click(rng, rng.uniform(2100, 2900), 0.07, 1.0 / (1 + h * 0.8)), int(at * SR), 1.0, wrap=False)
        at += rng.uniform(0.012, 0.028)
    return buf


def chip_remove_v(seed):
    """Retrait : glissé bref sur le feutre puis clic léger."""
    rng = np.random.default_rng(seed)
    n = int(0.09 * SR)
    slide = fft_filter(rng.standard_normal(n), 1200, 6000) * env_adsr(n, 0.01, 0.02, 0.5, 0.04) * 0.25
    buf = np.zeros(int(0.14 * SR))
    mix_at(buf, slide, 0, 1.0, wrap=False)
    mix_at(buf, chip_click(rng, rng.uniform(2600, 3200), 0.05, 0.6), int(0.05 * SR), 1.0, wrap=False)
    return buf


def chip_stack_v(seed, count, spacing, gain_decay=0.12):
    """Pile de jetons qui s'entrechoquent (gains, balayage)."""
    rng = np.random.default_rng(seed)
    total = int((spacing * count + 0.15) * SR)
    buf = np.zeros(total)
    at = 0.0
    for i in range(count):
        mix_at(buf, chip_click(rng, rng.uniform(2000, 3300), 0.06, 1.0 / (1 + i * gain_decay)), int(at * SR), 1.0, wrap=False)
        at += spacing * rng.uniform(0.6, 1.4)
    return buf


def ball_roll_v(seed, dur=3.6):
    """Bille sur la piste : roulement dont la hauteur et le volume suivent la vitesse,
    souffle de rotation, puis cliquetis sur les frettes quand elle ralentit."""
    rng = np.random.default_rng(seed)
    n = int(dur * SR)
    t = np.arange(n) / SR
    v = np.exp(-t / (dur * 0.55))
    # Roulement : deux bandes de bruit, l'aiguë domine quand la bille va vite.
    low = fft_filter(rng.standard_normal(n), 250, 1100)
    high = fft_filter(rng.standard_normal(n), 1100, 5200)
    roll = low * (0.35 + 0.65 * (1 - v)) + high * v
    rot = np.cumsum(1.2 + 3.0 * v) / SR
    swirl = 0.7 + 0.3 * np.sin(2 * np.pi * rot)
    x = roll * (0.15 + 0.85 * v ** 0.7) * swirl * 0.6
    # Frettes : tic dont la cadence suit la vitesse, audibles surtout en fin de course.
    fret_rate = 37 * (0.4 + 2.0 * v)
    ph = np.cumsum(fret_rate) / SR
    ticks = np.flatnonzero(np.diff(np.floor(ph)) > 0)
    for i in ticks:
        weight = (1 - v[i]) ** 1.5
        if weight < 0.05 or rng.random() > 0.55:
            continue
        click = modal(rng, [3100, 4700, 6900], [0.006, 0.004, 0.003], [0.5, 0.3, 0.2], 0.02, 0.5, (3000, 12000), 0.3)
        mix_at(x, click, int(i), 0.12 * weight, wrap=False)
    return x * env_adsr(n, 0.04, 0.1, 0.95, 0.35)


def ball_bounce_v(seed):
    """Choc sur un losange déflecteur (laiton) : tintement bref + corps de la bille."""
    rng = np.random.default_rng(seed)
    metal = modal(rng, [2750, 4130, 6280, 8900], [0.05, 0.035, 0.02, 0.012], [0.5, 0.35, 0.2, 0.1], 0.12, 0.8, (3000, 14000), 0.5)
    body = modal(rng, [880, 1730], [0.012, 0.008], [0.5, 0.25], 0.05, 1.0, (800, 5000), 0.4)
    buf = np.zeros(int(0.13 * SR))
    mix_at(buf, metal, 0, 0.7, wrap=False)
    mix_at(buf, body, 0, 0.8, wrap=False)
    return buf


def ball_land_v(seed):
    """Arrivée dans une case : rebonds de plus en plus rapprochés puis petit cliquetis."""
    rng = np.random.default_rng(seed)
    buf = np.zeros(int(0.7 * SR))
    at, gap, amp = 0.0, rng.uniform(0.09, 0.12), 1.0
    for _ in range(7):
        hit = modal(rng, [rng.uniform(950, 1150), 1900, 3300], [0.03, 0.018, 0.01], [0.6, 0.3, 0.15], 0.08, 1.2, (1200, 8000), 0.6)
        mix_at(buf, hit, int(at * SR), amp, wrap=False)
        at += gap
        gap *= rng.uniform(0.55, 0.65)
        amp *= 0.62
        if at > 0.6:
            break
    return buf


def wheel_spin_v(seed, dur=1.2):
    """Lancement du cylindre : grondement du roulement et souffle des cases."""
    rng = np.random.default_rng(seed)
    n = int(dur * SR)
    t = np.arange(n) / SR
    rumble = fft_filter(rng.standard_normal(n), 40, 220) * 0.8
    bearing = (np.sin(2 * np.pi * 92 * t) * 0.4 + np.sin(2 * np.pi * 184 * t) * 0.2) * (0.7 + 0.3 * np.sin(2 * np.pi * 6 * t))
    air = fft_filter(rng.standard_normal(n), 500, 2500) * (0.5 + 0.5 * np.sin(2 * np.pi * 14 * t)) * 0.35
    return (rumble + bearing * 0.5 + air) * env_adsr(n, 0.15, 0.1, 0.7, 0.45) * 0.6


def sfx_defs():
    """id -> (fonction(variante) -> signal, nombre de variantes)."""
    def v(k, spread=0.06):
        return 1 + (k - 2) * spread

    d = {}
    d["click"] = (lambda k: inst_click(2000 * v(k)), 4)
    d["hover"] = (lambda k: inst_click(3200 * v(k), 0.02) * 0.4, 3)
    d["card_hover"] = (lambda k: fft_filter(noise(int(0.04 * SR)), 3000, 9000) * env_exp(int(0.04 * SR), 0.01) * 0.3, 3)
    d["card_place"] = (lambda k: inst_clack(900 * v(k), 0.08) * 0.8, 4)
    d["card_flip"] = (lambda k: fft_filter(noise(int(0.12 * SR)), 2000, 8000) * env_adsr(int(0.12 * SR), 0.01, 0.03, 0.3, 0.06) * 0.7, 4)
    d["card_use"] = (lambda k: arpeggio([72, 76, 79, 84], 0.05 * v(k), inst_vibe), 3)
    d["lock"] = (lambda k: inst_clack(3000 * v(k), 0.06), 3)
    d["error"] = (lambda k: fft_filter(square(110 * v(k), t_axis(0.18)), 0, 900) * env_adsr(int(0.18 * SR), 0.005, 0.05, 0.6, 0.05) * 0.5, 3)
    d["panel_open"] = (lambda k: sweep(300, 1200 * v(k), 0.18) * 0.4, 3)
    d["panel_close"] = (lambda k: sweep(1200 * v(k), 300, 0.15) * 0.4, 3)
    d["curtain"] = (lambda k: fft_filter(noise(int(0.35 * SR)), 300, 3000) * env_adsr(int(0.35 * SR), 0.1, 0.1, 0.6, 0.15) * 0.5, 3)
    d["chip_place"] = (lambda k: chip_place_v(100 + k), 5)
    d["chip_remove"] = (lambda k: chip_remove_v(200 + k), 4)
    d["chip_sweep"] = (lambda k: chip_stack_v(300 + k, 9, 0.022), 3)
    d["chip_lose"] = (lambda k: inst_bass(70 * v(k), 0.15) * 0.6, 3)
    d["chips"] = (lambda k: chip_stack_v(400 + k, 3, 0.03), 5)
    d["chips_win"] = (lambda k: addpad(chip_stack_v(500 + k, 6, 0.028) * 0.8, inst_coin(2600 * v(k), 0.3) * 0.25), 5)
    d["mult"] = (lambda k: sweep(400 * v(k), 1400 * v(k), 0.16, "square") * 0.35, 4)
    d["xmult"] = (lambda k: (sweep(200 * v(k), 1800, 0.3, "saw") * 0.35 + inst_kick(0.3) * 0.6), 4)
    d["coins"] = (lambda k: cluster(inst_coin, 8, 0.04, 2500 * v(k)) * 0.6, 4)
    d["coin"] = (lambda k: inst_coin(2700 * v(k)) * 0.6, 5)
    d["coin_loss"] = (lambda k: arpeggio([76, 72, 67], 0.07, inst_vibe) * 0.6, 3)
    d["zero"] = (lambda k: reverb(inst_gong(70 * v(k, 0.03), 2.5), 1.5, 0.3) * 0.9, 3)
    d["shatter"] = (lambda k: (fft_filter(noise(int(0.5 * SR)), 3000, 14000) * env_exp(int(0.5 * SR), 0.12) + cluster(inst_coin, 6, 0.02, 4200)[: int(0.5 * SR)] * 0.4) * 0.7, 3)
    d["glass"] = d["shatter"]
    d["transform"] = (lambda k: arpeggio([79, 83, 86, 91], 0.04, inst_vibe) * 0.6, 3)
    d["clock"] = (lambda k: np.concatenate([inst_clack(2400, 0.06), np.zeros(int(0.12 * SR)), inst_clack(1900, 0.06)]) * 0.7, 3)
    d["count_up"] = (lambda k: cluster(inst_click, 10, 0.035, 2600) * 0.5, 3)
    d["celebrate"] = (lambda k: chord_hit([60, 64, 67, 72], inst_ep, 0.8) * 0.7, 3)
    d["jackpot"] = (lambda k: reverb(np.concatenate([arpeggio([72, 76, 79, 84, 88], 0.06, inst_bell), np.zeros(int(0.2 * SR))]), 1.2, 0.3) * 0.8, 3)
    d["ball_roll"] = (lambda k: ball_roll_v(600 + k, 3.6), 3)
    d["ball_bounce"] = (lambda k: ball_bounce_v(700 + k), 5)
    d["ball_land"] = (lambda k: ball_land_v(800 + k), 4)
    d["ball_launch"] = (lambda k: sweep(200, 900 * v(k), 0.25, "noise") * 0.5, 3)
    d["ball_wood"] = d["ball_land"]
    d["ball_metal"] = (lambda k: inst_coin(1800 * v(k), 0.4) * 0.7, 3)
    d["ball_glass"] = (lambda k: inst_bell(1900 * v(k), 0.6, 2, 3.5) * 0.5, 3)
    d["wheel_spin"] = (lambda k: wheel_spin_v(900 + k, 1.2), 3)
    d["deadline_won"] = (lambda k: reverb(fanfare([60, 64, 67, 72, 76]), 1.0, 0.25) * 0.8, 3)
    d["deadline_failed"] = (lambda k: reverb(trombone_down(), 1.0, 0.25) * 0.7, 3)
    d["buy"] = (lambda k: np.concatenate([inst_coin(2200, 0.1), inst_bell(1760 * v(k), 0.6, 1.5, 2)]) * 0.7, 3)
    d["sell"] = (lambda k: (cluster(inst_coin, 6, 0.03, 2900 * v(k)) * 0.6), 3)
    d["reroll"] = (lambda k: cluster(lambda f, dur=0.05: fft_filter(noise(int(dur * SR)), 2500, 9000) * env_exp(int(dur * SR), 0.01), 7, 0.03, 0) * 0.7, 3)
    d["pack_open"] = (lambda k: np.concatenate([fft_filter(noise(int(0.15 * SR)), 1500, 9000) * env_adsr(int(0.15 * SR), 0.01, 0.05, 0.5, 0.05) * 0.6, arpeggio([84, 88, 91], 0.05, inst_vibe) * 0.5]), 3)
    d["pact"] = (lambda k: reverb(inst_pad(midi(38), 2.0) * 0.6 + inst_bell(midi(62), 2.0, 6, 1.41) * 0.4, 2.0, 0.4) * 0.8, 2)
    d["curse"] = (lambda k: reverb(chord_hit([48, 49, 55], inst_pad, 1.2), 1.5, 0.35) * 0.7, 3)
    d["boss_enter"] = (lambda k: reverb(addpad(chord_hit([36, 43, 48, 51], lambda f, dur=1.2, vel=1.0: inst_lead(f, dur, vel, "brass"), 1.2) * 0.8, inst_gong(55, 1.5) * 0.4), 1.4, 0.3), 2)
    d["stinger_victory"] = (lambda k: reverb(fanfare([60, 64, 67, 72, 76, 79, 84]), 1.6, 0.3) * 0.9, 1)
    d["stinger_defeat"] = (lambda k: reverb(trombone_down(slow=True), 1.6, 0.3) * 0.8, 1)
    d["deadline"] = d["deadline_won"]
    d["breath"] = (lambda k: fft_filter(noise(int(0.6 * SR)), 300, 2500) * env_adsr(int(0.6 * SR), 0.2, 0.1, 0.5, 0.25) * 0.4, 2)
    d["stamp"] = (lambda k: inst_kick(0.2) * 0.6 + np.pad(inst_clack(600, 0.08), (0, int(0.12 * SR))) * 0.6, 3)
    d["paper"] = d["card_flip"]
    d["cloth"] = (lambda k: fft_filter(noise(int(0.2 * SR)), 400, 3000) * env_adsr(int(0.2 * SR), 0.03, 0.05, 0.4, 0.1) * 0.5, 3)
    d["fire"] = (lambda k: fft_filter(noise(int(0.6 * SR)), 200, 2500) * env_adsr(int(0.6 * SR), 0.05, 0.1, 0.6, 0.3) * 0.6, 3)
    d["explosion"] = (lambda k: (inst_kick(0.6) + fft_filter(noise(int(0.6 * SR)), 60, 3000) * env_exp(int(0.6 * SR), 0.2)) * 0.8, 3)
    d["magnet"] = (lambda k: fft_filter(saw(60 * v(k), t_axis(0.4)), 0, 600) * env_adsr(int(0.4 * SR), 0.05, 0.1, 0.6, 0.15) * 0.4, 3)
    d["shimmer"] = d["transform"]
    d["ghost"] = (lambda k: reverb(sweep(600 * v(k), 300, 0.6, "sine") * 0.4, 1.5, 0.5), 3)
    d["jingle"] = (lambda k: cluster(inst_coin, 4, 0.05, 3200 * v(k)) * 0.5, 3)
    d["double"] = (lambda k: np.concatenate([inst_clack(1500, 0.07), inst_clack(1500 * 1.5, 0.07)]), 3)
    d["thorn"] = (lambda k: sweep(1400 * v(k), 2400, 0.08, "saw") * 0.3, 3)
    d["sticky"] = (lambda k: fft_filter(noise(int(0.15 * SR)), 100, 1200) * env_exp(int(0.15 * SR), 0.05) * 0.6, 3)
    d["tick"] = (lambda k: inst_clack(2600 * v(k), 0.05) * 0.6, 3)
    d["choir"] = (lambda k: reverb(chord_hit([64, 67, 71, 76], lambda f, dur=1.0, vel=1.0: inst_lead(f, dur, vel, "sine"), 1.0) * 0.5, 2.0, 0.4), 2)
    d["zap"] = (lambda k: sweep(3000 * v(k), 200, 0.15, "square") * 0.35, 3)
    d["chime"] = (lambda k: inst_bell(1568 * v(k), 0.8, 2, 3.0) * 0.5, 4)
    d["echo"] = (lambda k: np.concatenate([inst_bell(880, 0.25, 2, 2) * a for a in (0.6, 0.35, 0.2)]), 3)
    d["vault"] = (lambda k: np.concatenate([inst_clack(400, 0.1), inst_clack(500, 0.1), inst_bell(660 * v(k), 0.6, 2, 2) * 0.5]), 3)
    d["grow"] = (lambda k: arpeggio([67, 71, 74], 0.05 * v(k), inst_vibe) * 0.5, 3)
    d["void"] = (lambda k: reverb(sweep(200, 60, 0.6, "sine") * 0.6, 1.5, 0.5), 2)
    d["meow"] = (lambda k: sweep(700 * v(k), 450, 0.35, "saw") * env_adsr(int(0.35 * SR), 0.05, 0.1, 0.6, 0.1) * 0.25, 3)
    d["quack"] = (lambda k: fft_filter(square(330 * v(k), t_axis(0.18), 0.3), 300, 2200) * env_adsr(int(0.18 * SR), 0.01, 0.05, 0.6, 0.05) * 0.35, 3)
    d["blade"] = (lambda k: sweep(4000 * v(k), 8000, 0.12, "noise") * 0.4, 3)
    d["clang"] = (lambda k: inst_bell(523 * v(k), 0.6, 5, 1.41) * 0.6, 3)
    d["crack"] = (lambda k: inst_clack(700 * v(k), 0.08), 3)
    d["stone"] = (lambda k: inst_kick(0.25) * 0.5 + np.pad(inst_clack(300, 0.1), (0, int(0.15 * SR))) * 0.5, 3)
    d["dice"] = (lambda k: cluster(inst_clack, 4, 0.06, 1200 * v(k)) * 0.7, 3)
    d["shield"] = d["clang"]
    d["whoosh"] = (lambda k: sweep(300, 2000 * v(k), 0.3, "noise") * 0.5, 3)
    d["sigh"] = (lambda k: fft_filter(noise(int(0.5 * SR)), 300, 1500) * env_adsr(int(0.5 * SR), 0.15, 0.1, 0.5, 0.2) * 0.4, 2)
    d["wink"] = (lambda k: arpeggio([84, 91], 0.05, inst_vibe) * 0.5, 3)
    d["lose_soft"] = d["chip_lose"]
    for who, base in (("lea", 72), ("vic", 62), ("odile", 76), ("barnabe", 57), ("marthe", 69), ("ghost", 81), ("house", 45), ("boss", 50), ("npc", 66)):
        d["blip_" + who] = ((lambda b: (lambda k: blip(b + k)))(base), 5)
    # 1.4 — machine à sous du jackpot.
    d["slot_lever"] = (lambda k: np.concatenate([cluster(inst_clack, 6, 0.035, 1400 * v(k)) * 0.7, sweep(500, 180, 0.18, "saw") * 0.3]), 3)
    d["slot_spin"] = (lambda k: addpad(cluster(inst_click, 28, 0.04, 1700 * v(k)) * 0.5, fft_filter(noise(int(1.2 * SR)), 300, 2400) * 0.12), 3)
    d["slot_stop"] = (lambda k: inst_kick(0.25) * 0.7 + np.pad(inst_clack(700 * v(k), 0.1), (0, int(0.15 * SR))) * 0.7, 4)
    d["slot_tease"] = (lambda k: sweep(300 * v(k), 1600, 0.9, "square") * env_adsr(int(0.9 * SR), 0.05, 0.2, 0.7, 0.2) * 0.25, 2)
    d["slot_win"] = (lambda k: reverb(addpad(arpeggio([76, 79, 84, 88], 0.07, inst_bell) * 0.7, cluster(inst_coin, 10, 0.05, 2800 * v(k)) * 0.5), 1.0, 0.25), 3)
    d["slot_big"] = (lambda k: reverb(addpad(fanfare([60, 64, 67, 72, 76, 79, 84]) * 0.7, cluster(inst_coin, 30, 0.04, 2600 * v(k)) * 0.5, np.pad(cluster(lambda f, dur=0.6: inst_bell(f, dur, 3, 1.4), 8, 0.12, 1320), (int(0.3 * SR), 0)) * 0.4), 1.4, 0.3), 2)
    d["slot_ring"] = (lambda k: cluster(lambda f, dur=0.08: inst_bell(f, dur, 4, 3.0), 16, 0.045, 2100 * v(k)) * 0.5, 2)
    # 1.4 — objets du décor (casino abandonné).
    d["decor_glass"] = (lambda k: addpad(inst_bell(2900 * v(k), 0.5, 1.5, 2.76) * 0.5, inst_bell(4100 * v(k), 0.35, 1.2, 2.2) * 0.25), 4)
    d["decor_ice"] = (lambda k: cluster(lambda f, dur=0.06: inst_bell(f, dur, 1.0, 3.1), 4, 0.05, 3600 * v(k)) * 0.4, 3)
    d["decor_bottle"] = (lambda k: addpad(inst_bell(420 * v(k), 0.5, 1.0, 2.0) * 0.4, inst_clack(900 * v(k), 0.06) * 0.6), 3)
    d["decor_switch"] = (lambda k: addpad(inst_clack(1500 * v(k), 0.05), np.pad(fft_filter(saw(120, t_axis(0.25)), 0, 800) * env_exp(int(0.25 * SR), 0.1) * 0.25, (int(0.05 * SR), 0))), 3)
    d["decor_neon"] = (lambda k: fft_filter(square(120 * v(k), t_axis(0.5), 0.5), 0, 1200) * env_adsr(int(0.5 * SR), 0.02, 0.1, 0.6, 0.2) * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 9 * t_axis(0.5)))) * 0.25, 3)
    d["decor_phone"] = (lambda k: np.concatenate([cluster(lambda f, dur=0.04: inst_bell(f, dur, 3.0, 1.0), 20, 0.03, 1400 * v(k)), np.zeros(int(0.25 * SR)), cluster(lambda f, dur=0.04: inst_bell(f, dur, 3.0, 1.0), 20, 0.03, 1400 * v(k))]) * 0.45, 2)
    d["decor_squeak"] = (lambda k: sweep(2400 * v(k), 3600, 0.12, "sine") * env_adsr(int(0.12 * SR), 0.01, 0.03, 0.6, 0.04) * 0.3, 3)
    d["decor_puff"] = (lambda k: fft_filter(noise(int(0.7 * SR)), 200, 1800) * env_adsr(int(0.7 * SR), 0.1, 0.2, 0.4, 0.3) * 0.45, 3)
    d["decor_topple"] = (lambda k: chip_stack_v(1100 + k, 12, 0.03), 3)
    d["decor_pluck"] = (lambda k: inst_pluck(midi(76 + k), 0.4) * 0.5, 3)
    d["decor_creak"] = (lambda k: fft_filter(saw(90 * v(k), t_axis(0.6)) * (1 + 0.5 * np.sin(2 * np.pi * 7 * t_axis(0.6))), 200, 1600) * env_adsr(int(0.6 * SR), 0.05, 0.1, 0.6, 0.2) * 0.25, 3)
    # 1.5 — épreuves du lancer : percussions des couloirs du jeu de rythme et morceaux dédiés.
    d["qte_kick"] = (lambda k: addpad(inst_kick(0.3), inst_click(1800 * v(k), 0.02) * 0.3), 3)
    d["qte_snare"] = (lambda k: inst_snare(0.18) * (1.0 + 0.05 * k), 3)
    d["qte_hat"] = (lambda k: addpad(inst_hat(0.08) * 1.6, inst_coin(5200 * v(k), 0.08) * 0.2), 3)
    d["qte_clap"] = (lambda k: cluster(lambda f, dur=0.05: fft_filter(noise(int(dur * SR)), 900, 5000) * env_exp(int(dur * SR), 0.012), 3, 0.011, 0) * 0.9, 3)
    # 1.5 — cinématique d'intro.
    d["thunder"] = (lambda k: reverb(addpad(inst_kick(1.2) * 0.5, fft_filter(noise(int(2.6 * SR)), 30, 900) * env_adsr(int(2.6 * SR), 0.02, 0.4, 0.5, 1.6)), 2.0, 0.4) * 0.9, 2)
    d["steps"] = (lambda k: np.concatenate([np.pad(addpad(inst_kick(0.12) * 0.5, inst_clack(300 * v(k), 0.06) * 0.5), (0, int(0.32 * SR))) for _ in range(4)]) * 0.7, 3)
    d["door_boom"] = (lambda k: reverb(addpad(inst_gong(48, 3.0) * 0.6, inst_kick(0.8), fft_filter(saw(55, t_axis(2.0)), 0, 400) * env_adsr(int(2.0 * SR), 0.3, 0.4, 0.5, 0.8) * 0.4), 2.5, 0.45), 1)
    d["heartbeat"] = (lambda k: np.concatenate([inst_kick(0.18) * 0.8, np.zeros(int(0.12 * SR)), inst_kick(0.2) * 0.6, np.zeros(int(0.5 * SR))]), 2)
    # 1.7 — la Pluie du Grand Lustre.
    d["chandelier"] = (lambda k: reverb(cluster(lambda f, dur=0.5: inst_bell(f, dur, 1.2, 3.1), 7, 0.045, 3400 * v(k)) * 0.45, 1.2, 0.35), 3)
    d["gust"] = (lambda k: fft_filter(noise(int(1.0 * SR)), 150, 1800) * env_adsr(int(1.0 * SR), 0.25, 0.2, 0.6, 0.45) * 0.55, 2)
    for style in ("jazz", "funk", "mambo"):
        d["groove_" + style] = ((lambda st: (lambda k: groove(st)))(style), 1)
    return d


GROOVE_BPM = {"jazz": 112, "funk": 100, "mambo": 120}


def groove(style: str, bars: int = 4) -> np.ndarray:
    """Morceau du jeu de rythme : une mesure de décompte (baguettes), `bars` mesures de groove,
    une mesure de fin. Tempo = GROOVE_BPM (doit correspondre à balance.json → throw_trials.rhythm)."""
    beat = 60.0 / GROOVE_BPM[style]
    total = int((bars + 2) * 4 * beat * SR)
    buf = np.zeros(total)

    def at(bar, b):
        return int(((bar * 4) + b) * beat * SR)

    for b in range(4):
        mix_at(buf, inst_clack(2400 if b == 0 else 1900, 0.06) * 0.6, at(0, b), wrap=False)
    progs = {
        "jazz": [(50, "m7"), (55, "7"), (48, "maj7"), (45, "7")],
        "funk": [(45, "m7"), (45, "m7"), (50, "7"), (52, "7")],
        "mambo": [(48, "maj7"), (53, "maj7"), (55, "7"), (48, "maj7")],
    }[style]
    rng = np.random.default_rng({"jazz": 11, "funk": 12, "mambo": 13}[style])
    for i in range(bars):
        bar = i + 1
        root, q = progs[i % len(progs)]
        tones = chord_tones(root + 12, q)
        if style == "jazz":
            for b in range(4):
                mix_at(buf, inst_ride(0.5) * 0.7, at(bar, b), wrap=False)
                if b % 2 == 1:
                    mix_at(buf, inst_ride(0.3) * 0.4, at(bar, b + 0.66), wrap=False)
                    mix_at(buf, inst_brush(0.15), at(bar, b), wrap=False)
                walk = [root, root + 4, root + 7, root + 9][b] if b < 3 else root + 11
                mix_at(buf, inst_bass(midi(walk - 12), beat * 0.9) * 0.9, at(bar, b), wrap=False)
            for b in (0, 1.66, 2.66):
                mix_at(buf, chord_hit(tones, inst_ep, beat * 0.8) * 0.35, at(bar, b), wrap=False)
            for b in (0.66, 2, 3.33):
                mix_at(buf, inst_vibe(midi(tones[rng.integers(0, 4)] + 12), 0.4) * 0.3, at(bar, b), wrap=False)
        elif style == "funk":
            for e in range(8):
                mix_at(buf, inst_hat(0.05) * (1.0 if e % 2 == 0 else 0.6), at(bar, e * 0.5), wrap=False)
            for b in (0, 1.5, 2.5):
                mix_at(buf, inst_kick(0.3) * 0.9, at(bar, b), wrap=False)
            for b in (1, 3):
                mix_at(buf, inst_snare(0.2) * 0.8, at(bar, b), wrap=False)
            for b, n in ((0, 0), (0.75, 12), (1.5, 7), (2, 0), (2.75, 10), (3.5, 12)):
                mix_at(buf, inst_bass(midi(root - 12 + n), beat * 0.4) * 0.9, at(bar, b), wrap=False)
            for b in (0.5, 1.25, 2.5, 3.25):
                mix_at(buf, chord_hit(tones, inst_pluck, beat * 0.3) * 0.35, at(bar, b), wrap=False)
            mix_at(buf, inst_lead(midi(tones[1] + 12), beat * 1.5, 0.5, "brass") * 0.25, at(bar, 3), wrap=False)
        else:
            for b in (0, 1.5, 2, 3.5):
                mix_at(buf, inst_clack(900, 0.08) * 0.5, at(bar, b), wrap=False)
            for b in (0.5, 1.0, 2.5, 3.0):
                mix_at(buf, inst_clack(1500, 0.05) * 0.4, at(bar, b), wrap=False)
            for e in range(8):
                mix_at(buf, inst_hat(0.04) * 0.5, at(bar, e * 0.5), wrap=False)
            for b, n in ((0, 0), (1.5, 7), (2, 7), (3.5, 0)):
                mix_at(buf, inst_bass(midi(root - 12 + n), beat * 0.45) * 0.9, at(bar, b), wrap=False)
            for b in (0.5, 1.0, 2.0, 2.5, 3.5):
                mix_at(buf, chord_hit(tones, inst_ep, beat * 0.25) * 0.3, at(bar, b), wrap=False)
            for b, n in ((0, 0), (0.5, 2), (1, 4), (2, 7), (3, 4)):
                mix_at(buf, inst_lead(midi(tones[0] + 12 + n), beat * 0.45, 0.6, "brass") * 0.22, at(bar, b), wrap=False)
    end = bars + 1
    mix_at(buf, chord_hit(chord_tones(progs[0][0] + 12, progs[0][1]), inst_ep, beat * 3) * 0.5, at(end, 0), wrap=False)
    mix_at(buf, inst_kick(0.4), at(end, 0), wrap=False)
    mix_at(buf, inst_ride(1.0) * 0.6, at(end, 0), wrap=False)
    return reverb(buf, 1.0, 0.15)[:total]


def sweep(f0, f1, dur, wave_="sine"):
    t = t_axis(dur)
    f = np.geomspace(max(f0, 1), max(f1, 1), len(t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    if wave_ == "square":
        x = np.sign(np.sin(ph))
    elif wave_ == "saw":
        x = 2 * ((ph / (2 * np.pi)) % 1) - 1
    elif wave_ == "noise":
        x = fft_filter(noise(len(t)), 300, 6000) * (0.5 + 0.5 * np.sin(ph))
    else:
        x = np.sin(ph)
    return x * env_adsr(len(t), 0.01, 0.05, 0.7, dur * 0.3)


def cluster(fn, count, gap, f):
    parts = []
    total = int((gap * count + 0.4) * SR)
    buf = np.zeros(total)
    for i in range(count):
        ff = f * (1 + RNG.uniform(-0.08, 0.08)) if f else 0
        x = fn(ff) if f else fn(0)
        mix_at(buf, x, int(i * gap * SR), 1.0 / (1 + i * 0.15), wrap=False)
    return buf


def arpeggio(notes, gap, fn):
    total = int((gap * len(notes) + 0.9) * SR)
    buf = np.zeros(total)
    for i, m in enumerate(notes):
        mix_at(buf, fn(midi(m)), int(i * gap * SR), 0.6, wrap=False)
    return buf


def chord_hit(notes, fn, dur):
    buf = np.zeros(int((dur + 0.2) * SR))
    for m in notes:
        mix_at(buf, fn(midi(m), dur), 0, 1.0 / len(notes), wrap=False)
    return buf


def fanfare(notes):
    buf = np.zeros(int(2.4 * SR))
    for i, m in enumerate(notes):
        mix_at(buf, inst_lead(midi(m), 0.5 if i < len(notes) - 1 else 1.4, 0.8, "brass"), int(i * 0.09 * SR), 0.5, wrap=False)
    mix_at(buf, chord_hit([notes[0] - 12, notes[0], notes[2]], inst_ep, 1.6), int(len(notes) * 0.09 * SR), 0.6, wrap=False)
    return buf


def trombone_down(slow=False):
    step = 0.45 if slow else 0.3
    buf = np.zeros(int((step * 4 + 1.0) * SR))
    for i, m in enumerate([55, 54, 53, 52]):
        dur = step if i < 3 else 1.0
        t = t_axis(dur)
        f = midi(m) * (1 + (0.02 * np.sin(2 * np.pi * 6 * t) if i == 3 else 0))
        x = fft_filter(saw(f, t), 0, 900) * env_adsr(len(t), 0.03, 0.05, 0.8, 0.1)
        mix_at(buf, x, int(i * step * SR), 0.5, wrap=False)
    return buf


def blip(m):
    t = t_axis(0.05)
    return square(midi(m), t, 0.25) * env_adsr(len(t), 0.002, 0.01, 0.6, 0.02) * 0.25


def gen_sfx() -> int:
    SFX_DIR.mkdir(parents=True, exist_ok=True)
    count = 0
    for sid, (fn, n) in sfx_defs().items():
        for k in range(n):
            x = fn(k)
            x = softclip(normalize(x, 0.95) * 1.1) * 0.85
            fade = min(int(0.005 * SR), len(x) // 4)
            if fade > 0:
                x[-fade:] *= np.linspace(1, 0, fade)
            write_wav(SFX_DIR / f"{sid}_{k + 1}.wav", x)
            count += 1
    amb = ambience(24.0)
    write_wav(SFX_DIR / "ambience_casino.wav", amb)
    write_wav(SFX_DIR / "ambience_rain.wav", rain_loop(16.0))
    return count + 2


def rain_loop(dur):
    """Pluie sur le pavé : souffle large + gouttes, bouclable."""
    n = int(dur * SR)
    buf = fft_filter(noise(n), 400, 9000) * 0.35 + fft_filter(noise(n), 80, 400) * 0.25
    for _ in range(900):
        pos = int(RNG.uniform(0, dur - 0.1) * SR)
        mix_at(buf, inst_click(RNG.uniform(2500, 6000), 0.015) * RNG.uniform(0.02, 0.08), pos)
    edge = int(0.5 * SR)
    buf[:edge] = buf[:edge] * np.linspace(0, 1, edge) + buf[-edge:] * np.linspace(1, 0, edge)
    return normalize(buf[: n - edge], 0.45)


def ambience(dur):
    """Brouhaha de salle : murmure filtré + tintements lointains, bouclable."""
    n = int(dur * SR)
    murmur = fft_filter(noise(n), 150, 900) * 0.25
    t = np.arange(n) / SR
    murmur *= 0.7 + 0.3 * np.sin(2 * np.pi * 0.11 * t) * np.sin(2 * np.pi * 0.07 * t)
    buf = murmur
    for _ in range(40):
        pos = int(RNG.uniform(0, dur - 0.5) * SR)
        mix_at(buf, inst_coin(RNG.uniform(2000, 3500), 0.3) * 0.08, pos)
    for _ in range(12):
        pos = int(RNG.uniform(0, dur - 0.5) * SR)
        mix_at(buf, cluster(inst_clack, 3, 0.04, RNG.uniform(1400, 2000))[: int(0.4 * SR)] * 0.08, pos)
    buf = reverb(buf, 1.2, 0.4)[:n]
    edge = int(0.5 * SR)
    buf[:edge] = buf[:edge] * np.linspace(0, 1, edge) + buf[-edge:] * np.linspace(1, 0, edge)
    return normalize(buf[: n - edge], 0.5)


# --------------------------------------------------------------------------- musique

class Track:
    """Une boucle de `bars` mesures à `bpm`, 3 couches synchronisées."""

    def __init__(self, bpm: float, bars: int, beats: int = 4, swing: float = 0.0):
        self.bpm, self.bars, self.beats, self.swing = bpm, bars, beats, swing
        self.beat = 60.0 / bpm
        self.length = int(bars * beats * self.beat * SR)
        self.layers = [np.zeros(self.length) for _ in range(3)]

    def pos(self, bar: int, beat: float) -> int:
        b = beat
        frac = b % 1.0
        if self.swing and abs(frac - 0.5) < 1e-6:
            b += self.swing * 0.5
        return int(((bar * self.beats) + b) * self.beat * SR)

    def add(self, layer: int, x: np.ndarray, bar: int, beat: float, gain: float = 1.0) -> None:
        mix_at(self.layers[layer], x, self.pos(bar, beat) % self.length, gain)

    def render(self, rev: float = 0.25) -> list[np.ndarray]:
        out = []
        peak = 1e-9
        processed = []
        for lay in self.layers:
            wet = reverb(lay, 1.4, rev)
            looped = wet[: self.length].copy()
            tail = wet[self.length:]
            looped[: len(tail)] += tail[: self.length]
            processed.append(looped)
            peak = max(peak, np.max(np.abs(looped)))
        total_peak = np.max(np.abs(sum(processed))) + 1e-9
        g = 0.85 / max(total_peak, peak)
        for p in processed:
            out.append(softclip(p * g * 1.2) * 0.9)
        return out


SCALES = {"major": [0, 2, 4, 5, 7, 9, 11], "minor": [0, 2, 3, 5, 7, 8, 10], "dorian": [0, 2, 3, 5, 7, 9, 10], "phrygian": [0, 1, 3, 5, 7, 8, 10], "harmonic": [0, 2, 3, 5, 7, 8, 11]}


def chord_tones(root: int, quality: str) -> list[int]:
    q = {"maj7": [0, 4, 7, 11], "m7": [0, 3, 7, 10], "7": [0, 4, 7, 10], "m": [0, 3, 7], "dim": [0, 3, 6, 9], "m7b5": [0, 3, 6, 10], "sus": [0, 5, 7, 10]}[quality]
    return [root + x for x in q]


def melody(rng, scale_root: int, scale: list[int], bars: int, beats: int, density: float, register: int = 72) -> list[tuple]:
    notes = []
    degree = 0
    for bar in range(bars):
        b = 0.0
        while b < beats:
            dur = rng.choice([0.5, 0.5, 1.0, 1.0, 1.5, 2.0])
            if rng.random() < density:
                degree += int(rng.choice([-2, -1, -1, 1, 1, 2, 0, 3, -3]))
                degree = max(-3, min(10, degree))
                octave, idx = divmod(degree, len(scale))
                m = register + scale_root % 12 + scale[idx] + 12 * octave
                notes.append((bar, b, min(dur, beats - b), m))
            b += dur
    return notes


def build_track(name: str) -> list[np.ndarray]:
    rng = np.random.default_rng(abs(hash(name)) % (2 ** 32))
    cfg = {
        "menu": dict(bpm=78, bars=8, swing=0.33, key=53, scale="major", prog=[(2, "m7"), (7, "7"), (0, "maj7"), (9, "m7")], lead="vibe", drums="brush", dens=0.45),
        "act1": dict(bpm=104, bars=8, swing=0.33, key=53, scale="major", prog=[(0, "maj7"), (9, "m7"), (2, "m7"), (7, "7")], lead="vibe", drums="brush", dens=0.6),
        "act2": dict(bpm=112, bars=8, swing=0.0, key=50, scale="harmonic", prog=[(0, "m"), (5, "m"), (7, "7"), (0, "m")], lead="clarinet", drums="habanera", dens=0.6),
        "act3": dict(bpm=72, bars=8, swing=0.0, key=48, scale="phrygian", prog=[(0, "m"), (1, "maj7"), (0, "m"), (8, "maj7")], lead="sine", drums="sparse", dens=0.35),
        "boss": dict(bpm=138, bars=8, swing=0.0, key=45, scale="harmonic", prog=[(0, "m"), (0, "m"), (8, "maj7"), (7, "7")], lead="brass", drums="drive", dens=0.7),
        "intro": dict(bpm=66, bars=8, swing=0.0, key=50, scale="harmonic", prog=[(0, "m"), (8, "maj7"), (5, "m"), (7, "7")], lead="clarinet", drums="sparse", dens=0.3),
        "shop": dict(bpm=120, bars=8, swing=0.25, key=55, scale="major", prog=[(0, "maj7"), (4, "m7"), (5, "maj7"), (7, "7")], lead="vibe", drums="brush", dens=0.55),
    }[name]
    tr = Track(cfg["bpm"], cfg["bars"], 4, cfg["swing"])
    key = cfg["key"]
    scale = SCALES[cfg["scale"]]
    prog = cfg["prog"]
    for bar in range(tr.bars):
        root, q = prog[bar % len(prog)]
        tones = chord_tones(key + root, q)
        # Couche 0 : basse + accords + batterie
        if cfg["drums"] == "habanera":
            for b, step in ((0, 0), (1.5, 2), (2, 1), (3, 2)):
                tr.add(0, inst_bass(midi(tones[step % len(tones)] - 24), 0.45), bar, b, 0.9)
        elif cfg["drums"] == "drive":
            for b in np.arange(0, 4, 0.5):
                tr.add(0, inst_bass(midi(tones[0] - 24), 0.22), bar, float(b), 0.8)
        else:
            for b in range(4):
                walk = tones[(b * 2) % len(tones)] - 24 + (1 if b == 3 else 0)
                tr.add(0, inst_bass(midi(walk), tr.beat * 0.95), bar, b, 0.8 if cfg["drums"] != "sparse" or b % 2 == 0 else 0.0)
        comp = inst_pad if cfg["drums"] in ("sparse",) else inst_ep
        for b in ((0, 2.5) if cfg["drums"] != "sparse" else (0,)):
            for m in tones:
                tr.add(0, comp(midi(m), tr.beat * (2 if cfg["drums"] != "sparse" else 4)), bar, b, 0.22)
        if cfg["drums"] == "brush":
            for b in range(4):
                tr.add(0, inst_ride(), bar, b, 0.35)
                tr.add(0, inst_ride(0.3), bar, b + 0.5, 0.2)
                if b in (1, 3):
                    tr.add(0, inst_brush(), bar, b, 0.5)
            tr.add(0, inst_kick(), bar, 0, 0.35)
        elif cfg["drums"] == "habanera":
            tr.add(0, inst_kick(), bar, 0, 0.6)
            tr.add(0, inst_kick(), bar, 1.5, 0.4)
            tr.add(0, inst_snare(), bar, 2, 0.35)
            for b in np.arange(0, 4, 0.5):
                tr.add(0, inst_hat(), bar, float(b), 0.3)
        elif cfg["drums"] == "drive":
            for b in range(4):
                tr.add(0, inst_kick(), bar, b, 0.7)
                tr.add(0, inst_hat(), bar, b + 0.5, 0.4)
                if b in (1, 3):
                    tr.add(0, inst_snare(), bar, b, 0.55)
        else:
            tr.add(0, inst_gong(midi(key - 24), 3.0), bar, 0, 0.12 if bar % 2 == 0 else 0.0)
            tr.add(0, inst_hat(open_=True), bar, 3.5, 0.2)
        # Couche 2 : renfort (cuivres / percussions en plus)
        if bar % 2 == 1 or cfg["drums"] == "drive":
            stab = [lambda f, d: inst_lead(f, d, 0.8, "brass")][0]
            for m in tones[:3]:
                tr.add(2, stab(midi(m), 0.35), bar, 3.5 if cfg["drums"] != "drive" else 0, 0.25)
        for b in np.arange(0, 4, 0.25 if cfg["drums"] == "drive" else 0.5):
            tr.add(2, inst_hat(), bar, float(b), 0.18)
        tr.add(2, inst_snare(), bar, 3.75, 0.25)
    # Couche 1 : mélodie
    for bar, b, dur, m in melody(rng, key, scale, tr.bars, 4, cfg["dens"]):
        if cfg["lead"] == "vibe":
            x = inst_vibe(midi(m), dur * tr.beat + 0.3)
        else:
            x = inst_lead(midi(m), dur * tr.beat * 0.95, 0.8, cfg["lead"])
        tr.add(1, x, bar, b, 0.45)
    return tr.render(0.28 if name != "act3" else 0.45)


def gen_music() -> int:
    MUSIC_DIR.mkdir(parents=True, exist_ok=True)
    count = 0
    for name in ("menu", "act1", "act2", "act3", "boss", "shop", "intro"):
        for i, layer in enumerate(build_track(name)):
            write_ogg(MUSIC_DIR / f"{name}_{i}.ogg", layer)
            count += 1
    return count


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", choices=["sfx", "music"], default=None)
    args = ap.parse_args()
    if args.only in (None, "sfx"):
        print(f"SFX : {gen_sfx()} fichiers")
    if args.only in (None, "music"):
        print(f"Musique : {gen_music()} couches")


if __name__ == "__main__":
    main()
