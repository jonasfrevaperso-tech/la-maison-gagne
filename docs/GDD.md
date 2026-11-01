# La Maison Gagne — Game Design Document

Version 1.0 · 2026-11-01 · Godot 4.7 · PC (Linux, Windows, Steam Deck)

> Jeu de hasard **simulé**. Monnaie fictive. Aucun achat, aucun lien avec de l'argent réel.

## 1. Pitch
Tu hérites de la dette de ta famille envers **La Maison**, un casino souterrain art déco, le **Grand Zéro**, dont la roulette ne s'arrête jamais. Chaque soir, tu rembourses — un tour de roue à la fois. Tu modifies la roue, tu empiles des grigris absurdes, et tu finis par la briser.

## 2. Piliers → règles de conception
| Pilier | Traduction concrète |
|---|---|
| Tension | Résultat tiré avant l'animation ; l'animation ménage le suspense (ralenti sur les quasi-ratés). Jauge de dette qui bat au dernier tour. |
| Jus | Chaque `ScoreEvent` est joué un par un avec son, nombre flottant, secousse proportionnelle. Paliers de célébration. |
| Synergies brisées | Langage d'effets composable (déclencheurs × conditions × actions) ; grigris évolutifs, copieurs, re-déclencheurs, roue modifiable. |
| Lisibilité | Formule unique affichée en permanence : `Jetons × Mult`. Chaque contribution est attribuée à sa source (icône qui saute). Résumé de défaite. |
| Runs 35–50 min | 24 échéances × 4 tours ≈ 96 tours ; ~20 s/tour + boutiques. Relance en 5 s depuis l'écran de fin. |
| Maîtrise | Visée au lancer (timing), choix des paris (voisinage vs extérieurs), construction du moteur, gestion de l'argent (intérêts). |

## 3. Structure d'un run
- **8 Paliers** en **3 Actes** : I (1–3) « Le Rez-de-chaussée Doré », II (4–6) « Les Salons Privés », III (7–8) « La Cave du Zéro ».
- Chaque palier : **Petite Échéance**, **Grande Échéance**, **Créancier** (boss à règle spéciale).
- Échéance : atteindre la **Dette** (score cumulé) avant la fin des **Tours** (4 de base).
- Dette = `tier_debts[palier] × mult[Petite 1 | Grande 1,5 | Créancier 2] × mult_risque × mult_créancier`.
  Base : 300, 800, 2000, 5000, 11000, 20000, 35000, 50000 (ajustée par simulation, voir BALANCE.md).
- Palier 7 : **Le Patron**. Palier 8 : **La Maison** (roue vivante, 3 phases).
- Victoire → fin de campagne selon les choix, puis **Mode Infini** (dette × 1,6 par palier).
- Entre deux actes : un **Événement** (choix narratif à conséquences).

## 4. Un tour
1. **Phase Paris** — le joueur pose jusqu'à `budget` jetons (10) sur le tapis.
2. **Phase Lancer** — une aiguille balaie la roue ; le relâchement choisit la case cible.
3. **Résolution** — `ThrowResolver` tire le résultat (flux RNG `wheel`), l'animation le raconte.
4. **Score** — `ScoreEngine` produit la liste ordonnée des `ScoreEvent`, jouée pas à pas.
5. **Fin de tour** — déclencheurs `on_round_end`, mise à jour séries/historique, sauvegarde.

## 5. Paris
Tapis européen complet, cotes réelles :

| Pari | Cases | Cote | Limite de table (jetons) |
|---|---|---|---|
| Plein | 1 | 35:1 | 2 |
| Cheval | 2 | 17:1 | 3 |
| Transversale | 3 | 11:1 | 4 |
| Carré (dont 0-1-2-3) | 4 | 8:1 | 4 |
| Sixain | 6 | 5:1 | 6 |
| Douzaine / Colonne | 12 | 2:1 | budget |
| Rouge/Noir, Pair/Impair, Manque/Passe | 18 | 1:1 | budget |

