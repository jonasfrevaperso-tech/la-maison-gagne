# Guide de playtest (1.1)

Objectif : remplacer les hypothèses des bots par des mesures sur de vrais joueurs (compréhension, difficulté réelle des Actes II–III, durée, son), puis réajuster `data/balance.json` à partir de chiffres.

## Avant la session
1. **Partir d'un profil neuf** si possible (Options → « Ouvrir le dossier des données », déplacer `profile.json` ailleurs) : le tutoriel se rejoue et les statistiques ne mélangent pas plusieurs joueurs.
2. **Accepter les statistiques locales** au premier lancement (ou Options → Jeu → « Statistiques de jeu locales »). Rien n'est envoyé : un fichier par run dans `telemetry/` du dossier des données.
3. Prévoir 2 runs complets par testeur (≈ 1 h 30), dont au moins un au-delà de l'Acte I.

## Pendant la session
- **F8 à tout moment** (ou « Noter ce moment » dans le menu pause) : humeur (Génial / Bien / Bof / Pénible / Bug), un mot, une capture d'écran automatique. C'est l'outil principal : ne pas hésiter à en abuser, surtout pour « je ne comprends pas », « c'est long », « c'est injuste ».
- L'observateur ne donne pas d'aide sur les règles pendant le premier run (on mesure le tutoriel).
- **Son** : une fois par testeur, Options → Audio → « Écouter les sons… » : marquer « À revoir » ce qui sonne faux, agressif ou trop discret.

## Questions à poser après chaque run
1. Qu'est-ce qui décide du score d'un tour ? (vérifie la compréhension Jetons × Mult)
2. À quoi sert la visée ? As-tu senti que tu la contrôlais ?
3. Un moment où tu t'es senti volé ? Un moment où tu t'es senti très fort ?
4. Combien de temps penses-tu avoir joué ? (à comparer au temps mesuré)
5. Quel grigri voulais-tu absolument ? Lequel n'as-tu jamais compris ?

## Après la session
```bash
# 1. Référence bot (même format, à refaire après chaque changement d'équilibrage)
godot --headless --path . -s res://scripts/sim/sim_main.gd -- --runs=300 --bot=expert --telemetry=user://dev/bot_ref
# 2. Rapport joueurs vs bot + propositions
python3 tools/telemetry_report.py --human ~/.local/share/godot/app_userdata/"La Maison Gagne"/telemetry
#    (plusieurs testeurs : --human dossier1 dossier2 …)
# 3. Sons à remplacer
python3 tools/audio_mix.py
```
Le rapport (`docs/PLAYTEST_REPORT.md`) donne : taux de victoire, durée réelle des runs et des tours, survie par palier, marge score/dette aux échéances, paris réellement joués, taux de choix des grigris, toutes les notes F8 triées par humeur. Les propositions (`docs/balance_proposal.json`) ne sont **jamais appliquées automatiquement** : dettes ajustées de ±20 % au plus, en ne corrigeant que la moitié de l'écart mesuré, et seulement pour les paliers joués au moins 8 fois.

## Lire les résultats
| Signal | Interprétation | Levier |
|---|---|---|
| Victoires joueurs ≪ bot expert, mais marges proches au palier 1–2 | difficulté de compréhension, pas d'équilibrage | tutoriel, lisibilité |
| Survie qui s'effondre à un palier précis | mur de difficulté | `run.tier_debts` de ce palier |
| Runs gagnants > 50 min | trop long | moins de tours par échéance ou dettes plus basses en Acte III |
| Grigri acheté > 70 % du temps et victoire ≥ moyenne | dominant | effet ou rareté |
| Notes « Pénible » regroupées sur la visée ou le zéro | sentiment d'injustice | `throw.control_by_precision`, taxe du zéro |
