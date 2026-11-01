#!/usr/bin/env python3
"""Rapport de playtest : lit la télémétrie locale des joueurs (et, en option, celle des
bots du simulateur, même format) et écrit un rapport Markdown avec des propositions de
réglage de data/balance.json. Rien n'est appliqué automatiquement : les propositions
sont écrites à part (docs/balance_proposal.json) pour relecture.

Usage :
  python3 tools/telemetry_report.py                      # télémétrie du joueur (dossier par défaut)
  python3 tools/telemetry_report.py --human DIR [DIR…]   # un ou plusieurs dossiers (plusieurs testeurs)
  python3 tools/telemetry_report.py --bot DIR            # référence bot (sim_main --telemetry=…)
  python3 tools/telemetry_report.py --out docs/PLAYTEST_REPORT.md --proposal docs/balance_proposal.json

Pour produire la référence bot :
  godot --headless --path . -s res://scripts/sim/sim_main.gd -- --runs=300 --bot=synergy --telemetry=user://dev/bot_ref
"""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import statistics
import sys
from collections import Counter, defaultdict

ROOT = pathlib.Path(__file__).resolve().parent.parent
USER_DIR = pathlib.Path(os.environ.get("XDG_DATA_HOME", pathlib.Path.home() / ".local" / "share")) / "godot" / "app_userdata" / "La Maison Gagne"
DEFAULT_HUMAN = USER_DIR / "telemetry"
DEFAULT_BOT = USER_DIR / "dev" / "bot_ref"

# Seuils (rapport, pas jeu : ils ne vont pas dans balance.json).
MIN_DEADLINES_PER_TIER = 8      # en dessous : pas de proposition pour ce palier
MIN_OFFERS = 4                  # en dessous : grigri non classé
MAX_DEBT_STEP = 0.20            # une proposition ne bouge pas une dette de plus de ±20 %
DAMPING = 0.5                   # on ne corrige que la moitié de l'écart mesuré
TARGET_WIN_RATE = (0.35, 0.45)  # cible du GDD pour un joueur compétent
TARGET_RUN_MINUTES = (35, 50)
DOMINANT_PICK = 0.70
NEGLECTED_PICK = 0.15


# --------------------------------------------------------------------------- lecture


def load_runs(dirs: list[pathlib.Path]) -> tuple[list[list[dict]], list[dict]]:
    """Renvoie (runs, notes hors run). Un run = liste ordonnée d'enregistrements."""
    runs: list[list[dict]] = []
    notes: list[dict] = []
    for d in dirs:
        if not d.exists():
            continue
        for f in sorted(d.glob("*.jsonl")):
            recs = []
            for line in f.read_text(encoding="utf-8").splitlines():
                line = line.strip()
                if not line:
                    continue
                try:
                    recs.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
            if f.name == "notes.jsonl":
                notes.extend(recs)
            elif recs and recs[0].get("t") == "run_start":
                for r in recs:
                    r["_file"] = f.name
                    r["_dir"] = str(d)
                runs.append(recs)
    return runs, notes


def of(run: list[dict], kind: str) -> list[dict]:
    return [r for r in run if r.get("t") == kind]


def end_of(run: list[dict]) -> dict | None:
    ends = of(run, "run_end")
    return ends[-1] if ends else None


# --------------------------------------------------------------------------- mesures


def pct(x: float) -> str:
    return f"{x * 100:.0f} %"


def med(xs: list[float]) -> float:
    return statistics.median(xs) if xs else 0.0


def summary(runs: list[list[dict]]) -> dict:
    finished = [r for r in runs if end_of(r) is not None]
    wins = [r for r in finished if end_of(r)["victory"]]
    spins = [s for r in runs for s in of(r, "spin")]
    run_minutes = [end_of(r)["seconds"] / 60 for r in finished if end_of(r).get("seconds")]
    win_minutes = [end_of(r)["seconds"] / 60 for r in wins if end_of(r).get("seconds")]
    sec_per_spin = [end_of(r)["seconds"] / max(end_of(r)["spins"], 1) for r in finished if end_of(r).get("seconds")]
    return {
        "runs": len(runs),
        "finished": len(finished),
        "wins": len(wins),
        "win_rate": len(wins) / len(finished) if finished else 0.0,
        "spins": len(spins),
        "think": med([s.get("think_s", 0) for s in spins]),
        "sec_per_spin": med(sec_per_spin),
        "run_minutes": med(run_minutes),
        "win_minutes": med(win_minutes),
        "in_zone": sum(1 for s in spins if s.get("in_zone")) / len(spins) if spins else 0.0,
        "characters": Counter(r[0].get("character", "?") for r in runs),
    }