- **Gain d'un pari** = `mise × valeur_jeton × (cote + 1)` (mise rendue, D-005). Valeur de jeton : 5 (améliorable).
- **Zéro** : tous les paris extérieurs perdent, **Taxe de La Maison** = 2 $ (sauf protection).
- Interactions : clic gauche = +1 jeton, clic droit = −1, molette = ±1, Ctrl+Z annuler, R répéter le dernier pari, C effacer, favoris (3 emplacements), manette : curseur sur le tapis.

## 6. Lancer et Précision
- L'aiguille fait le tour de la roue en `pointer_period_seconds` (2,4 s). Relâcher = case cible.
- `control` (probabilité de rester dans la zone) et `largeur de zone` dépendent de la Précision (1 à 7) :

| Précision | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| Contrôle | 35 % | 45 % | 55 % | 62 % | 70 % | 78 % | 85 % |
| Zone | 7 | 7 | 5 | 5 | 5 | 3 | 3 |

- Dans la zone : tirage triangulaire (poids `k+1−|o|`). Hors contrôle : **rebond fou** uniforme (anti-série : la dernière case pèse ×0,5).
- Cases spéciales : **Aimant** (attire depuis un voisin), **Collante** (la bille y revient).
- **Dr Odile Khan** affiche la distribution exacte (`ThrowResolver.distribution`).
- Les entrées (cible, instant) sont journalisées pour les replays.

## 7. Pipeline de score
```
Score = floor( Jetons × (1 + Σ Mult_add) × Π Mult_mul )
```
Ordre (identique en jeu et en simulation) :
1. `on_ball_land` (sources globales).
2. Zéro → `on_zero`, taxe.
3. Paris dans l'ordre de pose : gain → `on_bet_win` (par pari) / `on_bet_lose`. Re-déclenchements de paris.
4. Case touchée : numéro en Jetons (+10/niveau) → type → édition → sceau. Re-déclenchements (≤ 8 passes). Miroir : rejoue la case opposée.
5. `on_score_calc` : personnage, contrats, créancier, risques, **puis grigris de gauche à droite** (+ édition du grigri).
6. Total → `on_round_end`.

Toutes les étapes émettent un `ScoreEvent {kind, source, amount, chips_after, mult_after}`.

## 8. La roue est ton deck
- 37 cases au départ, taille 8 à ∞. Ajouter un doublon (« un deuxième 17 ») augmente sa probabilité.
- **24 types de cases** (voir docs/content/pockets.md), **4 Éditions** (Brillante +Jetons, Holographique +Mult, Polychrome ×Mult, Noire +1 emplacement sur un grigri / ×Jetons sur une case), **6 Sceaux**.
- Paquet de cases (boutique) : 3 cartes `{type, numéro, édition?, sceau?}` ; choisir **Ajouter** (nouvelle case à côté de son numéro) ou **Remplacer** (transforme la case existante).

## 9. Langage d'effets
Toutes les sources (grigris, cases, éditions, sceaux, contrats, personnages, créanciers, risques, Fortune, événements) partagent le même format :
```json
{"trigger": "on_bet_win", "if": [{"c": "bet_kind", "v": "straight"}], "do": [{"op": "add_mult", "v": 3}]}
```
- **Déclencheurs** : on_run_start, on_deadline_start, on_bet_phase, on_bet_placed, on_spin_start, on_ball_land, on_zero, on_bet_win, on_bet_lose, on_pocket_score, on_edition, on_seal, on_score_calc, on_round_end, on_deadline_end, on_shop_enter, on_reroll, on_buy, on_sell, on_fortune_used, on_acquire, on_remove, on_use.
- **Conditions** : prédicats (couleur, parité, type de case, type de pari, hasard, quasi-raté…) ou comparaison de **variables** (`{"c": "money", "op": ">=", "v": 20}`).
- **Valeurs** : nombre ou expression `{"var": "counter", "mul": 2, "add": 1, "div": 5, "min": 0, "max": 50}`.
- **Actions** : add_chips, add_mult, mul_mult, add_money, compteurs (évolutifs), tours, budget, précision, re-déclenchements, transformations de roue, création de cartes/grigris, dette, protection du Zéro, copie du voisin, etc.
- Liste exhaustive : `EffectRunner.TRIGGERS / PREDICATES / VARIABLES / OPS` ; tout est vérifié par `tools/validate_data.gd`.

