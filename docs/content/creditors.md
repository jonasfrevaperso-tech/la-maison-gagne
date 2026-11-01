# Créanciers (16)

| id | Nom (FR / EN) | Description | Rareté / coût | Tags | Effets | Ambiance |
|---|---|---|---|---|---|---|
| cr_muet | Le Croupier Muet / The Mute Dealer | Les cotes sont masquées. −1 Précision. | paliers 1–3 |  | on_deadline_start→set_flag; on_spin_start→temp_precision | Il ne dit rien. Il n'en a pas besoin. |
| cr_rouge_noir | Madame Rouge-et-Noire / Madame Red-and-Black | Interdit le pari sur une couleur à chaque tour. | paliers 1–3 |  | on_bet_phase→ban_random_color | Une moitié de robe rouge, l'autre noire, et aucune moitié d'indulgence. |
| cr_comptable | Le Comptable / The Accountant | Prélève 25 % de chaque pari gagnant. | paliers 1–3 |  | on_bet_win→multiply_win | Il a calculé ton espérance de vie. Elle est négative. |
| cr_chanteuse | La Chanteuse / The Singer | Son rythme décale la bille : −15 % de contrôle. | paliers 1–3 |  | on_deadline_start→set_flag | Elle chante faux exprès. C'est pire. |
| cr_jumeau | Le Jumeau / The Twin | Il « emprunte » un de tes grigris (désactivé) le temps de l'échéance. | paliers 4–6 |  | on_deadline_start→disable_random_grigri | Il a ton visage. En mieux, dit-il. |
| cr_baron_carre | Baron Carré / Baron Square | Seuls les carrés et les sixains sont autorisés. | paliers 4–6 |  |  | Monocle carré, moustache carrée, esprit carré. |
| cr_usurier | L'Usurier / The Usurer | La dette augmente de 6 % à chaque tour. | paliers 4–6 |  | on_round_end→debt_add_pct | Ses doigts comptent même quand il dort. |
| cr_pyromane | Le Pyromane / The Arsonist | Brûle une case au hasard à chaque tour. | paliers 4–6 |  | on_round_end→burn_random_pocket | Il dit que c'est pour l'ambiance. |
| cr_douairiere | La Douairière / The Dowager | −2 $ à chaque tour où moins de 2 paris gagnent. | paliers 4–6 |  | on_round_end→add_money | Elle a enterré quatre maris et une banque. |
| cr_magnetiseur | Le Magnétiseur / The Mesmerist | La zone de visée s'élargit à 9 cases. | paliers 4–6 |  | on_deadline_start→set_flag | Regarde la bille. Regarde-la bien. Tu as sommeil. |
| cr_notaire | Le Notaire / The Notary | Un tour de moins pour rembourser. | paliers 4–6 |  | on_deadline_start→add_spins | Il a l'acte. Il a toujours l'acte. |
| cr_prestidigitateur | Le Prestidigitateur / The Conjurer | 30 % de chances que la case touchée change de numéro (définitivement). | paliers 4–6 |  | on_round_end→randomize_pocket | Ton 17 ? Quel 17 ? |
| cr_ombre | L'Ombre du Grand-Père / Grandfather's Shadow | Mult ×0,5. Ses dettes deviennent les tiennes. | paliers 1–8 (secret) |  | on_score_calc→mul_mult | Il te sourit avec tes dents. |
| cr_croupier_or | Le Croupier d'Or / The Golden Dealer | −3 $ à chaque tour. Le vaincre rapporte une fortune. | paliers 1–8 (secret) |  | on_round_end→add_money; on_deadline_end→add_money | Entièrement en or. Même les cils. |
| cr_patron | Le Patron / The Boss | Interdit une couleur à chaque tour et prélève 20 % des gains. | paliers 7–7 |  | on_bet_phase→ban_random_color; on_bet_win→multiply_win | Personne n'a vu ses mains. Il porte des gants de toute façon. |
| cr_la_maison | La Maison / The House | Roue vivante en 3 phases : intérêts, puis interdits et brouillage, puis brasier. | paliers 8–8 |  |  | Elle ne s'est jamais arrêtée de tourner. Elle ne sait pas comment. |
