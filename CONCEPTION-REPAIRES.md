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

### Trois postes, une touche chacun

`Interieurs.poste(id, genre)` retrouve les meubles qui se manipulent **par leur
modèle**, dans l'ordre écrit — pas de caractère à ajouter aux huit plans, pas de
table à tenir à côté. Un appartement qui gagne un portemanteau gagne sa
garde-robe le jour où on l'y pose. La garde-robe accepte le **lit** en dernier
recours : deux plans sur huit n'ont pas de portemanteau, et « on se change au
pied du lit » se comprend mieux qu'un appartement où l'on ne peut pas se
changer.

| poste | F | E |
|---|---|---|
| le coffre | ouvrir le **menu de la planque** : déposer, retirer, payer les travaux | **retirer** |
| la garde-robe | changer de tenue | — |
| la porte | ressortir (**au volant** si on a le garage) | — |

**Le menu de la planque** (`ui/planque.gd`, même charte que la supérette) a
remplacé le `F` à l'aveugle qui déposait puis achetait « le prochain » travail
sans le nommer : on payait cinq mille dollars un garage sans savoir ce qu'il
gardait. Le menu montre les trois travaux, leur prix, ce qu'ils font, et
lequel vient d'abord (l'ordre tient : coffre, arsenal, garage). Le premier
travail n'avait d'ailleurs **aucun effet** — il était payé pour rien, et le
menu le montrait bien : depuis, sans coffre-fort, la planque ne cache que
4 000 $ « sous le matelas » (`MATELAS`), le dépôt s'arrête là et le dit. Au
volant, `F` dépose seulement. `outils/tableau.sh /tmp/x.png planque`
photographie le menu.

**Retirer** manquait : le coffre était un puits, l'argent y entrait et n'en
sortait plus, et on ne pouvait pas ressortir avec de quoi payer un hôpital. Il
a fallu une seconde touche — empiler un troisième sens sur `F` rendait le geste
imprévisible, on venait chercher de l'argent et on repartait avec un arsenal.
`E` ne sert à rien d'autre chez soi : il n'y a pas de portière dans un salon.

**Se changer** est le geste de GTA : on rentre chez soi, on ressort avec une
autre tête. Le choix est gardé dans `Session`, donc il vaut aussi pour les
manches suivantes et pour le hub. Le changement part sur le réseau **une fois**,
à l'instant du changement, et pas dans le message de position — celui-là part
douze fois par seconde, et y glisser une clé de personnage coûterait cent fois
le prix de l'information. Chez les autres, la peau se change sur le pantin déjà
posé (`Personnages.habiller`) : le rebâtir couperait sa démarche.

⚠ **La porte passe avant la garde-robe.** Dans le Taudis, le portemanteau est à
quarante centimètres du paillasson : dans l'autre ordre on se changeait au lieu
de sortir, et on ne pouvait plus quitter le studio. Le banc de marche signale
maintenant tout poste à portée de la porte.

### Le garage, et le catalogue qu'on lit enfin

`_ranger_le_vehicule` gardait déjà la voiture qu'on ramène chez soi. Il manquait
de la **ressortir** : se relever après une mort annonçait « votre véhicule vous
attend » et il n'y avait rien devant la porte. Un message qui ment est pire
qu'un garage qui n'existe pas. Maintenant, quand on possède le garage et qu'une
voiture y dort, on ressort **au volant** — de chez soi comme après une mort — et
la ligne du HUD le dit avant qu'on appuie : une voiture qui apparaît sous le
joueur sans prévenir se lit comme un défaut. Elle porte son propre identifiant
(`ID_VOITURE_GARAGE`) : deux voitures du même numéro, et l'une efface l'autre de
la nappe chez les autres joueurs.

Les huit appartements ont un **nom** et un **résumé** depuis le premier jour, et
personne ne les avait jamais lus : on achetait « une planque » à un prix, sans
savoir qu'on achetait Le Penthouse ou Le Taudis. En arrivant sur une planque
libre, le résumé s'affiche deux secondes ; la ligne d'action porte le nom.

⚠ Le prix reste celui de `PlanVille`, pas celui du catalogue : c'est lui qui est
équilibré avec l'argent qu'on ramasse en ville, et afficher deux prix pour la
même porte ne se comprendrait pas. Le prix du catalogue continue de servir à la
vitrine et à l'éditeur web, qui ne connaissent pas `PlanVille`.

