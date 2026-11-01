# PROMPT MAÎTRE — LA MAISON GAGNE

Roguelite de roulette de casino · Godot 4 · développé de bout en bout avec Claude Code

## 0. Mode d'emploi

Dépose ce texte dans un dossier de projet vide (par exemple `PROMPT.md`), lance `claude` dedans, vérifie avec `/mcp` que les serveurs godot et blender sont connectés, puis envoie : « Lis PROMPT.md en entier et exécute-le phase par phase, en autonomie. » Après une coupure : « Reprends depuis docs/PROGRESS.md ».

## 1. Rôle et mission

Tu es un studio complet : game designer, programmeur Godot senior, economy designer, artiste technique, sound designer, narrative designer, QA et producer. Ta mission : livrer un projet Godot 4 complet, jouable de la première partie à la fin de la campagne, prêt à être ouvert et édité dans l'éditeur, avec code propre, données modifiables, tests, documentation et exports Linux/Windows. Tu as carte blanche créative et tu vises l'ambition maximale, mais toujours dans cet ordre : d'abord un noyau jouable et fun, ensuite le contenu, ensuite le polish.

## 2. Environnement et contraintes

- Machine : Fedora, i5-10400F, RX 6700, 32 Go de RAM. Cible : 60 FPS stables à 1920×1080, fenêtre redimensionnable, plein écran, 16:9 et 16:10.
- Godot 4.x stable (vérifie `godot --version`), GDScript à typage statique strict, `class_name` systématique. Pas de C#.
- Outils : serveurs MCP Godot et Blender (utilise-les pour inspecter et créer les scènes, lancer le jeu, lire les erreurs, piloter Blender). Si un MCP est indisponible, bascule sur la CLI (`godot --headless --path . --import`, `blender -b`). Python 3 + uv pour les scripts d'outillage (génération audio, icônes, simulation).
- Licences : tout est original, généré ou CC0 ; trace chaque source dans docs/CREDITS.md. Les inspirations (Balatro, Clover Pit, Raccoin) concernent les mécaniques et le ressenti uniquement : noms, personnages, visuels et sons sont originaux.
- Monnaie fictive uniquement, aucun achat intégré, aucune incitation au jeu d'argent réel. Une mention « jeu de hasard simulé » figure sur l'écran titre et dans les crédits.

## 3. Méthode de travail (non négociable)

1. Écris d'abord CLAUDE.md à la racine (stack, conventions, commandes, règles) et tiens-le à jour. Journal d'avancement dans docs/PROGRESS.md, décisions dans docs/DECISIONS.md.
2. Planifie avant de coder (plan mode pour chaque phase), puis exécute.
3. Un commit git par étape cohérente (messages conventionnels), un tag à la fin de chaque phase (par exemple `phase-03-core-loop`).
4. Après chaque modification : lance le projet (headless ou via MCP), lis les erreurs et avertissements, corrige jusqu'à zéro erreur, puis lance les tests.
5. Utilise des sous-agents spécialisés (gameplay, UI, audio, assets Blender, QA/simulation) pour préserver le contexte. Compacte quand nécessaire en t'appuyant sur PROGRESS.md.
6. Ne demande confirmation que si tu es réellement bloqué : sinon tranche, documente, avance. À la fin de chaque phase, rédige un rapport court (fait / testé / reste à faire / risques).
7. Tout le contenu de jeu est piloté par des données (Resources `.tres` ou JSON validés par un script), jamais codé en dur. Aucun nombre magique dans le code.
8. Le hasard est déterministe : une seule source RNG seedée (`RngService`), séparée en flux (roue, boutique, effets, cosmétique) pour permettre graines partagées, replays et tests reproductibles.

## 4. Vision et piliers

Pitch : tu hérites de la dette de ta famille envers La Maison, un casino souterrain dont la roulette ne s'arrête jamais. Chaque soir, tu dois rembourser, un tour de roue à la fois. On vise la montée en puissance et les synergies de Balatro, la pression de la dette et les objets étranges de Clover Pit, le côté tactile et la gourmandise sonore de Raccoin, autour d'une roulette européenne que tu modifies, optimises et finis par briser.

Piliers :

