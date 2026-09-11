# Ce avec quoi on interagit dans Carnage

Les bâtiments, lieux, véhicules et objets auxquels le joueur peut *faire
quelque chose* — ce qui existe aujourd'hui dans le code, et ce que les phases
du **Guide des fonctionnalités GTA 2 Voxel** doivent encore ajouter.

Les numéros de phase sont ceux du guide (§2, *Ordre de développement priorisé*).

## Le parcours

Chargement → **salon** (l'écran d'accueil : tables, *Pseudo*, *Options*) →
manche de CARNAGE → retour au salon avec le classement. Il n'y a plus ni hub à
portails, ni autres jeux, ni écran de résultats.

## Les touches

Trois, et c'est voulu : à cette échelle un menu se lit moins vite qu'on ne se
fait tirer dessus.

| touche | rôle |
|---|---|
| `E` | monter dans un véhicule / en descendre — et **retirer** au coffre, chez soi |
| `F` | l'affaire du lieu où l'on se tient (la ligne du HUD dit toujours laquelle) |
| `TAB` | la carte, sa légende, et la boutique des planques |
| `R` **tenue** | la **roue des stations** : pousser dans une direction, relâcher (au volant) |
| ↑ ↑ ↓ ↓ ← → ← → B A | le **menu de triche** (⚠ la manche ne compte plus pour vous) |

## Ce qui répond déjà

