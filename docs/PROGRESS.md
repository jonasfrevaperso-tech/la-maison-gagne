# Journal d'avancement

> Reprise après coupure : lire ce fichier, `CLAUDE.md`, puis `docs/DECISIONS.md`. Lancer `tools/check.sh`.

## État courant
- Phase en cours : **Livré (1.2.0)** — suite : test sur un vrai Steam Deck (`docs/STEAM_DECK.md`), sessions humaines (`docs/PLAYTEST.md`), `docs/ROADMAP.md` (1.3)
- Dernier tag : `v1.2.0`

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

## Phase 6 — Contenu complet ✅
- Fait : 150 grigris (60/55/20/15, dont 108 écrits par le sous-agent « contenu »), 30 Fortune, 20 contrats, 24 cases + 4 éditions + 6 sceaux, 12 créanciers + 2 secrets + Patron + La Maison (3 phases), 6 personnages, 8 risques, 20 événements (garantis à chaque acte, 40 % aux autres paliers, choix conditionnels), 60 succès, 20 défis ; tables `docs/content/*.md` générées (`tools/gen_content_docs.py`) ; 235 icônes.
- Testé : couverture à 100 % (harnais enrichi d'une boutique simulée), tests événements/succès/défis ; `check.sh` vert.
- Risques : équilibrage du nouveau contenu → phase 12.

## Phase 7 — Méta et campagne ✅
- Fait : Hall (personnages, Risque max, défis jouables, graine du jour, fins), Codex (collection vue/masquée, créanciers rencontrés), Succès (60, notifications), Statistiques ; campagne : intros Actes I-III, clôtures d'acte, finale à choix → 3 fins + vraie fin secrète (lettre de grand-père + aucun pacte) ; créancier secret L'Ombre du Grand-Père (déclenché par l'histoire), Croupier d'Or en mode Infini ; Fantôme débloqué par succès.
- Testé : `check.sh` vert, captures des écrans méta.

## Phase 8 — Tutoriel ✅
- Fait : `TutorialDirector` piloté par `data/events/tutorial.json` (14 bulles : objectif, mises, paris intérieurs, budget, lancer, visée, rebond fou, score, historique, boutique, grigris, Fortune, créancier, pacte), ancrées sur l'élément concerné, non bloquantes, « Couper les conseils », rejouables (Options → Rejouer le tutoriel) ; premier run guidé (dettes de l'Acte I ×0,85) ; l'ancienne fenêtre d'aide unique est supprimée.
- Testé : capture sur profil vierge, `check.sh` vert.

## Phase 9 — Direction artistique finale ✅
- Fait : 24 portraits pixel art 128×128 animés (repos, clignement, parole ×2) par `tools/gen_portraits.py` ; props 3D low-poly modélisés et rendus dans Blender en CLI (`tools/blender/render_props.py` : roue 3/4 pour l'écran titre, jetons 4 couleurs, bille) ; 235 icônes ; shaders : CRT, bloom, éditions (brillante/holo/polychrome/noire), dissolution en braises (vente), distorsion de chaleur (Pyromane, La Maison phase 3, défi Brasier) ; icônes de type sur la roue ; menu titre resserré.
- Limite : la config OCIO de Blender (Fedora) est incompatible avec la lib installée → pas de tone mapping, éclairage compensé à la main.

## Phase 10 — Audio ✅
- Fait : table de mixage par son (`audio/sfx_mix.json`) qui ramène les sons à onde carrée (Mult, blips, erreurs) au niveau des autres ; musique adaptative pilotée par la tension (progression de la dette, créancier, dernier tour) en plus du Mult pendant le score ; sous-titres supplémentaires (remboursement, échec, créancier, destruction) ; rapport objectif `tools/audio_report.py` → `docs/AUDIO.md` (crête, RMS, silence, raccord des boucles) intégré à `check.sh`.
- Limite : aucune écoute humaine ; seules des mesures objectives valident le son.

## Phase 11 — Jus et polish ✅
- Fait (catalogue section 9 complété) : zoom caméra sur la fin de course de la bille, jetons qui rebondissent à la pose, cases couvertes surlignées en or dans la zone de visée (action 6 de la revue), teinte de fond par créancier qui s'intensifie à chaque phase, ombres mouvantes, fondu « CRT qui s'éteint » vers titre/résumé, toasts déplacés. Tout reste modulé par `JuiceProfile` (0–100 %, mode réduit).

## Phase 12 — Équilibrage ✅
- Plan : mesurer avec le bot compétent (« synergy », Monte-Carlo), balayer les leviers avec le bot rapide (glouton), confirmer.
- Fait : simulateur enrichi (offres suivies, taux de choix *quand proposé*, surcharges `--set=chemin=valeur` pour les balayages, bot qui sait relancer l'étal, Monte-Carlo 2× plus rapide). Balayage : baisser les dettes seul a peu d'effet (5 → 16 % pour le glouton) ; l'économie est le vrai levier. Réglage retenu : dettes 240/600/1200/2500/4800/8500/14000/21000, départ 8 $, récompenses 5/6/8 $, plafond d'intérêts 6 $.
- Passe sur les grigris (taux de choix *quand proposé*) : nerf de 11 dominants, renfort de 10 délaissés ; une passe supplémentaire a été annulée (elle baissait la puissance sans corriger les taux de choix, qui reflètent surtout la préférence du bot pour les communs bon marché).
- Résultat livré (300 runs, déterministe) : bot compétent **39,7 %** de victoires au Risque 0 (cible 35–45 %), survie régulière par palier (93/89/82/72/61/53/47 %), personnages entre 33 et 45 %. Runs gagnants : 48 tours en moyenne, 29,5 min au rythme du modèle (20 s/tour), ~35–42 min au rythme humain estimé (25–30 s/tour). Rapport : `docs/BALANCE.md`.
- Écarts restants : 10 dominants (2,0–3,3×) et 12 délaissés, en grande partie artefacts du bot (documentés dans le rapport) ; à revalider avec des joueurs.
- Risques : bots ≠ humains ; les grigris à croissance lente sont sous-évalués par le Monte-Carlo court (biais documenté dans BALANCE.md).

## Phase 13 — QA ✅
- Fait : fuzzing de graines (`tools/fuzz.gd`, intégré à `check.sh`) → 4 bugs réels corrigés avec tests de non-régression (perte de mises au rechargement, blocage par règles cumulées, tours négatifs, sérialisation inexacte) + fuite audio à la fermeture ; support manette complet du tapis (curseur, cycle des paris intérieurs, remappage) ; mesure de performance (`--perf` : 142 FPS de moyenne, 1 % lent 10 ms) ; résolutions 16:9/16:10 vérifiées ; plan et bilan dans `docs/QA.md`.
- Testé : 54 tests, 2 400 runs fuzzés sans violation, `check.sh` vert.

## Phase 14 — Livraison ✅
- Fait : modèles d'export officiels 4.7.2 installés, `export_presets.cfg` (Linux x86_64, Windows x86_64, données JSON incluses, outillage exclu), binaires exportés et binaire Linux testé (données chargées, tours joués) ; `README.md`, `docs/RELEASE_NOTES.md`, `docs/POSTMORTEM.md`, `docs/ROADMAP.md`.
- Limites : Windows et Steam Deck non testés sur matériel réel ; aucun test humain.

## Version 1.1 — Retours de table ✅
Plan : (0) corriger les retours de la 1.0 → (1) télémétrie locale → (2) historique et statistiques → (3) notes de test F8 → (4) rapport joueurs vs bot + propositions → (5) audio (synthèse physique, loudness, table d'écoute) → (6) Steam Deck / Windows (multi-résolution, contrôle d'interface, veille, performance) → (7) bot expert et contrôle d'équilibrage → (8) docs, exports, tag.
- (0) Ligne d'aide générée depuis les vraies touches (clavier ou manette), sessions de dev isolées dans `user://dev/` (cause de la « partie en cours »), confirmation avant d'écraser un run, cadre d'écrans + scène de référence (16:9 toute définition, 16:10, ultra-large), options d'affichage, options de dev retirées des exports.
- (1–4) `RunTelemetry` (pur) + autoload `Telemetry` (consentement, temps actif, JSONL par run), `NoteOverlay` (F8, capture), `RunHistory` (derniers runs, survie par palier, temps de jeu), `sim_main --telemetry`, `tools/telemetry_report.py`, `docs/PLAYTEST.md`.
- (5) Jetons, bille et cylindre en synthèse modale ; `tools/audio_mix.py` (loudness par famille, vérifiée par `check.sh`) ; table d'écoute dans les options.
- (6) `--dev-ui-check` (focus manette, boutons dans l'écran, 10 écrans + 8 surcouches + 2 états du run × 3 tailles) a trouvé 4 défauts réels (pactes/événements hors écran, titre et sélection débordants avec texte agrandi, rangée de relance hors écran) ; sauvegarde à la mise en veille ; mesure GPU (`--perf`) et préréglage économie appliqué d'office sur Steam Deck.
- (7) Bot expert : la version « espérance brute » ne gagnait que 36,6 % (paris à forte variance) ; avec une utilité plafonnée par le besoin de l'échéance, 44,2 % sur 330 runs, survie 95→91 %, paris variés. Règlement intérieur, seul dominant pour les deux bots, passe de +2 à +1,5 Mult par contrat. Détails : `docs/BALANCE.md`.
- Testé : 60 tests, `check.sh` vert (import, données, i18n, audio, mixage, lint, tests, fuzzing, simulation, interface, démarrage) ; binaires de release sans scripts de dev, options `--dev-*` inertes.
- Reste (humain) : sessions de playtest, écoute, Steam Deck et Windows réels.

## Version 1.2 — Tapis de jeu ✅
Plan : (1) entrées : mode manette, schéma complet, glyphes Xbox 360, invites du seul appareil actif → (2) prise en charge manette totale (menus, astuces, boutique, Fortune, paquets, clavier virtuel) prouvée par une campagne automatique → (3) Steam Deck Vérifié (lisibilité, clavier virtuel, liste de contrôle) → (4) refonte visuelle → (5) passe de test, rythme et animations → (6) contenu 1.2 → (7) docs, exports, tag.
- (1) Cause racine : `ui_accept`/`ui_cancel` sans manette en Godot 4.7 (D-020). `tools/gen_input_map.py`, `InputGlyphs`, `PromptBar`, `PromptBadge`, `tools/gen_glyphs.py` (26 glyphes), remappage clavier et manette.
- (2) `PadNavigator`, `RunScreenInput` (mode objets, ciblage à la croix), cartes focalisables (infobulle, LB/RB, Y), `VirtualKeyboard`, astuces A/X avec glyphes inline. `--dev-pad-run` gagne la campagne à la manette seule ; défaut trouvé et corrigé (focus sur un choix indisponible).
- (3) Plancher de police et vraie taille de texte (D-023), audit 9 px dans `--dev-ui-check` (4 configurations, 80 vues), `docs/STEAM_DECK.md`.
- (4) Boutique, fin de run, Hall, HUD ; DecoDivider, tuiles, cartes de section, boutons animés.
- (5) Décompte qui s'emballe, bille 3,1 s, transitions plus courtes ; campagnes complètes au clavier (pilote automatique) et à la manette sans erreur.
- (6) 30 grigris (`data/grigris/grigris_v12.json`) avec icônes dédiées, déclencheurs `on_seal` / `on_pocket_destroyed` enfin émis pour les grigris, variables `seal_count`, `landing_copies`, `endless_tiers`, opération `swap_pockets` ; créanciers Le Bonneteur et La Valseuse (portraits) ; Course de graine (`RunHistory.leaderboard`, écran dédié).
- Testé : 68 tests, `check.sh` vert (dont interface 80 vues et campagne à la manette).

## Rapport de phase
Format : fait / testé / reste à faire / risques.
