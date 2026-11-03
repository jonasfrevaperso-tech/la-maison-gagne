#!/usr/bin/env python3
"""Illustrations pixel art des cartons d'annonce des épreuves du lancer (v1.5.2).

Une scène par épreuve, 160×100, palette du jeu et tramage ordonné (Bayer 4×4), affichée
agrandie sans lissage sur le carton (`ThrowTrial._draw_intro`). Générées procéduralement :
graine fixe, rejouable.

Usage : uv run --with pillow --with numpy python3 tools/gen_trial_art.py
"""

from __future__ import annotations

import math
import pathlib
import random

import numpy as np
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "trials"
W, H = 160, 100

INK = (13, 10, 18)
NIGHT = (22, 18, 38)
PLUM = (48, 30, 58)
VELVET = (58, 18, 40)
WINE = (96, 30, 56)
RED = (200, 40, 56)
RED_D = (120, 20, 34)
GOLD = (212, 175, 55)
GOLD_L = (242, 210, 122)
GOLD_D = (130, 96, 30)
CYAN = (41, 224, 255)
CYAN_D = (20, 110, 140)
MAGENTA = (255, 46, 136)
EMERALD = (46, 230, 168)
GREEN = (16, 124, 16)
GREEN_L = (60, 200, 70)
BLUE = (30, 110, 230)
YELLOW = (255, 200, 30)
IVORY = (245, 240, 230)
SMOKE = (138, 132, 148)
STEEL = (170, 176, 190)
STEEL_D = (90, 94, 108)
FELT = (13, 70, 48)
FELT_L = (21, 100, 66)
WOOD = (92, 54, 30)
WOOD_D = (56, 32, 18)
AMBER = (230, 150, 40)
FOAM = (250, 246, 225)

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGB", (W, H), INK)
    return img, ImageDraw.Draw(img)


def gradient(img: Image.Image, box, top, bottom, steps: int = 6) -> None:
    x0, y0, x1, y1 = box
    px = img.load()
    for y in range(max(y0, 0), min(y1, H)):
        u = (y - y0) / max(y1 - y0 - 1, 1) * (steps - 1)
        for x in range(max(x0, 0), min(x1, W)):
            k = max(0, min(steps - 1, int(u + BAYER[y % 4, x % 4] - 0.5 + 0.5)))
            f = k / (steps - 1)
            px[x, y] = tuple(int(top[i] + (bottom[i] - top[i]) * f) for i in range(3))


def glow(img: Image.Image, cx, cy, r, col, strength=0.8) -> None:
    px = img.load()
    for y in range(max(0, int(cy - r)), min(H, int(cy + r) + 1)):
        for x in range(max(0, int(cx - r)), min(W, int(cx + r) + 1)):
            dist = math.hypot(x - cx, y - cy) / r
            if dist < 1 and BAYER[y % 4, x % 4] < (1 - dist) ** 1.5 * strength:
                old = px[x, y]
                px[x, y] = tuple(min(255, int(old[i] * 0.55 + col[i] * 0.55)) for i in range(3))


def rect(d, x0, y0, x1, y1, col) -> None:
    d.rectangle([int(x0), int(y0), int(x1), int(y1)], fill=col)


def disc(d, cx, cy, r, col, outline=None) -> None:
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col, outline=outline)


