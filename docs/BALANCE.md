# Rapport d'équilibrage (généré par `scripts/sim/sim_main.gd`)

Bot : **greedy** · runs : 600 · risque 0 · durée de simulation 44246 ms

- Taux de victoire : **39.0 %** (objectif bot compétent : 35–45 %)
- Palier moyen atteint : 5.69 / 8
- Durée estimée d'un run : 21.1 min (objectif 35–50 min pour un run gagnant)
- Progression moyenne de la dette au moment de l'échec : 68 %
- Grigris dominants : 30 · délaissés : 35 (sur 179 mesurés)

Limites : les bots visent mieux ou moins bien qu'un humain (erreur de ±1 case dans 35 % des lancers) et le bot « synergy »
estime chaque offre sur 12 tours simulés, ce qui sous-évalue les grigris à croissance lente (ex. Ouroboros, Tirelire).
Il compare la valeur au prix (les légendaires à 10 $ en pâtissent), ne joue ni transversales ni sixains, et ne voit
ni la valeur d'un tour supplémentaire ni celle des améliorations économiques : ces « délaissés » relèvent du bot.

## Courbe de survie par palier

| Palier | Runs l'atteignant |
|---|---|
| 1 | 100.0 % |
| 2 | 97.0 % |
| 3 | 90.2 % |
| 4 | 77.0 % |
| 5 | 64.8 % |
| 6 | 53.8 % |
| 7 | 45.7 % |
| 8 | 40.8 % |
| Victoire | 39.0 % |

## Par personnage

| Personnage | Runs | Victoires | Palier moyen |
|---|---|---|---|
| lea | 120 | 35.8 % | 5.67 |
| vic | 120 | 36.7 % | 5.70 |
| odile | 120 | 36.7 % | 5.43 |
| barnabe | 120 | 43.3 % | 5.88 |
| marthe | 120 | 42.5 % | 5.78 |

## Grigris — taux de choix quand proposé (moyenne 23.5 %, 179 grigris proposés ≥ 8 fois)

Dominant : > 2× la moyenne. Délaissé : < 0,25× la moyenne. Le taux brut dépend de la rareté, d'où cette mesure conditionnelle.

