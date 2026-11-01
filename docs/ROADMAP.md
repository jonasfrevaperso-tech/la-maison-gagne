# Feuille de route post-lancement

## 1.1 — Retours de joueurs ✅ (outillage livré, sessions humaines à mener)
- ✅ Outillage de session humaine : télémétrie locale sur consentement, notes F8 avec capture, protocole `docs/PLAYTEST.md`.
- ✅ Réajustement guidé de `data/balance.json` : `tools/telemetry_report.py` (joueurs vs bot expert, propositions relues à la main).
- ✅ Audio : sons de table refaits en synthèse physique, mixage par loudness, table d'écoute pour la réécoute humaine.
- ✅ Steam Deck / Windows : multi-résolution, préréglage économie, sauvegarde à la mise en veille, contrôle automatique de l'interface ; Windows exporté.
- ⏳ **Reste humain** : mener les sessions (`docs/PLAYTEST.md`), écouter les sons, lancer le jeu sur un vrai Steam Deck et sous Windows, puis appliquer les propositions du rapport.

## 1.1.x — Après les premières sessions
- Appliquer les propositions de `docs/balance_proposal.json` validées, refaire la référence bot.
- Remplacer les sons marqués « À revoir » (`python3 tools/audio_mix.py` les liste).
- Bulles du tutoriel ancrées hors des surcouches (elles masquent parfois le titre d'un pacte).

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