## 10. Grigris
- 5 emplacements (max 8). Raretés : Commun (4 $), Rare (6 $), Légendaire (10 $), Maudit (3 $, puissant mais coûteux).
- Catégories : paris, cases, séries, économie, boutique, bille, Zéro, évolutifs, contrats risqués, copieurs.
- Ordre modifiable par glisser-déposer, verrouillage (ni vente ni sacrifice), vente = ½ coût (+ bonus).
- Cible : 150 (60 C / 55 R / 20 L / 15 M).

## 11. Fortune & Contrats
- **Fortune** : consommables, 2 emplacements, à usage immédiat (souvent ciblant une case). 30 cartes.
- **Contrats** : améliorations permanentes du run, en chaînes de 2 niveaux (`requires`). 20 contrats.

## 12. Boutique
- 3 grigris, 2 paquets (cases / fortune / occulte), 1 contrat. Reroll : 3 $ puis +1 $.
- Probabilités de rareté **affichées**. Filet de sécurité : après 3 boutiques/rerolls sans rare, le prochain tirage en garantit un.
- Économie : récompense d'échéance 3/4/5 $ + 1 $ par tour non utilisé + intérêts 1 $ par 5 $ (plafond 5 $).

## 13. Échec et Pacte
Dette manquée → La Maison propose **un tour supplémentaire** contre un sacrifice : un grigri (le plus à droite non verrouillé), la case la plus précieuse, ou 3 jetons de budget définitivement. 1 Pacte par acte.

## 14. Niveaux de Risque (8, cumulatifs)
1. Dettes +20 %. 2. Petite Échéance : 3 tours. 3. Boutique +25 %. 4. Zéro double (une case 0 supplémentaire). 5. Créanciers renforcés (dette ×1,25). 6. Grigris maudits injectés en boutique. 7. Intérêts désactivés. 8. « La Maison gagne toujours » : Mult final ×0,85.

## 15. Personnages
| Perso | Passif | Roue / départ |
|---|---|---|
| Léa la Croupière | 1 relance de bille gratuite par échéance | standard + grigri « Gant de velours » |
| Vic le Parieur | limites de table ×2, Taxe du Zéro +3 $ | +2 budget, 1 case Épine |
| Dr Odile Khan | probabilités exactes affichées, +Mult sur paris combinés | 3 cases Prisme |
| Barnabé le Corbeau | vole 1 jeton à La Maison par pari gagnant ; +Mult par case éditée | 2 cases Dorées |
| Sœur Marthe | annule le premier tour perdu de chaque palier | 2 cases Sacrées |
| Le Fantôme (succès) | cases Fantômes, roue instable (une case change chaque échéance) | 4 cases Fantômes |

## 16. Créanciers (12 + 2 secrets + finale)
Le Croupier Muet, Madame Rouge-et-Noire, Le Comptable, Le Jumeau, La Chanteuse, Baron Carré, L'Usurier, Le Pyromane, La Douairière, Le Magnétiseur, Le Notaire, Le Prestidigitateur ; secrets : L'Ombre du Grand-Père, Le Croupier d'Or ; finale : Le Patron (palier 7), La Maison (palier 8, 3 phases). Détails : docs/content/creditors.md.

## 17. Campagne
Ton : noir, humour pince-sans-rire, tendresse. ~10 min de dialogues (visual novel, portraits animés, blips). 3 fins (Rembourser, S'enfuir, Reprendre la Maison) + vraie fin secrète. Détails : docs/content/story.md.

## 18. Méta
Hall (déblocages, personnages, Risque max par perso), Codex (collection vue/possédée), 60 succès, 20 défis, graine quotidienne, statistiques, mode Infini.

## 19. Anti-frustration
Anti-série sur les rebonds fous, filet rare en boutique, Pacte, résumé de défaite (« il manquait 12 % ; 3 Zéros ; ton meilleur tour : … »), suggestions de build selon les tags des grigris possédés.

## 20. Plan de production
Voir docs/PROGRESS.md (phases 0 → 14, tags `phase-NN-*`).
