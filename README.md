# La Maison Gagne

Roguelite de roulette européenne art déco, Godot 4.7. Tu hérites de la dette de ta famille envers **La Maison**, un casino souterrain dont la roue ne s'arrête jamais. Mise, vise, construis un moteur de grigris absurde, et descends jusqu'à la Roue Originelle.

> **Jeu de hasard simulé.** Monnaie fictive uniquement, aucun achat, aucun lien avec de l'argent réel.

## Jouer
- **Depuis les sources** : installer Godot 4.7.x, puis `godot --path .` à la racine (ou ouvrir `project.godot` dans l'éditeur et appuyer sur F5).
- **Exports** : `build/linux/LaMaisonGagne.x86_64` et `build/windows/LaMaisonGagne.exe` (voir « Exporter »).

### Commandes
Le **mode manette** se règle dans Options → Commandes : *Automatique* (les indications suivent le dernier appareil utilisé), *Activé* (tout à la manette, curseur masqué) ou *Désactivé* (clavier et souris). Seules les indications de l'appareil actif sont affichées, avec des glyphes Xbox 360 en pixel art pour la manette.

| Action | Souris / clavier | Manette |
|---|---|---|
| Naviguer · valider · retour | souris · Entrée · Échap | croix ou stick gauche · A · B |
| Onglets · défiler | clic · molette | LB / RB · stick droit |
| Miser · retirer un jeton | clic gauche (+1), Maj+clic (+5) · clic droit ou Retour arr. | curseur à la croix · A · B |
| Chevaux, transversales, carrés, sixains | bords et coins des cases | LB / RB autour du curseur |
| Annuler · répéter · effacer | Z · R · C | X · Y · L3 |
| Lancer puis relâcher | Espace / bouton LANCER | RT |
| Grigris et cartes Fortune | clic (glisser, double-clic, clic droit) | View : sélection ; A utiliser / vendre ; Y verrouiller ; LB/RB déplacer |
| Choisir une case (carte Fortune) | clic sur la roue | croix, puis A |
| Passer une animation · vitesse | Entrée · F | A ou B · LT |
| Astuces : compris · couper | Entrée · M | A · X |
| Pause | Échap | Menu (Start) |
| Note de test | F8 | R3 |
| Plein écran | F11 · Alt+Entrée | — |

Toutes les commandes sont remappables, au clavier comme à la manette (Options → Commandes). Les champs de texte s'ouvrent au clavier virtuel avec A.

### Affichage
16:9 à toute définition (720p, 1080p, 1440p, 4K), 16:10 (Steam Deck 1280×800) et ultra-larges. Options → Vidéo : mode (fenêtré, plein écran, plein écran exclusif), taille de fenêtre, limite d'images par seconde, préréglage économie (bloom coupé, 60 i/s ; appliqué d'office au premier lancement sur Steam Deck).

## Contenu
3 actes, 8 paliers, 24 échéances · 180 grigris · 24 cases spéciales, 4 éditions, 6 sceaux · 30 cartes Fortune · 20 contrats · 14 créanciers (dont 2 qui manipulent la roue) + 2 secrets + Le Patron + La Maison (3 phases) · 6 personnages · 8 niveaux de Risque · 20 événements · 60 succès · 20 défis · graine du jour et **Course de graine** (classement local par graine) · mode Infini · 3 fins + une vraie fin secrète · FR/EN.

### Steam Deck
Pensé pour le badge **Vérifié** : jouable de bout en bout à la manette (vérifié automatiquement à chaque `tools/check.sh`), glyphes de manette, clavier virtuel, 1280×800 natif, texte d'au moins 9 px, mise en veille. Détail critère par critère : `docs/STEAM_DECK.md`.

## Playtest
Statistiques de jeu **locales** (sur consentement, rien n'est envoyé), notes F8 avec capture, table d'écoute des sons : protocole complet dans `docs/PLAYTEST.md`, rapport avec `python3 tools/telemetry_report.py`.

## Développement
Voir `CLAUDE.md` (conventions) et `docs/` (GDD, bible artistique, décisions, progression, équilibrage, QA, audio, tables de contenu).

```bash
tools/check.sh                                          # tout vérifier (doit être vert)
godot --headless --path . -s res://tests/run_tests.gd   # tests
godot --headless --path . -s res://scripts/sim/sim_main.gd -- --runs=300 --bot=expert --report    # équilibrage → docs/BALANCE.md
godot --headless --path . -s res://scripts/sim/sim_main.gd -- --runs=300 --bot=expert --telemetry=user://dev/bot_ref  # référence pour le rapport de playtest
godot --headless --path . -- --dev-ui-check                     # interface : focus manette, débordements, lisibilité Steam Deck
godot --headless --path . -- --dev-pad-run=500 --dev-debt-mult=0.01   # campagne complète à la manette seule
python3 tools/audio_mix.py                                      # mixage par loudness → audio/sfx_mix.json
godot --headless --path . -s res://tools/fuzz.gd -- --runs=400  # fuzzing de graines
godot --path . -- --dev-run=lea --dev-autoplay=10 --shot-dir=/tmp/shots --perf   # QA à l'écran (mesure GPU/CPU)
```

### Régénérer les assets (tous originaux, générés par script)
```bash
python3 tools/gen_icons.py          # icônes pixel art (tools/icon_specs*.json)
python3 tools/gen_glyphs.py         # glyphes de manette Xbox 360 et souris (pixel art)
python3 tools/gen_input_map.py      # table des commandes → project.godot
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
