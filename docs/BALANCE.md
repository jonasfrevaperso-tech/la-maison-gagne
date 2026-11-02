# Rapport d'équilibrage (généré par `scripts/sim/sim_main.gd`)

Bot : **greedy** · runs : 600 · risque 0 · durée de simulation 42488 ms

- Taux de victoire : **39.8 %** (objectif bot compétent : 35–45 %)
- Palier moyen atteint : 5.30 / 8
- Durée estimée d'un run : 20.0 min (objectif 35–50 min pour un run gagnant)
- Progression moyenne de la dette au moment de l'échec : 67 %
- Grigris dominants : 30 · délaissés : 30 (sur 170 mesurés)

Limites : les bots visent mieux ou moins bien qu'un humain (erreur de ±1 case dans 35 % des lancers) et le bot « synergy »
estime chaque offre sur 12 tours simulés, ce qui sous-évalue les grigris à croissance lente (ex. Ouroboros, Tirelire).
Il compare la valeur au prix (les légendaires à 10 $ en pâtissent), ne joue ni transversales ni sixains, et ne voit
ni la valeur d'un tour supplémentaire ni celle des améliorations économiques : ces « délaissés » relèvent du bot.

## Courbe de survie par palier

| Palier | Runs l'atteignant |
|---|---|
| 1 | 100.0 % |
| 2 | 91.5 % |
| 3 | 81.7 % |
| 4 | 67.7 % |
| 5 | 56.5 % |
| 6 | 49.0 % |
| 7 | 42.8 % |
| 8 | 40.8 % |
| Victoire | 39.8 % |

## Par personnage

| Personnage | Runs | Victoires | Palier moyen |
|---|---|---|---|
| lea | 120 | 33.3 % | 5.56 |
| vic | 120 | 36.7 % | 5.08 |
| odile | 120 | 45.8 % | 5.36 |
| barnabe | 120 | 43.3 % | 5.28 |
| marthe | 120 | 40.0 % | 5.22 |

## Grigris — taux de choix quand proposé (moyenne 22.3 %, 170 grigris proposés ≥ 8 fois)

Dominant : > 2× la moyenne. Délaissé : < 0,25× la moyenne. Le taux brut dépend de la rareté, d'où cette mesure conditionnelle.

