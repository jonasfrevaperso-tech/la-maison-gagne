#!/usr/bin/env python3
"""Icônes de statistiques en pixel art (fiches de cases, infobulles) : 16×16, palette du jeu,
contour encre, agrandies ×2 au plus proche voisin. Dessinées en ASCII ci-dessous (une lettre =
une couleur de la palette, « . » = transparent).

Usage : python3 tools/gen_stat_icons.py   → assets/stat_icons/<id>.png + docs/stat_icons_sheet.png
"""
from __future__ import annotations

import pathlib

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "stat_icons"
SCALE = 2
PAL = {
    "k": (10, 8, 13, 255),  # encre
    "w": (245, 240, 230, 255),  # ivoire
    "b": (61, 139, 255, 255),  # jetons (bleu)
    "B": (30, 74, 160, 255),
    "r": (255, 59, 92, 255),  # mult (rouge)
    "R": (150, 26, 40, 255),
    "g": (212, 175, 55, 255),  # or
    "G": (138, 109, 30, 255),
    "y": (242, 210, 122, 255),
    "e": (46, 230, 168, 255),  # émeraude
    "E": (20, 120, 90, 255),
    "c": (41, 224, 255, 255),  # cyan
    "C": (20, 110, 140, 255),
    "m": (255, 46, 136, 255),  # magenta
    "p": (176, 58, 255, 255),  # maudit
    "s": (107, 98, 117, 255),  # fumée
    "S": (43, 38, 49, 255),
}

ICONS: dict[str, list[str]] = {
    "chips": [
        "................",
        ".....kkkkkk.....",
        "...kkbbwwbbkk...",
        "..kbbbwwwwbbbk..",
        "..kwbbbbbbbbwk..",
        ".kwwbBBBBBBbwwk.",
        ".kbbbBwwwwBbbbk.",
        ".kbbbBwbbwBbbbk.",
        ".kbbbBwbbwBbbbk.",
        ".kbbbBwwwwBbbbk.",
        ".kwwbBBBBBBbwwk.",
        "..kwbbbbbbbbwk..",
        "..kBbbwwwwbbBk..",
        "...kkBBwwBBkk...",
        ".....kkkkkk.....",
        "................",
    ],
    "mult": [
        "................",
        "......kkkk......",
        "......krrk......",
        "......krrk......",
        "......krrk......",
        "..kkkkkrrkkkkk..",
        "..krrrrrrrrrrk..",
        "..krrrrrrrrrrk..",
        "..kRRRRrrRRRRk..",
        "..kkkkkrrkkkkk..",
        "......krrk......",
        "......krrk......",
        "......kRRk......",
        "......kkkk......",
        "................",
        "................",
    ],
    "xmult": [
        "................",
        "..kkk......kkk..",
        "..krrk....krrk..",
        "..krrrk..krrrk..",
        "...krrrkkrrrk...",
        "....krrrrrrk....",
        ".....krrrrk.....",
        ".....krrrrk.....",
        "....krrrrrrk....",
        "...krrrRRrrrk...",
        "..krrRk..kRrrk..",
        "..kRRk....kRRk..",
        "..kkk......kkk..",
        "................",
        "................",
        "................",
    ],
    "money": [
        "................",
        ".....kkkkkk.....",
        "...kkggggggkk...",
        "..kgggyykggggk..",
        "..kggykkkkkggk..",
        ".kggykggkggggGk.",
        ".kggykggggggggk.",
        ".kgggykkkkgggGk.",
        ".kggggggkgyggGk.",
        ".kgggggggkygggk.",
        ".kgggkkkkkyggGk.",
        "..kgggggkggggk..",
        "..kGggggkgggGk..",
        "...kkGGGGGGkk...",
        ".....kkkkkk.....",
        "................",
    ],
    "level": [
        "................",
        ".......kk.......",
        "......kyyk......",
        ".....kyggyk.....",
        "....kyggggyk....",
        "...kyggkkggyk...",
        "..kyggk..kggyk..",
        "..kkkk.kk.kkkk..",
        "......kyyk......",
        ".....kyggyk.....",
        "....kyggggyk....",
        "...kyggkkggyk...",
        "..kyggk..kggyk..",
        "..kkkk....kkkk..",
        "................",
        "................",
    ],
    "chance": [
        "................",
        ".....kkkkkk.....",
        "...kkeeeeeekk...",
        "..keeEkkkkEeek..",
        "..keEk....kEek..",
        ".keEk.kkkk.kEek.",
        ".keek.keek.keek.",
        ".keek.kewk.keek.",
        ".keek.keek.keek.",
        ".keEk.kkkk.kEek.",
        "..keEk....kEek..",
        "..keeEkkkkEeek..",
        "...kkeeeeeekk...",
        ".....kkkkkk.....",
        "................",
        "................",
    ],
    "edition": [
        "................",
        ".......kk.......",
        "......kwck......",
        ".....kwccck.....",
        "....kwcccCCk....",
        "...kwcccccCCk...",
        "..kwccccccCCCk..",
        "..kccccccCCCCk..",
        "...kcccccCCCk...",
        "....kcccCCCk....",
        ".....kcCCCk.....",
        "......kCCk......",
        ".......kk.......",
        "................",
        "................",
        "................",
    ],
    "seal": [
        "................",
        "....kkkkkkk.....",
        "...krrrrrrrk....",
        "..krrwrrrrrRk...",
        ".krrwrrkkrrrRk..",
        ".krrrrkyykrrRk..",
        ".krrrkyggykrRk..",
        ".krrrkyggykrRk..",
        ".krrrrkyykrrRk..",
        "..krrrrkkrrRk...",
        "...krRRRRRRk....",
        "....kRkkkRk.....",
        "....kRk.kRk.....",
        "....kkk.kkk.....",
        "................",
        "................",
    ],
    "pocket": [
        "................",
        "..kkkkkkkkkkkk..",
        "..kggggggggggk..",
        "..kgkkkkkkkkgk..",
        "..kgkrrrrrrkgk..",
        "..kgkrrwwrrkgk..",
        "..kgkrwrrwrkgk..",
        "..kgkrrrrwrkgk..",
        "..kgkrrrwrrkgk..",
        "..kgkrrwrrrkgk..",
        "..kgkrwwwwrkgk..",
        "..kgkRRRRRRkgk..",
        "..kgkkkkkkkkgk..",
        "..kGGGGGGGGGGk..",
        "..kkkkkkkkkkkk..",
        "................",
    ],
    "curse": [
        "................",
        ".....kkkkkk.....",
        "....kppppppk....",
        "...kppppppppk...",
        "...kpkkppkkpk...",
        "...kpkwppwkpk...",
        "...kppppppppk...",
        "....kpppkppk....",
        ".....kppppk.....",
        ".....kpkpkk.....",
        "......kkkk......",
        "................",
        "................",
        "................",
        "................",
        "................",
    ],
}


def render(rows: list[str]) -> Image.Image:
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        assert len(row) == 16, (row, len(row))
        for x, ch in enumerate(row):
            if ch != ".":
                im.putpixel((x, y), PAL[ch])
    return im.resize((16 * SCALE, 16 * SCALE), Image.NEAREST)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (len(ICONS) * 40 + 8, 48), (10, 8, 13, 255))
    for i, (name, rows) in enumerate(ICONS.items()):
        assert len(rows) == 16, name
        im = render(rows)
        im.save(OUT / f"{name}.png")
        sheet.paste(im, (8 + i * 40, 8), im)
    sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(ROOT / "docs" / "stat_icons_sheet.png")
    print(f"{len(ICONS)} icônes de statistiques écrites dans {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