| lieu / objet | repère | portée | ce qu'on y fait | guide |
|---|---|---|---|---|
| **Cabine téléphonique** | **verte, jaune ou rouge** | 68 px | Le gang **du territoire** propose un **contrat** : nettoyer chez un rival, faire repeindre une voiture, tenir deux étoiles. La couleur du téléphone est celle du **travail qu'on y trouve** et ne change jamais : verte (facile, 40 de respect exigé), jaune (moyenne, 62, prime ×1,6), rouge (difficile, 82, ×2,4). L'enseigne s'allume quand ce gang-ci vous en confie assez, et le refus nomme le chiffre qui manque. Se décroche à pied **comme au volant**. | §4.1 + §3.3, phase 4 — **fait** |
| **Garage de peinture** | bleu | 60 px | On y entre **en voiture** : les étoiles tombent à zéro et la tôle est réparée. C'est le *respray* du guide. | §5.2 |
| **Atelier** | bleu, **cinq pastilles de couleur** | 60 px | Un garage sur deux vend aussi des modifications. On se gare **sur la pastille qu'on veut** et `F` achète : plaques (450 $), mitrailleuse de bord (950 $), mines (750 $), huile (550 $), bombe (650 $). Détail : `claude/atelier-de-modification.md`. | §7.2, phase 7 — **fait** |
| **Mines et flaques d'huile** | palet rouge clignotant / disque noir | 44 px / 62 px | Semées avec `F` au volant, loin de tout lieu. La mine détruit la première voiture qui passe (et se retire) ; la flaque fait perdre le cap — y compris à celui qui l'a posée. | §7.2 — **fait** |
| **Hôpital** | croix blanche | 90 px | `F` : se faire recoudre, 400 $. | §6 |
| **Planque à vendre** | maison violette | 70 px | `F` : l'acheter. Le nom et le résumé de l'appartement s'affichent à l'arrivée ; la carte dit quel quartier donne quel appartement. | hors guide (notre ajout) |
| **Sa planque** | maison violette | 70 px | À pied, `F` **entre chez soi**. Au volant, `F` dépose l'argent sans descendre. Y arriver en voiture la **range au garage** si on l'a acheté. | proche du « Jesus Saves » §4.4, mais gratuit |
| **Chez soi — le coffre** | disque **jaune** | 0,9 tuile | `F` dépose puis paie les travaux (coffre, arsenal, garage) ; `E` **retire** tout. | — |
| **Chez soi — la garde-robe** | disque **bleu** | 0,9 tuile | `F` : changer de tenue, gardé pour les manches suivantes. | — |
| **Chez soi — la porte** | disque **vert** | 0,9 tuile | `F` : ressortir — **au volant** si le garage est payé et qu'une voiture y dort. | — |
| **Arène** | rouge | 190 px | Le **tir ami** n'existe QUE là, et seulement si le coup part de l'arène ET y arrive. | hors guide (multijoueur) |
| **Véhicules** | — | 110 px | `E` dans les deux sens. Le vol est **arbitré par l'hôte** : le client demande, l'hôte accorde. **Vingt-huit** modèles depuis la tâche 3 — voir `claude/vehicules.md`. | §1.1, phase 1 |
| **Bateaux amarrés** | le long des quais | 110 px | `E` pour embarquer, comme une voiture. Ils ne naviguent que sur l'eau, et on ne débarque qu'à moins de 150 px d'une berge — « accostez d'abord ». | §7.1, tâche 3 — **fait** |
| **Colis caché** | malle dorée sur anneau | 78 px | Ramassage automatique, en roulant. 220 $ pièce, 3 000 $ pour les dix. |
| **Crâne de Kill Frenzy** | crâne blanc sur anneau rouge | 78 px | Lance un défi : huit victimes en trente secondes, avec l'arme fournie. 1 800 $. |
| **Taxi** | la carrosserie jaune | 110 px | Au volant d'un taxi : `F` prend le client qui hèle, le radar pointe la destination, `F` le dépose. 32 $ le pâté. |
| **Caisses** | — | 52 px | Ramassage automatique : **arme**, **trousse** (+50), **billet**. Tombent aussi des passants et des flics abattus. | §1.4 |
| **Camion de pompiers** | — | — | Il **arrive tout seul** sur les incendies et les éteint (`VilleVivante`, lance à eau). On peut le voler comme le reste. | §6.2, phase 3 — **fait** |
| **Medicar** | — | — | Il arrive quand des corps traînent : le joueur à terre est **relevé à moitié soigné**. | §6.3, phase 6 — **fait** |
| **Feux** | — | — | Se propagent de véhicule en véhicule, brûlent le joueur, explosent. | §6.1, phase 3 — **fait** |
| **Train** | rame rouge sur la voie ferrée, quai gris à bande jaune | 150 px à quai | Deux rames sur la seule droite en biais de la ville. À quai (7 s toutes les ~11 000 px), `E` fait monter : il traverse la ville à 940 px/s, plus vite qu'aucune voiture, sans feu ni barrage. En marche, **rien ne l'arrête** — piéton, berline en travers, char. Détail : `claude/le-train.md`. | §1.3 — **fait** |
| **Casse (compacteur)** | dalle rouillée à tapis jaune, deux mâchoires, au bord de la voie ferrée | 55 px | Six, une entre chaque paire de quais. Au volant, sur la dalle, `F` **broie** : la voiture disparaît pour de bon, on repart à pied avec 390 à 570 $ selon le gabarit et une caisse d'arme au sol. **Aucune étoile** — c'est la seule sortie propre d'un vol. Détail : `claude/le-train.md`. | §1.3 — **fait** |
| **Repaires de gang** | tag de la couleur du gang peint au sol, trois hommes dedans | 230 px | À pied sur le tag, `F` **entre** — mais seulement au palier **allié** (80 de respect avec ce gang-là), et le refus dit le chiffre qui manque. Dedans : le **râtelier**, seul comptoir d'armes du jeu (mitraillette 700 $ ou roquettes 1 700 $ selon le gang). Un seul dessin, sept teintes. Détail : `claude/repaires-de-gang.md`. | §3 — **fait** |
| **Voitures de gang** | carrosserie aux couleurs du gang, **mitrailleuse sur le toit** | — | Garées autour des repaires. Elles viennent **armées** (§1.3) : en voler une, c'est la mitrailleuse de bord gratuite — et `RESPECT_PERDU × 0,4` chez ce gang-là, pendant qu'un rival du secteur y gagne. Détail : `claude/vehicules.md`. | §1.3 — **fait** |
| **Hommes de gang** | casquette aux couleurs du gang, **anneau au sol** | — | Ils réagissent au **respect** : sous 20 ils tirent à vue, au-dessus de 80 ils tirent sur ce qui vous attaque (flic en chasse, gang hostile). L'anneau dit lequel des cinq paliers — c'est le seul endroit qui peint l'humeur, l'enseigne des cabines ayant repris sa vraie couleur. | §3.3 / §3.4, phase 4 — **fait** |

