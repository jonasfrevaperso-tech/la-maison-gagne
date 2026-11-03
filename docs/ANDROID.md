# La Maison Gagne sur Android

Version Android **séparée de la version PC** : même code et même branche, mais un profil mobile activé
uniquement par l'étiquette d'export `mobile` (préréglage d'export « Android »). Les exports PC
(`tools/build_release.sh`) n'exécutent jamais ces chemins, et `tools/check.sh` le vérifie
(étapes PC inchangées).

Appareil de référence : **Google Pixel 7** (2400×1080, 20:9, 420 dpi, Mali-G710, Vulkan, 90 Hz).
Cible : Android 7.0 et plus (API 24), arm64-v8a, la plupart des téléphones récents.

## Construire l'APK

```bash
tools/build_android.sh            # APK release signé  → build/LaMaisonGagne-<ver>-android-arm64.apk
tools/build_android.sh --debug    # APK de debug (clé ~/.android/debug.keystore)
tools/build_android.sh --install  # … puis installation sur le téléphone branché (adb)
```

Le script :
1. reporte la version du jeu (`config/version`) dans le préréglage : `version/name` = « 1.6.0 »,
   `version/code` = majeur×10000 + mineur×100 + correctif (10600) ;
2. importe le projet puis exporte le préréglage « Android » ;
3. vérifie l'alignement (`zipalign -P 16`, pages de 16 Ko), la signature (`apksigner`, schémas v2 et v3)
   et le manifeste (`aapt2 dump badging` : paquet, SDK cible, permission VIBRATE seule, arm64-v8a).

Outillage attendu (cf. `CLAUDE.md`) : JDK 17 (`~/.local/jdk/jdk17`), SDK Android (`~/Android/Sdk`,
build-tools 36.1.0, plateforme 36, NDK 29), modèles d'export Godot 4.7.2, chemins renseignés dans
`~/.config/godot/editor_settings-4.7.tres`.

## Clé de publication — À SAUVEGARDER

- Fichier : `~/.android/lamaisongagne-release.keystore` (PKCS12, alias `lamaisongagne`, RSA 4096).
- Mots de passe : `~/.android/lamaisongagne-release.env` (variables `GODOT_ANDROID_KEYSTORE_RELEASE_*`,
  droits 600). Ces deux fichiers sont **hors du dépôt** et ne doivent jamais y entrer.
- **Copie de sauvegarde indispensable** (clé USB chiffrée, gestionnaire de mots de passe) : sans cette clé,
  Android refusera d'installer une mise à jour par-dessus la version déjà installée — il faudrait
  désinstaller (et perdre la sauvegarde de partie) pour passer à une nouvelle clé.

## Installer sur le téléphone

Sans câble : télécharger l'APK depuis la release GitHub `v*-android`, l'ouvrir, autoriser
« Installer des applis inconnues » pour le navigateur ou le gestionnaire de fichiers, installer.

Avec câble (débogage USB activé dans les Options pour les développeurs) :

```bash
~/Android/Sdk/platform-tools/adb install -r build/LaMaisonGagne-1.6.0-android-arm64.apk
~/Android/Sdk/platform-tools/adb logcat -s godot:V   # journal du jeu
```

## Ce qui change sur téléphone

| Domaine | PC | Android |
|---|---|---|
| Rendu | Forward+ | Mobile (Vulkan), repli OpenGL ES 3 (qualité Économie imposée) |
| Qualité | `handheld` (Steam Deck) | Économie / Équilibré / Beau, baisse automatique si les images ralentissent (`FrameGovernor`) |
| Scènes 3D cachées | rendues | mises en veille quand une épreuve plein écran ou une surcouche à décor les couvre |
| Écran de jeu | scène 1920×1080 | scène 2200×1080 (`RunScreenLayoutMobile`) : tapis agrandi à droite, gros boutons, option gaucher |
| Mises | clic, Maj, clic droit, molette | doigt posé → loupe, glisser pour viser, relâcher pour poser ; appui long immobile → −1 jeton ; option « toucher pour confirmer » |
| Cartes | survol, double-clic, clic droit | toucher → fiche (description, Acheter/Vendre/Utiliser, Verrouiller, ◀ ▶) ; glisser pour réordonner |
| Infobulles | survol | appui long, bulle à l'opposé du doigt |
| Épreuves à symboles | touches / boutons de manette | boutons de couleur X/Y/B/A sous le pouce (`TouchPad`, données `touch_pad`) |
| Texte | ×1,0 | ×1,35 par défaut (jusqu'à ×1,7), 22 px minimum, boutons de 100 px de haut minimum |
| Zone utile | toute la fenêtre | zone sûre (poinçon de la caméra, barre de gestes) |
| Retour | Échap / B | geste Retour : ferme la surcouche, sinon pause ; sur l'écran titre, demande avant de quitter |
| Arrière-plan | — | sauvegarde, son coupé, pause ; écran maintenu allumé pendant la partie |
| Permissions | — | VIBRATE uniquement (pas d'Internet : la télémétrie reste locale) |

## Mettre au point sans téléphone

`--dev-mobile[=LxH]` émule le profil mobile sur PC : fenêtre au format du téléphone (2400×1080 par défaut),
souris = doigt, poinçon simulé de 110 px à gauche, réglages séparés (`settings_mobile.cfg`).

```bash
godot --path . -- --dev-mobile --dev-run=lea --dev-phase=hud --shot=/tmp/hud.png --frames=220
godot --headless --path . -- --dev-ui-check --dev-mobile      # 6 formats de téléphone, texte ×1,35 et ×1,6
```

Gestes scriptés pour les captures : `--dev-hover="x,y,p;x,y,m;x,y,r"` (appuyer, glisser, relâcher).

## Recette sur appareil

Voir `docs/ANDROID_QA.md`.
