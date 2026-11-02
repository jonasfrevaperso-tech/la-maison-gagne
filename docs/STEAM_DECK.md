# Steam Deck — critères « Vérifié »

Critères publics de Valve pour la note **Vérifié**, et comment le jeu les remplit. Chaque ligne « ✅ » est couverte par une vérification automatique de `tools/check.sh` ou par une décision de conception documentée. **La note n'est attribuée que par la revue de Valve, sur un vrai Steam Deck** : ce document prépare cette revue, il ne la remplace pas.

## Entrées
| Critère | Statut | Preuve |
|---|---|---|
| Le jeu se joue entièrement à la manette, configuration par défaut | ✅ | `--dev-pad-run` : de l'écran titre à la victoire de campagne (options, Codex, sélection, mises, lancer, astuces, boutique, paquets, ventes avec confirmation, Fortune et ciblage, pactes, événements, finale à choix, résumé) **uniquement** avec des événements de manette simulés, à chaque `check.sh` |
| Les invites montrent des boutons de manette (Steam Deck ou Xbox) | ✅ | Glyphes pixel art **Xbox 360** (`tools/gen_glyphs.py`, `assets/glyphs/`), acceptés par Valve ; Steam Input présente le Deck comme une manette Xbox. Aucune invite clavier/souris n'est affichée en mode manette (`InputGlyphs`) |
| Aucune saisie de texte sans clavier à l'écran | ✅ | Clavier virtuel intégré (`VirtualKeyboard`) ouvert par A sur tout champ de texte (graine, notes de test) |
| Pas de souris ni d'écran tactile nécessaires | ✅ | Toutes les actions souris ont un équivalent manette : réordonner (LB/RB), verrouiller (Y), vendre (A + confirmation), cibler une case (croix), infobulles au focus, défilement au stick droit |
| Mode manette au premier lancement sur Deck | ✅ | Mode « Automatique » : manette détectée sur Steam Deck → invites manette d'emblée ; réglable (Options → Commandes → Mode manette) |
| Remappage | ✅ | Clavier et manette, par glyphes (Options → Commandes) |

## Affichage
| Critère | Statut | Preuve |
|---|---|---|
| Résolution native 1280×800 (16:10) par défaut | ✅ | Plein écran par défaut ; cadre multi-résolution (D-016) ; `--dev-ui-check` contrôle 16:10 |
| Texte lisible : au moins 9 px à 1280×800 (12 px recommandés) | ✅ | Plancher `UiKit.MIN_FONT` (14 px logiques = 9,3 px), texte courant à 18 px logiques (12 px) ; `--dev-ui-check` mesure le plus petit texte de chaque vue rendue en 1280×800 (échec sous 9 px), y compris avec le texte agrandi à 130 % |
| Interface lisible sans zoom | ✅ | Option « Taille du texte » (100–130 %), 115 % d'office sur Deck |

## Fonctionnement
| Critère | Statut | Preuve |
|---|---|---|
| Pas de lanceur externe | ✅ | Le binaire lance directement le jeu |
| Fonctionne sous SteamOS | ✅ | Binaire Linux x86_64 natif (Vulkan), aucun intergiciel propriétaire |
| Mise en veille / reprise | ✅ | Sauvegarde automatique à la perte de focus et à la mise en pause de l'application (`GameState._notification`), reprise exacte d'un run |
| Performances | ⚠️ estimé | GPU mesuré sur RX 6700 (`--perf`) : 1,94 ms à 1280×800 avec tous les effets ; Deck ≈ 8× moins puissant → ≈ 15 ms, ≈ 10 ms en mode Steam Deck (activé d'office sur Deck, désactivable : 60 i/s, bloom coupé, roue 3D en MSAA 2× sans ombres). **À mesurer sur un vrai Deck.** |
| Autonomie | ✅ | Limite d'images réglable (30/60/90/120/144), mode Steam Deck / portable (interrupteur, réglages précédents restaurés), roue 3D désactivable |

## À faire hors code (publication Steam)
- Configuration Steam Input par défaut : « Manette » (gamepad), pas de couche souris.
- Déclarer le jeu natif Linux ; ne pas forcer Proton.
- Faire tester sur un vrai Steam Deck avant de soumettre à la revue (performances, mise en veille réelle, clavier virtuel).

## Commandes de vérification
```bash
godot --headless --path . -- --dev-ui-check                                # focus, débordements, lisibilité Deck
godot --headless --path . -- --dev-pad-run=500 --dev-debt-mult=0.01        # campagne à la manette seule
godot --path . --resolution 1280x800 -- --dev-run=lea --dev-autoplay=6 --perf   # mesure GPU/CPU
```