1. Tension : chaque tour est un petit suspense.
2. Jus : tout est animé, sonore, satisfaisant, surtout les gros scores.
3. Synergies brisées : le joueur construit un moteur absurde.
4. Lisibilité : malgré le chaos, le joueur comprend toujours pourquoi il a gagné ou perdu.
5. Runs de 35 à 50 minutes, relançables en 5 secondes.
6. Maîtrise : le hasard domine, mais l'habileté (paris, lancer, build) compte.

## 5. Boucle de jeu (spécification de départ, à affiner dans le GDD)

**5.1 Structure d'un run.** 8 Paliers regroupés en 3 Actes (paliers 1 à 3, 4 à 6, 7 à 8). Chaque palier = 2 Échéances (Petite, Grande) + 1 Créancier (boss avec règle spéciale). Chaque Échéance fixe une Dette à atteindre en score avant la fin de ses Tours (4 tours de base). Dettes de base par palier au départ, à ajuster par simulation : 300, 800, 2000, 5000, 11000, 20000, 35000, 50000, avec multiplicateurs ×1 / ×1,5 / ×2 pour Petite / Grande / Créancier. Mode Infini après la victoire.

**5.2 Un tour.** Phase Paris, Phase Lancer, résolution de la bille, calcul du score animé pas à pas, fin de tour (déclencheurs).

**5.3 Paris.** Tapis européen complet : plein (35:1), cheval, transversale, carré, sixain, douzaines, colonnes, rouge/noir, pair/impair, manque/passe. Le joueur dispose d'un budget de mises par tour (10 au départ) et d'une valeur de jeton améliorable. Interactions : glisser-déposer, clic, raccourcis, annuler, répéter le dernier pari, favoris.

**5.4 Lancer et précision.** Un lancer à jauge (puissance + moment de relâche) choisit une zone cible. La bille atterrit dans la zone selon la Précision (stat améliorable, zone de 1 à 7 cases, tirage RNG pondéré). Le résultat est tiré avant l'animation ; l'animation physique guidée (rebonds, quasi-ratés) raconte ce résultat. Les entrées du joueur sont loguées pour les replays.

**5.5 Pipeline de score (façon Balatro).** Score du tour = (Jetons gagnés + bonus de Jetons) × (1 + somme des Mult additifs) × produit des Mult multiplicatifs. Jetons gagnés = somme de (mise × cote) des paris gagnants. Chaque effet se déclenche dans l'ordre exact de la roue et des grigris, affiché et animé un par un. Le Zéro (vert) fait perdre les mises extérieures et déclenche la Taxe de La Maison, sauf effets contraires.

**5.6 La roue est ton deck.** 37 cases au départ. Les cases peuvent être achetées, remplacées, améliorées ou détruites. Types de cases (cible : au moins 20) : Standard, Dorée (+Jetons), Rubis (+Mult), Verre (gros Mult mais peut se briser), Aimant (attire la bille voisine), Miroir (copie la case opposée), Bombe, Fantôme (compte pour deux numéros), Joker (adopte la couleur du pari), Jumelle, Épine (pénalité mais gros multiplicateur), Collante, Prisme, Voleuse (vole des jetons à La Maison), Chronométrée, Maudite, Sacrée, Éclair, Zéro double, etc. Une case peut aussi porter un Sceau (effet secondaire) et une Édition (Brillante, Holographique, Polychrome, Noire).

**5.7 Grigris (équivalent des jokers).** 5 emplacements au départ, extensibles à 8. Raretés : Commun, Rare, Légendaire, Maudit. Catégories : déclencheurs sur paris, sur cases, sur séries (rouge N fois de suite), sur économie, sur boutique, sur bille, sur Zéro, évolutifs (grandissent au fil du run), contrats risqués. Ordre modifiable, vente possible, éditions.

**5.8 Cartes Fortune et Contrats.** Les cartes Fortune (consommables, 2 emplacements) modifient la roue, les paris ou le run. Les Contrats sont des améliorations passives permanentes pour le run (+tours, +précision, +mises, remises en boutique, etc.), organisés en chaînes à deux niveaux.

**5.9 Boutique.** Entre les échéances : 3 grigris, 2 paquets (cases / fortune / occulte), 1 contrat, reroll à coût croissant, vente. Intérêts sur l'argent économisé (plafonnés). Les probabilités de tirage sont affichées.

