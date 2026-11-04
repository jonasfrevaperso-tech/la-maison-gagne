# Notes de version — 1.8.0 « Le Musée »

Une mise à jour pour les deux versions du jeu. Chaque point précise la version concernée : **[PC]**, **[Android]** ou **[PC + Android]**.

## Le Musée [PC + Android]
Un nouveau mode, ouvert depuis le menu principal (et depuis le Codex) : **cinq salles en vitrine** où chaque épreuve du lancer est exposée sous la forme d'une maquette 3D, sur un piédestal éclairé, avec son cartel de laiton.
- **Les salles** : le Bar (Bouteilles, Shaker, Verre parfait, Juke-box, Fléchettes), le Salon des cartes (Bonneteau, Mémoire, Blackjack, Plus haut / plus bas, Grattage, Dés), la Salle d'arcade (Envahisseurs, Pachinko, Tiercé, Effet), le Hall et la Fontaine (Pêche, Jonglage, Pluie, Billard, Élan) et les Coffres (Coffre-fort, Lasers, Cave, Tour, Tri). Les 25 épreuves y sont, chacune une fois.
- **Se déplacer** : à la manette, gauche / droite entre les objets et LB / RB entre les salles ; à la souris, survoler un objet ; au doigt, glisser sur la salle ou toucher la rangée des objets.
- **S'entraîner** : « Jouer » lance l'épreuve seule, sans lâcher et sans lien avec une partie, en **Détente** (plus lent, cibles plus larges), **Normal** ou **Expert** (un peu plus rapide).
- **Records et médailles** : la meilleure note par épreuve et par difficulté, et une médaille **bronze** (50 %), **argent** (70 %) ou **or** (90 %). La Détente plafonne au bronze. Compteur de médailles par salle et au total. Rien de tout cela n'influe sur les parties.
- **Succès** : « Visite guidée » (une première médaille) et « Conservateur » (l'or aux 25 épreuves).
- Les épreuves pas encore croisées en partie se jouent aussi, marquées « inédites » sur leur cartel.

## Les épreuves refaites [PC + Android]
Les quatorze épreuves qui étaient dessinées à plat passent en **3D**, avec un vrai décor :
- **Arcade** : borne des Envahisseurs sous sa vitre, caves voûtées de la Cave (tonneaux, lampes à huile), plateau de Pachinko sous verre aux clous de laiton, manège forain du Tiercé avec ses chevaux de bois.
- **Table** : table de blackjack en feutrine avec de vraies cartes et un sabot, cartes 3D de Plus haut / plus bas, table de craps et dés qui roulent, ticket à gratter posé sur le comptoir d'un tabac.
- **Adresse** : fontaine du hall avec eau animée et carpes pour la Pêche, salle des coffres enfumée traversée de faisceaux pour les Lasers, scène de cabaret sous projecteur pour le Jonglage, billard aux billes laquées et à la queue visible.
- **Élan** : jauge de laiton gravée devant le rebord de la roue. **Effet** : club de jazz (disque, égaliseur, projecteurs) derrière des pistes lumineuses. **Tri** : tapis roulant à lattes et bacs-gobelets, jetons de casino en relief.
- **Tour de jetons** : guichet de la caisse en fond (boiseries, barreaux de laiton, présentoirs).

## Un rythme plus humain [PC + Android]
- Toutes les épreuves sont mesurées par un **bot « humain »** (temps de réaction, gestes imprécis, six gestes par seconde au plus) : chacune doit lui rester jouable. Celles qui allaient trop vite ont été ralenties ou élargies, notamment l'Élan, les Bouteilles, la Tour, le Shaker, les Dés, le Tiercé et le Billard.
- Chaque épreuve commence par un court « Prêt ? » pour regarder la scène.
- **Blackjack** : 6 s par décision, distribution plus lente, pause après chaque carte ; la vitesse ne compte qu'après le temps de lecture.
- **Pluie du Grand Lustre**, **Envahisseurs** et **Cave** : plus lents et plus tolérants.
- **Billard** : quatre coups, visée plus douce, billes et poches plus grosses.

## Corrections [PC + Android]
- **Dialogue d'ouverture** : il ne se joue plus qu'une fois par profil ; une nouvelle partie ne rejoue que la réplique à choix. Option Jeu → « Revoir les dialogues de l'histoire ».
- **Cases misées sur la roue** : un liseré doré et une pastille-jeton (avec le nombre de jetons) marquent chaque case misée ; pendant la visée, les cases non misées s'assombrissent (plus encore en contraste renforcé).

## Android
- Le Musée se joue au doigt (glisser entre les objets, rangée d'objets en bas, boutons de salle en haut). Au menu, « Le Musée » est sur la ligne de « Nouvelle partie ».

---

# Notes de version — 1.7.0 « Salle de jeux »

Une mise à jour pour les deux versions du jeu. Chaque point précise la version concernée : **[PC]**, **[Android]** ou **[PC + Android]**.

## Onze nouvelles épreuves — 25 en tout [PC + Android]
Chaque lancer tire toujours deux épreuves, désormais parmi **vingt-cinq**. Toutes notent l'adresse ou la décision, jamais la chance.
- **Les Envahisseurs du Zéro** : une borne d'arcade du sous-sol. Des rangées de jetons-envahisseurs descendent vers le tapis : on déplace le râteau-canon du croupier et on tire, abrité derrière des piles de jetons qui s'effritent. Une plaque volante passe en bonus, et les envahisseurs ripostent.
- **La Cave du Grand Zéro** : course de plateformes dans les caves. On saute fosses, tonneaux et rats, on se balance aux câbles des lustres au-dessus des grandes fosses et on cueille les trésors.
- **Pachinko** : les billes dévalent un plateau de clous ; on frappe le taquet gauche ou droit au moment où elles passent pour les renvoyer dans le godet d'or.
- **Blackjack express** : trois mains, quelques secondes par décision (tirer, doubler, rester). Seules la justesse de la décision (stratégie de base) et sa vitesse sont notées, jamais les cartes.
- **Le Grattage** : neuf cases, quatre grattages. Le reflet qui balaie le ticket fait scintiller les trois trèfles d'or à chaque passage ; il faut observer avant de gratter.
- **Les Dés** : on vise, on dose la force, et les dés doivent rebondir sur la bande du fond de la table de craps avant de s'arrêter dans la zone dorée. La face ne compte pas.
- **Le Tiercé** : course de chevaux de bois de fête foraine. On alterne deux touches au rythme du sabot doré ; marteler trop vite essouffle le cheval.
- **La Pêche au Gros** : les carpes dorées de la fontaine du hall. Lancer dans les remous, ferrer au bon moment, puis remonter en gardant la tension du fil dans le vert.
- **Les Lasers du Coffre** : traverser la salle des coffres jusqu'à la porte blindée entre des faisceaux qui balaient, glissent et clignotent.
- **Le Jonglage** : sur la scène du cabaret, garder en l'air des jetons de plus en plus nombreux en frappant la bonne main au bon moment.
- **Le Billard** : trois coups, une bille à empocher à chaque fois, avec la bille fantôme pour viser et une jauge de force.
- **Codex** : nouvelle section « Épreuves du lancer », qui affiche l'illustration, le nom et la règle de chaque épreuve déjà jouée.

## La Pluie du Grand Lustre [PC + Android]
La Pluie de jetons est entièrement refaite.
- **Décor** : la salle de bal du Grand Zéro en 3D. Le lustre de cristal se balance puis se décroche, le plafond à caissons fuit, un croupier fantôme regarde depuis le balcon et les appliques vacillent.
- **Le plateau** a de l'inertie et s'incline. On y attrape des jetons (1) et des plaques (3) en évitant les fausses pièces, les bouteilles et les cigares, qui étourdissent.
- **Bonus** : aimant, grand plateau, ralenti et valeur ×2.
- **La pile** vacille et se renverse si elle monte trop haut ou si on la secoue. Il faut la **mettre à l'abri** au bon moment.
- **Enchaînements** : un multiplicateur récompense les prises consécutives.
- **Quatre vagues** : bruine, rafale du ventilateur, tourbillons, puis le lustre qui se décroche.

## Corrections [PC + Android]
- **Confirmations à la manette** (quitter une partie, nouvelle partie, quitter le jeu) : on peut de nouveau aller sur « Non ». Le focus restait piégé sur « Oui » quand la boîte s'ouvrait depuis le menu de pause.
- **Verrou des objets** : un cadenas en pixel art dans le coin haut gauche de la carte, à côté du compteur. Il ne recouvre plus la pastille de famille.
- **Écrans de chargement** : un carton art déco (roulette qui tourne, astuce, barre de progression) couvre l'entrée en partie et le bilan. Au premier lancement, la Maison « prépare la table » : les épreuves, la machine à sous et les décors sont rendus une fois derrière le carton. Les petits gels du début de partie disparaissent.

## PC
- **Réglages graphiques complets** (Options → Vidéo → Graphismes) :
  - **préréglage** : Bas, Moyen, Élevé, Ultra, Steam Deck ou Personnalisé ;
  - **mise à l'échelle 3D** : bilinéaire, **AMD FSR 1.0** ou **AMD FSR 2.2**, avec raccourcis Qualité, Équilibré, Performance et Ultra-performance, et **netteté FSR** réglable ;
  - **échelle de rendu**, **anticrénelage** (MSAA, FXAA, TAA ; FSR 2 fait le sien), **ombres** (sans à hautes), **filtrage anisotrope**, **occlusion ambiante** et **densité des particules** ;
  - **synchronisation verticale** : sans, activée, adaptative ou mailbox.
- La roue et le tapis, rendus sur fond transparent, restent en mise à l'échelle bilinéaire (FSR y perdrait la transparence).
- Compteur d'images : il affiche aussi la pire image récente.

## Android
- **Fiche de case au doigt** : pendant la visée, la fiche de la case sous le doigt (cote, gain, chances, limite) s'affiche du côté opposé à la main.
- **Toutes les épreuves en plein écran**, jusqu'aux bords des écrans 20:9 ; les petites épreuves sont agrandies.
- **Joystick virtuel** fixe en bas à gauche (en bas à droite en mode gaucher) : Fléchettes (joystick et bouton LANCER), Pluie du Grand Lustre, Envahisseurs, Cave, Dés, Lasers et Billard.
- **Shaker** : A dans le coin bas gauche, B dans le coin bas droit, pour alterner les deux pouces. Pachinko et Tiercé utilisent la même disposition.
- **Chargement plus court** : la préparation de la table, faite une fois par session, est passée de ≈ 12 s à ≈ 5 s sur Pixel 7 (scènes chauffées par lots).
- Les boutons tactiles portent le nom de leur action (FEU, SAUT, VIDER, TIRER / DOUBLER / RESTER, PÊCHER, FRAPPER…). Les libellés longs sont réduits pour tenir dans le bouton.

# Notes de version — 1.6.0 « Les Familles »

## Des builds lisibles
- **Dix familles de grigris** : Rouge & Noir, Le Plein, Les Numéros, La Main, L'Atelier, La Banque, Le Moteur, L'Étoile, L'Arrosage et Le Pacte. Chaque grigri appartient à une famille (pastille de couleur dans le coin de sa carte).
- **Paliers de build** : 2, 3 puis 5 grigris d'une même famille activent un bonus de plus en plus fort (ex. Rouge & Noir : +3 Mult par chance simple gagnée, puis +6, puis ×1,3 en plus). « Build activé ! » s'affiche quand un palier est franchi.
- **Bandeau des familles** sous tes grigris : progression de chaque build (2/3, 5 ★…), infobulle détaillée au survol ; l'infobulle d'un grigri montre sa famille et ce qu'il t'apporterait (« 1 → 2 »).
- **Le Bazar suit ton build** : les grigris de tes familles reviennent plus souvent à l'étal et dans le paquet occulte.
- **Codex** : les grigris sont rangés par famille, avec le détail des paliers.
- **Nouveau : +1 emplacement de grigri** à acheter au Bazar (14 $, puis 24 $ ; deux fois au plus).

## Économie
- Moins d'argent en début de partie : récompenses d'échéance 4 / 5 / 6 $, intérêts plafonnés à 5 $, grigris un peu plus chers (5 / 7 / 12 $), gains d'argent de la machine à sous réduits. À l'entrée du Bazar, on a désormais 11 à 21 $ au lieu de 14 à 66 $.

## Épreuves plus abordables
- **Effet (rythme)** : une seule note à la fois (plus jamais deux touches ensemble), notes plus espacées, et des **notes longues à maintenir** jusqu'au bout de leur traîne.
- **Shaker** : on alterne **B et A** à la manette (→ et ↓ au clavier).
- **Bouteilles**, **Tri des jetons** et **Mémoire des cartes** : plus lents et plus tolérants (balayage plus lent, jetons moins rapides, mémorisation plus longue, plus de temps).
- **Tirage des épreuves** : vérifié sur 3 000 lancers, chaque épreuve sort 7,1 % du temps (le Bonneteau souvent tiré était une coïncidence). Désormais, un lancer évite aussi les épreuves des deux lancers précédents.

## Décors
- **Tapis de jeu en 3D** : feutrine éclairée par une suspension, boudin de cuir capitonné et liseré de laiton, filets dorés en relief, pastilles des numéros vernies, losanges rouge et noir en relief, piles de jetons qui projettent leur ombre, numéros gagnants qui s'illuminent. Les zones de mise restent exactement au même endroit.
- **Bazar** : l'arrière-boutique en 3D derrière l'étal (étagères de bric-à-brac, caisse enregistreuse, ampoules qui se balancent, néon BAZAR).
- **Victoire et défaite** : la table du triomphe (tours de jetons, champagne, confettis dorés, projecteurs, néon JACKPOT) ou la table désertée (jetons épars, verre renversé, reconnaissances de dette, néon RIEN NE VA PLUS).
- **Toutes les fenêtres** (Bazar, événements, pacte, pause, récompenses…) reçoivent un cadre art déco : éventails dorés, filets à gradins, fronton.
- Réglage « 3D » désactivé : retour au décor 2D d'avant.

# Notes de version — 1.5.3 (correctif d'équilibrage)

La machine à sous à quatre rouleaux de la 1.5.2 donnait trop : le bot expert gagnait 56 % des parties (cible 35–45 %, 45 % en 1.5.1).

- Lots multiplicatifs réduits : brelan de cerises ×1,5 (au lieu de ×2) et +6 Mult, carré de cerises ×2 (au lieu de ×3) et +12 Mult, paire de cerises +1 Mult (au lieu de +2), paire de diamants ×1,25 (au lieu de ×1,5), carré de fers à cheval ×1,5 (au lieu de ×2).
- 7 et diamant un peu plus rares sur les rouleaux.
- Pluie de jetons plus juste : un jeton doré n'apparaît plus hors de portée du précédent (deux jetons aux deux bouts du tapis étaient impossibles à attraper ensemble) ; une partie parfaite est toujours possible.
- Résultat : bot glouton ≈ 40 % (moyenne de 3 × 600 parties), bot expert 48 % (200 parties).

# Notes de version — 1.5.2 « Lumières sur la table »

## Les épreuves en 3D
- **Onze épreuves passent en 3D** : Bonneteau (gobelets de cuivre, lampe nue qui se balance), Mémoire des cartes (vraies cartes qui se retournent sur le tapis), Fléchettes (cible de pub dans son armoire, fléchettes qui se plantent), Tour de jetons (plaques laquées), Bouteilles (étagère du bar, verre teinté, néon BAR qui grésille), Juke-box (caisse laquée, tubes à bulles, disque qui tourne, boutons qui s'enfoncent), Pluie de jetons (pièces qui tournoient, plateau en laiton qui se remplit), Coffre-fort (porte d'acier, molette graduée qui tourne vraiment), Shaker et Verre parfait (comptoir, étagère de bouteilles rétroéclairée, tireuse en laiton).
- **Les autres sont redessinées** : Tri des jetons, Effet (rythme) et Plus haut / plus bas.
- **Cartons d'annonce illustrés** : chaque épreuve a sa propre illustration en pixel art, avec son titre, sa règle et ses commandes (clavier, souris ou manette selon l'appareil utilisé).
- **Couleurs des boutons Xbox** : le Tri des jetons, le Juke-box et l'Effet utilisent les couleurs de la manette, à la même place : X bleu à gauche, Y jaune en haut, B rouge à droite, A vert en bas.
- **Plus haut, plus bas** : les figures ont leur emblème (bonnet à plume du Valet, diadème de la Dame, couronne du Roi), leur couleur (cœur ou pique) et des index dans les coins ; en anglais, J / Q / K.

## La machine à sous
- **Quatre rouleaux** au lieu de trois, **en 3D**, dans son propre décor : moquette, néon « LUCETTE », machines voisines, tabourets.
- **Tirage bien plus long** : les rouleaux ralentissent un par un, cran par cran. Quand un gain est possible, le dernier rouleau traîne et le cœur bat.
- **Carrés** (très rares) : quatre 7 = deux tours offerts, quatre diamants = un grigri légendaire… Deux nouveaux symboles, le citron et le fer à cheval.

## Menu principal
- **Nouvelle scène 3D** : la grande salle du Grand Zéro abandonnée. Lustre qui se balance, poussière dans la lumière, enseigne qui grésille, projecteur qui balaie la salle, machines éteintes (une clignote encore).
- **Nouveau menu** : la reprise affiche un résumé de la partie en cours (personnage, palier, échéance), les écrans secondaires sont rangés en grille, et une astuce change toutes les quelques secondes.

## Confort
- **Effet (rythme)** : plus de doubles notes sur deux boutons opposés (X+B ou Y+A), seulement des boutons voisins ; un peu plus de marge sur le timing.
- **Bonneteau** : à chaque nouvelle manche, le curseur repart du gobelet du milieu. Avec un nombre pair de gobelets, aucun n'est présélectionné : il ne trahit plus jamais la bonne réponse.
- **Vitesse d'animation** remise à ×1 (un réglage ×4 hérité restait en mémoire).
- **Pluie de la cinématique** moins forte.
- **Options › Jeu** : les descriptions passent à la ligne, la page ne s'élargit plus.

## Corrections
- Fléchettes : un appui immédiat sur une nouvelle fléchette tombait pile au centre (le viseur n'était pas encore décalé).
- Épreuves sur le tapis : le fond est entièrement opaque, la table ne transparaît plus.

# Notes de version — 1.5.1 « Faites chauffer la machine »

## La machine à sous tourne plus souvent
- **Plus aucun jackpot perdu** : « JACKPOT ! » s'affiche seulement quand la machine se lance, et elle se lance aussi sur un **coup énorme qui solde l'échéance** d'un seul tir, y compris juste avant une fin de session. Sinon, la célébration devient « COLOSSAL ! ».
- **Sceau Cloche** : une case scellée offre un **tirage gratuit** quand la bille s'y arrête. Posé par la fortune *Cordon de sonnette*, le grigri *Groom à clochette*, et par le brelan de cloches de la machine.
- **Nouveaux gains** : symbole Diamant (brelan = un grigri rare + 5 $, paire = ×1,5 Mult au tour suivant), brelan de cerises = Mult +6 **et ×2**, brelan de cloches = argent + Sceau Cloche.
- **Machine refaite** : rayons de lumière tournants, laque à bandes, chenillards lumineux, rivets, Lucette qui cligne des yeux (et a des cœurs dans les yeux quand tu gagnes), bac à pièces où les gains tombent et s'empilent, gerbes d'étincelles.

## Le lancer : 14 épreuves
- **Cinq nouvelles** : **Le Verre parfait** (verser jusqu'au trait, la mousse monte encore après), **Le Juke-box** (rejouer une mélodie de lumières, en plein écran), **Pluie de jetons** (attraper les jetons dorés, éviter les fausses pièces, en plein écran), **Plus haut, plus bas** (le bon calcul compte, pas la chance), **Tri des jetons** (tapis roulant qui accélère).
- **Plus exigeantes** : Bonneteau en 3 manches avec 4 gobelets au dernier tour et plus de mélanges ; Mémoire à 6 paires ; Effet à 20 notes ; Bouteilles, Fléchettes, Coffre-fort, Tour de jetons et Shaker resserrés ; fenêtres du lâcher réduites.
- **Visée plus lente** : le curseur de choix de la case parcourt la roue plus lentement, on vise plus facilement la case voulue.
- Mémoire des cartes : les symboles s'affichent (plus de carrés blancs).

## Super builds
- **9 nouveaux grigris** autour du jackpot et du ×Mult : *Quitte ou double* (×Mult qui double à chaque tour gagnant jusqu'à ×32), *Réaction en chaîne*, *Chorale de clochettes*, *Intérêts composés*, *Photo dédicacée de Lucette*, *Jetons commémoratifs*, *Seau à pièces*, *Machine à sous de poche*, *Groom à clochette*.
- **Grands nombres** : au-delà de 100 000, affichage abrégé (« 12,3 M », « 4,56 Md » ; en anglais « 12.3M », « 4.56B »), puis notation scientifique.
- **Mult en feu** : plus le Mult (et les Jetons) grimpe, plus sa case tremble, se dore puis change de couleur, et s'embrase.

## Difficulté façon Balatro
Premiers paliers plus doux (180 au lieu de 240), fin de partie bien plus exigeante (37 000 au dernier palier au lieu de 21 000) : il faut construire un vrai moteur. Bot glouton 39,0 %, bot expert 45,0 % (cible 35–45 %). Détails : `docs/BALANCE.md`.

## Corrections
- Roue 3D : plus jamais coupée par la barre des grigris (marge de rendu agrandie).
- Bazar à la manette : le bouton Contrat est atteignable même quand le paquet de droite est vendu (les boutons désactivés sont enjambés).
- Barre d'invites qui chevauchait « FORTUNE » avec une grande taille de texte.
- La fiche de pari ne s'affiche plus par-dessus la machine à sous.

# Notes de version — 1.5.0 « Grande Ouverture »

## Un prologue
- **Cinématique d'intro en pixel art** avant la toute première partie : façade du Grand Zéro sous la pluie et son néon qui grésille, l'enveloppe au sceau doré, la lettre de Grand-père, le registre des dettes (« MONTANT DÛ : TOUT »), l'escalier qui descend trop bas, la porte dorée. Parallaxe, travellings, tonnerre, pas, tampon, musique dédiée. Un appui avance le texte ; **maintenir n'importe quelle touche 3 secondes** passe la cinématique. Revoir : Titre → Prologue.

## Le lancer : 9 épreuves
Chaque lancer tire **2 épreuves différentes au hasard**, puis le lâcher final (l'anneau qui se referme sur la bille) :
- **Élan** (deux élans) et **Effet**, façon jeu de rythme : 16 notes sur 4 pistes, accords, trois grooves (jazz, funk, mambo) avec batterie et basse, bruitage par piste, pénalité des appuis à vide.
- Nouvelles, dont plusieurs **en plein écran** : **Les Bouteilles** (lancer des jetons sur des bouteilles de bière au fond du bar), **Mémoire des cartes** (5 paires à retrouver), **Bonneteau** (suivre la bille sous les gobelets), **Fléchettes** (la main tangue, corriger la visée), **Coffre-fort** (écouter le cadran), **Tour de jetons** (empiler sans déborder), **Shaker** (garder la mousse dans la bande dorée).
- Chaque épreuve s'annonce par une carte de présentation (règle et commandes du périphérique utilisé) ; jouable au clavier, à la souris et à la manette.
- Options : Complet (2 épreuves), Rapide (1 épreuve), Simple.

## Une histoire plus fournie
- Dialogues réécrits et densifiés, plus drôles : Anselme le vieux croupier, le Patron et son secret de famille, La Maison qui parle en majuscules depuis qu'elle a absorbé un notaire.
- **Répliques propres à chaque personnage jouable** (Léa, Vic, Odile, Barnabé, Marthe, le Fantôme) dans tous les actes.
- **Nouvelles scènes** : interlude au milieu de chaque acte, premier passage au Bazar (Gaston le Brocanteur), premier jackpot (Lucette, la machine à sous qui parle), premier pacte. Fin secrète enrichie.

## Corrections et finitions
- Fiche de pari à la manette : posée à côté du tapis (plus sur la sélection), fond translucide.
- Jackpot obtenu sur le tour qui rembourse l'échéance : la machine à sous se lance bien avant le Bazar.
- Paquet du Bazar : le choix d'un objet est obligatoire (plus de paquet payé sans contrepartie).
- Animation de la carte survolée au Bazar (plus de carte dédoublée ni de cadre décalé).
- Roue 3D : passe derrière l'interface, plus jamais coupée.
- Bazar, dialogues à choix, machine à sous et toutes les surcouches tiennent dans l'écran à toutes les définitions (1280×800 Steam Deck compris), sans chevauchement ; chaque bouton est atteignable à la manette (contrôle automatique sur 6 définitions et 2 tailles de texte).
- Musique atténuée pendant l'épreuve de rythme.

## Équilibrage
Bot glouton : 39,8 % (600 parties). Bot expert : 47,1 % au lancer neutre (45,5 % en 1.4, écart dans le bruit statistique), 54,2 % avec des lancers adroits. Chaque épreuve est vérifiée automatiquement : faisable pour un joueur appliqué, perdue si l'on ne fait rien. Détails : `docs/BALANCE.md`.

# Notes de version — 1.4.0 « Le Casino Abandonné »

## Un décor qui vit
- **La table d'un casino abandonné, en 3D, derrière toute l'interface** : feutre délavé, auréoles de verres, brûlures de cigare, poussière qui danse dans la lumière d'un lustre aux mauvais contacts.
- **Objets interactifs** dans les coins libres, à la manière des plateaux de Hearthstone : lampe de banquier (s'allume… après deux hoquets), verre de whisky qui tinte, bouteille qui finit par tomber, cendrier qui fume, dés qui roulent, cartes qui se retournent, pile de jetons qui s'écroule puis se reforme, enseigne « CASINO » au néon qui grésille et change de couleur. Un rat et une araignée passent de temps en temps : cliquez-les, ils détalent.
- Manette : une pichenette du stick droit taquine un objet. Options → Vidéo → Décor 3D (désactivable, allégé en mode Steam Deck).

## JACKPOT !
- Un **plein gagnant** fait surgir une machine à sous : levier, rouleaux qui s'arrêtent un à un (ralenti quand deux symboles s'alignent), ampoules en chenillard puis en stroboscope, pluie de pièces, fanfares.
- **1 tirage, 2 sur un lancer « Très bien », 3 sur un « Parfait »** : le mini-jeu compte encore plus.
- Gains : argent, Mult ou contrôle de la bille pour le tour suivant, jetons de mise en plus, et le brelan de 7 offre **un tour supplémentaire**.

## Le mini-jeu de lancer, version 2
- Trois temps au lieu de deux, plus longs et plus exigeants, toujours dans l'esprit QTE : **Élan** (maintenir, relâcher quand la jauge — qui accélère — traverse la zone dorée, placée ailleurs à chaque lancer), **Effet** (quatre invites défilent : flèches, X/Y/B/A ou clics gauche/droit au bon moment), **Lâcher** (frapper quand l'anneau, qui accélère, touche la bille).
- Verdict par temps et verdict global ; un lancer moyen vaut toujours l'ancien lancer.

## Grigris à malus visuels
Sept nouveaux grigris au bonus généreux… et à l'effet secondaire visible pendant les lancers : **Flasque de gin** (la salle tangue, vision double), **Fume-cigarette** (volutes de fumée), **Monocle fêlé** (verre fissuré), **Néon agonisant** (la salle clignote), **Double serré** (tremblote), **Miroir de foire** (tout est à l'envers pendant que la bille roule), **Lunettes de nuit** (on n'y voit presque rien). Réglage : Options → Jus → Malus visuels des grigris.

## Lisibilité et rythme
- **Fiches de paris illustrées** (souris et manette) : type de pari en couleur, cote, gain par jeton, limite de table, numéros couverts en pastilles, barre de chances, avertissement du zéro. À la manette, la ligne d'aide ne déborde plus sur « FORTUNE ».
- **Rythme ralenti** : la bille roule plus longtemps, les dialogues s'écrivent plus posément (pauses à la ponctuation, fondus).
- **Écran de démarrage noir** (plus de logo Godot sur fond gris).
- **Tutoriel complété** : mini-jeu en trois temps, fiches de paris, taille de la mise, jackpot, décor, malus visuels, menu pause et vitesse.
- **4 nouveaux succès** : Ding ding ding !, Machine infernale, Main de croupier, Vision trouble.

## Équilibrage
Bot expert, graines 201–206 : 41,7 % (lancers maladroits), **45,5 % (lancer neutre, contre 45,8 % en 1.3)**, 56,2 % (lancers adroits). Gains de la machine à sous et bonus des grigris à malus réglés par simulation ; un lancer parfait donne désormais +7 points de contrôle (au lieu de +10). Détails : `docs/BALANCE.md`.

# Notes de version — 1.3.0 « Table de casino »

## Une vraie table de casino
- **Roue en 3D** : cabinet en bois verni, rotor doré, déflecteurs, bille qui roule sur la piste avec sa traînée, caméra qui plonge sur la case gagnante, éclairs de lumière à l'arrivée. La roue tourne aussi en 3D à l'écran titre.
- **Gerbes de jetons et de pièces en 3D** sur les gros gains et quand une échéance est remboursée.
- L'ancienne roue 2D reste disponible (Options → Vidéo → Roue en 3D).

## Le lancer devient un mini-jeu
- Après la visée, deux temps de quelques secondes : **ÉLAN** (arrêter l'aiguille dans la zone dorée, plus large avec la Précision) puis **LÂCHER** (frapper quand l'anneau se referme sur la bille). Verdict : Parfait, Très bien, Bien ou Raté.
- La qualité ajuste le contrôle de la bille de −10 à +10 points. Un lancer moyen vaut exactement l'ancien lancer : l'équilibre global est conservé (voir Équilibrage).
- Même geste au clavier (Espace), à la souris (clic) et à la manette (RT ou A). Mode Simple (appuyer/relâcher) dans les options.

## Manette
- **Stick gauche bien moins sensible**, et réglable : Options → Commandes → Sensibilité du stick (aussi en cours de partie).
- **Gâchettes** : un appui = une action (LT comptait des dizaines d'entrées).
- **Curseur par demi-case** : centre = plein, bord = cheval, coin = carré, bord du tapis = transversale ou sixain. Fini les quatre appuis sur LB/RB pour atteindre un carré.
- **LB / RB règlent la taille de la mise** (1, 2, 5, 10 jetons), affichée sur le curseur.

## Lisibilité
- **Fiches de cases illustrées** (infobulle à la souris, ciblage à la manette) : pastille du numéro, icônes pixel art et couleurs par statistique (jetons en bleu, Mult en rouge, ×Mult, argent, niveau), édition, sceau, barre de chance.

## Réglages et affichage
- **Réglages en cours de partie** : Pause → Réglages (volumes, vitesse, lancer, aides, mode manette, sensibilité du stick, effets, mode Steam Deck).
- **17 définitions courantes** de 1280×720 à 5120×2880, dont **2560×1440**, 16:10, 21:9 et 32:9 ; en plein écran, rendu à la définition native ou à une résolution plus basse.
- **Mode Steam Deck / portable** : un interrupteur (texte agrandi, bloom coupé, 60 i/s, roue 3D allégée), activé d'office sur Deck ; le couper restaure les réglages précédents.
- Écran d'ouverture **« Conçu avec Godot, Blender et Claude Code »** (passer : n'importe quelle touche ou bouton).

## Distribution
- Exports autonomes : **Windows** (`.exe`), **Linux** (binaire) et **Flatpak** (`.flatpak`), produits par `tools/build_release.sh`.

## Équilibrage
Bot expert, 330 runs par niveau d'adresse : 42,1 % (lancers maladroits), 45,8 % (lancer neutre = 1.2), 50,0 % (lancers adroits). Le neutre est identique à la 1.2 ; sur les deux protocoles réunis, 42,3 % (cible 35–45 %). Détails : `docs/BALANCE.md`.

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

---

# 1.6.0-android — La Maison dans la poche

La version 1.6.0 complète, jouable entièrement au doigt sur les téléphones Android récents (Android 7 et plus, 64 bits). Testée sur Google Pixel 7. Même contenu que la version PC, mêmes sauvegardes de partie d'un lancement à l'autre ; la version PC ne change pas.

## Au doigt
- **Miser** : pose le doigt sur le tapis, une loupe montre la case visée ; glisse vers un bord ou un coin pour un cheval ou un carré, relâche pour poser. Appui long immobile sur une pile : retire un jeton. Bouton de taille de mise (×1, ×2, ×5, ×10). Option « toucher pour confirmer ».
- **Cartes** (grigris, Fortune, Bazar) : touche une carte pour ouvrir sa fiche (description, Acheter / Vendre / Utiliser, Verrouiller, déplacer ◀ ▶).
- **Épreuves** : toutes jouables au doigt ; celles à symboles affichent des boutons de couleur X / Y / B / A sous le pouce. Fléchettes : vise en glissant, lance en relâchant. Coffre-fort : tourne la molette d'un geste circulaire.
- **Infobulles** : appui long. **Cinématique** : maintiens le doigt pour la passer.
- **Rythme** : la latence audio du téléphone est compensée (Options › Jeu › Décalage audio).
- **Vibrations** : pose de jeton, verdict Parfait, rouleaux et jackpot de la machine à sous (désactivables).

## Téléphone
- Écran de jeu repensé pour le 20:9 : tapis agrandi sous le pouce, gros boutons, disposition gaucher. Texte agrandi par défaut (×1,35, jusqu'à ×1,7). Rien sous la caméra ni sous la barre de gestes.
- Qualité Économie / Équilibré / Beau, baisse automatique si le téléphone peine. Toute la 3D est conservée.
- Geste Retour : ferme la fenêtre ouverte, sinon met en pause ; sur l'écran titre, demande avant de quitter.
- Appel, notification, bouton d'accueil : la partie est sauvegardée et le son coupé ; au retour, pause (ou « touche pour reprendre » en pleine épreuve). Même après un arrêt forcé, « Reprendre la partie » au lancement.
- L'écran ne se met pas en veille pendant une partie.
- Seule permission : vibreur. Aucune connexion Internet, aucun achat, aucune publicité.

## Installer
Télécharger `LaMaisonGagne-1.6.0-android-arm64.apk` sur le téléphone, l'ouvrir et autoriser « Installer des applis inconnues » pour le navigateur ou le gestionnaire de fichiers. Les mises à jour suivantes s'installent par-dessus sans perdre la progression.
