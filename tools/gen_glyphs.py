#!/usr/bin/env python3
"""Glyphes de commandes en pixel art (docs/ART_BIBLE.md) : boutons de manette Xbox 360
(A/B/X/Y en gemmes colorées, LB/RB, LT/RT, Back/Start, Guide, croix, sticks) et souris.

Dessinés sur une petite grille (16 px de haut) avec la palette du jeu et un contour encre de
1 px, puis agrandis ×2 au plus proche voisin (le jeu les affiche en filtrage « nearest »).
Les touches de clavier ne sont pas des images : `KeyPrompt` dessine une touche en relief avec
le nom localisé de la touche (disposition AZERTY/QWERTY respectée).

Usage : python3 tools/gen_glyphs.py   → assets/glyphs/<id>.png
"""
from __future__ import annotations

import pathlib

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "glyphs"
SCALE = 2
INK = (10, 8, 13, 255)
IVORY = (245, 240, 230, 255)
SMOKE = (107, 98, 117, 255)
SMOKE_DARK = (43, 38, 49, 255)
BODY = (58, 54, 66, 255)
BODY_LIGHT = (92, 86, 104, 255)
FACE = {
    "a": ((70, 180, 60, 255), (40, 120, 36, 255)),
    "b": ((220, 50, 50, 255), (150, 26, 30, 255)),
    "x": ((52, 120, 230, 255), (30, 74, 160, 255)),
    "y": ((240, 190, 40, 255), (170, 120, 20, 255)),
}
GUIDE = ((90, 200, 80, 255), (40, 120, 40, 255))

# Police bitmap 5×7 (lignes de bits, poids fort à gauche).
FONT = {
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
    "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
}


def canvas(w: int, h: int) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def text(d: ImageDraw.ImageDraw, s: str, x: int, y: int, col: tuple, shadow: tuple | None = INK) -> None:
    """Texte bitmap 5×7 avec ombre portée d'1 px (lisibilité sur fond coloré)."""
    for layer, (ox, oy, c) in enumerate(((1, 1, shadow), (0, 0, col))):
        if c is None:
            continue
        cx = x + ox
        for ch in s:
            rows = FONT[ch]
            for j, row in enumerate(rows):
                for i, bit in enumerate(row):
                    if bit == "1":
                        d.point((cx + i, y + oy + j), fill=c)
            cx += 6
        del layer


def text_w(s: str) -> int:
    return len(s) * 6 - 1


def disc(d: ImageDraw.ImageDraw, size: int, fill: tuple, dark: tuple) -> None:
    """Bouton rond : contour encre, remplissage en deux tons (lumière en haut à gauche)."""
    d.ellipse((0, 0, size - 1, size - 1), fill=INK)
    d.ellipse((1, 1, size - 2, size - 2), fill=dark)
    d.ellipse((1, 1, size - 3, size - 3), fill=fill)
    d.point((4, 3), fill=(255, 255, 255, 140))
    d.point((3, 4), fill=(255, 255, 255, 140))


