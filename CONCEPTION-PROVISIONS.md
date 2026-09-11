# La faim, la soif et la supérette

Deux jauges qui descendent, une boutique où les remonter, un sac qu'on porte et
un frigo qui garde le reste.

## Pourquoi maintenant

Une manche de Carnage n'a **pas de chrono** : on reste en ville tant qu'on veut.
C'est ce qui donne au jeu son intérêt — on rentre déposer son argent, on monte
son respect, on prend le train. C'est aussi ce qui lui enlevait toute raison de
s'arrêter : sans horloge, rien n'oblige à sortir de la voiture.

La faim et la soif remettent une **pendule**. Mais une pendule qu'on peut
remonter, ce qui n'est pas du tout la même chose qu'un compte à rebours : elle
ne dit pas « il vous reste quatre minutes », elle dit « il faut repasser à la
supérette », et ça se règle en trente secondes quand on sait où en trouver une.

## Les deux jauges

| | vide en | à pied |
|---|---|---|
| **FAIM** | 260 s | ×1,35 |
| **SOIF** | 200 s | ×1,35 |

**La soif descend plus vite que la faim**, et c'est voulu : l'eau est l'article
le moins cher de la boutique (40 $). On a donc un besoin fréquent et bon marché,
qui apprend le geste, et un besoin lent et coûteux, qui fait faire des courses.
Deux jauges à la même vitesse, ce serait une seule jauge dessinée deux fois.

**À pied on se dépense** d'un tiers de plus. Le facteur est petit à dessein :
assez pour qu'un long trajet à pied se paie, pas assez pour punir qui descend de
voiture — ce que le jeu passe son temps à demander.

**À zéro, le ventre ronge** : 2 points de vie par seconde et par jauge vide, soit
cinquante secondes à pleine vie avec une jauge à sec, vingt-cinq avec les deux.
De quoi comprendre, trouver une supérette et y arriver.

⚠ **On ne passe PAS par `_encaisser`.** Elle secoue l'écran, joue un choc et
retient un agresseur. Mourir de faim n'a ni coupable ni impact — c'est une
usure, et une secousse par seconde pendant cinquante secondes rendrait le jeu
injouable bien avant la mort.

⚠ **Le temps du ventre s'arrête à l'intérieur** (chez soi, dans un repaire). Ce
n'est pas du réalisme, c'est du confort : on entre chez soi pour ranger de
l'argent, pas pour se faire surprendre par une jauge qu'on ne voit plus.

⚠ **Les jauges vivent chez le CLIENT.** C'est un état personnel : personne
d'autre n'a besoin de savoir que vous avez faim, et la vie — qui, elle, voyage
déjà — suffit à raconter ce qui vous arrive aux trois autres. Les faire passer
par l'hôte, ce serait deux nombres de plus à quinze paquets par seconde pour une
information que personne ne lit.

## La supérette

**Un lieu par secteur**, tiré comme l'hôpital et la planque, dans la même liste
de candidats — donc jamais dans l'eau, jamais sur la voie ferrée, et **jamais
sur le pâté d'un autre lieu visitable** : deux portes au même endroit, c'est un
`F` qui ne sait plus à qui répondre. Sur la manche `PROVISIONS` : 171 boutiques
pour 221 secteurs, les 50 manquants étant les secteurs d'eau et de parc.