def survival(runs: list[list[dict]], tiers: int) -> dict[int, tuple[int, int]]:
    """Palier t : (runs entrés dans t, runs ayant passé t)."""
    out: dict[int, list[int]] = {t: [0, 0] for t in range(1, tiers + 1)}
    for r in runs:
        e = end_of(r)
        if e is None:
            continue
        last = tiers if e["victory"] else int(e["tier"])
        for t in range(1, min(last, tiers) + 1):
            out[t][0] += 1
            if e["victory"] or t < last:
                out[t][1] += 1
    return {t: (v[0], v[1]) for t, v in out.items()}


def margins(runs: list[list[dict]]) -> dict[int, list[float]]:
    """Rapport score / dette de chaque échéance terminée, par palier."""
    out: dict[int, list[float]] = defaultdict(list)
    for r in runs:
        for d in of(r, "deadline"):
            if d.get("debt"):
                out[int(d["tier"])].append(d["score"] / d["debt"])
    return out


def bet_mix(runs: list[list[dict]]) -> Counter:
    c: Counter = Counter()
    for r in runs:
        for s in of(r, "spin"):
            for k, v in s.get("bets", {}).items():
                c[k] += v
    return c


def grigri_table(runs: list[list[dict]]) -> dict[str, dict]:
    t: dict[str, dict] = defaultdict(lambda: {"offered": 0, "bought": 0, "runs": 0, "wins": 0})
    for r in runs:
        for s in of(r, "shop"):
            for g in s.get("offered", []):
                t[g]["offered"] += 1
            for g in s.get("bought", []):
                t[g]["bought"] += 1
        e = end_of(r)
        if e is None:
            continue
        owned = set(e.get("grigris", []))
        for s in of(r, "shop"):
            owned.update(s.get("bought", []))
        for g in owned:
            t[g]["runs"] += 1
            t[g]["wins"] += 1 if e["victory"] else 0
    return t


# --------------------------------------------------------------------------- propositions


def propose_debts(human: list[list[dict]], bot: list[list[dict]], balance: dict) -> tuple[list[int], list[str]]:
    """Ajuste chaque dette de palier pour rapprocher la marge humaine (score/dette médian)
    de la marge de référence (bot compétent si disponible, sinon 1,0 = juste à l'équilibre)."""
    debts = list(balance["run"]["tier_debts"])
    hm = margins(human)
    bm = margins(bot) if bot else {}
    notes: list[str] = []
    new = list(debts)
    for i, debt in enumerate(debts):
        t = i + 1
        samples = hm.get(t, [])
        if len(samples) < MIN_DEADLINES_PER_TIER:
            notes.append(f"Palier {t} : {len(samples)} échéance(s) jouée(s), pas assez pour proposer.")
            continue
        h = med(samples)
        ref = med(bm.get(t, [])) if bm.get(t) else 1.0
        factor = (h / ref) if ref > 0 else 1.0
        factor = 1.0 + (factor - 1.0) * DAMPING
        factor = max(1.0 - MAX_DEBT_STEP, min(1.0 + MAX_DEBT_STEP, factor))
        new[i] = int(round(debt * factor / 10.0) * 10)
        notes.append(f"Palier {t} : marge humaine {h:.2f} contre référence {ref:.2f} → dette {debt} → {new[i]} (×{factor:.2f}).")
    return new, notes


def classify_grigris(table: dict[str, dict]) -> tuple[list[str], list[str]]:
    dominant, neglected = [], []
    for g, v in sorted(table.items()):
        if v["offered"] < MIN_OFFERS:
            continue
        rate = v["bought"] / v["offered"]
        if rate >= DOMINANT_PICK:
            dominant.append(g)
        elif rate <= NEGLECTED_PICK:
            neglected.append(g)
    return dominant, neglected


# --------------------------------------------------------------------------- rapport