⚠ **Sans escamoter deux murs, on entre chez soi et on regarde un mur.** Un
appartement bâti tel quel est une boîte fermée, et la caméra du jeu regarde
depuis le sud : les façades qui donnent de ce côté sont entre l'œil et la pièce.
Le banc de photo les retirait depuis toujours — dans son coin, ce qui explique
que les vitrines étaient lisibles et que personne n'avait vu le problème.
`Interieurs.degager_la_vue()` est maintenant la SEULE implémentation, appelée
par le jeu et par le banc : la photo montre ce qu'on verra.

## Le banc du repaire EN JEU

```
./outils/chez_soi.sh penthouse
```

`vitrine.sh` photographie un intérieur sous des lumières de studio, posé à
l'origine, cadré sur son contenu : c'est ce qu'il faut pour juger une
décoration, et ça ne dit **rien** de ce que le joueur verra. Dans le jeu, le
même appartement est bâti six cents unités sous la ville, éclairé par l'heure
bleue de Carnage, et cadré par une caméra fixe à septante-deux degrés — trois
choses qui peuvent chacune le rendre illisible.

`outils/chez_soi.sh` reprend **les mêmes fonctions que le jeu** — `SOUS_SOL`,
`cadre()`, `degager_la_vue()`, `poser_pantin()`, `MatieresCarnage.ambiance()` —
pour que l'image ne puisse pas mentir par construction. C'est exactement le
piège de la vitrine : elle escamotait les deux façades de devant dans son coin,
donc le défaut « on entre chez soi et on regarde un mur » ne pouvait pas s'y
voir.

Premier défaut trouvé par lui : **la jauge de vie**. Dehors, elle fait un mètre
soixante au-dessus d'un personnage, sur une rue de vingt mètres — on la remarque
à peine. Chez soi, la caméra cadre huit mètres de large : la même barre verte
prend le sixième de l'écran, en travers de la cuisine. Et elle n'a rien à dire,
puisque chez soi on ne se fait pas tirer dessus. `poser_pantin()` l'éteint, donc
le jeu et les deux bancs l'éteignent ensemble. Restent l'anneau de couleur et le
pseudo, qui suffisent à se repérer.

### Des marques au sol, comme dans GTA 2

Un disque de couleur par chose à faire — **jaune** le coffre, **bleu** la
garde-robe, **vert** la porte — et on sait où aller sans lire une ligne de
texte. Sans elles, un joueur qui entre chez lui pour la première fois voit un
appartement meublé et rien qui dise que le coffre est un coffre : vus de dessus,
le portemanteau, le placard et le coffre ont exactement la même silhouette.

Elles ne sont **pas** posées par `batir()`. La vitrine juge la décoration : y
ajouter trois disques fluo empêcherait de voir si un canapé traverse un mur. Le
jeu et `chez_soi.sh` les posent, la vitrine non — seule différence assumée entre
les deux bancs.

Deux choses apprises en les posant :

- ⚠ **la dalle de sol fait cinq centimètres d'épaisseur** (mesuré : `floorFull`
  va de 0 à 0,05). Une marque posée à un centimètre était donc DANS le sol, et
  invisible. On l'a cherchée un moment en accusant la transparence, puis
  l'ombre, puis le tampon de profondeur ;
- **on se met DEVANT un meuble, pas dessus.** Une marque au centre du lit passe
  sous le matelas (le Penthouse a avalé la sienne), et un rayon mesuré depuis le
  centre du meuble se déclenche à travers lui — le coffre répondait de l'autre
  côté du lit. `point_de_poste()` donne le point où l'on se tient, et le jeu
  comme la marque l'appellent : deux calculs pour un même point, c'est un bouton
  qui ment tôt ou tard.
- ⚠ **devant, c'est du côté de la FAÇADE.** La première version « sortait » du
  gabarit par le plus court chemin, ce qui n'est pas devant : pour le lit de
  l'Atelier, le plus court chemin était les dix-huit centimètres entre le lit
  et sa table de chevet — la marque y était invisible et le joueur ne pouvait
  pas s'y tenir. On part maintenant de la façade (+Z à `r = 0`, la convention
  du kit), au rayon du JOUEUR, et l'on ne glisse ailleurs que si une chaise
  occupe le devant.