**5.10 Échec et Pacte.** Dette non atteinte = fin du run, sauf Pacte : La Maison propose un tour supplémentaire en échange d'un sacrifice (un grigri, une case, ou une partie du budget de mises). Un Pacte maximum par acte.

**5.11 Niveaux de Risque.** 8 niveaux cumulatifs (dettes plus lourdes, Zéro double, boutique plus chère, moins de tours, créanciers renforcés, grigris maudits injectés, etc.), débloqués par les victoires.

**Anti-frustration.** Tirages pondérés anti-séries, filet de sécurité en boutique, résumé de run expliquant les causes de la défaite, suggestions de build.

## 6. Cibles de contenu

Génère les tables complètes dans docs/content/, puis les données correspondantes.

- Cases spéciales : 24 · Éditions : 4 · Sceaux : 6
- Grigris : 150 (60 communs, 55 rares, 20 légendaires, 15 maudits)
- Cartes Fortune : 30 · Contrats : 20
- Créanciers : 12 (+2 secrets) · Événements entre actes : 20
- Personnages jouables : 6 · Niveaux de Risque : 8
- Succès : 60 · Défis : 20 · Graine quotidienne

Chaque entrée contient : id, nom FR/EN, description, rareté, coût, effet défini par composants d'effet, tags de synergie, icône, son associé, et une courte phrase d'ambiance drôle.

## 7. Scénario, campagne, personnages, antagonistes

**Lore.** Le Grand Zéro est un casino art déco enfoui sous une ville qui l'a oublié. La Maison, entité ou consortium dont la roue ne s'arrête jamais, prête de l'argent aux désespérés. Ton héros est le dernier héritier d'une famille qui a toujours perdu. Pour libérer les siens de la dette, il faut descendre étage par étage jusqu'à la Roue Originelle.

**Campagne en 3 actes.** Ton mélange de noir, d'humour pince-sans-rire et de tendresse, avec environ 10 minutes de scènes dialoguées au total.

- Acte I, « Le Rez-de-chaussée Doré » : vitrine glamour, tutoriel intégré.
- Acte II, « Les Salons Privés » : tricheurs, VIP, trahisons.
- Acte III, « La Cave du Zéro » : la vérité sur la dette et sur le Patron.

Dialogues courts façon visual novel, portraits animés, voix en « blips » synthétiques, choix qui débloquent grigris et événements. 3 fins (Rembourser, S'enfuir, Reprendre la Maison) et une vraie fin secrète.

**Personnages jouables (6)**, chacun avec passif et roue de départ uniques :

- Léa la Croupière : une relance de bille gratuite par échéance.
- Vic le Parieur : mises maximales doublées, Zéro plus dangereux.
- Dr Odile Khan, mathématicienne : probabilités exactes affichées, bonus sur paris combinés.
- Barnabé le Corbeau : vole des jetons, attiré par ce qui brille.
- Sœur Marthe : bénédictions, annule la première perte de chaque palier.
- Le Fantôme (à débloquer par succès) : cases fantômes, roue instable.

**Antagonistes (Créanciers).** 12 à concevoir, chacun avec règle de boss, dialogues, thème musical et animation d'entrée. Exemples : Le Croupier Muet (masque les cotes), Madame Rouge-et-Noire (interdit une couleur à chaque tour), Le Comptable (taxe chaque gain), Le Jumeau (copie ton meilleur grigri), La Chanteuse (son rythme décale la bille), Baron Carré (mises limitées aux carrés), L'Usurier (intérêts sur la dette à chaque tour), Le Pyromane (brûle des cases). Puis Le Patron, et enfin La Maison elle-même : une roue vivante en 3 phases pour la finale.

## 8. Direction artistique

- Style : casino art déco noir et or, néons magenta, cyan et émeraude, velours, fumée. Stylisation 2.5D cohérente : éléments clés (roue, bille, jetons, tapis, props) modélisés en low-poly dans Blender puis rendus en sprites et sprite sheets, ou intégrés en 3D via SubViewport. Icônes et cartes en pixel art 64×64 ou 96×96 à palette limitée, portraits 128×128 animés sur 4 à 6 frames.
- Palette fixée une fois pour toutes dans docs/ART\_BIBLE.md (valeurs hexadécimales), avec typographies libres de droits : une display art déco, une lisible pour l'UI, une monospace pour les chiffres.
- Shaders : CRT léger (courbure, scanlines, aberration chromatique, réglables), bloom, vignettage, dissolve, brillance des éditions, distorsion de chaleur, flou de mouvement sur la bille.
- Pipeline d'assets : scripts Python et Blender versionnés dans tools/ (génération d'icônes à partir de formes et de palettes, rendus turntable, atlas), manifeste assets/manifest.json, placeholders cohérents remplaçables sans toucher au code.
- Cohérence avant quantité : valide le guide de style sur 10 icônes avant de produire les 150.

