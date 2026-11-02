# Crédits et sources

**La Maison Gagne** — jeu de hasard simulé, monnaie fictive, aucun argent réel, aucun achat.

## Développement
Conçu et développé avec Claude Code (Anthropic) pour jonasfreva.

## Moteur et outils
- Godot Engine 4.7 — licence MIT — https://godotengine.org
- gdtoolkit (gdlint/gdformat) — licence MIT
- Blender 5.2 — GPL (outil uniquement, aucun code Blender n'est distribué)
- Claude Code (Anthropic) — conception et programmation assistées
- Écran d'ouverture (`assets/splash/`) : logo Godot par Andrea Calabró (CC BY 4.0, godotengine.org/press) ; logo Blender (Blender Foundation, usage « made with Blender » selon blender.org/about/logo) ; symbole Claude (Anthropic). Marques de leurs propriétaires respectifs, utilisées pour créditer les outils.
- Python 3, numpy, Pillow — outillage hors jeu

## Assets
Tous les assets (icônes, sprites, sons, musiques) sont **générés par les scripts de `tools/`** et sont originaux. Aucune ressource tierce n'est incluse, sauf mention ci-dessous.

| Asset | Source | Licence |
|---|---|---|
| Police display « Limelight » | Sorkin Type Co, via google/fonts | SIL OFL 1.1 (`assets/fonts/licenses/limelight_OFL.txt`) |
| Police UI « Josefin Sans » | Santiago Orozco, via google/fonts | SIL OFL 1.1 (`assets/fonts/licenses/josefinsans_OFL.txt`) |
| Police mono « JetBrains Mono » | JetBrains, via google/fonts | SIL OFL 1.1 (`assets/fonts/licenses/jetbrainsmono_OFL.txt`) |
| Icônes pixel art (`assets/icons/`) | générées par `tools/gen_icons.py` | originales (projet) |
| Effets sonores et ambiance (`audio/sfx/`) | synthétisés par `tools/gen_audio.py` | originaux (projet) |
| Portraits (`assets/portraits/`) | générés par `tools/gen_portraits.py` | originaux (projet) |
| Illustrations de la cinématique (`assets/cutscene/`) | générées par `tools/gen_cutscene.py` | originales (projet) |
| Props 3D rendus (`assets/sprites/` : roue, jetons, bille) | modélisés et rendus par `tools/blender/render_props.py` (Blender, Cycles) | originaux (projet) |
| Shaders (`shaders/`) | écrits pour le projet | originaux (projet) |
| Musiques (`audio/music/`) | composées et synthétisées par `tools/gen_audio.py` | originales (projet) |

## Inspirations (mécaniques et ressenti uniquement)
Balatro, Clover Pit, Raccoin. Aucun nom, personnage, visuel ou son n'en est repris.
