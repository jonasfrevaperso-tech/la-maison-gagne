# Feuille de route post-lancement

## 1.1 — Retours de joueurs (priorité)
- Session de test humaine : temps de compréhension du lancer, lisibilité du score, difficulté réelle des Actes II–III.
- Réajuster `data/balance.json` avec la télémétrie locale optionnelle (taux de victoire par palier, grigris choisis).
- Réécoute et mixage audio ; remplacer les sons les moins convaincants.
- Test sur Steam Deck réel et sous Windows.

## 1.2 — Contenu
- 30 grigris supplémentaires autour des mécaniques peu exploitées (sixains, sceaux, Infini).
- Nouveaux créanciers à mécanique de roue (rotation inversée, cases qui changent de place).
- Mode « Course de graine » : classement local par graine du jour.

## DLC « Les Étages Oubliés »
Un quatrième acte entre les Salons et la Cave : casino abandonné, roue à 2 zéros, nouveau personnage (la Contrebandière), 3 créanciers, 25 grigris.

## Coop (exploratoire)
Deux joueurs, une seule roue : chacun mise et vise à tour de rôle, dette commune, grigris partagés par emplacement. Le moteur logique pur et déterministe permet un netcode par entrées (seules les actions transitent).

## Mods
Le contenu étant 100 % JSON validé, ouvrir un dossier `user://mods/` chargé par `ContentDB` (préfixes d'ids par mod), documenter le langage d'effets (`docs/GDD.md` §9) et livrer le validateur aux moddeurs.
