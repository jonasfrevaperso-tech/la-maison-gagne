# Rapport d'équilibrage (généré par `scripts/sim/sim_main.gd`)

Bot : **greedy** · runs : 500 · risque 0 · durée de simulation 40084 ms

- Taux de victoire : **15.0 %** (objectif 2.0 : glouton ≈ 15–25 %, hasard ≤ 3 %, cf. D-085, D-086)
- Tours par échéance réglée (palier ≥ 3, médiane) : 3.0 (objectif 3–4)
- Palier moyen atteint : 4.94 / 8
- Durée estimée d'un run : 20.3 min (objectif 35–50 min pour un run gagnant)
- Grigris dominants : 30 · délaissés : 42 (sur 179 mesurés)
- Progression moyenne de la dette au moment de l'échec : 65 %

Limites : les bots visent mieux ou moins bien qu'un humain (erreur de ±1 case dans 35 % des lancers) et le bot « synergy »
estime chaque offre sur 12 tours simulés, ce qui sous-évalue les grigris à croissance lente (ex. Ouroboros, Tirelire).
Il compare la valeur au prix (les légendaires à 10 $ en pâtissent), ne joue ni transversales ni sixains, et ne voit
ni la valeur d'un tour supplémentaire ni celle des améliorations économiques : ces « délaissés » relèvent du bot.

## Courbe de survie par palier

| Palier | Runs l'atteignant |
|---|---|
| 1 | 100.0 % |
| 2 | 99.8 % |
| 3 | 95.6 % |
| 4 | 73.6 % |
| 5 | 49.2 % |
| 6 | 33.4 % |
| 7 | 24.2 % |
| 8 | 18.4 % |
| Victoire | 15.0 % |

## Par personnage

| Personnage | Runs | Victoires | Palier moyen |
|---|---|---|---|
| lea | 100 | 15.0 % | 4.97 |
| vic | 100 | 11.0 % | 5.00 |
| odile | 100 | 17.0 % | 4.99 |
| barnabe | 100 | 14.0 % | 4.69 |
| marthe | 100 | 18.0 % | 5.06 |

## Grigris — taux de choix quand proposé (moyenne 22.6 %, 179 grigris proposés ≥ 8 fois)

Dominant : > 2× la moyenne. Délaissé : < 0,25× la moyenne. Le taux brut dépend de la rareté, d'où cette mesure conditionnelle.

