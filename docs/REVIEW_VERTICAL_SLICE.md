# Revue critique — Tranche verticale (Acte I)

Date : 2026-11-01 · Tag : `phase-05-vertical-slice`

Méthode : pilote automatique à l'écran (≈ 60 tours joués, captures à chaque étape), 500 runs simulés par bot, lecture du code de présentation. **Limite importante : aucun humain n'a encore joué.** Le ressenti « tactile » (rythme du lancer, plaisir sonore) n'est évalué que par proxy.

## Ce qui fonctionne
- **La boucle est complète et lisible.** Paris → visée → bille → score détaillé → échéance → boutique → créancier. Chaque contribution au score apparaît à sa source (pari sur le tapis, case sur la roue, grigri qui rebondit) : on comprend pourquoi on a gagné.
- **La roue-deck est un vrai levier.** Transformer/dupliquer des cases change les probabilités de façon tangible ; les icônes de type sur la roue rendent ces choix visibles.
- **La visée crée de la tension.** Relâcher au bon moment, voir la bille rester « dans la zone » ou partir en « rebond fou » donne un petit suspense à chaque tour (pilier Tension).
- **Les créanciers de l'Acte I changent la façon de jouer** (cotes masquées, couleur interdite, taxe, rythme qui décale la bille) sans être injustes.
- **Courbe de l'Acte I raisonnable** : 90 % des runs du bot glouton franchissent le palier 1, ~58 % finissent l'acte (cf. BALANCE.md). Un humain qui vise bien devrait faire mieux qu'un bot qui rate 35 % de ses visées.
- **Robustesse** : 44 tests, couverture de 100 % du contenu, sauvegarde atomique, zéro erreur/warning, reprise exacte d'un run.

## Ce qui ne fonctionne pas (encore)
1. **Stratégie dominante en début de run** : pleins voisins + couleur de la zone. Les paris « exotiques » (transversales, sixains) sont rarement meilleurs. → Phase 6 : grigris qui récompensent spécifiquement transversales/sixains/colonnes, cases Prisme plus fortes, contrats de limites de table.
2. **Le Mult est trop rare au début** : beaucoup de tours se jouent à « × 1 ». Le plaisir Balatro du Mult qui enfle arrive tard. → Phase 6 : plus de communs +Mult simples ; Phase 12 : vérifier par simulation la part du Mult dans le score au palier 2.
3. **Économie serrée** : 4 $ au départ, récompenses 3/4/5 $. Un seul achat par boutique au début : peu de décisions. → tester 5 $ de départ et un intérêt plus généreux en phase 12.
4. **Visuels provisoires** : portraits procéduraux trop rudimentaires (silhouette grise), la roue est vectorielle et plate malgré l'inclinaison. → Phase 9 (Blender + portraits pixel 128×128 animés).
5. **Audio non validé à l'oreille** : la synthèse produit des sons cohérents et un mixage par bus, mais personne n'a écouté. → Phase 10 : réécoute, niveaux par bus, sidechain.
6. **La visée manque de retour avant le relâchement** : on ne voit pas clairement quelles mises tombent dans la zone. → afficher la couverture de la zone (cases misées surlignées dans l'arc cyan) — à faire en phase 11.
7. **Le premier tour est verbeux** : titre d'acte + dialogue + aide = trois écrans avant de jouer. → Phase 8 : tutoriel contextuel par bulles, dialogue d'ouverture raccourci et passable d'un clic (déjà possible avec Échap).

## Décision
La tranche verticale est **jouable, compréhensible et robuste**, avec un noyau qui a du potentiel (roue-deck + visée + pipeline Balatro). Les faiblesses identifiées sont du contenu (phase 6), de l'équilibrage (phase 12) et du polish (phases 9-11), pas des défauts de conception du noyau. **On poursuit** sans refonte, en intégrant les sept actions ci-dessus au plan.
