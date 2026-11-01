# Rapport d'équilibrage (généré par `scripts/sim/sim_main.gd`)

Bot : **synergy** · runs : 300 · risque 0 · durée de simulation 1373571 ms

- Taux de victoire : **39.7 %** (objectif bot compétent : 35–45 %)
- Palier moyen atteint : 5.98 / 8
- Durée estimée d'un run : 22.5 min (objectif 35–50 min pour un run gagnant)
- Progression moyenne de la dette au moment de l'échec : 69 %
- Grigris dominants : 10 · délaissés : 12 (sur 135 mesurés)

Limites : les bots visent mieux ou moins bien qu'un humain (erreur de ±1 case dans 35 % des lancers) et le bot « synergy »
estime chaque offre sur 12 tours simulés, ce qui sous-évalue les grigris à croissance lente (ex. Ouroboros, Tirelire).
Il compare la valeur au prix (les légendaires à 10 $ en pâtissent), ne joue ni transversales ni sixains, et ne voit
ni la valeur d'un tour supplémentaire ni celle des améliorations économiques : ces « délaissés » relèvent du bot.

## Courbe de survie par palier

| Palier | Runs l'atteignant |
|---|---|
| 1 | 100.0 % |
| 2 | 93.3 % |
| 3 | 89.3 % |
| 4 | 82.3 % |
| 5 | 72.0 % |
| 6 | 61.0 % |
| 7 | 53.0 % |
| 8 | 46.7 % |
| Victoire | 39.7 % |

## Par personnage

| Personnage | Runs | Victoires | Palier moyen |
|---|---|---|---|
| lea | 60 | 45.0 % | 6.53 |
| vic | 60 | 33.3 % | 5.78 |
| odile | 60 | 41.7 % | 5.70 |
| barnabe | 60 | 40.0 % | 6.00 |
| marthe | 60 | 38.3 % | 5.87 |

## Grigris — taux de choix quand proposé (moyenne 25.2 %, 135 grigris proposés ≥ 8 fois)

Dominant : > 2× la moyenne. Délaissé : < 0,25× la moyenne. Le taux brut dépend de la rareté, d'où cette mesure conditionnelle.

