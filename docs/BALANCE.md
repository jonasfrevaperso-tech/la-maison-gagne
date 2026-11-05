# Rapport d'équilibrage (généré par `scripts/sim/sim_main.gd`)

Bot : **greedy** · runs : 500 · risque 0 · durée de simulation 43223 ms

- Taux de victoire : **24.2 %** (objectif 2.0 : glouton ≈ 20–25 %, hasard ≤ 3 %, cf. D-085)
- Tours par échéance réglée (palier ≥ 3, médiane) : 3.0 (objectif 3–4)
- Palier moyen atteint : 5.29 / 8
- Durée estimée d'un run : 21.6 min (objectif 35–50 min pour un run gagnant)
- Grigris dominants : 16 · délaissés : 32 (sur 179 mesurés)
- Progression moyenne de la dette au moment de l'échec : 68 %

Limites : les bots visent mieux ou moins bien qu'un humain (erreur de ±1 case dans 35 % des lancers) et le bot « synergy »
estime chaque offre sur 12 tours simulés, ce qui sous-évalue les grigris à croissance lente (ex. Ouroboros, Tirelire).
Il compare la valeur au prix (les légendaires à 10 $ en pâtissent), ne joue ni transversales ni sixains, et ne voit
ni la valeur d'un tour supplémentaire ni celle des améliorations économiques : ces « délaissés » relèvent du bot.

## Courbe de survie par palier

| Palier | Runs l'atteignant |
|---|---|
| 1 | 100.0 % |
| 2 | 100.0 % |
| 3 | 97.8 % |
| 4 | 77.6 % |
| 5 | 53.4 % |
| 6 | 39.6 % |
| 7 | 32.2 % |
| 8 | 28.0 % |
| Victoire | 24.2 % |

## Par personnage

| Personnage | Runs | Victoires | Palier moyen |
|---|---|---|---|
| lea | 100 | 38.0 % | 5.99 |
| vic | 100 | 24.0 % | 5.27 |
| odile | 100 | 23.0 % | 5.09 |
| barnabe | 100 | 16.0 % | 4.83 |
| marthe | 100 | 20.0 % | 5.25 |

## Grigris — taux de choix quand proposé (moyenne 20.3 %, 179 grigris proposés ≥ 8 fois)

Dominant : > 2× la moyenne. Délaissé : < 0,25× la moyenne. Le taux brut dépend de la rareté, d'où cette mesure conditionnelle.