- **deux marques qui se touchent, c'est un `F` qu'on ne sait pas lire.** Dans
  le Taudis, le portemanteau à deux pas du paillasson posait sa marque bleue
  SUR la verte de la porte. Il est passé contre le mur est du séjour, entre le
  coffre et le canapé.

### L'heure se force, sinon le banc ment aussi

Le jour tombe tout seul, par cycles de quinze minutes (`MatieresCarnage.nuit()`).
Deux photos prises à trois heures d'intervalle sortaient donc l'une de nuit,
l'autre en plein jour — et on a cru une seconde à une régression du rendu.
`chez_soi.sh <id> <sortie> <nuit>` fixe l'heure : `0` plein jour, `1` pleine
nuit, **0,85 par défaut**, l'heure bleue de Carnage.

### Le cadrage se calcule, il ne se devine pas

La caméra ne suit pas le joueur chez lui : elle cadre l'appartement entier. Le
recul, lui, a demandé trois essais :

1. « le plus grand côté fois 1,25 » — le studio flottait au milieu d'un grand
   cadre noir, et un appartement large aurait débordé sur un écran étroit ;
2. la taille projetée à plat — l'appartement se retrouvait rogné de tous les
   côtés, parce que le bord du plan le plus **proche** de la caméra n'est pas à
   la distance du centre : il est trois mètres plus près, donc il grossit
   d'autant ;
3. la borne sur les **huit coins** de la boîte, en perspective, comme le banc de
   vitrine le fait depuis toujours. C'est le seul calcul qui ne se trompe
   jamais, et il ne coûte que huit tours de boucle.

Deux détails qui comptent : `Camera3D.fov` est le champ **vertical** (Godot
garde la hauteur), donc l'axe horizontal s'en déduit par la proportion RÉELLE de
la fenêtre — un joueur en fenêtre haute ne doit pas voir moins ; et le plan n'est
pas centré sur son sol, puisque les murs ne montent que du côté opposé à la
caméra. On relève donc le point visé d'une demi-hauteur de mur projetée.

 Un
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

⚠ **Un intérieur n'est pas à l'échelle de la ville.** La coque est bâtie à
`ECHELLE`, donc une unité de monde y vaut **un mètre** (un mur du kit fait
1,29 × 2 = 2,58 m sous plafond). Dehors, la ville est en pixels de jeu ramenés
par `Decor.ECHELLE`, et le pantin est taillé pour ELLE : posé tel quel dans un
appartement, il dépasse le plafond — la première photo montrait un géant dans sa
cuisine. `Interieurs.poser_pantin()` le MESURE et le ramène à 1,75 m ; le jour
où le casting change de modèle, il n'y a rien à reprendre.

Une subtilité qui a coûté un aller-retour : la boîte englobante d'un maillage
**animé** est plus grande que le personnage — Godot la gonfle pour couvrir
toutes les poses du squelette (1,82 de large sur 3,33 de *profondeur*, pour un
bonhomme qui n'a pas trois mètres d'épaisseur). Ramenée bêtement à 1,75 m, elle
donnait un personnage d'un mètre cinquante qui avait l'air d'un enfant. D'où
`MARGE_BOITE`, mesurée sur l'image contre un plafond de 2,58 m et des lits de
deux mètres.

Le banc de marche simule aussi le trajet **porte → coffre** au pas réel du jeu,
à travers `Interieurs.degager` : l'inondation dit qu'un chemin existe, la marche
dit qu'on l'emprunte avec les vraies constantes. Deux questions différentes, et
c'est la seconde qui casse — un pas trop long saute par-dessus une porte d'une
tuile et le joueur rebondit contre le chambranle.

