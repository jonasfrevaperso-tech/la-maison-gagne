#!/usr/bin/env python3
"""Illustrations pixel art de la cinématique d'intro (v1.5), générées procéduralement.

Chaque plan est découpé en calques 320×180 (RGBA) affichés agrandis ×6 sans lissage par
IntroCutscene : `bg` (fond), `mid` (décor), `fg` (premier plan, parallaxe), plus des calques
animés (`glow` qui scintille, `stamp`, portes…). Palette réduite et tramage ordonné (Bayer 4×4).

Usage : uv run --with pillow --with numpy python3 tools/gen_cutscene.py
"""

from __future__ import annotations

import math
import pathlib
import random

import numpy as np
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "cutscene"
W, H = 320, 180

INK = (13, 10, 18)
NIGHT = (22, 18, 38)
PLUM = (48, 30, 58)
WINE = (96, 30, 56)
RED = (200, 50, 60)
GOLD = (212, 175, 55)
GOLD_L = (242, 210, 122)
GOLD_D = (130, 96, 30)
CYAN = (41, 224, 255)
MAGENTA = (255, 46, 136)
IVORY = (245, 240, 230)
SMOKE = (138, 132, 148)
BRICK = (70, 36, 40)
BRICK_D = (44, 24, 30)
WOOD = (92, 54, 30)
WOOD_D = (56, 32, 18)
PAPER = (226, 210, 170)
PAPER_D = (190, 168, 120)

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def canvas() -> Image.Image:
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def dither_gradient(img: Image.Image, box: tuple[int, int, int, int], top: tuple, bottom: tuple, steps: int = 6) -> None:
    """Dégradé vertical quantifié en `steps` bandes, transitions tramées."""
    x0, y0, x1, y1 = box
    px = img.load()
    for y in range(y0, y1):
        u = (y - y0) / max(y1 - y0 - 1, 1) * (steps - 1)
        for x in range(x0, x1):
            k = int(u + BAYER[y % 4, x % 4] - 0.5 + 0.5)
            k = max(0, min(steps - 1, k))
            f = k / (steps - 1)
            px[x, y] = tuple(int(top[i] + (bottom[i] - top[i]) * f) for i in range(3)) + (255,)


def rect(d: ImageDraw.ImageDraw, x0, y0, x1, y1, col) -> None:
    d.rectangle([int(x0), int(y0), int(x1), int(y1)], fill=col)


def dither_rect(img: Image.Image, box, col_a, col_b, density: float) -> None:
    """Remplit une zone d'un mélange tramé de deux couleurs (densité de b entre 0 et 1)."""
    px = img.load()
    x0, y0, x1, y1 = [int(v) for v in box]
    for y in range(max(y0, 0), min(y1, H)):
        for x in range(max(x0, 0), min(x1, W)):
            px[x, y] = (col_b if BAYER[y % 4, x % 4] < density else col_a) + (255,)


def glow_disc(img: Image.Image, cx, cy, r, col, strength=1.0) -> None:
    """Halo tramé (alpha) autour d'une source de lumière."""
    px = img.load()
    for y in range(max(0, int(cy - r)), min(H, int(cy + r) + 1)):
        for x in range(max(0, int(cx - r)), min(W, int(cx + r) + 1)):
            dist = math.hypot(x - cx, y - cy) / r
            if dist >= 1:
                continue
            a = (1 - dist) ** 1.6 * strength
            if BAYER[y % 4, x % 4] < a:
                old = px[x, y]
                if old[3] == 0:
                    px[x, y] = col + (int(150 * min(a * 1.5, 1)),)
                else:
                    px[x, y] = tuple(min(255, int(old[i] * 0.5 + col[i] * 0.6)) for i in range(3)) + (old[3],)


def save(img: Image.Image, name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / f"{name}.png")


# --------------------------------------------------------------------------- 1. la rue sous la pluie


