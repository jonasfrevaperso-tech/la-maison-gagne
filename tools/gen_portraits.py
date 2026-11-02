#!/usr/bin/env python3
"""Portraits pixel art 128×128, 4 frames (repos, clignement, parole A, parole B) en bande horizontale.

Dessin sur une grille 64×64 agrandie ×2 (gros pixels), palette de la bible artistique.
Chaque portrait est décrit par un dictionnaire de traits (peau, cheveux, yeux, accessoire, tenue).
Sortie : assets/portraits/<id>.png (512×128). Usage : python3 tools/gen_portraits.py
"""
from __future__ import annotations

import pathlib

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "portraits"
G = 64
SCALE = 2
FRAMES = 4

C = {
    "ink": (10, 8, 13), "velvet_deep": (26, 12, 20), "velvet": (58, 18, 40), "gold": (212, 175, 55), "gold_light": (242, 210, 122),
    "gold_dark": (138, 109, 30), "ivory": (245, 240, 230), "smoke": (107, 98, 117), "smoke_dark": (43, 38, 49), "magenta": (255, 46, 136),
    "cyan": (41, 224, 255), "emerald": (46, 230, 168), "red": (200, 16, 46), "black": (30, 27, 36), "green": (15, 138, 79),
    "blue": (61, 139, 255), "purple": (176, 58, 255), "orange": (255, 138, 61), "steel": (154, 164, 181), "brown": (92, 58, 36),
    "skin1": (241, 204, 170), "skin2": (214, 166, 125), "skin3": (160, 110, 75), "skin4": (110, 72, 50), "pale": (220, 220, 230),
    "ghost": (190, 200, 230), "white": (250, 250, 250), "split": (200, 16, 46), "grey": (150, 150, 160), "blonde": (230, 200, 110), "ginger": (190, 90, 40),
}


