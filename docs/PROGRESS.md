# Journal d'avancement

> Reprise après coupure : lire ce fichier, `CLAUDE.md`, puis `docs/DECISIONS.md`. Lancer `tools/check.sh`.

## État courant
- Phase en cours : **Phase 6 — Contenu complet**
- Dernier tag : `phase-05-vertical-slice`

## Phase 0 — Reconnaissance ✅
- Environnement : Godot 4.7.2 (MCP godot OK), Blender 5.2.2, Python 3.14 + numpy 2.4 + Pillow 12, uv, gdtoolkit 4 (installé via uv), git 2.53, 12 cœurs.
- Dépôt git initialisé (`main`), structure `scenes/ scripts/ data/ assets/ shaders/ ui/ audio/ tools/ tests/ docs/ localization/`.
- Socle logique pur écrit dès la Phase 0 (roue, RNG à flux, paris, lancer, moteur d'effets, score, run, boutique) pour que la Phase 2 se concentre sur la présentation.
- 8 autoloads (EventBus, Settings, Localization, RngService, DataRegistry, SaveSystem, AudioBus, GameState), écran titre, transitions rideaux, CRT + bloom.
- Sortie : le projet s'importe et démarre sans erreur ni warning.

## Phase 1 — Conception ✅
- Plan : GDD complet avec formules → bible artistique → données initiales (data-driven) → validateur.
- Fait : `docs/GDD.md` (structure, formules de score/lancer/économie, langage d'effets), `docs/ART_BIBLE.md` (palette hex, typos OFL, shaders), données : 25 types de cases, 4 éditions, 6 sceaux, 42 grigris, 13 Fortune, 20 contrats (10 chaînes), 16 créanciers (dont 2 secrets, Patron, La Maison en 3 phases), 6 personnages, 8 risques.
- Testé : `tools/validate_data.gd` (ids, champs, vocabulaire d'effets, références croisées) → 0 erreur.
- Reste : tables complètes en docs/content/ (générées depuis data en phase 6), événements, succès, défis.
- Risques : équilibrage initial très dur (0–1 % de victoires simulées) → traité en phase 12, ajusté légèrement avant la tranche verticale.

## Phase 2 — Prototype ✅
- Plan : vues roue/tapis/score → machine à états d'interface → surcouches → pilote automatique QA.
- Fait : `WheelView` (roue 2.5D vectorielle à taille variable, visée par aiguille, bille qui raconte un résultat déjà tiré, ralenti sur quasi-raté), `TableView` (tapis européen complet, détection fine plein/cheval/carré/transversale/sixain), `ScorePanel`, `ScorePresenter` (rejoue les ScoreEvent un à un), `DebtGauge`, grigris (glisser-déposer, verrouillage, infobulles riches), boutique, pacte, récompense, intro de créancier, pause, sélection perso/risque/graine, résumé de défaite, options complètes, crédits. 269 chaînes FR/EN.
- Testé : 33 tests unitaires/intégration verts, lint propre, pilote automatique : 6 tours réels joués à l'écran avec passage par récompense et boutique, captures vérifiées.
- Reste : icônes définitives, audio, tutoriel.
- Risques : perfs du rendu vectoriel de la roue (à profiler phase 13).

## Phase 3 — Boucle centrale ✅
- Plan : vérifier de bout en bout la boucle déjà écrite en logique (échéances, dette, tours, Zéro, pipeline, fin de run, mode Infini) à l'écran.
- Fait : run complet joué par le pilote automatique jusqu'à l'écran de victoire (24 échéances, créanciers, pacte, boutique), mode Infini, résumé corrigé.
- Testé : 34 tests (dont victoire→Infini en logique pure), `check.sh` vert.
- Reste : contenu (phase 4+), équilibrage.
- Risques : difficulté actuelle trop élevée pour un humain moyen (simulation 0 %) → ajustement avant la tranche verticale.

## Phase 4 — Systèmes de contenu ✅
- Plan : tests de couverture pilotés par les données (chaque entrée doit avoir un effet observable), sauvegarde robuste, lisibilité des effets.
- Fait : test de couverture sur les 42 grigris, 24 cases spéciales, 4 éditions, 6 sceaux, 13 Fortune, 20 contrats (chaînes vérifiées), 16 créanciers ; événements visibles pour re-déclenchements de paris, budget/précision temporaires ; sauvegarde : relecture silencieuse des fichiers corrompus + bascule sur .bak + avertissement à l'écran titre ; remappage clavier persistant.
- Testé : 44 tests, `check.sh` vert (zéro erreur/warning dans tous les journaux).
- Reste : contenu complet (phase 6).
- Risques : aucun bloquant.

## Phase 5 — Tranche verticale ✅
- Plan : art provisoire cohérent (polices, icônes), audio provisoire (SFX + musique), narration de l'Acte I, équilibrage de l'Acte I, revue critique.
- Fait : polices OFL (Limelight, Josefin Sans, JetBrains Mono) avec graisse fixée et repli symboles ; générateur d'icônes pixel art (`tools/gen_icons.py`, style validé sur 10 icônes puis 110 générées) ; synthétiseur audio (`tools/gen_audio.py` : 306 SFX avec variantes, ambiance de salle, 6 musiques × 3 couches dynamiques en OGG) ; système de dialogues visual novel (portraits, blips, choix à effets) + carte de titre d'acte animée + dialogue d'ouverture et de clôture de l'Acte I ; icônes de type sur la roue ; retour « dans la zone / rebond fou » ; option d'assistance de visée ; sortie propre sans fuite (audio coupé, caches statiques vidés).
- Équilibrage : contrôle de base 35 → 45 %, première dette 240, courbe des paliers adoucie. Bot glouton : 90 % passent le palier 1, ~58 % l'Acte I, 9,8 % de victoires.
- Testé : `check.sh` vert ; Acte I joué à l'écran avec le son, zéro erreur.
- Revue : `docs/REVIEW_VERTICAL_SLICE.md` (7 actions planifiées).
- Risques : ressenti humain non vérifié (aucun joueur réel).

## Rapport de phase
Format : fait / testé / reste à faire / risques.