def shot_street(rng: random.Random) -> None:
    bg = canvas()
    dither_gradient(bg, (0, 0, W, H), (8, 6, 20), (52, 24, 60), 7)
    d = ImageDraw.Draw(bg)
    # Lune voilée.
    glow_disc(bg, 262, 30, 26, (180, 170, 200), 0.6)
    d.ellipse([254, 22, 270, 38], fill=(200, 196, 214, 255))
    # Silhouettes d'immeubles lointains, fenêtres éclairées.
    x = -4
    while x < W:
        w = rng.randint(18, 40)
        h = rng.randint(50, 110)
        rect(d, x, H - h, x + w, H, (20, 14, 30, 255))
        for wy in range(H - h + 6, H - 20, 8):
            for wx in range(x + 3, x + w - 4, 6):
                if rng.random() < 0.18:
                    rect(d, wx, wy, wx + 2, wy + 3, (230, 190, 90, 255) if rng.random() < 0.8 else (120, 200, 230, 255))
        x += w + rng.randint(0, 3)
    save(bg, "street_bg")

    mid = canvas()
    d = ImageDraw.Draw(mid)
    # Façade art déco du casino : corps, gradins, pilastres.
    fx0, fx1 = 70, 250
    rect(d, fx0, 46, fx1, 150, BRICK + (255,))
    dither_rect(mid, (fx0, 46, fx1, 150), BRICK, BRICK_D, 0.35)
    d = ImageDraw.Draw(mid)
    for i, (a, b) in enumerate(((fx0 + 20, fx1 - 20), (fx0 + 40, fx1 - 40), (fx0 + 62, fx1 - 62))):
        rect(d, a, 46 - 8 * (i + 1), b, 46 - 8 * i, (BRICK_D if i % 2 else BRICK) + (255,))
    rect(d, fx0 + 80, 14, fx1 - 80, 22, GOLD_D + (255,))
    for px_ in range(fx0 + 6, fx1 - 4, 22):
        rect(d, px_, 50, px_ + 5, 150, (58, 30, 34, 255))
        rect(d, px_ + 1, 50, px_ + 2, 150, (110, 60, 60, 255))
    # Marquise et portes condamnées.
    rect(d, fx0 + 30, 100, fx1 - 30, 106, GOLD_D + (255,))
    rect(d, fx0 + 30, 106, fx1 - 30, 108, (60, 40, 20, 255))
    rect(d, 136, 110, 184, 150, (24, 16, 18, 255))
    for k in range(4):
        y = 114 + k * 9
        d.polygon([(132, y + (3 if k % 2 else 0)), (188, y + (0 if k % 2 else 3)), (188, y + 4 + (0 if k % 2 else 3)), (132, y + 4 + (3 if k % 2 else 0))], fill=WOOD + (255,))
        d.point([(140, y + 2), (180, y + 2)], fill=(160, 150, 140, 255))
    # Affiches déchirées.
    for (ax, ay) in ((92, 112), (204, 116)):
        rect(d, ax, ay, ax + 18, ay + 26, PAPER_D + (255,))
        rect(d, ax + 2, ay + 3, ax + 16, ay + 9, WINE + (255,))
        d.polygon([(ax + 18, ay + 18), (ax + 10, ay + 26), (ax + 18, ay + 26)], fill=BRICK + (255,))
    # Fenêtres hautes aveugles.
    for wx in range(fx0 + 16, fx1 - 20, 30):
        rect(d, wx, 62, wx + 14, 88, (16, 12, 22, 255))
        rect(d, wx, 62, wx + 14, 64, GOLD_D + (255,))
    # Trottoir mouillé.
    rect(d, 0, 150, W, 180, (30, 26, 40, 255))
    dither_rect(mid, (0, 150, W, 180), (30, 26, 40), (44, 36, 58), 0.3)
    save(mid, "street_mid")

    # Néon « GRAND ZÉRO » (calque animé : il grésille).
    glow = canvas()
    d = ImageDraw.Draw(glow)
    letters = "GRAND ZERO"
    lx = 104
    for ch in letters:
        if ch == " ":
            lx += 6
            continue
        _neon_letter(d, ch, lx, 30, MAGENTA)
        lx += 11
    glow_disc(glow, 160, 34, 70, MAGENTA, 0.35)
    # Reflets roses dans les flaques.
    for k in range(18):
        x0 = rng.randint(90, 230)
        y0 = rng.randint(156, 176)
        rect(ImageDraw.Draw(glow), x0, y0, x0 + rng.randint(4, 14), y0, MAGENTA + (110,))
    save(glow, "street_glow")

    fg = canvas()
    d = ImageDraw.Draw(fg)
    # Réverbère.
    rect(d, 24, 40, 27, 168, (28, 26, 34, 255))
    d.polygon([(16, 40), (36, 40), (31, 32), (21, 32)], fill=(40, 36, 44, 255))
    rect(d, 20, 40, 32, 43, GOLD_L + (255,))
    glow_disc(fg, 26, 46, 30, GOLD_L, 0.5)
    # Silhouette de dos, manteau, chapeau, une enveloppe à la main.
    hx = 236
    d.polygon([(hx - 9, 178), (hx + 9, 178), (hx + 7, 134), (hx - 7, 134)], fill=(10, 8, 14, 255))
    d.ellipse([hx - 6, 122, hx + 6, 136], fill=(10, 8, 14, 255))
    rect(d, hx - 9, 121, hx + 9, 123, (10, 8, 14, 255))
    rect(d, hx - 5, 116, hx + 5, 122, (10, 8, 14, 255))
    rect(d, hx + 8, 150, hx + 14, 154, IVORY + (255,))
    rect(d, hx + 10, 151, hx + 11, 152, RED + (255,))
    save(fg, "street_fg")