| Grigri | Proposé | Choisi | Taux | × moyenne | Statut |
|---|---|---|---|---|---|
| g_piggy_bank | 188 | 142 | 76 % | 3.71 | dominant |
| g_chain_reaction | 109 | 72 | 66 % | 3.25 | dominant |
| g_auctioneer | 85 | 49 | 58 % | 2.83 | dominant |
| g_salon_echo | 86 | 47 | 55 % | 2.69 | dominant |
| g_insomniac | 96 | 49 | 51 % | 2.51 | dominant |
| g_patience | 157 | 80 | 51 % | 2.50 | dominant |
| g_lucette_photo | 62 | 31 | 50 % | 2.46 | dominant |
| g_last_call | 93 | 46 | 49 % | 2.43 | dominant |
| g_sommelier | 113 | 55 | 49 % | 2.39 | dominant |
| g_hourglass | 85 | 40 | 47 % | 2.31 | dominant |
| g_red_carpet | 83 | 38 | 46 % | 2.25 | dominant |
| g_ladder | 71 | 32 | 45 % | 2.22 | dominant |
| g_window_shopper | 70 | 31 | 44 % | 2.18 | dominant |
| g_ledger | 92 | 38 | 41 % | 2.03 | dominant |
| g_bishop | 68 | 28 | 41 % | 2.02 | dominant |
| g_ash_collector | 76 | 31 | 41 % | 2.00 | dominant |
| g_neon_sign | 230 | 91 | 40 % | 1.94 | ok |
| g_paper_crown | 216 | 83 | 38 % | 1.89 | ok |
| g_night_owl | 71 | 27 | 38 % | 1.87 | ok |
| g_geometer | 188 | 71 | 38 % | 1.86 | ok |
| g_cracked_chip | 261 | 98 | 38 % | 1.85 | ok |
| g_baker | 190 | 71 | 37 % | 1.84 | ok |
| g_outsider | 201 | 75 | 37 % | 1.83 | ok |
| g_tram_conductor | 70 | 26 | 37 % | 1.83 | ok |
| g_odd_pair | 191 | 70 | 37 % | 1.80 | ok |
| g_slow_waltz | 229 | 82 | 36 % | 1.76 | ok |
| g_column_drummer | 196 | 70 | 36 % | 1.76 | ok |
| g_tram_line | 71 | 25 | 35 % | 1.73 | ok |
| g_empty_pockets | 228 | 80 | 35 % | 1.72 | ok |
| g_miser | 160 | 56 | 35 % | 1.72 | ok |
| g_bell_choir | 69 | 24 | 35 % | 1.71 | ok |
| g_blueprint | 104 | 36 | 35 % | 1.70 | ok |
| g_first_drink | 240 | 82 | 34 % | 1.68 | ok |
| g_glass_heart | 71 | 24 | 34 % | 1.66 | ok |
| g_compound_interest | 69 | 23 | 33 % | 1.64 | ok |
| g_night_glasses | 202 | 67 | 33 % | 1.63 | ok |
| g_marathon | 228 | 75 | 33 % | 1.62 | ok |
| g_marksman | 73 | 24 | 33 % | 1.62 | ok |
| g_pendulum | 70 | 23 | 33 % | 1.61 | ok |
| g_cracked_monocle | 67 | 22 | 33 % | 1.61 | ok |
| g_stockbroker | 64 | 21 | 33 % | 1.61 | ok |
| g_accordion | 49 | 16 | 33 % | 1.60 | ok |
| g_house_rules | 258 | 83 | 32 % | 1.58 | ok |
| g_monogram | 78 | 25 | 32 % | 1.58 | ok |
| g_high_roller | 50 | 16 | 32 % | 1.57 | ok |
| g_horseshoe | 176 | 56 | 32 % | 1.56 | ok |
| g_matchbox | 242 | 77 | 32 % | 1.56 | ok |
| g_gin_flask | 107 | 34 | 32 % | 1.56 | ok |
| g_twin_flame | 73 | 23 | 32 % | 1.55 | ok |
| g_straight_razor | 155 | 48 | 31 % | 1.52 | ok |
| g_shoe_shine | 159 | 49 | 31 % | 1.51 | ok |
| g_gilded_cage | 62 | 19 | 31 % | 1.51 | ok |
| g_fortune_cookie | 66 | 20 | 30 % | 1.49 | ok |
| g_low_lamp | 217 | 65 | 30 % | 1.47 | ok |
| g_neighbours | 65 | 19 | 29 % | 1.44 | ok |
| g_high_heels | 191 | 55 | 29 % | 1.42 | ok |
| g_quartet | 176 | 50 | 28 % | 1.40 | ok |
| g_croupier_wink | 74 | 21 | 28 % | 1.39 | ok |
| g_twin_dice | 60 | 17 | 28 % | 1.39 | ok |
| g_minimalist | 68 | 19 | 28 % | 1.37 | ok |
| g_house_of_cards | 43 | 12 | 28 % | 1.37 | ok |
| g_window_dresser | 73 | 20 | 27 % | 1.35 | ok |
| g_double_or_nothing | 64 | 17 | 27 % | 1.31 | ok |
| g_velvet_glove | 192 | 50 | 26 % | 1.28 | ok |
| g_metro_map | 74 | 19 | 26 % | 1.26 | ok |
| g_boss_cigar | 272 | 69 | 25 % | 1.25 | ok |
| g_bow_tie | 72 | 18 | 25 % | 1.23 | ok |
| g_red_ribbon | 194 | 48 | 25 % | 1.22 | ok |
| g_zero_lover | 54 | 13 | 24 % | 1.18 | ok |
| g_ruby_slipper | 84 | 20 | 24 % | 1.17 | ok |
| g_scarlet_streak | 191 | 44 | 23 % | 1.13 | ok |
| g_ashtray | 155 | 35 | 23 % | 1.11 | ok |
| g_steel_toes | 173 | 38 | 22 % | 1.08 | ok |
| g_tramway | 166 | 36 | 22 % | 1.07 | ok |
| g_spare_change | 157 | 34 | 22 % | 1.06 | ok |
| g_cufflinks | 186 | 40 | 22 % | 1.06 | ok |
| g_sugar_cube | 173 | 37 | 21 % | 1.05 | ok |
| g_hinge | 197 | 42 | 21 % | 1.05 | ok |
| g_bookie | 71 | 15 | 21 % | 1.04 | ok |
| g_double_espresso | 265 | 55 | 21 % | 1.02 | ok |
| g_black_cat | 181 | 37 | 20 % | 1.00 | ok |
| g_egg_box | 194 | 39 | 20 % | 0.99 | ok |
| g_loaded_die | 180 | 36 | 20 % | 0.98 | ok |
| g_funhouse_mirror | 51 | 10 | 20 % | 0.96 | ok |
| g_so_close | 182 | 34 | 19 % | 0.92 | ok |
| g_green_visor | 188 | 35 | 19 % | 0.92 | ok |
| g_umbrella | 172 | 32 | 19 % | 0.91 | ok |
| g_brass_knuckles | 186 | 34 | 18 % | 0.90 | ok |
| g_metropolis | 45 | 8 | 18 % | 0.87 | ok |
| g_grandmaster | 45 | 8 | 18 % | 0.87 | ok |
| g_glass_cutter | 68 | 12 | 18 % | 0.87 | ok |
| g_lucky_seven | 153 | 27 | 18 % | 0.87 | ok |
| g_ouroboros | 47 | 8 | 17 % | 0.84 | ok |
| g_dice_cup | 151 | 25 | 17 % | 0.81 | ok |
| g_six_pack | 178 | 29 | 16 % | 0.80 | ok |
| g_city_block | 86 | 14 | 16 % | 0.80 | ok |
| g_wax_stamp | 176 | 28 | 16 % | 0.78 | ok |
| g_weighted_chip | 185 | 29 | 16 % | 0.77 | ok |
| g_india_ink | 163 | 25 | 15 % | 0.75 | ok |
| g_seven_sisters | 68 | 10 | 15 % | 0.72 | ok |
| g_pearl_necklace | 75 | 11 | 15 % | 0.72 | ok |
| g_even_sock | 225 | 33 | 15 % | 0.72 | ok |
| g_ruby_brooch | 185 | 27 | 15 % | 0.72 | ok |
| g_lipstick | 193 | 28 | 15 % | 0.71 | ok |
| g_doric_column | 200 | 29 | 14 % | 0.71 | ok |
| g_half_moon | 213 | 30 | 14 % | 0.69 | ok |
| g_folding_fan | 181 | 25 | 14 % | 0.68 | ok |
| g_metronome | 97 | 13 | 13 % | 0.66 | ok |
| g_gold_tooth | 62 | 8 | 13 % | 0.63 | ok |
| g_house_key | 47 | 6 | 13 % | 0.63 | ok |
| g_lottery_ticket | 174 | 22 | 13 % | 0.62 | ok |
| g_coat_check | 169 | 21 | 12 % | 0.61 | ok |
| g_billiard_chalk | 162 | 20 | 12 % | 0.61 | ok |
| g_insurance | 81 | 10 | 12 % | 0.61 | ok |
| g_magnet_shoes | 178 | 21 | 12 % | 0.58 | ok |
| g_rubber_ball | 162 | 19 | 12 % | 0.58 | ok |
| g_odd_duck | 197 | 23 | 12 % | 0.57 | ok |
| g_double_down | 52 | 6 | 12 % | 0.57 | ok |
| g_red_tape | 179 | 20 | 11 % | 0.55 | ok |
| g_cigarette_holder | 200 | 22 | 11 % | 0.54 | ok |
| g_bellhop | 183 | 20 | 11 % | 0.54 | ok |
| g_after_hours | 103 | 11 | 11 % | 0.52 | ok |
| g_dying_neon | 191 | 20 | 10 % | 0.51 | ok |
| g_cartographer | 67 | 7 | 10 % | 0.51 | ok |
| g_jackpot_tokens | 58 | 6 | 10 % | 0.51 | ok |
| g_tarot_reader | 165 | 17 | 10 % | 0.51 | ok |
| g_seamstress | 78 | 8 | 10 % | 0.50 | ok |
| g_eternity_clock | 49 | 5 | 10 % | 0.50 | ok |
| g_metro_ticket | 185 | 18 | 10 % | 0.48 | ok |
| g_overtime | 96 | 9 | 9 % | 0.46 | ok |
| g_perpetual_motion | 22 | 2 | 9 % | 0.45 | ok |
| g_zero_hero | 156 | 14 | 9 % | 0.44 | ok |
| g_magnifier | 182 | 16 | 9 % | 0.43 | ok |
| g_revenge | 24 | 2 | 8 % | 0.41 | ok |
| g_pocket_slot | 165 | 13 | 8 % | 0.39 | ok |
| g_pickpocket | 79 | 6 | 8 % | 0.37 | ok |
| g_golden_rake | 27 | 2 | 7 % | 0.36 | ok |
| g_compound | 87 | 6 | 7 % | 0.34 | ok |
| g_secret_pocket | 180 | 12 | 7 % | 0.33 | ok |
| g_rainmaker | 76 | 5 | 7 % | 0.32 | ok |
| g_silver_tongue | 31 | 2 | 6 % | 0.32 | ok |
| g_chandelier | 32 | 2 | 6 % | 0.31 | ok |
| g_glass_blower | 170 | 10 | 6 % | 0.29 | ok |
| g_gardener | 69 | 4 | 6 % | 0.28 | ok |
| g_monocle | 177 | 10 | 6 % | 0.28 | ok |
| g_undertaker | 160 | 9 | 6 % | 0.28 | ok |
| g_coin_bucket | 184 | 10 | 5 % | 0.27 | ok |
| g_notary_ring | 68 | 3 | 4 % | 0.22 | délaissé |
| g_census | 69 | 3 | 4 % | 0.21 | délaissé |
| g_tip_jar | 162 | 7 | 4 % | 0.21 | délaissé |
| g_notary_stamp | 71 | 3 | 4 % | 0.21 | délaissé |
| g_crown_jewels | 25 | 1 | 4 % | 0.20 | délaissé |
| g_phoenix | 26 | 1 | 4 % | 0.19 | délaissé |
| g_spiderweb | 80 | 3 | 4 % | 0.18 | délaissé |
| g_groom_bell | 223 | 7 | 3 % | 0.15 | délaissé |
| g_archivist | 32 | 1 | 3 % | 0.15 | délaissé |
| g_zero_tithe | 65 | 2 | 3 % | 0.15 | délaissé |
| g_scrap_dealer | 67 | 2 | 3 % | 0.15 | délaissé |
| g_bank_vault | 36 | 1 | 3 % | 0.14 | délaissé |
| g_alchemist | 74 | 2 | 3 % | 0.13 | délaissé |
| g_compass | 76 | 2 | 3 % | 0.13 | délaissé |
| g_landlord | 80 | 2 | 2 % | 0.12 | délaissé |
| g_maestro | 41 | 1 | 2 % | 0.12 | délaissé |
| g_lucky_penny | 219 | 5 | 2 % | 0.11 | délaissé |
| g_forger | 69 | 1 | 1 % | 0.07 | délaissé |
| g_fortune_teller | 71 | 1 | 1 % | 0.07 | délaissé |
| g_sealing_wax | 73 | 1 | 1 % | 0.07 | délaissé |
| g_lodestone | 69 | 0 | 0 % | 0.00 | délaissé |
| g_grand_zero | 27 | 0 | 0 % | 0.00 | délaissé |
| g_philosophers_stone | 25 | 0 | 0 % | 0.00 | délaissé |
| g_twin_city | 32 | 0 | 0 % | 0.00 | délaissé |
| g_ballroom | 31 | 0 | 0 % | 0.00 | délaissé |
| g_dealer_hand | 27 | 0 | 0 % | 0.00 | délaissé |
| g_trapdoor | 72 | 0 | 0 % | 0.00 | délaissé |
| g_coupon_book | 69 | 0 | 0 % | 0.00 | délaissé |
| g_deck_of_fate | 30 | 0 | 0 % | 0.00 | délaissé |
| g_oracle | 31 | 0 | 0 % | 0.00 | délaissé |
| g_infinite_chip | 29 | 0 | 0 % | 0.00 | délaissé |
| g_jeweller | 62 | 0 | 0 % | 0.00 | délaissé |
