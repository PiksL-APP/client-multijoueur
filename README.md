# Piks Theft Auto

Une ville qu'on parcourt à plusieurs — **Pikstown** — et des parties de 2 à
4 joueurs avec leur score. Le tout tourne dans le navigateur : Godot 4.5
exporté en WebAssembly, Supabase Realtime pour le réseau, Vercel pour
l'hébergement.

**UN SEUL JEU.** Le dépôt a porté un hub à portails et trois jeux ; il ne porte
plus que **CARNAGE**. Le hub en voxels, ÉNIGME (la ferme) et BOUSCULADE ont
été retirés, avec les modules et les modèles qui n'existaient que pour eux —
`SUPPRIMER-LES-AUTRES-JEUX.bat` garde la trace exacte de ce qui est parti, et
tout se retrouve dans l'historique git.

**On entre par le chargement, puis par le salon.** Le voile de chargement
(`ui/chargement.gd` — l'affiche, l'astuce, la barre) se lève sur le **salon**,
qui est devenu l'écran d'accueil : les tables de quatre, « Lancer la manche »,
et deux portes de côté, *Pseudo* et *Options*. La fin d'une manche y ramène,
avec le classement affiché au-dessus des tables : il n'y a plus d'écran de
résultats, et donc plus un clic entre deux parties. L'éditeur de carte reste
accessible en atelier (`--ecran=editeur`), sans entrée dans l'interface.

**Dans le navigateur, la page EST la maquette.** Le kit fourni (un `.dc.html`
de Claude Design) n'est pas réinterprété : il est HÉBERGÉ. `web/kit/` porte son
moteur de rendu, React, et ses visuels ; la coque d'export de Godot recopie son
corps et son script à l'identique, et la toile du jeu attend dessous. Le
chargement, le menu, Commencer et Options sont donc exacts par construction.
Trois retouches : les neuf fonds au lieu de deux, l'avancement pris sur le vrai
chargeur du moteur plutôt qu'un minuteur, et « Entrer à Pikstown » qui passe la
main au jeu. Hors navigateur, ce sont les écrans Godot qui servent.

**L'habillage d'avant-partie suit la maquette** (`Loading GTA Piks Theft
Auto`) : polices Archivo Black et Barlow Condensed, palette rose `#ff2ea6`,
cyan `#22e3f2` et orange `#ff9d2e`, capitales très espacées. Tout est
rassemblé dans `ui/charte.gd` — elle ne remplace pas `ui/fabrique.gd`, qui
habille le JEU : l'un est l'affiche du film, l'autre la borne d'arcade.

**Un vrai chargement.** Les vingt-cinq morceaux de ville ne sont pas bâtis
d'un bloc : ils partent en file, du plus proche du centre au plus lointain, un
par image, derrière l'écran de chargement de la maquette
(`ui/chargement.gd`) : neuf affiches qui se croisent, l'astuce qui tourne,
l'anneau et son compteur, la barre biseautée violet–rose–cyan. Puis le voile
se fond et le menu paraît, sur la ville. Et cette ville VIT : trente-quatre
voitures et seize passants suivent les axes de la trame — pas la simulation du
jeu, une circulation taillée pour être vue de très haut, qui boucle au bord du
champ.

**Le thème** *Vice City Drift* tourne sous le menu, la création, les options
et le salon, se tait quand la manche commence et reprend aux résultats.
L'interface sonne aussi — neuf bruitages de menu dans `sons/interface/`.

**Le casting vient de Kenney** (`modeles/kenney/`, CC0) : un seul maillage
articulé de 58 os, `characterMedium.fbx`, et douze images de peau tirées des
lots *protagonists*, *retro* et *survivors*. Godot 4.5 lit le FBX nativement
— aucune conversion. Les animations (`idle`, `run`, `jump`) vivent dans leurs
propres fichiers, sans maillage, et se greffent sur le squelette à la volée
(`commun/personnages.gd`). Douze personnages pour le poids d'un.