## Ce que les phases restantes ouvrent

| phase du guide | ce que ça ajoute comme chose manipulable |
|---|---|
| ~~Tâche 3 — véhicules~~ | **Fait.** Le Car Kit au complet (course, tracteur, benne, plateau) et cinq bateaux pilotables amarrés aux quais. Restent, du §7.1 : bus / taxi Xpress / train, tank et Pacifier, tow truck / hot dog van / ice-cream van. |
| ~~Phase 4 — respect des gangs~~ | **Fait.** Sept gangs, trois par district (Le Consortium dans les trois, comme le Zaibatsu du guide), une jauge 0–100 par gang partant de 50, cinq paliers, des alliés qui se battent à côté de vous au-dessus de 80, trois barres au tableau de bord et un anneau d'humeur sous les hommes de main. Détail : `claude/respect-des-gangs.md`. Et depuis le 10/09, les repaires s'ouvrent à 80 — `claude/repaires-de-gang.md`. |
| ~~Phase 7 — garages de modification~~ | **Fait.** Pas un second garage : un garage sur deux vend en plus, sur cinq pastilles où l'on se gare. Restent ouverts : la couleur de la carrosserie qui change vraiment, et la bombe déclenchée à distance (plus de touche libre). |
| ~~Phase 8 — montée de la recherche~~ | **Fait.** Six crans au lieu de cinq, quatre corps (police, SWAT, agents spéciaux, armée) avec leurs tenues, leurs carrosseries et leurs armes ; un fourgon qui débarque quatre hommes à trois étoiles, un char qui canonne à six. Détail : `claude/montee-de-la-recherche.md`. |
| ~~Phase 9 — side-missions~~ | **Fait.** Colis dorés à ramasser (dix, avec prime de collection), crâne rouge qui lance un Kill Frenzy (huit victimes en trente secondes, arme fournie), course de taxi payée au pâté, et cascades — des **frôlements**, faute d'axe vertical. Détail : `claude/les-a-cotes.md`. |
| ~~Tâche — le train et la casse (§1.3)~~ | **Fait.** Deux rames sur la voie ferrée, sept quais, `E` à quai pour monter, rien qui l'arrête en marche — et six compacteurs au bord du ballast, où `F` broie une voiture contre de l'argent et une arme. Détail : `claude/le-train.md`. |
| ~~Phase 10 — radio~~ | **Fait.** Six stations, une par défaut selon la carrosserie, `R` pour changer. La fréquence de la police ne joue que des voix. |

## Ce que le guide décrit et qu'on n'a pas encore

À garder en tête, parce que ce sont des interactions à part entière :

- **l'église « Jesus Saves »** (§4.4) : sauvegarde payante. Notre planque en
  tient lieu, mais elle est gratuite et ne coûte pas de score ;
- **le lance-flammes monté sur le camion de pompiers** (§6.2), débloqué par une
  mission ;
- **le canon à eau orientable** : notre camion éteint tout seul, le joueur ne
  tient pas la lance.

## Ce qui existe en décor et qu'on ne peut pas manipuler

Le joueur va essayer, autant le savoir :

- les **dépôts, conteneurs, chantiers, cuves** du port ;
- les **grands navires** (cargos, paquebot) : décor, seules les cinq petites
  coques se pilotent ;
- les **feux tricolores, lampadaires, bornes d'incendie** ;
- les **portes d'immeuble** : seule la planque du joueur s'ouvre. Les huit
  intérieurs existent, un par quartier ; rien n'interdit techniquement d'en
  ouvrir d'autres, c'est une décision de contenu.
