# Journal d'avancement

> Reprise après coupure : lire ce fichier, `CLAUDE.md`, puis `docs/DECISIONS.md`. Lancer `tools/check.sh`.

## État courant
- Phase en cours : **Phase 1 — Conception**
- Dernier tag : `phase-00-recon`

## Phase 0 — Reconnaissance ✅
- Environnement : Godot 4.7.2 (MCP godot OK), Blender 5.2.2, Python 3.14 + numpy 2.4 + Pillow 12, uv, gdtoolkit 4 (installé via uv), git 2.53, 12 cœurs.
- Dépôt git initialisé (`main`), structure `scenes/ scripts/ data/ assets/ shaders/ ui/ audio/ tools/ tests/ docs/ localization/`.
- Socle logique pur écrit dès la Phase 0 (roue, RNG à flux, paris, lancer, moteur d'effets, score, run, boutique) pour que la Phase 2 se concentre sur la présentation.
- 8 autoloads (EventBus, Settings, Localization, RngService, DataRegistry, SaveSystem, AudioBus, GameState), écran titre, transitions rideaux, CRT + bloom.
- Sortie : le projet s'importe et démarre sans erreur ni warning.

## Rapport de phase
Format : fait / testé / reste à faire / risques.
