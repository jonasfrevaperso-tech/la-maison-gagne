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
| Lancer puis relâcher | Espace / bouton LANCER | Start |
| Passer une animation | Entrée | B |
| Vitesse ×1/×2/×4 | F | Back |
Toutes les touches clavier sont remappables (Options → Commandes).

## Contenu
3 actes, 8 paliers, 24 échéances · 150 grigris · 24 cases spéciales, 4 éditions, 6 sceaux · 30 cartes Fortune · 20 contrats · 12 créanciers + 2 secrets + Le Patron + La Maison (3 phases) · 6 personnages · 8 niveaux de Risque · 20 événements · 60 succès · 20 défis · graine du jour · mode Infini · 3 fins + une vraie fin secrète · FR/EN.

## Développement
Voir `CLAUDE.md` (conventions) et `docs/` (GDD, bible artistique, décisions, progression, équilibrage, QA, audio, tables de contenu).

```bash
tools/check.sh                                          # tout vérifier (doit être vert)
godot --headless --path . -s res://tests/run_tests.gd   # tests
godot --headless --path . -s res://scripts/sim/sim_main.gd -- --runs=300 --bot=synergy --report   # équilibrage → docs/BALANCE.md
godot --headless --path . -s res://tools/fuzz.gd -- --runs=400  # fuzzing de graines
godot --path . -- --dev-run=lea --dev-autoplay=10 --shot-dir=/tmp/shots --perf   # QA à l'écran
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

## Licences
Code et assets originaux du projet. Polices sous SIL OFL 1.1 (`assets/fonts/licenses/`). Détails : `docs/CREDITS.md`.
