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
