# Plan de test et bilan QA

## Batterie automatique (`tools/check.sh`, doit finir vert)
| Étape | Outil | Ce qui est vérifié |
|---|---|---|
| Import | `godot --import` | ressources importées sans erreur |
| Données | `tools/validate_data.gd` | compilation de tous les scripts ; ids, champs, vocabulaire d'effets, références croisées, locuteurs |
| Traductions | `tools/i18n_check.py` | toute clé utilisée existe en FR et EN |
| Audio | `tools/audio_report.py` | saturation, silence, raccord des boucles (`docs/AUDIO.md`) |
| Lint | `gdlint` (`gdlintrc`) | style et ordre des déclarations |
| Tests | `tests/run_tests.gd` | 54 tests : règles, score, couverture de 100 % du contenu, sauvegarde, événements/succès/défis, curseur manette, non-régression |
| Fuzzing | `tools/fuzz.gd` | runs aléatoires, invariants à chaque action, aller-retour de sauvegarde tous les 7 pas |
| Simulation | `scripts/sim/sim_main.gd` | 40 runs de bout en bout sans erreur |
| Démarrage | `-- --quit-frames=120` | lancement et sortie propres (zéro erreur, zéro fuite) |

## Tests manuels assistés
- **Interface** : `-- --dev-autoplay=N --shot-dir=…` joue de vrais tours à l'écran et capture chaque étape (paris, visée, bille, score, surcouches). Le run complet a été joué jusqu'à la victoire.
- **Performance** : `-- --perf` (avec l'autoplay). Mesure de référence (RX 6700, 1080p+, jus 100 %) : 7,05 ms en moyenne (142 FPS, écran 144 Hz), 1 % le plus lent 10,1 ms, un seul pic de 150 ms au premier affichage (compilation de shaders), ≤ 757 draw calls, 94 Mo.
- **Résolutions** : captures en 1920×1200 (16:10), 1280×800, 1280×720 et 2560×1440 ; mise en page `canvas_items` + `expand` OK.
- **Manette / Steam Deck** : menus au focus ; tapis au curseur (croix/stick), A miser, X annuler, Y répéter, LB/RB paris intérieurs, Start lancer, B passer, Back vitesse. Remappage clavier dans les options. Testé par test unitaire du curseur ; **non testé sur un vrai Steam Deck**.

## Bugs trouvés en phase 13 (tous corrigés, avec test de non-régression)
| # | Gravité | Symptôme | Cause | Correction |
|---|---|---|---|---|
| 1 | Majeure | Au chargement d'une sauvegarde, des mises disparaissent (personnage Vic) | le bulletin était reposé sans le bonus de limite de table | reconfiguration complète du bulletin avant de reposer les mises |
| 2 | Majeure | Blocage : aucun pari possible (défi « Rouge à lèvres » contre Madame Rouge-et-Noire) | règles cumulées interdisant tout | garde-fou : l'interdiction de couleur puis la restriction de type sautent si plus rien n'est jouable |
| 3 | Mineure | Compteur de tours négatif, échéance à 0 tour jouable | malus cumulés (défi + Risque 2 / Notaire) | minimum d'1 tour en début d'échéance, compteur borné à 0 |
| 4 | Mineure | Sauvegarde non relue à l'identique (entiers devenus flottants dans les drapeaux) | JSON ne distingue pas entiers et flottants | drapeaux sérialisés en flottants |
| 5 | Cosmétique | Fuites de lectures audio à la fermeture | sons lancés pendant le délai de fermeture | l'AudioBus devient muet dès la coupure |

Bilan du fuzzing après corrections : 2 400 runs, ~35 000 actions, 0 violation.

## Limites connues
- Aucun test humain (ressenti, lisibilité, son à l'oreille).
- Steam Deck réel non testé ; Windows non testé (export seulement).
