# Le train et la casse (guide §1.3)

La ville a toujours eu sa **voie ferrée** : une droite en biais d'un bord à
l'autre, le seul trait qui ne suive pas la grille — et c'est ce qui la fait lire
comme une ville plutôt que comme un quadrillage. Mais rien n'y roulait. C'était
une texture, peinte par le nuanceur du sol (`MatieresCarnage`, sol type 14 :
ballast, traverses, deux rails à ±0,75 unité de l'axe).

Deux rames y circulent maintenant, et elles font les deux choses que le guide
demande d'un train.

## 1. On le prend

Il marque l'arrêt tous les **11 000 px** (~110 tuiles) — sept quais sur la ligne
de Pikstown — et reste **sept secondes** portes ouvertes. À quai, `E` fait
monter comme dans une voiture ; il traverse alors la ville en ligne droite, à
**940 px/s** (au-dessus de `VITESSE_MAX` d'une carrosserie, qui est 760), sans
un feu, sans un barrage, et la police ne monte pas dedans.

⚠ **Un passager reste à pied.** Il n'est pas « au volant » d'un train : il ne le
conduit pas, ne le rend pas, n'a pas de tôle. `_pied` reste vrai et c'est
`_train` qui dit qu'on voyage — ce qui évite d'apprendre à toute la conduite, au
klaxon, à la radio et au réseau ce qu'est une locomotive.

⚠ **On ne saute pas d'un train lancé.** `E` en marche répond « attendez le
prochain quai ». Sauter à 940 px/s, dans ce jeu, veut dire réapparaître dans un
mur. Et l'on descend **du côté du quai** : de l'autre, on atterrit sur le
ballast, hors de portée de tout.

⚠ **Le train passe avant la portière.** Un quai est presque toujours au bord
d'une rue : testé après la voiture garée à dix mètres, on ne montait jamais dans
le train.

## 2. On se fait écraser par lui

Rien ne l'arrête : ni un piéton, ni une berline en travers, ni le char de
l'armée. C'est le seul danger du jeu qui **ne vise personne, ne se combat pas et
ne se négocie pas** — il passe, à l'heure. Une poursuite qui coupe la voie au
mauvais moment se termine là, pour le poursuivi comme pour les six voitures
derrière.

Le fauchage travaille dans le **repère de la voie** (abscisse le long, écart de
côté) et pas en distances point à point : une rame fait 336 px de long pour 60
de large, un rayon autour de sa tête laisserait passer le quart arrière.

⚠ **Un train à l'arrêt ne fauche personne.** Sinon la portière ouverte tuait
celui qui vient la prendre, et l'on ne pouvait tout simplement pas monter.

⚠ **Il ne fauche pas son propre passager.** Il est pile sous la rame — c'est la
définition d'un voyage. Le drapeau `train` voyage donc dans l'état que chaque
client annonce à l'hôte.

## Ce qui circule sur le réseau

**Une abscisse.** La voie est une droite que les quatre joueurs savent tracer :
diffuser des coordonnées serait payer deux fois pour la même information. Un
instantané porte, par rame : identifiant, abscisse, sens, vitesse, secondes
d'arrêt restantes.

⚠ **Le client extrapole.** À 940 px/s et huit instantanés par seconde, une rame
recopiée telle quelle avançait par bonds de 120 px — un train qui clignote d'une
rue à l'autre. Un train est le seul objet de la ville dont on sait exactement où
il sera dans un dixième de seconde : `age` compte les secondes depuis
l'instantané, et le client avance la rame tout seul entre deux.

## Les trois pièges, gardés ici pour ne pas y retomber

1. **Le passage d'unités.** `PlanVille.rail()` donne la voie en unités 3D (une
   tuile = 10), la simulation travaille en pixels (une tuile = 100). Sans la
   division par `Decor.ECHELLE`, les deux rames roulaient dans le coin
   nord-ouest de la carte, sur une voie dix fois trop courte. Le banc mesure
   donc la longueur de la ligne et vérifie que soixante points échantillonnés
   tombent **sur le ballast que le nuanceur dessine**.

2. **Le freinage qui se débranche tout seul.** La distance d'arrêt varie comme
   le carré de la vitesse : recalculée à chaque image, la condition « je dois
   freiner » redevenait fausse à soixante mètres du quai — le train relançait.
   Il passait devant sept quais d'affilée sans s'arrêter une fois, à chaque fois
   en ralentissant juste assez pour donner l'illusion d'y penser. **Le freinage
   se verrouille** (`freine`) jusqu'à l'arrêt.

3. **Le demi-tour au terminus, testé à chaque image.** « Suis-je au bout de la
   ligne ? » était vrai aussi à la première image du départ — la rame était
   encore à un dixième de pixel du terminus, elle repartait et se retournait
   aussitôt. Elle passait sa vie à faire des demi-tours sur place au bout du
   quai : **cinquante-cinq en cinq minutes**. Le demi-tour se fait maintenant à
   l'arrêt, et nulle part ailleurs.

Le banc compte donc les demi-tours (il en veut deux, pas cinquante) et les
arrêts (une quinzaine en cinq minutes : onze mille pixels à 940, plus sept
secondes de quai, font une vingtaine de secondes par saut). Un banc qui vérifie
seulement « la rame n'est pas sortie de la ligne » passe au vert sur un train
qui n'a jamais quitté le terminus.

## Le quai

⚠ **Il fait la longueur d'une rame**, pas seize unités. Trop court, il ne passait
que sous la motrice : le train s'arrêtait « à quai » avec ses deux voitures dans
le vide, et l'on montait à côté d'un bout de béton de la taille d'un abribus.

⚠ **Il est posé par le jeu**, à l'abscisse que `VilleVivante.gares()` donne, et
pas dessiné dans la carte : la voie change avec le code de la manche, un quai
dessiné à la main tomberait dans la rivière une manche sur deux.

⚠ **Le décor de la ville se peint avec les gris de la ville.** Le quai s'est
d'abord peint avec la palette de l'interface (`Palette.SURFACE`, `Palette.SERIE`)
et sortait en dalle NOIRE surmontée de deux auvents bleu vif. La palette sert à
l'écran, pas au béton.

## La casse (§1.3)

Le guide veut un **compacteur** : « broyer une voiture pour récupérer un
power-up ». Il y en a **six**, un au milieu de chaque intervalle entre deux
quais : on les croise en suivant la voie, ce qui est exactement ce qu'on fait
quand on cherche où se débarrasser d'une voiture.

On y entre au volant, `F` broie, on en ressort à pied — plus riche, et avec une
caisse d'arme au sol (le « power-up », servi par le ramassage qui existe déjà
plutôt que par un troisième système d'inventaire).

⚠ **Ce n'est pas `detruire_auto`.** Celle-là compte un crime, marque des points,
allume un brasier et appelle les pompiers. Brûler une voiture en pleine rue et
la déposer à la casse ne sont pas le même geste : la casse est la **seule chose
qu'on puisse faire d'une voiture volée sans que la police s'en mêle**, et c'est
ce qui lui donne une raison d'exister à côté du garage de peinture.

⚠ **On ne rend pas la voiture avant de la broyer.** `_basculer_portiere` la
remet en circulation : rendue puis broyée, elle réapparaissait une seconde plus
tard chez les autres joueurs, garée sur la dalle, intouchable.

⚠ **L'événement s'appelle `broye`, pas `casse`** : « casse » est déjà l'impact
d'une balle dans une façade, et deux sens sur le même nom, c'est un jour perdu à
chercher pourquoi tirer sur un mur rend de l'argent.

### Deux réglages qui se tiennent

**La place.** La bande du ballast fait 110 px de chaque côté de l'axe
(`LARGEUR_RAIL` = 2,2 tuiles). Écartée de 200 px avec une dalle de 190, la casse
tombait **entièrement hors du ballast** : elle se posait sur le pâté d'à côté,
par-dessus les immeubles — et rien dans le code ne s'en plaignait, il fallait la
voir. Écartée de 68 avec une dalle de 110, elle va de 13 à 123 px de l'axe :
dedans, sans recouvrir les rails, et le convoi (30 px de large) passe à côté
sans toucher la voiture garée dessus. Le banc vérifie les deux bouts du réglage.

**Le tarif.** Il suit la **longueur du gabarit** (`VoxelsCarnage.GABARITS`) —
la seule mesure qui existe déjà pour les vingt-huit modèles, celle qu'on voit à
l'écran, et qui ne vieillira pas au prochain véhicule ajouté. Mais à 240 + 34
par voxel, une citadine ramassée au coin de la rue valait 750 $ : plus qu'un
contrat de gang, sans risque et sans une étoile. On volait, on roulait jusqu'au
ballast, on recommençait, et tout le reste du jeu devenait facultatif. À
**120 + 18** la citadine fait 390 et la benne 570 — de quoi tenir, jamais de quoi
s'enrichir. Ce qu'on vient chercher, c'est l'arme au sol.

## Les bancs

```bash
godot --headless --path . -s outils/train.gd       # la voie, les rames, les quais, le fauchage
./outils/voir.sh "t:,t:quai,t:casse" 24            # la rame, le quai, le compacteur
./outils/apercu.sh TRAIN /tmp/rail.png rail 95     # une rame à quai, dans la ville
./outils/apercu.sh TRAIN /tmp/casse.png casse 70   # une casse au bord de la voie
godot --headless --path . --solo --banc-jeu=carnage --manche=40 --banc-position=rail
```

⚠ **Les arguments du banc de partie passent SANS le séparateur `--`** :
`OS.get_cmdline_args()` ne rend pas ce qui le suit, et le jeu ouvrait alors le
salon ordinaire — sans pilote automatique, sans solo, en attendant un serveur
qui ne vient pas. Le banc « ne quittait jamais le menu ».

`--banc-position=rail` pose le pilote au quai le plus central : la voie dépend du
code de la manche, tiré au lancement, on ne peut donc pas écrire la tuile d'une
gare à la main. La ligne de diagnostic du banc porte `trains=2/268px` — le nombre
de rames et la distance de la plus proche. Une rame invisible et une rame absente
rendent exactement la même photo ; ce chiffre-là les distingue.

Au 10/09, sur la manche `TRAIN` : voie de 72 842 px pour une ville large de
68 000, 60/60 points sur le ballast, 7 quais, 16 arrêts et 2 demi-tours en cinq
minutes, et le fauchage qui prend le badaud sur la voie, la voiture en travers,
et laisse le passant d'à côté ; six casses toutes dans la bande de ballast et
toutes hors du convoi, une benne à 570 $ contre 390 pour une citadine, et un
broyage qui ne laisse ni épave, ni brasier, ni étoile.
