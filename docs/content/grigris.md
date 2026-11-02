# Grigris (187)

Répartition : common 75, rare 71, legendary 24, cursed 17

| id | Nom (FR / EN) | Description | Rareté / coût | Tags | Effets | Ambiance |
|---|---|---|---|---|---|---|
| g_ashtray | Cendrier / Ashtray | +10 Jetons par pari perdu. | common | bets, chips, safety | on_bet_lose→add_chips | Plein des cendres de paris consumés. |
| g_baker | Boulanger / Baker | +4 Mult par douzaine gagnante. | common | bets, dozen, mult | on_bet_win→add_mult | Treize à la douzaine, sauf ici. |
| g_bellhop | Pourboire du groom / Bellhop's Tip | +2 $ au dernier tour d'une échéance. | common | economy, spins | on_round_end→add_money | Il porte vos valises vers la sortie. Il n'y en a pas. |
| g_billiard_chalk | Craie de billard / Billiard Chalk | +1,5 Mult par point de Précision. | common | precision, mult | on_score_calc→add_mult | Mauvais jeu, bon geste. |
| g_black_cat | Chat noir / Black Cat | +4 Mult si la bille tombe sur du noir. | common | color, mult | on_score_calc→add_mult | Il a traversé ta route. Puis ta roue. |
| g_boss_cigar | Cigare du Patron / Boss's Cigar | +80 Jetons, −8 à chaque tour. Se consume à 0. | common | chips, decay | on_acquire→counter_set; on_score_calc→add_chips; on_round_end→counter_add; on_round_end→self_destroy | Il était encore chaud dans le cendrier. |
| g_brass_knuckles | Poing américain / Brass Knuckles | +8 Mult si 3 paris ou plus gagnent. | common | bets, mult | on_score_calc→add_mult | Pour les négociations difficiles. |
| g_cigarette_holder | Fume-cigarette / Cigarette Holder | +20 Jetons par pari gagnant. Des volutes de fumée voilent la table pendant les lancers. | common | chips, curse_fx | on_bet_win→add_chips | Élégant, mortel, très années trente. |
| g_coat_check | Vestiaire / Coat Check | +3 Mult par carte Fortune détenue. | common | fortune, mult | on_score_calc→add_mult | Ticket 37. On ne vous rendra rien. |
| g_column_drummer | Batteur de colonne / Column Drummer | +4 Mult par colonne gagnante. | common | bets, column, mult | on_bet_win→add_mult | Il bat la mesure sur la colonne de gauche. |
| g_cracked_chip | Jeton fêlé / Cracked Chip | +6 Mult. 1 chance sur 10 de se briser à chaque tour. | common | mult, destroy | on_score_calc→add_mult; on_round_end→self_destroy | Il a déjà survécu à une chute. De justesse. |
| g_cufflinks | Boutons de manchette / Cufflinks | +3 Mult si la case touchée est une case Standard. | common | pockets, mult | on_score_calc→add_mult | L'élégance, c'est la simplicité. Et le crédit. |
| g_dice_cup | Cornet à dés / Dice Cup | 1 chance sur 2 : +4 Mult. | common | chance, mult | on_score_calc→add_mult | Secouez. Priez. Renversez. |
| g_doric_column | Colonne dorique / Doric Column | +60 Jetons par colonne gagnante. | common | bets, column, chips | on_bet_win→add_chips | Volée dans le hall. Personne n'a remarqué. |
| g_double_espresso | Double serré / Double Espresso | +20 Jetons à chaque tour. Les mains (et l'écran) tremblent pendant les lancers. | common | chips, curse_fx | on_score_calc→add_chips | Le quatrième de la soirée. Ou le cinquième. |
| g_dying_neon | Néon agonisant / Dying Neon | +1 $ quand la bille tombe sur du rouge. Le néon grésille et la salle clignote pendant les lancers. | common | money, curse_fx | on_ball_land→add_money | Il dit encore « OUVERT ». Plus pour longtemps. |
| g_egg_box | Boîte d'œufs / Egg Box | +60 Jetons par douzaine gagnante. | common | bets, dozen, chips | on_bet_win→add_chips | Une douzaine, c'est douze. Sauf chez le boulanger. |
| g_empty_pockets | Vide-poches / Empty Pockets | +4 Mult par emplacement de grigri vide. | common | slots, mult | on_score_calc→add_mult | Le vide, c'est aussi une forme de style. |
| g_even_sock | Chaussettes paires / Matching Socks | +40 Jetons si le numéro est pair. | common | parity, chips | on_score_calc→add_chips | Les seules de la ville qui vont ensemble. |
| g_first_drink | Premier verre / First Drink | +6 Mult au premier tour d'une échéance. | common | mult, spins | on_score_calc→add_mult | Offert par la maison. Tout est offert, au début. |
| g_folding_fan | Éventail / Folding Fan | +2 Mult par jeton de budget non misé. | common | budget, mult | on_score_calc→add_mult | Elle s'évente avec l'argent qu'elle n'a pas joué. |
| g_geometer | Géomètre / Geometer | +6 Mult par carré, transversale ou sixain gagnant. | common | bets, corner, street, six_line, mult | on_bet_win→add_mult | Tout est affaire d'angles. Et d'angoisse. |
| g_glass_blower | Souffleur de verre / Glassblower | Une case détruite donne une carte Fortune. | common | destroy, fortune | on_pocket_destroyed→add_fortune | Ce qui se brise se refait. Plus joli. |
| g_green_visor | Visière verte / Green Visor | +3 Mult si 5 emplacements de pari ou plus sont joués. | common | bets, mult | on_score_calc→add_mult | Le comptable voit tout. Surtout en vert. |
| g_half_moon | Demi-lune / Half Moon | +40 Jetons si le numéro est entre 19 et 36 et qu'au moins un pari gagne. | common | range, chips | on_score_calc→add_chips | La moitié haute de la nuit. |
| g_high_heels | Talons hauts / High Heels | +5 Mult si le numéro est entre 19 et 36. | common | mult, range | on_score_calc→add_mult | Elle a dansé jusqu'au dernier jeton. |
| g_hinge | Charnière / Hinge | +5 Mult par cheval gagnant. | common | split, bets, mult | on_bet_win→add_mult | Entre deux numéros, il y a de la place pour un rêve. |
| g_horseshoe | Fer à cheval / Horseshoe | +6 Mult par cheval gagnant. | common | bets, split, mult | on_bet_win→add_mult | Le cheval, lui, n'a pas eu de chance. |
| g_house_rules | Règlement intérieur / House Rules | +1,5 Mult par Contrat signé. | common | contract, mult | on_score_calc→add_mult | Article 1 : La Maison a raison. Article 2 : voir article 1. |
| g_india_ink | Encre de Chine / India Ink | +40 Jetons si la bille tombe sur du noir. | common | color, chips | on_score_calc→add_chips | Pour signer en noir sur noir. |
| g_lipstick | Rouge à lèvres / Lipstick | +40 Jetons si la bille tombe sur du rouge. | common | color, chips | on_score_calc→add_chips | La trace sur le verre n'est pas la vôtre. |
| g_loaded_die | Dé pipé / Loaded Die | 1 chance sur 3 : +10 Mult. | common | chance, mult | on_score_calc→add_mult | Pipé dans quel sens ? Mystère. |
| g_lottery_ticket | Ticket à gratter / Scratch Card | Chaque relance de l'étal : 1 chance sur 4 de gagner 5 $. | common | economy, reroll, chance | on_reroll→add_money | Gratte. Encore. Encore un peu. |
| g_low_lamp | Lampe basse / Low Lamp | +5 Mult si le numéro est entre 1 et 18. | common | mult, range | on_score_calc→add_mult | Elle éclaire juste assez pour perdre. |
| g_lucky_penny | Sou fétiche / Lucky Penny | +1 $ à chaque tour où au moins un pari gagne. | common | economy | on_round_end→add_money | Ramassé dans le caniveau devant La Maison. Il en a vu d'autres. |
| g_lucky_seven | Le Sept / The Seven | +10 Mult si le numéro est 7, 17 ou 27. | common | mult, pockets | on_score_calc→add_mult | Un chiffre porte-bonheur. Statistiquement, non. |
| g_magnet_shoes | Chaussures aimantées / Magnet Shoes | +9 Mult quand la bille est attirée par une case. | common | ball, mult | on_score_calc→add_mult | Il ne marche pas. Il est tiré. |
| g_magnifier | Loupe / Magnifier | Le numéro touché rapporte deux fois plus de Jetons (+2 × numéro). | common | pockets, chips | on_score_calc→add_chips | Grossit les chiffres. Et les illusions. |
| g_marathon | Marathon / Marathon | +1 Mult par palier atteint (+3 par palier du mode Infini). | common | endless, mult | on_score_calc→add_mult,add_mult | Ce n'est pas un sprint. Ce n'est pas non plus une bonne idée. |
| g_matchbox | Boîte d'allumettes / Matchbox | +10 Mult, −1 à chaque tour. Se consume à 0. | common | mult, decay | on_acquire→counter_set; on_score_calc→add_mult; on_round_end→counter_add; on_round_end→self_destroy | Dix allumettes. Dix vœux. Dix déceptions. |
| g_metro_ticket | Ticket de métro / Metro Ticket | +40 Jetons si la bille reste dans la zone visée. | common | ball, chips | on_score_calc→add_chips | Valable pour un seul trajet. Vers le bas. |
| g_miser | Le Radin / The Miser | +1 Mult par tranche de 5 $ possédés. | common | economy, mult | on_score_calc→add_mult | Il compte ses pièces en dormant. Elles aussi. |
| g_monocle | Monocle / Monocle | +1 Précision. | common | ball, precision | on_acquire→perm_precision; on_remove→perm_precision | On voit mieux d'un œil. L'autre pleure. |
| g_neon_sign | Enseigne au néon / Neon Sign | +8 Mult au dernier tour d'une échéance. | common | mult, spins | on_score_calc→add_mult | Elle clignote « OUVERT ». Elle ment. |
| g_night_glasses | Lunettes de nuit / Night Glasses | +5 Mult si la bille tombe sur du noir. On n'y voit presque rien pendant les lancers. | common | color, mult, curse_fx | on_score_calc→add_mult | Portées à minuit, par principe. |
| g_odd_duck | Canard impair / Odd Duck | +40 Jetons si le numéro est impair. | common | parity, chips | on_score_calc→add_chips | Il boite. Personne n'ose lui demander pourquoi. |
| g_odd_pair | Paire dépareillée / Odd Pair | +3 Mult par pari Pair ou Impair gagnant. | common | bets, parity, mult | on_bet_win→add_mult | Une rouge, une verte. Personne n'ose rien dire. |
| g_outsider | L'Homme de l'extérieur / The Outsider | +3 Mult par pari extérieur gagnant. | common | bets, outside, mult | on_bet_win→add_mult | Il ne s'assoit jamais à la table. Il regarde. |
| g_paper_crown | Couronne en papier / Paper Crown | +1 Mult par grigri possédé. | common | mult, slots | on_score_calc→add_mult | Roi d'un soir, débiteur à vie. |
| g_patience | Patience / Patience | +1 Mult par tour consécutif sans pari gagnant (remis à zéro dès qu'un pari gagne). | common | growth, mult, safety | on_score_calc→add_mult; on_round_end→counter_add; on_round_end→counter_set | La roue finit toujours par tourner. Paraît-il. |
| g_piggy_bank | Tirelire / Piggy Bank | Gagne +1 Mult à chaque échéance remboursée. | common | growth, mult | on_deadline_end→counter_add; on_score_calc→add_mult | Elle grossit. Toi, tu maigris. |
| g_quartet | Quatuor / Quartet | +4 Mult par carré gagnant. | common | corner, bets, mult | on_bet_win→add_mult | Quatre numéros, quatre instruments, une seule fausse note. |
| g_red_ribbon | Ruban rouge / Red Ribbon | +4 Mult si la bille tombe sur du rouge. | common | color, mult | on_score_calc→add_mult | Noué au poignet par une grand-mère superstitieuse. |
| g_red_tape | Paperasse / Red Tape | +40 Jetons si la bille tombe sur une case scellée. | common | seal, chips | on_score_calc→add_chips | Formulaire B-12, en trois exemplaires. |
| g_rubber_ball | Balle en caoutchouc / Rubber Ball | +6 Mult après un rebond fou (hors zone). | common | ball, mult | on_score_calc→add_mult | Elle rebondit partout. Comme vos créanciers. |
| g_ruby_brooch | Broche de rubis / Ruby Brooch | +2 Mult par case Rubis sur la roue. | common | pockets, mult | on_score_calc→add_mult | Épinglée sur un cœur qui n'en a plus. |
| g_scarlet_streak | Série écarlate / Scarlet Streak | +12 Mult si la même couleur sort 3 fois de suite ou plus. | common | streak, mult | on_score_calc→add_mult | Rouge, rouge, rouge. Ton cœur aussi. |
| g_secret_pocket | Poche secrète / Secret Pocket | +2 budget de mises. | common | budget | on_acquire→perm_budget; on_remove→perm_budget | Cousue dans la doublure. Avec du fil volé. |
| g_shoe_shine | Cireur / Shoe Shiner | +1 Mult par grigri vendu durant ce run. | common | economy, mult | on_score_calc→add_mult | Il fait briller ce que vous lâchez. |
| g_six_pack | Pack de six / Six-Pack | +45 Jetons par sixain gagnant. | common | six_line, bets, chips | on_bet_win→add_chips | Une ligne, six chances, une soif. |
| g_slow_waltz | Valse lente / Slow Waltz | +6 Mult au deuxième tour de chaque échéance. | common | spins, mult | on_score_calc→add_mult | Un, deux, trois. Un, deux, dette. |
| g_so_close | Presque / So Close | +90 Jetons quand la bille frôle un de tes numéros (case voisine). | common | ball, chips, safety | on_score_calc→add_chips | « Presque » est le mot préféré de La Maison. |
| g_spare_change | Petite monnaie / Spare Change | +2 Jetons par $ possédé. | common | economy, chips | on_score_calc→add_chips | Ça tinte dans la poche. C'est déjà ça. |
| g_steel_toes | Embouts d'acier / Steel Toes | +3 Mult par case Acier et +3 Mult par case de Verre sur la roue. | common | pockets, mult | on_score_calc→add_mult; on_score_calc→add_mult | Pour marcher sur des éclats sans broncher. |
| g_straight_razor | Rasoir droit / Straight Razor | +6 Mult par plein gagnant. | common | bets, straight, mult | on_bet_win→add_mult | Pour les décisions tranchées. |
| g_sugar_cube | Sucre en morceau / Sugar Cube | +2 Mult par pari gagnant. | common | bets, mult | on_bet_win→add_mult | Pour faire passer la dette. |
| g_tarot_reader | Liseuse de tarot / Tarot Reader | +3 $ par carte Fortune utilisée. | common | fortune, economy | on_fortune_used→add_money | Elle voit ton avenir. Il coûte trois dollars. |
| g_tip_jar | Bocal à pourboires / Tip Jar | +2 $ quand la bille frôle un de tes numéros. | common | economy, ball | on_round_end→add_money | La Maison a parfois pitié. Rarement. |
| g_tramway | Tramway / Tramway | +50 Jetons par transversale, sixain ou carré gagnant. | common | bets, street, six_line, chips | on_bet_win→add_chips | Dernier tram pour le sous-sol : 3 h du matin. |
| g_umbrella | Parapluie / Umbrella | +8 Mult quand la bille tombe sur le Zéro. | common | zero, mult | on_score_calc→add_mult | Il pleut des pertes ? Ouvrez-le. |
| g_undertaker | Croque-mort / Undertaker | +3 $ quand une case est détruite. | common | destroy, economy | on_pocket_destroyed→add_money | Toujours poli, toujours payé. |
| g_velvet_glove | Gant de velours / Velvet Glove | +3 Mult. | common | mult | on_score_calc→add_mult | Main de fer non fournie. |
| g_wax_stamp | Cachet de cire / Wax Stamp | +4 Mult quand une case scellée compte. | common | seal, mult | on_seal→add_mult | « Lu et approuvé. » |
| g_weighted_chip | Jeton lesté / Weighted Chip | +1 valeur de jeton. | common | chips, economy | on_acquire→perm_chip_value; on_remove→perm_chip_value | Plomb à l'intérieur. Comme ton estomac. |
| g_zero_hero | Bouclier du Zéro / Zero Shield | Le Zéro ne fait plus perdre les paris extérieurs ni payer la taxe. | common | zero, safety | on_zero→protect_zero | Un couvercle de casserole, mais avec conviction. |
| g_accordion | Accordéon / Accordion | +0,5 Mult à chaque tour (cumulatif) ; remis à zéro par le Zéro. | rare | growth, zero, mult | on_score_calc→add_mult; on_round_end→counter_add; on_zero→counter_set | Il gonfle, il gonfle, puis le Zéro s'assoit dessus. |
| g_after_hours | Après la fermeture / After Hours | Mode Infini : +1 tour par échéance. | rare | endless, spins | on_deadline_start→add_spins | « On ferme ! » — personne ne bouge. |
| g_alchemist | Alchimiste / Alchemist | 3 chances sur 20 : une case Standard touchée devient Dorée. | rare | pockets, golden | on_round_end→transform_pocket | Plomb, or, plomb, or… il a perdu le fil. |
| g_ash_collector | Collectionneur de cendres / Ash Collector | +3 Mult permanent à chaque case détruite. | rare | destroy, growth, mult | on_pocket_destroyed→counter_add; on_score_calc→add_mult | Il range les cendres par ordre alphabétique. |
| g_auctioneer | Commissaire-priseur / Auctioneer | ×Mult = 1 + 0,15 par grigri vendu durant ce run. | rare | economy, growth, xmult | on_score_calc→mul_mult | Adjugé ! À vous. Hélas. |
| g_bishop | L'Évêque / The Bishop | Gagne +2 Mult (permanent) par carré gagnant. | rare | growth, corner, mult | on_bet_win→counter_add; on_score_calc→add_mult | Il ne bouge qu'en diagonale. Comme la morale. |
| g_blueprint | Plan du casino / Casino Blueprint | Copie l'effet du grigri à sa droite. | rare | copy | on_score_calc→copy_right; on_bet_win→copy_right; on_ball_land→copy_right; on_round_end→copy_right; on_zero→copy_right; on_bet_lose→copy_right | La sortie de secours y est dessinée au crayon. Effacée. |
| g_bookie | Le Bookmaker / The Bookie | +1,5 Mult par pari perdu. | rare | bets, mult, safety | on_bet_lose→add_mult | Il note vos pertes avec tendresse. |
| g_bow_tie | Nœud papillon / Bow Tie | ×1,5 Mult si 2 paris ou plus gagnent. | rare | bets, xmult | on_score_calc→mul_mult | Noué à la perfection. Pour l'enterrement de la dette. |
| g_cartographer | Cartographe / Cartographer | +15 Mult quand la bille frôle un de tes numéros. | rare | ball, mult | on_score_calc→add_mult | Il a tracé la roue au compas. Elle a bougé. |
| g_census | Recensement / Census | +3 Jetons par case de la roue. | rare | pockets, chips | on_score_calc→add_chips | On compte tout le monde. Même ceux qui se cachent. |
| g_city_block | Pâté de maisons / City Block | +7 Mult par transversale gagnante. | rare | street, bets, mult | on_bet_win→add_mult | Trois numéros, un quartier, aucun voisin aimable. |
| g_compass | Boussole / Compass | Après un rebond fou, +1 Précision pour le lancer suivant. | rare | ball, precision | on_round_end→temp_precision | Le nord, c'est en bas. |
| g_compound | Intérêts composés / Compound Interest | Plafond des intérêts +5 $. | rare | economy, interest | on_acquire→interest_cap; on_remove→interest_cap | L'arme de La Maison, retournée contre elle. |
| g_coupon_book | Carnet de bons / Coupon Book | Boutique −2 $ sur tout. | rare | economy | on_acquire→shop_discount; on_remove→shop_discount | Valable jusqu'à la fin des temps. Ou du run. |
| g_cracked_monocle | Monocle fêlé / Cracked Monocle | ×1,5 Mult si la bille tombe dans la zone visée. Le verre fêlé zèbre la vue pendant les lancers. | rare | xmult, curse_fx | on_score_calc→mul_mult | Il voit juste… d'un seul œil. |
| g_croupier_wink | Clin d'œil du croupier / Dealer's Wink | 1 chance sur 2 : les paris gagnants paient une seconde fois. | rare | retrigger, bets | on_ball_land→retrigger_bets | Il a une poussière dans l'œil. Tous les soirs. |
| g_double_or_nothing | Quitte ou double / Double or Nothing | 1 chance sur 2 : ×2 Mult. Puis 1 chance sur 2 : ×0,75 Mult. | rare | chance, xmult | on_score_calc→mul_mult; on_score_calc→mul_mult | Une pièce, deux faces, zéro garantie. |
| g_forger | Faussaire / Forger | 1 chance sur 5 : la case touchée est dupliquée (la roue grandit). | rare | pockets, chance | on_round_end→add_pocket_copy | Signature parfaite. Encre encore fraîche. |
| g_fortune_cookie | Biscuit chinois / Fortune Cookie | +3 Mult permanent par carte Fortune utilisée. | rare | fortune, growth, mult | on_fortune_used→counter_add; on_score_calc→add_mult | « Vous allez miser gros. » Évidemment. |
| g_fortune_teller | Diseuse de bonne aventure / Fortune Teller | Au dernier tour d'une échéance, crée une carte Fortune. | rare | fortune | on_round_end→add_fortune | Elle voit votre avenir. Elle préfère ne rien dire. |
| g_funhouse_mirror | Miroir de foire / Funhouse Mirror | ×2 Mult si la bille tombe sur un nombre « miroir » (12, 21, 13, 31, 23, 32). Pendant que la bille roule, tout est à l'envers. | rare | xmult, curse_fx | on_score_calc→mul_mult | Vu de l'autre côté, la Maison perd. |
| g_gardener | Jardinier / Gardener | Si au moins un pari gagne, la case touchée gagne un niveau (+10 Jetons). | rare | pockets, growth | on_round_end→upgrade_pocket | Il arrose les cases avec vos larmes. |
| g_gilded_cage | Cage dorée / Gilded Cage | Une case Dorée touchée compte une fois de plus. | rare | pockets, golden, retrigger | on_ball_land→retrigger_pocket | Le perroquet ne chante que « mise ». |
| g_gin_flask | Flasque de gin / Gin Flask | +5 Mult. Pendant les lancers, la salle tangue et on voit double. | rare | mult, curse_fx | on_score_calc→add_mult | « Juste une gorgée pour la main. » |
| g_glass_cutter | Diamantaire / Glass Cutter | Une case de Verre touchée compte une fois de plus. | rare | pockets, glass, retrigger | on_ball_land→retrigger_pocket | Il taille le verre comme d'autres taillent les cartes. |
| g_glass_heart | Cœur de verre / Glass Heart | ×2 Mult supplémentaire quand la bille touche une case de Verre. | rare | pockets, glass, xmult | on_score_calc→mul_mult | Il s'est déjà brisé. Il a été recollé à la colle de jeton. |
| g_gold_tooth | Dent en or / Gold Tooth | +30 Jetons par case Dorée sur la roue. | rare | pockets, golden, chips | on_score_calc→add_chips | Arrachée en garantie. Remboursée en sourire. |
| g_high_roller | Gros Joueur / High Roller | ×1,5 Mult si tout le budget de mises est engagé. | rare | budget, xmult | on_score_calc→mul_mult | Tout ou rien. Surtout rien. |
| g_hourglass | Sablier / Hourglass | ×Mult = 1 + 0,15 par tour restant. | rare | spins, xmult | on_score_calc→mul_mult | Le sable tombe. La dette monte. |
| g_insomniac | Insomniaque / Insomniac | Mode Infini : ×2 Mult. | rare | endless, xmult | on_score_calc→mul_mult | Le casino ne ferme jamais. Toi non plus. |
| g_insurance | Police d'assurance / Insurance Policy | Si aucun pari ne gagne, les mises perdues sont remboursées en Jetons. | rare | safety, chips | on_score_calc→refund_lost | Clause 37 : sauf Zéro, sauf jeudi, sauf vous. |
| g_jeweller | Joaillier / Jeweller | +25 Jetons si la case touchée a une édition. 3 chances sur 20 : la case touchée devient Brillante. | rare | pockets, edition | on_score_calc→add_chips; on_round_end→set_pocket_edition | Il polit vos cases contre une petite commission. |
| g_ladder | Échelle de soie / Silk Ladder | Gagne +1 Mult (permanent) à chaque plein gagnant. | rare | growth, straight, mult | on_bet_win→counter_add; on_score_calc→add_mult | Pour monter. Ou pour s'enfuir par la fenêtre. |
| g_landlord | Propriétaire / Landlord | +1 $ par emplacement de grigri vide, à chaque tour. | rare | economy, slots | on_round_end→add_money | Il loue le vide. Très cher. |
| g_last_call | Dernière tournée / Last Call | ×2 Mult au dernier tour d'une échéance. | rare | spins, xmult | on_score_calc→mul_mult | La barmaid compte les verres. Et les têtes. |
| g_ledger | Grand Livre / The Ledger | +4 % du score déjà marqué dans l'échéance en Jetons (max 200). | rare | growth, chips | on_score_calc→add_chips | Chaque ligne est une promesse. Aucune n'est tenue. |
| g_lodestone | Pierre d'aimant / Lodestone | +12 % de contrôle de la bille. | rare | ball, control | on_acquire→perm_control; on_remove→perm_control | Elle tire vers le nord. Ou vers le 17. |
| g_marksman | Le Tireur / The Marksman | ×1,5 Mult par plein gagnant. | rare | bets, straight, xmult | on_bet_win→mul_mult | Un seul numéro. Une seule balle. |
| g_metro_map | Plan de métro / Metro Map | ×Mult = taille de la roue ÷ 37. | rare | pockets, xmult | on_score_calc→mul_mult | Toutes les lignes mènent au terminus Zéro. |
| g_metronome | Métronome / Metronome | +4 Mult par sortie consécutive de la même couleur. | rare | streak, mult | on_score_calc→add_mult | Tic, rouge. Tac, rouge. Tic… |
| g_minimalist | Le Minimaliste / The Minimalist | ×2,5 Mult si un seul emplacement de pari est joué. | rare | bets, xmult | on_score_calc→mul_mult | Un costume, un pari, une prière. |
| g_monogram | Monogramme / Monogram | +3 Mult par niveau de la case touchée. | rare | pockets, growth, mult | on_score_calc→add_mult | Brodé sur chaque case. Vos initiales. Vos dettes. |
| g_neighbours | Les Voisins / The Neighbours | ×1,5 Mult si la bille reste dans la zone visée. | rare | ball, xmult | on_score_calc→mul_mult | Ils entendent tout à travers la cloison. |
| g_night_owl | Oiseau de nuit / Night Owl | ×1,5 Mult si 4 types de paris différents ou plus sont posés. | rare | bets, xmult | on_score_calc→mul_mult | Il ne dort jamais. Il mise. |
| g_notary_ring | Chevalière du notaire / Notary's Signet | +1,5 Mult par case scellée sur la roue. | rare | seal, mult | on_score_calc→add_mult | Chaque sceau, une signature de plus au bas de ta dette. |
| g_notary_stamp | Tampon du notaire / Notary Stamp | 1 chance sur 4 à chaque tour : appose un sceau aléatoire sur une case au hasard. | rare | pockets, seal | on_round_end→add_random_seal | Lu et approuvé. Surtout approuvé. |
| g_overtime | Heures sup / Overtime | +1 tour par échéance. | rare 8 $ | spins | on_acquire→add_extra_spins; on_remove→add_extra_spins | Payées en jetons. En jetons de La Maison. |
| g_pearl_necklace | Collier de perles / Pearl Necklace | +20 Jetons par pari gagnant. | rare | bets, chips | on_bet_win→add_chips | Une perle par victoire. Le fil est court. |
| g_pendulum | Pendule / Pendulum | +0,5 Mult permanent à chaque lancer dans ta zone. | rare | ball, growth, mult, control | on_score_calc→counter_add; on_score_calc→add_mult | Il oscille. Il insiste. Il finit toujours par revenir. |
| g_pickpocket | Pickpocket / Pickpocket | Chaque pari gagnant vole 3 jetons à La Maison (Jetons bonus). | rare | bets, chips | on_bet_win→steal_chips | Main légère, conscience lourde. |
| g_rainmaker | Faiseur de pluie / Rainmaker | +1 $ par pari extérieur gagnant. | rare | economy, outside | on_bet_win→add_money | Il fait pleuvoir des pièces. Petites. |
| g_red_carpet | Tapis rouge / Red Carpet | ×1,25 Mult par pari Rouge ou Noir gagnant. | rare | bets, color, xmult | on_bet_win→mul_mult | Déroulé pour vous. Enroulé derrière vous. |
| g_ruby_slipper | Escarpin rubis / Ruby Slipper | ×2 Mult si la case touchée est un Rubis. | rare | pockets, xmult | on_score_calc→mul_mult | Clac, clac, clac. On ne rentre pas à la maison. |
| g_salon_echo | Écho de salon / Salon Echo | +2 Mult et copie le grigri à sa gauche. | rare | copy, mult | on_score_calc→add_mult,copy_left; on_bet_win→copy_left | Ce qui se dit au salon se répète au salon. |
| g_scrap_dealer | Ferrailleur / Scrap Dealer | +4 jetons de budget au tour qui suit une destruction de case. | rare | destroy, budget | on_pocket_destroyed→temp_budget | Rien ne se perd. Surtout pas chez lui. |
| g_sealing_wax | Bâton de cire / Sealing Wax | Début d'échéance : pose un sceau au hasard sur une case. | rare | seal, pockets | on_deadline_start→add_random_seal | Rouge sang, bien sûr. |
| g_seamstress | Couturière / Seamstress | Les chevaux gagnants rapportent 2 fois plus de Jetons. | rare | split, bets, chips | on_bet_win→multiply_win | Elle recoud ce que la roue déchire. |
| g_seven_sisters | Les Sept Sœurs / Seven Sisters | ×1,7 Mult si le numéro est un multiple de 7 (0, 7, 14, 21, 28, 35). | rare | pockets, xmult | on_score_calc→mul_mult | Sept sœurs, sept dettes, un seul héritier. |
| g_sommelier | Sommelier / Sommelier | ×2 Mult un tour sur trois (tours totaux du run). | rare | spins, xmult | on_score_calc→mul_mult | Un grand cru tous les trois verres. |
| g_spiderweb | Toile d'araignée / Spiderweb | +60 Jetons si une case voisine de la case touchée est Dorée. | rare | pockets, chips | on_score_calc→add_chips | Elle attrape tout ce qui brille. |
| g_stockbroker | Agent de change / Stockbroker | À chaque échéance remboursée, gagne +1 Mult (permanent) par tranche de 10 $ possédés. | rare | economy, growth, mult | on_deadline_end→counter_add; on_score_calc→add_mult | Achetez bas, vendez… non, ne vendez pas. |
| g_tram_conductor | Contrôleur de tram / Tram Conductor | ×1,5 Mult par transversale, sixain ou carré gagnant. | rare | bets, street, six_line, corner, xmult | on_bet_win→mul_mult | Tickets, s'il vous plaît. Et vos économies. |
| g_tram_line | Ligne de tramway / Tram Line | ×1,6 Mult par sixain gagnant. | rare | six_line, bets, xmult | on_bet_win→mul_mult | Terminus : la fortune. Correspondance : la ruine. |
| g_trapdoor | Trappe / Trapdoor | Après un rebond fou, 1 chance sur 4 : +1 tour. | rare | ball, spins, chance | on_round_end→add_spins | Elle s'ouvre sous ceux qui n'ont plus rien. Et les rend. |
| g_twin_dice | Dés jumeaux / Twin Dice | ×3 Mult si le même numéro sort deux fois de suite. | rare | repeat, xmult | on_score_calc→mul_mult | Ils se disputent toujours qui est l'aîné. |
| g_twin_flame | Flamme jumelle / Twin Flame | ×1,5 Mult si la même couleur sort 2 fois de suite ou plus. | rare | streak, xmult | on_score_calc→mul_mult | Deux fois rouge, et le cœur s'emballe. |
| g_window_dresser | Étalagiste / Window Dresser | +6 Jetons permanents par relance de l'étal. | rare | reroll, growth, chips | on_reroll→counter_add; on_score_calc→add_chips | Il refait la vitrine. Encore. Et encore. |
| g_window_shopper | Lèche-vitrine / Window Shopper | +2 Mult par reroll de boutique effectué durant ce run. | rare | economy, growth, mult | on_score_calc→add_mult | Elle regarde tout. N'achète rien. Gagne quand même. |
| g_zero_lover | Amoureux du Zéro / Zero's Sweetheart | Sur un Zéro : ×5 Mult et protège les paris. | rare | zero, xmult | on_zero→protect_zero; on_score_calc→mul_mult | Il a demandé le Zéro en mariage. Le Zéro a dit rien. |
| g_zero_tithe | Dîme du Zéro / Zero's Tithe | Sur un Zéro : +8 $ et +40 Jetons. | rare | zero, economy | on_zero→add_money,add_chips | Le Zéro prend. Le Zéro rend, parfois. |
| g_archivist | L'Archiviste / The Archivist | Une case scellée compte une fois de plus. | legendary | seal, retrigger | on_seal→retrigger_pocket | Il n'oublie rien. Il recopie tout. Deux fois. |
| g_ballroom | Salle de bal / Ballroom | ×Mult = 0,75 × nombre de types de paris posés (min ×1). | legendary | bets, xmult | on_score_calc→mul_mult | Chaque pari danse avec un autre. |
| g_bank_vault | Salle des coffres / Bank Vault | Plafond des intérêts +10 $ et +2 $ à chaque tour. | legendary | economy, interest | on_acquire→interest_cap; on_remove→interest_cap; on_round_end→add_money | La combinaison est gravée sur votre pierre tombale. |
| g_chandelier | Le Lustre / The Chandelier | La case touchée compte deux fois de plus. | legendary | retrigger, pockets | on_ball_land→retrigger_pocket | Mille cristaux. Mille reflets de ta perte. |
| g_crown_jewels | Joyaux de la couronne / Crown Jewels | ×Mult = 1 + 0,75 par case éditée sur la roue. | legendary | pockets, edition, xmult | on_score_calc→mul_mult | Volés à un roi qui les avait mis en gage. |
| g_dealer_hand | Main du Croupier / Dealer's Hand | Les paris gagnants paient deux fois. | legendary | retrigger, bets | on_ball_land→retrigger_bets | Coupée net. Elle continue de distribuer. |
| g_deck_of_fate | Jeu du destin / Deck of Fate | Chaque échéance remboursée donne une carte Fortune. | legendary | fortune | on_deadline_end→add_fortune | Le destin bat les cartes. Toi, tu les tires. |
| g_eternity_clock | Horloge d'éternité / Eternity Clock | ×Mult qui gagne 0,3 à chaque échéance remboursée (départ ×1). | legendary | endless, growth, xmult | on_acquire→counter_set; on_deadline_end→counter_add; on_score_calc→mul_mult | Tic. Tac. Tic. Tac. Tic. |
| g_golden_rake | Râteau d'or / Golden Rake | ×Mult qui grandit de 0,1 par pari gagnant (permanent, départ ×1). | legendary | growth, bets, xmult | on_bet_win→counter_add; on_score_calc→mul_mult | Il ratisse pour vous, pour une fois. |
| g_grand_zero | Le Grand Zéro / The Grand Zero | Sur un Zéro : protège les paris et ×10 Mult. | legendary | zero, xmult, safety | on_zero→protect_zero; on_score_calc→mul_mult | Le casino porte son nom. Ce n'est pas un hasard. |
| g_grandmaster | Grand Maître / Grandmaster | ×Mult = 1 + 0,5 par grigri légendaire possédé (lui compris). | legendary | xmult | on_score_calc→mul_mult | Il a gagné ici en 1929. Il n'en est jamais remonté. |
| g_house_key | Clé de La Maison / Key to the House | ×3 Mult. | legendary | xmult | on_score_calc→mul_mult | Elle ouvre toutes les portes. Sauf la sortie. |
| g_house_of_cards | Château de cartes / House of Cards | ×5 Mult. 1 chance sur 6 de s'effondrer à chaque tour. | legendary | xmult, destroy | on_score_calc→mul_mult; on_round_end→self_destroy | Ne respirez pas. Ne misez pas trop fort. |
| g_infinite_chip | Jeton infini / Infinite Chip | +3 valeur de jeton. | legendary | chips, economy | on_acquire→perm_chip_value; on_remove→perm_chip_value | On ne voit jamais son autre face. |
| g_maestro | Le Maestro / The Maestro | ×Mult = 1 + 0,5 par sortie consécutive de la même couleur. | legendary | streak, xmult | on_score_calc→mul_mult | Il dirige la roue d'une baguette en os. |
| g_metropolis | Métropole / Metropolis | +0,5 Mult par tour joué durant ce run. | legendary | growth, mult | on_score_calc→add_mult | La ville au-dessus grandit. En dessous aussi. |
| g_oracle | L'Oracle / The Oracle | +2 Précision et +15 % de contrôle de la bille. | legendary | precision, control, ball | on_acquire→perm_precision; on_remove→perm_precision; on_acquire→perm_control; on_remove→perm_control | Elle a vu où tomberait la bille. Elle a souri. |
| g_ouroboros | Ouroboros / Ouroboros | ×Mult qui grandit de 8 % à chaque tour (départ ×1,2). | legendary | growth, xmult | on_acquire→counter_set; on_score_calc→mul_mult; on_round_end→counter_mul | Il se mord la queue depuis l'ouverture du casino. |
| g_perpetual_motion | Mouvement perpétuel / Perpetual Motion | La case touchée compte une fois de plus ; dans la zone, les paris gagnants paient aussi deux fois. | legendary | retrigger, ball | on_ball_land→retrigger_pocket; on_ball_land→retrigger_bets | Les physiciens le disent impossible. La roue s'en moque. |
| g_philosophers_stone | Pierre philosophale / Philosopher's Stone | Chaque case Standard touchée devient Dorée. | legendary | pockets, golden | on_round_end→transform_pocket | Elle change tout en or. Sauf votre dette. |
| g_phoenix | Phénix / Phoenix | Protège du Zéro. Gagne ×1 Mult (permanent) à chaque Zéro ; ×Mult = 1 + nombre de Zéros vécus avec lui. | legendary | zero, growth, xmult | on_zero→counter_add; on_score_calc→mul_mult; on_zero→protect_zero | Il renaît de vos cendres. Pas des siennes. |
| g_revenge | La Revanche / Revenge | Si aucun pari ne gagne : +60 Jetons et ×6 Mult. | legendary | safety, xmult | on_score_calc→add_chips,mul_mult | Perdre, c'est juste gagner en différé. |
| g_silver_tongue | Langue d'argent / Silver Tongue | ×Mult = 1 + 0,1 par $ possédé (max ×4). | legendary | economy, xmult | on_score_calc→mul_mult | Elle a convaincu La Maison de lui faire crédit. Deux fois. |
| g_twin_city | Ville jumelle / Twin City | ×Mult = 1 + 0,5 par autre case portant le même numéro que celle touchée. | legendary | pockets, xmult | on_score_calc→mul_mult | Deux 17, c'est une coïncidence. Trois, c'est un quartier. |
| g_black_hole | Trou noir / Black Hole | ×3 Mult. 1 chance sur 20 que la case touchée soit aspirée (détruite). | cursed | xmult, destroy, curse | on_score_calc→mul_mult; on_round_end→destroy_pocket | Il a avalé une roue entière en 1954. |
| g_blood_pact | Pacte de sang / Blood Pact | ×3,5 Mult. Les Créanciers commencent avec +50 % de dette. | cursed | xmult, debt, curse | on_score_calc→mul_mult; on_deadline_start→debt_add_pct | Signé en rouge. L'encre n'était pas de l'encre. |
| g_broken_clock | Horloge cassée / Broken Clock | ×3 Mult. Chaque échéance a 1 tour de moins. | cursed | xmult, spins, curse | on_score_calc→mul_mult; on_deadline_start→add_spins | Elle a raison deux fois par jour. Ici, il n'y a pas de jour. |
| g_cracked_mirror | Miroir fêlé / Cracked Mirror | Copie ses deux voisins. −1 emplacement de grigri. | cursed | copy, slots, curse | on_acquire→add_slot; on_remove→add_slot; on_score_calc→copy_left,copy_right; on_bet_win→copy_left,copy_right | Sept ans de malheur, payables en trois fois. |
| g_cursed_idol | Idole maudite / Cursed Idol | +20 Mult. −1 Précision. | cursed | mult, precision, curse | on_score_calc→add_mult; on_acquire→perm_precision; on_remove→perm_precision | Ses yeux suivent la bille. Et vous. |
| g_cursed_seal | Sceau maudit / Cursed Seal | ×1,5 Mult quand une case scellée compte. Chaque échéance coûte 5 % de dette en plus. | cursed | seal, xmult, curse | on_seal→mul_mult; on_deadline_start→debt_add_pct | La cire ne sèche jamais vraiment. |
| g_dead_mans_hand | Main du mort / Dead Man's Hand | ×3 Mult. −2 budget de mises. | cursed | xmult, budget, curse | on_score_calc→mul_mult; on_acquire→perm_budget; on_remove→perm_budget | Il tenait encore ses jetons quand on l'a trouvé. |
| g_eclipse | Éclipse / Eclipse | ×5 Mult sur le noir, ×0,5 Mult sur le rouge. | cursed | xmult, color, curse | on_score_calc→mul_mult; on_score_calc→mul_mult | Le rouge s'éteint. Le noir dévore. |
| g_glass_jaw | Mâchoire de verre / Glass Jaw | ×4 Mult. Si aucun pari ne gagne, 1 chance sur 10 de se briser. | cursed | xmult, destroy, curse | on_score_calc→mul_mult; on_round_end→self_destroy | Un coup de malchance et tout part en éclats. |
| g_hex_bag | Sac à sorts / Hex Bag | ×2,5 Mult. 1 chance sur 10 à chaque tour de brûler une case au hasard. | cursed | xmult, pockets, curse | on_score_calc→mul_mult; on_round_end→burn_random_pocket | Il sent le soufre et la menthe. |
| g_imp | Diablotin avide / Greedy Imp | ×Mult = 1 + 0,15 par $ possédé. Perd 3 $ à chaque tour. | cursed | xmult, economy, curse | on_score_calc→mul_mult; on_round_end→add_money | Il mange l'argent qu'il vous fait gagner. |
| g_impatient | L'Impatient / The Impatient | +2 $ par relance de l'étal. Chaque échéance coûte 4 % de dette en plus. | cursed | reroll, economy, curse | on_reroll→add_money; on_deadline_start→debt_add_pct | « Suivant ! Suivant ! » |
| g_iou | Reconnaissance de dette / IOU | ×3 Mult. Chaque échéance commence avec +10 % de dette. | cursed | xmult, debt, curse | on_score_calc→mul_mult; on_deadline_start→debt_add_pct | Signé de ta main. Tu ne te souviens pas. |
| g_leech | Sangsue / Leech | ×2,5 Mult. Coûte 1 $ à chaque tour. | cursed | xmult, economy, curse | on_score_calc→mul_mult; on_round_end→add_money | Elle boit lentement. Elle a tout son temps. |
| g_loan_shark | Prêt sur gage / Loan Shark | +15 $ à l'acquisition, +5 Mult. Chaque échéance commence avec +5 % de dette. | cursed | debt, economy, mult, curse | on_acquire→add_money; on_score_calc→add_mult; on_deadline_start→debt_add_pct | Taux d'intérêt : oui. |
| g_vampire | Le Vampire / The Vampire | À chaque échéance remboursée, dévore un grigri et gagne ×0,5 Mult. | cursed | destroy, growth, xmult, curse | on_deadline_end→destroy_random_grigri,counter_add; on_score_calc→mul_mult | Il ne boit pas de sang. Il boit des porte-bonheur. |
| g_zero_pact | Pacte du Zéro / Zero's Pact | ×4 Mult. La taxe du Zéro coûte 5 $ de plus. | cursed | xmult, zero, curse | on_score_calc→mul_mult; on_zero→house_tax_add | Le Zéro n'oublie jamais un rendez-vous. |
