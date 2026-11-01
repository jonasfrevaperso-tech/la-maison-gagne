#!/usr/bin/env python3
"""Génère les tables de contenu docs/content/*.md à partir de data/ (source de vérité).

Usage : python3 tools/gen_content_docs.py
"""
from __future__ import annotations

import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "content"

CATS = [
    ("pockets", "pockets", "pocket_types", "Cases spéciales"),
    ("editions", "pockets", "editions", "Éditions"),
    ("seals", "pockets", "seals", "Sceaux"),
    ("grigris", "grigris", "grigris", "Grigris"),
    ("fortunes", "fortunes", "fortunes", "Cartes Fortune"),
    ("contracts", "contracts", "contracts", "Contrats"),
    ("creditors", "creditors", "creditors", "Créanciers"),
    ("characters", "characters", "characters", "Personnages"),
    ("risks", "risks", "risks", "Niveaux de Risque"),
    ("events", "events", "events", "Événements"),
    ("achievements", "achievements", "achievements", "Succès"),
    ("challenges", "challenges", "challenges", "Défis"),
]
RARITY_ORDER = {"common": 0, "rare": 1, "legendary": 2, "cursed": 3}


def load(folder: str, prefix: str) -> list[dict]:
    out: list[dict] = []
    for f in sorted((ROOT / "data" / folder).glob(prefix + "*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        out.extend(d if isinstance(d, list) else d.get("entries", []))
    return out


def cell(s) -> str:
    return str(s).replace("|", "\\|").replace("\n", " ")


def effects_summary(e: dict) -> str:
    parts = []
    for eff in e.get("effects", []):
        ops = ",".join(a.get("op", "?") for a in eff.get("do", []))
        parts.append(f"{eff.get('trigger', '?')}→{ops}")
    return "; ".join(parts)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    index = ["# Tables de contenu", "", "Générées par `tools/gen_content_docs.py` depuis `data/`. Ne pas éditer à la main.", ""]
    for slug, folder, prefix, title in CATS:
        rows = load(folder, prefix)
        if slug == "grigris":
            rows.sort(key=lambda e: (RARITY_ORDER.get(e.get("rarity", ""), 9), e["id"]))
        lines = [f"# {title} ({len(rows)})", ""]
        if slug == "grigris":
            counts: dict = {}
            for e in rows:
                counts[e.get("rarity")] = counts.get(e.get("rarity"), 0) + 1
            lines.append("Répartition : " + ", ".join(f"{k} {v}" for k, v in sorted(counts.items(), key=lambda kv: RARITY_ORDER.get(kv[0], 9))))
            lines.append("")
        lines.append("| id | Nom (FR / EN) | Description | Rareté / coût | Tags | Effets | Ambiance |")
        lines.append("|---|---|---|---|---|---|---|")
        for e in rows:
            rc = e.get("rarity", "")
            if "cost" in e:
                rc = f"{rc} {e['cost']} $".strip()
            if "level" in e:
                rc = f"niveau {e['level']}"
            if "tier_min" in e:
                rc = f"paliers {e['tier_min']}–{e['tier_max']}" + (" (secret)" if e.get("secret") else "")
            lines.append("| {} | {} / {} | {} | {} | {} | {} | {} |".format(
                e["id"], cell(e.get("name_fr", "")), cell(e.get("name_en", "")), cell(e.get("desc_fr", "")), cell(rc),
                cell(", ".join(e.get("tags", []))), cell(effects_summary(e)), cell(e.get("flavor_fr", e.get("intro_fr", "")))))
        (OUT / f"{slug}.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
        index.append(f"- [{title}]({slug}.md) — {len(rows)} entrées")
    (OUT / "README.md").write_text("\n".join(index) + "\n", encoding="utf-8")
    print(f"Tables écrites dans {OUT}")


if __name__ == "__main__":
    main()
