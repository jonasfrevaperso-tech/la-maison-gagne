#!/usr/bin/env python3
"""Générateur d'icônes pixel art (64×64) pour grigris, cases, Fortune, contrats, éditions, sceaux.

Style (docs/ART_BIBLE.md) : motif dessiné sur une grille 32×32 avec la palette fixe, ombrage
en deux tons, contour encre 1 px, médaillon art déco dont le liseré indique la rareté, puis
agrandissement ×2 au plus proche voisin. Chaque entrée de data/ référence un `icon` ; le motif
est choisi via tools/icon_specs.json (id → motif + couleur), sinon déduit du premier tag.

Usage :
  python3 tools/gen_icons.py                 # toutes les icônes → assets/icons/
  python3 tools/gen_icons.py --sheet 10      # planche de validation du style (10 icônes)
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import pathlib

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "icons"
SPECS = ROOT / "tools" / "icon_specs.json"
GRID = 32
SCALE = 2

PAL = {
    "ink": (10, 8, 13), "velvet_deep": (26, 12, 20), "velvet": (58, 18, 40), "felt": (13, 59, 42),
    "gold": (212, 175, 55), "gold_light": (242, 210, 122), "gold_dark": (138, 109, 30), "ivory": (245, 240, 230),
    "smoke": (107, 98, 117), "smoke_dark": (43, 38, 49), "magenta": (255, 46, 136), "cyan": (41, 224, 255),
    "emerald": (46, 230, 168), "red": (200, 16, 46), "black": (42, 37, 50), "green": (15, 138, 79),
    "danger": (255, 77, 61), "blue": (61, 139, 255), "mult": (255, 59, 92), "purple": (176, 58, 255),
    "orange": (255, 138, 61), "glass": (191, 233, 255), "steel": (154, 164, 181), "brown": (110, 70, 40),
}
RARITY_RIM = {"common": "smoke", "rare": "cyan", "legendary": "gold_light", "cursed": "purple"}


def shade(c: tuple, f: float) -> tuple:
    return tuple(max(0, min(255, int(v * f))) for v in c)


class Canvas:
    """Grille 32×32 RGBA avec primitives sans anticrénelage."""

    def __init__(self) -> None:
        self.img = Image.new("RGBA", (GRID, GRID), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def px(self, x: int, y: int, c: str | tuple) -> None:
        if 0 <= x < GRID and 0 <= y < GRID:
            self.img.putpixel((x, y), _rgba(c))

    def rect(self, x0, y0, x1, y1, c, fill=True):
        self.d.rectangle((x0, y0, x1, y1), fill=_rgba(c) if fill else None, outline=None if fill else _rgba(c))

    def ellipse(self, x0, y0, x1, y1, c, fill=True):
        self.d.ellipse((x0, y0, x1, y1), fill=_rgba(c) if fill else None, outline=None if fill else _rgba(c))

    def poly(self, pts, c):
        self.d.polygon(pts, fill=_rgba(c))

    def line(self, pts, c, w=1):
        self.d.line(pts, fill=_rgba(c), width=w)

    def text_digit(self, s: str, x: int, y: int, c) -> None:
        """Chiffres 3×5 pour les petits numéros."""
        font = {
            "0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
            "2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "111", "001", "111"],
            "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
            "6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
            "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
            "x": ["000", "101", "010", "101", "000"], "+": ["000", "010", "111", "010", "000"],
            "%": ["101", "001", "010", "100", "101"], "$": ["011", "110", "010", "011", "110"],
        }
        cx = x
        for ch in s:
            g = font.get(ch)
            if g is None:
                cx += 2
                continue
            for j, row in enumerate(g):
                for i, b in enumerate(row):
                    if b == "1":
                        self.px(cx + i, y + j, c)
            cx += 4


def _c(c):
    return PAL[c] if isinstance(c, str) else c


def _rgba(c) -> tuple:
    v = _c(c)
    return tuple(v) if len(v) == 4 else (*v, 255)


# --------------------------------------------------------------------------- motifs
# Chaque motif dessine dans la zone centrale (≈ 6..26) avec une couleur principale `a`
# et une secondaire `b`.

def m_chip(cv, a, b):
    cv.ellipse(7, 7, 24, 24, a)
    cv.ellipse(10, 10, 21, 21, b)
    for k in range(8):
        ang = k * math.pi / 4
        x, y = 16 + math.cos(ang) * 7.5, 16 + math.sin(ang) * 7.5
        cv.px(int(round(x)) - 1, int(round(y)) - 1, "ivory")


def m_coin(cv, a, b):
    cv.ellipse(8, 7, 23, 24, a)
    cv.ellipse(10, 9, 21, 22, shade(_c(a), 0.8))
    cv.text_digit("$", 14, 13, b)


def m_ribbon(cv, a, b):
    cv.poly([(16, 9), (9, 5), (8, 13)], a)
    cv.poly([(16, 9), (23, 5), (24, 13)], a)
    cv.ellipse(13, 7, 19, 12, shade(_c(a), 0.75))
    cv.poly([(15, 11), (10, 25), (13, 24), (16, 13)], a)
    cv.poly([(17, 11), (22, 25), (19, 24), (16, 13)], shade(_c(a), 0.85))


def m_cat(cv, a, b):
    cv.ellipse(9, 12, 23, 26, a)
    cv.poly([(10, 14), (10, 6), (15, 11)], a)
    cv.poly([(22, 14), (22, 6), (17, 11)], a)
    cv.px(13, 17, b); cv.px(19, 17, b); cv.px(13, 18, b); cv.px(19, 18, b)
    cv.px(16, 20, "magenta")


def m_sock(cv, a, b):
    cv.rect(12, 5, 18, 18, a)
    cv.poly([(12, 18), (18, 18), (24, 22), (24, 26), (12, 26)], a)
    for y in (8, 12):
        cv.line([(12, y), (18, y)], b)


def m_duck(cv, a, b):
    cv.ellipse(8, 14, 24, 25, a)
    cv.ellipse(15, 7, 23, 15, a)
    cv.poly([(23, 10), (27, 11), (23, 13)], "orange")
    cv.px(20, 10, "ink")


def m_glove(cv, a, b):
    cv.rect(10, 13, 21, 25, a)
    for i, x in enumerate((10, 13, 16, 19)):
        cv.rect(x, 6 + (i % 2), x + 2, 14, a)
    cv.poly([(21, 15), (25, 11), (26, 13), (22, 19)], a)
    cv.rect(10, 22, 21, 25, b)


def m_razor(cv, a, b):
    cv.poly([(6, 18), (22, 6), (25, 9), (9, 21)], a)
    cv.line([(9, 21), (6, 18)], b)
    cv.rect(18, 18, 26, 22, "brown")


def m_bars(cv, a, b):
    for i, h in enumerate((10, 14, 18)):
        cv.rect(7 + i * 6, 26 - h, 11 + i * 6, 26, a if i != 1 else b)


def m_horseshoe(cv, a, b):
    cv.ellipse(7, 6, 25, 26, a)
    cv.ellipse(11, 10, 21, 22, (0, 0, 0, 0))
    cv.d.ellipse((11, 10, 21, 22), fill=(0, 0, 0, 0))
    cv.rect(11, 18, 21, 27, (0, 0, 0, 0))
    cv.d.rectangle((11, 18, 21, 27), fill=(0, 0, 0, 0))
    for y in (10, 15, 20):
        cv.px(9, y, b); cv.px(23, y, b)


def m_eggs(cv, a, b):
    cv.rect(6, 15, 25, 24, "brown")
    for i in range(3):
        cv.ellipse(7 + i * 6, 9, 12 + i * 6, 17, a)


def m_column(cv, a, b):
    cv.rect(10, 9, 21, 24, a)
    cv.rect(8, 6, 23, 9, b)
    cv.rect(8, 24, 23, 27, b)
    for x in (12, 15, 18):
        cv.line([(x, 10), (x, 23)], shade(_c(a), 0.75))


def m_cigar(cv, a, b):
    cv.poly([(5, 20), (22, 11), (25, 15), (8, 24)], "brown")
    cv.poly([(16, 14), (19, 12), (21, 16), (18, 18)], a)
    for k in range(3):
        cv.px(24 + k, 10 - k * 2, "smoke")


def m_piggy(cv, a, b):
    cv.ellipse(6, 10, 25, 24, a)
    cv.ellipse(22, 14, 27, 19, shade(_c(a), 0.8))
    cv.rect(9, 23, 11, 26, a); cv.rect(19, 23, 21, 26, a)
    cv.rect(13, 9, 18, 10, "ink")
    cv.px(19, 14, "ink")


def m_die(cv, a, b):
    cv.rect(7, 7, 24, 24, a)
    for x, y in ((11, 11), (20, 20), (15, 15), (20, 11), (11, 20)):
        cv.rect(x - 1, y - 1, x, y, b)


def m_shield(cv, a, b):
    cv.poly([(16, 5), (25, 9), (24, 18), (16, 26), (8, 18), (7, 9)], a)
    cv.text_digit("0", 15, 12, b)


def m_flames(cv, a, b):
    for i, x in enumerate((8, 14, 20)):
        cv.poly([(x, 25), (x + 2, 10 + i), (x + 5, 25)], a if i % 2 == 0 else b)


def m_arrow_near(cv, a, b):
    cv.ellipse(15, 15, 24, 24, b)
    cv.line([(6, 8), (17, 17)], a, 2)
    cv.poly([(17, 13), (19, 19), (13, 17)], a)


def m_pocket(cv, a, b):
    cv.poly([(8, 9), (24, 9), (22, 25), (10, 25)], a)
    cv.line([(8, 9), (24, 9)], b, 2)
    cv.px(16, 17, b)


def m_monocle(cv, a, b):
    cv.ellipse(7, 7, 22, 22, a)
    cv.ellipse(9, 9, 20, 20, "glass")
    cv.line([(20, 20), (26, 27)], b)


def m_bag(cv, a, b):
    cv.ellipse(7, 11, 24, 26, a)
    cv.poly([(12, 11), (14, 6), (18, 6), (20, 11)], a)
    cv.text_digit("$", 14, 15, b)


def m_blueprint(cv, a, b):
    cv.rect(6, 7, 25, 24, a)
    for x in range(8, 25, 4):
        cv.line([(x, 8), (x, 23)], shade(_c(a), 1.3))
    cv.rect(10, 11, 17, 18, b, fill=False)
    cv.rect(18, 15, 22, 20, b, fill=False)


def m_tooth(cv, a, b):
    cv.poly([(9, 8), (23, 8), (22, 18), (19, 26), (16, 19), (13, 26), (10, 18)], a)
    cv.px(12, 10, "ivory")


def m_heart(cv, a, b):
    cv.ellipse(7, 8, 16, 17, a)
    cv.ellipse(15, 8, 24, 17, a)
    cv.poly([(8, 14), (23, 14), (16, 25)], a)
    cv.line([(13, 10), (17, 16), (14, 21)], b)


def m_metronome(cv, a, b):
    cv.poly([(11, 26), (21, 26), (18, 6), (14, 6)], a)
    cv.line([(16, 24), (22, 8)], b, 2)


def m_ladder(cv, a, b):
    cv.line([(10, 5), (10, 26)], a, 2)
    cv.line([(21, 5), (21, 26)], a, 2)
    for y in range(8, 26, 5):
        cv.line([(10, y), (21, y)], b)


def m_magnet(cv, a, b):
    cv.rect(8, 8, 12, 22, a); cv.rect(19, 8, 23, 22, a)
    cv.rect(8, 22, 23, 26, a)
    cv.rect(8, 5, 12, 8, b); cv.rect(19, 5, 23, 8, b)


def m_stack(cv, a, b):
    for i in range(5):
        cv.ellipse(9, 20 - i * 3, 22, 25 - i * 3, a if i % 2 == 0 else b)


def m_dot(cv, a, b):
    cv.ellipse(12, 12, 19, 19, a)


def m_eye(cv, a, b):
    cv.ellipse(6, 11, 25, 21, "ivory")
    cv.ellipse(12, 11, 19, 20, a)
    cv.ellipse(14, 13, 17, 18, "ink")
    cv.line([(6, 10), (25, 10)], b)


def m_key(cv, a, b):
    cv.ellipse(6, 6, 15, 15, a)
    cv.ellipse(9, 9, 12, 12, (0, 0, 0, 0))
    cv.d.ellipse((9, 9, 12, 12), fill=(0, 0, 0, 0))
    cv.line([(13, 13), (25, 25)], a, 3)
    cv.rect(20, 20, 23, 23, b)


def m_hand(cv, a, b):
    m_glove(cv, a, b)
    cv.ellipse(12, 16, 19, 22, b)


def m_snake_ring(cv, a, b):
    cv.ellipse(6, 6, 25, 25, a)
    cv.d.ellipse((10, 10, 21, 21), fill=(0, 0, 0, 0))
    cv.ellipse(20, 5, 26, 11, b)
    cv.px(23, 7, "ink")


def m_chandelier(cv, a, b):
    cv.line([(16, 3), (16, 9)], a)
    cv.poly([(7, 12), (25, 12), (21, 18), (11, 18)], a)
    for x in (8, 13, 18, 23):
        cv.poly([(x, 18), (x + 2, 18), (x + 1, 24)], b)


def m_scroll(cv, a, b):
    cv.rect(8, 7, 23, 25, a)
    cv.ellipse(6, 5, 11, 10, shade(_c(a), 0.8)); cv.ellipse(20, 22, 25, 27, shade(_c(a), 0.8))
    for y in (11, 14, 17):
        cv.line([(11, y), (20, y)], b)


def m_fangs(cv, a, b):
    cv.ellipse(6, 7, 25, 22, a)
    cv.poly([(11, 17), (14, 17), (12, 25)], "ivory")
    cv.poly([(18, 17), (21, 17), (20, 25)], "ivory")
    cv.px(12, 12, b); cv.px(19, 12, b)


def m_zero(cv, a, b):
    cv.ellipse(8, 5, 23, 26, a)
    cv.ellipse(11, 9, 20, 22, b)


def m_mirror(cv, a, b):
    cv.ellipse(8, 5, 23, 22, a)
    cv.ellipse(10, 7, 21, 20, "glass")
    cv.line([(12, 9), (16, 14), (14, 18)], "ink")
    cv.rect(14, 22, 17, 27, b)


def m_card(cv, a, b):
    cv.rect(9, 5, 23, 26, "ivory")
    cv.rect(10, 6, 22, 25, a)
    cv.poly([(16, 10), (20, 15), (16, 21), (12, 15)], b)


def m_star(cv, a, b):
    pts = []
    for k in range(10):
        r = 10 if k % 2 == 0 else 4
        ang = -math.pi / 2 + k * math.pi / 5
        pts.append((16 + math.cos(ang) * r, 16 + math.sin(ang) * r))
    cv.poly(pts, a)


def m_bolt(cv, a, b):
    cv.poly([(18, 4), (9, 17), (15, 17), (12, 28), (23, 13), (17, 13)], a)


def m_clock(cv, a, b):
    cv.ellipse(7, 7, 24, 24, a)
    cv.ellipse(9, 9, 22, 22, "ivory")
    cv.line([(16, 16), (16, 11)], "ink")
    cv.line([(16, 16), (20, 17)], "ink")


def m_skull(cv, a, b):
    cv.ellipse(8, 6, 23, 21, a)
    cv.rect(11, 19, 20, 25, a)
    cv.rect(11, 12, 14, 15, "ink"); cv.rect(17, 12, 20, 15, "ink")
    for x in (12, 15, 18):
        cv.px(x, 23, "ink")


def m_bell(cv, a, b):
    cv.poly([(10, 21), (12, 9), (16, 6), (20, 9), (22, 21)], a)
    cv.rect(8, 21, 23, 23, a)
    cv.ellipse(14, 23, 18, 27, b)


def m_wheel(cv, a, b):
    cv.ellipse(5, 5, 26, 26, "gold_dark")
    for k in range(12):
        ang0 = k * math.pi / 6
        ang1 = ang0 + math.pi / 6
        pts = [(16, 16), (16 + math.cos(ang0) * 10, 16 + math.sin(ang0) * 10), (16 + math.cos(ang1) * 10, 16 + math.sin(ang1) * 10)]
        cv.poly(pts, a if k % 2 == 0 else b)
    cv.ellipse(13, 13, 18, 18, "gold")


def m_sector(cv, a, b):
    """Case de roue (cases spéciales)."""
    cv.poly([(6, 8), (26, 8), (21, 26), (11, 26)], "gold_dark")
    cv.poly([(8, 10), (24, 10), (20, 24), (12, 24)], a)
    cv.ellipse(13, 13, 19, 19, b)


def m_seal(cv, a, b):
    for k in range(12):
        ang = k * math.pi / 6
        cv.ellipse(int(16 + math.cos(ang) * 8) - 3, int(16 + math.sin(ang) * 8) - 3, int(16 + math.cos(ang) * 8) + 3, int(16 + math.sin(ang) * 8) + 3, a)
    cv.ellipse(8, 8, 23, 23, a)
    cv.ellipse(11, 11, 20, 20, shade(_c(a), 0.75))
    cv.px(15, 15, b); cv.px(16, 16, b)


def m_gem(cv, a, b):
    cv.poly([(16, 5), (25, 13), (16, 27), (7, 13)], a)
    cv.poly([(16, 5), (25, 13), (16, 13)], shade(_c(a), 1.25))
    cv.line([(7, 13), (25, 13)], b)


def m_plus(cv, a, b):
    cv.rect(13, 6, 18, 25, a); cv.rect(6, 13, 25, 18, a)


def m_times(cv, a, b):
    cv.line([(8, 8), (23, 23)], a, 4); cv.line([(23, 8), (8, 23)], a, 4)


def m_flask(cv, a, b):
    cv.rect(13, 5, 18, 12, "glass")
    cv.poly([(13, 12), (18, 12), (25, 26), (6, 26)], "glass")
    cv.poly([(10, 19), (21, 19), (25, 26), (6, 26)], a)


def m_moon(cv, a, b):
    cv.ellipse(7, 6, 24, 25, a)
    cv.d.ellipse((12, 4, 28, 22), fill=(0, 0, 0, 0))


def m_crown(cv, a, b):
    cv.poly([(6, 24), (6, 10), (11, 16), (16, 7), (21, 16), (26, 10), (26, 24)], a)
    for x in (10, 16, 22):
        cv.px(x, 20, b)


def m_mask(cv, a, b):
    cv.poly([(5, 10), (27, 10), (25, 20), (18, 21), (16, 17), (14, 21), (7, 20)], a)
    cv.ellipse(9, 12, 14, 16, "ink"); cv.ellipse(18, 12, 23, 16, "ink")


def m_bottle(cv, a, b):
    cv.rect(14, 4, 17, 10, a)
    cv.rect(10, 10, 21, 27, a)
    cv.rect(10, 15, 21, 20, b)


def m_umbrella(cv, a, b):
    cv.poly([(5, 15), (16, 5), (27, 15)], a)
    cv.line([(16, 15), (16, 25)], b)
    cv.line([(16, 25), (13, 26)], b)


def m_feather(cv, a, b):
    cv.poly([(8, 26), (22, 6), (25, 8), (12, 24)], a)
    cv.line([(8, 26), (23, 7)], b)


def m_rose(cv, a, b):
    cv.ellipse(10, 6, 22, 17, a)
    cv.line([(16, 17), (16, 27)], "emerald")
    cv.poly([(16, 21), (21, 19), (17, 23)], "emerald")


def m_spider(cv, a, b):
    cv.ellipse(12, 11, 20, 21, a)
    for y in (12, 15, 18):
        cv.line([(12, y), (6, y - 3)], a); cv.line([(20, y), (26, y - 3)], a)
    cv.px(14, 14, b); cv.px(17, 14, b)


def m_hat(cv, a, b):
    cv.rect(10, 7, 21, 21, a)
    cv.rect(5, 21, 26, 24, a)
    cv.rect(10, 17, 21, 19, b)


def m_scale(cv, a, b):
    cv.line([(16, 5), (16, 26)], a)
    cv.line([(7, 9), (25, 9)], a)
    cv.poly([(4, 17), (10, 17), (7, 11)], b); cv.poly([(22, 17), (28, 17), (25, 11)], b)
    cv.rect(11, 25, 21, 27, a)


def m_anchor(cv, a, b):
    cv.line([(16, 7), (16, 25)], a, 2)
    cv.ellipse(13, 3, 19, 9, a)
    cv.d.arc((7, 14, 25, 27), 0, 180, fill=(*_c(a), 255), width=2)
    cv.line([(11, 11), (21, 11)], b)


MOTIFS = {k[2:]: v for k, v in globals().items() if k.startswith("m_") and callable(v)}

TAG_MOTIF = {
    "mult": "plus", "xmult": "times", "chips": "chip", "economy": "coin", "money": "coin", "color": "ribbon",
    "parity": "die", "bets": "chip", "straight": "razor", "outside": "bars", "split": "horseshoe", "dozen": "eggs",
    "column": "column", "zero": "zero", "safety": "shield", "streak": "flames", "ball": "dot", "precision": "monocle",
    "control": "magnet", "budget": "pocket", "growth": "ladder", "decay": "cigar", "chance": "die", "copy": "blueprint",
    "retrigger": "wheel", "pockets": "sector", "golden": "coin", "glass": "heart", "slots": "pocket", "interest": "bag",
    "repeat": "die", "destroy": "skull", "curse": "skull", "debt": "scroll", "ghost": "mask", "spins": "clock",
}
COLOR_CYCLE = ["magenta", "cyan", "emerald", "gold", "mult", "blue", "orange", "purple", "red", "ivory"]


def load_specs() -> dict:
    """Fusionne tools/icon_specs*.json (un fichier par lot de contenu)."""
    out: dict = {}
    for f in sorted(SPECS.parent.glob("icon_specs*.json")):
        out.update(json.loads(f.read_text(encoding="utf-8")))
    return out


def entries(cat_dir: str, prefix: str) -> list:
    out = []
    for f in sorted((ROOT / "data" / cat_dir).glob(prefix + "*.json")):
        data = json.loads(f.read_text(encoding="utf-8"))
        out.extend(data if isinstance(data, list) else data.get("entries", []))
    return out


def stable_pick(key: str, seq: list):
    h = int(hashlib.sha1(key.encode()).hexdigest(), 16)
    return seq[h % len(seq)]


def frame(cv: Canvas, rim: str, kind: str) -> None:
    """Médaillon art déco : fond velours, liseré de rareté, rayons."""
    if kind == "fortune":
        cv.rect(2, 1, 29, 30, rim)
        cv.rect(3, 2, 28, 29, "velvet_deep")
        cv.rect(5, 4, 26, 27, "velvet")
        return
    if kind == "contract":
        cv.rect(3, 2, 28, 29, "ivory")
        cv.rect(4, 3, 27, 28, (232, 222, 200))
        return
    cv.ellipse(1, 1, 30, 30, rim)
    cv.ellipse(2, 2, 29, 29, "velvet_deep")
    for k in range(16):
        ang = k * math.pi / 8
        x, y = 16 + math.cos(ang) * 13, 16 + math.sin(ang) * 13
        cv.px(int(round(x)) - 1 + (k % 2), int(round(y)) - 1, shade(PAL["velvet"], 1.4))


def outline_and_shade(img: Image.Image) -> Image.Image:
    """Contour encre extérieur + reflet en haut à gauche des formes opaques."""
    src = img.copy()
    w, h = img.size
    out = img.copy()
    for y in range(h):
        for x in range(w):
            a = src.getpixel((x, y))[3]
            if a == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and src.getpixel((nx, ny))[3] > 0:
                        out.putpixel((x, y), (*PAL["ink"], 255))
                        break
            else:
                up = src.getpixel((x, y - 1))[3] if y > 0 else 0
                left = src.getpixel((x - 1, y))[3] if x > 0 else 0
                if up == 0 or left == 0:
                    r, g, b, _ = src.getpixel((x, y))
                    out.putpixel((x, y), (*shade((r, g, b), 1.25), 255))
                down = src.getpixel((x, y + 1))[3] if y < h - 1 else 0
                right = src.getpixel((x + 1, y))[3] if x < w - 1 else 0
                if down == 0 or right == 0:
                    r, g, b, _ = src.getpixel((x, y))
                    out.putpixel((x, y), (*shade((r, g, b), 0.7), 255))
    return out


def render(entry: dict, kind: str, specs: dict) -> Image.Image:
    eid = entry.get("icon", entry["id"])
    spec = specs.get(eid, {})
    tags = entry.get("tags", [])
    motif = spec.get("motif") or (TAG_MOTIF.get(tags[0]) if tags else None) or {"pocket": "sector", "seal": "seal", "edition": "gem", "fortune": "card", "contract": "scroll"}.get(kind, "chip")
    a = spec.get("a") or stable_pick(eid, COLOR_CYCLE)
    b = spec.get("b") or ("ivory" if a not in ("ivory", "gold") else "velvet")
    rim = RARITY_RIM.get(entry.get("rarity", "common"), "gold")
    if kind == "pocket":
        rim = "gold"
    base = Canvas()
    frame(base, rim, kind)
    layer = Canvas()
    MOTIFS[motif](layer, a, b)
    layer.img = outline_and_shade(layer.img)
    base.img.alpha_composite(layer.img)
    if kind == "contract":
        base.rect(20, 22, 26, 27, "red")
    return base.img.resize((GRID * SCALE, GRID * SCALE), Image.NEAREST)


def all_items() -> list:
    items = []
    for e in entries("grigris", "grigris"):
        items.append((e, "grigri"))
    for e in entries("pockets", "pocket_types"):
        items.append((e, "pocket"))
    for e in entries("pockets", "editions"):
        items.append((e, "edition"))
    for e in entries("pockets", "seals"):
        items.append((e, "seal"))
    for e in entries("fortunes", "fortunes"):
        items.append((e, "fortune"))
    for e in entries("contracts", "contracts"):
        items.append((e, "contract"))
    return items


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet", type=int, default=0, help="planche de validation des N premières icônes")
    args = ap.parse_args()
    specs = load_specs()
    OUT.mkdir(parents=True, exist_ok=True)
    items = all_items()
    if args.sheet:
        n = args.sheet
        sheet = Image.new("RGBA", (n * 72 + 8, 80), (*PAL["ink"], 255))
        for i, (e, kind) in enumerate(items[:n]):
            sheet.alpha_composite(render(e, kind, specs), (8 + i * 72, 8))
        sheet.save(OUT / "_style_sheet.png")
        print(f"Planche de style : {OUT / '_style_sheet.png'}")
        return
    count = 0
    for e, kind in items:
        icon_id = e.get("icon", e["id"])
        render(e, kind, specs).save(OUT / f"{icon_id}.png")
        count += 1
    print(f"{count} icônes générées dans {OUT}")


if __name__ == "__main__":
    main()
