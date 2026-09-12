# Le parc de véhicules

Vingt-huit véhicules : le **Car Kit** de Kenney au complet, plus une **flotte**
tirée du Watercraft Pack. L'indice de modèle est ce qui circule sur le réseau —
un joueur qui vole un taxi doit être vu dans un taxi par les trois autres.

## Ce qui a été ajouté (tâche 3)

Quatre carrosseries dormaient dans `modeles/kenney/voitures/` sans indice, donc
sans exister : elles sont dessinées, payées, et ne roulaient nulle part.

| # | véhicule | modèle | où on le trouve |
|---|---|---|---|
| 19 | voiture de course | `race` | centre et quartier des bureaux, rare |
| 20 | tracteur | `tractor` | le parc et le bout de la banlieue |
| 21 | benne à ordures | `garbage-truck` | partout sauf le centre |
| 22 | plateau de livraison | `delivery-flat` | zone industrielle et port |

La course et le tracteur sont les deux **bouts** de l'échelle, et c'est fait
exprès : `v 1,45 / a 1,55 / tôle 0,4` contre `v 0,52 / a 0,50 / tôle 2,6`.
Trouver l'une ou l'autre doit changer la minute qui suit.

## La flotte

| # | bateau | modèle |
|---|---|---|
| 23 | chaloupe | `boat-row-large` |
| 24 | vedette | `boat-speed-a` |
| 25 | vedette rapide | `boat-speed-c` |
| 26 | barque de pêche | `boat-fishing-small` |
| 27 | remorqueur | `boat-tug-a` |

⚠ **Un bateau est un véhicule comme un autre.** Même espace d'indices, même
identifiant de dormante, même `E` pour monter, même nappe de morceau, même
message réseau. C'est ce qui fait que la flotte tient en une table et deux
fonctions au lieu d'un second système parallèle.

**Un mouillage est une place de stationnement posée sur l'eau.** Une case d'eau
qui touche un quai reçoit une `place` dans sa fiche, exactement comme une case
de pâté en reçoit une le long du trottoir — et tout le reste suit sans une ligne
de plus. Un anneau sur huit environ (`CHANCE_MOUILLAGE = 0,13`) : un port où
chaque mètre de quai porte un bateau ressemble à un parking.

⚠ **`degager_bateau` est le MIROIR de `degager`** : c'est la terre qui arrête et
l'eau qui laisse passer. Une coque et une carrosserie ne peuvent pas partager la
même fonction — l'une est bloquée par exactement ce qui porte l'autre.

⚠ **On ne débarque pas au milieu du bassin.** Sauter d'un bateau à cent mètres
du quai serait une noyade, et le jeu n'a pas de noyade : on resterait à marcher
sur l'eau. Tant qu'il n'y a pas de terre à moins de 150 px, la portière ne
s'ouvre pas, et la ligne du HUD dit « accostez d'abord ».

Deux détails à savoir :

- le filtre `est_voie` de `dormantes_autour` évitait d'interroger les tuiles de
  rue, qui n'ont jamais de place. L'eau en a maintenant : sans l'exception, un
  anneau sur cinq tombait sur un indice de voie et son bateau devenait
  impossible à monter, sans que rien ne le distingue des autres à l'écran ;
- il n'y a **pas de son de moteur marin** dans la banque : le hors-bord prend le
  grain « compact » et le remorqueur celui du camion. Inventer un diesel marin
  demande une prise, pas une ligne de table.

## Les longueurs ne sont pas décoratives

`VoxelsCarnage.GABARITS` donne à chaque indice sa longueur en voxels. C'est elle
qui **met le modèle Kenney à l'échelle** (`FormesCarnage.maillage_voiture`), et
c'est à elle que se réfèrent les places de stationnement et le pare-buffle.

Le Watercraft Pack **n'est pas à l'échelle entre ses classes** — un remorqueur y
fait la taille d'une vedette. Les longueurs de la flotte sont donc celles qu'on
veut dans le jeu, à une unité par mètre : chaloupe 5 m, vedette 7 m, barque 9 m,
remorqueur 18 m.

## Les voitures de gang sont armées (§1.3)

Elles ne portaient que **la couleur du gang** : on les reconnaissait, elles ne
valaient rien de plus qu'une berline. Elles viennent maintenant avec leur
**mitrailleuse de toit** — neuf cent cinquante dollars d'atelier, gratuits.

Le prix se paie en **respect** : voler la voiture d'un gang lui coûte
`RESPECT_PERDU × 0,4`, et depuis cette tâche un rival du secteur y gagne un
quart de `RESPECT_GAGNE`.

⚠ Le gain au rival était à **zéro**. Tout le reste du jeu fait bouger DEUX
jauges — un mort, une voiture brûlée, un contrat rendu — parce que c'est ce qui
tient le triangle de rivalité (§3.1) : sans le second mouvement, on peut fâcher
tout le monde sans jamais devenir l'ami de personne. Un quart de gain : partir
au volant de leur voiture sous leurs fenêtres se remarque, mais ça ne remplace
pas un contrat.

