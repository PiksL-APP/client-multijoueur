# Piks-l Multijoueur

Un hub que l'on parcourt à plusieurs, des portails, et derrière chaque portail
un jeu de 2 à 4 joueurs avec son score. Le tout tourne dans le navigateur :
Godot 4.5 exporté en WebAssembly, Supabase Realtime pour le réseau, Vercel pour
l'hébergement.

**Un mur ne stoppe pas, il fait glisser.** Une collision ne coûte que la part
de vitesse mise dans la façade, et la voiture se réaligne dessus quand on la
frôle. Le braquage atteint son plein dès 165 px/s : avant, la voiture ne
tournait qu'à pleine vitesse, ce qui la rendait inconduisible dans des rues de
cent quarante pixels.

**La ville se déduit du code de la manche**, jamais du réseau : même code, même
plan, chez tout le monde et à tout instant. Diffuser le plan aurait coûté
plusieurs kilo-octets par partie et un cas de plus pour qui rejoint en retard.

**Le hub est en voxels.** Le village, ses maisons, ses arbres, ses habitants
et les héros sont bâtis cube par cube par `outils/voxel.py`, à une seule
palette, et écrits en glTF dans `modeles/voxel/` (couleurs par sommet, faces
plates, maillage glouton). Rien n'y est découpé dans un dessin d'autrui : le
script est la seule source du décor, et pour changer le village on change le
script et on le relance. Une case du plan fait 16 pixels dans la simulation
et UNE unité dans le monde ; un modèle fin est bâti en voxels de 1/8 d'unité
(un personnage fait seize voxels de haut), les arbres et le terrain en voxels
plus gros. Les personnages sont des glTF à six nœuds (jambes, corps, bras,
tête), balancés par le moteur en marchant. Le même script dessine le **plan**
du village sur une grille de cases — terrain, objets, portes, cases bloquées —
et bâtit chaque pièce (sol, trois murs, meubles fondus dans un seul maillage,
le sud ouvert comme une maison de poupée), puis écrit `modeles/voxel/plan.json`
: ce qu'on voit et ce qui arrête le joueur sortent de la même source, donc ne
divergent jamais. `outils/voir.sh nom1,nom2` pose des modèles en ligne et les
photographie, pour les juger sans lancer le jeu. Le socle (`scenes/ecran.gd`)
porte `plan()` pour la 2D et `monde()` pour la 3D ; le hub, comme les jeux,
vit dans `monde()`. Le pack *Pixel Crawler* (`modeles/village/`, écrit par
`outils/village.py`) ne sert plus au rendu : l'écran d'accueil montre les
pantins voxel eux-mêmes, dans trois petites fenêtres 3D.