def sh(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


def col(name):
    return C[name] if isinstance(name, str) else name


PORTRAITS = {
    # Personnages jouables
    "lea": dict(skin="skin1", hair="ginger", style="bob", eyes="emerald", outfit="gold", collar="black", acc="bowtie", bg="velvet"),
    "vic": dict(skin="skin2", hair="black", style="slick", eyes="brown", outfit="magenta", collar="ivory", acc="cigarette", bg="velvet", stubble=True),
    "odile": dict(skin="skin3", hair="black", style="bun", eyes="brown", outfit="cyan", collar="ivory", acc="glasses", bg="velvet_deep"),
    "barnabe": dict(skin="black", hair="black", style="raven", eyes="gold_light", outfit="emerald", collar="black", acc="beak", bg="velvet"),
    "marthe": dict(skin="skin1", hair="ivory", style="veil", eyes="blue", outfit="black", collar="ivory", acc="cross", bg="velvet_deep"),
    "ghost": dict(skin="ghost", hair="pale", style="slick", eyes="cyan", outfit="smoke", collar="ivory", acc="none", bg="smoke_dark", ghost=True),
    # Créanciers
    "cr_muet": dict(skin="pale", hair="black", style="slick", eyes="ink", outfit="black", collar="ivory", acc="mask", bg="smoke_dark", mouth="none"),
    "cr_rouge_noir": dict(skin="skin1", hair="split", style="long", eyes="red", outfit="split", collar="gold", acc="earrings", bg="velvet"),
    "cr_comptable": dict(skin="skin2", hair="grey", style="bald", eyes="ink", outfit="smoke", collar="ivory", acc="glasses", bg="smoke_dark"),
    "cr_chanteuse": dict(skin="skin4", hair="black", style="waves", eyes="magenta", outfit="magenta", collar="gold", acc="flower", bg="velvet"),
    "cr_jumeau": dict(skin="skin2", hair="blonde", style="slick", eyes="cyan", outfit="cyan", collar="ivory", acc="half_mask", bg="velvet_deep"),
    "cr_baron_carre": dict(skin="skin1", hair="grey", style="bald", eyes="ink", outfit="gold_dark", collar="ivory", acc="monocle_tophat", bg="velvet", moustache=True),
    "cr_usurier": dict(skin="skin3", hair="grey", style="bald", eyes="emerald", outfit="emerald", collar="black", acc="visor", bg="smoke_dark"),
    "cr_pyromane": dict(skin="skin2", hair="orange", style="spiky", eyes="orange", outfit="red", collar="black", acc="match", bg="velvet"),
    "cr_douairiere": dict(skin="pale", hair="white", style="bun", eyes="purple", outfit="purple", collar="gold", acc="pearls", bg="velvet_deep"),
    "cr_magnetiseur": dict(skin="skin2", hair="black", style="slick", eyes="purple", outfit="black", collar="purple", acc="spiral", bg="smoke_dark", moustache=True),
    "cr_notaire": dict(skin="skin1", hair="grey", style="side", eyes="ink", outfit="black", collar="ivory", acc="glasses", bg="smoke_dark"),
    "cr_prestidigitateur": dict(skin="skin1", hair="black", style="slick", eyes="cyan", outfit="black", collar="red", acc="tophat", bg="velvet", moustache=True),
    "cr_bonneteur": dict(skin="skin3", hair="brown", style="spiky", eyes="orange", outfit="orange", collar="black", acc="match", bg="smoke_dark", moustache=True),
    "cr_valseuse": dict(skin="pale", hair="black", style="bun", eyes="purple", outfit="purple", collar="gold", acc="flower", bg="velvet"),
    "cr_ombre": dict(skin="smoke", hair="smoke_dark", style="side", eyes="gold_light", outfit="smoke_dark", collar="smoke", acc="none", bg="black", ghost=True),
    "cr_croupier_or": dict(skin="gold_light", hair="gold", style="slick", eyes="gold_dark", outfit="gold", collar="gold_dark", acc="bowtie", bg="velvet_deep"),
    "cr_patron": dict(skin="skin2", hair="white", style="side", eyes="gold", outfit="black", collar="gold", acc="fedora", bg="velvet_deep", moustache=True),
    "cr_la_maison": dict(skin="velvet", hair="none", style="none", eyes="magenta", outfit="velvet", collar="gold", acc="wheel_face", bg="black", mouth="grille"),
    # PNJ
    "house": dict(skin="velvet", hair="none", style="none", eyes="magenta", outfit="velvet", collar="gold", acc="wheel_face", bg="black", mouth="grille"),
    "npc_croupier": dict(skin="skin1", hair="grey", style="side", eyes="ink", outfit="black", collar="ivory", acc="visor", bg="velvet", moustache=True),
}


class P:
    def __init__(self):
        self.im = Image.new("RGBA", (G, G), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def e(self, box, c):
        self.d.ellipse(box, fill=(*col(c), 255))

    def r(self, box, c):
        self.d.rectangle(box, fill=(*col(c), 255))

    def p(self, pts, c):
        self.d.polygon(pts, fill=(*col(c), 255))

    def l(self, pts, c, w=1):
        self.d.line(pts, fill=(*col(c), 255), width=w)

    def px(self, x, y, c):
        if 0 <= x < G and 0 <= y < G:
            self.im.putpixel((x, y), (*col(c), 255))


def draw(t: dict, frame: int) -> Image.Image:
    p = P()
    bg = col(t["bg"])
    # Fond : arche art déco + rayons
    p.r((0, 0, G - 1, G - 1), sh(bg, 0.7))
    for k in range(0, G, 4):
        p.l([(32, 70), (k, 0)], sh(bg, 1.15))
    p.e((6, 4, 57, 70), sh(bg, 1.05))
    p.d.arc((6, 4, 57, 70), 180, 360, fill=(*C["gold_dark"], 255), width=1)
    skin = col(t["skin"])
    outfit = col(t["outfit"]) if t["outfit"] != "split" else C["red"]
    # Buste
    if t["outfit"] == "split":
        p.p([(8, 64), (32, 46), (32, 64)], "red")
        p.p([(56, 64), (32, 46), (32, 64)], "black")
    else:
        p.p([(6, 64), (14, 50), (50, 50), (58, 64)], outfit)
        p.p([(14, 50), (26, 48), (32, 58), (38, 48), (50, 50), (52, 54), (12, 54)], sh(outfit, 0.8))
    p.p([(26, 48), (32, 57), (38, 48), (32, 50)], t["collar"])
    # Cou + tête
    p.r((27, 40, 37, 49), sh(skin, 0.85))
    if t["style"] != "none" or t["acc"] != "wheel_face":
        p.e((18, 14, 46, 44), skin)
        p.e((16, 26, 20, 33), sh(skin, 0.9))
        p.e((44, 26, 48, 33), sh(skin, 0.9))
    # Cheveux
    hair = t["hair"]
    st = t["style"]
    if hair not in ("none",) and st not in ("bald", "none", "veil", "raven"):
        hc = col("black") if hair == "split" else col(hair)
        if st == "bob":
            p.e((16, 10, 48, 30), hc); p.r((16, 20, 21, 38), hc); p.r((43, 20, 48, 38), hc)
        elif st == "slick":
            p.e((18, 10, 46, 26), hc); p.p([(18, 20), (30, 12), (46, 18), (46, 22)], sh(hc, 1.2))
        elif st == "bun":
            p.e((18, 11, 46, 25), hc); p.e((26, 4, 38, 14), hc)
        elif st == "long":
            p.e((16, 10, 48, 28), hc); p.r((15, 20, 21, 50), hc); p.r((43, 20, 49, 50), hc)
            if hair == "split":
                p.r((32, 10, 48, 27), "red"); p.r((43, 20, 49, 50), "red")
        elif st == "waves":
            p.e((14, 10, 50, 30), hc)
            for y in (30, 36, 42):
                p.e((13, y, 20, y + 7), hc); p.e((44, y, 51, y + 7), hc)
        elif st == "spiky":
            for x in range(18, 46, 5):
                p.p([(x, 20), (x + 3, 6), (x + 6, 20)], hc)
        elif st == "side":
            p.e((18, 11, 46, 24), hc); p.l([(24, 13), (24, 20)], sh(hc, 0.6))
    if st == "bald":
        p.e((20, 22, 24, 30), col(hair)); p.e((40, 22, 44, 30), col(hair))
    if st == "veil":
        p.p([(14, 40), (16, 12), (32, 6), (48, 12), (50, 40), (44, 44), (44, 16), (20, 16), (20, 44)], "black")
        p.r((19, 15, 45, 18), "ivory")
    if st == "raven":
        p.e((16, 10, 48, 44), "black")
        p.p([(30, 4), (36, 8), (34, 14)], "black")
    # Tête de La Maison : une roue
    if t["acc"] == "wheel_face":
        p.e((14, 8, 50, 46), "gold_dark")
        import math
        for k in range(16):
            a0 = k * math.pi / 8
            a1 = a0 + math.pi / 8
            pts = [(32, 27), (32 + math.cos(a0) * 16, 27 + math.sin(a0) * 16), (32 + math.cos(a1) * 16, 27 + math.sin(a1) * 16)]
            p.p(pts, "red" if k % 2 else "black")
        p.e((25, 20, 39, 34), "velvet_deep")
    # Yeux
    blink = frame == 1
    ey = 28
    eye_c = col(t["eyes"])
    for ex in (25, 35):
        if t["acc"] == "wheel_face":
            p.r((ex, ey - 4, ex + 3, ey - 2), eye_c)
            continue
        if blink:
            p.l([(ex - 1, ey + 1), (ex + 4, ey + 1)], "ink")
        else:
            p.r((ex, ey, ex + 3, ey + 2), "white")
            p.r((ex + 1, ey, ex + 2, ey + 2), eye_c)
        p.l([(ex - 1, ey - 2), (ex + 4, ey - 3 if ex < 30 else ey - 2)], sh(col(hair) if hair not in ("none",) else C["ink"], 0.7))
    # Nez, bouche
    if t["acc"] not in ("wheel_face", "beak"):
        p.l([(32, 30), (31, 34), (33, 34)], sh(skin, 0.75))
    mouth = t.get("mouth", "normal")
    talk = frame in (2, 3)
    if mouth == "grille":
        for x in range(26, 39, 3):
            p.l([(x, 37), (x, 41 if talk else 39)], "gold_light")
    elif mouth != "none" and t["acc"] != "beak":
        if talk:
            p.e((29, 36, 35, 40 if frame == 2 else 42), "ink")
            p.r((30, 36, 34, 37), "white")
        else:
            p.l([(29, 38), (35, 38)], sh(skin, 0.55))
    if t.get("moustache"):
        p.p([(26, 35), (32, 34), (38, 35), (36, 37), (32, 36), (28, 37)], sh(col(hair), 0.8) if hair != "none" else "ink")
    if t.get("stubble"):
        for x in range(25, 40, 2):
            for y in range(37, 43, 2):
                p.px(x, y, sh(skin, 0.7))
    # Accessoires
    acc = t["acc"]
    if acc == "bowtie":
        p.p([(27, 49), (32, 51), (27, 53)], "red"); p.p([(37, 49), (32, 51), (37, 53)], "red")
    elif acc == "cigarette":
        p.l([(35, 39), (44, 41)], "ivory", 2); p.px(45, 41, "orange")
        for k in range(3):
            p.px(46 + k, 38 - 2 * k - frame % 2, "smoke")
    elif acc == "glasses":
        p.d.rectangle((23, 26, 29, 32), outline=(*C["gold"], 255)); p.d.rectangle((33, 26, 39, 32), outline=(*C["gold"], 255)); p.l([(29, 29), (33, 29)], "gold")
    elif acc == "beak":
        p.p([(28, 32), (36, 32), (32, 42)], "gold"); p.l([(28, 32), (36, 32)], "gold_dark")
    elif acc == "cross":
        p.r((31, 52, 33, 60), "gold"); p.r((29, 54, 35, 55), "gold")
    elif acc == "mask":
        p.r((19, 24, 45, 33), "black"); p.r((24, 27, 28, 30), "ivory"); p.r((35, 27, 39, 30), "ivory")
    elif acc == "half_mask":
        p.p([(32, 14), (46, 20), (46, 40), (32, 42)], "ivory")
    elif acc == "earrings":
        p.e((15, 34, 18, 38), "gold"); p.e((46, 34, 49, 38), "gold")
    elif acc == "flower":
        p.e((40, 10, 48, 18), "magenta"); p.px(44, 14, "gold_light")
    elif acc in ("monocle_tophat", "tophat"):
        p.r((20, 2, 44, 14), "black"); p.r((15, 13, 49, 16), "black"); p.r((20, 10, 44, 12), "red" if acc == "tophat" else "gold")
        if acc == "monocle_tophat":
            p.d.ellipse((33, 25, 40, 32), outline=(*C["gold"], 255)); p.l([(40, 30), (42, 44)], "gold")
    elif acc == "visor":
        p.p([(16, 18), (48, 18), (52, 23), (12, 23)], "emerald")
    elif acc == "match":
        p.l([(44, 46), (50, 36)], "brown", 2); p.e((48, 31 - frame % 2, 53, 37), "orange")
    elif acc == "pearls":
        for x in range(22, 44, 3):
            p.e((x, 46, x + 2, 48), "ivory")
    elif acc == "spiral":
        for k, rr in enumerate((10, 7, 4)):
            p.d.ellipse((32 - rr, 52 - rr // 2, 32 + rr, 52 + rr // 2), outline=(*C["purple" if k % 2 == 0 else "cyan"], 255))
    elif acc == "fedora":
        p.p([(14, 16), (50, 16), (46, 12), (42, 4), (22, 4), (18, 12)], "black"); p.r((20, 11, 44, 13), "gold")
    img = p.im
    if t.get("ghost"):
        a = img.split()[3].point(lambda v: int(v * 0.85))
        img.putalpha(a)
    return img.resize((G * SCALE, G * SCALE), Image.NEAREST)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for pid, traits in PORTRAITS.items():
        sheet = Image.new("RGBA", (G * SCALE * FRAMES, G * SCALE), (0, 0, 0, 0))
        for f in range(FRAMES):
            sheet.alpha_composite(draw(traits, f), (f * G * SCALE, 0))
        sheet.save(OUT / f"{pid}.png")
    print(f"{len(PORTRAITS)} portraits générés dans {OUT}")


if __name__ == "__main__":
    main()
