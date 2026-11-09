# Journal d'avancement

> Reprise après coupure : lire ce fichier, `CLAUDE.md`, puis `docs/DECISIONS.md`. Lancer `tools/check.sh`.

## État courant
- Phase en cours : **Livré (1.9.0 « Répétition générale »)** — voir la section 1.9.0 en fin de fichier
- Dernier tag : `v1.9.0` / `v1.9.0-android`

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

## Version 1.3 — Table de casino ✅
- Plan : (1) manette : stick → appuis de croix réglables, gâchettes à un appui, curseur par demi-case, mise sur LB/RB ; (2) mini-jeu de lancer + équilibrage par simulations ; (3) roue 3D, roue de titre, gerbes 3D ; (4) fiches de cases illustrées ; (5) réglages en jeu ; (6) résolutions et mode Steam Deck ; (7) écran d'ouverture ; (8) exports Windows / Linux / Flatpak ; (9) docs, check, tag.
- Fait : tout le plan. Nouveaux fichiers : `GameInput`, `StickRepeater`, `ThrowSkill`, `ThrowMinigame`, `RunScreenThrow`, `Wheel3D`, `TitleWheel`, `ChipBurst3D`, `PocketCard`, `QuickSettings`, `SplashScreen`, `tools/gen_stat_icons.py`, `tools/build_release.sh`, `packaging/flatpak/`.
- Testé : `check.sh` vert (tests manette/curseur/mini-jeu, interface avec réglages rapides, campagne manette avec mini-jeu), captures 3D (roue, titre, gerbes, écran d'ouverture), Flatpak installé et lancé (Vulkan), équilibrage (`docs/BALANCE.md`).
- Reste humain : jouer le mini-jeu (ressenti des fenêtres), Steam Deck réel, Windows réel.

## Version 1.4 — Le Casino Abandonné ✅ (tag v1.4.0)
Plan (chaque étape : code → tests → captures → corrections) :
1. Écran de démarrage Godot noir (pas de logo ni de gris).
2. Fiches de paris illustrées (icônes, couleurs) en infobulle et à la manette ; correction du débordement sur « FORTUNE ».
3. Rythme : dialogues, lancer de bille et mini-jeu ralentis (constantes JuiceProfile / balance).
4. Mini-jeu de lancer v2, plus ambitieux et plus exigeant, esprit QTE : élan maintenu (charger/relâcher), effet (suite d'invites à frapper en rythme), lâcher (anneau). Référence de qualité recalibrée.
5. Jackpot (plein gagnant) → machine à sous en surcouche, 1 à 3 tirages selon la qualité du lancer ; gains temporaires (Mult, contrôle, budget, tour offert, argent) calculés dans le cœur (flux `effects`), joués en « moment à dopamine » (sons, lumières, pièces).
6. Grigris à malus visuels (vision alcoolisée, fumée, monocle fêlé, néon qui grésille, tremblements, miroir), effets cohérents avec leur nom ; option d'accessibilité pour les atténuer.
7. Décor : table de casino d'un casino abandonné en 3D derrière toute l'interface, objets décoratifs interactifs (lampe, verre, bouteille, cendrier, dés, piles de jetons, néon, téléphone, araignée, rat…), sons dédiés ; option pour le désactiver.
8. Tutoriel : chaque fonctionnalité expliquée au fil de la première partie.
9. Équilibrage par simulations (machine à sous incluse), docs, check, exports, tag v1.4.0.

Bilan 1.4 : les 9 étapes sont livrées. `tools/check.sh` vert (83 tests, interface 3 résolutions, campagne manette). Équilibrage : neutre 45,5 %, maladroit 41,7 %, adroit 56,2 % (`docs/BALANCE.md`). Exports Windows, Linux, Flatpak régénérés.

## Version 1.5 — « Grande Ouverture »
Plan (chaque étape : code → tests → captures → corrections) :
1. Bugs signalés : fiche de pari manette (placement hors du tapis et de la sélection, fond translucide) ; jackpot perdu quand une échéance est remboursée sur le même tour ; paquet acheté sans choix (choix obligatoire) ; animation de sélection du Bazar ; roue 3D coupée (rendue derrière l'interface, sans bord coupé).
2. Mise en page : Bazar, dialogues à choix, surcouches et mini-jeux tiennent dans l'écran sans chevauchement à toutes les résolutions (800p compris) ; tous les boutons atteignables à la manette ; contrôle automatique étendu (`--dev-ui-check` : chevauchements, débordements, focus de chaque bouton).
3. Lancer : 9 épreuves tirées au hasard (2 par lancer, distinctes) + le lâcher final. Existantes améliorées (Élan ; Effet façon DDR : plus de notes, accords, musique dédiée, bruitages). Nouvelles, certaines en plein écran : Jetons sur les bouteilles, Mémoire des cartes, Bonneteau, Fléchettes, Coffre-fort, Tour de jetons, Shaker. Chacune jouable clavier/souris/manette, bot de test, sons.
4. Cinématique d'intro en pixel art (illustrations générées, parallaxe, pluie, néons, bruitages, musique), passable en maintenant une touche 3 s.
5. Histoire : dialogues densifiés, plus détaillés et plus drôles ; profondeur des personnages (passé, motivations, répliques propres à chaque personnage jouable) ; partie plus scénarisée (scènes entre les actes et aux moments clés).
6. Lisibilité à toutes les résolutions, notamment 1280×800.
7. Campagne de tests (interface, manette, équilibrage), corrections jusqu'au dernier problème, docs, exports, tag v1.5.0.

Bilan 1.5 : les 7 étapes sont livrées. `tools/check.sh` vert (85 tests, banc des 9 épreuves, interface 186 vues sur 6 définitions et 2 tailles de texte sans aucun problème, campagne gagnée à la manette seule). Équilibrage : glouton 39,8 %, expert 47,1 % neutre / 54,2 % adroit (`docs/BALANCE.md`). Exports Windows, Linux et Flatpak 1.5.0 régénérés.


## Version 1.5.1 — « Faites chauffer la machine »
Plan (chaque étape : code → tests → captures → corrections) :
1. Bugs signalés : cartes de la Mémoire blanches (texture libérée avant affichage) ✅ ; roue 3D coupée par la barre des grigris (marge de rendu portée à 280 px) ✅ ; manette au Bazar : un bouton désactivé (paquet vendu) renvoyait au début du menu, il est désormais enjambé ✅ (contrôle automatique étendu aux cartes et aux paquets vendus).
2. Jackpots fiables et plus fréquents : « JACKPOT ! » affiché = machine à sous lancée (plein gagnant, ou coup qui solde l'échéance d'un seul tir) ; nouveau Sceau Cloche (case qui offre un tirage gratuit) et objets qui le posent ; opérations `slot_pull` et `temp_xmult`.
3. Machine à sous plus belle et plus généreuse en variété : nouveaux gains (×Mult, grigri, sceau Cloche, amélioration de case), animations et effets renforcés ; fréquence et gains calés par simulation.
4. Visée plus lente (sélection de la case), mini-jeux plus exigeants pour toucher la case visée ; Bonneteau et autres épreuves durcies ; 5 nouvelles épreuves (14 au total).
5. Super builds façon Balatro : grigris à ×Mult croissant, relances, synergies ; nombres compacts (K, M, Md, T…) ; affichage du Mult animé selon sa grandeur.
6. Courbe de difficulté façon Balatro (dettes à croissance accélérée), équilibrage par simulations (cible 35–45 % bot compétent).
7. Contrôle complet de l'interface (manette, 6 définitions) ; dépôt GitHub public avec les releases ; docs, exports, tag v1.5.1.

Bilan 1.5.1 : les 7 étapes sont livrées. `tools/check.sh` vert (92 tests, banc des 14 épreuves, interface 204 vues sur 6 définitions et 2 tailles de texte sans problème, campagne gagnée à la manette seule). Équilibrage : glouton 39,0 %, expert 45,0 % (`docs/BALANCE.md`). Exports Windows, Linux et Flatpak 1.5.1 régénérés ; dépôt GitHub public avec les releases.

## Version 1.5.2 — « Lumières sur la table »
Plan (chaque étape : code → tests → captures → corrections) :
1. Corrections rapides : vitesse d'animation ×1 par défaut (sélecteur fiabilisé) ; pluie de la cinématique moins forte ; figures (V, D, R) avec leur symbole dans « Plus haut, plus bas » ; Bonneteau à la manette : curseur remis au gobelet du milieu à chaque choix ; épreuve de rythme plus abordable et sans accords sur des touches opposées ; Tri des jetons aux couleurs des boutons Xbox (A vert, B rouge, X bleu, Y jaune) et plus beau ; descriptions de l'onglet Jeu des options qui débordaient à l'horizontale.
2. Machine à sous : 4 rouleaux, lancer bien plus long avec arrêts lents un par un (tension, faux arrêts), machine en 3D avec son décor.
3. Cartes de présentation des épreuves : une illustration unique en pixel art par épreuve, avec titre et commandes du périphérique actif.
4. Graphismes des épreuves retravaillés, 3D quand c'est cohérent (gobelets, bouteilles, cartes, jetons, cible, coffre…).
5. Menu principal retravaillé (décor animé, mise en scène, navigation manette).
6. Campagne de tests complète : interface (6 définitions, 2 tailles de texte, manette), mécaniques, animations, menus et sous-menus ; difficulté des épreuves et équilibrage par simulations ; corrections jusqu'au dernier problème.
7. Docs, `tools/check.sh`, exports, tag v1.5.2, publication GitHub (release).

Bilan 1.5.2 : les 7 étapes sont livrées. Onze épreuves en 3D (`Stage3D.use_3d`, caméra frontale calée au pixel), trois redessinées, 14 illustrations pixel art (`tools/gen_trial_art.py`) sur les cartons d'annonce ; machine à sous 3D à 4 rouleaux (arrêts lents, suspense, carrés) ; écran titre en 3D (salle abandonnée) avec résumé de partie et astuces. Bugs trouvés en test et corrigés : Fléchettes (appui immédiat = centre garanti), machine à sous bloquée si l'on martelait la touche pendant le tirage (accélération limitée à une fois par tirage), astuce de l'écran titre qui chevauchait la mention légale en 1920×1200 avec texte agrandi, test d'un bonus temporaire trop strict. `tools/check.sh` vert (92 tests, banc des 14 épreuves, interface 204 vues, campagne gagnée à la manette seule en 24 tours). Équilibrage : glouton 43,3 % (cible 35–45 %).

Correctif 1.5.3 : rééquilibrage de la machine à sous (expert 56 % → 48 %, glouton ≈ 40 %), voir `docs/BALANCE.md`.

## Version 1.6.0 — « Les Familles »
Plan :
1. Épreuves plus abordables : rythme (une note à la fois, notes longues à maintenir), shaker B/A, bouteilles, tri, mémoire ; vérification du tirage des épreuves.
2. Builds lisibles : 10 familles de grigris à paliers (2/3/5), bandeau, infobulles, Codex, Bazar orienté build.
3. Économie : moins d'argent tôt, emplacement de grigri achetable.
4. Décors : tapis de jeu 3D, décors 3D du Bazar et des bilans, cadres art déco des surcouches.
5. Vérification complète (données, tests, banc des épreuves, interface 6 définitions, campagne manette), simulations, docs, exports, publication.

Bilan 1.6.0 : les 5 étapes sont livrées. Tirage des épreuves vérifié uniforme (3 000 lancers, 7,1 % chacune) ; un lancer évite désormais les épreuves des deux précédents. 196 grigris répartis en 10 familles, 96 tests. Argent à l'entrée du Bazar : 11–21 $ (au lieu de 14–66 $). Équilibrage : glouton 41,5 %, expert 49,0 % (voir `docs/BALANCE.md`). `tools/check.sh` vert (96 tests, banc des 14 épreuves, interface, campagne gagnée à la manette seule en 24 tours).

## Version 1.6.0-android — « La Maison dans la poche »
Plan (cf. `docs/ANDROID.md`) : phases 15 à 20.
- **Phase 15 — Socle** ✅ (`phase-15-android-socle`) : `Platform`, émulation `--dev-mobile`, surcharges `.mobile`, préréglage d'export Android, clé de publication hors dépôt, `tools/build_android.sh`, icône adaptative.
- **Phase 16 — Rendu** ✅ (`phase-16-android-rendu`) : moteur Mobile, `RenderQuality` à 3 niveaux, `FrameGovernor`, veille des scènes 3D couvertes, repli OpenGL ES.
- **Phase 17 — Tactile** ✅ (`phase-17-android-tactile`) : profil d'entrée « doigt », zone sûre, écran de jeu mobile, fiches de cartes, loupe de mise, infobulles à l'appui long, contrôle d'interface mobile dans `check.sh`.
- **Phase 18 — Gestes** ✅ (`phase-18-android-gestes`) : pavé tactile des épreuves, fléchettes et coffre au doigt, décalage audio du rythme, textes tactiles du tutoriel, vibrations.
- **Phase 19 — Système** ✅ (`phase-19-android-systeme`) : Retour, arrière-plan, écran allumé, reprise après arrêt forcé.
- **Phase 20 — Appareil et publication** ✅ (`phase-20-android-release`) : recette sur Pixel 7 (Android 17) par adb.

Recette Pixel 7 (adb, APK release) : installation par-dessus sans perte de sauvegarde ; Vulkan / Forward Mobile sur Mali-G710 ; titre, sélection, cinématique (passage au doigt maintenu), dialogue, astuces, mise glissée sur Rouge, visée, épreuves (Verre parfait, Tour de jetons, Bonneteau) au doigt ; Retour → pause → Retour ferme ; accueil en pleine épreuve → voile de reprise ; arrêt forcé → « Reprendre la partie ».
Corrigés grâce à l'appareil : le dialogue n'avançait pas au toucher (la boîte de texte arrêtait le clic), astuces de mise en file qui figeaient l'épreuve, voile de reprise créé pendant la propagation d'une notification, consigne de la cinématique coupée, « sur cet ordinateur » dans la question de télémétrie.
Mesures : mémoire PSS ≈ 1,28 Go dont ≈ 0,94 Go « Graphics » (pilote Mali ; 0,3 Go de mémoire vidéo mesurée par Godot en émulation, surtout tampons de rendu 3D et lueur) — au-dessus de l'objectif de 600 Mo, sans incidence sur un téléphone de 8 Go ; à surveiller sur les modèles 4 Go (qualité Économie). Images : 50e centile 5 ms. La chauffe sur 20 min n'a pas été mesurée (cœurs à 73–87 °C pendant les installations successives, téléphone branché).

## Version 1.7.0 — « Salle de jeux » (PC + Android)
Plan : phases 21 à 27 (remarques de test sur les deux versions).
- **Phase 21 — Correctifs** ✅ (`phase-21-correctifs`) : Oui / Non à la manette dans les confirmations ouvertes depuis un menu (focus des surcouches parentes suspendu), fiche de case au doigt pendant la visée, cadenas des objets en haut à gauche, `HitchMonitor` (`--dev-hitch`), contrôle `--dev-confirm-check` dans `check.sh`.
- **Phase 22 — Graphismes** ✅ (`phase-22-graphismes`) : `RenderQuality.configure`, préréglages Bas → Ultra / Steam Deck / Personnalisé, FSR 1.0 / 2.2, échelle et netteté, MSAA / FXAA / TAA, ombres, anisotrope, SSAO, particules, VSync à 4 modes [PC].
- **Phase 23 — Chargements** ✅ (`phase-23-chargements`) : carton de chargement, chargement en tâche de fond, chauffe des pipelines une fois par session.
- **Phase 24 — Épreuves au doigt** ✅ (`phase-24-android-epreuves`) : plein écran, joystick virtuel, pavé `split` (Shaker) [Android].
- **Phase 25 — La Pluie du Grand Lustre** ✅ (`phase-25-pluie`).
- **Phase 26 — Onze épreuves** ✅ (`phase-26a-arcade`, `phase-26b-table`, `phase-26c-adresse`) : Envahisseurs, Cave, Pachinko, Blackjack, Grattage, Dés, Tiercé, Pêche, Lasers, Jonglage, Billard ; Codex des épreuves.
- **Phase 27 — Publication** ✅ (`phase-27-release`).

Bilan 1.7.0 : `tools/check.sh` vert (122 tests, banc des 25 épreuves : bot ≥ 0,8, inactif ≤ 0,4, interface PC et mobile 204 vues, confirmations à la manette, campagne gagnée à la manette seule). Les bots des épreuves ne font plus qu'un geste de manette par image, rejoué tel quel par la campagne à la manette. Chauffe : 30 scènes, 124 pipelines en ≈ 3,4 s derrière le carton ; aucune image de plus de 50 ms une fois la partie ouverte (PC). Mémoire vidéo en émulation mobile : ≈ 241 Mo. Pixel 7 (adb) : installation par-dessus la 1.6.0 sans perte de sauvegarde, chauffe par lots de 6 scènes ≈ 5,2 s (au lieu de 11,6 s), fléchettes au joystick en plein écran, lancer complet sans erreur au logcat.

## Version 1.8.0 — « Le Musée » (PC + Android)
Plan : phases 28 à 32 (remarques de test sur les deux versions).
- **Phase 28 — Correctifs** ✅ (`phase-28-correctifs`) : dialogues d'acte une fois par profil, cases misées marquées (liseré, pastille, assombrissement en visée), Blackjack lisible, Pluie / Envahisseurs / Cave adoucies.
- **Phase 29 — Difficulté** ✅ (`phase-29-difficulte`) : bot humain au banc (D-072), « Prêt ? » de 0,6 s, dix épreuves ralenties ou élargies.
- **Phase 30 — Rework des épreuves** ✅ (`phase-30a` arcade, `phase-30b` table, `phase-30c` adresse, `phase-30d` Élan / Effet / Tri, `phase-30e` harmonisation) : les 14 épreuves à plat passent en 3D (D-073).
- **Phase 31 — Le Musée** ✅ (`phase-31a-musee-salles`, `phase-31b-musee-jeu`) : cinq salles, 25 maquettes, entraînement à trois difficultés, records et médailles, deux succès (D-074).
- **Phase 32 — Publication** ✅ (`phase-32-release`).

## Version 1.9.0 — « Répétition générale » (PC + Android)
Plan : phases 33 à 40 (remarques de test sur les deux versions).
- **Phase 33 — Correctifs** ✅ (`phase-33-correctifs`) : B dans les épreuves du Musée et pause, Mémoire qui ne scintille plus, jauge des Bouteilles, Shaker et Cave adoucis (D-076).
- **Phase 34 — Tutos** ✅ (`phase-34-tutos`) : démonstration, essai, épreuve ; bouton Tuto au Musée ; options (D-077).
- **Phase 35 — Épreuves** ✅ (`phase-35-epreuves`) : Billard (trajectoire, lance-pierre), Grattage refait, Tiercé à piste de rythme (D-078).
- **Phase 36 — Android direct** ✅ (`phase-36-android-direct`) : sept épreuves jouées sur les objets (D-079).
- **Phase 37 — Défaite** ✅ (`phase-37-defaite`) : cinématique à variantes par acte et créancier (D-080).
- **Phase 38 — Assets** ✅ (`phase-38-assets`) : HDRI de reflets, textures PBR CC0, trois cartons regénérés (D-081).
- **Phase 39 — Recette** ✅ (`phase-39-recette`) : `docs/QA_1.9.md`.
- **Phase 40 — Publication** ✅ (`phase-40-release`) : builds faits avec le Godot 4.7.2 officiel (`~/.local/opt/godot-4.7.2/bin` placé en tête du PATH, car le Godot de Fedora est en 4.7.1). Recette sur le Pixel 7 consignée dans `docs/QA_1.9.md`. APK de 42,6 Mo (39,5 Mo en 1.8.0).

Banc 1.9.0 (épreuves modifiées, bot parfait / bot humain) : Bouteilles 1,00 / 0,78–0,80 · Shaker 1,00 / 0,87–0,96 · Cave 0,99–1,00 / 0,75–0,93 · Billard 1,00 / 0,92 · Grattage 1,00 / 0,94 · Tiercé 1,00 / 0,95 · Pluie 0,98–0,99. Partie automatique PC et mobile sans erreur de script ; 133 tests.

## Version 2.0.0 — « La Grande Saison » (PC + Android)
Plan : phases 41 à 53 (50 épreuves, 28 builds de 7 grigris, difficulté resserrée, export des données).
- **Phase 41 — Correctifs** ✅ (`phase-41-correctifs`) : Pluie, Pachinko, Cave (personnage animé, accrochage amorti), tutos ralentis (D-082).
- **Phase 42 — Dix épreuves approfondies** ✅ (`phase-42a`, `phase-42b`) : D-083. Banc (bot / humain) : Verre 1,00 / 0,76–0,91 · Bonneteau 0,99 / 0,99 · Grattage 0,92 / 0,96 · Tiercé 0,94 / 0,62 · Effet 1,00 / 0,97 · Billard 1,00 / 0,71–0,92 · Lasers 0,94–1,00 · Tri 1,00 / 1,00 · Bouteilles 0,84–1,00 / 0,76–0,79 · Tour 1,00 / 0,62–0,76.
- **Phase 43 — Journal et export** ✅ (`phase-43-export`) : journal local toujours tenu, épreuves journalisées (chronologie des gestes et verdicts), Options → « Exporter mes données » (.zip : sauvegardes, JSONL, 5 CSV, README), rapport qui lit l'archive (D-084).
- **Phase 44 — Difficulté** ✅ (`phase-44-difficulte`) : 5 tours par échéance, dettes ×3–4 dès le palier 3, économie resserrée ; glouton 24 %, hasard 1,5 %, sans achat éliminé au palier 2,5, 3 tours par échéance (D-085).
- **Phase 45 — Builds** ✅ (`phase-45-builds`) : 28 familles de 7, paliers 2 / 4 / 7, 28 emblèmes, biais de boutique 1,0, dettes recalées (glouton 15 %, hasard 0,7 %) (D-086).
- **Phase 46 — Cabaret** ✅ (`phase-46-cabaret`) : salle 6 du Musée. Claquettes, Projecteur, Funambule, Lancer de chapeau, Mentaliste ; décor `CabaretSet`, six nouvelles poses de `Figure3D` (D-087).
- **Phase 47 — Cuisines** ✅ (`phase-47-cuisines`) : salle 7 du Musée. Crêpe Suzette, Découpage, Service, Commandes, Soufflé ; décor `KitchenSet` (D-088). Banc (bot / humain / inactif) : Crêpe 1,00 / 0,89 / 0 · Découpage 0,88 / 0,80 / 0,27 · Service 0,83 / 0,67 / 0 · Commandes 1,00 / 1,00 / 0 · Soufflé 0,86 / 0,86 / 0,05.
- **Phase 48 — Toits** ✅ (`phase-48-toits`) : salle 8 du Musée. Pigeon voyageur, Gouttières, Antenne, Tyrolienne, Télescope ; décor `RooftopSet` (D-089). Banc (bot / humain / inactif) : Pigeon 0,94 / 0,88 / 0,06 · Gouttières 1,00 / 1,00 / 0 · Antenne 1,00 / 1,00 / 0,03 · Tyrolienne 1,00 / 0,95 / 0,03 · Télescope 1,00 / 1,00 / 0. Pilote manette : plafond porté à 1 800 s, diagnostic de défaite.
- **Phase 49 — Fumoir** ✅ (`phase-49-fumoir`) : salle 9 du Musée. Ronds de fumée, Palet, Dominos, Bluff, Échecs éclair ; décor `SmokingSet`, moteur `ChessMini`, 42 positions générées (D-090). Banc (bot / humain / inactif) : Ronds 0,97 / 0,77 / 0 · Palet 1,00 / 0,82 / 0 · Dominos 1,00 / 1,00 / 0 · Bluff 0,95 / 0,92 / 0 · Échecs 1,00 / 1,00 / 0.