## 9. Animations et jus (catalogue minimal à implémenter)

- Score : comptage ascendant avec pitch croissant, nombres flottants, jauge de Mult qui gonfle et vibre, paliers de célébration (Bien, Énorme, Jackpot, Casse-la-banque).
- Bille : traînée lumineuse, rebonds, ralenti dramatique sur les quasi-ratés, roue qui ralentit par saccades, zoom caméra.
- Impacts : hitstop, screen shake réglable, flashs, particules (pièces, étincelles, confettis, fumée), cartes et jetons qui rebondissent, inclinaison 3D légère des cartes sous la souris.
- Paris : jetons qui claquent et s'empilent, lueur sur les cases gagnantes.
- Boutique : cartes qui se retournent, achat avec rebond, vente avec gerbe de pièces.
- Transitions : rideaux de casino, fondu CRT, titre d'acte animé.
- Boss : entrée théâtrale, jauge de dette qui bat, changements visuels à chaque phase.
- Ambiance : néons qui clignotent, poussière, ombres mouvantes.

Tout est paramétré par un `JuiceProfile` réglable de 0 à 100 %, avec un mode réduit pour l'accessibilité.

## 10. Audio

- SFX synthétisés par scripts Python (numpy, wave) ou dans Godot : jetons, bille sur bois et métal, roue, clics, coffre, cloche de jackpot, achat, vente, erreur, menus, blips de dialogue par personnage, ambiance de salle. Chaque son a 3 à 5 variantes et un pitch randomisé. Mixage par bus (Master, Musique, SFX, UI, Ambiance) avec compresseur et léger sidechain.
- Musique : 5 boucles originales (menu, Acte I jazz lounge, Acte II tension chic, Acte III sombre, boss) générées par script (séquenceur, gammes, patterns), avec couches dynamiques qui s'ajoutent quand le Mult monte. Stingers de victoire, défaite et jackpot.
- Options audio complètes et sous-titres des sons importants.

## 11. UI/UX, QoL, accessibilité, localisation

- Écrans : titre, choix du personnage, choix du Risque, run (tapis, roue, grigris, dette, historique), boutique, carte de campagne, Hall (méta), Codex (collection), succès, statistiques, options, crédits, résumé de run.
- QoL : accélération des animations ×2 et ×4 avec saut, auto-répétition des paris, annulation, favoris de paris, infobulles riches avec glossaire cliquable, calculateur de probabilités et d'espérance de gain, historique des 50 derniers tours, verrouillage et réordonnancement des grigris, tri et filtres, confirmation avant actions irréversibles, sauvegarde automatique avec reprise exacte du run, partage de graine, mode replay, raccourcis clavier, manette complète (Steam Deck).
- Accessibilité : modes daltonien, taille de texte, réduction des flashs et des secousses, contraste élevé, remappage des touches, assistance de difficulté optionnelle.
- Localisation FR et EN (fichiers PO ou CSV de Godot), FR par défaut.
- Sauvegardes versionnées avec migrations, dans `user://`, résistantes à la corruption (écriture atomique + sauvegarde de secours).

## 12. Architecture technique

- Arborescence : res://scenes, scripts, data, assets, shaders, ui, audio, tools, tests, docs.
- Autoloads : EventBus (signaux typés), GameState (machine à états du run), RngService, SaveSystem, AudioBus, Settings, Localization, DataRegistry.
- Système d'effets : composants `Effect` pilotés par les données, déclencheurs ordonnés (`on_run_start`, `on_bet_placed`, `on_spin_start`, `on_ball_land`, `on_score_calc`, `on_round_end`, `on_shop_enter`, etc.), file d'événements de score animable et testable sans interface.
- Séparation stricte entre logique et présentation : le moteur de score est pur et testable en headless.
- Tests : GdUnit4 (ou GUT) pour la logique, tests d'intégration par scènes, non-régression par graines. Script `tools/check.sh` qui enchaîne import, lint (gdtoolkit), tests et simulation rapide.
- Performances : profilage, pooling des particules, budget de draw calls.

