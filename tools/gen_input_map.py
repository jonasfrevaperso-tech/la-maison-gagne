#!/usr/bin/env python3
"""Écrit la section [input] de project.godot à partir d'une table lisible (source de vérité
des commandes). Schéma manette type Xbox 360 / Steam Deck :

  Menus      : croix / stick gauche = naviguer · A = valider · B = retour · LB/RB = onglets
               stick droit = défiler
  Tapis      : croix / stick gauche = curseur · A = +1 jeton · B = −1 jeton · X = annuler
               Y = répéter · LB/RB = paris intérieurs · L3 = effacer · RT = lancer / relâcher
               LT = vitesse · View (Back) = grigris et Fortune · Menu (Start) = pause
  Animations : A ou B = passer
  Astuces    : A = compris · X = couper les conseils
  Partout    : R3 = note de test

Usage : python3 tools/gen_input_map.py   (puis godot --headless --path . --import)
"""
from __future__ import annotations

import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
PROJECT = ROOT / "project.godot"

# Touches physiques (enum Key de Godot).
K = {
    "space": 32, "enter": 4194309, "kp_enter": 4194310, "escape": 4194305, "tab": 4194306,
    "f8": 4194339, "e": 69, "z": 90, "r": 82, "c": 67, "f": 70, "q": 81, "w": 87, "i": 73, "m": 77, "backspace": 4194308,
}
# Boutons (JoyButton) et axes (JoyAxis).
B = {"a": 0, "b": 1, "x": 2, "y": 3, "back": 4, "start": 6, "l3": 7, "r3": 8, "lb": 9, "rb": 10}
AX = {"lt": 4, "rt": 5}

ACTIONS: dict[str, dict] = {
    # Actions d'interface intégrées : réécrites pour ajouter la manette (absente par défaut en 4.7).
    "ui_accept": {"keys": ["enter", "kp_enter", "space"], "buttons": ["a"]},
    "ui_cancel": {"keys": ["escape"], "buttons": ["b"]},
    # Jeu
    "ui_spin": {"keys": ["space"], "axes": ["rt"]},
    "bet_place": {"keys": ["e"], "buttons": ["a"]},
    "bet_remove": {"keys": ["backspace"], "buttons": ["b"]},
    "bet_undo": {"keys": ["z"], "buttons": ["x"]},
    "bet_repeat": {"keys": ["r"], "buttons": ["y"]},
    "bet_clear": {"keys": ["c"], "buttons": ["l3"]},
    "speed_toggle": {"keys": ["f"], "axes": ["lt"]},
    "skip_anim": {"keys": ["enter"], "buttons": ["a", "b"]},
    "bet_cycle_prev": {"keys": ["q"], "buttons": ["lb"]},
    "bet_cycle_next": {"keys": ["w"], "buttons": ["rb"]},
    "item_panel": {"keys": ["i"], "buttons": ["back"]},
    "pause_menu": {"keys": ["escape"], "buttons": ["start"]},
    "playtest_note": {"keys": ["f8"], "buttons": ["r3"]},
    "tip_mute": {"keys": ["m"], "buttons": ["x"]},
}


def key_ev(code: int) -> str:
    return ('Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,'
            '"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,'
            f'"keycode":0,"physical_keycode":{code},"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)')


def btn_ev(idx: int) -> str:
    return ('Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,'
            f'"button_index":{idx},"pressure":0.0,"pressed":false,"script":null)')


def axis_ev(axis: int) -> str:
    return ('Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":-1,'
            f'"axis":{axis},"axis_value":1.0,"script":null)')


def section() -> str:
    lines = ["[input]", ""]
    for name, spec in ACTIONS.items():
        evs = [key_ev(K[k]) for k in spec.get("keys", [])]
        evs += [btn_ev(B[b]) for b in spec.get("buttons", [])]
        evs += [axis_ev(AX[a]) for a in spec.get("axes", [])]
        lines.append(f"{name}={{")
        lines.append('"deadzone": 0.5,')
        lines.append('"events": [' + "\n, ".join(evs) + "]")
        lines.append("}")
    lines.append("")
    return "\n".join(lines) + "\n"


def main() -> None:
    text = PROJECT.read_text(encoding="utf-8")
    new = re.sub(r"\[input\]\n.*?(?=\n\[)", section().rstrip("\n") + "\n", text, flags=re.S)
    PROJECT.write_text(new, encoding="utf-8")
    print(f"[input] : {len(ACTIONS)} actions écrites dans project.godot")


if __name__ == "__main__":
    main()
