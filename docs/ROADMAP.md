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

## 1.2 — Contenu et manette ✅
- ✅ 30 grigris autour des mécaniques peu exploitées (sceaux, Infini, destructions, relances, Fortune, paris intérieurs, attraction, roue).
- ✅ Créanciers à mécanique de roue : La Valseuse (rotation inversée), Le Bonneteur (cases qui changent de place).
- ✅ Course de graine : classement local par graine (du jour ou partagée).
- ✅ Prise en charge manette complète, glyphes Xbox 360, préparation Steam Deck Vérifié.
- ⏳ Reste humain : test sur un vrai Steam Deck avant la revue Valve ; sessions de playtest (`docs/PLAYTEST.md`).

## 1.3 — Table de casino ✅
- ✅ Roue en 3D (cabinet en bois, rotor, bille, caméra qui plonge), roue 3D à l'écran titre, gerbes de jetons 3D.
- ✅ Mini-jeu de lancer (élan + lâcher) qui module le contrôle, équilibre préservé ; mode Simple en option.
- ✅ Manette : stick gauche réglable, gâchettes à un seul appui, curseur par demi-case, taille de la mise sur LB/RB.
- ✅ Fiches de cases illustrées (icônes et couleurs des statistiques), réglages en cours de partie.
- ✅ 17 définitions courantes (dont 1440p, 16:10, 21:9, 32:9), résolution de rendu en plein écran, mode Steam Deck réversible.
- ✅ Écran « Conçu avec Godot, Blender et Claude Code » ; exports Windows, Linux et Flatpak.

## 1.4 — Le Casino Abandonné ✅
- ✅ Mini-jeu de lancer v2 en trois temps (élan maintenu, effet QTE, lâcher), plus exigeant et plus long.
- ✅ Jackpot : machine à sous (1 à 3 tirages selon le lancer), gains temporaires et tour offert.
- ✅ Décor 3D d'un casino abandonné derrière l'interface, objets interactifs et bestioles.
- ✅ Sept grigris à malus visuel (gin, fumée, monocle fêlé…), réglables.
- ✅ Fiches de paris illustrées, rythme ralenti, écran de démarrage noir, tutoriel complété.

## 1.5 — Grande Ouverture ✅
- ✅ Lancer : 9 épreuves (2 tirées par lancer, dont 5 nouvelles en plein écran ou sur le tapis) + lâcher final ; épreuve de rythme enrichie (grooves, accords, bruitages).
- ✅ Cinématique d'intro en pixel art, passable en maintenant une touche 3 s.
- ✅ Histoire densifiée : scènes d'interlude, premières rencontres, répliques propres à chaque personnage.
- ✅ Corrections d'interface (fiche de pari manette, Bazar en 800p, paquets, roue 3D non coupée, jackpot avant le Bazar) et contrôle automatique sur 6 définitions.

## 1.5.1 — Faites chauffer la machine ✅
- ✅ Machine à sous plus fréquente et fiable (gros coups, Sceau Cloche, tirages gratuits), refaite graphiquement.
- ✅ 14 épreuves (5 nouvelles), épreuves durcies, visée plus lente.
- ✅ Super builds : ×Mult croissants, nombres abrégés, Mult en feu ; courbe de dettes façon Balatro.
- ✅ Dépôt GitHub public et releases.

## 1.6 — Pistes
- Glyphes Steam Deck et PlayStation au choix (le Deck accepte déjà les glyphes Xbox).
- Classement partagé de la Course de graine (export/import d'un fichier de résultats, sans serveur).
- Animations de cartes à l'achat et à la vente plus marquées ; écran de victoire de campagne dédié.
- Tapis de jeu en 3D (jetons empilés en relief), comme la roue ; objets du décor modélisés dans Blender.

## DLC « Les Étages Oubliés »
Un quatrième acte entre les Salons et la Cave : casino abandonné, roue à 2 zéros, nouveau personnage (la Contrebandière), 3 créanciers, 25 grigris.

## Coop (exploratoire)
Deux joueurs, une seule roue : chacun mise et vise à tour de rôle, dette commune, grigris partagés par emplacement. Le moteur logique pur et déterministe permet un netcode par entrées (seules les actions transitent).

## Mods
Le contenu étant 100 % JSON validé, ouvrir un dossier `user://mods/` chargé par `ContentDB` (préfixes d'ids par mod), documenter le langage d'effets (`docs/GDD.md` §9) et livrer le validateur aux moddeurs.