| Grigri | Proposé | Choisi | Taux | × moyenne | Statut |
|---|---|---|---|---|---|
| g_auctioneer | 100 | 91 | 91 % | 3.87 | dominant |
| g_chain_reaction | 96 | 87 | 91 % | 3.85 | dominant |
| g_lucette_photo | 89 | 78 | 88 % | 3.73 | dominant |
| g_patience | 204 | 178 | 87 % | 3.71 | dominant |
| g_piggy_bank | 207 | 166 | 80 % | 3.41 | dominant |
| g_pendulum | 96 | 72 | 75 % | 3.19 | dominant |
| g_window_shopper | 109 | 80 | 73 % | 3.12 | dominant |
| g_stockbroker | 99 | 72 | 73 % | 3.09 | dominant |
| g_monogram | 91 | 63 | 69 % | 2.94 | dominant |
| g_tram_conductor | 81 | 56 | 69 % | 2.94 | dominant |
| g_ash_collector | 105 | 67 | 64 % | 2.71 | dominant |
| g_ladder | 77 | 49 | 64 % | 2.71 | dominant |
| g_accordion | 101 | 64 | 63 % | 2.69 | dominant |
| g_fortune_cookie | 99 | 61 | 62 % | 2.62 | dominant |
| g_bishop | 112 | 69 | 62 % | 2.62 | dominant |
| g_glass_heart | 94 | 57 | 61 % | 2.58 | dominant |
| g_salon_echo | 105 | 62 | 59 % | 2.51 | dominant |
| g_red_carpet | 96 | 54 | 56 % | 2.39 | dominant |
| g_gilded_cage | 98 | 55 | 56 % | 2.39 | dominant |
| g_marksman | 104 | 58 | 56 % | 2.37 | dominant |
| g_tram_line | 86 | 46 | 53 % | 2.27 | dominant |
| g_glass_cutter | 119 | 62 | 52 % | 2.21 | dominant |
| g_night_owl | 98 | 51 | 52 % | 2.21 | dominant |
| g_funhouse_mirror | 102 | 53 | 52 % | 2.21 | dominant |
| g_sommelier | 91 | 45 | 49 % | 2.10 | dominant |
| g_bow_tie | 99 | 48 | 48 % | 2.06 | dominant |
| g_double_or_nothing | 91 | 44 | 48 % | 2.06 | dominant |
| g_neighbours | 83 | 40 | 48 % | 2.05 | dominant |
| g_minimalist | 97 | 46 | 47 % | 2.02 | dominant |
| g_last_call | 91 | 43 | 47 % | 2.01 | dominant |
| g_twin_dice | 79 | 36 | 46 % | 1.94 | ok |
| g_window_dresser | 125 | 56 | 45 % | 1.90 | ok |
| g_bell_choir | 96 | 43 | 45 % | 1.90 | ok |
| g_twin_flame | 89 | 39 | 44 % | 1.86 | ok |
| g_cracked_monocle | 101 | 44 | 44 % | 1.85 | ok |
| g_insomniac | 97 | 42 | 43 % | 1.84 | ok |
| g_seven_sisters | 89 | 38 | 43 % | 1.82 | ok |
| g_compound_interest | 101 | 43 | 43 % | 1.81 | ok |
| g_geometer | 235 | 100 | 43 % | 1.81 | ok |
| g_high_roller | 97 | 41 | 42 % | 1.80 | ok |
| g_hourglass | 98 | 41 | 42 % | 1.78 | ok |
| g_ruby_slipper | 107 | 44 | 41 % | 1.75 | ok |
| g_miser | 237 | 95 | 40 % | 1.70 | ok |
| g_metro_map | 98 | 39 | 40 % | 1.69 | ok |
| g_shoe_shine | 245 | 97 | 40 % | 1.68 | ok |
| g_zero_lover | 91 | 32 | 35 % | 1.49 | ok |
| g_eternity_clock | 55 | 19 | 35 % | 1.47 | ok |
| g_quartet | 238 | 77 | 32 % | 1.38 | ok |
| g_column_drummer | 246 | 77 | 31 % | 1.33 | ok |
| g_straight_razor | 246 | 75 | 30 % | 1.30 | ok |
| g_croupier_wink | 97 | 29 | 30 % | 1.27 | ok |
| g_night_glasses | 230 | 67 | 29 % | 1.24 | ok |
| g_baker | 269 | 75 | 28 % | 1.19 | ok |
| g_outsider | 248 | 69 | 28 % | 1.18 | ok |
| g_phoenix | 47 | 13 | 28 % | 1.18 | ok |
| g_ledger | 91 | 25 | 27 % | 1.17 | ok |
| g_city_block | 96 | 25 | 26 % | 1.11 | ok |
| g_bookie | 96 | 25 | 26 % | 1.11 | ok |
| g_horseshoe | 254 | 64 | 25 % | 1.07 | ok |
| g_odd_pair | 238 | 59 | 25 % | 1.05 | ok |
| g_maestro | 37 | 9 | 24 % | 1.03 | ok |
| g_hinge | 256 | 61 | 24 % | 1.01 | ok |
| g_cracked_chip | 265 | 56 | 21 % | 0.90 | ok |
| g_red_ribbon | 257 | 52 | 20 % | 0.86 | ok |
| g_ashtray | 220 | 44 | 20 % | 0.85 | ok |
| g_golden_rake | 56 | 11 | 20 % | 0.84 | ok |
| g_rubber_ball | 253 | 49 | 19 % | 0.82 | ok |
| g_steel_toes | 248 | 47 | 19 % | 0.81 | ok |
| g_so_close | 260 | 48 | 18 % | 0.78 | ok |
| g_silver_tongue | 49 | 9 | 18 % | 0.78 | ok |
| g_low_lamp | 245 | 45 | 18 % | 0.78 | ok |
| g_first_drink | 221 | 40 | 18 % | 0.77 | ok |
| g_spare_change | 249 | 45 | 18 % | 0.77 | ok |
| g_brass_knuckles | 256 | 46 | 18 % | 0.76 | ok |
| g_tramway | 255 | 45 | 18 % | 0.75 | ok |
| g_weighted_chip | 276 | 48 | 17 % | 0.74 | ok |
| g_high_heels | 253 | 44 | 17 % | 0.74 | ok |
| g_loaded_die | 243 | 42 | 17 % | 0.73 | ok |
| g_dice_cup | 249 | 43 | 17 % | 0.73 | ok |
| g_marathon | 244 | 42 | 17 % | 0.73 | ok |
| g_paper_crown | 257 | 44 | 17 % | 0.73 | ok |
| g_cufflinks | 225 | 38 | 17 % | 0.72 | ok |
| g_lucky_seven | 249 | 42 | 17 % | 0.72 | ok |
| g_umbrella | 258 | 43 | 17 % | 0.71 | ok |
| g_crown_jewels | 42 | 7 | 17 % | 0.71 | ok |
| g_empty_pockets | 221 | 36 | 16 % | 0.69 | ok |
| g_sugar_cube | 234 | 38 | 16 % | 0.69 | ok |
| g_doric_column | 257 | 40 | 16 % | 0.66 | ok |
| g_slow_waltz | 245 | 38 | 16 % | 0.66 | ok |
| g_billiard_chalk | 233 | 36 | 15 % | 0.66 | ok |
| g_double_down | 39 | 6 | 15 % | 0.65 | ok |
| g_coat_check | 247 | 38 | 15 % | 0.65 | ok |
| g_house_rules | 242 | 37 | 15 % | 0.65 | ok |
| g_egg_box | 279 | 42 | 15 % | 0.64 | ok |
| g_ouroboros | 40 | 6 | 15 % | 0.64 | ok |
| g_six_pack | 234 | 35 | 15 % | 0.64 | ok |
| g_black_cat | 275 | 41 | 15 % | 0.63 | ok |
| g_scarlet_streak | 249 | 37 | 15 % | 0.63 | ok |
| g_neon_sign | 252 | 37 | 15 % | 0.62 | ok |
| g_matchbox | 257 | 37 | 14 % | 0.61 | ok |
| g_wax_stamp | 223 | 31 | 14 % | 0.59 | ok |
| g_house_key | 44 | 6 | 14 % | 0.58 | ok |
| g_ruby_brooch | 249 | 33 | 13 % | 0.56 | ok |
| g_green_visor | 267 | 35 | 13 % | 0.56 | ok |
| g_gin_flask | 92 | 12 | 13 % | 0.55 | ok |
| g_metro_ticket | 247 | 32 | 13 % | 0.55 | ok |
| g_chandelier | 47 | 6 | 13 % | 0.54 | ok |
| g_dealer_hand | 47 | 6 | 13 % | 0.54 | ok |
| g_perpetual_motion | 40 | 5 | 12 % | 0.53 | ok |
| g_house_of_cards | 41 | 5 | 12 % | 0.52 | ok |
| g_blueprint | 115 | 14 | 12 % | 0.52 | ok |
| g_jackpot_tokens | 115 | 14 | 12 % | 0.52 | ok |
| g_velvet_glove | 223 | 27 | 12 % | 0.51 | ok |
| g_magnet_shoes | 251 | 30 | 12 % | 0.51 | ok |
| g_metropolis | 53 | 6 | 11 % | 0.48 | ok |
| g_folding_fan | 224 | 24 | 11 % | 0.46 | ok |
| g_even_sock | 257 | 27 | 11 % | 0.45 | ok |
| g_cigarette_holder | 277 | 29 | 10 % | 0.45 | ok |
| g_odd_duck | 261 | 26 | 10 % | 0.42 | ok |
| g_gardener | 91 | 9 | 10 % | 0.42 | ok |
| g_tip_jar | 236 | 23 | 10 % | 0.41 | ok |
| g_red_tape | 259 | 25 | 10 % | 0.41 | ok |
| g_lottery_ticket | 259 | 25 | 10 % | 0.41 | ok |
| g_boss_cigar | 261 | 25 | 10 % | 0.41 | ok |
| g_magnifier | 263 | 25 | 10 % | 0.40 | ok |
| g_notary_ring | 116 | 11 | 9 % | 0.40 | ok |
| g_india_ink | 257 | 24 | 9 % | 0.40 | ok |
| g_gold_tooth | 103 | 9 | 9 % | 0.37 | ok |
| g_half_moon | 253 | 22 | 9 % | 0.37 | ok |
| g_undertaker | 254 | 22 | 9 % | 0.37 | ok |
| g_bellhop | 254 | 22 | 9 % | 0.37 | ok |
| g_insurance | 94 | 8 | 9 % | 0.36 | ok |
| g_grand_zero | 48 | 4 | 8 % | 0.35 | ok |
| g_cartographer | 97 | 8 | 8 % | 0.35 | ok |
| g_double_espresso | 282 | 23 | 8 % | 0.35 | ok |
| g_metronome | 111 | 9 | 8 % | 0.34 | ok |
| g_revenge | 51 | 4 | 8 % | 0.33 | ok |
| g_dying_neon | 245 | 19 | 8 % | 0.33 | ok |
| g_census | 80 | 6 | 8 % | 0.32 | ok |
| g_lipstick | 249 | 18 | 7 % | 0.31 | ok |
| g_pocket_slot | 254 | 18 | 7 % | 0.30 | ok |
| g_glass_blower | 250 | 17 | 7 % | 0.29 | ok |
| g_pickpocket | 109 | 7 | 6 % | 0.27 | ok |
| g_grandmaster | 50 | 3 | 6 % | 0.26 | ok |
| g_archivist | 52 | 3 | 6 % | 0.25 | délaissé |
| g_seamstress | 87 | 5 | 6 % | 0.24 | délaissé |
| g_zero_hero | 240 | 13 | 5 % | 0.23 | délaissé |
| g_infinite_chip | 59 | 3 | 5 % | 0.22 | délaissé |
| g_lucky_penny | 265 | 13 | 5 % | 0.21 | délaissé |
| g_coin_bucket | 288 | 14 | 5 % | 0.21 | délaissé |
| g_tarot_reader | 252 | 12 | 5 % | 0.20 | délaissé |
| g_compass | 106 | 5 | 5 % | 0.20 | délaissé |
| g_ballroom | 43 | 2 | 5 % | 0.20 | délaissé |
| g_notary_stamp | 94 | 4 | 4 % | 0.18 | délaissé |
| g_groom_bell | 265 | 11 | 4 % | 0.18 | délaissé |
| g_monocle | 249 | 10 | 4 % | 0.17 | délaissé |
| g_twin_city | 51 | 2 | 4 % | 0.17 | délaissé |
| g_landlord | 103 | 4 | 4 % | 0.17 | délaissé |
| g_pearl_necklace | 106 | 4 | 4 % | 0.16 | délaissé |
| g_secret_pocket | 275 | 10 | 4 % | 0.15 | délaissé |
| g_coupon_book | 111 | 4 | 4 % | 0.15 | délaissé |
| g_spiderweb | 114 | 4 | 4 % | 0.15 | délaissé |
| g_jeweller | 94 | 3 | 3 % | 0.14 | délaissé |
| g_compound | 95 | 3 | 3 % | 0.13 | délaissé |
| g_deck_of_fate | 36 | 1 | 3 % | 0.12 | délaissé |
| g_lodestone | 117 | 3 | 3 % | 0.11 | délaissé |
| g_oracle | 49 | 1 | 2 % | 0.09 | délaissé |
| g_fortune_teller | 100 | 2 | 2 % | 0.09 | délaissé |
| g_rainmaker | 108 | 2 | 2 % | 0.08 | délaissé |
| g_philosophers_stone | 61 | 1 | 2 % | 0.07 | délaissé |
| g_trapdoor | 81 | 1 | 1 % | 0.05 | délaissé |
| g_zero_tithe | 90 | 1 | 1 % | 0.05 | délaissé |
| g_after_hours | 94 | 1 | 1 % | 0.05 | délaissé |
| g_sealing_wax | 100 | 1 | 1 % | 0.04 | délaissé |
| g_bank_vault | 36 | 0 | 0 % | 0.00 | délaissé |
| g_overtime | 96 | 0 | 0 % | 0.00 | délaissé |
| g_scrap_dealer | 104 | 0 | 0 % | 0.00 | délaissé |
| g_alchemist | 107 | 0 | 0 % | 0.00 | délaissé |
| g_forger | 85 | 0 | 0 % | 0.00 | délaissé |

