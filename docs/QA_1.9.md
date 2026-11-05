# Recette 1.9.0 « Répétition générale »

Chaque ligne donne le constat, sa cause, le correctif et la vérification.

## Passes automatiques
- `tools/check.sh` : validation des données, lint, 133 tests, banc des 25 épreuves (bot, humain, inactif, durée), 210 vues d'interface sur PC et 210 sur mobile, confirmations, campagne gagnée à la manette. Vert à chaque phase (33 à 39).
- Partie automatique PC avec tutos (`--dev-run=lea --dev-autoplay=60 --dev-tutos=1`) : 585 captures, défaite au palier 2, cinématique de défaite puis bilan, aucune erreur de script.
- Partie automatique mobile (`--dev-mobile`) : 818 captures, 17 tours jusqu'au palier 3, aucune erreur de script.

## Constats et correctifs
| # | Constat | Cause | Correctif | Vérification |
|---|---|---|---|---|
| 1 | Au Musée, B quittait l'épreuve | `ui_cancel` arrivait à `PadNavigator` et appelait `go_back()` | Pendant le jeu, tous les événements vont à l'épreuve ; on quitte par Pause (Reprendre, Recommencer, Quitter) | `test_museum_b_reaches_trial` |
| 2 | La maquette de la Mémoire scintillait | Couches des cartes espacées de 1 mm et cartes qui se chevauchaient (z-fighting) | `PlayingCard3D.LAYER` passe à 3 mm, cartes espacées et étiquettes en `ALPHA_CUT_DISCARD` | Captures en rotation, PC et mobile |
| 3 | La zone de force des Bouteilles débordait de sa jauge et était trop facile à viser | Dessin non borné ; `power_zone` de 0,28 | Dessin borné à la jauge, zone 0,07 et dégressivité jusqu'à 0,26 ; balayage plus lent et goulot plus tolérant | Banc : humain 0,78–0,80 |
| 4 | Shaker et Cave trop durs | Bande étroite (Shaker) ; fosses larges et étourdissement long (Cave) | Réglages dans `balance.json` | Banc : humain 0,87–0,96 au Shaker et 0,75–0,93 à la Cave |
| 5 | Billard brut, prévisualisation trop courte | — | Trajectoire complète avec rebond, bille fantôme, poche conseillée, lance-pierre, chute animée | `test_billiards_slingshot`, banc à 0,92 |
| 6 | Grattage incompréhensible | — | Refait de zéro : trois zones cerclées, débordement pénalisé | `test_scratch_overflow_costs`, banc à 0,94 |
| 7 | Rythme du Tiercé illisible | — | Piste de rythme G/D, tic sur chaque temps, verdicts, temps plus long | Banc : humain 0,95 |
| 8 | Aucune initiation aux épreuves | — | Démonstration, essai qui ne compte pas, puis l'épreuve ; bouton Tuto au Musée ; option pour revoir les tutos | `test_trial_tuto_flow` |
| 9 | Sur la table (PC), le carton de démonstration cachait le haut de l'épreuve (Tri, Shaker) | Le carton était dessiné dans le cadre de l'épreuve | Carton placé au-dessus du cadre sur PC, compact en haut du cadre sur téléphone | Captures « Tri » au Musée avec `--dev-tutos=1` |
| 10 | Juke-box, Pluie et autres jouaient sur des boutons émulés sur Android | Pavé tactile déclaré dans les données | `touch_direct` : on touche les objets eux-mêmes (7 épreuves) | `test_direct_touch_plays`, `test_catch_direct_bank` |
| 11 | Billard sur mobile : tir accidentel en visant | Le bouton de tir servait aussi à doser | Lance-pierre : on ne tire qu'au-delà d'un seuil, revenir sur la bille annule | `test_billiards_slingshot` |
| 12 | Défaite sans mise en scène | — | Cinématique « registre soldé, aube, porte », avec des variantes par acte et par créancier | `test_defeat_cutscene_variants`, partie automatique |
| 14 | Banc : Cave et Pêche sous le seuil humain sur un passage (0,39 et 0,54) | Forte variance selon le tirage (fosse à câble large, fenêtre de ferrage courte) | Cave : `rope_pit_width` 440, `grab_scale` 2,5, `fall_stun` 0,3 ; Pêche : `cast_tolerance` 0,18, `react_window` 0,7 | 5 passages Cave à 0,73–0,93 ; 4 passages Pêche à 0,76–0,87 |
| 15 | Pendant une épreuve, une mauvaise note du Juke-box affichait « LANCER RATÉ » (vu sur le Pixel 7) | Les verdicts de geste reprenaient l'étiquette de qualité du lancer | Étiquettes courtes `POP_Q_*` (Parfait !, Très bien, Bien, Raté) ; le verdict de fin d'épreuve est inchangé | Pixel 7 |
| 16 | Musée sur téléphone : « La Pluie du Grand Lustr » coupé dans la rangée | Texte rogné sans points de suspension | `OVERRUN_TRIM_ELLIPSIS` | Capture `--dev-mobile` |
| 17 | Banc : le bot parfait de la Pluie passe parfois sous 0,8 (0,78–0,79) | La note exigeait 100 % des pièces dorées, et le tirage dépend de l'ordre des épreuves | `catch.full_share` 0,9 : 90 % des pièces suffisent pour la note pleine | 3 passages : bot 0,95–1,00, humain 0,89–0,94, inactif ≤ 0,29 |
| 13 | L'import de l'HDRI émettait deux avertissements | En-tête `GAMMA` / `PRIMARIES` ignoré par Godot | Lignes d'en-tête retirées (image inchangée) | Import sans avertissement |

## Écrans relus (captures)
Chargement, partie (tapis, roue, surcouches, machine à sous), les 25 épreuves au carton, en démonstration, en jeu et au verdict, le Musée (5 salles), la cinématique de défaite et le bilan. Tout a été relu sur PC (1920×1080) et en émulation mobile.

## Pixel 7 (adb, APK release 1.9.0)
- Installé par-dessus la 1.8.0 : la partie en cours est conservée ; Vulkan / Forward Mobile sur Mali-G710.
- Musée : sol en marbre, maquettes ; Juke-box avec démonstration, essai, puis épreuve, joué en touchant directement les boutons, sans pavé.
- Billard au lance-pierre : un petit glissement depuis la blanche ne tire pas, une traction tire, et un toucher hors de la bille ne fait rien.
- Mémoire : PSS de 1,06 Go, dont 0,68 Go « Graphics » (1,28 Go en 1.6.0). Aucune erreur au logcat.
- Non refait sur l'appareil : la cinématique de défaite, vérifiée sur PC et en émulation mobile.