def face_button(letter: str) -> Image.Image:
    im, d = canvas(16, 16)
    fill, dark = FACE[letter]
    disc(d, 16, fill, dark)
    up = letter.upper()
    text(d, up, (16 - text_w(up)) // 2, 4, IVORY)
    return im


def shoulder(label: str, trigger: bool) -> Image.Image:
    """LB/RB : barre arrondie ; LT/RT : gâchette plus haute, bord supérieur incliné."""
    w, h = 22, 16
    im, d = canvas(w, h)
    top = 1 if trigger else 3
    d.rounded_rectangle((0, top, w - 1, h - 2), radius=4 if trigger else 3, fill=INK)
    d.rounded_rectangle((1, top + 1, w - 2, h - 3), radius=3 if trigger else 2, fill=BODY)
    d.line((2, top + 1, w - 3, top + 1), fill=BODY_LIGHT)
    if trigger:
        d.polygon([(1, top + 1), (6, top + 1), (1, top + 5)], fill=INK)
    text(d, label, (w - text_w(label)) // 2, (h - 7) // 2 + (1 if trigger else 0), IVORY)
    return im


def small_oval(arrow: str) -> Image.Image:
    """Back (flèche gauche) et Start (flèche droite), ovales argentés de la 360."""
    w, h = 20, 14
    im, d = canvas(w, h)
    d.ellipse((0, 0, w - 1, h - 1), fill=INK)
    d.ellipse((1, 1, w - 2, h - 2), fill=SMOKE)
    d.ellipse((2, 1, w - 3, h - 4), fill=(170, 164, 182, 255))
    cy = h // 2
    if arrow == "left":
        d.polygon([(6, cy), (12, cy - 4), (12, cy + 4)], fill=INK)
    else:
        d.polygon([(14, cy), (8, cy - 4), (8, cy + 4)], fill=INK)
    return im


def guide() -> Image.Image:
    im, d = canvas(16, 16)
    disc(d, 16, *GUIDE)
    text(d, "X", 5, 4, IVORY)
    return im


def dpad(highlight: str) -> Image.Image:
    """Croix ; `highlight` : '', 'up', 'down', 'left', 'right', 'ud', 'lr'."""
    im, d = canvas(16, 16)
    arm = [(5, 0, 10, 15), (0, 5, 15, 10)]
    for r in arm:
        d.rectangle(r, fill=INK)
    d.rectangle((6, 1, 9, 14), fill=BODY)
    d.rectangle((1, 6, 14, 9), fill=BODY)
    lit = {"up": [(6, 1, 9, 5)], "down": [(6, 10, 9, 14)], "left": [(1, 6, 5, 9)], "right": [(10, 6, 14, 9)]}
    keys = {"ud": ["up", "down"], "lr": ["left", "right"]}.get(highlight, [highlight] if highlight else [])
    for k in keys:
        for r in lit[k]:
            d.rectangle(r, fill=IVORY)
    d.rectangle((7, 7, 8, 8), fill=SMOKE_DARK)
    return im


def stick(side: str, click: bool) -> Image.Image:
    im, d = canvas(16, 16)
    d.ellipse((0, 0, 15, 15), fill=INK)
    d.ellipse((1, 1, 14, 14), fill=SMOKE_DARK)
    d.ellipse((3, 3, 12, 12), fill=BODY_LIGHT if click else BODY)
    d.ellipse((4, 4, 11, 11), fill=BODY_LIGHT)
    text(d, side, 5, 4, IVORY if not click else (255, 230, 120, 255))
    if click:
        d.point((15, 0), fill=IVORY)
        d.point((14, 1), fill=IVORY)
    return im


def mouse(button: str) -> Image.Image:
    """Souris : 'left', 'right', 'wheel', ''."""
    w, h = 12, 16
    im, d = canvas(w, h)
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius=5, fill=INK)
    d.rounded_rectangle((1, 1, w - 2, h - 2), radius=4, fill=(200, 194, 208, 255))
    d.line((6, 1, 6, 6), fill=INK)
    d.line((1, 7, w - 2, 7), fill=INK)
    if button == "left":
        d.rectangle((2, 2, 5, 6), fill=(255, 46, 136, 255))
    elif button == "right":
        d.rectangle((7, 2, 9, 6), fill=(255, 46, 136, 255))
    elif button == "wheel":
        d.rectangle((5, 2, 6, 5), fill=(255, 46, 136, 255))
    return im


def touch(kind: str) -> Image.Image:
    """Doigt (index tendu) : 'tap', 'hold', 'double', 'drag', 'swipe'."""
    w, h = 16, 16
    im, d = canvas(w, h)
    skin = (240, 205, 170, 255)
    shade = (196, 150, 116, 255)
    accent = (255, 46, 136, 255)
    fx = 7  # colonne gauche de l'index
    # Onde de contact autour du bout du doigt.
    if kind in ("tap", "double", "hold"):
        d.ellipse((fx - 4, 0, fx + 6, 6), outline=accent)
        if kind == "double":
            d.ellipse((fx - 6, -2, fx + 8, 8), outline=(255, 140, 190, 255))
        if kind == "hold":
            d.ellipse((fx - 3, 1, fx + 5, 5), fill=(255, 46, 136, 120))
    if kind == "drag":
        d.line((1, 3, 4, 3), fill=accent)
        d.line((11, 3, 14, 3), fill=accent)
        d.point((2, 2), fill=accent)
        d.point((2, 4), fill=accent)
        d.point((13, 2), fill=accent)
        d.point((13, 4), fill=accent)
    if kind == "swipe":
        for x in range(1, 15):
            d.point((x, 1), fill=accent)
        d.point((13, 0), fill=accent)
        d.point((13, 2), fill=accent)
        d.point((12, 0), fill=accent)
        d.point((12, 2), fill=accent)
    # Index (3 px de large) et main.
    d.rectangle((fx - 1, 2, fx + 3, 10), fill=INK)
    d.rectangle((fx, 3, fx + 2, 10), fill=skin)
    d.rectangle((fx - 4, 8, fx + 7, 15), fill=INK)
    d.rectangle((fx - 3, 9, fx + 6, 14), fill=skin)
    d.line((fx + 3, 9, fx + 3, 12), fill=shade)
    d.line((fx + 5, 9, fx + 5, 12), fill=shade)
    d.line((fx - 3, 14, fx + 6, 14), fill=shade)
    d.point((fx + 1, 3), fill=(255, 235, 215, 255))
    return im


def save(name: str, im: Image.Image) -> None:
    im.resize((im.width * SCALE, im.height * SCALE), Image.NEAREST).save(OUT / f"{name}.png")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    glyphs: dict[str, Image.Image] = {}
    for b in "abxy":
        glyphs[f"pad_{b}"] = face_button(b)
    glyphs["pad_lb"] = shoulder("LB", False)
    glyphs["pad_rb"] = shoulder("RB", False)
    glyphs["pad_lt"] = shoulder("LT", True)
    glyphs["pad_rt"] = shoulder("RT", True)
    glyphs["pad_back"] = small_oval("left")
    glyphs["pad_start"] = small_oval("right")
    glyphs["pad_guide"] = guide()
    for h in ["", "up", "down", "left", "right", "ud", "lr"]:
        glyphs["pad_dpad" + (f"_{h}" if h else "")] = dpad(h)
    glyphs["pad_ls"] = stick("L", False)
    glyphs["pad_rs"] = stick("R", False)
    glyphs["pad_l3"] = stick("L", True)
    glyphs["pad_r3"] = stick("R", True)
    for b in ["", "left", "right", "wheel"]:
        glyphs["mouse" + (f"_{b}" if b else "")] = mouse(b)
    for k in ["tap", "hold", "double", "drag", "swipe"]:
        glyphs[f"touch_{k}"] = touch(k)
    for name, im in glyphs.items():
        save(name, im)
    # Planche de contrôle (non importée : hors de assets/).
    sheet = Image.new("RGBA", (len(glyphs) * 50, 40), (26, 12, 20, 255))
    for i, im in enumerate(glyphs.values()):
        big = im.resize((im.width * SCALE, im.height * SCALE), Image.NEAREST)
        sheet.alpha_composite(big, (i * 50 + 2, 4))
    sheet.save(ROOT / "docs" / "glyphs_sheet.png")
    print(f"Glyphes : {len(glyphs)} → {OUT}")


if __name__ == "__main__":
    main()