**Tout se règle** (`autoload/reglages.gd`, gardé dans `user://`) : trois
volumes sur trois bus audio, l'effet maquette, les ombres, la finesse du rendu,
le plein écran, et chaque touche du clavier. Les trois valent partout, menu ET
Piks Theft Auto : `Commandes` lit toutes ses touches dans les réglages, et
`MatieresCarnage.ambiance()` y prend son halo et ses ombres.

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
| **CARNAGE** | Un GTA 2 à l'heure bleue. Une ville PROCÉDURALE de six cent quatre-vingts par cinq cent vingt tuiles — cent fois la précédente — tirée du code de la manche et générée À LA DEMANDE, morceau par morceau, autour de chaque joueur : un centre d'affaires neutre et ses tours, des quartiers de bureaux, des rues commerçantes à néons, la vieille ville, les cités, la banlieue pavillonnaire, la zone industrielle, le port, des parcs et des lacs. Sept gangs se partagent tout ça — trois par district, dont Le Consortium qui est partout — par secteurs aux frontières irrégulières. Les immeubles sont des boîtes dont un shader dessine les étages et allume les fenêtres ; le sol, les trottoirs, les passages piétons et l'eau sont un autre shader. Des dizaines de milliers de voitures dorment le long des rues et se volent toutes ; les taxis roulent au centre, les fourgons dans la zone. On conduit, on **descend** (E), on court, on tire. Les passants rapportent, les gangs plus, les flics encore plus — et tout cela fait monter les **étoiles de recherche**. Chaque secteur a son **garage** qui efface le casier, sa **cabine** qui donne des contrats, ses **repaires** tagués au sol, une **arène** une fois sur deux — le seul endroit où les joueurs peuvent se blesser. Manche de 4 minutes, radar centré sur soi en haut à droite. |

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

**Le respect.** SEPT gangs, mais TROIS par district : la ville est coupée en
trois secteurs, chacun tenu par deux gangs locaux, et **Le Consortium** tient
boutique dans les trois. Une jauge de 0 à 100 par gang et par joueur, qui part
à 50 — inconnu, ni attendu ni chassé — et cinq paliers : sous 20 on vous tire
à vue, sous 40 on ne vous confie rien, entre 40 et 60 on vous ignore, au-dessus
de 60 on vous laisse passer, au-dessus de 80 **on se bat à côté de vous**.
Tuer chez l'un coûte onze points chez lui et en rapporte cinq chez ses deux
rivaux *du secteur* — trois morts pour se faire tirer dessus, et la sanction
s'annonce deux fois avant de tomber. Brûler une de leurs voitures compte
aussi, sinon on ferait le vide au lance-roquettes sans jamais fâcher personne.
Détail : `CONCEPTION-GANGS.md`.

**Les alliés.** Au-dessus de quatre-vingts, un homme de gang ne se contente
plus de laisser passer : il tire sur ce qui vous tire dessus — le flic qui
vous poursuit, l'homme du gang qui vous canarde. Il ne vise jamais un autre
JOUEUR : le respect serait une arme à distance. Un anneau au sol sous ses
pieds dit son humeur, et les trois barres du district s'empilent au-dessus de
la fiche.

**Les contrats.** Une cabine par territoire, et l'employeur est le gang **du
territoire** — pas le numéro de la cabine, comme c'était le cas jusqu'à la
phase 4. Il paie pour nettoyer chez un rival, faire repeindre une voiture, ou
tenir deux étoiles jusqu'au bout. Sous quarante de respect il n'a rien pour
vous ; au-dessus de soixante le travail est plus dur et paie une fois et demie
plus ; au-dessus de quatre-vingts, deux fois et demie. La prime se touche en
argent ET en respect — et fâche d'autant le gang qu'on a servi contre lui.

**La recherche monte en six crans** (`CONCEPTION-RECHERCHE.md`). Une voiture de
patrouille, puis la police à pied, puis **le SWAT** dont le fourgon débarque
quatre hommes, les barrages, **les agents spéciaux** et l'hélicoptère, et enfin
**l'armée** : un camion olive et un char qui canonne — un obus toutes les deux
secondes et demie, qui souffle tout dans cent vingt pixels, tôle comprise. Les
quatre corps ont leur tenue, leur carrosserie, leur cadence et leurs dégâts ;
la police ordinaire reste de la partie même à six, sinon la rue n'a plus l'air
d'une ville en panique.

**L'autoradio** (phase 10). Six stations — PIKS FM, Radio Taverne, Canal Forêt,
Ondes du village, Fréquence police, Silence — et **chaque carrosserie a la
sienne** : on monte dans un taxi et on tombe sur les ondes du village, dans une
sportive sur la synthé, dans un camion sur la taverne. C'est le détail de GTA 2
qui donne une personnalité à une voiture volée ; sans lui, en changer ne change
que la tôle. On tient `R` : une **roue** s'ouvre, six secteurs, on pousse dans une direction
et on relâche. C'est le geste de la roue d'armes des GTA modernes, et il vaut
mieux qu'un défilement — à six stations, appuyer cinq fois pour revenir à la
précédente, ça se paie en tôle. Elle ne met rien en pause (la manche est
multijoueur), mais le volant est neutralisé pendant qu'on vise : pousser à
gauche pour choisir enverrait la voiture dans le trottoir. Une pastille marque
la station qui joue.

