# Plan de test et bilan QA

## Batterie automatique (`tools/check.sh`, doit finir vert)
| Étape | Outil | Ce qui est vérifié |
|---|---|---|
| Import | `godot --import` | ressources importées sans erreur |
| Données | `tools/validate_data.gd` | compilation de tous les scripts ; ids, champs, vocabulaire d'effets, références croisées, locuteurs |
| Traductions | `tools/i18n_check.py` | toute clé utilisée existe en FR et EN |
| Audio | `tools/audio_report.py` | saturation, silence, raccord des boucles (`docs/AUDIO.md`) |
| Mixage | `tools/audio_mix.py --check` | chaque son à ±1,5 dB de la loudness cible de sa famille |
| Lint | `gdlint` (`gdlintrc`) | style et ordre des déclarations |
| Tests | `tests/run_tests.gd` | 60 tests : règles, score, couverture de 100 % du contenu, sauvegarde, événements/succès/défis, curseur manette, non-régression, multi-résolution, aide aux commandes, télémétrie, historique |
| Fuzzing | `tools/fuzz.gd` | runs aléatoires, invariants à chaque action, aller-retour de sauvegarde tous les 7 pas |
| Simulation | `scripts/sim/sim_main.gd` | 40 runs de bout en bout sans erreur |
| Interface | `-- --dev-ui-check` | 10 écrans + 8 surcouches × 3 tailles logiques (16:9, 16:10, texte agrandi) : un contrôle a le focus manette, aucun bouton hors de l'écran |
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

## Version 1.1
### Retours après la 1.0 (corrigés)
| Symptôme | Cause | Correction |
|---|---|---|
| Le texte d'aide sous le tapis déborde | phrase unique trop longue (clavier + manette), retour à la ligne sur les grigris | ligne unique générée depuis les vraies touches du périphérique courant, tronquée proprement (`InputHints`) |
| Une partie est « déjà en cours » au premier lancement | les captures et pilotes automatiques écrivaient dans la sauvegarde du joueur | sessions de dev isolées dans `user://dev/` ; confirmation avant d'écraser un run ; ancienne sauvegarde mise de côté dans `avant-1.1/` |
| Résolutions autres que 1080p | mise en page absolue en 1920×1080 | cadre d'écrans + scène de référence (D-016), options de résolution |

### Trouvés par le contrôle d'interface (corrigés)
- Pactes et événements : boutons hors de l'écran (mise à l'échelle des surcouches calculée avant la mise en page) → ajustement après mise en page.
- Titre et sélection de personnage débordent avec le texte agrandi → cadre d'écrans réduit uniformément, menu titre sur deux colonnes.

### Performance (RX 6700, `--perf`, mesure GPU)
| Résolution | GPU médian | GPU 99e centile | CPU de rendu |
|---|---|---|---|
| 1920×1080, effets complets | 2,72 ms | 3,31 ms | 0,34 ms |
| 1280×800, effets complets | 1,94 ms | 2,11 ms | 0,33 ms |
| 1280×800, sans bloom | 1,26 ms | 1,44 ms | 0,32 ms |
| 1280×800, sans CRT ni bloom | 0,78 ms | 0,96 ms | 0,31 ms |

Estimation Steam Deck (GPU ≈ 8× moins puissant) : ≈ 15 ms par image avec tous les effets, ≈ 10 ms en préréglage économie (appliqué d'office au premier lancement sur Deck) → 60 i/s tenables. **Estimation, pas une mesure.**

### Journal du moteur
Des lignes « Attempt to disconnect a nonexistent connection from 'root' (focus_entered / tree_exited) » sont apparues dans un journal de session réelle (Wayland). Elles ne viennent d'aucun code du jeu (aucune connexion manuelle à ces signaux) et n'ont pas pu être reproduites par simulation (infobulles, clics, changements d'écran, `--dev-hover`) : erreur interne du moteur liée aux fenêtres popup, sans effet visible. À surveiller.

## Limites connues
- Aucun test humain (ressenti, lisibilité, son à l'oreille).
- Steam Deck réel non testé ; Windows non testé (export seulement, pas de Wine disponible).
