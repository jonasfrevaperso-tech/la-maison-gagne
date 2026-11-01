# Journal des décisions

Format : D-NNN · date · décision · raison · alternatives écartées.

- **D-001 · 2026-11-01 · Godot 4.7.2 (version installée), rendu Forward+.** Cible PC (RX 6700, Vulkan). Le style 2D/2.5D n'exige pas plus.
- **D-002 · Contenu en JSON validé, pas en `.tres`.** 150 grigris + tables générées par script : JSON diffable, éditable dans l'éditeur (éditeur de texte intégré) et validé par `tools/validate_data.gd` (ids, champs, vocabulaire d'effets, références croisées). Les constantes de tuning vivent dans `data/balance.json`.
- **D-003 · Runner de tests maison (`tests/run_tests.gd`) au lieu de GdUnit4/GUT.** Aucune dépendance réseau ni addon à maintenir pour Godot 4.7 ; la logique est pure (RefCounted) donc testable sans arbre de scène. API minimale `TestCase.check/eq/near`.
- **D-004 · Plan de phase écrit dans docs/PROGRESS.md plutôt qu'en « plan mode » interactif.** Le plan mode demande une validation humaine, incompatible avec l'exécution autonome demandée. Chaque phase a son plan écrit avant le code.
- **D-005 · Gain d'un pari = mise × (cote + 1) (mise rendue).** Avec « mise × cote » seul, les paris simples (1:1) valent moitié moins que les pleins en espérance ; rendre la mise égalise l'espérance de base (36/37) entre tous les paris, comme au vrai casino. Paramètre `bets.stake_returned`.
- **D-006 · Lancer = visée + contrôle + zone.** Le relâchement choisit une case cible. Avec la probabilité `control` (selon la Précision) la bille tombe dans une zone centrée (largeur 7→3, tirage triangulaire), sinon « rebond fou » uniforme. La visée favorise les paris de voisinage (pleins adjacents sur la roue), d'où des limites de table sur les paris intérieurs (2 jetons par plein au départ) pour garder les paris extérieurs viables.
- **D-007 · La roue est un deck à taille variable.** Les cases peuvent être ajoutées (doublons d'un numéro), retirées (min. 8), transformées. Les paris se résolvent par numéro/couleur de la case touchée, donc ajouter un « 17 » augmente les chances du 17.
- **D-008 · Formule de score conforme à la spec, sans ordre multiplicatif.** Score = Jetons × (1 + ΣMult) × ΠMult. Plus lisible que l'ordre séquentiel de Balatro (pilier Lisibilité) ; l'ordre reste visible pour les effets à état.
- **D-009 · Les cases rapportent leur numéro en Jetons bonus** (comme les cartes jouées dans Balatro), + 10 par niveau d'amélioration.
- **D-010 · Identité git locale** (`user.name=jonasfreva`, email du compte) configurée dans le dépôt uniquement, aucune identité globale n'existant.
- **D-011 · UI construite en code** (scènes `.tscn` = racine + script). Plus robuste à générer sans éditeur, reste éditable ; les écrans sont des `Control` autonomes.
- **D-012 · Lint : lignes à 140 colonnes, `max-returns` 40, `max-public-methods` 60** (`gdlintrc`). Le GDScript typé avec chaînes localisées dépasse vite 100 colonnes ; les `match` d'interpréteur ont légitimement beaucoup de retours. `gdformat --line-length=140` est la référence de formatage.
- **D-013 · QA visuelle automatisée par crochets de développement** (`-- --dev-run=<perso> --dev-phase=… --shot=… --dev-autoplay=N --shot-dir=…`). Permet de jouer de vrais tours à l'écran et de capturer des images sans intervention humaine.
- **D-014 · RunAnalysis (explication de défaite) placé en présentation**, car il dépend des traductions ; le cœur `scripts/core/` reste sans autoload.