| Grigri | Proposé | Choisi | Taux | × moyenne | Statut |
|---|---|---|---|---|---|
| g_house_rules | 135 | 111 | 82 % | 3.27 | dominant |
| g_straight_razor | 168 | 111 | 66 % | 2.63 | dominant |
| g_hourglass | 68 | 44 | 65 % | 2.57 | dominant |
| g_paper_crown | 157 | 99 | 63 % | 2.51 | dominant |
| g_matchbox | 177 | 98 | 55 % | 2.20 | dominant |
| g_metronome | 77 | 42 | 55 % | 2.17 | dominant |
| g_loaded_die | 167 | 90 | 54 % | 2.14 | dominant |
| g_ledger | 76 | 40 | 53 % | 2.09 | dominant |
| g_high_heels | 192 | 100 | 52 % | 2.07 | dominant |
| g_cracked_chip | 175 | 90 | 51 % | 2.04 | dominant |
| g_shoe_shine | 161 | 81 | 50 % | 2.00 | ok |
| g_ashtray | 168 | 82 | 49 % | 1.94 | ok |
| g_bookie | 62 | 30 | 48 % | 1.92 | ok |
| g_house_key | 27 | 13 | 48 % | 1.91 | ok |
| g_velvet_glove | 166 | 78 | 47 % | 1.87 | ok |
| g_green_visor | 171 | 80 | 47 % | 1.86 | ok |
| g_dice_cup | 172 | 80 | 47 % | 1.85 | ok |
| g_billiard_chalk | 153 | 70 | 46 % | 1.82 | ok |
| g_scarlet_streak | 160 | 72 | 45 % | 1.79 | ok |
| g_sugar_cube | 167 | 73 | 44 % | 1.74 | ok |
| g_auctioneer | 71 | 31 | 44 % | 1.73 | ok |
| g_black_cat | 165 | 70 | 42 % | 1.69 | ok |
| g_salon_echo | 88 | 37 | 42 % | 1.67 | ok |
| g_miser | 174 | 73 | 42 % | 1.67 | ok |
| g_boss_cigar | 186 | 78 | 42 % | 1.67 | ok |
| g_outsider | 153 | 64 | 42 % | 1.66 | ok |
| g_low_lamp | 161 | 67 | 42 % | 1.65 | ok |
| g_metro_ticket | 161 | 64 | 40 % | 1.58 | ok |
| g_cufflinks | 161 | 63 | 39 % | 1.55 | ok |
| g_magnifier | 177 | 67 | 38 % | 1.50 | ok |
| g_red_ribbon | 188 | 71 | 38 % | 1.50 | ok |
| g_weighted_chip | 167 | 62 | 37 % | 1.48 | ok |
| g_croupier_wink | 85 | 30 | 35 % | 1.40 | ok |
| g_lipstick | 171 | 59 | 35 % | 1.37 | ok |
| g_ouroboros | 32 | 11 | 34 % | 1.37 | ok |
| g_monocle | 179 | 58 | 32 % | 1.29 | ok |
| g_rubber_ball | 184 | 59 | 32 % | 1.27 | ok |
| g_odd_duck | 153 | 49 | 32 % | 1.27 | ok |
| g_spare_change | 181 | 57 | 31 % | 1.25 | ok |
| g_half_moon | 169 | 53 | 31 % | 1.25 | ok |
| g_high_roller | 80 | 25 | 31 % | 1.24 | ok |
| g_marksman | 81 | 25 | 31 % | 1.23 | ok |
| g_patience | 162 | 50 | 31 % | 1.23 | ok |
| g_house_of_cards | 26 | 8 | 31 % | 1.22 | ok |
| g_piggy_bank | 166 | 51 | 31 % | 1.22 | ok |
| g_even_sock | 183 | 56 | 31 % | 1.22 | ok |
| g_secret_pocket | 183 | 56 | 31 % | 1.22 | ok |
| g_empty_pockets | 189 | 56 | 30 % | 1.18 | ok |
| g_coat_check | 170 | 50 | 29 % | 1.17 | ok |
| g_india_ink | 190 | 55 | 29 % | 1.15 | ok |
| g_geometer | 173 | 49 | 28 % | 1.13 | ok |
| g_slow_waltz | 163 | 46 | 28 % | 1.12 | ok |
| g_steel_toes | 168 | 47 | 28 % | 1.11 | ok |
| g_first_drink | 176 | 49 | 28 % | 1.11 | ok |
| g_umbrella | 183 | 50 | 27 % | 1.09 | ok |
| g_so_close | 180 | 49 | 27 % | 1.08 | ok |
| g_zero_hero | 175 | 46 | 26 % | 1.04 | ok |
| g_chandelier | 23 | 6 | 26 % | 1.04 | ok |
| g_tip_jar | 152 | 39 | 26 % | 1.02 | ok |
| g_neon_sign | 164 | 41 | 25 % | 0.99 | ok |
| g_perpetual_motion | 40 | 10 | 25 % | 0.99 | ok |
| g_folding_fan | 172 | 42 | 24 % | 0.97 | ok |
| g_egg_box | 164 | 40 | 24 % | 0.97 | ok |
| g_lucky_penny | 182 | 44 | 24 % | 0.96 | ok |
| g_neighbours | 59 | 14 | 24 % | 0.94 | ok |
| g_metropolis | 38 | 9 | 24 % | 0.94 | ok |
| g_lucky_seven | 170 | 40 | 24 % | 0.93 | ok |
| g_sommelier | 77 | 18 | 23 % | 0.93 | ok |
| g_brass_knuckles | 181 | 42 | 23 % | 0.92 | ok |
| g_doric_column | 183 | 42 | 23 % | 0.91 | ok |
| g_red_carpet | 76 | 17 | 22 % | 0.89 | ok |
| g_bellhop | 170 | 38 | 22 % | 0.89 | ok |
| g_baker | 175 | 39 | 22 % | 0.89 | ok |
| g_twin_dice | 72 | 16 | 22 % | 0.88 | ok |
| g_column_drummer | 172 | 38 | 22 % | 0.88 | ok |
| g_accordion | 73 | 16 | 22 % | 0.87 | ok |
| g_tramway | 168 | 35 | 21 % | 0.83 | ok |
| g_bow_tie | 87 | 18 | 21 % | 0.82 | ok |
| g_ruby_brooch | 166 | 34 | 20 % | 0.81 | ok |
| g_ladder | 69 | 14 | 20 % | 0.81 | ok |
| g_horseshoe | 185 | 36 | 19 % | 0.77 | ok |
| g_odd_pair | 166 | 31 | 19 % | 0.74 | ok |
| g_double_or_nothing | 66 | 12 | 18 % | 0.72 | ok |
| g_grandmaster | 28 | 5 | 18 % | 0.71 | ok |
| g_lodestone | 79 | 14 | 18 % | 0.70 | ok |
| g_zero_lover | 73 | 12 | 16 % | 0.65 | ok |
| g_ruby_slipper | 72 | 11 | 15 % | 0.61 | ok |
| g_revenge | 20 | 3 | 15 % | 0.60 | ok |
| g_twin_flame | 75 | 11 | 15 % | 0.58 | ok |
| g_gold_tooth | 90 | 13 | 14 % | 0.57 | ok |
| g_compass | 64 | 9 | 14 % | 0.56 | ok |
| g_last_call | 59 | 8 | 14 % | 0.54 | ok |
| g_monogram | 60 | 8 | 13 % | 0.53 | ok |
| g_blueprint | 72 | 9 | 12 % | 0.50 | ok |
| g_gardener | 80 | 10 | 12 % | 0.50 | ok |
| g_jeweller | 64 | 8 | 12 % | 0.50 | ok |
| g_ballroom | 32 | 4 | 12 % | 0.50 | ok |
| g_silver_tongue | 33 | 4 | 12 % | 0.48 | ok |
| g_grand_zero | 33 | 4 | 12 % | 0.48 | ok |
| g_window_shopper | 83 | 10 | 12 % | 0.48 | ok |
| g_forger | 69 | 8 | 12 % | 0.46 | ok |
| g_maestro | 26 | 3 | 12 % | 0.46 | ok |
| g_oracle | 36 | 4 | 11 % | 0.44 | ok |
| g_coupon_book | 63 | 7 | 11 % | 0.44 | ok |
| g_spiderweb | 81 | 9 | 11 % | 0.44 | ok |
| g_glass_heart | 73 | 8 | 11 % | 0.44 | ok |
| g_stockbroker | 65 | 7 | 11 % | 0.43 | ok |
| g_trapdoor | 68 | 7 | 10 % | 0.41 | ok |
| g_notary_stamp | 59 | 6 | 10 % | 0.40 | ok |
| g_glass_cutter | 69 | 7 | 10 % | 0.40 | ok |
| g_pickpocket | 69 | 7 | 10 % | 0.40 | ok |
| g_pearl_necklace | 79 | 8 | 10 % | 0.40 | ok |
| g_golden_rake | 31 | 3 | 10 % | 0.38 | ok |
| g_metro_map | 73 | 7 | 10 % | 0.38 | ok |
| g_cartographer | 77 | 7 | 9 % | 0.36 | ok |
| g_phoenix | 26 | 2 | 8 % | 0.31 | ok |
| g_landlord | 80 | 6 | 8 % | 0.30 | ok |
| g_alchemist | 69 | 5 | 7 % | 0.29 | ok |
| g_rainmaker | 71 | 5 | 7 % | 0.28 | ok |
| g_gilded_cage | 59 | 4 | 7 % | 0.27 | ok |
| g_fortune_teller | 90 | 6 | 7 % | 0.26 | ok |
| g_seven_sisters | 75 | 5 | 7 % | 0.26 | ok |
| g_minimalist | 75 | 5 | 7 % | 0.26 | ok |
| g_night_owl | 66 | 4 | 6 % | 0.24 | délaissé |
| g_compound | 66 | 4 | 6 % | 0.24 | délaissé |
| g_bishop | 69 | 4 | 6 % | 0.23 | délaissé |
| g_insurance | 71 | 4 | 6 % | 0.22 | délaissé |
| g_bank_vault | 38 | 2 | 5 % | 0.21 | délaissé |
| g_zero_tithe | 71 | 3 | 4 % | 0.17 | délaissé |
| g_tram_conductor | 78 | 3 | 4 % | 0.15 | délaissé |
| g_crown_jewels | 38 | 1 | 3 % | 0.10 | délaissé |
| g_overtime | 77 | 2 | 3 % | 0.10 | délaissé |
| g_infinite_chip | 40 | 1 | 2 % | 0.10 | délaissé |
| g_dealer_hand | 27 | 0 | 0 % | 0.00 | délaissé |
| g_philosophers_stone | 36 | 0 | 0 % | 0.00 | délaissé |