### La mitrailleuse se VOIT

Jusqu'ici elle n'existait que dans une puce du tableau de bord, et deux voitures
identiques n'en étaient pas. `FormesCarnage._mitrailleuse()` pose un socle, un
bloc, un tube et un chargeur en travers sur le toit — le chargeur est ce qui
fait lire « mitrailleuse » plutôt que « antenne » sur une image de deux cents
pixels. Elle est **cachée par défaut** et `armer_la_voiture()` la montre.

⚠ **La hauteur est MESURÉE, pas devinée** (`coque.mesh.get_aabb()`). Vingt-huit
carrosseries, d'un coupé à un camion de pompiers : un chiffre en dur plantait le
canon dans le pare-brise de l'une et à un mètre au-dessus du toit de l'autre.
C'est exactement la faute du char, sorti du banc en pick-up vert parce que sa
tourelle était à l'intérieur de la caisse.

Elle apparaît aux **trois** endroits, par la même fonction : la voiture de gang
garée dans la rue, la voiture du joueur (à l'achat comme au vol), et celle d'un
**autre joueur** — son drapeau voyage dans le paquet de position (`mg`). Sans
ce dernier, on voyait une voiture de gang volée repasser désarmée, et l'on
apprenait à se fier à une silhouette qui ment.

## La peinture ne recouvre que la tôle

Le shader des kits (`MatieresCarnage.KENNEY`) **multipliait** tout le modèle
par la teinte : une voiture bleue avait les jantes bleues et les vitres bleues,
la peinture sombre du garage noircissait le pare-brise, et la nappe des
dormantes — colorée par instance, même multiplication — faisait pareil dans
tout le parking.

Dans l'atlas du Car Kit, la carrosserie est la **seule matière saturée** : les
vitres, les pneus, les jantes, les chromes et les phares sont des gris
(saturation de 0,05 à 0,21, mesurée sur les vingt modèles) quand la moindre
tôle dépasse 0,53. Le shader, en mode `peinture` (posé pour `/voitures/` et
`/bateaux/`), remplace donc la couleur là où la saturation dépasse un seuil
(`smoothstep(0.30, 0.45)`) et laisse le reste intact ; il garde le dégradé de
l'atlas en faisant varier la peinture avec la luminance d'origine, pour ne pas
poser un aplat. La couleur d'instance des nappes passe par le même chemin, et
le **blanc** veut dire « livrée d'usine » — le taxi reste jaune, la police
blanche et bleue, l'ambulance et le camion de pompiers gardent leurs bandes.
⚠ Avant, `VoxelsCarnage.peinture` donnait à la police un blanc cassé qui,
multiplié, ne se voyait pas ; en remplacement, il aurait repeint la bande bleue
en blanc. Les modèles à livrée rendent `Color.WHITE`.

### Une voiture garde sa couleur

Trois endroits décidaient chacun de la couleur d'une voiture : la nappe des
dormantes (`VoxelsCarnage.peinture(modele, id)`), le trafic réveillé (blanc,
donc l'orange `peinture(i, 7)` pour tout le monde) et la voiture volée (blanc
aussi). Résultat : une berline **garée rouge démarrait orange**, et une
voiture de gang volée perdait sa bannière en ouvrant la porte.

`FormesCarnage.couleur_de_l_auto(carte, modele, id, de_gang, gang, teinte)` la
tient pour tous : la peinture du garage d'abord (elle voyage), la bannière du
gang ensuite, sinon la couleur tirée de l'identifiant — celle que la nappe a
peinte. Le « pris » porte maintenant le gang de la voiture (`gg`), le voleur
prend la couleur avec le volant, elle part dans son paquet de position (`tc`)
et revient à l'hôte quand il descend (`sort`, `t`). Les matières peintes sont
**partagées** par (modèle, couleur) (`matiere_peinte`) : dix peintures de
trafic, dix du garage, sept de gang, et pas un duplicata par voiture.

Les peintures du trafic (`VoxelsCarnage.PEINTURES`) ont été éclaircies d'un
ton : pensées pour une multiplication, le rouge sombre et le violet ne
donnaient plus qu'un bordeaux et un prune ternes en remplacement.

Au banc : `outils/voir.sh v:peintures` (dix peintures sur le 4x4),
`v:peintures:0-8` (les carrosseries de la ville, une peinture chacune) et
`--banc-position=garage` dans une manche.

## Les bancs

La ville et son parc n'avaient **aucun banc** : on ne les voyait qu'en jouant,
donc seulement là où le hasard d'une manche menait. C'est exactement pour ça que
quatre carrosseries sont restées inutilisées et qu'un port sans bateaux n'a
choqué personne.

```bash
./outils/voir.sh "etalon,v:*" 8 /tmp/parc.png     # tout le parc, sur une pelouse
./outils/voir.sh "v:19,v:20,v:21,v:22" 9          # quatre véhicules, lisibles
./outils/voir.sh "v:0+,v:13+,v:16+,v:18+" 11     # la mitrailleuse sur quatre gabarits
godot --headless -s outils/respect.gd            # chapitre 6 : voler une voiture de gang
godot --headless -s outils/flotte.gd              # les mouillages et la navigation
./outils/apercu.sh FLOTTE /tmp/port.png port 120  # un morceau de ville, au port
```

- `v:<indice>` sort un véhicule bâti **comme le jeu le bâtit**
  (`FormesCarnage.voiture_kit`), avec son étiquette ; `v:*` les sort tous.
- `outils/flotte.gd` compte les cases d'eau, les cases de quai, les bateaux
  amarrés et leur répartition, puis vérifie les deux sens de la navigation : la
  terre arrête la coque, le large la laisse passer. Sur la manche `FLOTTE` :
  2 782 cases d'eau, 455 au bord d'un quai, 40 bateaux, 150/150 et 197/197.
- `outils/apercu.sh` bâtit un morceau **et ses huit voisins** sous l'ambiance du
  jeu, et le photographie. `port` cherche tout seul le premier mouillage — le
  chercher à la main sur six cent quatre-vingts tuiles n'est pas une façon de
  travailler.

## Ce qui reste

- Les catégories du guide (§7.1) qu'on n'a pas : **bus, taxi Xpress, train**
  (services publics), **tank et Pacifier** (militaires), **tow truck, hot dog
  van, ice-cream van** (utilitaires). Le bus et la limousine existent en voxels,
  pas dans le kit.
- ~~Le **lance-flammes monté** et le **canon à eau** du camion de pompiers
  (§6.2)~~ — **faits le 11/09**, voir « Le camion de pompiers » plus bas.

## Le camion de pompiers : la lance se tient (§6.2)

Au volant du camion (gabarit 18), ESPACE ne tire pas : il **arrose**. Le jet
part du toit de la cabine et porte deux cent quarante pixels dans un cône
étroit (`VilleVivante.arroser_devant`) : il éteint ce qui brûle dedans et
**couche les passants** — poussés le long du jet, puis en fuite dans son sens
— sans blesser personne. C'est ce qui en fait autre chose qu'une mitrailleuse
bleue, et la seule façon de traverser une foule sans l'écraser ni la fâcher.
Le camion de la ville arrose avec le même jet, visible chez tout le monde
(`arrose`, douzième champ de l'instantané) ; celui d'un autre joueur aussi
(`je` dans son paquet : 1 eau, 2 feu).

**Le lance-flammes** est laissé par le patron d'un repaire à la première
mission rendue (`CONCEPTION-REPAIRES-DE-GANG.md`). `F` au volant bascule la
lance eau/feu — une touche de plus, c'était une de trop ; l'affaire du lieu,
en pleine rue au volant du camion, c'est la lance. Le feu porte cent
soixante-dix pixels : les passants grillent (trois points de tôle par
seconde, accumulés, car leur tôle est un entier), les voitures des autres
brûlent (quarante-cinq par seconde), un foyer s'allume au bout du jet toutes
les six dixièmes — et c'est de là que part l'incendie, l'alerte, les
pompiers, la police (un coup de feu à chaque foyer). Il ne touche pas les
autres joueurs : ils ne se blessent qu'en arène.

⚠ **« On la voit arroser » n'était vrai nulle part** : le feu baissait sous
la lance de l'IA, sans jet. Le jet est des gouttes en cubes (`jet_d_eau`,
cent quarante, une seconde) lancées à trente unités par seconde sous vingt de
gravité : l'arc retombe à vingt et une unités, la portée de la simulation est
à vingt-quatre — ce qu'on voit tomber est ce qui mouille. `local_coords` est
à faux : les gouttes parties restent où elles sont quand le camion tourne,
sinon tout le jet pivotait d'un bloc, comme un bâton bleu accroché au capot.
Les flammes (`flammes_de_lance`) sont plus grosses, plus lentes, MONTENT au
lieu de retomber, passent du jaune au rouge puis à la fumée, unshaded — et
portent une lumière orange au bout, pour la nuit.

**Là où le jet retombe, la rue le montre** : une éclaboussure (un émetteur
posé dans le monde, au point de chute, pas sur le camion — elle reste où l'eau
tombe) et une **flaque** tous les sept dixièmes, disque sombre et translucide
avec un reflet de ciel au milieu, qui s'efface en douze secondes. Sur la
chaussée seulement : sur l'herbe, l'eau s'en va dans la terre, et un disque
gris sur une pelouse se lisait comme une tache de boue. Vingt-quatre flaques
au plus. Sans elles, l'eau disparaissait dans le bitume comme si elle n'y
était jamais tombée.

⚠ **Le souffle de la lance est synthétisé** (deux passe-bas sur du bruit
blanc, en boucle, comme la pluie de `meteo.gd`) ; le feu prend
`lance_flammes.ogg`, relancé tant qu'on tient.

Bancs : `outils/atelier.gd` §6 (l'eau) et §7 (le feu) ; photo :
`--banc-modele=18 [--banc-feu]` dans une manche solo.
