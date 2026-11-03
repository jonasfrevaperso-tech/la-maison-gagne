#!/usr/bin/env python3
"""Icônes Android (export « Android ») en pixel art, d'après l'emblème du jeu (icon.svg) :
roue de roulette dorée, moyeu magenta, bille ivoire, sur velours sombre à rayons art déco.

Sorties (assets/android/) :
  icon_192.png            icône classique 192×192 (coins arrondis)
  icon_fg_432.png         avant-plan adaptatif (la roue tient dans la zone sûre de 66 %)
  icon_bg_432.png         arrière-plan adaptatif (velours + rayons)
  icon_mono_432.png       icône monochrome (thème Android 13+)
Usage : uv run --with pillow tools/gen_android_icons.py
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "android"
GRID = 72  # dessin sur une grille de 72 pixels, agrandie sans lissage
INK = (10, 8, 13, 255)
VELVET = (26, 20, 32, 255)
VELVET_DEEP = (18, 12, 22, 255)
GOLD = (212, 175, 55, 255)
GOLD_LIGHT = (245, 215, 110, 255)
GOLD_DARK = (138, 106, 30, 255)
RED = (200, 30, 50, 255)
BLACK = (24, 22, 28, 255)
GREEN = (15, 138, 79, 255)
MAGENTA = (255, 46, 136, 255)
IVORY = (245, 240, 230, 255)
CLEAR = (0, 0, 0, 0)


def wheel(px: Image.Image, cx: float, cy: float, r: float, mono: bool = False) -> None:
    """Roue vue de dessus : jante dorée, 37 cases, croisillon, moyeu, bille."""
    w, h = px.size
    pockets = 37
    for y in range(h):
        for x in range(w):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            if d > r:
                continue
            a = (math.atan2(dy, dx) + math.pi / 2) % (2 * math.pi)
            k = int(a / (2 * math.pi) * pockets)
            if mono:
                col = IVORY if d > r * 0.84 or d < r * 0.36 or (r * 0.58 < d < r * 0.82 and k % 2 == 0) else CLEAR
            elif d > r * 0.9:
                col = GOLD_LIGHT if dy < -dx * 0.3 else GOLD
            elif d > r * 0.84:
                col = GOLD_DARK
            elif d > r * 0.58:
                col = GREEN if k == 0 else (RED if k % 2 else BLACK)
                if d > r * 0.8:
                    col = tuple(min(255, int(c * 1.25)) for c in col[:3]) + (255,)
            elif d > r * 0.36:
                col = (110, 60, 30, 255) if (k // 3) % 2 else (90, 48, 24, 255)
            elif d > r * 0.24:
                col = MAGENTA
            else:
                col = INK
            px.putpixel((x, y), col)
    # Croisillon doré.
    dr = ImageDraw.Draw(px)
    for ang in (0, math.pi / 2):
        for s in (-1, 1):
            ex = cx + math.cos(ang) * r * 0.34 * s
            ey = cy + math.sin(ang) * r * 0.34 * s
            dr.line([(cx, cy), (ex, ey)], fill=IVORY if mono else GOLD_LIGHT, width=1)
    # Bille sur la piste.
    bx, by = cx + r * 0.71 * math.cos(-2.2), cy + r * 0.71 * math.sin(-2.2)
    dr.ellipse([bx - 2.2, by - 2.2, bx + 2.2, by + 2.2], fill=IVORY)
    if not mono:
        dr.point([(bx - 1, by - 1)], fill=(255, 255, 255, 255))


def background(px: Image.Image) -> None:
    w, h = px.size
    cx, cy = w / 2, h / 2
    for y in range(h):
        for x in range(w):
            a = math.atan2(y + 0.5 - cy, x + 0.5 - cx)
            ray = int((a + math.pi) / (2 * math.pi) * 24) % 2
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy) / (w * 0.7)
            base = VELVET if ray else VELVET_DEEP
            k = max(0.55, 1.0 - d * 0.6)
            px.putpixel((x, y), tuple(int(c * k) for c in base[:3]) + (255,))
    dr = ImageDraw.Draw(px)
    # Filet à gradins art déco.
    m = 3
    dr.rectangle([m, m, w - 1 - m, h - 1 - m], outline=GOLD_DARK)


def scale(img: Image.Image, size: int) -> Image.Image:
    return img.resize((size, size), Image.NEAREST)


def rounded(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] - 1], radius=radius, fill=255)
    out = Image.new("RGBA", img.size, CLEAR)
    out.paste(img, (0, 0), mask)
    return out


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    # Avant-plan : la roue tient dans le cercle sûr (66 % de 72 ≈ 47 px de diamètre).
    fg = Image.new("RGBA", (GRID, GRID), CLEAR)
    wheel(fg, GRID / 2, GRID / 2, 22.5)
    scale(fg, 432).save(OUT / "icon_fg_432.png")
    bg = Image.new("RGBA", (GRID, GRID), VELVET)
    background(bg)
    scale(bg, 432).save(OUT / "icon_bg_432.png")
    mono = Image.new("RGBA", (GRID, GRID), CLEAR)
    wheel(mono, GRID / 2, GRID / 2, 22.5, mono=True)
    scale(mono, 432).save(OUT / "icon_mono_432.png")
    # Icône classique : fond + roue plus grande, coins arrondis.
    small = 48
    full = Image.new("RGBA", (small, small), VELVET)
    background(full)
    wheel(full, small / 2, small / 2, 20.5)
    rounded(scale(full, 192), 36).save(OUT / "icon_192.png")
    print("Icônes Android :", ", ".join(sorted(p.name for p in OUT.glob("*.png"))))


if __name__ == "__main__":
    main()
