# Les intérieurs de repaire — conception et réglage à la main

Huit appartements achetables dans les repaires de Carnage. Tout tient dans
`jeux/carnage/interieurs.gd` ; les modèles sont le **Furniture Kit** et le
**Food Kit** de Kenney (CC0), copiés dans `modeles/kenney/interieur/` et
`modeles/kenney/nourriture/`.

## Voir un intérieur

```
./outils/vitrine.sh taudis            # -> /tmp/vitrine/taudis.png
./outils/vitrine.sh penthouse "" 120  # azimut 120° au lieu de 34
./outils/vitrine.sh loft "" 34 78     # vue presque à la verticale (le plan)
```

Le banc bâtit l'appartement comme le jeu le fera, escamote les deux façades qui
sont entre la caméra et la pièce, et recadre la photo sur le sujet. Le rendu se
REGARDE : c'est comme ça qu'on voit qu'un canapé traverse un mur.

## Le catalogue

| id | nom | prix | quartier |
|---|---|---|---|
| `taudis` | Le Taudis | 0 | cités |
| `ouvrier` | L'Appart ouvrier | 12 000 | vieille ville |
| `planque` | La Planque | 24 000 | zone industrielle |
| `atelier` | L'Atelier | 38 000 | port |
| `pavillon` | Le Pavillon | 55 000 | banlieue |
| `poste` | L'Ancien poste | 72 000 | rues commerçantes |
| `loft` | Le Loft | 110 000 | quartier des bureaux |
| `penthouse` | Le Penthouse | 250 000 | centre d'affaires |

## Le plan est un dessin

Une grille de `2·largeur+1` sur `2·hauteur+1` caractères. Les positions
IMPAIRES sont les tuiles, les PAIRES les arêtes entre tuiles.

```
"---F---F-",      arêtes horizontales : - mur   D porte   A arche large
"|. . . .|",      tuiles : espace = dehors, . = sol n°0, 1..9 = sol n°1..9
"|       |",                              F fenêtre   B baie vitrée   H muret
"|. . . .|",      arêtes verticales : | mur, mêmes lettres
"|     -D-",
"|. . .|1|",
"-D-------",
```

Une tuile fait UNE unité de kit et DEUX mètres de jeu (`ECHELLE = 2.0`) : un mur
Kenney mesure 1,29, soit 2,58 m sous plafond, et le personnage 1,80 m passe
dessous. Les poteaux d'angle sont posés tout seuls là où deux murs se joignent.

Le caractère de la tuile choisit sa couleur dans `"sols"` : `.` prend la
première, `1` la deuxième, et ainsi de suite. C'est ce qui distingue un
carrelage de salle d'eau d'un parquet de séjour sans changer de modèle.

## ⚠ La convention du kit : LA FAÇADE REGARDE +Z

Ça ne se devine pas et ça a coûté deux passes complètes. Un modèle du Furniture
Kit montre ses portes, son écran, son assise **du côté +Z**, et son volume part
donc vers l'arrière, en −Z. Ce n'est pas l'avant habituel d'un moteur 3D (−Z).

Conséquence pour `contre()` : adossé au mur **nord**, un meuble ne tourne
**pas** (`r = 0`) ; au mur sud `r = 2` ; à l'ouest `r = 1` ; à l'est `r = 3`.

Pourquoi ça ne se voit pas : sur une vue de trois quarts, un placard vu de dos
et vu de face ont exactement la même silhouette. On peut retourner les
soixante-dix meubles d'un appartement sans que rien ne saute aux yeux.

La table est VÉRIFIABLE, et c'est la seule preuve qui vaille :

```
GODOT=<godot> LIBGL_ALWAYS_SOFTWARE=1 HOME=/tmp/hv \
  xvfb-run -a -s "-screen 0 800x600x24" $GODOT --path . \
  --rendering-driver opengl3 res://outils/faces.tscn \
  --modeles=<liste,séparée,par,virgules> --cote=sud \
  --sortie=res://_transfert/vitrine/faces-sud.png
```

`outils/faces.gd` photographie les modèles alignés, une fois depuis le nord et
une fois depuis le sud, caméra orthogonale STRICTEMENT de niveau — une plongée,
même de quatorze degrés, décale tout le cadre le long de l'axe de visée et il
ne reste qu'une rangée sur huit. La face qui montre les poignées est le sud.

## Reprendre un meuble à la main

