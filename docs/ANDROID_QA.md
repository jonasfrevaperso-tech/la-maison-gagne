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
- [ ] Les 25 épreuves se jouent au doigt, en plein écran (toucher, maintenir, glisser, boutons de couleur, joystick virtuel).
- [ ] Joystick virtuel : fixe en bas à gauche (à droite en gaucher), intensité progressive, retour au centre au lâcher.
- [ ] Shaker, Pachinko, Tiercé : un bouton dans chaque coin bas, alternance des deux pouces.
- [ ] Fiche de case visible sous le doigt pendant la visée.
- [ ] Carton de chargement à l'entrée en partie, aucun gel une fois ouvert.
- [ ] Effet (rythme) : les notes tombent juste au son (régler le décalage audio si besoin).
- [ ] Coffre-fort : la molette tourne au doigt.
- [ ] Cartons d'annonce : commandes tactiles affichées ; toucher passe le carton.

## Le Musée
- [ ] Menu : « Le Musée » sur la ligne de « Nouvelle partie » ; carton de chargement à l'entrée.
- [x] Glisser sur la salle passe d'un objet à l'autre ; toucher un objet de la rangée le choisit, « Jouer » le lance (Pixel 7, 1.8.0).
- [ ] Boutons « Salle précédente / suivante » ; Retour (geste) revient au menu, ou au musée depuis une épreuve.
- [ ] Une épreuve « panel » et une épreuve « full » en plein écran, pavé et joystick affichés ; écran de résultat (note, médaille, Rejouer).
- [x] Record conservé après fermeture de l'application et réinstallation par-dessus (Pixel 7, 1.8.0).

## 1.9.0 — Jeu direct, tutos et défaite
- [ ] Première rencontre d'une épreuve : démonstration (carton en haut), essai bandeau cyan, puis épreuve ; toucher passe chaque étape.
- [ ] Juke-box, Effet, Plus haut / plus bas, Tri, Jonglage, Pachinko : on touche l'objet, aucun pavé affiché.
- [ ] Pluie : le plateau suit le doigt, bouton VIDER met la pile à l'abri.
- [ ] Billard : glisser depuis la blanche vise et dose, relâcher sous le seuil ne tire pas, revenir sur la bille annule.
- [ ] Grattage : gratter au doigt dans les pointillés, le débordement est signalé.
- [ ] Défaite : cinématique (registre, aube, porte), passage au doigt maintenu, puis bilan.
- [ ] Musée : la maquette de la Mémoire ne scintille pas ; geste Retour en épreuve ouvre la pause.
- [ ] Mémoire après une partie avec Billard et Musée (`dumpsys meminfo`), à comparer à la 1.8.0.

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

