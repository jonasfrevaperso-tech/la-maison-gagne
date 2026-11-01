# La Maison Gagne

Roguelite de roulette européenne art déco, Godot 4.7. Tu hérites de la dette de ta famille envers **La Maison**, un casino souterrain dont la roue ne s'arrête jamais. Mise, vise, construis un moteur de grigris absurde, et descends jusqu'à la Roue Originelle.

> **Jeu de hasard simulé.** Monnaie fictive uniquement, aucun achat, aucun lien avec de l'argent réel.

## Jouer
- **Depuis les sources** : installer Godot 4.7.x, puis `godot --path .` à la racine (ou ouvrir `project.godot` dans l'éditeur et appuyer sur F5).
- **Exports** : `build/linux/LaMaisonGagne.x86_64` et `build/windows/LaMaisonGagne.exe` (voir « Exporter »).

### Commandes
| Action | Souris / clavier | Manette |
|---|---|---|
| Miser | clic gauche (+1), Maj+clic (+5), molette | croix/stick : curseur · A : miser · LB/RB : chevaux, transversales, carrés, sixains |
| Retirer / annuler | clic droit · Ctrl+Z | X |
| Répéter le dernier pari | R | Y |
| Effacer les mises | C | — |
| Lancer puis relâcher | Espace / bouton LANCER | Menu (Start) |
| Passer une animation | Entrée | B |
| Vitesse ×1/×2/×4 | F | View (Back) |
| Plein écran / fenêtré | F11 · Alt+Entrée | — |
| Noter un moment de jeu (playtest) | F8 | menu pause |
Toutes les touches clavier sont remappables (Options → Commandes). L'aide sous le tapis affiche les touches réellement assignées, pour le clavier ou la manette selon le dernier périphérique utilisé.

### Affichage
16:9 à toute définition (720p, 1080p, 1440p, 4K), 16:10 (Steam Deck 1280×800) et ultra-larges. Options → Vidéo : mode (fenêtré, plein écran, plein écran exclusif), taille de fenêtre, limite d'images par seconde, préréglage économie (bloom coupé, 60 i/s ; appliqué d'office au premier lancement sur Steam Deck).

## Contenu
3 actes, 8 paliers, 24 échéances · 150 grigris · 24 cases spéciales, 4 éditions, 6 sceaux · 30 cartes Fortune · 20 contrats · 12 créanciers + 2 secrets + Le Patron + La Maison (3 phases) · 6 personnages · 8 niveaux de Risque · 20 événements · 60 succès · 20 défis · graine du jour · mode Infini · 3 fins + une vraie fin secrète · FR/EN.

## Playtest
Statistiques de jeu **locales** (sur consentement, rien n'est envoyé), notes F8 avec capture, table d'écoute des sons : protocole complet dans `docs/PLAYTEST.md`, rapport avec `python3 tools/telemetry_report.py`.

## Développement
Voir `CLAUDE.md` (conventions) et `docs/` (GDD, bible artistique, décisions, progression, équilibrage, QA, audio, tables de contenu).

```bash
tools/check.sh                                          # tout vérifier (doit être vert)
godot --headless --path . -s res://tests/run_tests.gd   # tests
godot --headless --path . -s res://scripts/sim/sim_main.gd -- --runs=300 --bot=expert --report    # équilibrage → docs/BALANCE.md
godot --headless --path . -s res://scripts/sim/sim_main.gd -- --runs=300 --bot=expert --telemetry=user://dev/bot_ref  # référence pour le rapport de playtest
godot --headless --path . -- --dev-ui-check                     # interface : focus manette et débordements, 3 résolutions
python3 tools/audio_mix.py                                      # mixage par loudness → audio/sfx_mix.json
godot --headless --path . -s res://tools/fuzz.gd -- --runs=400  # fuzzing de graines
godot --path . -- --dev-run=lea --dev-autoplay=10 --shot-dir=/tmp/shots --perf   # QA à l'écran (mesure GPU/CPU)
```

### Régénérer les assets (tous originaux, générés par script)
```bash
python3 tools/gen_icons.py          # icônes pixel art (tools/icon_specs*.json)
python3 tools/gen_portraits.py      # portraits animés
python3 tools/gen_audio.py          # effets, ambiance, musiques (numpy + ffmpeg)
blender -b --factory-startup -P tools/blender/render_props.py -- assets/sprites   # roue, jetons, bille
python3 tools/gen_content_docs.py   # tables docs/content/
```

### Modifier le contenu
Tout le contenu est en JSON dans `data/` (une entrée = un objet avec `id`), avec un langage d'effets déclaratif (déclencheur + conditions + actions, voir `docs/GDD.md` §9). Le tuning est dans `data/balance.json`. Lancer `tools/check.sh` après modification : le validateur signale tout identifiant ou effet inconnu.

### Exporter
Installer les modèles d'export de Godot 4.7.2 (Éditeur → Gérer les modèles d'export), puis :
```bash
godot --headless --path . --export-release "Linux" build/linux/LaMaisonGagne.x86_64
godot --headless --path . --export-release "Windows" build/windows/LaMaisonGagne.exe
```

Les options de développement n'existent que depuis les sources (binaire éditeur) : `scripts/dev/` et `scripts/sim/` sont exclus des exports, et une session de développement écrit dans `user://dev/`, jamais dans la sauvegarde du joueur.

## Licences
Code et assets originaux du projet. Polices sous SIL OFL 1.1 (`assets/fonts/licenses/`). Détails : `docs/CREDITS.md`.
