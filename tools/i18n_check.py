#!/usr/bin/env python3
"""Vérifie que toutes les clés de traduction utilisées dans le code existent dans
localization/strings.csv (colonnes fr et en non vides). Les clés dynamiques
(préfixes + suffixes connus) sont développées à partir de DYNAMIC.

Usage : python3 tools/i18n_check.py   (code de sortie 1 si des clés manquent)
"""
import csv
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CSV_PATH = ROOT / "localization" / "strings.csv"
PREFIXES = ("BET_", "BTN_", "CARD_", "CHAR_", "CONFIRM_", "CREDITOR_", "CREDITS_", "DAILY_", "DEADLINE_",
            "FX_", "HINT_", "HISTORY_", "HUD_", "MENU_", "OPT_", "PACK_", "PACT_", "PAUSE_", "POCKET_", "RARITY_",
            "REJECT_", "REWARD_", "RISK_", "SHOP_", "SLOT_", "SUB_", "SUMMARY_", "TAG_", "TIP_", "TOAST_", "TUTO_",
            "WHY_", "GAME_", "DISCLAIMER_", "CELEB_", "LANG_", "SPEED_", "CB_", "ACTION_", "CODEX_", "HALL_",
            "ACH_", "STATS_", "DLG_", "END_", "CAMPAIGN_", "CHALLENGE_", "EVENT_", "REPLAY_", "PROB_", "CALC_", "THROW_", "ACT_", "KEYNAME_", "NOTE_", "OSK_", "RACE_")
PATTERN = re.compile(r'"([A-Z][A-Z0-9]*_[A-Z0-9_]*[A-Z0-9])"')

TAGS = set()
for f in (ROOT / "data").rglob("*.json"):
    try:
        data = json.loads(f.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        continue
    entries = data if isinstance(data, list) else data.get("entries", []) if isinstance(data, dict) else []
    for e in entries:
        if isinstance(e, dict):
            for t in e.get("tags", []):
                TAGS.add(t)

DYNAMIC = {
    "BET_": ["STRAIGHT", "SPLIT", "STREET", "CORNER", "SIX_LINE", "DOZEN", "COLUMN", "RED", "BLACK", "EVEN", "ODD", "LOW", "HIGH"],
    "DEADLINE_": ["SMALL", "BIG", "CREDITOR"],
    "RARITY_": ["COMMON", "RARE", "LEGENDARY", "CURSED"],
    "PACK_": ["POCKET", "FORTUNE", "OCCULT", "POCKET_DESC", "FORTUNE_DESC", "OCCULT_DESC"],
    "HINT_": ["AIMING", "RETHROW", "TARGETING"],
    "KEYNAME_": ["SPACE", "ENTER", "ESCAPE", "SHIFT", "BACKSPACE", "UP", "TAB"],
    "OPT_VOL_": ["MASTER", "MUSIC", "SFX", "UI", "AMBIENCE"],
    "ACTION_": ["UI_SPIN", "BET_UNDO", "BET_REPEAT", "BET_CLEAR", "SPEED_TOGGLE", "SKIP_ANIM", "BET_PLACE", "BET_CYCLE_PREV", "BET_CYCLE_NEXT", "BET_REMOVE", "ITEM_PANEL", "PAUSE_MENU", "PLAYTEST_NOTE"],
    "TAG_": sorted(t.upper() for t in TAGS),
    "CELEB_": ["GOOD", "HUGE", "JACKPOT", "BANK"],
    "NOTE_MOOD_": ["GREAT", "GOOD", "MEH", "BAD", "BUG"],
}
EXTRA = ["LANG_FR", "LANG_EN", "SPEED_1", "SPEED_2", "SPEED_4", "CB_OFF", "CB_PROTAN", "CB_DEUTAN", "CB_TRITAN"]


def used_keys() -> set:
    keys = set(EXTRA)
    for p in list((ROOT / "scripts").rglob("*.gd")) + list((ROOT / "tools").rglob("*.gd")):
        keys.update(k for k in PATTERN.findall(p.read_text(encoding="utf-8")) if k.startswith(PREFIXES))
    for prefix, suffixes in DYNAMIC.items():
        keys.update(prefix + s for s in suffixes)
    return keys


def main() -> int:
    with CSV_PATH.open(encoding="utf-8") as f:
        rows = {r["keys"]: r for r in csv.DictReader(f)}
    missing = sorted(k for k in used_keys() if k not in rows)
    empty = sorted(k for k, r in rows.items() if not r.get("fr") or not r.get("en"))
    for k in missing:
        print("MANQUANT", k)
    for k in empty:
        print("VIDE", k)
    print(f"i18n : {len(rows)} clés, {len(missing)} manquantes, {len(empty)} vides")
    return 1 if missing or empty else 0


if __name__ == "__main__":
    sys.exit(main())
