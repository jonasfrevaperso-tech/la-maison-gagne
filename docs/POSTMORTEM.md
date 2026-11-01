# Post-mortem

## Ce qui a bien marché
- **Cœur logique pur dès la phase 0** (aucun Node, aucun autoload dans `scripts/core/`). Le même code sert au jeu, aux 54 tests, au simulateur et au fuzzing ; la présentation ne fait que rejouer des `ScoreEvent`.
- **Un seul langage d'effets pour tout** (grigris, cases, éditions, sceaux, contrats, personnages, créanciers, risques, Fortune, événements, défis). 150 grigris ont pu être écrits en données par un sous-agent, validés automatiquement et testés en couverture à 100 %.
- **Hasard déterministe à flux séparés** : reproductibilité exacte des runs, graines partageables, tests et fuzzing rejouables.
- **QA automatisée à l'écran** (pilote automatique + captures) : a permis de jouer un run complet jusqu'à la victoire et de vérifier visuellement chaque phase sans humain.
- **Fuzzing** : a trouvé en quelques minutes quatre bugs que les tests écrits à la main n'avaient pas vus (perte de mises au rechargement, blocage par règles cumulées, tours négatifs, sérialisation inexacte).

## Ce qui a coûté cher
- **Équilibrage tardif.** La simulation a montré dès la phase 2 un jeu trop dur, mais le vrai levier (l'économie) n'a été identifié qu'en phase 12 par balayage de paramètres. Un balayage systématique aurait dû arriver plus tôt.
- **Fuites à la fermeture** liées à l'audio de Godot (lectures non libérées en headless ou pendant la sortie) : plusieurs itérations avant la bonne solution (sortie centralisée, AudioBus muet, pas de son en headless).
- **Pièges de l'API Godot 4** : `set_anchors_preset` sans reset des offsets, entiers relus en flottants par JSON, `Array.has()` sur des nombres JSON.
- **Pas de retour humain** : ressenti, lisibilité réelle et son restent à valider en jeu.

## Chiffres
~12 000 lignes de GDScript et ~2 000 de Python (outillage) · 150 grigris · 333 chaînes FR/EN · 235 icônes · 24 portraits · 306 SFX · 18 couches musicales · 15 tags de phase.
