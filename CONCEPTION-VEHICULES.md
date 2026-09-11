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
- Le **lance-flammes monté** et le **canon à eau orientable** du camion de
  pompiers (§6.2) : nos pompiers éteignent tout seuls, le joueur ne tient jamais
  la lance.