Chaque meuble est UNE ligne de la liste `"meubles"`, et deux fonctions
seulement :

```gdscript
pose("loungeSofa", 2.45, 1.95, 2)              # centre au sol (x, z) en tuiles, quart de tour
pose("n:soda-can", 1.42, 1.58, 0, 0.33)        # y = hauteur (posé sur une table de 0,33)
pose("n:barrel",   2.60, 0.40, 0, 0.0, 2.4)    # taille = facteur d'échelle
contre("kitchenSink", "N", 1.07, 0)            # adossé au mur nord de ligne z = 0, à x = 1,07
contre("toilet", "E", 2.72, 5, 0.10)           # décal = on l'écarte du mur de 0,10
contre("bathroomMirror", "N", 3.32, 2, 0.0, 0.72)   # accroché à 0,72 de haut
```

- `r` : `0` regarde le nord, `1` l'ouest, `2` le sud, `3` l'est.
- `contre` calcule la profondeur du meuble tout seul (il MESURE le modèle) :
  écrire la position du mur suffit, on ne recalcule rien quand on change de
  modèle.
- `taille` est là pour rattraper un modèle qui sort trop grand ou trop petit.
  Le Food Kit est déjà réduit d'office (`ECHELLE_NOURRITURE = 0.18`) : une
  pomme Kenney fait vingt centimètres, elle en ferait quarante à l'échelle du
  jeu.
- ⚠ `lampWall` et `toilet` ont le dos à l'envers dans le kit (leur volume part
  vers +Z) : ils sont listés dans `A_ENVERS` et `contre` les retourne. Un
  nouveau modèle qui entre dans un mur au lieu de s'y adosser va là.

Après une retouche : `./outils/vitrine.sh <id>` et on regarde.

## Les couleurs

Le kit n'a pas de texture : chaque surface porte une matière NOMMÉE (`wood`,
`carpet`, `carpetBlue`, `carpetDarker`, `carpetWhite`, `metal`, `metalDark`,
`_defaultMat`, `lamp`, `glass`). Un intérieur les repeint par table :

- `"teintes"` — la coque (murs, sols, poteaux) ;
- `"sols"` — la couleur de chaque type de sol, dans l'ordre des chiffres du plan ;
- `"teintes_meubles"` — le mobilier.

C'est ce qui fait qu'un même canapé sort brique au taudis et anthracite au
penthouse. La matière `lamp` devient émissive d'office : sans ça, un abat-jour
vu de trois quarts n'est qu'une boîte blanche.

## La planche de vignettes

`outils/planche.sh` n'existe pas : c'est `outils/planche.gd` / `.tscn`, lancés
comme la vitrine, qui photographient les 202 modèles des deux kits À LA
VERTICALE, chacun dans une case d'un damier de seize colonnes, sur fond
transparent — plus `_transfert/vitrine/gabarits.json`, le tableau des
encombrements. Ces deux fichiers alimentent l'éditeur de plan web (« l'Établi ») :
un modèle ajouté au dépôt n'y apparaît qu'après avoir relancé la planche.

```
GODOT=<godot> LIBGL_ALWAYS_SOFTWARE=1 HOME=/tmp/hv \
  xvfb-run -a -s "-screen 0 800x600x24" $GODOT --path . \
  --rendering-driver opengl3 res://outils/planche.tscn
```

⚠ La vignette est rendue à l'échelle de la case, pas à celle du modèle :
l'éditeur la redessine dans un carré de côté `max(largeur, profondeur)` centré
sur l'emprise. Changer `PAS` ou le centrage d'`Interieurs._instancier` décale
toutes les silhouettes.

## L'Établi (éditeur 3D web)

`outils/paquet.py` sort `_transfert/vitrine/paquet.b64` + `paquet-index.json` :
les 202 modèles des deux kits, aplatis par nom de matière, transformations de
nœuds cuites dans les sommets, positions quantifiées en entiers courts, le tout
gzippé (1,5 Mo → 0,3 Mo). C'est ce que l'éditeur web charge pour bâtir les
pièces en trois dimensions avec three.js, sans analyseur glTF ni requête réseau.

À relancer après tout ajout de modèle, en même temps que la planche :

```
python3 outils/paquet.py
```

⚠ L'index donne des DÉCALAGES EN OCTETS dans le tampon détendu : ajouter un
champ au format sans régénérer les deux fichiers ensemble donne des maillages
en charpie, sans le moindre message d'erreur.

