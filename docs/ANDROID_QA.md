# Recette Android (Pixel 7 et téléphones récents)

Les contrôles automatiques (`tools/check.sh`) couvrent la mise en page mobile (6 formats, deux tailles
de texte, cibles tactiles, poinçon simulé) et les règles du profil mobile. Cette liste couvre ce que seule
une main sur un vrai téléphone peut juger. Cocher, noter le modèle et la version d'Android.

## Installation et démarrage
- [x] L'APK s'installe par-dessus la version précédente (même clé) sans perdre la sauvegarde.
- [ ] Icône adaptative correcte (ronde, carrée, thème monochrome d'Android 13+).
- [ ] Démarrage à froid < 6 s jusqu'à l'écran « Conçu avec… ».
- [ ] Plein écran immersif, paysage ; tourner le téléphone retourne l'image (les deux sens).
- [ ] Langue du système au premier lancement (français, sinon anglais).

## Lisibilité et toucher
- [ ] Tous les textes se lisent à bout de bras (texte ×1,35 par défaut) ; ×1,7 reste utilisable.
- [ ] Rien sous le poinçon de la caméra ni sous la barre de gestes, dans les deux sens de paysage.
- [ ] Chaque bouton se touche du premier coup avec le pouce.
- [ ] Les listes (Codex, Succès, Statistiques, Options) défilent au doigt sans déclencher de bouton.
- [ ] Appui long sur un bouton à infobulle : la bulle s'affiche loin du doigt.

## Tapis et cartes
- [ ] Loupe : la mise visée (plein, cheval, carré, transversale, sixain) correspond à ce qu'on voit.
- [x] Relâcher pose la mise ; appui long immobile sur une pile retire un jeton (vibration).
- [ ] Option « toucher pour confirmer » : premier toucher = surbrillance, second = pose.
- [x] Bouton de mise (×1, ×2, ×5, ×10) et LANCER sous le pouce ; disposition gaucher en miroir.
- [ ] Bazar : toucher une carte ouvre sa fiche ; Acheter / Vendre / Verrouiller / ◀ ▶ fonctionnent.
- [ ] Carte Fortune : Utiliser, puis toucher la case de la roue.

## Épreuves du lancer
- [ ] Les 14 épreuves se jouent au doigt (toucher, maintenir, glisser, boutons de couleur).
- [ ] Effet (rythme) : les notes tombent juste au son (régler le décalage audio si besoin).
- [ ] Coffre-fort : la molette tourne au doigt.
- [ ] Cartons d'annonce : commandes tactiles affichées ; toucher passe le carton.

## Système
- [x] Bouton/geste Retour : ferme la surcouche, sinon ouvre la pause ; sur le titre, demande avant de quitter.
- [x] Mise en arrière-plan en pleine épreuve, retour : jeu en pause, rien de perdu.
- [ ] Appel entrant / alarme pendant la partie : son coupé, reprise propre.
- [x] Forcer l'arrêt de l'application en pleine partie : « Reprendre la partie » au relancement.
- [ ] L'écran ne se met pas en veille pendant une partie.
- [ ] Mode économie de batterie : la qualité baisse d'elle-même (toast), le jeu reste fluide.

## Performances (Pixel 7, qualité Équilibré)
- [ ] 60 im/s stables à l'écran de jeu, dans les épreuves et à la machine à sous (compteur d'images).
- [ ] Après 20 min : pas de baisse automatique de qualité, téléphone tiède (`adb shell dumpsys thermalservice`).
- [ ] Mémoire < 600 Mo (`adb shell dumpsys meminfo io.github.jonasfreva.lamaisongagne`).

## Relevé du 2026-11-03 — Pixel 7, Android 17, APK release 1.6.0
Coché ci-dessus : vérifié par adb (gestes injectés, captures d'écran). Également vu : Vulkan / Forward Mobile sur Mali-G710,
dialogue et astuces au doigt, cinématique passée au doigt maintenu, épreuves Verre parfait, Tour de jetons et Bonneteau,
voile « touche pour reprendre » au retour en pleine épreuve.
Mesures : PSS ≈ 1,28 Go (dont ≈ 0,94 Go « Graphics »), images : 50e centile 5 ms, 90e 34 ms (chargements compris).
Reste à juger à la main : loupe, rythme et décalage audio, lisibilité à bout de bras, chauffe sur 20 min, mode économie de batterie,
appel entrant réel, icône adaptative.

