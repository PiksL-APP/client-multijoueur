# La montée du niveau de recherche

*Phase 8 du guide « GTA 2 Voxel » (§5). Six crans, quatre corps, et ce qui
change à chacun.*

## Six crans, pas cinq

`PALIERS = [40, 115, 230, 400, 620, 900]`. Le sixième a été ajouté avec cette
phase : à cinq, l'hélicoptère était le dernier mot, et une jauge dont le
dernier cran arrive à la moitié de ce qu'on peut faire en une manche cesse de
menacer. Neuf cents points, c'est une manche à saccager sans jamais repasser
au garage.

| cran | ce qui arrive |
|---|---|
| 1 | une voiture de patrouille |
| 2 | la police descend de voiture |
| 3 | **le SWAT** : fourgon qui débarque quatre hommes |
| 4 | barrages aux carrefours |
| 5 | **agents spéciaux** + l'hélicoptère |
| 6 | **l'armée et son char** |

Les trois crans qui changent la NATURE de la réponse s'annoncent à l'écran
(« LE SWAT ARRIVE », « AGENTS SPÉCIAUX », « L'ARMÉE — UN CHAR VOUS CHERCHE »),
et seulement en montant : sinon le joueur découvre le char en le percutant.

## Quatre corps

| corps | pv | cadence | dégâts | portée | carrosserie | tenue |
|---|---|---|---|---|---|---|
| police | 4 | 1,15 s | 9 | 640 | voiture de police | bleu |
| SWAT | 7 | 0,78 s | 13 | 700 | fourgon | bleu de nuit |
| agent spécial | 9 | 0,58 s | 16 | 780 | berline sport noire | noir |
| armée | 12 | 0,64 s | 20 | 860 | camion olive | olive |

Sans ces quatre lignes, monter d'une étoile ne changeait que le NOMBRE de
voitures, et cinq étoiles ressemblaient à trois avec plus de bruit.

**Ce sont tous des `PATROUILLE`.** Le corps ne change ni le genre du véhicule,
ni la conduite, ni le radar : un fourgon du SWAT poursuit comme une voiture de
police parce que c'est la même fonction qui le conduit. C'est la seule raison
pour laquelle cette phase tient dans un fichier plutôt que dans six.

**La police ordinaire reste de la partie même à six étoiles** (le tirage lui
laisse sa part) : une rue où il n'y a QUE des chars n'a plus l'air d'une ville
en panique, elle a l'air d'un niveau de jeu.

## Le fourgon se vide

Arrivé à trois cents pixels de sa cible, le fourgon s'arrête et débarque
**quatre hommes**. C'est ce qui fait de trois étoiles autre chose que « deux
étoiles avec une voiture de plus » : on ne sème pas quatre types à pied en
tournant à droite. Il ne se vide qu'une fois — vérifié au banc.

## Le char

Il ne poursuit pas, il **canonne**. Il roule moins vite que tout le monde
(190 contre 300 et plus), encaisse 320 points, et tire un obus toutes les deux
secondes et demie dès qu'il vous tient à sept cents pixels. L'obus ne vole
pas : l'hôte décide où il tombe et souffle tout dans un rayon de cent vingt
pixels — voitures comprises. C'est la seule attaque du jeu qui ne fait aucune
différence entre celui qui est à pied et celui qui est en tôle.

⚠ **La dispersion doit dépasser le souffle.** À 110 pixels de dispersion pour
120 de souffle, l'obus touchait **deux cents fois sur deux cents** au banc : le
char ne ratait jamais, quarante-six points toutes les deux secondes et demie,
et la seule réponse était de quitter l'écran. À 240, un tir sur deux porte
(99/200 mesuré) — on peut tenir la rue si on bouge.

## Ce qui se voit

- **le gilet.** Les quatre corps ont d'abord été distingués par la seule
  couleur passée à `pieton`, qui ne teint que la calotte et le fanion : au
  banc, les quatre uniformes étaient rigoureusement identiques, parce que le
  corps du personnage vient de l'atlas Kenney et ne se teinte pas. D'où la
  plaque de couleur sur le torse — précisément ce qu'une caméra en plongée
  voit d'un homme debout ;
- **le char.** Aucun kit n'a de char : on prend le camion, on l'habille en
  olive, on lui pose deux chenilles, une tourelle et un canon qui dépasse du
  capot. ⚠ Les chiffres sont ceux de la caisse, **mesurés** (`get_aabb` :
  6,25 × 2,75 × 3,18) — la tourelle a d'abord été plantée à 1,5 de haut,
  c'est-à-dire à l'intérieur de la carrosserie, et le char sortait du banc en
  simple pick-up vert. On ne devine pas la taille d'un modèle importé ;
- **une sixième étoile** au tableau de bord. La rangée se resserre de 30 à 26
  pixels pour garder la même largeur : elle est centrée en haut de l'écran, et
  une rangée qui s'élargit décale tout le reste.

## Ce que le réseau porte

Le **corps** et le **canon** voyagent dans l'instantané, en fin de ligne (les
anciens clients lisent les lignes plus courtes sans broncher). Sans eux, les
quatre hommes d'un fourgon apparaissaient chez les autres joueurs en simples
îlotiers, et le char sans son canon.

## Le banc

```bash
godot --headless --path . -s outils/recherche.gd   # crans, corps, fourgon, char, réseau
./outils/voir.sh "u:0,u:1,u:2,u:3,d:char" 7        # les quatre tenues et le char
```

Il vérifie notamment, par mille tirages à chaque cran, **qu'on ne peut pas
tomber sur l'armée à deux étoiles** : c'est le genre de `>=` qu'on écrit à
l'envers une fois sur trois et qui ne se voit jamais en jouant.

## Ce qui reste

- les **agents spéciaux** ont une arme « silencieuse » dans le guide : chez
  nous ils tirent plus vite et plus fort, mais le silencieux n'a pas d'effet
  (nos coups de feu de PNJ ne font pas monter la recherche de toute façon) ;
- le guide parle de **véhicules blindés** au cran 6 : nous n'avons que le
  camion olive et le char ;
- **baisser** la recherche reste le garage de peinture, l'attente, ou les
  plaques de l'atelier (qui la gèlent). Changer de véhicule ne la baisse pas
  encore, alors que le guide le prévoit (§5.2).