def write_report(human_dirs: list[pathlib.Path], bot_dir: pathlib.Path | None, out: pathlib.Path, proposal_path: pathlib.Path) -> int:
    balance = json.loads((ROOT / "data" / "balance.json").read_text(encoding="utf-8"))
    tiers = int(balance["run"]["tiers"])
    human, notes = load_runs(human_dirs)
    bot, _ = load_runs([bot_dir]) if bot_dir else ([], [])
    for r in human:
        notes.extend(of(r, "note"))
    if not human:
        print("Aucune télémétrie joueur trouvée dans :", ", ".join(map(str, human_dirs)))
        print("Active « Statistiques de jeu locales » dans les options, joue, puis relance ce script.")
        return 1
    hs, bs = summary(human), summary(bot) if bot else None
    L: list[str] = ["# Rapport de playtest", ""]
    L.append(f"Sources : {', '.join(map(str, human_dirs))}" + (f" · référence bot : {bot_dir}" if bot else ""))
    L.append("")
    L.append("## Vue d'ensemble")
    L.append("| | Joueurs | " + ("Bot | " if bs else "") + "Cible |")
    L.append("|---|---|" + ("---|" if bs else "") + "---|")

    def row(label: str, hv: str, bv: str, target: str) -> None:
        L.append(f"| {label} | {hv} | " + (f"{bv} | " if bs else "") + f"{target} |")

    row("Runs (terminés)", f"{hs['runs']} ({hs['finished']})", f"{bs['runs']}" if bs else "", "")
    row("Taux de victoire", pct(hs["win_rate"]), pct(bs["win_rate"]) if bs else "", f"{pct(TARGET_WIN_RATE[0])}–{pct(TARGET_WIN_RATE[1])} (joueur compétent)")
    row("Durée médiane d'un run", f"{hs['run_minutes']:.1f} min", f"{bs['run_minutes']:.1f} min" if bs else "", "")
    row("Durée médiane d'un run gagné", f"{hs['win_minutes']:.1f} min", f"{bs['win_minutes']:.1f} min" if bs else "", f"{TARGET_RUN_MINUTES[0]}–{TARGET_RUN_MINUTES[1]} min")
    row("Temps par tour, boutique comprise (médiane)", f"{hs['sec_per_spin']:.1f} s", f"{bs['sec_per_spin']:.1f} s (modèle)" if bs else "", "")
    row("Réflexion avant un lancer", f"{hs['think']:.1f} s", "", "")
    row("Lancers dans la zone visée", pct(hs["in_zone"]), pct(bs["in_zone"]) if bs else "", "")
    L.append("")
    L.append("Personnages joués : " + ", ".join(f"{k} ×{v}" for k, v in hs["characters"].most_common()))
    L.append("")

    L.append("## Survie par palier")
    hsurv = survival(human, tiers)
    bsurv = survival(bot, tiers) if bot else {}
    L.append("| Palier | Joueurs (passés / entrés) | " + ("Bot | " if bot else "") + "Dette |")
    L.append("|---|---|" + ("---|" if bot else "") + "---|")
    for t in range(1, tiers + 1):
        e, p = hsurv[t]
        hcell = f"{pct(p / e)} ({p}/{e})" if e else "—"
        bcell = ""
        if bot:
            be, bp = bsurv[t]
            bcell = f"{pct(bp / be)} | " if be else "— | "
        L.append(f"| {t} | {hcell} | {bcell}{balance['run']['tier_debts'][t - 1]} |")
    L.append("")

    L.append("## Marge aux échéances (score / dette, médiane)")
    hm, bm = margins(human), margins(bot) if bot else {}
    L.append("| Palier | Joueurs | " + ("Bot | " if bot else "") + "Échéances jouées |")
    L.append("|---|---|" + ("---|" if bot else "") + "---|")
    for t in range(1, tiers + 1):
        if not hm.get(t) and not bm.get(t):
            continue
        L.append(f"| {t} | {med(hm.get(t, [])):.2f} | " + (f"{med(bm.get(t, [])):.2f} | " if bot else "") + f"{len(hm.get(t, []))} |")
    L.append("")

    L.append("## Paris joués (part des jetons)")
    hb, bb = bet_mix(human), bet_mix(bot) if bot else Counter()
    htot, btot = sum(hb.values()) or 1, sum(bb.values()) or 1
    kinds = sorted(set(hb) | set(bb), key=lambda k: -hb.get(k, 0))
    L.append("| Type | Joueurs | " + ("Bot |" if bot else ""))
    L.append("|---|---|" + ("---|" if bot else ""))
    for k in kinds:
        L.append(f"| {k} | {pct(hb.get(k, 0) / htot)} | " + (f"{pct(bb.get(k, 0) / btot)} |" if bot else ""))
    L.append("")

    L.append("## Grigris")
    gt = grigri_table(human)
    dominant, neglected = classify_grigris(gt)
    L.append(f"Classés à partir de {MIN_OFFERS} apparitions en boutique. Choisis ≥ {pct(DOMINANT_PICK)} : **dominants** ; ≤ {pct(NEGLECTED_PICK)} : **délaissés**.")
    L.append("")
    L.append("| Grigri | Proposé | Acheté | Taux | Victoires quand possédé |")
    L.append("|---|---|---|---|---|")
    for g, v in sorted(gt.items(), key=lambda kv: -kv[1]["bought"]):
        if v["offered"] == 0 and v["runs"] == 0:
            continue
        rate = pct(v["bought"] / v["offered"]) if v["offered"] else "—"
        wr = f"{pct(v['wins'] / v['runs'])} ({v['runs']})" if v["runs"] else "—"
        tag = " **dominant**" if g in dominant else (" *délaissé*" if g in neglected else "")
        L.append(f"| {g}{tag} | {v['offered']} | {v['bought']} | {rate} | {wr} |")
    L.append("")

    L.append("## Notes de test")
    if not notes:
        L.append("Aucune note (F8 en jeu ou « Noter ce moment » dans le menu pause).")
    by_mood: dict[str, list[dict]] = defaultdict(list)
    for n in notes:
        by_mood[n.get("mood", "?")].append(n)
    for mood in ["bug", "bad", "meh", "good", "great"] + [m for m in by_mood if m not in ("bug", "bad", "meh", "good", "great")]:
        for n in by_mood.get(mood, []):
            where = f"palier {n['tier']}, tour {n.get('n', '?')}" if "tier" in n else n.get("screen", "")
            shot = f" — capture `{n['shot']}`" if n.get("shot") else ""
            L.append(f"- **{mood}** ({where}) : {n.get('text') or '(sans texte)'}{shot}")
    L.append("")

    L.append("## Propositions de réglage")
    new_debts, debt_notes = propose_debts(human, bot, balance)
    L.extend(f"- {n}" for n in debt_notes)
    if dominant:
        L.append(f"- Grigris à affaiblir ou renchérir (choisis presque toujours) : {', '.join(dominant)}.")
    if neglected:
        L.append(f"- Grigris à renforcer (presque jamais choisis) : {', '.join(neglected)}.")
    if hs["finished"] and not (TARGET_WIN_RATE[0] <= hs["win_rate"] <= TARGET_WIN_RATE[1]):
        L.append(f"- Taux de victoire joueurs {pct(hs['win_rate'])} hors cible : vérifier d'abord l'économie (`economy.start_money`, `economy.deadline_rewards`), levier principal (cf. docs/BALANCE.md).")
    proposal = {"run": {"tier_debts": new_debts}, "grigris_to_nerf": dominant, "grigris_to_buff": neglected}
    proposal_path.parent.mkdir(parents=True, exist_ok=True)
    proposal_path.write_text(json.dumps(proposal, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    L.append("")
    L.append(f"Propositions écrites dans `{proposal_path.relative_to(ROOT) if proposal_path.is_relative_to(ROOT) else proposal_path}` (à recopier à la main dans `data/balance.json` après relecture, puis `tools/check.sh` et une simulation de contrôle).")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(L) + "\n", encoding="utf-8")
    print(f"Rapport : {out} ({hs['runs']} run(s) joueur" + (f", {bs['runs']} run(s) bot" if bs else "") + f", {len(notes)} note(s))")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--human", nargs="+", type=pathlib.Path, default=[DEFAULT_HUMAN])
    ap.add_argument("--bot", type=pathlib.Path, default=None)
    ap.add_argument("--out", type=pathlib.Path, default=ROOT / "docs" / "PLAYTEST_REPORT.md")
    ap.add_argument("--proposal", type=pathlib.Path, default=ROOT / "docs" / "balance_proposal.json")
    a = ap.parse_args()
    bot = a.bot if a.bot else (DEFAULT_BOT if DEFAULT_BOT.exists() else None)
    return write_report(a.human, bot, a.out, a.proposal)


if __name__ == "__main__":
    sys.exit(main())
