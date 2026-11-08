# CLAUDE.md — La Maison Gagne

Roguelite de roulette européenne (Godot 4.7, GDScript typé). Jeu de hasard **simulé**, monnaie fictive, aucun achat.

## Stack
- Godot 4.7.x stable (`godot --version`), GDScript typage statique strict, `class_name` systématique, pas de C#.
- Python 3 + uv (+ numpy, Pillow) pour l'outillage dans `tools/`. Blender 5.x (`blender -b`) pour les assets 3D.
- Linter : gdtoolkit (`gdlint`, `gdformat`) installé via `uv tool install gdtoolkit`.
- Tests : runner maison headless `tests/run_tests.gd` (aucune dépendance externe, cf. DECISIONS D-003).

## Commandes
- Tout vérifier : `tools/check.sh` (import → lint → tests → simulation rapide). Doit finir sans erreur ni warning.
- Import : `godot --headless --path . --import`
- Tests : `godot --headless --path . -s res://tests/run_tests.gd`
- Simulation : `godot --headless --path . -s res://scripts/sim/sim_main.gd -- --runs=500 --bot=greedy`
- Validation des données : `godot --headless --path . -s res://tools/validate_data.gd`
- Banc des épreuves : `godot --headless --path . -- --dev-trial-bench=3 [--dev-trials-only=catch,dice]` (35 épreuves ; bot ≥ 0,8, humain ≥ 0,55, inactif ≤ 0,4). Bots : un geste de manette par image (`axis`, `confirm`, `sym`+`symbol`, `dir`, `hold`, `release`), cf. D-069.
- À-coups : `--dev-hitch` (journal des images > 50 ms) ; réglages forcés : `--dev-set=video/preset=ultra;video/scaling=fsr2`.
- Musée : `godot --path . -- --dev-screen=museum --dev-tab=<salle 0-6> [--dev-trials=<épreuve> --dev-autoplay=1]` (D-074); `--dev-focus=N` (objet), `--dev-tutos=1` (tuto forcé, aussi en partie automatique), cf. D-077.
- Données du joueur : journal `user://journal/*.jsonl` ; export Options → « Exporter mes données » (`DataExport`, D-084) ; analyse `python3 tools/telemetry_report.py --human <archive.zip>`.
- Défaite : `--dev-defeat-cutscene` (le bilan de dev passe par la cinématique, D-080).
- Lancer le jeu : `godot --path .`
- Android : `tools/build_android.sh [--debug] [--install]` (APK dans `build/`, cf. `docs/ANDROID.md`) ; émulation sur PC : `godot --path . -- --dev-mobile` ; interface mobile : `godot --headless --path . -- --dev-ui-check --dev-mobile` ; mémoire vidéo : `--dev-mem=200`.
- Pixel 7 : `~/Android/Sdk/platform-tools/adb install -r build/LaMaisonGagne-<ver>-android-arm64.apk`, journal `adb logcat -s godot:V`.

## Arborescence
- `scripts/core/` : logique **pure** (RefCounted, aucun accès aux autoloads, aucun Node). Testable headless.
- `scripts/core/effects/` : interpréteur d'effets data-driven (conditions + actions).
- `scripts/autoload/` : EventBus, Settings, Localization, RngService, DataRegistry, SaveSystem, AudioBus, GameState.
- `scripts/presentation/` : vues (roue, tapis, score animé), lisent la logique, ne la modifient que via le contrôleur.
- `scripts/ui/` : écrans et widgets. `scenes/` : `.tscn` (racine + script, enfants construits en code si dynamiques).
- `data/` : contenu JSON (une entrée = un objet avec `id`). `data/balance.json` : toutes les constantes de tuning.
- `docs/` : GDD, ART_BIBLE, DECISIONS, PROGRESS, BALANCE, CREDITS, `content/` (tables).
- `tools/` : scripts d'outillage (audio, icônes, validation, check). `tests/` : tests unitaires/intégration.

## Règles
1. Aucun nombre magique : constantes de jeu dans `data/balance.json` (lu via `Balance`), constantes visuelles dans `JuiceProfile`/thème.
2. Tout le contenu est data-driven (JSON validé par `tools/validate_data.gd`). Jamais de contenu codé en dur.
3. Hasard : uniquement via `RngStreams` (flux `wheel`, `shop`, `effects`, `cosmetic`). Jamais `randi()`/`randf()` globaux en logique.
4. Le résultat d'un lancer est calculé avant l'animation ; l'animation raconte le résultat.
5. Séparation logique / présentation : le moteur de score produit une liste de `ScoreEvent` que la présentation rejoue.
6. Après chaque modif : `tools/check.sh` doit passer (zéro erreur, zéro warning).
7. Commits conventionnels (`feat:`, `fix:`, `docs:`, `test:`, `chore:`, `refactor:`), un tag `phase-NN-nom` par phase.
8. Textes joueur : FR par défaut, EN disponible. UI via `tr()` + `localization/strings.csv` ; contenu via champs `name_fr/name_en`.
9. Journal : `docs/PROGRESS.md` (où on en est), décisions : `docs/DECISIONS.md`.

## Conventions GDScript
- `snake_case` fichiers/fonctions/variables, `PascalCase` classes, `UPPER_SNAKE` constantes.
- Toujours typer : `var x: int = 0`, `func f(a: int) -> void:`, `Array[Pocket]`, `Dictionary[String, int]` quand utile.
- Signaux typés dans `EventBus`, nommés au passé (`bet_placed`, `spin_resolved`).

┌────────────────────────────────────────────────────────────────────────────┬──────────────────────────────────────────────────────────────────────────────┐
│                                  Élément                                   │                                 Emplacement                                  │
├────────────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────┤
│ JDK 17 (Temurin)                                                           │ ~/.local/jdk/jdk17                                                           │
├────────────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────┤
│ Android SDK : platform-tools, build-tools 36.1.0, Android 36, NDK 29       │ ~/Android/Sdk                                                                │
├────────────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────┤
│ Templates d'export Android de Godot 4.7.2                                  │ ~/.local/share/godot/export_templates/4.7.2.stable                           │
├────────────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────┤
│ Clé de signature debug                                                     │ ~/.android/debug.keystore                                                    │
├────────────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────┤
│ Chemins du JDK, du SDK et de la clé dans les paramètres de l'éditeur Godot │ ~/.config/godot/editor_settings-4.7.tres (copie de l'ancien fichier en .bak) │
└────────────────────────────────────────────────────────────────────────────┴──────────────────────────────────────────────────────────────────────────────┘
