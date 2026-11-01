# Cases spéciales (25)

| id | Nom (FR / EN) | Description | Rareté / coût | Tags | Effets | Ambiance |
|---|---|---|---|---|---|---|
| standard | Standard / Standard | Rapporte son numéro en Jetons. | common |  |  | Du bois, du vernis, de l'espoir. |
| golden | Dorée / Golden | +50 Jetons. | common | chips | on_pocket_score→add_chips | Plaquée or. Comme les promesses de La Maison. |
| ruby | Rubis / Ruby | +4 Mult. | common | mult | on_pocket_score→add_mult | Taillé dans un regret. |
| glass | Verre / Glass | ×2 Mult. 1 chance sur 4 de se briser. | rare | xmult, destroy | on_pocket_score→mul_mult,chance_destroy_pocket | Fragile, comme ton crédit. |
| magnet | Aimant / Magnet | Attire la bille tombée sur une case voisine (33 %). +15 Jetons. | rare | ball, chips | on_pocket_score→add_chips | Personne ne sait d'où vient la limaille. |
| mirror | Miroir / Mirror | Rejoue aussi la case diamétralement opposée. +1 Mult. | rare | copy, mult | on_pocket_score→add_mult | Il te renvoie l'image d'un joueur qui gagne. Menteur. |
| bomb | Bombe / Bomb | +150 Jetons, ×1,5 Mult, puis explose (détruite). | rare | chips, xmult, destroy | on_pocket_score→add_chips,mul_mult,destroy_pocket | La mèche est courte. Ta patience aussi. |
| ghost | Fantôme / Ghost | Compte aussi comme le numéro de la case suivante. | rare | bets, ghost | on_pocket_score→add_mult | Il était là avant toi. Il sera là après. |
| joker | Joker / Joker | Compte comme rouge ET noir. | rare | color, bets |  | Il n'a pas choisi son camp. Il a choisi le tien. |
| twin | Jumelle / Twin | La case compte deux fois. | rare | retrigger | on_pocket_score→retrigger_pocket | L'autre moitié est quelque part sous la table. |
| thorn | Épine / Thorn | ×3 Mult, mais coûte 1 $. | rare | xmult, money | on_pocket_score→mul_mult,add_money | Ça pique. C'est bon signe. |
| sticky | Collante / Sticky | +20 Jetons. Au tour suivant, 40 % de chances que la bille y revienne. | common | ball, chips | on_pocket_score→add_chips | Personne n'a jamais nettoyé ce coin. |
| prism | Prisme / Prism | +2 Mult par type de pari différent posé. | common | mult, bets | on_pocket_score→add_mult | Une seule lumière, mille façons de perdre. |
| thief | Voleuse / Thief | +2 $ et vole 4 jetons à La Maison (Jetons bonus). | common | money, chips | on_pocket_score→add_money,steal_chips | Elle a la main leste et le sourire désolé. |
| timed | Chronométrée / Timed | +3 Mult par tour restant dans l'échéance. | common | mult, spins | on_pocket_score→add_mult | Tic. Tac. Tic. Dette. |
| cursed | Maudite / Cursed | −3 Mult. Placée par La Maison. | cursed | curse | on_pocket_score→add_mult | Elle porte le nom d'un ancêtre. Le tien. |
| sacred | Sacrée / Sacred | +2 Mult. Rembourse les paris perdus (en Jetons). | rare | safety, mult | on_pocket_score→add_mult,refund_lost | Bénie par une sœur qui ne comptait pas. |
| lightning | Éclair / Lightning | ×3 Mult au premier tour d'une échéance, ×1,5 sinon. | rare | xmult, spins | on_pocket_score→mul_mult; on_pocket_score→mul_mult | Ne frappe jamais deux fois. Sauf ici. |
| double_zero | Zéro double / Double Zero | Agit comme un Zéro. | cursed | zero, curse |  | Un zéro ne suffisait pas à La Maison. |
| steel | Acier / Steel | ×1,5 Mult. | common | xmult | on_pocket_score→mul_mult | La bille y sonne comme une cloche d'église. |
| lucky | Chanceuse / Lucky | 1 chance sur 4 : +15 Mult. 1 chance sur 10 : +10 $. | common | chance, mult, money | on_pocket_score→add_mult; on_pocket_score→add_money | Un trèfle à quatre feuilles verni dedans. |
| echo | Écho / Echo | +2 Mult par case de la même couleur d'affilée. | common | streak, mult | on_pocket_score→add_mult | Rouge… rouge… rouge… tu entends ? |
| burnt | Brûlée / Burnt | Ne rapporte rien. −1 Mult. | cursed | curse | on_pocket_score→add_chips,add_mult | Ça sent le vernis cramé et les mauvaises décisions. |
| vault | Coffre / Vault | +3 $. | common | money | on_pocket_score→add_money | La combinaison est ta date de naissance. Inquiétant. |
| sprout | Germe / Sprout | Gagne un niveau (+10 Jetons) à chaque fois qu'elle est touchée. | common | growth, chips | on_pocket_score→upgrade_pocket | Arrose-la de jetons. Elle adore. |
