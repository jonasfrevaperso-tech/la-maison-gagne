# Recette 2.0.0 « La Grande Saison »

Chaque ligne donne le constat, sa cause, le correctif et la vérification.

## Passes automatiques
- **`tools/check.sh`**, vert à chaque phase (41 à 52) :
  - validation des données et lint ;
  - 173 tests ;
  - banc des **50 épreuves** (bot, humain, inactif, durée) ;
  - 210 vues d'interface sur PC et 210 sur mobile ;
  - confirmations et campagne gagnée à la manette.
- **Partie automatique en émulation mobile** (`--dev-mobile --dev-run=lea --dev-autoplay=12`) : 552 captures, aucune erreur de script. Relues : les épreuves de 20 salles différentes (Shaker, Dominos, Bonneteau, Coffre, Tyrolienne, Tour, Clé, Ronds de fumée, Antenne, Bouteilles, Échecs, Service…), la mise et le score.
- **Captures PC au Musée** : les 25 nouvelles épreuves (en jeu, en démonstration et au verdict), les 10 salles et les épreuves aux décors refaits.

## Économie (simulateur, épreuves réussies à 0,8)
| Bot | Parties | Victoire | Palier moyen | Cible du plan |
|---|---|---|---|---|
| Hasard | 400 | 0,8 % | 3,2 | ≤ 3 % ✅ |
| Sans achat | 400 | 0 % | 2,4 | perdre en acte 2 ✅ |
| Glouton | 400 | 14,8 % | 4,9 | voir ci-dessous |
| Expert (synergy) | 80 | 16,2 % | 5,7 | voir ci-dessous |

- **Échéances :** à partir du palier 3, une échéance réglée prend 3 tours en médiane.
- **Glouton et expert :** ils restent sous les 20 à 25 % visés en phase 44. Le joueur réel battait nettement les bots en 1.9, mais il manque encore des parties réelles en 2.0 pour recaler. Le recalage se fera avec une archive « Exporter mes données » (`tools/telemetry_report.py --human`).

## Constats et correctifs
| # | Constat | Cause | Correctif | Vérification |
|---|---|---|---|---|
| 1 | Lancer de chapeau : le bot humain passait parfois sous 0,55 au banc | Crochet du portemanteau étroit (36 px), forte variance selon le vent | `hattoss.hook_radius` 40 | 3 bancs : humain 0,75 à 0,93 |
| 2 | Fuite : notes très dispersées (bot de 0,15 à 1,00), inactif jusqu'à 0,69 | Barrages mobiles tirés au hasard (deux camions de front, voitures lentes côte à côte), files laissées vides | Vitesse par file, camions à droite, passage garanti qui zigzague, rangées régulières, bot à distances de freinage réelles (D-091) | 60 graines : bot 0,96, inactif 0,14 ; 6 bancs : bot ≥ 0,82, humain ≥ 0,67, inactif ≤ 0,26 |
| 3 | Sur le Pixel 7, le texte de l'étape du tuto débordait du carton | Ligne dessinée sans largeur maximale, avec le grand texte du téléphone | `ThrowTrial.text_fit` : taille réduite jusqu'au petit texte, puis deux lignes ; carton un peu plus haut | `test_tuto_line_splits_in_two`, capture `--dev-mobile --dev-tutos=1` |
| 4 | Musée : socles en « marbre » à damier, cadres vides | La texture de marbre était celle du sol (damier) | Marbre veiné CC0 « Marble 012 », cartons illustrés dans les cadres (D-092) | Captures PC et Pixel 7 |

## Pixel 7 (adb, APK release 2.0.0)
- **Installation** par-dessus la 1.9.0, même clé de signature : la partie en cours (Léa, palier 1) et les 8 médailles d'or du Musée sont conservées. Vulkan / Forward Mobile sur Mali-G710.
- **Mémoire :** PSS de 652 Mo à l'écran titre, dont 392 Mo « Graphics ». Aucune erreur au logcat.
- **Musée :** salles du Bar et du Garage, socles de marbre et cartons encadrés. La Fuite est lancée au toucher, avec démonstration, et le constat 3 a été relevé à ce moment.
- **Non fait sur l'appareil :**
  - jouer au doigt chaque nouvelle salle (geste humain requis) ;
  - l'export de l'archive par le sélecteur de fichiers Android (il demande des touchers dans le sélecteur du système). Couvert par les tests d'archive sur PC ; à essayer sur le téléphone.