## Vérifier avant de photographier

`python3 outils/empreintes.py` d'abord (une fois par changement de kit) :
il RASTÉRISE les triangles de chaque modèle en une grille de 16 sur 16 avec la
hauteur de chaque case. C'est indispensable — à la boîte englobante, un bureau
d'angle, un canapé d'angle ou une chaise à pieds sont des blocs pleins et
« chevauchent » tout ce qu'on range dans leur creux ; aux SOMMETS seuls, un lit
lowpoly ne marque que ses huit coins et son matelas passe pour du vide.

`python3 outils/verifier.py` relit le catalogue résolu et signale ce qui ne se
voit pas à l'œil sur une vue de trois quarts :

- un meuble dont le DEVANT donne sur une cloison ou sur le vide ;
- un meuble mural (placard haut, hotte, miroir, patère) dont le dos ne touche
  aucune cloison ;
- un siège qui tourne le dos à sa table, un canapé qui tourne le dos à la télé ;
- deux emprises RÉELLES qui s'interpénètrent de plus de 12 cm de côté ;
- un meuble qui FRANCHIT le plan médian d'une cloison. On mesure bien le
  franchissement du plan médian, et non le recouvrement de l'épaisseur du mur :
  celle-ci vaut 0,052 tuile, si bien que l'ancien seuil de 0,055 ne pouvait
  jamais se déclencher — le contrôle ne voyait que les meubles traversant de
  part en part. Le meuble doit tenir ENTIÈREMENT d'un côté, à 3 cm de débord
  près : comparer au seul côté de son centre laisserait passer celui qui a
  fini de traverser ;
- un meuble À CHEVAL SUR DEUX PIÈCES : sa façade dessert l'une, son corps est
  dans l'autre. Les pièces viennent d'un remplissage par diffusion sur le plan,
  où **une porte sépare autant qu'un mur** — sans cela tout le logement ne fait
  qu'une pièce et le contrôle ne voit rien ;
- un meuble planté DEVANT UNE PORTE : on garde l'ouverture (0,5 tuile) sur
  0,42 tuile de part et d'autre, soit un mètre de passage. C'est le contrôle
  qui a fait déplacer trois portes de plan et agrandir la salle d'eau du
  Taudis — une tuile ne peut pas tenir une douche, un WC, un lavabo ET son
  propre passage.

⚠ Deux modèles ont le volume vers +Z (`lampWall`, `toilet`) : leur devant est à
l'opposé de tous les autres, le contrôle le sait, `contre()` aussi.
⚠ Un meuble en L (`deskCorner`, `loungeSofaCorner`, `loungeDesignSofaCorner`)
déclenche un faux chevauchement avec ce qui se range dans son creux : sa boîte
englobante couvre le vide de l'angle. C'est le seul faux positif connu.

Sur la première passe, ce contrôle a trouvé 47 meubles à retourner sur les huit
intérieurs — dont vingt-quatre rien que dans le Taudis. Aucun ne se voyait sur
les photos sans les chercher.

## Rien ne fusionne : `outils/decoller.py`

La règle du coffre — il doit rester SEUL, pas fondu dans une file de meubles —
vaut pour le reste du mobilier. Mais tout contact n'est pas un défaut : une
file de cuisine, un lit et sa table de chevet, une table et ses chaises, un bar
et ses tabourets, une télé sur son meuble, une bibliothèque à côté du bureau
SE LISENT comme un ensemble voulu. Une poubelle contre un meuble télé, une
bibliothèque contre une baignoire : non — ça fait un bloc informe.

Chaque modèle reçoit donc une FAMILLE (cuisine, bar, lit, repas, bureau, salon,
rangement, eau, poubelle, déco, coffre) et une MOBILITÉ — qui cède le passage :
une poubelle bouge, une baignoire est scellée. Deux familles qui se touchent
sans figurer dans la liste des voisinages admis sont un défaut ; l'outil écarte
le plus mobile des deux du plus petit décalage qui résout le contact sans rien
casser d'autre (mur, porte, chevauchement, orientation, dégagement du coffre),
et exige un vrai vide de 16 cm pour que l'écart se voie.

Deux pièges, corrigés :

- **le contact À TRAVERS UNE CLOISON.** Une bibliothèque et une baignoire dos à
  dos de part et d'autre d'une paroi ont des emprises voisines dans la grille
  et passent pour collées. On teste donc si une cloison dure coupe le segment
  entre les deux centres. Ce seul test a fait tomber la moitié des signalements
  (18 → 8) ;