**Ajouter une station** : déposer le `.ogg` dans `sons/`, ajouter une ligne à
`Sons.STATIONS` (nom, piste, couleur), et `outils/radio.tscn` vérifie que le
fichier existe — une piste mal orthographiée ne fait sinon aucun bruit et
aucune erreur.
La radio s'allume en montant et s'éteint en descendant — un autoradio qui joue
pendant qu'on court dans la rue, c'est une bande-son, pas une radio. La
fréquence de la police n'a pas de morceau : elle DIT des choses, en empruntant
les voix de la radio de bord. Les morceaux sont ceux du dépôt (CC0).

**Le mode solo.** `--solo` (ou `?solo=1`) fait tourner le jeu SANS SERVEUR : le
canal se rejoint lui-même, le joueur est seul dans la salle et il en est
l'hôte. Sans ça, le jeu était injouable dès que le réseau manquait — le salon
attendait un hôte qui ne venait jamais : clone du dépôt sans `config.cfg`,
Supabase en panne, avion. C'est aussi ce qui permet de jouer une manche
ENTIÈRE au banc et de la photographier :

```bash
godot --headless --path . --banc-jeu=carnage --manche=20 --solo
xvfb-run -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
  --banc-jeu=carnage --manche=40 --solo --banc-etoiles=3 --photo=/tmp/vues
```

**Le menu de triche** s'ouvre au code Konami — ↑ ↑ ↓ ↓ ← → ← → B A, tapé en
roulant. Dix codes : blindage, arsenal, cinquante mille dollars, casier vierge,
six étoiles, atelier complet, respect au maximum ou à zéro, un char pour vous,
et la nuit qui s'arrête. Ils passent par les mêmes fonctions que le jeu (le
magot par `_encaisser_argent`, le char par `_naitre_auto`) : un code qui
écrirait dans les variables finirait par mentir. ⚠ **Il coûte le classement** :
dès qu'un code est activé, le score de ce joueur n'est plus déposé en base —
on écarte le tricheur, pas la manche, sinon dix touches suffiraient à effacer
le score des trois autres. B et A se lisent par code de touche et non par code
physique : sur un AZERTY, on appuie sur les lettres imprimées.

**Les à-côtés** (`CONCEPTION-A-COTES.md`). Huit colis dorés dans la ville, dix
à trouver et une prime de collection ; un crâne rouge qui lance un **Kill
Frenzy** — huit victimes en trente secondes, l'arme fournie ; la **course de
taxi**, un métier attaché à une carrosserie (on devient chauffeur en volant un
taxi) ; et les **cascades**, qui sont des FRÔLEMENTS faute d'axe vertical :
passer au ras d'une voiture qui roule, à pleine vitesse, sans la toucher.

**L'atelier.** Un garage de peinture sur deux vend aussi des modifications, sur
cinq pastilles peintes en couronne : on se gare sur celle qu'on veut et `F`
achète. Plaques maquillées (la recherche cesse de monter quarante-cinq
secondes, elle ne redescend pas), mitrailleuse de bord, mines, taches d'huile,
bombe qui saute six secondes après qu'on a quitté la voiture. Mines et flaques
vivent chez l'hôte comme les caisses ; une mine s'amorce avant de mordre, une
flaque glisse aussi sous celui qui l'a posée. Détail : `CONCEPTION-ATELIER.md`.

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

