#!/usr/bin/env python3
"""Mixage objectif des effets sonores : mesure le volume perçu de chaque son (loudness
« momentanée » maximale, fenêtre de 400 ms, pondération K simplifiée, cf. ITU-R BS.1770)
et calcule le décalage de volume (dB) qui amène chaque famille de sons à sa cible.

Écrit audio/sfx_mix.json (lu par AudioBus.play). Les sons repérés « à revoir » lors de
l'écoute en jeu (Options > Audio > Écouter les sons) sont listés à la fin.

Usage : python3 tools/audio_mix.py [--check]   (--check : n'écrit rien, code 1 si un son
        s'écarte de plus de TOLERANCE_DB de sa cible)
"""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import sys
import wave
from collections import defaultdict

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent
SFX = ROOT / "audio" / "sfx"
MIX = ROOT / "audio" / "sfx_mix.json"
USER_DIR = pathlib.Path(os.environ.get("XDG_DATA_HOME", pathlib.Path.home() / ".local" / "share")) / "godot" / "app_userdata" / "La Maison Gagne"
REVIEW = USER_DIR / "audio_review.json"
SR = 44100
WINDOW_S = 0.4
TOLERANCE_DB = 1.5
OFFSET_RANGE = (-18.0, 8.0)

# Cible de loudness momentanée (LUFS) par famille, avant volumes du joueur. Repère : la
# musique est à ≈ −20 LUFS intégrés (−24 après le volume « musique » par défaut). L'interface
# reste sous la musique, le jeu à son niveau, les grands moments au-dessus.
TARGETS = {
    "ui": -29.0,
    "voice": -26.0,
    "table": -23.0,
    "feedback": -21.0,
    "moment": -17.0,
}
FAMILY = {
    "ui": ["click", "hover", "card_hover", "panel_open", "panel_close", "error", "lock", "tick", "curtain", "card_flip", "paper", "cloth", "card_place"],
    "voice": ["blip_"],
    "table": ["chip_place", "chip_remove", "chip_sweep", "chip_lose", "ball_", "wheel_spin", "lose_soft", "reroll", "dice"],
    "moment": ["zero", "jackpot", "deadline", "stinger_", "boss_enter", "pact", "curse", "celebrate", "explosion", "shatter", "glass"],
}


def family_of(sid: str) -> str:
    for fam, keys in FAMILY.items():
        for k in keys:
            if sid == k or (k.endswith("_") and sid.startswith(k)):
                return fam
    return "feedback"


def read(path: pathlib.Path) -> np.ndarray:
    with wave.open(str(path)) as w:
        x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64) / 32768.0
        if w.getnchannels() == 2:
            x = x.reshape(-1, 2).mean(axis=1)
    return x


def k_weight(x: np.ndarray) -> np.ndarray:
    """Pondération K approchée dans le domaine fréquentiel : passe-haut ~60 Hz, +4 dB au-delà de 1,5 kHz."""
    n = len(x)
    spec = np.fft.rfft(x, n * 2)
    f = np.fft.rfftfreq(n * 2, 1 / SR)
    hp = 1 / np.sqrt(1 + (60 / np.maximum(f, 1)) ** 4)
    shelf = 1 + (10 ** (4 / 20) - 1) / (1 + (1500 / np.maximum(f, 1)) ** 2)
    return np.fft.irfft(spec * hp * shelf)[:n]


def momentary_max(x: np.ndarray) -> float:
    y = k_weight(x) ** 2
    win = int(WINDOW_S * SR)
    if len(y) < win:
        y = np.pad(y, (0, win - len(y)))
    c = np.concatenate([[0.0], np.cumsum(y)])
    hop = max(win // 4, 1)
    energies = [(c[i + win] - c[i]) / win for i in range(0, len(y) - win + 1, hop)]
    e = max(energies) if energies else 1e-12
    return -0.691 + 10 * np.log10(max(e, 1e-12))


def measure() -> dict[str, float]:
    by_id: dict[str, list[float]] = defaultdict(list)
    for p in sorted(SFX.glob("*.wav")):
        stem = p.stem
        sid = stem.rsplit("_", 1)[0] if stem.rsplit("_", 1)[-1].isdigit() else stem
        if sid.startswith("ambience"):
            continue
        by_id[sid].append(momentary_max(read(p)))
    return {sid: float(np.median(v)) for sid, v in by_id.items()}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    loud = measure()
    old = json.loads(MIX.read_text(encoding="utf-8")) if MIX.exists() else {}
    mix: dict = {"_doc": "Décalage de volume (dB) par effet sonore, appliqué par AudioBus.play. Calculé par tools/audio_mix.py (loudness par famille) ; ne pas éditer à la main."}
    off_target = []
    for sid in sorted(loud):
        fam = family_of(sid)
        offset = float(np.clip(TARGETS[fam] - loud[sid], *OFFSET_RANGE))
        mix[sid] = round(offset, 1)
        current = float(old.get(sid, 0.0))
        if abs(loud[sid] + current - TARGETS[fam]) > TOLERANCE_DB:
            off_target.append((sid, fam, loud[sid] + current, TARGETS[fam]))
    if a.check:
        for sid, fam, got, want in off_target:
            print(f"HORS CIBLE {sid} ({fam}) : {got:.1f} LUFS au lieu de {want:.1f}")
        print(f"Mixage : {len(loud)} sons, {len(off_target)} hors cible")
        return 1 if off_target else 0
    MIX.write_text(json.dumps(mix, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    fams = defaultdict(int)
    for sid in loud:
        fams[family_of(sid)] += 1
    print(f"Mixage écrit : {len(loud)} sons ({', '.join(f'{k} {v}' for k, v in sorted(fams.items()))})")
    if REVIEW.exists():
        review = json.loads(REVIEW.read_text(encoding="utf-8"))
        bad = sorted(k for k, v in review.items() if v == "bad")
        if bad:
            print("Sons marqués « à revoir » à l'écoute :", ", ".join(bad))
    return 0


if __name__ == "__main__":
    sys.exit(main())
