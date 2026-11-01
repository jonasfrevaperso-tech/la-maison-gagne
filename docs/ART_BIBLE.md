# Bible artistique — La Maison Gagne

## Intention
Casino art déco **noir et or**, enfoui. Velours, laiton, fumée, néons **magenta / cyan / émeraude**. Glamour fatigué, chic et menaçant, avec une pointe d'absurde.

## Palette (fixée — `scripts/ui/palette.gd`)
| Rôle | Nom | Hex |
|---|---|---|
| Fond | Encre | `#0a080d` |
| Velours profond | Velvet Deep | `#1a0c14` |
| Velours | Velvet | `#3a1228` |
| Tapis | Feutre | `#0d3b2a` / `#155c40` |
| Or | Gold | `#d4af37` (clair `#f2d27a`, sombre `#8a6d1e`) |
| Texte | Ivoire | `#f5f0e6` |
| Neutre | Fumée | `#6b6275` / `#2b2631` |
| Néon 1 | Magenta | `#ff2e88` |
| Néon 2 | Cyan | `#29e0ff` |
| Néon 3 | Émeraude | `#2ee6a8` |
| Roulette | Rouge `#c8102e` · Noir `#16141a` · Vert `#0f8a4f` |
| Score | Jetons (bleu) `#3d8bff` · Mult (rouge) `#ff3b5c` |
| Danger | `#ff4d3d` |
| Raretés | Commun `#b8b2c2` · Rare `#29e0ff` · Légendaire `#f2d27a` · Maudit `#b03aff` |
| Daltonien | Rouge → `#e66100`, Noir → `#1f2a44` + motif (rayures sur les rouges) |

Règle : jamais de couleur hors palette ; les variations se font par `darkened/lightened` et alpha.

## Typographies (libres de droits, SIL OFL)
- **Display art déco** : *Limelight* (titres, boutons) — repli DejaVu Serif.
- **UI lisible** : *Josefin Sans* — repli DejaVu Sans.
- **Monospace chiffres** : *JetBrains Mono* — repli DejaVu Sans Mono.
Fichiers attendus : `assets/fonts/display.ttf`, `ui.ttf`, `mono.ttf` (sinon repli système automatique).

## Formes et langage visuel
- Motifs : éventails rayonnants, chevrons, arches à gradins, filets dorés doubles.
- Coins : rayon 6 px ; bordures or 2 px ; ombres portées dures (décalage 4 px, encre 60 %).
- Cartes (grigris, Fortune) : 96×96 px pixel art, cadre doré dont la couleur interne indique la rareté.
- Icônes : 64×64 px pixel art, palette limitée (≤ 8 couleurs de la palette + noir), contour 1 px encre.
- Portraits : 128×128 px, 4 à 6 frames (respiration, clignement, parole).

## 2.5D
Roue, bille, jetons, tapis et props : modélisés low-poly dans Blender (`tools/blender/`), rendus en sprites (turntable 8/16 angles) ou affichés via SubViewport. La roue de jeu est dessinée vectoriellement (taille de deck variable) avec ombrage pseudo-3D (anneaux, reflets, inclinaison 18°).

## Shaders
CRT léger (courbure, scanlines, aberration, vignettage), bloom (glow 2D), dissolve (destruction de case/grigri), brillance d'édition (Brillante : reflet balayé ; Holographique : arc-en-ciel ; Polychrome : teinte cyclique ; Noire : inversion + halo), distorsion de chaleur (Pyromane), flou de mouvement de la bille.

## Animation
Ease out cubique pour les entrées, back/elastic pour les rebonds de cartes, hitstop 40–120 ms sur les gros gains, secousse proportionnelle au log du gain. Tout passe par `JuiceProfile` (0–100 %, mode réduit).

## Validation
Le guide est validé sur 10 icônes de référence (`assets/icons/_style_sheet.png`) avant production en masse.