**Les kits Kenney reprennent du service.** Depuis la v10, ce qui roule et ce
qui meuble la rue ne sort plus de nos cubes mais des kits CC0 de Kenney
(`modeles/kenney/`, licence dans `LICENCE-kenney.md`) : dix-sept carrosseries
du Car Kit (berline, sportive, citadine, 4×4, taxi, van, livraison, camion,
police, pick-up, ambulance, camion de pompiers… ⚠ tournées d'un quart de tour
dans l'AUTRE sens que le reste du kit : les carrosseries regardent +Z quand
les props regardent −Z, et avec la rotation commune toute la ville roulait en
marche arrière, phares derrière et calandre au cul), les lampadaires, feux,
bennes et panneaux du City Kit: Roads, les arbres, buissons et bancs du Nature
Kit. Ce que les kits n'ont pas — le bus, la limousine, les motos, les bornes,
les conteneurs, la fontaine — reste en voxels : mieux vaut deux styles voisins
qu'un modèle manquant. Trois pièges, tous vus à l'image : un glTF Kenney
référence son atlas `Textures/colormap.png` en fichier EXTERNE et **chaque kit
a le sien** (copier les seuls maillages donne des modèles tout blancs, sans le
moindre message d'erreur) ; un modèle a PLUSIEURS matières (le tronc et le
feuillage d'un arbre) alors qu'une nappe n'en porte qu'une, donc
`FormesCarnage.maillage_kenney` fond tout en une surface en écrivant la couleur
de chaque matière dans la COULEUR DE SOMMET — sans quoi l'arbre entier prenait
la couleur de son feuillage ; et la palette du Nature Kit est pastel, son
feuillage TURQUOISE, donc on recolore par nom de matière (`TEINTES_KENNEY`) —
le modèle reste celui de Kenney, la palette est la nôtre. Les modèles sont
posés comme le reste : une nappe (`MultiMesh`) par modèle et par morceau, la
longueur d'une voiture restant celle de son gabarit (les collisions, les places
de stationnement et le pare-buffle s'y réfèrent). Les IMMEUBLES aussi viennent des kits :
commercial pour le centre et les affaires, industriel pour les hangars,
suburban pour les pavillons. On choisit le modèle dont le rapport
hauteur/largeur ressemble le plus au volume demandé par le plan, puis on
l'étire à l'emprise exacte — un modèle bien choisi s'étire peu —, et la teinte
du quartier passe en couleur d'instance, sinon la ville entière serait
gris-bleu. **Et le mur tient** : jusqu'à la v12, la grille de
voxels attendait sous le modèle et le premier cube arraché la faisait prendre
le relais — un immeuble dessiné se changeait sous les yeux du joueur en tas de
cubes, et une rue mitraillée redevenait la ville d'avant. Une façade encaisse
donc maintenant : `MorceauVille.casser` ne rend plus que le point et la
couleur touchés, de quoi jouer la poussière, les éclats et le choc. La grille
reste — elle sert aux collisions et à savoir ce qu'une balle a touché — mais
elle n'est jamais maillée tant que l'immeuble est debout, et il l'est
toujours : la ville coûte dix fois moins de rectangles qu'en voxels pleins.
**Deux voisins ne se ressemblent pas** : on ne prend plus le seul modèle au
meilleur rapport hauteur/largeur (deux immeubles de même taille — et un pâté
n'en fait pas d'autres — tombaient forcément sur le même) mais l'un des cinq
plus proches, tiré par l'identifiant. **Et ils ne se touchent pas** : une
façade laisse quinze pixels au bord de sa tuile, trente entre deux immeubles ;
à douze, avec les quartiers qui rognaient encore de moitié, la ville n'était
plus qu'un bloc. ⚠ Un quart de tour n'est permis qu'à un bâtiment d'emprise
CARRÉE : l'échelle étant portée par la base, tourner une emprise de trois
tuiles sur une la faisait déborder en travers de la rue. La nuit, les fenêtres s'allument par le shader `KENNEY` : on repère
les carreaux à leur bleu franc dans l'atlas — ⚠ seulement sur les faces
VERTICALES, sans quoi le gris-bleu des toitures passait pour du vitrage et
les toits luisaient.

**Les rues viennent du kit.** Depuis la v13, la chaussée des rues de la GRILLE
est pavée avec le City Kit: Roads (`modeles/kenney/routes/`) : bitume,
marquage médian, passages piétons et surtout **trottoirs en relief** — c'est ce
relief qui manquait le plus, un trottoir peint à plat ne borde rien. Une tuile
du kit est une dalle de 1 × 1 unité posée au sol ; nos rues font DEUX tuiles de
large, on pose donc une dalle par PAIRE de tuiles, depuis sa tuile ouest (ou
nord), étirée à vingt unités en travers et dix dans le sens de la marche — une
route droite s'étire dans son sens sans que rien ne se voie. Les carrefours
prennent une seule dalle pour leurs quatre tuiles. ⚠ La route du modèle court
selon X et ses trottoirs bordent en Z : une rue verticale demande un quart de
tour, et l'échelle s'applique AVANT la rotation — tournée d'abord, la dalle
emportait sa largeur en travers de la rue. ⚠ L'asphalte du kit est gris TRÈS
clair : posé tel quel il passait toute la ville au blanc, d'où `TEINTE_ROUTE`.
Ce qui n'est PAS pavé : les boulevards, les places en étoile et les
esplanades — leur géométrie est libre et ne se pave pas en tuiles carrées ;
elles gardent le sol peint par le shader. Les dalles sont posées deux
centimètres au-dessus de lui, pour que les deux surfaces ne se disputent pas
le même plan, et ne projettent pas d'ombre — plate, elle tomberait sur
elle-même en un damier sale.

**La ville est un ARCHIPEL.** Depuis la v13, trois bras d'eau (`PlanVille.BRAS`)
la découpent en six îles : un bras d'ouest en est — l'ancienne rivière — et
deux du nord au sud. On voit la rive d'en face, on sait qu'on change de monde
en passant le pont, et la police d'un district met un temps fou à venir. Deux
réglages ont demandé plusieurs essais à l'image : les bras sont LARGES (vingt
à vingt-six tuiles) et les ponts RARES (une avenue sur trois,
`PONTS_PAR_AVENUE`) — c'est le même problème vu deux fois, un bras de dix
tuiles franchi à chaque avenue ne se lit pas comme un bras de mer mais comme
une flaque percée de trous.

