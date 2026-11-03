# La Maison Gagne

Roguelite de roulette européenne art déco, Godot 4.7. Tu hérites de la dette de ta famille envers **La Maison**, un casino souterrain dont la roue ne s'arrête jamais. Mise, vise, construis un moteur de grigris absurde, et descends jusqu'à la Roue Originelle.

> **Jeu de hasard simulé.** Monnaie fictive uniquement, aucun achat, aucun lien avec de l'argent réel.

## Jouer
- **Depuis les sources** : installer Godot 4.7.x, puis `godot --path .` à la racine (ou ouvrir `project.godot` dans l'éditeur et appuyer sur F5).
- **Exports** : Windows (`.exe`), Linux (binaire `x86_64`) et **Flatpak** (`.flatpak`), tous autonomes — `tools/build_release.sh` (voir « Exporter »).
- **Android** : APK signé (`LaMaisonGagne-<version>-android-arm64.apk`, release GitHub `v*-android`) : l'ouvrir sur le téléphone et autoriser « Installer des applis inconnues ». Entièrement jouable au doigt (loupe de mise, fiches de cartes, boutons de couleur des épreuves). Construction : `tools/build_android.sh` — voir `docs/ANDROID.md`.

### Commandes
Le **mode manette** se règle dans Options → Commandes : *Automatique* (les indications suivent le dernier appareil utilisé), *Activé* (tout à la manette, curseur masqué) ou *Désactivé* (clavier et souris). Seules les indications de l'appareil actif sont affichées, avec des glyphes Xbox 360 en pixel art pour la manette.

| Action | Souris / clavier | Manette |
|---|---|---|
| Naviguer · valider · retour | souris · Entrée · Échap | croix ou stick gauche · A · B |
| Onglets · défiler | clic · molette | LB / RB · stick droit |
| Miser · retirer un jeton | clic gauche, Maj+clic (+5) · clic droit ou Retour arr. | curseur (croix ou stick gauche) · A · B |
| Taille de la mise (1, 2, 5, 10) | Q / W | LB / RB |
| Chevaux, transversales, carrés, sixains | bords et coins des cases | le curseur avance par demi-case : centre = plein, bord = cheval, coin = carré |
| Annuler · répéter · effacer | Z · R · C | X · Y · L3 |
| Lancer : viser, puis le mini-jeu (élan, effet, lâcher) | Espace ou clic / bouton LANCER ; effet : flèches ou clics gauche/droit | RT ou A ; effet : X Y B A |
| Machine à sous (jackpot) : tirer le levier | Espace, Entrée ou clic | RT ou A |
| Taquiner le décor | clic sur un objet | pichenette du stick droit |
| Grigris et cartes Fortune | clic (glisser, double-clic, clic droit) | View : sélection ; A utiliser / vendre ; Y verrouiller ; LB/RB déplacer |
| Choisir une case (carte Fortune) | clic sur la roue | croix, puis A |
| Passer une animation · vitesse | Entrée · F | A ou B · LT |
| Astuces : compris · couper | Entrée · M | A · X |
| Pause | Échap | Menu (Start) |
| Note de test | F8 | R3 |
| Plein écran | F11 · Alt+Entrée | — |

La sensibilité du stick gauche se règle dans Options → Commandes (et en cours de partie : Pause → Réglages).

Toutes les commandes sont remappables, au clavier comme à la manette (Options → Commandes). Les champs de texte s'ouvrent au clavier virtuel avec A.

### Le lancer
Après la visée, chaque lancer enchaîne **deux épreuves tirées au hasard** parmi quatorze, puis le **lâcher** (frapper quand l'anneau touche la bille) : Élan, Effet (jeu de rythme à 4 pistes sur un groove jazz, funk ou mambo), Les Bouteilles, Mémoire des cartes, Bonneteau, Fléchettes, Coffre-fort, Tour de jetons, Shaker, et depuis la 1.5.1 Le Verre parfait, Le Juke-box, Pluie de jetons, Plus haut plus bas et Tri des jetons. Chaque épreuve s'annonce sur un carton illustré en pixel art, avec sa règle et les commandes du périphérique utilisé ; onze d'entre elles se jouent dans une petite scène 3D (gobelets, cartes, cible, bouteilles, juke-box, coffre…). La qualité (moyenne des épreuves × 0,65 + lâcher × 0,35) ajuste le contrôle de la bille de −10 à +7 points autour de la Précision ; un lancer « moyen » vaut exactement l'ancien lancer. Options → Jeu → Lancer : *Complet* (2 épreuves), *Rapide* (1 épreuve) ou *Simple* (appuyer/relâcher, contrôle neutre).

### Histoire
Une cinématique en pixel art ouvre la toute première partie (maintenir une touche 3 s pour la passer ; à revoir depuis Titre → Prologue). Dialogues à chaque acte, interludes, scènes de première rencontre (Bazar, machine à sous, pacte) et répliques propres à chacun des six personnages jouables.

### Jackpot et machine à sous
Un **plein gagnant** (ou un coup qui solde l'échéance, ou une case à Sceau Cloche) fait surgir Lucette, la machine à sous 3D à **quatre rouleaux** : 1 tirage, 2 après un lancer « Très bien », 3 après un « Parfait ». Les rouleaux s'arrêtent un à un, lentement. Paires, brelans et carrés rapportent de l'argent, du Mult ou du contrôle pour le tour suivant, des jetons de mise en plus… et le brelan de 7 un **tour offert**. Tout est tiré par le moteur avant l'animation.

### Le casino abandonné
La partie se joue sur la table d'un casino laissé à l'abandon, en 3D derrière l'interface : feutre usé, lustre qui grésille, poussière dans la lumière. Les objets posés dans les coins réagissent au clic (lampe, verre de whisky, bouteille, cendrier, dés, cartes, pile de jetons, enseigne au néon), et un rat et une araignée passent de temps en temps. Options → Vidéo → Décor 3D (désactivable).

Certains grigris ont un **malus visuel** pendant les lancers (Flasque de gin : vision double ; Fume-cigarette : fumée ; Monocle fêlé ; Néon agonisant ; Double serré ; Miroir de foire ; Lunettes de nuit), compensé par un bonus. Options → Jus → Malus visuels des grigris pour les atténuer ou les couper (aussi en cours de partie : Pause → Réglages).

### Affichage
Plein écran à la définition native ou à une résolution de rendu au choix ; en fenêtré, 17 définitions courantes de 1280×720 à 5120×2880 : 16:9 (720p, 1080p, **1440p**, 4K, 5K), 16:10 (1280×800 Steam Deck, 1440×900, 1680×1050, 1920×1200, 2560×1600, 2880×1800), 21:9 (2560×1080, 3440×1440, 3840×1600) et 32:9 (5120×1440). Options → Vidéo : mode, résolution, limite d'images, **roue en 3D** (désactivable) et **mode Steam Deck / portable** (texte agrandi, bloom coupé, 60 i/s ; activé d'office sur Steam Deck, désactivable, les réglages précédents sont restaurés).

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
python3 tools/gen_cutscene.py       # illustrations pixel art de la cinématique d'intro
blender -b --factory-startup -P tools/blender/render_props.py -- assets/sprites   # roue, jetons, bille
python3 tools/gen_content_docs.py   # tables docs/content/
```

### Modifier le contenu
Tout le contenu est en JSON dans `data/` (une entrée = un objet avec `id`), avec un langage d'effets déclaratif (déclencheur + conditions + actions, voir `docs/GDD.md` §9). Le tuning est dans `data/balance.json`. Lancer `tools/check.sh` après modification : le validateur signale tout identifiant ou effet inconnu.

### Exporter
Installer les modèles d'export de Godot 4.7.2 (Éditeur → Gérer les modèles d'export), puis :
```bash
tools/build_release.sh            # Windows + Linux + Flatpak → build/
tools/build_release.sh --no-flatpak
```
Produit `build/LaMaisonGagne-<version>-windows-x86_64.zip` (un `.exe` autonome, données embarquées), `build/LaMaisonGagne-<version>-linux-x86_64.tar.gz` (un binaire autonome) et `build/LaMaisonGagne-<version>-x86_64.flatpak` (paquet `packaging/flatpak/`, runtime `org.freedesktop.Platform` 25.08 ; prérequis : `flatpak-builder` et `flatpak install --user flathub org.freedesktop.Platform//25.08 org.freedesktop.Sdk//25.08`). Installer le Flatpak : `flatpak install --user LaMaisonGagne-<version>-x86_64.flatpak`.

Les options de développement n'existent que depuis les sources (binaire éditeur) : `scripts/dev/` et `scripts/sim/` sont exclus des exports, et une session de développement écrit dans `user://dev/`, jamais dans la sauvegarde du joueur.

## Licences
Code et assets originaux du projet. Polices sous SIL OFL 1.1 (`assets/fonts/licenses/`). Détails : `docs/CREDITS.md`.
