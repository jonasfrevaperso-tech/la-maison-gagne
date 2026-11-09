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
    """Le Grattage (1.9) : ticket argenté, trois zones cerclées de pointillés, une à moitié grattée."""
    img, d = canvas()
    rect(d, 0, 0, W, H, (26, 15, 20))
    rect(d, 0, 80, W, H, WOOD_D)
    rect(d, 14, 10, 146, 88, GOLD_D)
    rect(d, 16, 12, 144, 86, (244, 231, 200))
    rect(d, 40, 15, 120, 21, VELVET)
    rect(d, 22, 26, 138, 82, (184, 184, 196))
    for y in range(26, 82, 4):
        rect(d, 22, y, 138, y + 1, (168, 168, 182))
    cols = [EMERALD, YELLOW, RED]
    for k, cx in enumerate((42, 80, 118)):
        cy = 52 if k != 1 else 58
        if k == 0:
            disc(d, cx, cy, 11, (255, 246, 220))
            disc(d, cx - 3, cy - 2, 3, cols[k])
            disc(d, cx + 3, cy - 2, 3, cols[k])
            disc(d, cx, cy + 3, 3, cols[k])
        elif k == 1:
            d.pieslice((cx - 11, cy - 11, cx + 11, cy + 11), 180, 360, fill=(255, 246, 220))
            d.polygon([(cx, cy - 8), (cx + 3, cy - 2), (cx - 3, cy - 2)], fill=cols[k])
        for a in range(0, 360, 30):
            rr = math.radians(a)
            d.point((int(cx + math.cos(rr) * 13), int(cy + math.sin(rr) * 13)), fill=GOLD)
    disc(d, 92, 54, 6, GOLD)
    disc(d, 92, 54, 4, GOLD_L)
    for k in range(6):
        d.point((84 - k * 2, 60 + (k % 3)), fill=STEEL)
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
    """Le Tiercé (1.9) : chevaux de bois sur leurs rails, piste de rythme gauche / droite en bas."""
    img, d = canvas()
    rect(d, 0, 0, W, H, (26, 12, 24))
    rect(d, 0, 4, W, 14, VELVET)
    for k in range(20):
        disc(d, 4 + k * 8, 6, 1, GOLD_L if k % 2 else GOLD_D)
    cols = [YELLOW, CYAN, RED, EMERALD]
    for k in range(4):
        y = 24 + k * 13
        rect(d, 8, y + 5, 140, y + 6, (180, 120, 60))
        x = 34 + (3 - k) * 12 + (26 if k == 0 else 0)
        rect(d, x, y - 2, x + 14, y + 2, cols[k])
        rect(d, x + 12, y - 5, x + 16, y, cols[k])
        for l in (1, 5, 9, 12):
            rect(d, x + l, y + 2, x + l + 1, y + 5, cols[k])
    for y in range(20, 76, 4):
        rect(d, 146, y, 150, y + 2, IVORY if (y // 4) % 2 else INK)
    # Piste de rythme : ligne de frappe dorée, notes alternées qui arrivent.
    rect(d, 16, 80, 144, 96, INK)
    rect(d, 30, 79, 32, 97, GOLD_L)
    for k, x in enumerate((31, 56, 81, 106, 131)):
        col = CYAN if k % 2 == 0 else MAGENTA
        d.ellipse((x - 5, 83, x + 5, 93), outline=col)
        if k % 2 == 0:
            d.polygon([(x - 3, 88), (x + 2, 85), (x + 2, 91)], fill=col)
        else:
            d.polygon([(x + 3, 88), (x - 2, 85), (x - 2, 91)], fill=col)
    save(img, "derby")


def art_fishing(rng) -> None:
    """La Pêche au Gros : fontaine de marbre, statue dorée, carpes, canne et bouchon."""
    img, d = canvas()
    rect(d, 0, 0, W, H, (28, 24, 32))
    rect(d, 14, 40, 146, 92, (207, 198, 184))
    rect(d, 18, 44, 142, 88, (15, 59, 74))
    rect(d, 74, 14, 86, 40, GOLD_D)
    disc(d, 80, 10, 6, GOLD)
    for (x, y, a) in ((40, 60, 1), (110, 74, -1), (64, 78, 1)):
        d.polygon([(x + 8 * a, y), (x, y - 3), (x - 6 * a, y), (x, y + 3)], fill=GOLD)
        d.polygon([(x - 6 * a, y), (x - 10 * a, y - 3), (x - 10 * a, y + 3)], fill=GOLD_D)
    d.line((6, 98, 40, 20), fill=WOOD, width=2)
    d.line((40, 20, 96, 62), fill=IVORY)
    disc(d, 96, 62, 2, RED)
    d.arc((88, 56, 104, 68), 0, 360, fill=IVORY)
    save(img, "fishing")


def art_lasers(rng) -> None:
    """Les Lasers du Coffre : dalles d'acier, coffres, faisceaux rouges, porte blindée, voleur."""
    img, d = canvas()
    rect(d, 0, 0, W, H, (7, 9, 12))
    rect(d, 8, 12, 152, 90, (21, 24, 30))
    for x in range(8, 152, 12):
        d.line((x, 12, x, 90), fill=(30, 34, 40))
    for k in range(10):
        rect(d, 10 + k * 14, 4, 20 + k * 14, 10, (74, 80, 92))
    rect(d, 140, 38, 150, 64, GOLD_D)
    disc(d, 145, 51, 4, GOLD)
    for (a, b) in (((40, 12), (60, 80)), ((90, 90), (76, 30))):
        d.line((*a, *b), fill=(120, 20, 30), width=3)
        d.line((*a, *b), fill=(255, 60, 60), width=1)
    rect(d, 110, 20, 111, 44, (255, 60, 60))
    rect(d, 110, 60, 111, 90, (255, 60, 60))
    disc(d, 22, 52, 5, INK)
    disc(d, 22, 52, 4, IVORY)
    save(img, "lasers")


def art_juggle(rng) -> None:
    """Le Jonglage : rideaux du cabaret, projecteur, croupier, jetons en arc."""
    img, d = canvas()
    rect(d, 0, 0, W, H, (18, 6, 12))
    for x in range(0, 40, 8):
        rect(d, x, 0, x + 6, H, (100, 10, 22))
        rect(d, W - x - 6, 0, W - x, H, (100, 10, 22))
    d.polygon([(70, 0), (90, 0), (120, 100), (40, 100)], fill=(40, 30, 24))
    rect(d, 0, 86, W, H, WOOD_D)
    rect(d, 74, 56, 86, 86, INK)
    rect(d, 78, 56, 82, 72, IVORY)
    disc(d, 80, 50, 6, (232, 200, 168))
    for k, (x, y) in enumerate(((56, 40), (70, 22), (90, 22), (104, 40))):
        chip(d, x, y, 5, [RED, YELLOW, CYAN, EMERALD][k])
    d.line((52, 70, 108, 70), fill=GOLD)
    save(img, "juggle")


def art_billiards(rng) -> None:
    """Le Billard (1.9) : table vue de dessus, trajectoire, bille fantôme, flèche vers la poche."""
    img, d = canvas()
    rect(d, 0, 0, W, H, (14, 10, 8))
    rect(d, 10, 12, 150, 90, (110, 58, 28))
    rect(d, 16, 18, 144, 84, (11, 90, 58))
    rect(d, 20, 22, 140, 80, (18, 120, 76))
    for (x, y) in ((20, 22), (80, 22), (140, 22), (20, 80), (80, 80), (140, 80)):
        disc(d, x, y, 5, INK)
        d.ellipse((x - 6, y - 6, x + 6, y + 6), outline=GOLD_D)
    d.ellipse((133, 15, 147, 29), outline=EMERALD)
    disc(d, 50, 66, 4, IVORY)
    for k in range(9):
        x0 = 54 + k * 6
        d.line((x0, 66 - k * 2.2, x0 + 3, 66 - k * 2.2 - 1.1), fill=IVORY)
    d.ellipse((104, 42, 112, 50), outline=IVORY)
    disc(d, 114, 41, 4, YELLOW)
    d.line((117, 38, 133, 25), fill=YELLOW)
    d.polygon([(136, 22), (130, 25), (133, 28)], fill=YELLOW)
    d.line((14, 80, 44, 69), fill=(216, 176, 122), width=2)
    save(img, "billiards")


# --------------------------------------------------------------------------- 2.0 : le Cabaret


def cabaret(img, d, floor_y=78) -> None:
    """Fond commun du Cabaret : rideaux, lambrequin à franges, éventail doré, plancher, rampe."""
    rect(d, 0, 0, W, H, (18, 6, 12))
    for k in range(9):
        a = math.pi * (0.1 + 0.8 * k / 8)
        d.line((80, floor_y - 4, 80 + math.cos(a) * 60, floor_y - 4 - math.sin(a) * 60), fill=GOLD_D)
    for x in range(0, 30, 6):
        rect(d, x, 0, x + 4, H, (110, 10, 24))
        rect(d, W - x - 4, 0, W - x, H, (110, 10, 24))
    rect(d, 0, 0, W, 7, (110, 10, 24))
    rect(d, 0, 7, W, 8, GOLD)
    for x in range(2, W, 5):
        d.point((x, 9), fill=GOLD_D)
    gradient(img, (0, floor_y, W, H), WOOD, WOOD_D, 3)
    rect(d, 0, floor_y, W, floor_y, GOLD)
    for x in range(8, W, 14):
        glow(img, x, floor_y + 2, 5, GOLD_L, 0.9)
        d.point((x, floor_y + 2), fill=FOAM)


def figure(d, x, y, coat, skirt=False, arms="down", skin=(232, 184, 150), hat=None) -> None:
    """Petit personnage (pieds en x, y) : jambes, buste, tête, bras selon la pose."""
    legs = (28, 20, 24) if not skirt else skin
    rect(d, x - 3, y - 10, x - 1, y, legs)
    rect(d, x + 1, y - 10, x + 3, y, legs)
    rect(d, x - 4, y - 21, x + 4, y - 10, coat)
    if skirt:
        d.polygon([(x - 4, y - 12), (x + 4, y - 12), (x + 7, y - 6), (x - 7, y - 6)], fill=coat)
    disc(d, x, y - 25, 3, skin)
    if arms == "up":
        d.line((x - 4, y - 20, x - 8, y - 29), fill=coat, width=2)
        d.line((x + 4, y - 20, x + 8, y - 29), fill=coat, width=2)
    elif arms == "out":
        d.line((x - 4, y - 19, x - 12, y - 20), fill=coat, width=2)
        d.line((x + 4, y - 19, x + 12, y - 20), fill=coat, width=2)
    else:
        d.line((x - 4, y - 20, x - 6, y - 12), fill=coat, width=2)
        d.line((x + 4, y - 20, x + 6, y - 12), fill=coat, width=2)
    if hat:
        rect(d, x - 3, y - 31, x + 3, y - 28, hat)


def art_tapdance(rng) -> None:
    """Les Claquettes : danseuse et groom face à face, pas qui claquent, piste des croches."""
    img, d = canvas()
    cabaret(img, d)
    glow(img, 58, 50, 22, GOLD_L, 0.5)
    glow(img, 102, 50, 22, GOLD_L, 0.5)
    figure(d, 58, 77, (90, 26, 138), skirt=True, arms="out")
    figure(d, 102, 77, RED, arms="out", hat=RED)
    for x, col in ((50, RED), (66, YELLOW), (94, CYAN), (110, EMERALD)):
        d.line((x - 2, 72, x - 5, 68), fill=col)
        d.line((x + 2, 72, x + 5, 68), fill=col)
    rect(d, 30, 88, 130, 95, INK)
    for k in range(9):
        d.line((30 + k * 12.5, 89, 30 + k * 12.5, 94), fill=SMOKE if k % 2 == 0 else STEEL_D)
    for k, col in ((0, RED), (3, YELLOW), (5, CYAN), (6, EMERALD)):
        disc(d, 36 + k * 12.5, 91, 2, col)
    save(img, "tapdance")


def art_spotlight(rng) -> None:
    """Le Projecteur : faisceau de poursuite sur la meneuse en or, doublure argent dans l'ombre."""
    img, d = canvas()
    cabaret(img, d)
    for side in (0, 1):
        x0 = 28 if side == 0 else 112
        for k in range(6):
            rect(d, x0 + (k * 3 if side == 0 else -k * 3), 78 - k * 4, x0 + 20 + (k * 3 if side == 0 else -k * 3), 78 - k * 4, GOLD_D)
    d.polygon([(70, 0), (78, 0), (100, 78), (64, 78)], fill=(60, 52, 40))
    glow(img, 82, 70, 20, FOAM, 0.8)
    figure(d, 82, 77, GOLD, skirt=True, arms="up")
    figure(d, 40, 77, (110, 116, 130), skirt=True)
    d.ellipse((64, 40, 100, 78), outline=GOLD_L)
    save(img, "spotlight")


def art_tightrope(rng) -> None:
    """Le Funambule : fil entre deux mâts, funambule et sa perche, filet, fanions dans le vent."""
    img, d = canvas()
    cabaret(img, d, floor_y=90)
    for x in (22, 138):
        rect(d, x - 1, 30, x + 1, 90, GOLD)
        d.polygon([(x, 22), (x + (9 if x < 80 else -9), 25), (x, 28)], fill=MAGENTA)
    d.line((22, 40, 138, 40), fill=STEEL)
    for x in range(26, 136, 6):
        d.line((x, 72, x + 3, 76), fill=SMOKE)
    d.line((24, 74, 136, 74), fill=SMOKE)
    figure(d, 74, 40, IVORY, arms="out")
    d.line((54, 26, 96, 18), fill=(150, 100, 50), width=2)
    for y in (12, 20):
        d.line((110, y, 124, y), fill=CYAN)
        d.polygon([(124, y - 2), (128, y), (124, y + 2)], fill=CYAN)
    save(img, "tightrope")


def art_hattoss(rng) -> None:
    """Le Lancer de chapeau : groom au bras levé, haut-de-forme en cloche vers la patère."""
    img, d = canvas()
    cabaret(img, d)
    figure(d, 26, 77, RED, arms="up", hat=RED)
    for k in range(10):
        u = k / 9
        x = 34 + u * 92
        y = 46 - math.sin(u * math.pi) * 30 + u * 2
        d.point((int(x), int(y)), fill=GOLD_L)
    rect(d, 124, 36, 126, 78, WOOD)
    rect(d, 120, 77, 130, 78, WOOD)
    d.line((125, 38, 120, 34), fill=GOLD)
    d.line((125, 38, 130, 34), fill=GOLD)
    rect(d, 92, 18, 100, 26, INK)
    rect(d, 89, 26, 103, 27, INK)
    rect(d, 92, 24, 100, 25, RED)
    for k in range(4):
        disc(d, 50 + k * 10, 14 + (k % 2) * 3, 5, (200, 212, 232))
    save(img, "hattoss")


def art_mentalist(rng) -> None:
    """Le Mentaliste : turban, boule de cristal, rangées de jetons et leurs points d'indice."""
    img, d = canvas()
    cabaret(img, d)
    figure(d, 44, 64, (26, 14, 46), arms="out", hat=IVORY)
    d.polygon([(30, 77), (58, 77), (54, 60), (34, 60)], fill=(58, 10, 74))
    rect(d, 33, 59, 55, 60, GOLD)
    glow(img, 44, 54, 9, (160, 100, 255), 1.0)
    disc(d, 44, 54, 4, (150, 90, 255))
    rect(d, 80, 16, 146, 74, INK)
    d.rectangle((80, 16, 146, 74), outline=GOLD_D)
    rows = ((RED, YELLOW, CYAN, 1, 0), (YELLOW, EMERALD, (176, 58, 255), 1, 2), (YELLOW, EMERALD, (176, 58, 255), 3, 0))
    for r, (a, b, c, blk, wht) in enumerate(rows):
        y = 26 + r * 16
        for k, col in enumerate((a, b, c)):
            chip(d, 90 + k * 12, y, 4, col)
        for k in range(blk):
            disc(d, 126 + k * 6, y, 2, GOLD_L)
        for k in range(wht):
            disc(d, 126 + (blk + k) * 6, y, 2, IVORY)
    save(img, "mentalist")


# --------------------------------------------------------------------------- 2.0 : les Cuisines

CREAM = (232, 224, 204)
COPPER = (200, 120, 64)


def kitchen(img, d, counter_y=74) -> None:
    """Fond commun des Cuisines : carreaux de métro crème, frise noire, casseroles de cuivre, comptoir inox."""
    rect(d, 0, 0, W, H, (106, 100, 88))
    for row in range(0, counter_y // 5 + 1):
        off = 0 if row % 2 == 0 else 5
        for x in range(-off, W, 10):
            rect(d, x + 1, row * 5 + 1, x + 9, row * 5 + 4, CREAM)
    rect(d, 0, 20, W, 23, INK)
    rect(d, 0, 24, W, 24, GOLD)
    rect(d, 0, 30, W, 30, GOLD_D)
    for x in range(14, W, 30):
        d.line((x, 30, x, 33), fill=GOLD_D)
        disc(d, x, 38, 5, COPPER)
        disc(d, x - 1, 37, 2, (232, 170, 110))
    gradient(img, (0, counter_y, W, H), STEEL, STEEL_D, 3)
    rect(d, 0, counter_y, W, counter_y + 1, IVORY)


def art_crepe(rng) -> None:
    """La Crêpe Suzette : la poêle lance la crêpe qui tourne, flamme bleue, puis l'éclat du flambé."""
    img, d = canvas()
    kitchen(img, d)
    for k in range(5):
        glow(img, 70 + k * 5, 74, 3, (80, 140, 255), 1.0)
    rect(d, 58, 70, 96, 73, INK)
    rect(d, 96, 71, 124, 72, WOOD)
    for k, (x, y) in enumerate(((78, 60), (82, 44), (78, 30))):
        w = (16, 6, 14)[k]
        d.ellipse((x - w, y - 2, x + w, y + 2), fill=(232, 176, 96))
    d.arc((60, 22, 100, 70), 200, 340, fill=GOLD_L)
    glow(img, 136, 40, 12, AMBER, 0.9)
    for k in range(5):
        d.polygon([(130 + k * 3, 54), (133 + k * 3, 40 - (k % 2) * 6), (136 + k * 3, 54)], fill=(255, 150 - k * 15, 40))
    save(img, "crepe")


def art_cutting(rng) -> None:
    """Le Découpage : planche, carotte et son pointillé ondulé, couteau, deux pépins rouges à enjamber."""
    img, d = canvas()
    rect(d, 0, 0, W, H, (40, 30, 24))
    gradient(img, (10, 14, 150, 92), (196, 140, 80), (150, 100, 52), 4)
    for y in range(18, 92, 9):
        d.line((10, y, 150, y), fill=(170, 116, 62))
    d.rounded_rectangle((30, 40, 134, 64), radius=10, fill=(232, 120, 40))
    for k in range(4):
        d.line((24, 50, 14, 40 + k * 6), fill=(80, 150, 50), width=2)
    pts = [(34 + x, 52 + 8 * math.sin(x / 14.0)) for x in range(0, 98, 2)]
    for k in range(0, len(pts) - 1, 2):
        d.line((pts[k], pts[k + 1]), fill=INK)
    for x in (70, 104):
        disc(d, x, int(52 + 8 * math.sin((x - 34) / 14.0)), 3, RED)
    rect(d, 112, 50, 114, 78, STEEL)
    rect(d, 111, 78, 115, 90, INK)
    save(img, "cutting")


def art_service(rng) -> None:
    """Le Service : le serveur de dos, plateau de verres de vin levé, l'allée entre les nappes blanches."""
    img, d = canvas()
    gradient(img, (0, 0, W, 50), (30, 14, 10), (70, 30, 20), 3)
    gradient(img, (0, 50, W, H), (140, 90, 46), (100, 60, 30), 4)
    d.polygon([(70, 50), (90, 50), (130, H), (30, H)], fill=(124, 80, 40))
    for k, (x, y, r) in enumerate(((22, 60, 10), (138, 60, 10), (44, 52, 6), (116, 52, 6), (60, 48, 4), (100, 48, 4))):
        d.ellipse((x - r, y - r // 2, x + r, y + r // 2), fill=IVORY)
        rect(d, x - r, y, x + r, y + r, (220, 214, 200))
        glow(img, x, y - 2, 3, AMBER, 0.8)
    glow(img, 80, 12, 10, GOLD_L, 0.7)
    rect(d, 72, 66, 88, 90, (22, 22, 30))
    disc(d, 80, 61, 5, (58, 36, 22))
    d.line((88, 70, 98, 60), fill=(22, 22, 30), width=3)
    d.line((98, 60, 98, 52), fill=(22, 22, 30), width=3)
    d.ellipse((84, 48, 114, 54), fill=STEEL)
    for k in range(4):
        x = 89 + k * 6
        d.polygon([(x - 2, 40), (x + 2, 40), (x + 1, 46), (x - 1, 46)], fill=(200, 220, 240))
        rect(d, x - 1, 42, x + 1, 44, (138, 16, 32))
        d.line((x, 46, x, 50), fill=(200, 220, 240))
    save(img, "service")


def art_orders(rng) -> None:
    """Les Commandes : trois bons au rail du passe (l'un montre sa recette), verre à cocktail."""
    img, d = canvas()
    kitchen(img, d, counter_y=80)
    rect(d, 14, 8, 146, 9, STEEL)
    cols = ((216, 232, 240), YELLOW, IVORY, (138, 216, 255))
    for k in range(3):
        x = 22 + k * 44
        rect(d, x, 10, x + 34, 50, (244, 236, 216))
        rect(d, x, 10, x + 34, 15, INK if k != 2 else RED)
        for j in range(3):
            if k == 0:
                disc(d, x + 7 + j * 10, 30, 4, cols[(j * 3 + 1) % 4], outline=INK)
            else:
                disc(d, x + 7 + j * 10, 30, 4, (216, 204, 176))
        rect(d, x + 3, 44, x + 3 + (28 if k == 0 else 12), 46, GOLD if k == 0 else EMERALD)
    d.polygon([(66, 58), (94, 58), (80, 72)], fill=(200, 220, 240))
    d.polygon([(70, 60), (90, 60), (80, 69)], fill=YELLOW)
    rect(d, 79, 72, 81, 80, (200, 220, 240))
    rect(d, 72, 79, 88, 80, (200, 220, 240))
    disc(d, 110, 76, 4, YELLOW)
    rect(d, 40, 58, 46, 80, (200, 220, 240))
    save(img, "orders")


def art_souffle(rng) -> None:
    """Le Soufflé : four vitré, soufflé qui monte dans son ramequin, thermomètre à zone verte."""
    img, d = canvas()
    kitchen(img, d, counter_y=86)
    rect(d, 14, 30, 100, 86, (28, 26, 30))
    rect(d, 14, 30, 100, 31, GOLD)
    gradient(img, (22, 38, 92, 80), (110, 60, 30), (60, 30, 16), 3)
    glow(img, 57, 60, 20, AMBER, 0.6)
    d.line((26, 42, 88, 42), fill=(255, 90, 20), width=2)
    rect(d, 46, 64, 68, 76, IVORY)
    d.ellipse((44, 50, 70, 70), fill=(232, 184, 96))
    rect(d, 46, 64, 68, 76, IVORY)
    for x in range(47, 68, 3):
        d.line((x, 64, x, 76), fill=(210, 206, 196))
    disc(d, 128, 52, 22, INK, outline=GOLD)
    d.arc((110, 34, 146, 70), 250, 300, fill=EMERALD, width=4)
    d.line((128, 52, 138, 36), fill=GOLD_L, width=2)
    disc(d, 128, 52, 2, GOLD)
    save(img, "souffle")


# --------------------------------------------------------------------------- 2.0 : les Toits

ZINC = (90, 100, 120)
ZINC_D = (58, 66, 82)
BRICK = (138, 58, 38)
SKY_N = (10, 16, 36)
LAMP = (255, 200, 102)


def rooftop(img, d, roof_y=78, rng=None, moon=True) -> None:
    """Fond commun des Toits : nuit étoilée, lune, ville aux fenêtres allumées, toits de zinc."""
    gradient(img, (0, 0, W, roof_y), SKY_N, (42, 58, 106), 4)
    r = rng or random.Random(5)
    for _ in range(40):
        d.point((r.randrange(W), r.randrange(roof_y - 20)), fill=FOAM)
    if moon:
        glow(img, 136, 16, 10, (220, 230, 255), 0.6)
        disc(d, 136, 16, 6, FOAM)
    x = 0
    while x < W:
        w = r.randrange(10, 22)
        h = r.randrange(14, 34)
        rect(d, x, roof_y - h, x + w - 1, roof_y, (22, 28, 50))
        for wy in range(roof_y - h + 3, roof_y - 2, 5):
            for wx in range(x + 2, x + w - 3, 4):
                if r.random() < 0.35:
                    d.point((wx, wy), fill=LAMP)
        x += w
    rect(d, 0, roof_y, W, H, ZINC)
    for xs in range(0, W, 8):
        d.line((xs, roof_y, xs, H), fill=ZINC_D)
    rect(d, 0, roof_y, W, roof_y + 1, ZINC_D)


def art_pigeon(rng) -> None:
    """Le Pigeon voyageur : plané entre deux souches fumantes vers l'anneau doré d'une fenêtre."""
    img, d = canvas()
    rooftop(img, d, 84, rng)
    for x, top in ((30, 56), (96, 62)):
        rect(d, x, top, x + 10, 84, BRICK)
        for k in range(3):
            disc(d, x + 4 + k * 3, top - 10 - k * 9, 4 + k * 2, (150, 156, 172))
    rect(d, 118, 34, 138, 54, LAMP)
    d.ellipse((112, 30, 144, 58), outline=GOLD_L, width=2)
    d.polygon([(62, 40), (78, 36), (86, 40), (78, 44)], fill=(122, 128, 144))
    d.polygon([(70, 39), (64, 28), (78, 37)], fill=(90, 96, 112))
    d.polygon([(70, 41), (64, 52), (78, 43)], fill=(90, 96, 112))
    disc(d, 84, 38, 2, (90, 106, 122))
    d.point((86, 37), fill=(255, 106, 26))
    save(img, "pigeon")


def art_gutters(rng) -> None:
    """Les Gouttières : mur de zinc, tuyaux de cuivre en chicane, eau bleue, tonneau sous l'orage."""
    img, d = canvas()
    rect(d, 0, 0, W, H, SKY_N)
    for k in range(40):
        x = rng.randrange(W)
        y = rng.randrange(H)
        d.line((x, y, x - 2, y + 6), fill=(110, 130, 180))
    rect(d, 24, 10, 136, 82, ZINC)
    for xs in range(24, 137, 10):
        d.line((xs, 10, xs, 82), fill=ZINC_D)
    rect(d, 20, 8, 140, 12, (70, 78, 96))
    copper = (200, 120, 64)
    water = (90, 150, 255)
    path = [(50, 14), (50, 30), (90, 30), (90, 50), (60, 50), (60, 70), (110, 70), (110, 84)]
    for (a, b), (c, e) in zip(path, path[1:]):
        d.line((a, b, c, e), fill=water, width=4)
        d.line((a, b, c, e), fill=(170, 200, 255), width=1)
    for (x, y) in path[1:-1]:
        disc(d, x, y, 3, copper)
    d.line((112, 18, 130, 18), fill=copper, width=4)
    d.line((30, 40, 30, 60), fill=copper, width=4)
    rect(d, 100, 84, 120, 95, WOOD)
    rect(d, 100, 87, 120, 88, INK)
    save(img, "gutters")


def art_antenna(rng) -> None:
    """L'Antenne : poste en noyer sur le toit, image qui perce la neige, antenne arête de poisson."""
    img, d = canvas()
    rooftop(img, d, 82, rng)
    rect(d, 20, 30, 92, 80, (138, 74, 34))
    rect(d, 26, 36, 76, 72, GOLD)
    rect(d, 28, 38, 74, 70, INK)
    for k in range(9):
        a0 = k * 40
        d.pieslice((36, 40, 66, 68), a0, a0 + 20, fill=RED if k % 2 else INK)
    disc(d, 51, 54, 4, GOLD)
    for _ in range(70):
        g = rng.randrange(90, 230)
        d.point((rng.randrange(28, 74), rng.randrange(38, 70)), fill=(g, g, g))
    disc(d, 84, 46, 3, INK)
    disc(d, 84, 60, 3, INK)
    rect(d, 126, 20, 127, 82, STEEL)
    rect(d, 108, 22, 146, 23, STEEL)
    for k in range(6):
        d.line((110 + k * 6, 17, 110 + k * 6, 28), fill=STEEL)
    save(img, "antenna")


def art_zipline(rng) -> None:
    """La Tyrolienne : câble entre deux toits, voyageur à la poulie, repère doré sur la plateforme."""
    img, d = canvas()
    rooftop(img, d, 86, rng, moon=False)
    glow(img, 24, 14, 9, (220, 230, 255), 0.5)
    disc(d, 24, 14, 5, FOAM)
    pts = [(14 + k * 7, 24 + int(k * 2.3 + 18 * math.sin(k / 19 * math.pi))) for k in range(20)]
    d.line(pts, fill=STEEL)
    rect(d, 10, 24, 12, 86, STEEL_D)
    rect(d, 146, 40, 148, 86, STEEL_D)
    rect(d, 112, 72, 150, 74, WOOD)
    rect(d, 126, 66, 127, 72, GOLD_L)
    glow(img, 126, 70, 4, GOLD_L, 0.8)
    x, y = pts[11]
    disc(d, x, y + 1, 2, STEEL)
    d.line((x, y + 2, x, y + 8), fill=STEEL_D)
    figure(d, x, y + 36, RED, arms="up")
    rect(d, 140, 50, 144, 62, RED)
    save(img, "zipline")


def art_telescope(rng) -> None:
    """Le Télescope : oculaire à trois anneaux, constellation tracée en or, lunette de laiton."""
    img, d = canvas()
    rooftop(img, d, 84, rng, moon=False)
    disc(d, 104, 44, 38, GOLD_D)
    disc(d, 104, 44, 35, (5, 8, 26))
    for r in (24, 12):
        d.ellipse((104 - r, 44 - r, 104 + r, 44 + r), outline=(60, 70, 110))
    stars = [(80, 34), (94, 22), (112, 30), (118, 52), (100, 60), (92, 46)]
    d.line(stars, fill=GOLD_L)
    for (x, y) in stars:
        disc(d, x, y, 2, FOAM)
    d.line((14, 76, 50, 52), fill=GOLD, width=5)
    d.line((48, 54, 52, 51), fill=GOLD_L, width=6)
    for dx in (-6, 0, 6):
        d.line((30, 66, 30 + dx * 2, 86), fill=WOOD)
    save(img, "telescope")


def main() -> None:
    rng = random.Random(1520)
    for fn in [art_charge, art_rhythm, art_bottles, art_memory, art_shells, art_darts, art_safe,
               art_tower, art_shaker, art_pour, art_simon, art_catch, art_highlow, art_sort,
               art_invaders, art_cave, art_pachinko, art_blackjack, art_scratch, art_dice, art_derby,
               art_fishing, art_lasers, art_juggle, art_billiards,
               art_tapdance, art_spotlight, art_tightrope, art_hattoss, art_mentalist,
               art_crepe, art_cutting, art_service, art_orders, art_souffle,
               art_pigeon, art_gutters, art_antenna, art_zipline, art_telescope]:
        fn(rng)
    print(f"{len(list(OUT.glob('trial_*.png')))} illustrations d'épreuves écrites dans {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