Trois pièges, tous vérifiés carte en main. ⚠ Un bras se franchit par les
avenues **perpendiculaires** : une avenue qui court dans le sens du courant ne
traverse rien, elle longe la berge, et la prendre pour un pont ouvrait un
couloir d'asphalte au milieu de l'eau sur toute la carte. ⚠ Là où deux bras se
croisent, il faut être un pont pour **les deux**, sinon le même couloir
réapparaît au croisement. ⚠ Et la ville doit rester **d'un seul tenant** : il
n'y a aucune recherche de chemin dans ce jeu — une voiture qui bute sur l'eau
tourne au hasard, une patrouille reste plaquée contre le rivage. On le vérifie
en comptant les composantes connexes de la carte (un atelier qui parcourt les
tuiles praticables en largeur) : il doit en rester UNE.

Ce que l'archipel a obligé à reprendre : le **cœur** (`PlanVille.coeur`), le
point de terre le plus proche du centre géométrique, parce que le milieu de la
carte peut désormais tomber en pleine eau — et c'est vers lui qu'on ramène qui
sort de la ville, et autour de lui que naissent les quatre joueurs. `depart`
vérifie en plus que chaque place est sur la **même terre** que le cœur
(`meme_terre`, un échantillonnage du segment) : tirés autour du centre, deux
joueurs tombaient de part et d'autre d'un bras et ne se croisaient pas de la
manche. Et les PONTS ont enfin une géométrie : un garde-corps de chaque côté
du tablier et une pile qui plonge dans l'eau sous une travée sur trois
(`MorceauVille._poser_le_pont`, une instance par tuile et par côté — une file
de cubes en coûterait mille sur un pont de vingt-six tuiles). `--banc-position=pont`
cadre un tablier : un pont qu'on ne photographie pas est un pont qu'on ne
corrige pas.