**2,5D.** La simulation se fait sur un plan — tout l'état réseau tient en
`Vector2` — mais le rendu est en vraie 3D : caméra en perspective inclinée,
lumière directionnelle avec ombres portées, contre-jour froid pour que les
faces à l'ombre gardent leur volume, brouillard de profondeur. Les objets ont
une hauteur (voitures à châssis et cabine, monstres qui sautillent, dalles qui
s'enfoncent, portes qui descendent dans le sol) sans que la logique de jeu
n'ait jamais à connaître un axe vertical. Toute la fabrique est dans
`commun/decor.gd`, y compris le facteur d'échelle : les coordonnées de jeu sont
en pixels, gardées telles quelles en unités 3D elles ruineraient la précision
des ombres.

En ligne : **https://multijoueur.piks-l.com**

## Ce qu'il y a dedans

| | |
| --- | --- |
| **Hub** | Un village en **voxels**, vu de trois quarts : on s'y croise, et on ENTRE dans les maisons. Une esplanade pavée adossée à une falaise, cinq maisons, un potager, une mare, la forêt autour, le jour qui tombe toutes les quinze minutes (même heure pour tous) et les feux qui s'allument. On choisit son héros à l'entrée (chevalier, voleur, mage), on se fait des signes (émotes 1-4), on ouvre son carnet (K : records, place au mur). La taverne, l'armurerie et l'auberge se visitent, avec leurs habitants qui parlent, le classement au mur et le portail qui lance la partie (Carnage, Énigme, Bousculade). Des réverbères s'allument le soir. On se parle : Entrée (ou T) ouvre le tchat, le message part à tout le hub — fil en bas à gauche, bulle au-dessus de la tête — et les touches de marche restent au texte tant qu'on écrit. L'image passe par un effet **maquette** (tilt-shift, `commun/maquette.gd`) : nette à hauteur du joueur, floue en haut et en bas, un peu plus saturée — un petit monde qu'on regarde de haut. Les volumes portent une **occlusion
ambiante cuite** dans leurs sommets, les masses (feuillages, pelouse, dallage)
sont teintées par un bruit de taches mêlé à la hauteur, la forêt roule en
collines autour de la clairière — restée plate, puisque c'est là qu'on marche
— et chaque maison est assise sur un socle de pierre avec son perron. Le champion d'un jeu porte une étoile devant son nom. |
| **CARNAGE** | Un GTA 2 à l'heure bleue. Une ville PROCÉDURALE de six cent quatre-vingts par cinq cent vingt tuiles — cent fois la précédente — tirée du code de la manche et générée À LA DEMANDE, morceau par morceau, autour de chaque joueur : un centre d'affaires neutre et ses tours, des quartiers de bureaux, des rues commerçantes à néons, la vieille ville, les cités, la banlieue pavillonnaire, la zone industrielle, le port, des parcs et des lacs. Trois gangs se partagent tout ça par secteurs aux frontières irrégulières. Les immeubles sont des boîtes dont un shader dessine les étages et allume les fenêtres ; le sol, les trottoirs, les passages piétons et l'eau sont un autre shader. Des dizaines de milliers de voitures dorment le long des rues et se volent toutes ; les taxis roulent au centre, les fourgons dans la zone. On conduit, on **descend** (E), on court, on tire. Les passants rapportent, les gangs plus, les flics encore plus — et tout cela fait monter les **étoiles de recherche**. Chaque secteur a son **garage** qui efface le casier, sa **cabine** qui donne des contrats, ses **repaires** tagués au sol, une **arène** une fois sur deux — le seul endroit où les joueurs peuvent se blesser. Manche de 4 minutes, radar centré sur soi en haut à droite. |
| **BOUSCULADE** | Une île en voxels qui flotte dans le vide, quatre joueurs qui se poussent. Z Q S D pour courir, **ESPACE** pour charger : un coup d'épaule qui envoie l'autre valser. L'île s'effrite par le bord, anneau après anneau, jusqu'à un disque de trois unités. Tombé ? Repêché au centre trois secondes plus tard — mais celui qui vous a poussé a marqué cent points ; deux points par seconde debout. Chacun simule son propre pantin (pas, charge, poussée reçue, chute) ; l'hôte compte les points. Manche de 90 secondes, portail à l'auberge. |
| **ÉNIGME** | Coopératif, trois chambres. Une dalle ne reste enfoncée que si quelqu'un — ou une caisse — pèse dessus, et la sortie d'une chambre n'accepte l'équipe qu'au complet. 3 minutes. |

### CARNAGE, dans le détail

**On descend de voiture.** C'est le geste qui sépare un jeu de voiture d'un
GTA : tant qu'on ne peut pas sortir, une ville n'est qu'un circuit. `E` ouvre
la portière dans les deux sens. À pied on est deux fois plus fragile, et c'est
voulu — sinon personne ne remonterait jamais au volant.

**Le vol de voiture est arbitré par l'hôte.** Le client DEMANDE, l'hôte
accorde. Sans cet aller-retour, deux joueurs arrivés à cent millisecondes
d'intervalle repartent chacun avec la même berline et chacun voit l'autre
rouler dans le vide. Une voiture conduite sort de la simulation de l'hôte et
n'est plus diffusée : c'est son conducteur qui l'annonce, douze fois par
seconde, comme n'importe quel joueur.

**Les étoiles.** Chaque crime chauffe une jauge : un passant vaut douze
points, une voiture quinze, un flic cinquante-deux, un coup de feu deux et
demi. Cinq paliers, cinq étoiles. La jauge redescend de neuf points par
seconde après quatre secondes et demie de calme. La réponse est graduée : une
patrouille par étoile, des flics à pied dès la deuxième, des barrages de rue
à la quatrième. Le **garage de peinture** remet tout à zéro — sans
échappatoire, cinq étoiles sont une condamnation et le joueur repose la
manette.

**Le respect.** Trois gangs, trois bandes de ville, une jauge par gang et par
joueur. Tuer chez l'un fait perdre vingt-deux points chez lui et en gagner
douze chez les deux autres. En dessous de −60 — soit trois morts, pas une — le
gang tire à vue ; au-dessus de +50 il laisse passer. Brûler une de leurs
voitures compte aussi, sinon on ferait le vide au lance-roquettes sans jamais
fâcher personne.

**Les contrats.** Une cabine par territoire. Le gang du quartier paie pour
nettoyer chez un rival, faire repeindre une voiture, ou tenir deux étoiles
jusqu'au bout. La prime se touche en argent ET en respect : c'est la seule
façon de remonter une jauge qu'on a fait plonger.

**Les arènes.** Deux esplanades qui enjambent une frontière de territoire —
contestées par construction. Le tir ami n'existe QUE là, et seulement si le
coup part de l'arène ET y arrive : un tireur posté dehors nettoierait
l'esplanade sans jamais y entrer. Partout ailleurs, les joueurs ne peuvent pas
se blesser et jouent la ville ensemble.

**La ville ne se génère JAMAIS d'un bloc.** Six cent quatre-vingts par cinq
cent vingt tuiles, c'est trois cent cinquante mille tuiles : les bâtir au coup
d'envoi bloquerait le navigateur dix secondes et ferait tomber le socket, pour
un décor dont personne ne visitera les neuf dixièmes. Tout est une FONCTION
PURE des coordonnées et du code (`PlanVille._bruit`) : n'importe quel pâté se
calcule à n'importe quel moment, chez n'importe quel joueur, et donne la même
chose. Le zonage est un Voronoï à graines jetées sur une grille de huit pâtés ;
chaque graine porte un type de quartier (tiré selon la distance au centre) et
un gang (tiré selon l'angle, bruité). Les lieux — garage, cabine, un ou deux
repaires, une arène une fois sur deux — se tirent par secteur de huit pâtés
sur huit, d'un générateur semé par le secteur et le code.

**La carte est celle de GTA 2, pas un quadrillage.** La ville est une ÎLE à la
côte irrégulière ; une RIVIÈRE serpente d'ouest en est et ne se franchit que
par les avenues (une rue sur quatre, arborée, à double ligne, jamais coupée) ;
une VOIE FERRÉE traverse en diagonale, seul trait qui ne suive pas la grille ;
et des ÎLOTS de deux pâtés sur deux se fondent — souvent dans la zone
industrielle, les parcs et les cités, presque jamais dans la vieille ville —
leurs rues intérieures devenant une cour en croix qu'on traverse. Les pâtés
que l'eau ou la voie touchent deviennent des quais. `TAB` affiche la carte
entière (un pixel par tuile, peinte par lots pendant les deux premières
secondes de la manche) avec sa légende et la position de chacun.

**La ville n'est pas un quadrillage.** Une PLACE EN ÉTOILE, un peu au nord du
centre — un obélisque sur un îlot, un parvis pavé qui rayonne — d'où partent
six avenues en diagonale jusqu'à la côte ; deux places secondaires à quatre
avenues ; un BOULEVARD CIRCULAIRE autour de la grande place, et les grands
boulevards, une seconde ellipse qui ceinture le centre et franchit la rivière
sur deux ponts. Ces « voies libres » (`PlanVille.voie_libre`) ne suivent pas la
grille : une tuile qu'elles traversent devient du boulevard quoi qu'en dise la
grille, le pâté coupé ne garde que des immeubles d'une tuile (`_bordure`), et
le shader du sol trace la chaussée en espace monde comme il trace la voie
ferrée. Le trafic les suit par leur tangente et tourne autour des places
(`voie_libre_en`). Et sur la grille elle-même, le DÉCALAGE : entre deux avenues,
une transversale sur deux s'arrête en T, comme les briques d'un mur — un
carrefour en croix est devenu l'exception. La rue décalée devient une cour
qu'on traverse quand même.

**Le rendu se fait par morceaux de vingt tuiles.** Un morceau se bâtit en
quelques dizaines de millisecondes quand son bord passe à quinze cents pixels
du joueur — un par image, du plus proche au plus loin — et se libère au-delà de
trente-quatre cents. Un morceau tient en une douzaine d'appels de dessin : UN
maillage de sol, UNE nappe d'immeubles, une nappe par modèle de mobilier et de
voiture dormante, un maillage d'enseignes, un de flaques de lumière. L'ancienne
ville dessinait chaque voiture garée en cinq appels ; celle-ci en dessine cent
cinquante par morceau en dix.

**Tout est en voxels — des voxels d'UNE unité, cousus par pâté — et ça se
casse.** Immeubles, mobilier, voitures, passants et joueurs sont des cubes.
Depuis la v7, un immeuble est une grille de cellules d'un mètre (jusqu'à
31 × 31 × 63 : `VoxelsCarnage.immeuble`) avec ses trous — fenêtres de deux
cubes en retrait dans la façade, porte, cour d'un L, retrait d'attique, toit en
pente (des rangs qui se resserrent d'un cube jusqu'au faîte, cheminée
comprise), cubes cassés — et TOUT LE PÂTÉ (jusqu'à seize immeubles) devient UN
seul `ArrayMesh` : un mailleur glouton fond les cellules voisines de même
couleur en rectangles (un mur de trente sur seize n'est plus quatre cent
quatre-vingts cubes de douze triangles mais une trentaine de rectangles), et
chaque trou ajoute les faces des cellules pleines qui le bordent. Le relief
vient de la forme et de la lumière, pas d'un quadrillage : le shader ne dessine
qu'une arête discrète par cube (lue dans les UV, la position en cellules sur la
face, car l'origine d'un immeuble n'est pas alignée sur l'unité), les fenêtres
« allumées » ne sont que du verre le jour et ne luisent qu'avec la nuit, et
l'APPUI d'une fenêtre allumée — le dessus de la cellule sous le trou, la seule
chose qu'une caméra presque verticale voit d'une embrasure — reçoit sa lumière
(classe `ECLAIRE`). Le parapet est clair sur un toit sombre : c'est le trait
qui dessine le contour de l'immeuble vu d'en haut. Autour de la grille, les
ORNEMENTS (`VoxelsCarnage.ornements`, instances à l'échelle E = 2) : bandeaux
d'étage en saillie, corniches, balcons, stores, et sur les toits plats
climatiseurs, citernes, antennes, cages d'escalier. Les VOITURES sont en voxels
d'un quart d'unité maillés de la même façon (`mailler_grille`, UV constants :
une peau lisse) : capot plus bas que le toit, pare-brise et lunette en
escalier, passages de roue, jantes claires, rétroviseurs, baguette de chrome,
seize gabarits (berline, sportive, citadine, 4×4, monospace, taxi, fourgon,
camion de livraison, benne, police, coupé, break, pick-up, bus, limousine,
ambulance). Seule la tôle (alpha 1) prend la peinture d'instance ; pneus,
chrome, feux, vitres gardent leur couleur (alpha `BRUT`). Les passants sont en
quarts d'unité (bras et jambes articulés). Le sol est quantifié sur la grille
des cubes. **La destruction est arbitrée par l'hôte** : une balle, une
roquette, une explosion ou un choc frontal à plus de trois cent quatre-vingts
pixels par seconde ôte des cubes (`VilleVivante.impacter/exploser/choquer`, un
cube par balle), l'événement `casse` — groupé dans le `lot` de l'image — vide
la cellule chez tout le monde et salit son pâté, qui se remaille — UN par
image, tous morceaux confondus (`MorceauVille.rafraichir`), dix à vingt
millisecondes — en exposant l'intérieur gris et en lâchant des débris. Quand il
reste moins de quarante pour cent du rez-de-chaussée, l'immeuble est ÉVENTRÉ :
sa fiche perd son bloc et on le traverse en voiture. Les cubes détruits sont
gardés par identifiant (immeuble = tuile et rang, cube = clé locale
`(i·32 + j)·64 + k`) : c'est ce qui permet à un morceau libéré puis rebâti de
rester en ruine. ⚠ Deux pièges GDScript rencontrés ici : `Color.to_rgba32()`
dépasse le signé 32 bits (un `PackedInt32Array` le tronquait en négatif), et
un tableau compact lu dans un dictionnaire puis allongé n'allonge qu'une copie
— on le réécrit dans la fiche. Pour juger une façade ou une carrosserie sans
relancer le banc : `/tmp/atelier.gd` et `/tmp/parc.gd` (six immeubles, seize
voitures, sous la caméra du jeu, dix secondes).

**La circulation suit l'heure.** Quarante-quatre voitures et quatre-vingt-dix
passants le jour, quatorze et quarante la nuit (`plafond_autos`,
`plafond_gens`, interpolés sur `MatieresCarnage.nuit()`), des cadences
d'apparition qui s'allongent la nuit, jamais une voiture qui naît sur une
autre (`_degage_des_autos`), et le parvis d'une place est un mur pour les
voitures — sinon elles y entraient par les axes de la grille et la place
devenait un parking.

**Le jour et la nuit.** La même horloge que le village : un cycle de quinze
minutes (`MatieresCarnage.nuit()`), neuf de jour, une de crépuscule, quatre de
nuit, une d'aube. Le ciel, le brouillard, le soleil et la lune s'interpolent
entre trois heures clés (`HEURES`) ; les fenêtres, enseignes et lampadaires
montent en émission quand la nuit tombe, et la rue passe du gris chaud au bleu
sourd — jamais noire : une nuit noire vue de dessus, c'est un écran vide.
`--nuit=<0..1>` (`?nuit=` dans l'URL) force l'heure pour photographier.

**Deux vraies lumières, pas une de plus.** Le mode compatibilité n'en supporte
que huit par objet ; une flaque additive au sol sous chaque lampadaire fait le
même effet pour rien. Les deux exceptions sont les phares de VOTRE voiture,
deux projecteurs qui ne s'allument que la nuit et font surgir les façades dans
leur faisceau. Le reste de l'ambiance est du shader : l'ombre des nuages qui
glisse sur la ville, le bitume qui se mouille la nuit, une ombre de contact
multiplicative au pied de chaque immeuble (sans elle, ils flottent), les
traces de pneus qu'on laisse en freinant, les étincelles d'une tôle qui racle
un mur, la poussière d'un cube qui part, et sur l'écran une vignette avec un
grain léger qui rougit aux chocs. ⚠ Une matière additive doit couper le
brouillard (`fog_disabled`) : sinon il peint un carré violet là où la flaque
devait être transparente.

**Les pâtés ne sont pas tous carrés.** Par secteur, la ville a un sens — ses
rues longues courent d'est en ouest ou du nord au sud — et une transversale
sur deux se ferme par tranches de trois pâtés (`LONG`) ; le DÉCALAGE ferme en
T la plupart des autres carrefours. Dans les quartiers denses
(`QUARTIERS_BATIS`), une rue fermée est BÂTIE : un immeuble d'une tuile du
style et de la hauteur des pâtés qu'il relie, et de haut le bloc n'est plus
qu'un seul long pâté de huit ou treize tuiles ; ailleurs elle reste une cour
(jardin, chantier, dépôt). Une cour de la largeur d'une rue, vue d'en haut,
c'était encore une rue — et la ville restait un damier.

**Les rues font deux tuiles de large.** Trottoir, file de stationnement, voie
de circulation, de chaque côté d'un axe. Une rue d'une tuile ne laissait pas la
place aux voitures garées ET au trafic : celui-ci freinait derrière les garées
et klaxonnait sans fin, et on cabossait sa voiture en longeant un trottoir.

**Les voitures dorment dans le plan, pas chez l'hôte.** Une place de
stationnement est une fiche de tuile ; son identifiant se déduit de la tuile et
du côté (`PlanVille.id_dormante`). Le morceau les peint en nappes ; l'hôte ne
prend une voiture en charge que quand elle se RÉVEILLE — volée, percutée,
tirée — et la retire alors de sa nappe chez tout le monde (`pris`, instantané,
ou la position du conducteur pour qui arrive en retard). Une ville de cent
mille voitures garées ne peut pas vivre dans une liste qu'on parcourt à chaque
image.

**La circulation roule à droite, freine et klaxonne.** Chaque voiture tient sa
file (vingt-cinq pixels à droite de l'axe), s'arrête derrière ce qu'elle a
devant — joueur, voiture, passant — et klaxonne au bout de sept dixièmes de
seconde à l'arrêt. Le klaxon (le vôtre aussi, `H`) fait décamper les passants,
comme un coup de feu. Ils préfèrent le trottoir et crient quand on les fauche.

**Le butin.** Un gang abattu lâche son arme une fois sur trois, un flic une
trousse ou une mitraillette une fois sur deux, un passant un billet une fois
sur six. Tout disparaît au bout de quatorze secondes, sinon la ville se couvre
de caisses et plus aucune ne vaut le détour.

**Les voitures ne se conduisent pas pareil.** Sportive qui file (×1,2) mais
tôle fine ; camion lourd (×0,78) qui encaisse presque le double ; police qui
pousse. C'est ce qui fait qu'on vole une voiture pour autre chose que sa couleur.

**À cinq étoiles, l'hélicoptère.** Il survole avec un temps de retard, tire par
rafales, et ne se sème pas : il fait du surplace quand on est à terre, et ne
rentre à la base que quand la jauge redescend. La seule sortie est le garage.

**L'interface est celle d'une borne d'arcade, du premier écran au dernier.**
Angles droits, cadres de deux pixels, polices pixel à leur taille native, une
barre d'accent à gauche de chaque panneau (`ui/fabrique.gd`) — l'accueil, le
village, le salon, la manche et les résultats partagent la même main. En
manche, `ui/hud.gd` peint tout en un `_draw` : chrono et scores en cartouche
(une barre de course sous chaque nom), les cinq étoiles de recherche toujours
visibles au milieu, la fiche du joueur en bas à gauche — jauges de vie et de
tôle, arme et munitions, puces d'état (qui vous chasse, arène, garage) —, le
contrat en bas au milieu avec son sablier, et les touches en cabochons sur la
dernière ligne, qui s'estompent quinze secondes après le départ. Le jeu ne
donne au HUD qu'une fiche (`Partie.fiche_joueur`) : l'énigme et Carnage ont
le même habillage avec leurs propres rubriques.

**Le radar, en haut à droite.** Centré sur soi, le nord en haut : la ville
fait six cent quatre-vingts tuiles, un plan entier n'y montrerait plus rien.
Les pâtés y sont teintés du gang qui les tient (vert les parcs, bleu l'eau), les
rues en sombre, les lieux à portée en pastilles nommées. La cible d'un contrat
clignote ; hors du cadre, une flèche au bord dit où aller et à combien de
tuiles. On réapparaît aussi près de là où l'on est tombé, jamais au centre —
dans une ville de soixante-huit mille pixels, ce serait repartir de zéro.

Les deux portails restants sont éteints : ils marquent la place des jeux
suivants sans faire croire qu'ils existent.

## L'architecture, en une page

```
Navigateur (Godot 4.5 → WebAssembly)
   │
   ├─ WebSocket ──► Supabase Realtime      présence + diffusion, un canal par salle
   └─ HTTPS ──────► Supabase PostgREST     dépôt du score, lecture du classement
```

**Il n'y a pas de serveur de jeu.** Vercel ne sait pas héberger un processus qui
vit entre deux requêtes, et en monter un ailleurs pour deux mini-jeux aurait
ajouté une infrastructure à payer et à surveiller. À la place :

- **un hôte parmi les joueurs**, désigné par la plus petite clé de présence.
  Tout le monde calcule la même chose à partir des mêmes métadonnées, donc
  personne n'a besoin d'arbitrer, et la réélection après un départ est
  immédiate ;
- **l'hôte simule ce qui est partagé** — monstres, caisses, portes, score — et
  le diffuse ;
- **chaque client simule son propre personnage** : la commande répond à
  l'image, pas au réseau.

Ce que ça coûte, en toute honnêteté : un hôte qui modifierait son client
pourrait mentir sur le score de la manche. La fonction SQL de dépôt borne les
valeurs au vraisemblable (voir plus bas), ce qui limite les dégâts sans les
supprimer. Un serveur autoritaire est le seul vrai remède, et il se branchera
sans toucher aux jeux : il suffira de remplacer l'élection d'hôte.

### Ce qui vit où

```
jeux/carnage.gd          l'écran : commandes, réseau, rendu, interface, morceaux à portée
jeux/carnage/plan.gd     le plan de ville, déduit du code : zonage, pâtés, lieux, dormantes
jeux/carnage/morceau.gd  un morceau rendu : sol, nappes d'immeubles, mobilier, voitures, lumières
jeux/carnage/matieres.gd les shaders (sol, façades, flaques, lumineux) et l'ambiance
jeux/carnage/vivant.gd   ce que l'HÔTE simule : foule, gangs, trafic, police, contrats
jeux/carnage/formes.gd   la fabrique de volumes (voitures, piétons, cabines, barrages)
ui/radar.gd              le radar centré sur soi, dans un coin
```

⚠ Les collisions de la ville ne balayent PAS une liste de rectangles. Elle en
compte plus de trois cents ; avec quarante-six piétons, dix-huit voitures et
des projectiles, un balayage linéaire coûtait vingt mille tests par image et
l'hôte perdait ses trames. Une tuile se déduit d'une position par deux
divisions — on ne teste jamais plus des quatre tuiles qui touchent le cercle.

⚠ L'instantané de l'hôte ne porte que ce qu'un joueur peut VOIR (1 500 px).
Une ville entière diffusée, ce serait vingt-cinq kilo-octets par seconde pour
des passants que personne ne regarde.

⚠ Deux pièges de GDScript rencontrés ici : `trait` est un mot réservé et
l'erreur ne parle que d'un « nom de variable attendu » sans jamais nommer le
mot ; et `plan` est pris par le socle `Ecran` — le plan de ville s'appelle
`carte` dans l'écran de jeu.

### Le client temps réel

`autoload/reseau.gd` parle le protocole Phoenix de Supabase Realtime
directement sur `WebSocketPeer` — pas de SDK JavaScript via `JavaScriptBridge`.
Raison : un pont JS n'existerait que dans l'export web, et plus rien ne serait
testable sans déployer. Là, le même code tourne dans l'éditeur, en `--headless`
et dans le navigateur.

Quatre messages suffisent : `phx_join`, `heartbeat`, `broadcast`, `presence`.

- **présence** : rare et fiable → identité, table, composition de l'équipe ;
- **diffusion** : fréquente et jetable → positions (12 fois par seconde),
  états, événements.

`broadcast.self` est à `false` : se faire renvoyer ses propres messages
doublerait la facture pour un état déjà connu.

### Les salons

Pas de service d'appariement. Le salon d'un jeu est un canal ; chacun annonce
un numéro de table dans sa méta de présence, et la répartition se **lit** dans
la présence — tout le monde calcule le même découpage. On rejoint la première
table qui a de la place, ce qui regroupe les joueurs au lieu de les éparpiller.

## La base

Migration : `supabase/migrations/20260906_multijoueur.sql`. Strictement
additive, préfixe `jeu_`.

- `jeu_joueurs` — identifiant tiré au sort par le navigateur à la première
  visite. Pas de compte, pas de donnée personnelle.
- `jeu_parties` — une manche, déposée une seule fois, par l'hôte.
- `jeu_scores` — un score par joueur et par manche.

RLS : **lecture publique, aucune écriture directe.** Tout passe par
`jeu_deposer_partie(jeu, code, duree_s, resultats)`, en `security definer`, qui

- refuse un jeu inconnu, une durée hors bornes, une équipe hors 1–4 ;
- ramène chaque score au plafond de la manche (Carnage : 40 points par seconde
  de jeu ; Énigme : 2 000) ;
- refuse plus de 60 dépôts par heure et par joueur.

## Développer

```bash
cp config.exemple.cfg config.cfg      # puis renseigner les clés Supabase
godot --editor --path .               # ou : godot --path .
```

`config.cfg` est hors dépôt : aucun secret dans un commit.

### Bancs d'essai sans interface

Deux instances côte à côte, chacune avec son `HOME` (donc sa propre identité) :

```bash
# 1. la présence et la diffusion tiennent-elles ?
HOME=/tmp/a godot --headless --path . --banc &
HOME=/tmp/b godot --headless --path . --banc

# 2. une manche complète, du salon au dépôt du score
HOME=/tmp/a godot --headless --path . --banc-jeu=carnage --manche=30 &
HOME=/tmp/b godot --headless --path . --banc-jeu=carnage --manche=30
```

Le second traverse TOUTE la chaîne : appariement dans le salon, élection de
l'hôte, décompte, simulation, diffusion des scores, dépôt en base. Il joue au
pilote automatique — dans Carnage, la voiture vise le monstre le plus proche,
sans quoi une manche d'essai finirait à zéro et ne vérifierait ni la
collision, ni le score, ni le dépôt.

C'est ce que permet `commun/commandes.gd` : les touches ne sont jamais lues
ailleurs. Sans ce passage obligé, la seule façon de vérifier une partie de
bout en bout serait de la jouer à la main — et personne ne le fait avant
chaque livraison.

### Photographier un jeu sans y jouer

```bash
xvfb-run -s "-screen 0 1280x720x24" godot --path . \
  --rendering-driver opengl3 --resolution 1280x720 \
  --banc-jeu=carnage --manche=30 --photo=/tmp/vues
```

Une image toutes les cinq secondes dans `/tmp/vues`. C'est ce contrôle qui a
montré ce qu'aucun test ne disait : les monstres apparaissaient aux bords de
l'arène et mettaient douze cents pixels à devenir menaçants — à l'écran, on
n'en croisait aucun.

`--manche` raccourcit la manche : attendre deux minutes par vérification,
personne ne le fait deux fois. `--banc-etoiles=3` fait partir déjà recherché,
`--banc-position=colonne,ligne` (en tuiles) fait partir ailleurs qu'au centre —
sans ça, le banc ne photographie jamais le port ni la banlieue. Dans le
navigateur, les mêmes réglages passent par l'adresse :
`?pilote=carnage&manche=60&etoiles=3&position=120,110`.

### Réexporter

```bash
./outils/exporter.sh
```

L'export atterrit dans `sortie/`, **qui est versionné** : c'est ce que Vercel
sert tel quel. Le sortir du dépôt obligerait à installer Godot dans le build
Vercel — 1,3 Go de modèles d'export à chaque déploiement.

`index.wasm` et `index.pck` sont servis en `must-revalidate`, pas en
`immutable` : leur nom ne change JAMAIS d'une version à l'autre. Mis en cache
immuable, un navigateur qui a déjà vu le jeu ne verrait plus jamais une mise à
jour — on l'a constaté en déployant une correction qui n'apparaissait pas.
La revalidation coûte un aller-retour et répond 304.

L'export est en variante *sans fils d'exécution* (`thread_support=false`) :
avec les fils, le navigateur exige les en-têtes d'isolation `COOP`/`COEP`, qui
cassent le chargement de ressources tierces. Pour de la 2D, on n'y perd rien.

## Ce qui n'est pas fait

- Rendu en mode compatibilité (exigé par le web) : ombres directionnelles
  seulement, pas d'occlusion ambiante ni de reflets.
- Sur téléphone, un manche virtuel et un bouton apparaissent — et n'apparaissent
  que là : un pavé tactile affiché à quelqu'un qui a un clavier passe pour un
  défaut. `--tactile` les force, pour pouvoir les vérifier au banc.
- Les ressources binaires du dépôt sont des kits Kenney, CC0, un dossier par
  kit avec sa licence et son atlas `Textures/colormap.png` (⚠ les glTF de
  Kenney référencent l'atlas en fichier EXTERNE : copier les seuls maillages
  donne un kit entièrement blanc, sans message d'erreur) : `modeles/ville/`
  (tuiles), `modeles/voitures/` (dix carrosseries), `modeles/commerce/`,
  `modeles/industrie/`, `modeles/banlieue/` (les immeubles des quartiers),
  `modeles/personnages/`, `modeles/creatures/`, plus `modeles/volvo-242.glb`
  et le village pixel art du hub. L'ancienne règle « presque rien de binaire »
  a cédé le jour où la ville a dû ne plus se ressembler d'un quartier à
  l'autre. Historique : `modeles/volvo-242.glb`
  (décimée de 44 000 à 5 900 triangles depuis un STL de modélisme) et
  `modeles/ville/` — le [kit de ville de Kenney](https://github.com/KenneyNL/Starter-Kit-City-Builder),
  CC0, quinze tuiles pour 412 Ko — **avec `modeles/ville/Textures/colormap.png`** :
  les glTF de Kenney référencent leur atlas en fichier EXTERNE, et copier les
  seuls maillages donne une ville entièrement blanche, sans le moindre message
  d'erreur. Le reste du décor est fabriqué en code.
  La ville est posée en **nappes** (`MultiMeshInstance3D`) : quatre cents
  tuiles dessinées une par une, c'est quatre cents appels de dessin par image,
  ce qui ne passe pas dans un navigateur en mode compatibilité. Regroupées par
  modèle, il en reste une quinzaine.
- Le son est entièrement synthétisé au démarrage (`autoload/sons.gd`) : aucun
  fichier binaire au dépôt. **M** le coupe, et le choix survit à la session.
- Le classement affiché est un top brut ; pas de saison, pas de remise à zéro.
- Chaque manche consomme des messages Realtime (≈ 50 par seconde à quatre
  joueurs). C'est confortable à l'échelle d'une démonstration, à surveiller si
  le hub devait devenir populaire.