## Version 1.5
Seules évolutions du cœur : le tour offert par la machine à sous survit à une échéance remboursée sur le même tour, et un paquet ne peut plus être acheté sans place libre. La qualité du lancer est désormais moyenne(2 épreuves) × 0,65 + lâcher × 0,35, recalée sur la même référence (0,65) : la correspondance qualité → contrôle (`ThrowSkill.control_bonus`) ne change pas.

| Bot | Parties | Victoire | 1.4 |
|---|---|---|---|
| greedy, lancer neutre | 600 | **39,8 %** | — |
| expert, lancer neutre (graines 201–204) | 240 | **47,1 %** (31,7 / 50,0 / 55,0 / 51,7) | 45,5 % |
| expert, lancers adroits (`--throw-skill=0.8`) | 240 | **54,2 %** | 56,2 % (0,7) |

L'écart de l'expert neutre (+1,6 point) est inférieur à l'erreur type (≈ 3,2 points sur 240 parties) : aucun réglage modifié. Le banc des épreuves (`--dev-trial-bench`) garantit que chaque épreuve est réussie par un joueur appliqué (≥ 0,8) et ratée sans rien faire (≤ 0,4).

## Version 1.5.1
Nouvelle courbe de dettes `[180, 460, 1050, 2350, 5000, 10200, 20000, 37000]` (ancienne `[240, 600, 1200, 2500, 4800, 8500, 14000, 21000]`), sans fin ×1,9 par palier. Courbes candidates comparées au bot glouton (400 parties chacune) :