**Les habitants sont des gens.** Depuis la v12, les piétons, les hommes de
main, les flics à pied et les joueurs descendus de voiture viennent du CASTING
partagé (`commun/personnages.gd`) : le maillage habillé du kit « Animated
Characters » de Kenney, douze peaux, et les trois animations du kit greffées
dessus. C'est le même casting qu'à la création de personnage — celui qu'on
choisit dans le menu est celui qui marche en ville
(`Session.personnage_affiche`), et un autre joueur se voit sous le personnage
que son identifiant désigne, calculé pareil chez tous. Nos bonshommes en cubes
ne tenaient plus la comparaison depuis que les voitures et les immeubles sont
dessinés : `VoxelsCarnage.personnage` a disparu. Trois réglages tenus à
l'image. L'ÉCHELLE : le casting est réglé pour le village (1,80 unité, la
taille d'un homme quand la tuile en fait dix) ; en ville la tuile fait le
triple et une berline dix unités de long, un piéton d'un mètre quatre-vingt y
serait un insecte — d'où `TAILLE_HABITANT`. L'ANIMATION : on ne parle au
lecteur que quand l'animation change, sinon `play` relance le pas à zéro à
chaque image et toute la rue piétine sur place. LA COULEUR : elle ne se met
pas sur le corps — teinter la texture d'une tenue teint aussi la peau et les
cheveux — mais sur une CASQUETTE posée sur le crâne : vue de dessus, et la
caméra ne voit à peu près que ça, c'est le seul endroit du personnage qui se
lise. Le fanion des hommes de main se dresse maintenant AU-DESSUS de la tête ;
planté à hauteur d'épaule comme du temps des cubes, il passait devant le
visage.

**Les options du hub commandent la ville.** Ce qu'on règle dans l'écran des
options vaut partout, Carnage compris — un réglage qui ne s'applique qu'à
moitié se lit comme une panne du jeu. Les TOUCHES : les cabochons d'aide en bas
de l'écran sont construits avec `Reglages.nom_de_touche`, jamais écrits en dur
— un joueur qui a remis « avancer » sur la flèche haut lisait quand même
« Z S » et cherchait le défaut dans le jeu ; et le nom affiché est celui GRAVÉ
sur son clavier (« Z » sur un AZERTY là où le moteur dit « W »). Les OMBRES :
`Reglages.ombres` éteint l'ombre portée du soleil de la ville — les taches de
contact sous les voitures restent, ce sont des maillages, et sans elles les
voitures flottent. Les EFFETS : `Reglages.effets` coupe le halo de
l'environnement et la passe de post-traitement (vignette, grain, coup rouge à
l'impact), qui relit l'image entière et est la première chose à retirer sur
une machine lente. La finesse de rendu et les volumes, eux, agissent déjà par
le viewport racine et les bus audio. ⚠ `MatieresCarnage` va chercher ces
réglages DANS L'ARBRE (`_reglage`) au lieu de nommer l'autoload : les ateliers
et les bancs lancés en `-s script.gd` n'ont pas d'autoload, et une référence
directe les ferait tous tomber en panne de compilation.

**Ça brûle.** Une voiture qui saute laisse un BRASIER, et un brasier est une
chose vivante : il chauffe ce qui l'entoure (passants, joueurs, tôle), il
essaie toutes les trois secondes de sauter sur une voiture voisine — qui
explose et allume le sien, c'est ainsi qu'un carambolage part en chaîne —, il
ronge le mur qu'il lèche un cube à la fois en montant le long de la façade,
puis il s'épuise en une trentaine de secondes (`VilleVivante.allumer`,
`_animer_les_feux`, au plus vingt-six foyers). Les feux vivent chez l'hôte
comme le reste de la ville et voyagent dans l'instantané : deux joueurs voient
le même incendie. Chacun s'inflige localement la brûlure qu'il traverse —
attendre l'aller-retour de l'hôte rendrait le feu inoffensif à pleine vitesse.
Le rendu est réglé pour une caméra presque à la VERTICALE, ce qui est tout le
problème du feu vu de dessus : une colonne de fumée droite ferait un couvercle
sur le quartier. Un brasier, ici, c'est un cœur de braises émissives qui bat
au sol (des particules additives ne se voient pas en plein jour, ça si), des
langues courtes qui lèchent autour, un filet de suie qui part EN BIAIS pour
sortir du champ, et une flaque de lumière qui vacille — la nuit, un incendie
éclaire sa rue. ⚠ Deux pièges : `amount_ratio` n'existe pas sur des
`CPUParticles3D` (on module la taille et la durée de vie, jamais le nombre,
qui réalloue tout le tableau), et la rampe de couleur MULTIPLIE la couleur de
base — une rampe grise sur une base blanche sort blanche, la suie se peint
dans `color`. `--banc-feu=N` allume N foyers autour du pilote et les
renouvelle toutes les huit secondes : sans ça on ne photographie jamais la
ville qui brûle.