## 13. Simulation et équilibrage

Construis un simulateur headless (`godot --headless`) qui joue des milliers de runs avec plusieurs bots (aléatoire, glouton, optimiseur de synergies). Il exporte des CSV (taux de victoire par palier et par personnage, grigris les plus et les moins choisis, durée, distribution des scores) et génère docs/BALANCE.md.

Objectifs : victoire à Risque 0 autour de 35 à 45 % pour un bot compétent, courbe de dette sans mur injuste, aucun grigri dominant (plus de 2× le taux de choix moyen) ni inutile, runs de 35 à 50 minutes. Boucle : simuler, ajuster les données, resimuler.

## 14. Phases de développement

Chaque phase a des objectifs, des livrables, des critères de sortie, des tests, un commit et un tag.

- **Phase 0, Reconnaissance** : vérifie Godot, les MCP, git, Python et Blender ; crée le dépôt, CLAUDE.md et la structure. Sortie : le projet s'ouvre sans erreur.
- **Phase 1, Conception** : GDD complet (docs/GDD.md), formules, tables de contenu initiales, ART\_BIBLE, plan de production.
- **Phase 2, Prototype gris** : roue, bille, tapis, paris, score minimal en formes grises. Sortie : un tour entier jouable.
- **Phase 3, Boucle centrale** : Échéances, dette, tours, Zéro, pipeline de score complet, fin de run. Sortie : un run complet jouable à la souris.
- **Phase 4, Systèmes de contenu** : cases spéciales, grigris, Fortune, Contrats, boutique, éditions, Pacte, sauvegarde. Sortie : 40 grigris et 10 cases fonctionnels, avec tests.
- **Phase 5, Vertical slice** : Acte I complet avec un boss, art et audio provisoires mais cohérents. Fais une revue critique et honnête du fun avant d'aller plus loin.
- **Phase 6, Contenu complet** : toutes les cibles de la section 6, 12 créanciers, 6 personnages, 8 niveaux de Risque.
- **Phase 7, Méta et campagne** : Hall, Codex, succès, déblocages, défis, graine quotidienne, mode Infini, scénario, dialogues, 3 fins.
- **Phase 8, Tutoriel** : tutoriel interactif d'environ 10 minutes dans l'Acte I (paris, lancer, score, grigris, boutique), ignorable, bulles contextuelles rejouables, premiers runs guidés.
- **Phase 9, Direction artistique finale** : assets Blender, icônes, portraits, shaders, UI habillée.
- **Phase 10, Audio** : SFX, musique adaptative, mixage.
- **Phase 11, Jus et polish** : catalogue complet de la section 9, transitions, profils d'intensité.
- **Phase 12, Équilibrage** : simulations, ajustements, rapports.
- **Phase 13, QA** : plan de test complet, fuzzing de graines, tests de sauvegarde, de manette et de performances, bugs triés et corrigés, zéro erreur ni warning au lancement.
- **Phase 14, Livraison** : exports Linux et Windows (presets), README, CREDITS, notes de version, post-mortem, feuille de route post-lancement (DLC, coop, mods).

## 15. Livrables finaux et critères de qualité

Un projet Godot ouvrable directement (`project.godot` à la racine) contenant : le jeu complet jouable de l'écran titre à la fin de la campagne, des données éditables dans l'éditeur, des tests au vert, une documentation complète, des outils documentés dans tools/, des presets d'export et un dépôt git propre avec les tags de phase.

Qualité attendue : zéro crash, zéro erreur console, 60 FPS, un retour visuel et sonore pour chaque action, chaque règle expliquée en jeu.

## 16. Première action

Démarre maintenant la Phase 0, puis enchaîne jusqu'à la Phase 5 sans t'arrêter. À la fin de la Phase 5, présente le rapport de vertical slice, puis poursuis les phases suivantes en autonomie, avec les mêmes règles.
