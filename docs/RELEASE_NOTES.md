# Notes de version — 1.2.0 « Tapis de jeu »

## Manette, de bout en bout
- **Mode manette** dans Options → Commandes : Automatique, Activé ou Désactivé.
- **Tout se joue à la manette** : menus (A valide, B revient, LB/RB changent d'onglet, stick droit défile), mises au curseur, lancer à la gâchette, astuces (A compris, X couper), boutique (acheter, vendre, verrouiller, réordonner), paquets, cartes Fortune et choix de la case, pactes, événements, finale, clavier virtuel pour la graine et les notes.
- **Glyphes de manette Xbox 360 en pixel art**, et en mode clavier des touches en relief portant le nom réel de la touche. Seules les indications de l'appareil utilisé s'affichent, partout (aide sous le tapis, boutons, tutoriel, boutique).
- Remappage au clavier **et** à la manette.

## Steam Deck
Préparé pour le badge Vérifié : 1280×800, texte d'au moins 9 px (option de taille réparée), clavier virtuel, mise en veille, invites manette au premier lancement. Liste de contrôle : `docs/STEAM_DECK.md`.

## Interface et rythme
- Nouvelles boutique, fin de run (tuiles de statistiques, analyse en deux cartes), Hall (personnages en portraits, défis lisibles), HUD du run (bandeau, titres de barres).
- Boutons qui réagissent au survol, à la sélection et à l'appui ; ornements art déco.
- Décompte du score qui s'emballe au fil des événements, bille plus vive, transitions plus courtes.

## Contenu
- **30 nouveaux grigris** autour des mécaniques peu exploitées : sceaux, mode Infini, destructions de cases, relances, cartes Fortune, chevaux / carrés / transversales / sixains, attraction de la bille, taille de la roue.
- **2 créanciers qui manipulent la roue** : Le Bonneteur (échange des cases de place) et La Valseuse (roue à l'envers, visée plus rapide).
- **Course de graine** : classement local de tous tes runs sur une même graine, celle du jour ou n'importe quel code partagé.

## Corrections
- A et B ne validaient ni n'annulaient rien dans les menus (actions d'interface sans manette dans Godot 4.7).
- Un choix d'événement indisponible pouvait recevoir la sélection et bloquer la manette.
- L'option « Taille du texte » n'avait plus d'effet depuis la 1.1.
- Recharger une partie hors phase de mise pouvait retirer des jetons du bulletin précédent après un bonus de budget temporaire (trouvé par le fuzzing).

## Équilibrage
- Victoires du bot expert : 38,8 % sur 330 runs (cible 35–45 %). Six grigris à mise en place renforcés (Couturière, Ligne de tramway, Collectionneur de cendres, Biscuit chinois, Ferrailleur, Horloge d'éternité). Détails : `docs/BALANCE.md`.

---

# Notes de version — 1.1.0 « Retours de table »

## Corrections signalées après la 1.0
- L'aide aux commandes sous le tapis ne déborde plus : une seule ligne, générée depuis les touches réellement assignées, pour le clavier/souris ou la manette selon le dernier périphérique utilisé.
- Plus de « partie déjà en cours » fantôme : les outils de test automatisés n'écrivent plus jamais dans ta sauvegarde ; commencer une nouvelle partie demande confirmation si un run est sauvegardé.
- Toutes les résolutions : 16:9 de 720p à 4K, 16:10 (Steam Deck 1280×800) et écrans ultra-larges, sans débordement, y compris avec le texte agrandi.

## Nouveautés
- **Affichage** : mode fenêtré / plein écran / plein écran exclusif, taille de fenêtre, limite d'images par seconde, préréglage économie ; F11 ou Alt+Entrée pour basculer.
- **Steam Deck** : texte agrandi et préréglage économie au premier lancement, sauvegarde automatique à la mise en veille, navigation manette vérifiée sur tous les écrans.
- **Playtest** : statistiques de jeu locales (sur consentement, rien n'est envoyé), notes de test avec capture d'écran (F8 ou menu pause), écran Statistiques avec temps de jeu, survie par palier et derniers runs.
- **Son** : jetons, bille (roulement, déflecteurs, arrivée dans la case) et cylindre refaits en synthèse physique ; mixage recalé par mesure de loudness ; table d'écoute dans Options → Audio pour signaler les sons à revoir.
- **Équilibrage** : nouveau bot de référence « expert » (tous les types de paris, valeur réelle des tours supplémentaires).

## Technique
Options de développement retirées des exports · contrôle automatique de l'interface (18 vues × 3 tailles) · mesure GPU/CPU · `tools/telemetry_report.py` (rapport joueurs vs bot + propositions de réglage) · `tools/audio_mix.py` · 60 tests.

---

# Notes de version — 1.0.0 « Le Grand Zéro »

## Le jeu
- Roguelite de roulette européenne : tapis complet (pleins, chevaux, transversales, carrés, sixains, douzaines, colonnes, chances simples), lancer à visée, score Jetons × Mult animé pas à pas.
- La roue est ton deck : ajoute, transforme, améliore, scelle ou détruis des cases.
- 3 actes, 8 paliers, 24 échéances, 12 créanciers + 2 secrets, Le Patron et La Maison (3 phases), mode Infini.
- 150 grigris, 30 cartes Fortune, 20 contrats, 24 cases spéciales, 4 éditions, 6 sceaux.
- 6 personnages (dont Le Fantôme, à débloquer), 8 niveaux de Risque, 20 événements, 20 défis, 60 succès, graine du jour.
- Campagne dialoguée (portraits animés, voix en blips), 3 fins + une vraie fin secrète.
- Tutoriel en bulles contextuelles, premier run guidé.

## Confort et accessibilité
Vitesse ×1/×2/×4 et saut d'animations, annuler/répéter, historique, infobulles riches avec glossaire des tags, probabilités affichées (option ou Dr Khan), confirmation des actions irréversibles, sauvegarde automatique avec reprise exacte, graine partageable, manette complète, remappage clavier, modes daltoniens, taille d'interface, mouvements et flashs réduits, sous-titres des sons, intensité du « jus » réglable, FR/EN.

## Technique
Godot 4.7.2 · GDScript typé · contenu 100 % en JSON validé · RNG déterministe à flux séparés · 54 tests, fuzzing, simulateur d'équilibrage à 3 bots · exports Linux x86_64 et Windows x86_64.

## Problèmes connus
- Équilibrage validé par bots uniquement (bot compétent ≈ 40 % de victoires au Risque 0) ; à réajuster avec des retours de joueurs.
- Audio contrôlé par mesures objectives, pas encore par une écoute humaine.
- Les options de développement (`-- --dev-run`, `--dev-autoplay`…) restent accessibles dans le binaire (sans effet en usage normal).