| Courbe | Dernier palier | Victoire glouton |
|---|---|---|
| ancienne | 21 000 | 39,2 % |
| ×2,2 régulier | 90 000 | 17,0 % |
| ×2,1 régulier | 72 000 | 22,2 % |
| début 220, fin 48 000 | 48 000 | 31,8 % |
| début 200, fin 38 000 | 38 000 | 36,5 % |
| **retenue** : début 180, fin 37 000 | 37 000 | **40,0 %** |

Vérification finale avec tout le contenu 1.5.1 (machine à sous plus fréquente, Sceau Cloche, 9 nouveaux grigris dont des ×Mult croissants, épreuves durcies) :

| Bot | Parties | Victoire | 1.5 |
|---|---|---|---|
| glouton | 600 | **39,0 %** | 39,8 % |
| expert, lancer neutre | 60 | **45,0 %** (erreur type ≈ 6,4 points) | 47,1 % |

Le début plus doux compense des premiers paliers où le joueur n'a pas encore de build ; la fin plus raide demande de vrais moteurs multiplicatifs (les grigris ×Mult croissants permettent des tours à plusieurs millions). Le total d'un tour est plafonné à 10¹⁸.

« Photo de Lucette » et « Réaction en chaîne » ressortent « dominants » (≈ 90 % de choix) : le bot glouton surévalue l'étiquette ×Mult. Leurs gains ont été réduits (+0,2 par jackpot ; +×0,35 par relance) sans effet sur le taux de choix, et le taux de victoire reste dans la cible : artefact du bot, à confirmer avec des parties humaines.

