# Personnages (6)

| id | Nom (FR / EN) | Description | Rareté / coût | Tags | Effets | Ambiance |
|---|---|---|---|---|---|---|
| lea | Léa la Croupière / Léa the Dealer | Une relance de bille gratuite par échéance. Commence avec le Gant de velours. |  |  |  | Vingt ans à lancer la bille pour les autres. Ce soir, c'est pour elle. |
| vic | Vic le Parieur / Vic the Gambler | +2 budget de mises, limites de table doublées. Le Zéro coûte 3 $ de plus. |  |  | on_run_start→table_limit; on_zero→house_tax_add | Il a déjà perdu une maison. Deux, si on compte celle-ci. |
| odile | Dr Odile Khan / Dr Odile Khan | Voit les probabilités exactes. +3 Mult si 3 types de paris ou plus sont posés. |  |  | on_score_calc→add_mult | Elle a prouvé que La Maison gagne. Maintenant, elle veut un contre-exemple. |
| barnabe | Barnabé le Corbeau / Barnabé the Raven | Vole 1 jeton à La Maison par pari gagnant. +2 Mult par case éditée sur la roue. |  |  | on_bet_win→steal_chips; on_score_calc→add_mult | Croâ. (Il parle très bien, il préfère juste ne pas.) |
| marthe | Sœur Marthe / Sister Marthe | Le premier tour entièrement perdu de chaque palier ne compte pas. Deux cases Sacrées. |  |  |  | Elle prie pour toi. Elle mise aussi un peu, par charité. |
| ghost | Le Fantôme / The Ghost | Quatre cases Fantômes. Roue instable : une case devient Fantôme à chaque échéance. |  |  | on_deadline_start→burn_random_pocket | Il a perdu au Grand Zéro en 1931. Il n'est jamais reparti. |