# Police néon 5×7 (contours) pour quelques lettres.
_FONT = {
    "G": ["01110", "10000", "10000", "10111", "10001", "10001", "01110"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    "Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
}


def _neon_letter(d: ImageDraw.ImageDraw, ch: str, x: int, y: int, col) -> None:
    rows = _FONT[ch]
    for j, row in enumerate(rows):
        for i, c in enumerate(row):
            if c == "1":
                d.rectangle([x + i * 2, y + j * 2, x + i * 2 + 1, y + j * 2 + 1], fill=col + (255,))


# --------------------------------------------------------------------------- 2. l'enveloppe


def shot_envelope(rng: random.Random) -> None:
    bg = canvas()
    d = ImageDraw.Draw(bg)
    # Papier peint à motifs fanés.
    rect(d, 0, 0, W, H, (34, 22, 30, 255))
    for y in range(0, 120, 12):
        for x in range((y // 12) % 2 * 8, W, 16):
            d.polygon([(x, y + 6), (x + 4, y + 2), (x + 8, y + 6), (x + 4, y + 10)], fill=(46, 30, 40, 255))
    # Cadre photo au mur : grand-père (silhouette sépia).
    rect(d, 40, 22, 82, 74, GOLD_D + (255,))
    rect(d, 44, 26, 78, 70, (120, 96, 70, 255))
    d.ellipse([54, 34, 68, 50], fill=(70, 52, 40, 255))
    d.polygon([(48, 70), (74, 70), (70, 52), (52, 52)], fill=(70, 52, 40, 255))
    rect(d, 52, 30, 70, 34, (70, 52, 40, 255))
    # Ruban noir de deuil au coin du cadre.
    d.polygon([(74, 22), (82, 22), (82, 30)], fill=(10, 8, 12, 255))
    save(bg, "envelope_bg")

    mid = canvas()
    d = ImageDraw.Draw(mid)
    # Table en bois.
    rect(d, 0, 112, W, H, WOOD + (255,))
    for y in range(116, H, 7):
        d.line([(0, y), (W, y + rng.randint(-1, 1))], fill=WOOD_D + (255,))
    # Enveloppe et sceau doré (une roulette).
    ex, ey = 120, 118
    rect(d, ex, ey, ex + 80, ey + 46, PAPER + (255,))
    d.polygon([(ex, ey), (ex + 40, ey + 24), (ex + 80, ey)], fill=PAPER_D + (255,))
    d.line([(ex, ey), (ex + 40, ey + 24), (ex + 80, ey)], fill=(160, 140, 100, 255))
    d.ellipse([ex + 33, ey + 17, ex + 47, ey + 31], fill=GOLD + (255,))
    d.ellipse([ex + 36, ey + 20, ex + 44, ey + 28], fill=GOLD_D + (255,))
    for a in range(0, 360, 45):
        r = math.radians(a)
        d.point([(ex + 40 + round(math.cos(r) * 5), ey + 24 + round(math.sin(r) * 5))], fill=GOLD_L + (255,))
    # Bougie.
    rect(d, 236, 82, 246, 128, IVORY + (255,))
    rect(d, 236, 82, 238, 128, (210, 204, 190, 255))
    d.polygon([(233, 128), (249, 128), (252, 134), (230, 134)], fill=GOLD_D + (255,))
    save(mid, "envelope_mid")

    glow = canvas()
    d = ImageDraw.Draw(glow)
    d.ellipse([238, 70, 244, 82], fill=GOLD_L + (255,))
    d.ellipse([240, 74, 243, 81], fill=IVORY + (255,))
    glow_disc(glow, 241, 80, 80, (255, 190, 90), 0.45)
    save(glow, "envelope_glow")

    fg = canvas()
    d = ImageDraw.Draw(fg)
    # Mains qui entrent dans le champ (manches sombres).
    for side in (-1, 1):
        bx = 160 + side * 70
        d.polygon([(bx - side * 60, H), (bx + side * 4, 122), (bx + side * 22, 128), (bx - side * 30, H)], fill=(30, 24, 36, 255))
        d.ellipse([bx - 8, 114, bx + 12, 130], fill=(206, 160, 130, 255))
    save(fg, "envelope_fg")


# --------------------------------------------------------------------------- 3. la lettre


def shot_letter(rng: random.Random) -> None:
    bg = canvas()
    dither_gradient(bg, (0, 0, W, H), (40, 26, 22), (14, 10, 12), 5)
    d = ImageDraw.Draw(bg)
    # Feuille vieillie, bords irréguliers, taches.
    pts = [(48, 14), (272, 10), (276, 170), (44, 174)]
    d.polygon(pts, fill=PAPER + (255,))
    dither_rect(bg, (48, 14, 272, 170), PAPER, PAPER_D, 0.12)
    d = ImageDraw.Draw(bg)
    for _ in range(9):
        x, y, r = rng.randint(60, 260), rng.randint(20, 160), rng.randint(3, 9)
        d.ellipse([x - r, y - r, x + r, y + r], outline=(176, 150, 104, 255))
    # Lignes réglées pâles (le texte est écrit par le jeu).
    for y in range(40, 160, 14):
        d.line([(62, y), (258, y)], fill=(205, 188, 150, 255))
    rect(d, 70, 22, 110, 24, (176, 150, 104, 255))
    save(bg, "letter_bg")


# --------------------------------------------------------------------------- 4. le registre


def shot_ledger(rng: random.Random) -> None:
    bg = canvas()
    d = ImageDraw.Draw(bg)
    rect(d, 0, 0, W, H, (20, 12, 16, 255))
    # Registre ouvert : deux pages, reliure.
    rect(d, 24, 12, 160, 172, PAPER + (255,))
    rect(d, 160, 12, 296, 172, PAPER + (255,))
    rect(d, 156, 10, 164, 174, (90, 30, 40, 255))
    dither_rect(bg, (24, 12, 296, 172), PAPER, PAPER_D, 0.1)
    d = ImageDraw.Draw(bg)
    for page_x in (32, 168):
        rect(d, page_x, 22, page_x + 120, 26, (120, 40, 50, 255))
        for k, y in enumerate(range(34, 166, 9)):
            d.line([(page_x, y + 6), (page_x + 120, y + 6)], fill=(200, 180, 140, 255))
            # « Noms » griffonnés, barrés à l'encre rouge (dettes de la famille, génération après génération).
            n = rng.randint(30, 70)
            sx = page_x + 2
            while sx < page_x + n:
                h = rng.randint(1, 3)
                d.line([(sx, y + 4 - h), (sx + 2, y + 4)], fill=(60, 40, 40, 255))
                sx += 3
            amt = page_x + 92
            for j in range(4):
                rect(d, amt + j * 6, y + 1, amt + j * 6 + 3, y + 4, (60, 40, 40, 255))
            if k < 12:
                d.line([(page_x, y + 3), (page_x + n, y + 3)], fill=RED + (255,))
    save(bg, "ledger_bg")
    # La dernière ligne, vide, qui attend un nom (surlignée en or).
    glow = canvas()
    d = ImageDraw.Draw(glow)
    rect(d, 168, 151, 288, 160, GOLD_L + (120,))
    save(glow, "ledger_glow")
    # Tampon « IMPAYÉ » (calque qui s'abat).
    st = canvas()
    d = ImageDraw.Draw(st)
    d.rectangle([110, 70, 210, 104], outline=RED + (255,), width=3)
    d.rectangle([114, 74, 206, 100], outline=RED + (200,), width=1)
    _stamp_word(d, "IMPAYE", 120, 80)
    save(st, "ledger_stamp")


_STAMP = {
    "I": ["111", "010", "010", "010", "010", "010", "111"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "P": ["1110", "1001", "1001", "1110", "1000", "1000", "1000"],
    "A": ["0110", "1001", "1001", "1111", "1001", "1001", "1001"],
    "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
    "E": ["1111", "1000", "1000", "1110", "1000", "1000", "1111"],
}


def _stamp_word(d: ImageDraw.ImageDraw, word: str, x: int, y: int) -> None:
    for ch in word:
        rows = _STAMP[ch]
        for j, row in enumerate(rows):
            for i, c in enumerate(row):
                if c == "1":
                    d.rectangle([x + i * 2, y + j * 2, x + i * 2 + 1, y + j * 2 + 1], fill=RED + (255,))
        x += len(rows[0]) * 2 + 3


# --------------------------------------------------------------------------- 5. l'escalier


def shot_stairs(rng: random.Random) -> None:
    bg = canvas()
    dither_gradient(bg, (0, 0, W, H), (6, 4, 10), (26, 16, 30), 5)
    d = ImageDraw.Draw(bg)
    # Halo doré tout en bas : la porte, très loin.
    glow_disc(bg, 160, 150, 40, GOLD_L, 0.7)
    d.rectangle([154, 138, 166, 156], fill=GOLD_L + (255,))
    save(bg, "stairs_bg")

    mid = canvas()
    d = ImageDraw.Draw(mid)
    # Marches en perspective qui fuient vers le bas.
    vx, vy = 160, 140
    for k in range(14, 0, -1):
        f = k / 14
        y = vy - (vy - 0) * (f ** 1.6) + 40 * f
        hw = 12 + 150 * f
        nxt = (k - 1) / 14
        y2 = vy - (vy - 0) * (nxt ** 1.6) + 40 * nxt
        hw2 = 12 + 150 * nxt
        shade = int(30 + 50 * f)
        d.polygon([(vx - hw, H - y), (vx + hw, H - y), (vx + hw2, H - y2), (vx - hw2, H - y2)], fill=(shade, int(shade * 0.7), int(shade * 0.75), 255))
        d.line([(vx - hw, H - y), (vx + hw, H - y)], fill=(shade + 30, int((shade + 30) * 0.8), int((shade + 30) * 0.7), 255))
    # Murs.
    d.polygon([(0, 0), (40, 0), (150, 140), (140, 150), (0, 180)], fill=(30, 18, 26, 255))
    d.polygon([(W, 0), (W - 40, 0), (170, 140), (180, 150), (W, 180)], fill=(26, 16, 22, 255))
    save(mid, "stairs_mid")

    fg = canvas()
    d = ImageDraw.Draw(fg)
    # Rampe en laiton et silhouette qui descend.
    d.line([(W - 10, 20), (190, 150)], fill=GOLD_D + (255,), width=3)
    d.line([(W - 10, 18), (190, 148)], fill=GOLD + (255,), width=1)
    for k in range(6):
        x = W - 20 - k * 22
        y = 26 + k * 21
        d.line([(x, y), (x, y + 40)], fill=GOLD_D + (255,), width=1)
    hx, hy = 150, 104
    d.polygon([(hx - 7, hy + 40), (hx + 7, hy + 40), (hx + 5, hy + 8), (hx - 5, hy + 8)], fill=(8, 6, 10, 255))
    d.ellipse([hx - 5, hy - 2, hx + 5, hy + 9], fill=(8, 6, 10, 255))
    save(fg, "stairs_fg")


# --------------------------------------------------------------------------- 6. la porte dorée


def shot_door(rng: random.Random) -> None:
    bg = canvas()
    d = ImageDraw.Draw(bg)
    rect(d, 0, 0, W, H, (8, 4, 10, 255))
    # Derrière la porte : la roue géante qui luit dans le noir.
    cx, cy, r = 160, 96, 70
    glow_disc(bg, cx, cy, r + 30, GOLD, 0.45)
    d = ImageDraw.Draw(bg)
    d.ellipse([cx - r, cy - r * 0.45, cx + r, cy + r * 0.45], fill=(60, 30, 20, 255))
    n = 37
    for k in range(n):
        a0 = 2 * math.pi * k / n
        a1 = 2 * math.pi * (k + 1) / n
        col = (30, 140, 70) if k == 0 else (RED if k % 2 else (20, 16, 22))
        pts = [(cx + math.cos(a) * rr, cy + math.sin(a) * rr * 0.45) for a, rr in ((a0, r * 0.92), (a1, r * 0.92), (a1, r * 0.68), (a0, r * 0.68))]
        d.polygon(pts, fill=col + (255,))
    d.ellipse([cx - r * 0.66, cy - r * 0.3, cx + r * 0.66, cy + r * 0.3], fill=GOLD_D + (255,))
    d.ellipse([cx - 14, cy - 6, cx + 14, cy + 6], fill=GOLD + (255,))
    d.ellipse([cx - r * 0.9 + 10, cy - 3, cx - r * 0.9 + 15, cy + 2], fill=IVORY + (255,))
    save(bg, "door_bg")
    # Battants (deux calques qui s'écartent).
    for side, name in ((-1, "door_left"), (1, "door_right")):
        lay = canvas()
        d = ImageDraw.Draw(lay)
        x0, x1 = (60, 160) if side < 0 else (160, 260)
        rect(d, x0, 10, x1, 180, GOLD_D + (255,))
        dither_rect(lay, (x0, 10, x1, 180), GOLD_D, GOLD, 0.35)
        d = ImageDraw.Draw(lay)
        for k in range(3):
            rect(d, x0 + 10, 24 + k * 50, x1 - 10, 24 + k * 50 + 40, GOLD + (255,))
            rect(d, x0 + 14, 28 + k * 50, x1 - 14, 24 + k * 50 + 36, GOLD_D + (255,))
            # Rayons art déco.
            ccx = (x0 + x1) // 2
            for a in range(-60, 61, 30):
                rr = math.radians(a - 90)
                d.line([(ccx, 24 + k * 50 + 36), (ccx + math.cos(rr) * 26, 24 + k * 50 + 36 + math.sin(rr) * 26)], fill=GOLD_L + (255,))
        hx = x1 - 8 if side < 0 else x0 + 8
        d.ellipse([hx - 3, 94, hx + 3, 100], fill=GOLD_L + (255,))
        save(lay, name)
    fg = canvas()
    d = ImageDraw.Draw(fg)
    # Encadrement de la porte (au premier plan) et sol de marbre.
    rect(d, 0, 0, 60, 180, (24, 16, 20, 255))
    rect(d, 260, 0, W, 180, (24, 16, 20, 255))
    rect(d, 0, 0, W, 10, (24, 16, 20, 255))
    rect(d, 52, 0, 60, 180, GOLD_D + (255,))
    rect(d, 260, 0, 268, 180, GOLD_D + (255,))
    rect(d, 52, 4, 268, 10, GOLD_D + (255,))
    save(fg, "door_fg")


def main() -> None:
    rng = random.Random(1987)
    shot_street(rng)
    shot_envelope(rng)
    shot_letter(rng)
    shot_ledger(rng)
    shot_stairs(rng)
    shot_door(rng)
    print("Cinématique :", len(list(OUT.glob("*.png"))), "calques")


if __name__ == "__main__":
    main()