Il signale au passage un **coffre trop près de la porte** (moins d'1,6 tuile) :
on déposerait sans entrer, et l'appartement ne servirait plus à rien.

## Où poser un coffre

```
godot --headless -s outils/marche.gd --coffre
```

Le banc propose les cinq meilleures places, écrites en `contre(...)`, prêtes à
coller. Une place valable est **adossée** à un mur, **dégagée de soixante
centimètres** (la règle du catalogue), **loin d'un passage**, et le coffre doit
y **rentrer** — un point à huit centimètres d'un angle est dégagé et pourtant
impossible, le coffre traverserait le mur d'à côté. Chacune de ces trois règles
a été ajoutée après que l'outil eut proposé, avec aplomb, une place que
`outils/verifier.py` refusait.

Résultat : **L'Ancien poste** passe de 0,8 à 4,8 tuiles — le coffre est monté
dans la cellule, à côté du placard, où il se lit comme un casier.

⚠ **Le Pavillon a passé des jours « sans aucune place »**, et c'était l'outil
qui était aveugle, pas le plan — deux fois :

- il comptait comme collé un meuble **de l'autre côté d'une cloison** : la
  table à manger de la cuisine, dos au mur nord de la chambre, interdisait tout
  ce mur. Le même aveuglement était dans la règle d'isolement du coffre de
  `outils/verifier.py`. Les deux testent maintenant si une cloison coupe le
  segment entre les deux meubles ;
- il prenait **toute arête ouverte** entre deux tuiles pour un passage à
  dégager. Entre deux tuiles d'une même pièce il n'y a rien, et « rien » n'est
  pas une porte : ce contrôle condamnait le milieu de chaque pièce et il ne
  restait que les tuiles closes sur trois côtés. Il ne regarde plus que les
  arêtes `D` et `A`.

Corrigé, l'outil trouve deux places dans le Pavillon, et le coffre est monté
**dans la chambre**, contre la cloison de la cuisine, à 2,3 tuiles de la porte
— là où l'on met un coffre dans une maison.

## Le contrôle tourne enfin partout

`outils/paquet.py` contenait **deux fois le même script**, collé bout à bout :
tout le travail se faisait deux fois, et ça ne se voyait qu'au temps
d'exécution. Ses chemins étaient en dur vers `~/mnt/client-multijoueur`, ce qui
marchait sur une machine et faisait échouer le contrôle des intérieurs partout
ailleurs — sans dire pourquoi. Les deux sont corrigés, et la chaîne complète
tourne d'un bout à l'autre :

```
python3 outils/paquet.py && python3 outils/empreintes.py
godot --headless --path . -s outils/vider.gd
python3 outils/verifier.py        # -> TOTAL 0
godot --headless -s outils/marche.gd
```

## La boutique : où loger

Sur la carte (`TAB`), sous la légende, tant qu'on n'a **pas** de planque :

| appartement | quartier | prix catalogue |
|---|---|---|
| Le Taudis | les cités | 0 |
| L'Appart ouvrier | vieille ville | 12 000 |
| La Planque | zone industrielle | 24 000 |
| L'Atelier | le port | 38 000 |
| Le Pavillon | banlieue pavillonnaire | 55 000 |
| L'Ancien poste | rues commerçantes | 72 000 |
| Le Loft | quartier des bureaux | 110 000 |
| Le Penthouse | centre d'affaires | 250 000 |

C'est la lecture **inverse** de `PAR_QUARTIER`, et c'est celle qui intéresse le
joueur : il ne se demande pas « qu'est-ce qu'on trouve ici », il se demande « où
vais-je pour avoir le penthouse ». Sans ce tableau on achetait la première
planque croisée, sans savoir qu'une autre rue donnait mieux — et les huit noms
du catalogue ne servaient à rien.

Deux règles : un quartier qui renvoie un appartement déjà pris (le parc donne le
pavillon, l'eau le taudis) ne fait **pas** une deuxième ligne, on garde le
premier ; et le tableau **disparaît** dès qu'on a sa planque, parce qu'à ce
moment-là c'est du bruit sur une carte qu'on ouvre pour se repérer, pas pour
faire des courses.

## Ce qui reste à faire

- La boutique : aujourd'hui la planque s'achète au prix de `PlanVille`, et
  l'appartement suit le quartier. Une vraie boutique montrerait le catalogue,
  ses prix et ses résumés avant l'achat.
- Le tableau « où loger » n'a été vérifié qu'en DONNÉES (`Interieurs.logements()`
  sort les huit lignes attendues) : son dessin sur la carte n'a pas encore été
  photographié, faute de pouvoir lancer une manche d'ici.
- Vérifier le tout en partie réelle : le branchement compile et les intérieurs
  sont photographiés à l'angle du jeu, mais aucune manche ne l'a encore joué.