| Grigri | Proposé | Choisi | Taux | × moyenne | Statut |
|---|---|---|---|---|---|
| g_auctioneer | 88 | 83 | 94 % | 4.22 | dominant |
| g_patience | 195 | 170 | 87 % | 3.90 | dominant |
| g_piggy_bank | 188 | 153 | 81 % | 3.64 | dominant |
| g_tram_conductor | 105 | 83 | 79 % | 3.54 | dominant |
| g_stockbroker | 91 | 71 | 78 % | 3.49 | dominant |
| g_window_shopper | 103 | 76 | 74 % | 3.30 | dominant |
| g_monogram | 89 | 64 | 72 % | 3.22 | dominant |
| g_pendulum | 91 | 65 | 71 % | 3.20 | dominant |
| g_accordion | 110 | 77 | 70 % | 3.13 | dominant |
| g_fortune_cookie | 99 | 67 | 68 % | 3.03 | dominant |
| g_tram_line | 88 | 56 | 64 % | 2.85 | dominant |
| g_ladder | 85 | 53 | 62 % | 2.79 | dominant |
| g_red_carpet | 95 | 59 | 62 % | 2.78 | dominant |
| g_bishop | 108 | 64 | 59 % | 2.65 | dominant |
| g_salon_echo | 85 | 48 | 56 % | 2.53 | dominant |
| g_hourglass | 94 | 52 | 55 % | 2.48 | dominant |
| g_insomniac | 107 | 59 | 55 % | 2.47 | dominant |
| g_cracked_monocle | 110 | 60 | 55 % | 2.44 | dominant |
| g_marksman | 87 | 46 | 53 % | 2.37 | dominant |
| g_ash_collector | 76 | 40 | 53 % | 2.36 | dominant |
| g_glass_heart | 93 | 47 | 51 % | 2.26 | dominant |
| g_last_call | 102 | 51 | 50 % | 2.24 | dominant |
| g_twin_flame | 87 | 42 | 48 % | 2.16 | dominant |
| g_gilded_cage | 96 | 45 | 47 % | 2.10 | dominant |
| g_night_owl | 90 | 42 | 47 % | 2.09 | dominant |
| g_sommelier | 88 | 41 | 47 % | 2.09 | dominant |
| g_minimalist | 107 | 49 | 46 % | 2.05 | dominant |
| g_bow_tie | 81 | 37 | 46 % | 2.05 | dominant |
| g_funhouse_mirror | 88 | 40 | 45 % | 2.04 | dominant |
| g_neighbours | 94 | 42 | 45 % | 2.00 | dominant |
| g_seven_sisters | 100 | 44 | 44 % | 1.97 | ok |
| g_ruby_slipper | 105 | 46 | 44 % | 1.96 | ok |
| g_glass_cutter | 101 | 41 | 41 % | 1.82 | ok |
| g_twin_dice | 106 | 43 | 41 % | 1.82 | ok |
| g_high_roller | 85 | 34 | 40 % | 1.79 | ok |
| g_zero_lover | 98 | 38 | 39 % | 1.74 | ok |
| g_croupier_wink | 97 | 36 | 37 % | 1.66 | ok |
| g_double_or_nothing | 100 | 37 | 37 % | 1.66 | ok |
| g_shoe_shine | 206 | 74 | 36 % | 1.61 | ok |
| g_metro_map | 86 | 29 | 34 % | 1.51 | ok |
| g_geometer | 214 | 71 | 33 % | 1.49 | ok |
| g_horseshoe | 238 | 76 | 32 % | 1.43 | ok |
| g_miser | 235 | 74 | 31 % | 1.41 | ok |
| g_outsider | 242 | 76 | 31 % | 1.41 | ok |
| g_hinge | 230 | 72 | 31 % | 1.40 | ok |
| g_night_glasses | 201 | 60 | 30 % | 1.34 | ok |
| g_quartet | 253 | 74 | 29 % | 1.31 | ok |
| g_window_dresser | 83 | 24 | 29 % | 1.29 | ok |
| g_golden_rake | 39 | 11 | 28 % | 1.26 | ok |
| g_straight_razor | 227 | 63 | 28 % | 1.24 | ok |
| g_baker | 221 | 60 | 27 % | 1.22 | ok |
| g_odd_pair | 232 | 62 | 27 % | 1.20 | ok |
| g_ledger | 81 | 21 | 26 % | 1.16 | ok |
| g_column_drummer | 238 | 60 | 25 % | 1.13 | ok |
| g_eternity_clock | 48 | 12 | 25 % | 1.12 | ok |
| g_so_close | 249 | 60 | 24 % | 1.08 | ok |
| g_high_heels | 257 | 59 | 23 % | 1.03 | ok |
| g_bookie | 98 | 22 | 22 % | 1.01 | ok |
| g_cracked_chip | 219 | 49 | 22 % | 1.00 | ok |
| g_first_drink | 265 | 59 | 22 % | 1.00 | ok |
| g_low_lamp | 254 | 56 | 22 % | 0.99 | ok |
| g_spare_change | 219 | 48 | 22 % | 0.98 | ok |
| g_lucky_seven | 211 | 46 | 22 % | 0.98 | ok |
| g_black_cat | 221 | 48 | 22 % | 0.97 | ok |
| g_paper_crown | 243 | 48 | 20 % | 0.88 | ok |
| g_brass_knuckles | 245 | 47 | 19 % | 0.86 | ok |
| g_ashtray | 240 | 46 | 19 % | 0.86 | ok |
| g_neon_sign | 245 | 46 | 19 % | 0.84 | ok |
| g_matchbox | 245 | 46 | 19 % | 0.84 | ok |
| g_coat_check | 261 | 48 | 18 % | 0.82 | ok |
| g_ruby_brooch | 236 | 43 | 18 % | 0.82 | ok |
| g_cufflinks | 254 | 46 | 18 % | 0.81 | ok |
| g_slow_waltz | 254 | 45 | 18 % | 0.79 | ok |
| g_ouroboros | 58 | 10 | 17 % | 0.77 | ok |
| g_billiard_chalk | 232 | 39 | 17 % | 0.75 | ok |
| g_magnet_shoes | 238 | 40 | 17 % | 0.75 | ok |
| g_steel_toes | 239 | 40 | 17 % | 0.75 | ok |
| g_empty_pockets | 230 | 38 | 17 % | 0.74 | ok |
| g_tramway | 231 | 38 | 16 % | 0.74 | ok |
| g_green_visor | 248 | 40 | 16 % | 0.72 | ok |
| g_marathon | 220 | 35 | 16 % | 0.71 | ok |
| g_umbrella | 229 | 36 | 16 % | 0.70 | ok |
| g_folding_fan | 259 | 40 | 15 % | 0.69 | ok |
| g_city_block | 98 | 15 | 15 % | 0.69 | ok |
| g_house_rules | 236 | 36 | 15 % | 0.68 | ok |
| g_dice_cup | 263 | 40 | 15 % | 0.68 | ok |
| g_loaded_die | 259 | 39 | 15 % | 0.67 | ok |
| g_scarlet_streak | 246 | 37 | 15 % | 0.67 | ok |
| g_phoenix | 60 | 9 | 15 % | 0.67 | ok |
| g_red_ribbon | 253 | 36 | 14 % | 0.64 | ok |
| g_rubber_ball | 224 | 31 | 14 % | 0.62 | ok |
| g_weighted_chip | 254 | 33 | 13 % | 0.58 | ok |
| g_wax_stamp | 264 | 34 | 13 % | 0.58 | ok |
| g_grand_zero | 39 | 5 | 13 % | 0.57 | ok |
| g_grandmaster | 40 | 5 | 12 % | 0.56 | ok |
| g_maestro | 42 | 5 | 12 % | 0.53 | ok |
| g_ballroom | 42 | 5 | 12 % | 0.53 | ok |
| g_metropolis | 43 | 5 | 12 % | 0.52 | ok |
| g_sugar_cube | 246 | 28 | 11 % | 0.51 | ok |
| g_six_pack | 241 | 27 | 11 % | 0.50 | ok |
| g_insurance | 91 | 10 | 11 % | 0.49 | ok |
| g_egg_box | 256 | 27 | 11 % | 0.47 | ok |
| g_red_tape | 252 | 26 | 10 % | 0.46 | ok |
| g_silver_tongue | 49 | 5 | 10 % | 0.46 | ok |
| g_doric_column | 253 | 25 | 10 % | 0.44 | ok |
| g_metro_ticket | 264 | 26 | 10 % | 0.44 | ok |
| g_revenge | 51 | 5 | 10 % | 0.44 | ok |
| g_lipstick | 237 | 23 | 10 % | 0.43 | ok |
| g_cartographer | 104 | 10 | 10 % | 0.43 | ok |
| g_cigarette_holder | 255 | 24 | 9 % | 0.42 | ok |
| g_double_espresso | 228 | 21 | 9 % | 0.41 | ok |
| g_half_moon | 231 | 21 | 9 % | 0.41 | ok |
| g_blueprint | 124 | 11 | 9 % | 0.40 | ok |
| g_metronome | 80 | 7 | 9 % | 0.39 | ok |
| g_magnifier | 220 | 19 | 9 % | 0.39 | ok |
| g_gin_flask | 105 | 9 | 9 % | 0.38 | ok |
| g_census | 106 | 9 | 8 % | 0.38 | ok |
| g_gardener | 107 | 9 | 8 % | 0.38 | ok |
| g_seamstress | 96 | 8 | 8 % | 0.37 | ok |
| g_perpetual_motion | 48 | 4 | 8 % | 0.37 | ok |
| g_gold_tooth | 90 | 7 | 8 % | 0.35 | ok |
| g_india_ink | 247 | 19 | 8 % | 0.34 | ok |
| g_lottery_ticket | 248 | 19 | 8 % | 0.34 | ok |
| g_even_sock | 249 | 19 | 8 % | 0.34 | ok |
| g_boss_cigar | 280 | 21 | 8 % | 0.34 | ok |
| g_pearl_necklace | 96 | 7 | 7 % | 0.33 | ok |
| g_odd_duck | 253 | 18 | 7 % | 0.32 | ok |
| g_velvet_glove | 240 | 17 | 7 % | 0.32 | ok |
| g_house_of_cards | 44 | 3 | 7 % | 0.31 | ok |
| g_compound | 103 | 7 | 7 % | 0.30 | ok |
| g_zero_hero | 266 | 18 | 7 % | 0.30 | ok |
| g_tip_jar | 239 | 16 | 7 % | 0.30 | ok |
| g_archivist | 45 | 3 | 7 % | 0.30 | ok |
| g_twin_city | 45 | 3 | 7 % | 0.30 | ok |
| g_tarot_reader | 258 | 17 | 7 % | 0.30 | ok |
| g_undertaker | 266 | 17 | 6 % | 0.29 | ok |
| g_lucky_penny | 276 | 17 | 6 % | 0.28 | ok |
| g_bellhop | 247 | 15 | 6 % | 0.27 | ok |
| g_infinite_chip | 50 | 3 | 6 % | 0.27 | ok |
| g_notary_ring | 89 | 5 | 6 % | 0.25 | ok |
| g_house_key | 37 | 2 | 5 % | 0.24 | délaissé |
| g_glass_blower | 263 | 13 | 5 % | 0.22 | délaissé |
| g_dying_neon | 240 | 11 | 5 % | 0.21 | délaissé |
| g_crown_jewels | 46 | 2 | 4 % | 0.19 | délaissé |
| g_philosophers_stone | 53 | 2 | 4 % | 0.17 | délaissé |
| g_secret_pocket | 240 | 9 | 4 % | 0.17 | délaissé |
| g_spiderweb | 85 | 3 | 4 % | 0.16 | délaissé |
| g_bank_vault | 57 | 2 | 4 % | 0.16 | délaissé |
| g_monocle | 256 | 8 | 3 % | 0.14 | délaissé |
| g_zero_tithe | 103 | 3 | 3 % | 0.13 | délaissé |
| g_fortune_teller | 112 | 3 | 3 % | 0.12 | délaissé |
| g_chandelier | 40 | 1 | 2 % | 0.11 | délaissé |
| g_compass | 88 | 2 | 2 % | 0.10 | délaissé |
| g_dealer_hand | 44 | 1 | 2 % | 0.10 | délaissé |
| g_notary_stamp | 92 | 2 | 2 % | 0.10 | délaissé |
| g_pickpocket | 93 | 2 | 2 % | 0.10 | délaissé |
| g_lodestone | 102 | 2 | 2 % | 0.09 | délaissé |
| g_deck_of_fate | 51 | 1 | 2 % | 0.09 | délaissé |
| g_rainmaker | 102 | 2 | 2 % | 0.09 | délaissé |
| g_landlord | 111 | 2 | 2 % | 0.08 | délaissé |
| g_forger | 80 | 1 | 1 % | 0.06 | délaissé |
| g_trapdoor | 95 | 1 | 1 % | 0.05 | délaissé |
| g_jeweller | 102 | 1 | 1 % | 0.04 | délaissé |
| g_alchemist | 105 | 1 | 1 % | 0.04 | délaissé |
| g_after_hours | 106 | 1 | 1 % | 0.04 | délaissé |
| g_sealing_wax | 97 | 0 | 0 % | 0.00 | délaissé |
| g_overtime | 116 | 0 | 0 % | 0.00 | délaissé |
| g_scrap_dealer | 99 | 0 | 0 % | 0.00 | délaissé |
| g_coupon_book | 96 | 0 | 0 % | 0.00 | délaissé |
| g_oracle | 35 | 0 | 0 % | 0.00 | délaissé |

## Version 1.5
Seules évolutions du cœur : le tour offert par la machine à sous survit à une échéance remboursée sur le même tour, et un paquet ne peut plus être acheté sans place libre. La qualité du lancer est désormais moyenne(2 épreuves) × 0,65 + lâcher × 0,35, recalée sur la même référence (0,65) : la correspondance qualité → contrôle (`ThrowSkill.control_bonus`) ne change pas.

| Bot | Parties | Victoire | 1.4 |
|---|---|---|---|
| greedy, lancer neutre | 600 | **39,8 %** | — |
| expert, lancer neutre (graines 201–204) | 240 | **47,1 %** (31,7 / 50,0 / 55,0 / 51,7) | 45,5 % |
| expert, lancers adroits (`--throw-skill=0.8`) | 240 | **54,2 %** | 56,2 % (0,7) |

L'écart de l'expert neutre (+1,6 point) est inférieur à l'erreur type (≈ 3,2 points sur 240 parties) : aucun réglage modifié. Le banc des épreuves (`--dev-trial-bench`) garantit que chaque épreuve est réussie par un joueur appliqué (≥ 0,8) et ratée sans rien faire (≤ 0,4).