- **le meuble qui change de pièce pour se dégager.** Une chaise de table qui
  finit de traverser la cloison est « d'un seul côté » et satisfait la
  géométrie — dans la chambre. Les quatre coins du meuble doivent rester dans
  la pièce que dessert sa façade.

    python3 outils/decoller.py     # imprime les pose() prêts à recopier

⚠ Un meuble en L (`deskCorner`, `loungeSofaCorner`, `loungeDesignSofaCorner`)

## Le coffre

Chaque repaire a **un** coffre, et un seul : c'est là que le joueur dépose son
argent. Kenney n'en fournit pas, il est donc fabriqué à la main —
`outils/coffre.py` écrit `modeles/interieur/coffre.glb` en boîtes, dans le
style du kit : faces plates, pas de texture, une matière NOMMÉE par pièce
(`acier`, `acierClair`, `acierSombre`, `laiton`, `lamp`) pour qu'il se repeigne
avec le reste de l'intérieur.

⚠ La diode s'appelle `lamp` À DESSEIN : `Interieurs._teinter` rend émissive
toute matière de ce nom, donc le coffre se repère dans une pièce sombre sans
une ligne de code de plus.

Le préfixe `c:` désigne ce qui n'est pas Kenney (`_chemin`). Le jeu n'a pas à
fouiller la scène pour le trouver :

```gdscript
Interieurs.coffre("pavillon")   # -> {"p": Vector2(3.35, 3.844), "r": 2}
```

et `batir()` pose en plus un méta `coffre` sur la racine, avec la position du
nœud. Un intérieur sans coffre déclenche un `push_error` : c'est le seul meuble
dont l'absence est une faute.

Après tout ajout de modèle maison : `python3 outils/coffre.py`, puis
`outils/paquet.py`, `outils/empreintes.py` et la planche — sinon l'éditeur web
et le contrôle ne le connaissent pas.

## Les collisions sortent du dessin

Elles ne sont écrites nulle part : `Interieurs.libre()` et
`Interieurs.degager()` les déduisent du **même dessin** que les murs qu'on voit,
et les emprises des meubles sont **mesurées** sur les modèles. C'est le parti du
hub (`modeles/voxel/plan.json`) : une table de collisions tenue à côté du plan
aurait vieilli au premier meuble déplacé, sans que personne s'en aperçoive avant
de traverser un canapé.

Tout est **en tuiles**, comme le dessin et comme `coffre()` — pas en unités de
monde. L'appelant multiplie par `ECHELLE`. Mélanger les deux repères ne se voit
pas : ça donne juste des murs deux fois trop loin.

- `RAYON_MARCHE = 0,14` tuile, soit un bonhomme de 56 cm de large. Essayé à 0,22
  d'abord, en croyant prendre une marge : les huit repaires sont devenus
  impraticables, portes comprises — une porte du kit n'ouvre que sur 0,8 tuile.
- Un meuble de moins de 30 cm de haut ne bloque pas (tapis, assiette), ni rien
  de posé à `y > 0` : bloquer une casserole condamnait la moitié d'une cuisine.
- Les rotations du plan sont des quarts de tour, donc une emprise reste toujours
  alignée sur les axes : tout est `Rect2`, jamais un rectangle tourné.
- `PASSAGES = ["D", "A"]` : on ne saute pas par la fenêtre d'un repaire, et un
  muret arrête aussi.

## Le banc de marche

```
godot --headless -s outils/marche.gd            # les huit repaires
godot --headless -s outils/marche.gd -- --plan  # + la carte de chacun
```

Il inonde chaque appartement **depuis sa porte**, avec le gabarit du joueur, et
répond aux trois questions qu'une photo ne pose jamais : entre-t-on, le coffre
est-il atteignable, reste-t-il du sol coupé du reste. Il mesure la **plus
grosse** poche perdue, pas leur total — trois recoins de sept cases dans trois
pièces différentes sonnaient comme une chambre condamnée. Le seuil est d'**une
tuile** : en dessous c'est le jour entre un lit et un bureau, au-dessus c'est
une pièce qu'on a condamnée en meublant.

Ce qu'il a trouvé du premier coup, et qu'aucune vitrine ne montrait :

- **Le Taudis** — le porte-manteau était planté devant la porte d'entrée, entre
  l'évier au nord et les cartons à l'est : 97 % du sol inatteignable, on entrait
  dans un sas de deux pas. Il est passé contre le mur ouest.