## Version 1.5.2

La machine à sous passe à quatre rouleaux avec deux symboles de plus (citron, fer à cheval) pour garder des combinaisons rares : paire ≈ 56 %, brelan ≈ 6,9 %, carré ≈ 0,3 % (cotes calculées par énumération, vérifiées par `test_v14_slot`). Les carrés ont des lots dédiés (`slot_prizes.json`), en repli sur le brelan puis la paire.

| Bot | Parties | Victoire | 1.5.1 |
|---|---|---|---|
| glouton | 600 | **43,3 %** | 39,0 % |

La hausse (+4,3 points) vient des lots de la machine à sous, plus variés et plus fréquents (paires à 4 rouleaux) ; elle reste dans la cible de 35–45 %, aucun réglage modifié. Correction qui touche l'adresse : aux Fléchettes, un appui immédiat ne tombe plus au centre (le banc des épreuves reste vert : bot ≥ 0,8, inactif ≤ 0,4 sur les 14 épreuves).

### Correctif 1.5.3

Mesure experte de la 1.5.2 : **56,0 %** (100 parties) — trop haut. La machine à sous pèse ≈ 17 points (glouton 25,8 % avec `slot.max_pulls=0`) ; le plafond de tirages et le seuil du « gros coup » n'ont pas d'effet mesurable, ce sont les lots ×Mult qui comptent. Réglages : brelan/carré/paire de cerises ×1,5 / ×2 / +1, paire de diamants ×1,25, carré de fers ×1,5 ; poids du 7 9 → 7, du diamant 5 → 4.

| Bot | Graine | Parties | Victoire |
|---|---|---|---|
| glouton | 1 / 2 / 3 | 3 × 600 | 44,2 / 37,0 / 40,0 % (**40,4 %**) |
| expert | 1 / 2 | 2 × 100 | 51,0 / 45,0 % (**48,0 %**, erreur type ≈ 3,5 points) |

L'expert reste au niveau des versions précédentes (47,1 % en 1.5, 45,0 % en 1.5.1).