**Les secours viennent.** Un camion de pompiers par tranche de trois foyers
(deux au plus, sinon c'est un convoi qui se gêne dans les rues) et un Medicar
quand un joueur est à terre : ils naissent au bord du champ cinq secondes
après l'alerte, roulent droit sur ce qu'ils doivent traiter en longeant les
murs comme les patrouilles — un camion qui respecte les sens interdits
n'arrive jamais —, puis le camion ARROSE (le foyer perd sa force sous la
lance, à cent cinquante pixels) et le Medicar RELÈVE (le joueur se remet
debout tout de suite, à moitié soigné, au lieu d'attendre). Quand il n'y a
plus rien à faire, le véhicule redevient civil et se fait oublier. Le camion
de pompiers est le dix-neuvième gabarit : caisse rouge, échelle couchée sur le
toit, bande blanche, deux gyrophares, tuyau enroulé à l'arrière.

**La cabine dit ce que le gang pense de vous.** L'enseigne au-dessus de chaque
téléphone porte une couleur par palier de respect — du rouge « on vous tire
dessus » au vert clair « on se bat avec vous » —, et c'est la MÊME table
(`FormesCarnage.COULEURS_HUMEUR`) que l'anneau sous les pieds de ses hommes :
la jauge de respect se lit depuis la rue, sans ouvrir un menu.

**Le jour et la nuit.** La même horloge que le village : un cycle de quinze
minutes (`MatieresCarnage.nuit()`), neuf de jour, une de crépuscule, quatre de
nuit, une d'aube. Le ciel, le brouillard, le soleil et la lune s'interpolent
entre trois heures clés (`HEURES`) ; les fenêtres, enseignes et lampadaires
montent en émission quand la nuit tombe, et la rue passe du gris chaud au bleu
sourd — jamais noire : une nuit noire vue de dessus, c'est un écran vide.
`--nuit=<0..1>` (`?nuit=` dans l'URL) force l'heure pour photographier.

**Le temps qu'il fait.** Sur la même horloge, un temps toutes les dix minutes
— clair, couvert, pluie, orage ou brouillard, tiré du créneau et donc le même
pour les quatre joueurs sans un octet de réseau (`MeteoCarnage`). Le couvert
grise le ciel et le soleil et efface l'ombre ; la pluie mouille le bitume de
jour (flaques, reflets, éclats d'impacts), trace ses traits sur l'écran, fait
son bruit (synthétisé : le dossier des sons n'a pas de pluie) et retire 18 %
d'adhérence ; l'orage ajoute l'éclair qui blanchit tout un dixième de seconde
et le tonnerre qui arrive avec le retard de la distance ; le brouillard mange
l'horizon. Pas une particule : des calques d'écran et des uniformes de shader,
comme GTA 2. `--meteo=pluie` fige un temps, le code MÉTÉO passe au suivant,
`--banc-eclair` tient l'éclair pour la photo. Sur sol mouillé, chaque flaque de
lumière rend un trait allongé (le reflet), et un faisceau additif part des
phares de toute voiture qui roule — une lueur par temps clair, un vrai coin de
lumière dans la brume. Détail : `CONCEPTION-METEO.md`.

**Deux vraies lumières, pas une de plus.** Le mode compatibilité n'en supporte
que huit par objet ; une flaque additive au sol sous chaque lampadaire fait le
même effet pour rien. Les deux exceptions sont les phares de VOTRE voiture,
deux projecteurs qui ne s'allument que la nuit et font surgir les façades dans
leur faisceau. Le **gyrophare** d'une patrouille tourne pour de vrai : bleu puis
rouge quatre fois par seconde, feu du toit et flaque additive au sol ensemble
(`FormesCarnage.clignoter_gyrophare`) — deux cubes émissifs sur un toit ne se
voient pas de soixante unités de haut, une rue qui passe au bleu puis au rouge,
si. Le reste de l'ambiance est du shader : l'ombre des nuages qui
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
barre d'accent à gauche de chaque panneau (`ui/fabrique.gd`) — le chargement,
le salon, le pseudo, les options et la manche partagent la même main. En
manche, `ui/hud.gd` peint tout en un `_draw` : chrono et scores en cartouche
(une barre de course sous chaque nom), les six têtes de recherche toujours
visibles au milieu, la fiche du joueur en bas à gauche — jauges de vie et de
tôle, arme et munitions, puces d'état (qui vous chasse, arène, garage) —, le
contrat en bas au milieu avec son sablier, et les touches en cabochons sur la
dernière ligne, qui s'estompent quinze secondes après le départ. Le jeu ne
donne au HUD qu'une fiche (`Partie.fiche_joueur`) : le HUD ne connaît pas le
jeu, seulement la fiche qu'on lui tend.

**Le radar, en haut à droite.** Centré sur soi, le nord en haut : la ville
fait six cent quatre-vingts tuiles, un plan entier n'y montrerait plus rien.
Les pâtés y sont teintés du gang qui les tient (vert les parcs, bleu l'eau), les
rues en sombre, les lieux à portée en pastilles nommées. La cible d'un contrat
clignote ; hors du cadre, une flèche au bord dit où aller et à combien de
tuiles. On réapparaît aussi près de là où l'on est tombé, jamais au centre —
dans une ville de soixante-huit mille pixels, ce serait repartir de zéro.

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

### Les bancs de la ville vivante

Ceux-là ne demandent ni réseau ni image : le plan et la ville vivante sont du
code pur, et c'est ce qui permet de les interroger.

```bash
godot --headless --path . res://outils/compiler.tscn   # tout se compile-t-il ?
godot --headless --path . -s outils/respect.gd         # gangs, paliers, contrats, alliés
godot --headless --path . -s outils/atelier.gd         # baies, mines, huile, bombe, plaques
godot --headless --path . -s outils/recherche.gd       # les six crans, les quatre corps, le char
godot --headless --path . -s outils/missions.gd        # colis, Kill Frenzy, taxi
godot --headless --path . -s outils/train.gd           # la voie, les rames, les quais, le fauchage, la casse
./outils/apercu.sh TRAIN /tmp/rail.png rail 95         # une rame à quai, dans la ville
./outils/voir.sh "t:,t:quai,t:casse" 24                # la rame, le quai, le compacteur
./outils/apercu.sh TRAIN /tmp/casse.png casse 70       # une casse au bord du ballast
godot --headless --path . -s outils/marche.gd          # les 15 intérieurs sont-ils praticables ?
./outils/vitrine.sh repaire2 "" "" "" pantin           # l'intérieur d'un repaire de gang
godot --headless --path . -s outils/provisions.gd      # faim, soif, catalogue, supérettes
./outils/tableau.sh /tmp/menu.png superette            # le menu de la supérette
./outils/tableau.sh /tmp/pause.png pause               # le menu de pause et la sortie
./outils/tableau.sh /tmp/triche.png triche             # les 18 codes du menu Konami
godot --path . --solo --banc-jeu=carnage --manche=40 --banc-subjectif --photo=/tmp/vues
./outils/apercu.sh PROVISIONS /tmp/sup.png superette 55 # la façade dans la ville
./outils/voir.sh "v:0+,v:13+,v:16+,v:18+" 11           # la mitrailleuse de toit sur quatre gabarits
./outils/voir.sh v:peintures 3.2                       # les dix peintures du garage sur le 4x4
./outils/voir.sh v:peintures:0-8 3.4                   # les carrosseries de la ville, une peinture chacune
./outils/voir.sh "c:0,c:1,c:2,c:2-" 7                  # les trois cabines, dont une éteinte
godot --headless --path . res://outils/konami.tscn     # la suite ↑↑↓↓←→←→BA
godot --headless -s outils/meteo.gd                     # le tirage, le fondu, le temps forcé, le bruit de pluie
godot --headless --path . res://outils/radio.tscn      # les stations et leurs pistes
./outils/tableau.sh /tmp/triche.png oui                # le menu de triche en image
godot --headless --path . -s outils/flotte.gd          # mouillages et navigation
godot --headless --path . -s outils/territoires.gd     # la carte des territoires en PNG
./outils/tableau.sh                                    # les barres de respect à l'écran
```

`outils/compiler.sh` mérite un mot : `--check-only --script` refuse tout
fichier qui parle à un autoload, si bien que les deux plus gros fichiers du
jeu n'étaient vérifiés par rien entre deux parties. Le banc les charge dans
une scène — donc avec les autoloads — et liste les refus.

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
`--meteo=clair|couvert|pluie|orage|brouillard` fige le temps, `--banc-eclair`
tient l'éclair allumé.
`--banc-position=colonne,ligne` (en tuiles) fait partir ailleurs qu'au centre —
sans ça, le banc ne photographie jamais le port ni la banlieue ; `=etoile`,
`=pont`, `=rail`, `=superette` et `=garage` visent un lieu dont la place
dépend du code de la manche (sous le portail du garage, la voiture ressort
repeinte à la première image). Dans le
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

### Ce que la ferme a laissé derrière elle

L'écran ÉNIGME a été retiré du dépôt — mais il vaut la peine de retenir
pourquoi il avait cessé de fonctionner. La réécriture de `commun/terrain.gd`
avait emporté six fonctions dont il dépendait, et il **ne se chargeait plus du
tout** : six « Static function not found » à l'ouverture. Personne ne l'a vu
pendant des jours, pour une raison qui vaut d'être retenue — **rien ne
chargeait les scripts entre deux parties**. `--check-only` refuse tout fichier
qui parle à un autoload, et un jeu qu'on n'ouvre pas ne dit rien.

C'est ce trou-là qui a donné `outils/compiler.sh`, qui charge maintenant TOUS
les scripts du dépôt, autoloads compris, et liste les refus. Il reste après le
départ de la ferme : c'est le filet qui manquait.

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