- **L'Appart ouvrier** — le fauteuil barrait la seule porte du séjour, et le
  meuble de télé bouchait l'autre côté : 80 % de l'appartement coupé de
  l'entrée. Il est revenu près du canapé, face à la télé.

Les huit passent (`REPAIRES PRATICABLES.`), à des recoins près qui sont
affichés, jamais tus.

## On entre chez soi

À pied, sur SA planque, `F` ouvre la porte. L'appartement qu'on y trouve se
déduit du **quartier** de la planque (`Interieurs.pour_quartier`) : même
planque, même appartement chez tout le monde, sans qu'un octet passe par le
réseau — c'est la règle de toute la ville. Le centre d'affaires donne le
penthouse, les cités le taudis, le port l'atelier.

Dedans, `F` sert deux fois et la ligne du HUD dit toujours laquelle : au
**coffre**, on dépose et on achète les travaux ; à la **porte**, on ressort.
Déposer depuis le trottoir marchait avant et ne racontait rien — on n'avait
aucune raison d'avoir un appartement. Au volant, `F` dépose toujours : on ne
descend pas de voiture pour porter une liasse.

Deux décisions de mise en œuvre :

- **On sort de la boucle.** Chez soi : ni tir, ni portière, ni police, ni
  heurts. Laisser tourner le reste voulait dire prendre une balle à travers un
  mur qui n'existe pas dans la simulation extérieure, sans même voir d'où elle
  vient. `_position` ne bouge pas pendant le séjour, donc les autres joueurs
  voient quelqu'un d'immobile sur sa planque — ce qui est exactement ce qui se
  passe.
- **L'intérieur est bâti loin SOUS la ville** (`Carnage.SOUS_SOL`), pas à sa
  place. Cacher la ville demanderait de la ranger sous un nœud à elle, soit
  trois cents `monde().add_child` à reprendre dans le fichier le plus chargé du
  jeu, pour un gain nul : la caméra regarde vers le bas, ce qui est au-dessus
  d'elle n'est jamais dans le cadre.

La caméra ne suit pas : elle cadre l'appartement entier, comme la vitrine. Un
six-mètres-sur-huit ne demande pas de suivi, et un plan qui bouge dans une pièce
donne le mal de mer.

`--banc-dedans` entre chez soi au coup d'envoi. Une planque s'achète après
plusieurs minutes de jeu, et sans ce raccourci l'intérieur ne serait jamais
photographié avant livraison — c'est exactement le trou par lequel les huit
appartements sont restés invisibles pendant des semaines.

## Juger l'échelle : le pantin

```
./outils/vitrine.sh taudis "" 0 72 pantin
```

Le cinquième argument pose le **personnage du jeu** à l'entrée, et `0 72` est
l'angle de la caméra de Carnage : la photo montre alors ce que le joueur verra.
Un appartement se juge beau tout seul ; rien ne dit qu'on y tient debout tant
qu'on n'a mis personne dedans.

Le banc de marche simule aussi le trajet **porte → coffre** au pas réel du jeu,
à travers `Interieurs.degager` : l'inondation dit qu'un chemin existe, la marche
dit qu'on l'emprunte avec les vraies constantes. Deux questions différentes, et
c'est la seconde qui casse — un pas trop long saute par-dessus une porte d'une
tuile et le joueur rebondit contre le chambranle.

Il signale au passage un **coffre trop près de la porte** (moins d'1,6 tuile) :
on déposerait sans entrer, et l'appartement ne servirait plus à rien. Le
Pavillon (1,0) et L'Ancien poste (0,8) sont dans ce cas — à replacer, c'est une
décision de décoration, pas un défaut de praticabilité.

## Ce qui reste à faire

- Rapprocher le coffre du fond dans le Pavillon et L'Ancien poste (voir
  ci-dessus), puis repasser `outils/verifier.py`.
- La boutique : aujourd'hui la planque s'achète au prix de `PlanVille`, et
  l'appartement suit le quartier. Une vraie boutique montrerait le catalogue,
  ses prix et ses résumés avant l'achat.
- Brancher l'interaction sur la garde-robe et le garage (le coffre est fait).
- Vérifier le tout en partie réelle : le branchement compile et les intérieurs
  sont photographiés à l'angle du jeu, mais aucune manche ne l'a encore joué.
