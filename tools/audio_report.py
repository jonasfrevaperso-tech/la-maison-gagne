#!/usr/bin/env python3
"""Contrôle objectif de l'audio (substitut à l'écoute) : crête, RMS, silences, raccord des boucles.

Écrit docs/AUDIO.md et sort en erreur si un fichier sature, est muet, ou si une boucle claque.
Usage : python3 tools/audio_report.py
"""
from __future__ import annotations

import pathlib
import subprocess
import sys
import wave

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent
SFX = ROOT / "audio" / "sfx"
MUSIC = ROOT / "audio" / "music"
CLIP_DB = -0.1
SILENT_DB = -50.0
LOOP_JUMP_MAX = 0.12  # écart max entre dernier et premier échantillon d'une boucle


def db(x: float) -> float:
    return 20 * np.log10(max(x, 1e-9))


def read_wav(p: pathlib.Path) -> np.ndarray:
    with wave.open(str(p)) as w:
        return np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0


def read_ogg(p: pathlib.Path) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(p), "-f", "s16le", "-ac", "1", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0


def main() -> int:
    rows = []
    problems = []
    groups: dict[str, list[tuple[float, float, float]]] = {}
    for p in sorted(SFX.glob("*.wav")):
        x = read_wav(p)
        peak, rms = db(float(np.max(np.abs(x)))), db(float(np.sqrt(np.mean(x ** 2))))
        sid = p.stem.rsplit("_", 1)[0] if p.stem[-1].isdigit() else p.stem
        groups.setdefault(sid, []).append((peak, rms, len(x) / 44100))
        if peak > CLIP_DB:
            problems.append(f"saturation : {p.name} ({peak:.1f} dBFS)")
        if peak < SILENT_DB:
            problems.append(f"quasi muet : {p.name}")
    for sid, vals in groups.items():
        rows.append((sid, len(vals), np.mean([v[0] for v in vals]), np.mean([v[1] for v in vals]), np.mean([v[2] for v in vals])))
    music_rows = []
    for p in sorted(MUSIC.glob("*.ogg")):
        x = read_ogg(p)
        jump = abs(float(x[-1]) - float(x[0]))
        peak, rms = db(float(np.max(np.abs(x)))), db(float(np.sqrt(np.mean(x ** 2))))
        music_rows.append((p.stem, len(x) / 44100, peak, rms, jump))
        if jump > LOOP_JUMP_MAX:
            problems.append(f"raccord de boucle : {p.name} (saut {jump:.3f})")
        if peak > CLIP_DB:
            problems.append(f"saturation : {p.name}")
    lines = ["# Rapport audio (généré par `tools/audio_report.py`)", "",
             "Mesures objectives en l'absence d'écoute humaine. Seuils : saturation > −0,1 dBFS, silence < −50 dBFS, saut de boucle > 0,12.", "",
             "## Effets sonores", "", "| Son | Variantes | Crête moy. (dBFS) | RMS moy. (dBFS) | Durée moy. (s) |", "|---|---|---|---|---|"]
    for sid, n, pk, rms, dur in rows:
        lines.append(f"| {sid} | {n} | {pk:.1f} | {rms:.1f} | {dur:.2f} |")
    lines += ["", "## Musique (couches)", "", "| Couche | Durée (s) | Crête | RMS | Saut de boucle |", "|---|---|---|---|---|"]
    for name, dur, pk, rms, jump in music_rows:
        lines.append(f"| {name} | {dur:.1f} | {pk:.1f} | {rms:.1f} | {jump:.3f} |")
    lines += ["", "## Problèmes", ""] + ([f"- {p}" for p in problems] or ["Aucun."])
    (ROOT / "docs" / "AUDIO.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Audio : {sum(r[1] for r in rows)} SFX, {len(music_rows)} couches, {len(problems)} problème(s)")
    for p in problems:
        print("  " + p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