def room(img, d, floor_y=72, floor=FELT, wall_top=NIGHT, wall_bottom=VELVET) -> None:
    """Fond commun : mur de velours qui s'assombrit, tapis, halo de lustre."""
    gradient(img, (0, 0, W, floor_y), wall_top, wall_bottom)
    gradient(img, (0, floor_y, W, H), floor, INK, 4)
    rect(d, 0, floor_y, W, floor_y, GOLD_D)
    glow(img, W // 2, 8, 46, GOLD_L, 0.35)


def chip(d, cx, cy, r, col, edge=IVORY) -> None:
    disc(d, cx, cy, r, col)
    for k in range(6):
        a = k * math.pi / 3
        d.point((cx + int(round(math.cos(a) * (r - 1))), cy + int(round(math.sin(a) * (r - 1)))), fill=edge)
    if r >= 4:
        d.ellipse([cx - r // 2, cy - r // 2, cx + r // 2, cy + r // 2], outline=edge)


def card(d, x, y, w, h, face=True, label="", red=True) -> None:
    rect(d, x + 1, y + 1, x + w + 1, y + h + 1, INK)
    if face:
        rect(d, x, y, x + w, y + h, IVORY)
        rect(d, x, y, x + w, y, (255, 255, 255))
        if label:
            d.text((x + 2, y + 1), label, fill=RED if red else INK)
    else:
        rect(d, x, y, x + w, y + h, RED_D)
        rect(d, x + 2, y + 2, x + w - 2, y + h - 2, WINE)
        for i in range(x + 3, x + w - 2, 3):
            d.point((i, y + h // 2), fill=GOLD_D)


def save(img: Image.Image, name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / f"trial_{name}.png")


# --------------------------------------------------------------------------- scènes


def art_charge(rng) -> None:
    img, d = canvas()
    room(img, d)
    # Jauge verticale avec zone dorée, bille lancée en arc.
    rect(d, 120, 18, 132, 86, INK)
    gradient(img, (122, 20, 131, 85), MAGENTA, CYAN_D, 5)
    rect(d, 121, 38, 132, 48, GOLD_L)
    rect(d, 118, 42, 135, 43, IVORY)
    for i in range(14):
        t = i / 13
        x = 20 + t * 80
        y = 70 - math.sin(t * math.pi) * 48
        d.point((int(x), int(y)), fill=GOLD_L if i % 2 else GOLD_D)
    disc(d, 100, 70, 4, IVORY)
    glow(img, 100, 70, 10, GOLD_L)
    # Main du croupier.
    rect(d, 10, 66, 26, 74, (220, 180, 150))
    rect(d, 4, 70, 12, 82, VELVET)
    save(img, "charge")


def art_rhythm(rng) -> None:
    img, d = canvas()
    room(img, d, 88)
    cols = [CYAN, GOLD_L, MAGENTA, EMERALD]
    for k in range(4):
        x = 30 + k * 26
        rect(d, x, 10, x + 18, 86, PLUM)
        for j in range(3):
            y = 18 + ((k * 23 + j * 27) % 60)
            rect(d, x + 2, y, x + 16, y + 6, cols[k])
        rect(d, x - 2, 74, x + 20, 76, IVORY)
    for n in range(6):
        x, y = rng.randint(4, 24), rng.randint(10, 70)
        disc(d, x, y, 2, GOLD_L)
        rect(d, x + 2, y - 7, x + 2, y, GOLD_L)
    glow(img, 70, 75, 30, MAGENTA, 0.4)
    save(img, "rhythm")


def art_bottles(rng) -> None:
    img, d = canvas()
    room(img, d, 62, WOOD, NIGHT, WINE)
    rect(d, 0, 60, W, 64, WOOD_D)
    cols = [(60, 140, 60), AMBER, (60, 140, 60), (120, 60, 30), (60, 140, 60)]
    for i, c in enumerate(cols):
        x = 30 + i * 22
        rect(d, x, 34, x + 9, 60, c)
        rect(d, x + 3, 24, x + 6, 34, c)
        rect(d, x + 2, 22, x + 7, 24, GOLD)
        rect(d, x + 1, 40, x + 8, 48, IVORY)
        rect(d, x + 1, 36, x + 2, 56, tuple(min(255, v + 60) for v in c))
    # Bouteille touchée, éclats.
    for k in range(10):
        a = rng.uniform(0, math.tau)
        d.point((100 + int(math.cos(a) * rng.randint(4, 12)), 30 + int(math.sin(a) * rng.randint(4, 12))), fill=IVORY)
    chip(d, 24, 80, 6, RED)
    for i in range(6):
        d.point((30 + i * 11, 76 - i * 7), fill=GOLD_L)
    save(img, "bottles")


def art_memory(rng) -> None:
    img, d = canvas()
    room(img, d, 8, FELT_L, NIGHT, FELT)
    for r in range(3):
        for c in range(4):
            x, y = 22 + c * 30, 14 + r * 27
            flipped = (r, c) in [(0, 1), (2, 2)]
            card(d, x, y, 22, 22, face=flipped)
            if flipped:
                disc(d, x + 8, y + 13, 3, RED)
                disc(d, x + 14, y + 14, 3, RED)
                rect(d, x + 10, y + 5, x + 11, y + 10, GREEN)
    glow(img, 52, 25, 16, GOLD_L, 0.5)
    glow(img, 112, 79, 16, GOLD_L, 0.5)
    save(img, "memory")


def art_shells(rng) -> None:
    img, d = canvas()
    room(img, d, 66)
    for i, x in enumerate([34, 80, 126]):
        lift = 14 if i == 1 else 0
        d.polygon([(x - 14, 64 - lift), (x + 14, 64 - lift), (x + 9, 38 - lift), (x - 9, 38 - lift)], fill=(170, 90, 40))
        rect(d, x - 14, 62 - lift, x + 14, 65 - lift, (120, 60, 30))
        rect(d, x - 7, 41 - lift, x - 5, 60 - lift, (210, 130, 70))
    disc(d, 80, 63, 4, IVORY)
    glow(img, 80, 63, 10, GOLD_L)
    for k in range(3):
        d.arc([30 + k * 30, 10, 80 + k * 30, 40], 200, 340, fill=GOLD_D)
    save(img, "shells")


def art_darts(rng) -> None:
    img, d = canvas()
    room(img, d, 92, WOOD_D, NIGHT, PLUM)
    cx, cy = 80, 46
    for r, c in [(34, INK), (31, (20, 20, 20)), (28, RED), (22, IVORY), (18, GREEN), (12, IVORY), (6, RED), (3, GREEN_L)]:
        disc(d, cx, cy, r, c)
    for k in range(20):
        a = k * math.pi / 10
        d.line([(cx, cy), (cx + math.cos(a) * 28, cy + math.sin(a) * 28)], fill=INK)
    for dx, dy in [(-2, -1), (9, -12), (-15, 8)]:
        x, y = cx + dx, cy + dy
        d.line([(x, y), (x + 14, y - 10)], fill=STEEL)
        d.polygon([(x + 14, y - 10), (x + 20, y - 15), (x + 18, y - 9)], fill=MAGENTA)
    glow(img, cx, cy, 40, GOLD_L, 0.25)
    save(img, "darts")


def art_safe(rng) -> None:
    img, d = canvas()
    room(img, d, 88)
    rect(d, 40, 10, 120, 88, STEEL_D)
    rect(d, 44, 14, 116, 84, STEEL)
    rect(d, 46, 16, 114, 82, (130, 136, 150))
    for y in [22, 76]:
        rect(d, 110, y, 116, y + 6, GOLD_D)
    cx, cy = 80, 49
    disc(d, cx, cy, 20, INK)
    disc(d, cx, cy, 18, GOLD_D)
    disc(d, cx, cy, 14, GOLD)
    for k in range(24):
        a = k * math.tau / 24
        d.point((cx + int(math.cos(a) * 16), cy + int(math.sin(a) * 16)), fill=INK)
    disc(d, cx, cy, 4, GOLD_L)
    d.line([(cx, cy), (cx, cy - 12)], fill=INK)
    # Stéthoscope.
    d.arc([12, 30, 46, 70], 270, 90, fill=SMOKE, width=2)
    disc(d, 46, 50, 4, STEEL)
    for i in range(3):
        d.arc([cx + 24 + i * 6, cy - 10 - i * 4, cx + 30 + i * 10, cy + 4 + i * 2], 300, 60, fill=CYAN)
    save(img, "safe")


def art_tower(rng) -> None:
    img, d = canvas()
    room(img, d, 84)
    cols = [RED, BLUE, GREEN_L, GOLD, RED, IVORY, BLUE, MAGENTA]
    for i, c in enumerate(cols):
        off = int(math.sin(i * 0.9) * 3) + i // 3
        y = 80 - i * 7
        rect(d, 64 + off, y - 5, 96 + off, y, c)
        rect(d, 64 + off, y - 5, 96 + off, y - 5, IVORY)
        for k in range(4):
            rect(d, 67 + off + k * 8, y - 3, 69 + off + k * 8, y - 2, IVORY)
    # Jeton qui arrive, en l'air.
    rect(d, 92, 12, 124, 17, GOLD_L)
    for i in range(3):
        d.point((108, 20 + i * 4), fill=GOLD_D)
    save(img, "tower")


def art_shaker(rng) -> None:
    img, d = canvas()
    room(img, d, 80, WOOD, NIGHT, WINE)
    d.polygon([(54, 78), (78, 78), (82, 30), (50, 30)], fill=STEEL)
    rect(d, 52, 22, 80, 30, STEEL_D)
    rect(d, 58, 14, 74, 22, STEEL)
    rect(d, 55, 34, 58, 74, (220, 225, 235))
    for k in range(5):
        disc(d, 38 + k * 3, 26 - k * 4, 2 + k % 2, FOAM)
        disc(d, 94 - k * 3, 24 - k * 3, 2, FOAM)
    # Jauge de mousse et bande dorée.
    rect(d, 112, 14, 124, 80, INK)
    rect(d, 113, 46, 123, 79, FOAM)
    rect(d, 110, 40, 126, 52, GOLD)
    rect(d, 113, 46, 123, 52, FOAM)
    for x in (40, 92):
        d.line([(x, 46), (x + (6 if x < 60 else -6), 52)], fill=GOLD_L)
    save(img, "shaker")


def art_pour(rng) -> None:
    img, d = canvas()
    room(img, d, 84, WOOD, NIGHT, WINE)
    rect(d, 0, 82, W, 86, WOOD_D)
    rect(d, 70, 4, 90, 14, STEEL_D)
    rect(d, 76, 14, 84, 22, STEEL)
    rect(d, 79, 22, 81, 46, AMBER)
    rect(d, 62, 40, 98, 82, (200, 220, 230))
    rect(d, 64, 56, 96, 81, AMBER)
    rect(d, 64, 48, 96, 56, FOAM)
    rect(d, 66, 58, 68, 78, (255, 200, 90))
    rect(d, 56, 50, 104, 50, GOLD_L)
    d.polygon([(52, 46), (56, 50), (52, 54)], fill=GOLD_L)
    for i in range(6):
        disc(d, 70 + i * 4, 64 + (i * 5) % 12, 1, (255, 230, 160))
    save(img, "pour")


def art_simon(rng) -> None:
    img, d = canvas()
    room(img, d, 92)
    d.rounded_rectangle([34, 6, 126, 94], radius=20, fill=WINE, outline=GOLD)
    d.rounded_rectangle([44, 14, 116, 40], radius=12, fill=INK)
    for k in range(8):
        disc(d, 50 + k * 9, 27, 2, [MAGENTA, GOLD_L, CYAN][k % 3])
    cols = [BLUE, YELLOW, RED, GREEN_L]
    pos = [(56, 66), (80, 52), (104, 66), (80, 80)]
    for k, (x, y) in enumerate(pos):
        lit = k == 1
        rect(d, x - 9, y - 6, x + 9, y + 6, cols[k] if lit else tuple(v // 3 for v in cols[k]))
        if lit:
            glow(img, x, y, 16, cols[k], 0.8)
    for n in range(4):
        d.point((20 + n * 3, 20 + n * 9), fill=GOLD_L)
        d.point((138 - n * 3, 22 + n * 8), fill=GOLD_L)
    save(img, "simon")


def art_catch(rng) -> None:
    """La Pluie du Grand Lustre : salle de bal, lustre de cristal, pluie de jetons et plaques."""
    img, d = canvas()
    room(img, d, 84, floor=WOOD, wall_top=NIGHT, wall_bottom=WINE)
    rect(d, 30, 84, 130, 88, RED_D)
    rect(d, 0, 0, W, 7, WOOD_D)
    for k in range(5):
        rect(d, 8 + k * 32, 7, 26 + k * 32, 10, INK)
    for x in (12, 148):
        rect(d, x, 18, x + 3, 78, GOLD_D)
    glow(img, 80, 22, 26, GOLD_L, 0.5)
    rect(d, 79, 7, 81, 14, GOLD)
    rect(d, 62, 14, 98, 16, GOLD)
    rect(d, 68, 20, 92, 21, GOLD_D)
    for k in range(9):
        x = 63 + k * 4
        rect(d, x, 16, x + 1, 19 + (k % 3), CYAN)
    for _ in range(10):
        x, y = rng.randint(14, 146), rng.randint(26, 70)
        roll = rng.random()
        if roll < 0.2:
            chip(d, x, y, 4, (176, 58, 255), INK)
        elif roll < 0.4:
            rect(d, x - 5, y - 3, x + 5, y + 3, IVORY)
            rect(d, x - 3, y - 1, x + 3, y + 1, GOLD)
        else:
            chip(d, x, y, 4, GOLD)
    rect(d, 60, 78, 100, 81, GOLD_D)
    rect(d, 60, 76, 100, 77, GOLD_L)
    for k in range(4):
        chip(d, 80, 73 - k * 3, 4, GOLD)
    save(img, "catch")


def art_highlow(rng) -> None:
    img, d = canvas()
    room(img, d, 8, FELT_L, NIGHT, FELT)
    card(d, 36, 22, 34, 50, True)
    d.text((41, 26), "R", fill=INK)
    # Couronne du Roi.
    d.polygon([(44, 54), (46, 42), (50, 48), (53, 40), (56, 48), (60, 42), (62, 54)], fill=GOLD)
    rect(d, 44, 54, 62, 57, GOLD_D)
    card(d, 90, 22, 34, 50, False)
    d.polygon([(80, 30), (74, 38), (86, 38)], fill=EMERALD)
    d.polygon([(80, 66), (74, 58), (86, 58)], fill=CYAN)
    d.text((95, 40), "?", fill=GOLD_L)
    save(img, "highlow")


def art_sort(rng) -> None:
    img, d = canvas()
    room(img, d, 92)
    rect(d, 0, 44, W, 62, (30, 30, 36))
    for x in range(0, W, 8):
        rect(d, x, 44, x, 62, (60, 60, 68))
    cols = [GREEN_L, RED, BLUE, YELLOW]
    for i, x in enumerate([18, 50, 82, 114, 146]):
        chip(d, x, 53, 6, cols[i % 4])
    d.rectangle([72, 40, 92, 66], outline=GOLD_L)
    # Bacs aux couleurs des boutons de manette.
    for k, (x, y) in enumerate([(30, 84), (70, 84), (110, 84), (150, 84)]):
        rect(d, x - 12, y - 6, x + 6, y + 8, tuple(v // 2 for v in cols[k]))
        rect(d, x - 12, y - 6, x + 6, y - 5, cols[k])
    for k in range(4):
        disc(d, 22 + k * 40, 22, 7, cols[k])
        d.text((19 + k * 40, 16), "ABXY"[k], fill=INK)
    save(img, "sort")


def art_invaders(rng) -> None:
    """Les Envahisseurs du Zéro : borne d'arcade, rangées de jetons-envahisseurs, râteau-canon."""
    img, d = canvas()
    rect(d, 0, 0, W, H, (18, 10, 28))
    rect(d, 20, 4, 140, 14, (40, 8, 40))
    rect(d, 20, 4, 140, 5, MAGENTA)
    rect(d, 24, 16, 136, 96, INK)
    inv = ["  #   #  ", "  #####  ", " ## # ## ", "#########", "# ##### #", "  #   #  "]
    cols = [MAGENTA, YELLOW, CYAN, EMERALD]
    for r in range(4):
        for c in range(6):
            x0, y0 = 32 + c * 17, 20 + r * 11
            for yy, row in enumerate(inv):
                for xx, ch in enumerate(row):
                    if ch == "#" and yy < 6:
                        d.point((x0 + xx, y0 + yy), fill=cols[r])
    for k in range(3):
        x = 40 + k * 36
        rect(d, x, 72, x + 12, 77, GOLD)
        rect(d, x + 2, 70, x + 10, 72, GOLD_D)
    rect(d, 76, 84, 84, 88, IVORY)
    rect(d, 79, 80, 81, 84, IVORY)
    rect(d, 79, 50, 80, 58, GOLD_L)
    rect(d, 101, 60, 102, 66, MAGENTA)
    for y in range(16, 96, 2):
        d.line((24, y, 136, y), fill=(0, 0, 0))
    save(img, "invaders")


def art_cave(rng) -> None:
    """La Cave du Grand Zéro : voûte de briques, fosse, câble de lustre, tonneau, trésor."""
    img, d = canvas()
    gradient(img, (0, 0, W, 78), (26, 15, 12), (44, 24, 18))
    for y in range(6, 76, 8):
        off = 6 if (y // 8) % 2 else 0
        for x in range(-off, W, 14):
            rect(d, x + 1, y + 1, x + 12, y + 6, (52, 28, 22))
    rect(d, 0, 78, W, H, (58, 36, 24))
    rect(d, 0, 78, W, 79, (107, 74, 42))
    rect(d, 70, 78, 110, H, INK)
    d.line((90, 10, 100, 50), fill=GOLD, width=1)
    disc(d, 90, 10, 3, GOLD_D)
    rect(d, 98, 50, 104, 56, RED)
    rect(d, 99, 46, 103, 50, IVORY)
    disc(d, 40, 72, 6, (122, 74, 36))
    d.line((34, 72, 46, 72), fill=(58, 34, 16))
    disc(d, 130, 50, 5, GOLD)
    disc(d, 130, 50, 3, IVORY)
    glow(img, 20, 30, 16, AMBER, 0.5)
    rect(d, 19, 30, 21, 38, (140, 90, 40))
    disc(d, 20, 28, 3, AMBER)
    save(img, "cave")


def art_pachinko(rng) -> None:
    """Pachinko : caisson rouge, ampoules, plateau de clous, billes, taquets, godet d'or."""
    img, d = canvas()
    rect(d, 0, 0, W, H, (20, 8, 18))
    rect(d, 34, 2, 126, 98, (90, 12, 24))
    for k in range(12):
        disc(d, 38 + k * 8, 5, 1, GOLD_L if k % 2 else GOLD_D)
    rect(d, 40, 10, 120, 92, (42, 32, 24))
    for r in range(7):
        for c in range(9):
            x = 46 + c * 9 + (4 if r % 2 else 0)
            if x < 116:
                d.point((x, 18 + r * 8), fill=IVORY)
    for (x, y) in ((60, 30), (88, 52), (70, 74)):
        disc(d, x, y, 2, STEEL)
    d.line((44, 80, 66, 84), fill=CYAN, width=2)
    d.line((116, 80, 94, 84), fill=CYAN, width=2)
    rect(d, 72, 86, 88, 92, GOLD)
    rect(d, 66, 86, 72, 92, SMOKE)
    rect(d, 88, 86, 94, 92, SMOKE)
    save(img, "pachinko")


def art_blackjack(rng) -> None:
    """Blackjack express : feutre en demi-lune, sabot, deux cartes, jetons, chrono."""
    img, d = canvas()
    rect(d, 0, 0, W, H, INK)
    d.ellipse((-30, -70, 190, 96), fill=GOLD_D)
    d.ellipse((-28, -68, 188, 94), fill=FELT)
    card(d, 56, 50, 20, 28, label="A", red=False)
    card(d, 80, 50, 20, 28, label="K", red=True)
    card(d, 70, 14, 16, 22, label="6", red=True)
    rect(d, 88, 14, 104, 36, VELVET)
    rect(d, 120, 10, 146, 30, WOOD_D)
    rect(d, 122, 12, 144, 26, VELVET)
    for k, col in enumerate((CYAN, YELLOW, RED)):
        rect(d, 30 + k * 36, 86, 58 + k * 36, 94, col)
    chip(d, 24, 64, 5, RED)
    chip(d, 24, 60, 5, GOLD)
    save(img, "blackjack")


def art_scratch(rng) -> None:
    """Le Grattage : ticket crème, 9 cases argentées, deux grattées (trèfles), reflet doré."""
    img, d = canvas()
    rect(d, 0, 0, W, H, (26, 15, 20))
    rect(d, 0, 78, W, H, WOOD_D)
    rect(d, 38, 6, 122, 94, (244, 231, 200))
    rect(d, 40, 8, 120, 92, GOLD)
    rect(d, 42, 10, 118, 90, (244, 231, 200))
    rect(d, 50, 13, 110, 19, VELVET)
    for i in range(9):
        x, y = 48 + (i % 3) * 22, 24 + (i // 3) * 22
        rect(d, x, y, x + 18, y + 18, (184, 184, 196))
        if i in (1, 5):
            rect(d, x + 2, y + 2, x + 16, y + 16, IVORY)
            disc(d, x + 7, y + 7, 3, EMERALD)
            disc(d, x + 11, y + 7, 3, EMERALD)
            disc(d, x + 9, y + 11, 3, EMERALD)
    glow(img, 101, 40, 10, GOLD_L, 0.7)
    disc(d, 101, 40, 2, IVORY)
    disc(d, 128, 70, 6, GOLD)
    save(img, "scratch")


def art_dice(rng) -> None:
    """Les Dés : table de craps vue de dessus, bande à pyramides, zone dorée, deux dés."""
    img, d = canvas()
    rect(d, 0, 0, W, H, (74, 42, 20))
    rect(d, 10, 8, 150, 92, GOLD_D)
    rect(d, 12, 10, 148, 90, FELT)
    for x in range(12, 148, 6):
        d.polygon([(x, 10), (x + 3, 14), (x + 6, 10)], fill=GOLD)
    disc(d, 100, 44, 12, (90, 110, 50))
    d.ellipse((88, 32, 112, 56), outline=GOLD_L)
    for (x, y) in ((92, 40), (102, 46)):
        rect(d, x, y, x + 8, y + 8, RED)
        d.point((x + 2, y + 2), fill=IVORY)
        d.point((x + 5, y + 5), fill=IVORY)
    for k in range(6):
        d.point((80 - k * 4, 80 - k * 8), fill=CYAN)
    rect(d, 20, 70, 140, 71, (200, 200, 190))
    save(img, "dice")


def art_derby(rng) -> None:
    """Le Tiercé : stand forain à ampoules, quatre chevaux de bois sur leurs rails, damier."""
    img, d = canvas()
    rect(d, 0, 0, W, H, (26, 12, 24))
    rect(d, 0, 4, W, 16, VELVET)
    for k in range(20):
        disc(d, 4 + k * 8, 6, 1, GOLD_L if k % 2 else GOLD_D)
    cols = [YELLOW, CYAN, RED, EMERALD]
    for k in range(4):
        y = 30 + k * 17
        rect(d, 8, y + 6, 140, y + 7, (180, 120, 60))
        x = 40 + (3 - k) * 14 + (20 if k == 0 else 0)
        rect(d, x, y - 2, x + 16, y + 3, cols[k])
        rect(d, x + 14, y - 6, x + 18, y, cols[k])
        for l in (1, 6, 10, 14):
            rect(d, x + l, y + 3, x + l + 1, y + 6, cols[k])
    for y in range(24, 96, 4):
        rect(d, 146, y, 150, y + 2, IVORY if (y // 4) % 2 else INK)
    save(img, "derby")


def main() -> None:
    rng = random.Random(1520)
    for fn in [art_charge, art_rhythm, art_bottles, art_memory, art_shells, art_darts, art_safe,
               art_tower, art_shaker, art_pour, art_simon, art_catch, art_highlow, art_sort,
               art_invaders, art_cave, art_pachinko, art_blackjack, art_scratch, art_dice, art_derby]:
        fn(rng)
    print(f"{len(list(OUT.glob('trial_*.png')))} illustrations d'épreuves écrites dans {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
