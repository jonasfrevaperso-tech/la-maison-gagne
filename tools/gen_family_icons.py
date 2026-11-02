#!/usr/bin/env python3
"""Emblèmes des familles de grigris (builds) en pixel art : 16×16, contour encre, agrandis ×2.
Chaque famille a sa couleur (f clair, F foncé) lue dans data/families/families.json ; les
emblèmes sont dessinés en ASCII ci-dessous.

Usage : python3 tools/gen_family_icons.py   → assets/families/<icon>.png
"""
from __future__ import annotations

import json
import pathlib

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "families"
SCALE = 2
BASE = {
    "k": (10, 8, 13, 255),
    "w": (245, 240, 230, 255),
    "r": (224, 64, 80, 255),
    "n": (40, 34, 46, 255),
    "g": (212, 175, 55, 255),
}

ART: dict[str, list[str]] = {
    "rouge_noir": [
        ".......kk.......",
        "......krnk......",
        ".....krrnnk.....",
        "....krrrnnnk....",
        "...krrrrnnnnk...",
        "..krrrrrnnnnnk..",
        ".krrrrrrnnnnnnk.",
        "krrrrrrrnnnnnnnk",
        "krrrrrrrnnnnnnnk",
        ".krrrrrrnnnnnnk.",
        "..krrrrrnnnnnk..",
        "...krrrrnnnnk...",
        "....krrrnnnk....",
        ".....krrnnk.....",
        "......krnk......",
        ".......kk.......",
    ],
    "plein": [
        ".....kkkkkk.....",
        "...kkffffffkk...",
        "..kffFFFFFFffk..",
        ".kfFFffffffFFfk.",
        ".kfFffkkkkffFfk.",
        "kfFffk....kffFfk",
        "kfFfk..ww..kfFfk",
        "kfFfk.wwww.kfFfk",
        "kfFfk.wwww.kfFfk",
        "kfFfk..ww..kfFfk",
        "kfFffk....kffFfk",
        ".kfFffkkkkffFfk.",
        ".kfFFffffffFFfk.",
        "..kffFFFFFFffk..",
        "...kkffffffkk...",
        ".....kkkkkk.....",
    ],
    "numeros": [
        "................",
        ".....kkkkkk.....",
        "....kffffffk....",
        "...kffFFFFffk...",
        "..kffFk..kFffk..",
        "..kfFk....kFfk..",
        "..kfFk....kFfk..",
        "..kfFk....kFfk..",
        "..kfFk....kFfk..",
        "..kfFk....kFfk..",
        "..kfFk....kFfk..",
        "..kffFk..kFffk..",
        "...kffFFFFffk...",
        "....kffffffk....",
        ".....kkkkkk.....",
        "................",
    ],
    "main": [
        "......kk.kk.....",
        "....kkfkkfkkk...",
        "...kfkfkkfkfk...",
        "...kfkfkkfkfk...",
        "...kfkfkkfkfk.kk",
        "...kfkfkkfkfkkfk",
        "...kfffffffffkfk",
        ".kkkffffffffffk.",
        "kfffkfffffffffk.",
        "kFfffffffffffk..",
        ".kFffffffffffk..",
        "..kFfffffffffk..",
        "...kFfffffffk...",
        "....kFFfffFk....",
        ".....kkkkkk.....",
        "................",
    ],
    "atelier": [
        "................",
        "..kkkkkkkkk.....",
        ".kffffffffFk....",
        ".kfFFFFFFFFk....",
        ".kffffffffFk....",
        "..kkkkwwkkk.....",
        "......kwk.......",
        "......kwk.......",
        "......kwk.......",
        "......kwk.......",
        "......kwk.......",
        "......kwk.......",
        ".....kgggk......",
        ".....kgggk......",
        "......kkk.......",
        "................",
    ],
    "banque": [
        ".....kkkkkk.....",
        "...kkffffffkk...",
        "..kffFFFFFFffk..",
        ".kfFFffkkffFFfk.",
        ".kfFfkkkkkkfFfk.",
        "kfFfkkfkkfffFfk.",
        "kfFfkkfkkfffFFfk",
        "kfFffkkkkkffFFfk",
        "kfFfffkkfkkfFFfk",
        "kfFfffkkfkkfFFfk",
        ".kfFfkkkkkkfFfk.",
        ".kfFFffkkffFFfk.",
        "..kffFFFFFFffk..",
        "...kkffffffkk...",
        ".....kkkkkk.....",
        "................",
    ],
    "moteur": [
        "......kkkk......",
        "..kk..kffk..kk..",
        ".kffkkkffkkkffk.",
        ".kfffffffffffFk.",
        "..kffFFFFFFfFk..",
        "kkkfFFkkkkFFfkkk",
        "kffffk....kffffk",
        "kfFffk....kffFfk",
        "kfFffk....kffFfk",
        "kkkfFFkkkkFFfkkk",
        "..kffFFFFFFfFk..",
        ".kfffffffffffFk.",
        ".kffkkkffkkkFFk.",
        "..kk..kffk..kk..",
        "......kkkk......",
        "................",
    ],
    "etoile": [
        ".......kk.......",
        "......kffk......",
        "......kffk......",
        ".....kfwffk.....",
        "kkkkkkfwfffkkkkk",
        "kffffffffffffFFk",
        ".kFfffffffffFFk.",
        "..kFffffffffFk..",
        "...kFfffffffk...",
        "...kfffffffFk...",
        "..kffffkkfffFk..",
        "..kfffk..kffFk..",
        ".kfffk....kfFFk.",
        ".kffk......kFFk.",
        ".kkk........kkk.",
        "................",
    ],
    "arrosage": [
        "................",
        ".kkkk......kkkk.",
        "kffffk....kffffk",
        "kfwwfk....kfwwfk",
        "kffffk....kffffk",
        "kFFFFk....kFFFFk",
        ".kkkk.kkkk.kkkk.",
        "......kffffk....",
        ".....kfwwfk.....",
        "......kffffk....",
        "......kFFFFk....",
        ".kkkk..kkkk.....",
        "kffffk..........",
        "kfwwfk..........",
        "kFFFFk..........",
        ".kkkk...........",
    ],
    "pacte": [
        "................",
        "....kkkkkkkk....",
        "...kwwwwwwwwk...",
        "..kwwwwwwwwwwk..",
        "..kwwwwwwwwwwk..",
        "..kwkkkwwkkkwk..",
        "..kwkffwwkffwk..",
        "..kwkkkwwkkkwk..",
        "..kwwwwkkwwwwk..",
        "...kwwwkkwwwk...",
        "....kwwwwwwk....",
        "....kwkwkwkk....",
        "....kwkwkwk.....",
        ".....kkkkkk.....",
        "................",
        "................",
    ],
}


def hex_rgb(h: str) -> tuple[int, int, int, int]:
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    fams = json.loads((ROOT / "data" / "families" / "families.json").read_text(encoding="utf-8"))
    for fam in fams:
        light = hex_rgb(fam["color"])
        dark = tuple(int(c * 0.55) for c in light[:3]) + (255,)
        pal = dict(BASE, f=light, F=dark)
        rows = ART[fam["id"]]
        img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        for y, row in enumerate(rows):
            assert len(row) == 16, (fam["id"], y, len(row))
            for x, ch in enumerate(row):
                if ch != ".":
                    img.putpixel((x, y), pal[ch])
        img = img.resize((16 * SCALE, 16 * SCALE), Image.NEAREST)
        img.save(OUT / f"{fam['icon']}.png")
    print(f"{len(fams)} emblèmes → {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