| Grigri | Proposé | Choisi | Taux | × moyenne | Statut |
|---|---|---|---|---|---|
| g_patience | 143 | 105 | 73 % | 3.24 | dominant |
| g_lucette_photo | 67 | 49 | 73 % | 3.23 | dominant |
| g_piggy_bank | 146 | 105 | 72 % | 3.18 | dominant |
| g_auctioneer | 73 | 52 | 71 % | 3.15 | dominant |
| g_chain_reaction | 71 | 48 | 68 % | 2.99 | dominant |
| g_stockbroker | 83 | 56 | 67 % | 2.98 | dominant |
| g_window_shopper | 68 | 44 | 65 % | 2.86 | dominant |
| g_pendulum | 71 | 44 | 62 % | 2.74 | dominant |
| g_salon_echo | 56 | 33 | 59 % | 2.60 | dominant |
| g_double_or_nothing | 60 | 35 | 58 % | 2.58 | dominant |
| g_bishop | 72 | 40 | 56 % | 2.45 | dominant |
| g_tram_conductor | 68 | 37 | 54 % | 2.40 | dominant |
| g_monogram | 66 | 35 | 53 % | 2.34 | dominant |
| g_minimalist | 66 | 34 | 52 % | 2.28 | dominant |
| g_neighbours | 59 | 30 | 51 % | 2.25 | dominant |
| g_bell_choir | 71 | 35 | 49 % | 2.18 | dominant |
| g_geometer | 188 | 92 | 49 % | 2.16 | dominant |
| g_window_dresser | 70 | 34 | 49 % | 2.15 | dominant |
| g_last_call | 66 | 32 | 48 % | 2.14 | dominant |
| g_cracked_monocle | 62 | 30 | 48 % | 2.14 | dominant |
| g_accordion | 58 | 28 | 48 % | 2.13 | dominant |
| g_sommelier | 82 | 39 | 48 % | 2.10 | dominant |
| g_seven_sisters | 72 | 34 | 47 % | 2.09 | dominant |
| g_tram_line | 53 | 25 | 47 % | 2.08 | dominant |
| g_metro_map | 70 | 33 | 47 % | 2.08 | dominant |
| g_ash_collector | 68 | 32 | 47 % | 2.08 | dominant |
| g_glass_heart | 66 | 31 | 47 % | 2.07 | dominant |
| g_night_owl | 71 | 33 | 46 % | 2.05 | dominant |
| g_red_carpet | 76 | 35 | 46 % | 2.03 | dominant |
| g_marksman | 72 | 33 | 46 % | 2.02 | dominant |
| g_ladder | 93 | 42 | 45 % | 1.99 | ok |
| g_insomniac | 72 | 32 | 44 % | 1.96 | ok |
| g_fortune_cookie | 78 | 34 | 44 % | 1.93 | ok |
| g_glass_cutter | 72 | 31 | 43 % | 1.90 | ok |
| g_bow_tie | 63 | 27 | 43 % | 1.89 | ok |
| g_ledger | 73 | 31 | 42 % | 1.88 | ok |
| g_odd_pair | 181 | 76 | 42 % | 1.85 | ok |
| g_miser | 151 | 63 | 42 % | 1.84 | ok |
| g_gilded_cage | 53 | 22 | 42 % | 1.83 | ok |
| g_hourglass | 75 | 31 | 41 % | 1.83 | ok |
| g_funhouse_mirror | 74 | 30 | 41 % | 1.79 | ok |
| g_baker | 161 | 64 | 40 % | 1.76 | ok |
| g_zero_lover | 56 | 22 | 39 % | 1.74 | ok |
| g_outsider | 180 | 70 | 39 % | 1.72 | ok |
| g_night_glasses | 154 | 59 | 38 % | 1.69 | ok |
| g_twin_flame | 72 | 27 | 38 % | 1.66 | ok |
| g_ruby_slipper | 48 | 18 | 38 % | 1.66 | ok |
| g_hinge | 180 | 67 | 37 % | 1.64 | ok |
| g_high_roller | 65 | 24 | 37 % | 1.63 | ok |
| g_shoe_shine | 168 | 62 | 37 % | 1.63 | ok |
| g_column_drummer | 179 | 66 | 37 % | 1.63 | ok |
| g_twin_dice | 69 | 24 | 35 % | 1.54 | ok |
| g_straight_razor | 188 | 65 | 35 % | 1.53 | ok |
| g_bookie | 85 | 29 | 34 % | 1.51 | ok |
| g_low_lamp | 159 | 54 | 34 % | 1.50 | ok |
| g_quartet | 163 | 55 | 34 % | 1.49 | ok |
| g_compound_interest | 73 | 24 | 33 % | 1.45 | ok |
| g_high_heels | 178 | 56 | 31 % | 1.39 | ok |
| g_neon_sign | 182 | 56 | 31 % | 1.36 | ok |
| g_house_rules | 170 | 52 | 31 % | 1.35 | ok |
| g_croupier_wink | 58 | 17 | 29 % | 1.29 | ok |
| g_horseshoe | 173 | 49 | 28 % | 1.25 | ok |
| g_cracked_chip | 179 | 50 | 28 % | 1.23 | ok |
| g_ashtray | 165 | 46 | 28 % | 1.23 | ok |
| g_lucky_seven | 199 | 55 | 28 % | 1.22 | ok |
| g_first_drink | 215 | 57 | 27 % | 1.17 | ok |
| g_red_ribbon | 181 | 46 | 25 % | 1.12 | ok |
| g_so_close | 163 | 41 | 25 % | 1.11 | ok |
| g_paper_crown | 152 | 37 | 24 % | 1.08 | ok |
| g_loaded_die | 185 | 45 | 24 % | 1.07 | ok |
| g_black_cat | 166 | 39 | 23 % | 1.04 | ok |
| g_sugar_cube | 162 | 37 | 23 % | 1.01 | ok |
| g_green_visor | 191 | 42 | 22 % | 0.97 | ok |
| g_cufflinks | 172 | 36 | 21 % | 0.92 | ok |
| g_egg_box | 192 | 39 | 20 % | 0.90 | ok |
| g_metronome | 79 | 16 | 20 % | 0.89 | ok |
| g_marathon | 174 | 35 | 20 % | 0.89 | ok |
| g_slow_waltz | 201 | 40 | 20 % | 0.88 | ok |
| g_spare_change | 171 | 34 | 20 % | 0.88 | ok |
| g_city_block | 66 | 13 | 20 % | 0.87 | ok |
| g_brass_knuckles | 179 | 34 | 19 % | 0.84 | ok |
| g_matchbox | 153 | 29 | 19 % | 0.84 | ok |
| g_phoenix | 28 | 5 | 18 % | 0.79 | ok |
| g_ruby_brooch | 180 | 32 | 18 % | 0.79 | ok |
| g_golden_rake | 34 | 6 | 18 % | 0.78 | ok |
| g_even_sock | 182 | 32 | 18 % | 0.78 | ok |
| g_ouroboros | 35 | 6 | 17 % | 0.76 | ok |
| g_double_down | 37 | 6 | 16 % | 0.72 | ok |
| g_silver_tongue | 31 | 5 | 16 % | 0.71 | ok |
| g_dice_cup | 168 | 27 | 16 % | 0.71 | ok |
| g_magnifier | 201 | 32 | 16 % | 0.70 | ok |
| g_six_pack | 158 | 25 | 16 % | 0.70 | ok |
| g_wax_stamp | 155 | 24 | 15 % | 0.68 | ok |
| g_blueprint | 85 | 13 | 15 % | 0.68 | ok |
| g_half_moon | 193 | 29 | 15 % | 0.66 | ok |
| g_magnet_shoes | 165 | 24 | 15 % | 0.64 | ok |
| g_steel_toes | 153 | 22 | 14 % | 0.64 | ok |
| g_doric_column | 195 | 28 | 14 % | 0.63 | ok |
| g_rubber_ball | 178 | 25 | 14 % | 0.62 | ok |
| g_empty_pockets | 176 | 24 | 14 % | 0.60 | ok |
| g_gin_flask | 81 | 11 | 14 % | 0.60 | ok |
| g_billiard_chalk | 186 | 25 | 13 % | 0.59 | ok |
| g_odd_duck | 189 | 25 | 13 % | 0.58 | ok |
| g_scarlet_streak | 187 | 24 | 13 % | 0.57 | ok |
| g_lipstick | 198 | 25 | 13 % | 0.56 | ok |
| g_census | 64 | 8 | 12 % | 0.55 | ok |
| g_tramway | 161 | 20 | 12 % | 0.55 | ok |
| g_weighted_chip | 162 | 20 | 12 % | 0.55 | ok |
| g_coat_check | 172 | 21 | 12 % | 0.54 | ok |
| g_lottery_ticket | 201 | 24 | 12 % | 0.53 | ok |
| g_umbrella | 153 | 18 | 12 % | 0.52 | ok |
| g_crown_jewels | 26 | 3 | 12 % | 0.51 | ok |
| g_folding_fan | 157 | 18 | 11 % | 0.51 | ok |
| g_notary_ring | 70 | 8 | 11 % | 0.50 | ok |
| g_seamstress | 80 | 9 | 11 % | 0.50 | ok |
| g_insurance | 77 | 8 | 10 % | 0.46 | ok |
| g_boss_cigar | 158 | 16 | 10 % | 0.45 | ok |
| g_india_ink | 188 | 19 | 10 % | 0.45 | ok |
| g_cigarette_holder | 160 | 16 | 10 % | 0.44 | ok |
| g_double_espresso | 173 | 16 | 9 % | 0.41 | ok |
| g_eternity_clock | 33 | 3 | 9 % | 0.40 | ok |
| g_maestro | 33 | 3 | 9 % | 0.40 | ok |
| g_gardener | 77 | 7 | 9 % | 0.40 | ok |
| g_jackpot_tokens | 68 | 6 | 9 % | 0.39 | ok |
| g_compound | 71 | 6 | 8 % | 0.37 | ok |
| g_metro_ticket | 190 | 16 | 8 % | 0.37 | ok |
| g_pearl_necklace | 60 | 5 | 8 % | 0.37 | ok |
| g_bellhop | 173 | 14 | 8 % | 0.36 | ok |
| g_rainmaker | 76 | 6 | 8 % | 0.35 | ok |
| g_cartographer | 52 | 4 | 8 % | 0.34 | ok |
| g_monocle | 171 | 13 | 8 % | 0.34 | ok |
| g_velvet_glove | 146 | 11 | 8 % | 0.33 | ok |
| g_spiderweb | 71 | 5 | 7 % | 0.31 | ok |
| g_tip_jar | 164 | 11 | 7 % | 0.30 | ok |
| g_red_tape | 152 | 9 | 6 % | 0.26 | ok |
| g_gold_tooth | 68 | 4 | 6 % | 0.26 | ok |
| g_undertaker | 138 | 8 | 6 % | 0.26 | ok |
| g_pocket_slot | 200 | 11 | 6 % | 0.24 | délaissé |
| g_dying_neon | 182 | 10 | 5 % | 0.24 | délaissé |
| g_chandelier | 37 | 2 | 5 % | 0.24 | délaissé |
| g_zero_tithe | 77 | 4 | 5 % | 0.23 | délaissé |
| g_lucky_penny | 178 | 9 | 5 % | 0.22 | délaissé |
| g_zero_hero | 182 | 9 | 5 % | 0.22 | délaissé |
| g_secret_pocket | 165 | 8 | 5 % | 0.21 | délaissé |
| g_archivist | 43 | 2 | 5 % | 0.21 | délaissé |
| g_perpetual_motion | 22 | 1 | 5 % | 0.20 | délaissé |
| g_after_hours | 70 | 3 | 4 % | 0.19 | délaissé |
| g_house_of_cards | 24 | 1 | 4 % | 0.18 | délaissé |
| g_landlord | 73 | 3 | 4 % | 0.18 | délaissé |
| g_house_key | 27 | 1 | 4 % | 0.16 | délaissé |
| g_coin_bucket | 181 | 6 | 3 % | 0.15 | délaissé |
| g_tarot_reader | 185 | 6 | 3 % | 0.14 | délaissé |
| g_twin_city | 32 | 1 | 3 % | 0.14 | délaissé |
| g_glass_blower | 170 | 5 | 3 % | 0.13 | délaissé |
| g_groom_bell | 221 | 6 | 3 % | 0.12 | délaissé |
| g_compass | 74 | 2 | 3 % | 0.12 | délaissé |
| g_coupon_book | 78 | 2 | 3 % | 0.11 | délaissé |
| g_pickpocket | 62 | 1 | 2 % | 0.07 | délaissé |
| g_sealing_wax | 62 | 1 | 2 % | 0.07 | délaissé |
| g_alchemist | 67 | 1 | 1 % | 0.07 | délaissé |
| g_notary_stamp | 69 | 1 | 1 % | 0.06 | délaissé |
| g_trapdoor | 72 | 1 | 1 % | 0.06 | délaissé |
| g_forger | 74 | 1 | 1 % | 0.06 | délaissé |
| g_scrap_dealer | 80 | 1 | 1 % | 0.06 | délaissé |
| g_lodestone | 84 | 1 | 1 % | 0.05 | délaissé |
| g_overtime | 93 | 1 | 1 % | 0.05 | délaissé |
| g_bank_vault | 35 | 0 | 0 % | 0.00 | délaissé |
| g_oracle | 35 | 0 | 0 % | 0.00 | délaissé |
| g_infinite_chip | 26 | 0 | 0 % | 0.00 | délaissé |
| g_metropolis | 25 | 0 | 0 % | 0.00 | délaissé |
| g_dealer_hand | 30 | 0 | 0 % | 0.00 | délaissé |
| g_deck_of_fate | 30 | 0 | 0 % | 0.00 | délaissé |
| g_grandmaster | 28 | 0 | 0 % | 0.00 | délaissé |
| g_revenge | 30 | 0 | 0 % | 0.00 | délaissé |
| g_ballroom | 32 | 0 | 0 % | 0.00 | délaissé |
| g_philosophers_stone | 33 | 0 | 0 % | 0.00 | délaissé |
| g_jeweller | 65 | 0 | 0 % | 0.00 | délaissé |
| g_grand_zero | 28 | 0 | 0 % | 0.00 | délaissé |
| g_fortune_teller | 72 | 0 | 0 % | 0.00 | délaissé |