Elle se repère à un **vert d'eau** que rien d'autre ne porte : un carré au radar
(les quatre autres lieux sont des ronds — à cinq pastilles dans un cadre de cent
pixels, c'est la forme qui distingue, pas la teinte) et une pastille sur la
carte.

La façade est le modèle **`ville/building-small-d`** du kit : une boutique
d'angle avec sa vitrine et son auvent. ⚠ Elle était d'abord bâtie **en boîtes** —
un auvent, deux poteaux, deux carrés jaunes en guise de vitrines : ça tenait de
loin et ça ne tenait que de loin. La ville est faite de deux cent trente-neuf
modèles importés ; une façade à la main est la seule qui ne ressemble pas aux
autres.

⚠ **Le bâtiment est repoussé au fond de sa tuile.** Centré, il couvrait le pas
de porte : vu de dessus — et la caméra ne voit à peu près que ça — on n'avait
plus qu'un toit, sans le disque qui dit qu'on peut y entrer.

## Le menu

Le **menu s'ouvre tout seul** quand on entre sur le pas de porte. Pas de `F` :
le menu EST l'interaction, et une boutique où il faut appuyer sur une touche
pour voir qu'il y a une boutique, c'est une boutique que personne ne trouve.

⚠ On ne le rouvre pas tant qu'on n'en est pas **sorti** : sans ce garde, le
fermer d'un coup d'ÉCHAP le rouvrait à l'image suivante, puisqu'on n'avait pas
bougé d'un pixel.

Pourquoi un menu et pas des pastilles au sol comme l'atelier : huit articles,
chacun avec un prix ET deux effets chiffrés, ça ne tient pas dans la ligne
d'action du tableau de bord — et huit pastilles sur un trottoir, c'est un damier.

Comme le menu de triche, **la ville continue de tourner derrière** (c'est du
multijoueur ; un monde figé qui reprend d'un coup saute de trois rues), et c'est
le joueur seul qui est figé par `Commandes.saisie`.

⚠ **Deux menus peuvent être ouverts** (la triche par-dessus la boutique) :
écrire `saisie = _triche_ouverte` tout court rendait les commandes en fermant
l'un alors que l'autre était encore là. Et **se faire descendre devant la caisse**
ferme la boutique — sinon `saisie` restait posée et l'on ne pouvait plus bouger.

## Le catalogue

| article | prix | effet |
|---|---|---|
| bouteille d'eau | 40 $ | +55 soif |
| barre chocolatée | 45 $ | +22 faim · −8 soif |
| café | 55 $ | +4 faim · +26 soif |
| soda | 65 $ | +8 faim · +42 soif |
| sandwich | 95 $ | +45 faim |
| salade | 120 $ | +38 faim · +12 soif · +10 vie |
| burger | 150 $ | +68 faim · −10 soif · +6 vie |
| trousse de secours | 320 $ | +45 vie |

**Les prix montent du premier au dernier** : un menu qui monte se lit de haut en
bas, on descend jusqu'à ce qu'on ne puisse plus payer et on s'arrête. Mélangé,
il faut le relire en entier à chaque passage.

**Au moins un article donne soif** (la barre, le burger) : c'est ce qui empêche
de tenir la manche entière sur un seul achat. Sans ça, six burgers règlent les
deux jauges.

⚠ **Les prix sont ceux de la rue.** Un sandwich à 95 $ là où un passant lâche un
billet et un contrat en paie 620 : manger coûte une minute de travail, pas une
soirée. Trop cher, on préfère mourir de faim ; trop bon marché, on achète huit
burgers au départ et les deux jauges ne servent plus à rien.

⚠ **Les couleurs sont celles d'une liste, pas celles de l'aliment.** Le café et
la barre étaient peints de leur vraie teinte (deux bruns) : sur le fond sombre
du menu ils sortaient **aussi éteints** que les articles trop chers, qu'on grise
exprès. Le seul signal de la boutique ne voulait plus rien dire.

## Le sac, le frigo, la touche

**Six places en poche**, trente au frigo. Le sac est un dictionnaire et pas une
liste : trois sandwichs tiennent sur une ligne au lieu d'en aligner trois, et le
tableau de bord reste dans son coin.

⚠ Une ligne à zéro **disparaît** au lieu de rester : sans ça le tableau de bord
affichait « sandwich ×0 » et l'inventaire se remplissait de fantômes.

**Le frigo de la planque** est le garde-manger. Il n'a demandé **aucun modèle
neuf** — les huit appartements en avaient déjà un, posé là par décoration il y a
des semaines. C'est tout l'intérêt de reconnaître un poste à son *modèle* : le
meuble existe, il suffit de lui donner un sens. Même geste que le coffre, et
c'est voulu : `F` range, `E` reprend. Deux réserves dans la même pièce qui
s'ouvriraient de deux façons différentes, c'est une touche qu'on cherche à
chaque fois.

`outils/marche.gd` a immédiatement trouvé deux défauts que personne n'aurait vus :
`L'Ancien poste` n'avait **pas de frigo du tout**, et celui de `L'Atelier` était
**inatteignable**, coincé dans un angle entre le lit et l'évier. Tant qu'il
n'était qu'un meuble ça ne gênait personne ; du jour où l'on y range ses
provisions, il faut pouvoir s'en approcher.

⚠ **Les deux frigos ajoutés l'ont été à l'aveugle, et les deux étaient faux.**
Celui de l'Atelier a été reposé SUR le coffre (3,40 contre 3,50 : les deux
emprises se chevauchaient), celui de l'Ancien poste au milieu de la pièce, face
à la porte de la cellule et dans son dégagement. `marche.gd` ne le voit pas —
il répond « atteignable », et c'est vrai. C'est `outils/verifier.py` qui les a
pris, et c'est pour ça que la chaîne se lance EN ENTIER après tout meuble posé,
pas seulement le banc du sujet du jour. Le frigo de l'Atelier prend le début du
mur nord et le coffre l'angle ; celui du poste va dans l'angle nord-est, contre
le mur est, et la poubelle qui y était file de l'autre côté du bureau d'angle.

**`G` mange ou boit** — une touche, pas de menu. Elle prend dans les poches ce
qui répond au besoin le plus pressant. Trois touches pour choisir entre un
sandwich et une bouteille d'eau pendant qu'on se fait tirer dessus, personne ne
le fait deux fois.

⚠ **`le_mieux` choisit ce qui COMBLE, pas ce qui remonte le plus.** Le burger
rend 68 de faim, l'eau 55 de soif : « le plus gros chiffre » prend le burger.
Mais à 95 de faim et 10 de soif, le burger ne comble que 5 points — la bouteille
en comble 55. C'est toute la différence entre une touche utile et une touche qui
gâche, et c'est le premier cas du banc.

## Les bancs

```bash
godot --headless --path . -s outils/provisions.gd   # catalogue, sac, choix, ville, durées
godot --headless --path . -s outils/marche.gd       # le frigo est-il atteignable dans les 8 appartements ?
./outils/tableau.sh /tmp/menu.png superette         # le menu, panier à moitié plein
./outils/apercu.sh PROVISIONS /tmp/sup.png superette 55   # la façade dans la ville
godot --headless --path . --solo --banc-jeu=carnage --manche=150 --banc-position=superette
```

⚠ **Le pilote du banc part avec 900 $.** Il commence à zéro comme tout le monde
et ramasse ce qu'il renverse : en une minute de banc il n'avait jamais les
quarante dollars d'une bouteille d'eau, et la caisse — l'achat, le refus, les
poches pleines — ne passait donc **jamais** par une manche. Un joueur, lui, part
bien à zéro.

⚠ **Le pilote fait ses courses tout seul** dans `_naviguer_dans_la_superette` :
il ne peut pas appuyer sur les flèches (le menu lit le clavier physique), donc
sans cette branche il achèterait zéro article.

Au 11/09, sur une manche de 150 s : la boutique s'ouvre au pas de porte, une
bouteille achetée, l'inventaire la porte, la soif tombe à 69, `G` la boit, la
jauge remonte à 97 et la ligne quitte le sac. Toute la chaîne, en jeu.

## Ce qui reste

- **Les provisions ne voyagent pas.** Un joueur qui vous voit boire ne voit
  rien : la seule chose qui change chez lui, c'est votre barre de vie. C'est
  assez pour le jeu tel qu'il est ; une animation de consommation demanderait un
  message de plus.
- **Le frigo ne garde rien entre deux manches.** Comme l'argent du coffre, il
  vit le temps d'une partie.
- **Aucun aliment ne se ramasse dans la rue.** Les caisses lâchent des armes,
  des trousses et des billets ; un sandwich tombé d'un passant serait la façon
  la moins chère de survivre sans jamais entrer dans une boutique — à décider.
