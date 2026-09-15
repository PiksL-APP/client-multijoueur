class_name GenerateurColline
extends RefCounted
## LE TROISIÈME QUARTIER TÉMOIN : LA COLLINE (cahier § 4).
##
## Les deux premiers témoins ont éprouvé la ville plate (le centre) puis la
## côte (la plage). Celui-ci éprouve LE RELIEF, et rien d'autre — c'est la
## seule partie du cahier qui restait sans preuve :
##
## * « pas de pente sous les quartiers bâtis : les quartiers sont sur des
##   PLATEAUX, le relief se franchit entre eux » → cinq terrasses, chacune
##   parfaitement plate, séparées de deux paliers ;
## * « les collines se montent en LONGS LACETS (rampes enchaînées avec des
##   plats) » → une seule route monte, d'un bout à l'autre du coteau, et fait
##   demi-tour à chaque terrasse ;
## * « murs de soutènement : béton en ville, rochers hors ville » → le nez de
##   chaque terrasse est un mur (posé par le rendu, `_poser_soutenements`) ;
## * « bâtiment sur pente : sur terrasses » → les maisons bordent la route de
##   chaque terrasse, jamais le talus ;
## * « piétons et relief : escaliers du kit entre les niveaux » → un escalier
##   droit relie les terrasses là où le lacet fait un long détour.
##
## L'ordre du cahier (§ 10) est respecté : terrain → axes → quartiers → rues →
## lots → détails.
##
## LA COUPE, du sud au nord : la ville basse (palier 0), puis cinq terrasses
## qui montent jusqu'au palier 10 — cinquante unités, vingt-cinq mètres de
## dénivelé sur trente cases. Les flancs est et ouest ne sont PAS terrassés :
## ils descendent EN PENTE LISSÉE, en herbe et en rochers, et c'est là qu'on
## voit que la colline est une colline et non un escalier.
##
## ⚠ LE RELIEF NE SE FRANCHIT QU'AUX NEZ DE TERRASSE. Partout ailleurs le sol
## varie continûment. C'est ce qui garde les objets AU SOL : une case qui
## tombe d'un bloc entier d'un bord à l'autre n'a pas de hauteur unique, donc
## l'arbre qu'on y pose flotte d'un côté ou s'enterre de l'autre (« enlève tes
## dénivelés dans la montagne, sinon les objets flottent », client, 12/09).

## ⚠ ET DEPUIS LE 14/09, C'EST UN VILLAGE DE PIERRE. « Je m'occupe des
## modifications à faire mais tu dois changer TOUS les modèles par des maisons
## de pierre (style sud de la France) » : le coteau ne porte plus un seul
## immeuble de rapport ni un seul pavillon d'Amérique, et le nez de ses
## terrasses n'est plus un panneau de falaise mais un MUR DE SOUTÈNEMENT
## maçonné — la pièce qui manquait pour qu'un terrain en gradins se lise comme
## un village perché. Voir `_lots` pour les maisons et `_soutenements` pour les
## murs.

## Les courbes larges et le rond-point (cahier § 5) : brique commune, appelée
## par `preload` — un `class_name` neuf n'existe pas dans l'export web.
const ANGLES := preload("res://commun/ville2/angles.gd")

## Les règles communes à tous les quartiers : rien sur la chaussée, et pas
## une pelouse nue. Appelées en dernier (voir `commun/ville2/proprete.gd`).
const PROPRETE := preload("res://commun/ville2/proprete.gd")
const ATLAS := preload("res://commun/ville2/atlas.gd")
const CHEMINS := preload("res://commun/ville2/chemins.gd")
const TEINTES := preload("res://commun/ville2/teintes.gd")

## Les panneaux publicitaires (cahier § 7) : toits, pignons aveugles, bords
## d'axe. Brique commune — l'affichage est une règle de ville, pas de quartier.
const AFFICHES := preload("res://commun/ville2/affiches.gd")

const CASE := Ville2.CASE
const DEMI := Ville2.DEMI
const PALIER := Ville2.PALIER

## LES TERRASSES, du bas vers le haut : la bande de cases (j0..j1 compris), le
## palier, la largeur (i0..i1 compris) et la ligne de la route. Chaque terrasse
## est plus étroite que celle d'en dessous : c'est ce qui donne une silhouette
## de colline plutôt qu'un gâteau de mariage.
## Le curseur de relief. À 1,0 la colline a sa hauteur pleine ; à 0 le terrain
## est plat et il n'y a plus que le plan de ville. `p` est le palier de chaque
## terrasse et RIEN d'autre dans ce fichier ne fixe une altitude : cette seule
## ligne commande tout le dénivelé.
const RELIEF := 1.0

## Le palier effectif d'une terrasse : son palier nominal, fois le relief.
static func palier_de(t: Dictionary) -> float:
	return float(t["p"]) * RELIEF

const TERRASSES := [
	{"j0": 21, "j1": 25, "i0": 4, "i1": 36, "p": 4, "route": 23},
	{"j0": 16, "j1": 20, "i0": 6, "i1": 34, "p": 8, "route": 18},
	{"j0": 11, "j1": 15, "i0": 8, "i1": 32, "p": 12, "route": 13},
	{"j0": 6, "j1": 10, "i0": 11, "i1": 29, "p": 16, "route": 8},
	{"j0": 2, "j1": 5, "i0": 14, "i1": 26, "p": 20, "route": 4},
]

## LA VILLE BASSE : tout ce qui est au sud de la première terrasse.
const J_BASSE := 26
## ⚠ QUATRE PALIERS D'UNE TERRASSE À L'AUTRE — VINGT UNITÉS, LA HAUTEUR EXACTE
## D'UN BLOC DE FALAISE KENNEY. Mesuré : `cliff_rock` fait 20 × 20 × 3,4 unités,
## `cliff_block` 20³, `cliff_blockHalf` 20 × 10 × 20, `cliff_blockQuarter`
## 20 × 5 × 20 — le kit nature est bâti sur la CASE, avec des marches d'un
## palier. Une terrasse d'une case de haut se pare donc de vraies falaises,
## posées à l'échelle du kit, sans étirement. (À trois paliers il fallait les
## mettre à l'échelle : 15 unités de haut, donc 15 de large, et une fente tous
## les cinq.) Le sommet est à cent unités — cinquante mètres, le haut de la
## fourchette du cahier (§ 4).
## ⚠⚠ LE FLANC DESCEND PAR TERRASSES, PAS PAR MARCHES D'UNE CASE. Trois essais
## ont été nécessaires, et les deux premiers ont été refusés par le client le
## même jour :
##
## 1. pente lissée (0,85 palier par case) → « je ne veux pas de pente lissée » ;
## 2. un palier par case → vingt marches fines qui descendent en éventail :
##    « je voulais juste pas d'escalier comme tu l'as fait » ;
## 3. celui-ci — UNE MARCHE DE QUATRE PALIERS TOUS LES `LARGE_MARCHE` CASES.
##
## La différence n'est pas de degré. Une marche de quatre paliers fait VINGT
## UNITÉS, c'est-à-dire une case : la hauteur exacte d'un `cliff_block` du kit
## nature (mesuré 20 × 20 × 20). Chaque redan est donc un bloc du kit posé tel
## quel, et sa largeur de trois cases en fait une TERRASSE — quelque chose où
## l'on peut marcher, poser un arbre, faire passer un sentier. Une marche d'un
## palier sur une case de large n'est ni l'un ni l'autre : c'est une contremarche,
## et vingt contremarches font un escalier.
##
## Du sommet (palier 20) au pied, cinq redans suffisent, soit quinze cases.
const MARCHE_FLANC := 4.0              ## la hauteur d'un redan, en paliers
const LARGE_MARCHE := 3                ## sa largeur, en cases

## Le palier du flanc à `d` cases du bord de la terrasse.
static func palier_du_flanc(depart: float, d: int) -> float:
	var redan := float((d + LARGE_MARCHE - 1) / LARGE_MARCHE)
	return depart - redan * MARCHE_FLANC

## LES LACETS : la route monte par les extrémités, alternativement à l'est et
## à l'ouest. `x` est la colonne du demi-tour.
const LACETS := [
	{"x": 33, "de": 0, "vers": 1},
	{"x": 9, "de": 1, "vers": 2},
	{"x": 30, "de": 2, "vers": 3},
	{"x": 13, "de": 3, "vers": 4},
]

const PRENOMS := ["des Terrasses", "du Belvédère", "des Vignes", "de la Corniche",
	"du Coteau", "des Cyprès", "de la Vue", "du Chemin Creux", "des Oliviers"]

## ⚠⚠ TOUT LE BÂTI EST DE LA PIERRE DU SUD, ET RIEN D'AUTRE (client, 14/09).
##
## Le kit n'a pas de mas provençal et n'en aura pas. Ce qui fait LIRE la pierre
## à la distance où l'on juge un quartier — celle d'une capture vue d'en haut —
## ce n'est pas le plan de masse, c'est trois choses :
##
## 1. LE VOLUME : un corps simple sous un toit à deux pentes. Tout le kit
##    `pavillons` est bâti là-dessus. Le kit `batiments` (le Commercial), lui,
##    est bâti sur des rez-de-chaussée VITRÉS et des toits plats : les sept
##    immeubles de rapport et les trois commerces qui tenaient la ville basse
##    et les terrasses d'en bas sont donc partis EN ENTIER. Une vitrine
##    d'immeuble dans un village perché se voit de l'autre bout de la carte ;
## 2. LE MUR : la teinte d'instance, prise dans `TEINTES.PIERRE_DU_SUD` — le
##    calcaire du Lubéron, et jamais un blanc pur ;
## 3. LE TOIT : la bande verte de l'atlas repeinte en tuile (`ATLAS.MIDI`,
##    « que de la tuile, dix nuances de cuisson »), les annexes en tuile
##    passée (`ATLAS.VIEILLE`). Voir la fin de `generer`.
##
## LES VINGT-ET-UN MODÈLES DU KIT PASSENT TOUS, rangés par gabarit. « Tu as
## l'air de toujours utiliser les mêmes maisons avec les mêmes variantes »
## (12/09) a déjà été dit deux fois : trois sacs qui épuisent vingt-et-un
## modèles avant d'en répéter un seul sont la seule réponse qui tienne, et
## chaque rangée tire dans un sac différent du sien.

## LES MAS ET LES BASTIDES : les plus larges et les plus profonds, un long
## corps de logis sous une panne faîtière. Ils tiennent le côté aval des
## terrasses hautes, là où la vue fait la valeur du terrain.
const MAS := ["pavillons/building-type-b", "pavillons/building-type-d",
	"pavillons/building-type-n", "pavillons/building-type-f",
	"pavillons/building-type-t", "pavillons/building-type-u",
	"pavillons/building-type-s"]
## LES MAISONS DE VILLAGE : le tout-venant, une à deux travées, mitoyennes dès
## qu'on les serre.
const MAISONS := ["pavillons/building-type-e", "pavillons/building-type-o",
	"pavillons/building-type-c", "pavillons/building-type-j",
	"pavillons/building-type-a", "pavillons/building-type-l",
	"pavillons/building-type-r", "pavillons/building-type-k"]
## LES CABANONS ET LES REMISES : les plus BAS du kit (0,74 à 0,92 case, mesuré
## dans `KitVille2.BATIMENTS`). Adossés au mur de soutènement côté amont, ils
## cassent la ligne de toits — une rue dont toutes les maisons ont la même
## hauteur est une rue de lotissement, pas un village.
const CABANONS := ["pavillons/building-type-h", "pavillons/building-type-i",
	"pavillons/building-type-m", "pavillons/building-type-g",
	"pavillons/building-type-p", "pavillons/building-type-q"]

## LES PIÈCES DU CLIENT POUR LE RELIEF (`modeles/pxl/`, à l'échelle du kit :
## posées avec `h = 0`). Mesurées au GLB le 14/09, et c'est ce qui décide de
## tout ce qui suit : le mur fait UN PALIER de haut et UNE CASE de long, donc
## il se pose bout à bout et s'empile sans le moindre calcul d'échelle.
const MUR := "pxl/mur-soutenement"                      ## 20 x 5 x 1 m
const ANGLE_SORTANT := "pxl/mur-soutenement-angle-out"   ## 1 x 5 x 1 m
const ANGLE_RENTRANT := "pxl/mur-soutenement-angle-in"   ## 1 x 5 x 1 m
const ESCALIER_DE_VILLE := "pxl/escalier-de-ville"       ## 4 x 5,9 x 20 m
const PYLONE := "pxl/pylone-telecom"                     ## 4,7 x 30 x 4,7 m

## Les pins tiennent la ligne de crête, les feuillus les terrasses basses —
## c'est la règle déjà retenue pour le relief (`claude/relief-et-assets.md`).
const PINS := ["nature/tree_pineTallA", "nature/tree_pineTallB", "nature/tree_pineTallC",
	"nature/tree_pineRoundC", "nature/tree_pineDefaultA"]
const FEUILLUS := ["nature/tree_default", "nature/tree_oak", "nature/tree_fat",
	"nature/tree_plateau", "nature/tree_small"]
const ROCHERS := ["nature/rock_largeA", "nature/rock_largeB", "nature/rock_largeC",
	"nature/rock_largeD", "nature/rock_tallA", "nature/rock_tallD", "nature/rock_smallE"]
const BUISSONS := ["nature/plant_bush", "nature/plant_bushDetailed", "nature/grass_large",
	"nature/plant_bushLarge", "nature/plant_bushTriangle", "nature/grass", "nature/grass_leafs",
	"nature/plant_flatTall", "nature/plant_flatShort"]
## LE SOUS-BOIS. Le kit nature ne se résume pas aux arbres : ce sont ces
## petites choses au sol — fleurs, champignons, souches, troncs tombés,
## pierres plates — qui font la différence entre une pelouse et une colline.
const SOUS_BOIS := ["nature/flower_redA", "nature/flower_redC", "nature/flower_yellowB",
	"nature/flower_yellowC", "nature/flower_purpleA", "nature/flower_purpleC",
	"nature/mushroom_red", "nature/mushroom_redGroup", "nature/mushroom_tanGroup",
	"nature/stump_round", "nature/stump_squareDetailed", "nature/log", "nature/log_large",
	"nature/stone_smallFlatA", "nature/stone_smallFlatC", "nature/rock_smallFlatB"]
## ⚠ EN MÈTRES, ET UNE UNITÉ FAIT UN MÈTRE (le joueur en fait 1,75, une
## voiture 4,75 de long). Ces hauteurs étaient toutes autour de 1,0 « parce
## que ça se voit mieux » : ça faisait des champignons d'un mètre et des
## fleurs à hauteur de genou (« toutes les fleurs, champignons etc. sont
## énormes comparé au personnage », client, 12/09). Une fleur des champs fait
## 45 cm, un champignon 25, une souche un demi-mètre, un tronc couché la
## largeur de son fût. Dans le même ordre que `SOUS_BOIS`.
const H_SOUS_BOIS := [0.45, 0.45, 0.45, 0.45, 0.45, 0.45, 0.22, 0.28, 0.28, 0.55, 0.60,
	0.50, 0.75, 0.25, 0.28, 0.32]

static func generer(graine := 3, taille := Vector2i(40, 40), curseurs := {}) -> Ville2:
	var v := Ville2.new(taille)
	v.nom = String(curseurs.get("nom", "temoin-colline"))
	v.graine = graine
	var alea := RandomNumberGenerator.new()
	alea.seed = graine
	Lotisseur.oublier_les_sacs()

	_terrain(v)
	_quartiers(v)
	var montee := _routes(v)
	_marches(v, montee)
	v.rasteriser()
	# ⚠ LES VIRAGES S'ARRONDISSENT AVANT LES MAISONS. Une courbe large mange
	# quatre cases ; si les lots sont déjà posés il n'en reste aucune de libre —
	# sur huit épingles de la colline, deux seulement s'arrondissaient. Arrondi
	# d'abord, le carré est marqué PRIS et le lotisseur le contourne tout seul.
	ANGLES.arrondir(v, alea)
	v.rasteriser()
	_lots(v, alea)
	v.rasteriser()
	# ⚠ RIEN À HABILLER SUR UN TERRAIN PLAT. Les murs tiennent le nez des
	# terrasses et les escaliers relient deux niveaux : sans relief, les uns
	# sont des panneaux plantés dans l'herbe et les autres des marches vers
	# nulle part. Ils reviennent avec `RELIEF`.
	#
	# ⚠ ET LES ESCALIERS PASSENT AVANT LES MURS, pas l'inverse : ils rendent
	# les cases où la maçonnerie doit S'OUVRIR pour les laisser passer. Posé
	# après coup, le mur murait son propre escalier — et rien dans l'image ne
	# l'aurait dit, sinon des marches contre un mur plein.
	if RELIEF > 0.0:
		_soutenements(v, _escaliers(v))
	_pylone(v)
	_sentiers(v, alea)
	_nature(v, alea)
	_details(v, alea)
	# ⚠ LES REPÈRES DU CLIENT. Ce sont ses propres modèles, faits pour ce
	# jeu : un quartier qui n'en porte aucun se lit comme du Kenney tout nu.
	_poser_repere(v, "piksl/eglise", Vector2i(18, 30), 0, "eglise", "Église du Coteau")
	_poser_repere(v, "piksl/supermarket", Vector2i(8, 33), 0, "supermarche", "Supérette des Terrasses")
	v.rasteriser()
	AFFICHES.semer(v, alea, 130.0, [], 3)
	# ⚠ AUCUNE TOITURE VERTE (client, 13/09). Voir `atlas.gd` : la bande
	# verte de l'atlas est repeinte par bâtiment, murs inchangés.
	#
	# LE VILLAGE EN TUILE, LES ANNEXES EN TUILE PASSÉE. `ATLAS.MIDI` n'est que
	# de la tuile romane en dix cuissons — c'est ce qui fait reconnaître un
	# village du Midi sur une photo aérienne, un seul matériau partout.
	# `ATLAS.VIEILLE` descend d'un ton : on la garde pour les cabanons et les
	# remises, dont personne ne refait le toit.
	TEINTES.couvrir_genres(v, alea, ["mas", "maison"], ATLAS.MIDI)
	TEINTES.couvrir(v, alea, "cabanon", ATLAS.VIEILLE)
	# Ce qui reste sans genre — les repères du client — suit le village.
	TEINTES.couvrir(v, alea, "", ATLAS.MIDI)
	# ⚠ `garder` À ZÉRO, ET C'EST VOULU ICI. Ailleurs on laisse une part des
	# maisons à la couleur du kit pour qu'un quartier ne soit pas un nuancier ;
	# un village de pierre n'a pas de maison blanche du tout, et une seule
	# suffirait à se voir.
	TEINTES.peindre(v, alea, "", TEINTES.PIERRE_DU_SUD, 0.00)
	PROPRETE.finir(v, alea)
	return v

# ------------------------------------------------------------------ le terrain

## Le terrain se pose en trois temps : tout au palier 0, les terrasses par
##-dessus, puis les flancs qui redescendent. Une case de terrasse est PLATE
## (elle porte exactement son palier) ; une case de flanc ne l'est pas, et le
## maillage lissé de `TerrainV2` s'en charge — c'est la différence entre une
## rue et une pelouse.
static func _terrain(v: Ville2) -> void:
	for j in v.taille.y:
		for i in v.taille.x:
			v.poser_terre(Vector2i(i, j), 0.0)
	for t in TERRASSES:
		for j in range(int(t["j0"]), int(t["j1"]) + 1):
			var b := bornes(t, j)
			for i in range(b.x, b.y + 1):
				v.poser_terre(Vector2i(i, j), palier_de(t) * PALIER)
				# ⚠ LA TERRASSE EST UN JARDIN, PAS UNE DALLE. Laissée en
				# `M_DALLE` (la matière par défaut), chaque terrasse sortait en
				# béton d'un bord à l'autre : une ville de parkings à flanc de
				# colline. La rue et les lots restent plats de toute façon —
				# `plate()` les compte — donc l'herbe ne mange que ce qui n'est
				# ni bâti ni roulant.
				v.poser_matiere(Vector2i(i, j), Ville2.M_HERBE)
	# Les flancs : à l'est et à l'ouest de chaque terrasse, le sol descend
	# jusqu'à rejoindre le niveau du bas. Il ne DESCEND JAMAIS sous ce qu'une
	# terrasse plus basse a déjà posé — sinon on creuse une douve autour de la
	# colline au lieu de l'appuyer sur son propre pied.
	for t in TERRASSES:
		for j in range(int(t["j0"]), int(t["j1"]) + 1):
			var b := bornes(t, j)
			for d in range(1, 10):
				# ⚠ LES DEUX FLANCS DESCENDENT PAREIL, ET EN PENTE LISSÉE.
				# L'essai du 12/09 faisait tomber le flanc OUEST en marches
				# d'une case entière, habillées de falaises du kit, pour
				# trancher entre « tout le terrain en blocs du kit nature » et
				# « maillage lissé, kit sur les cassures ». Le client a tranché
				# le jour même : « enlève tes dénivelés dans la montagne, sinon
				# les objets flottent ». C'est le nœud du problème — un arbre
				# posé au milieu d'une case qui tombe de vingt unités d'un bord
				# à l'autre ne peut être ni au ras du haut ni au ras du bas. La
				# pente lissée n'a pas ce défaut : le sol y varie CONTINÛMENT,
				# donc `TerrainV2.hauteur_en` place chaque objet pile dessus.
				_flanc(v, Vector2i(b.x - d, j), palier_du_flanc(palier_de(t), d))
				_flanc(v, Vector2i(b.y + d, j), palier_du_flanc(palier_de(t), d))
	# Le pied du coteau : au-delà de neuf cases, le flanc n'a pas fini de
	# descendre là où la terrasse est haute. On le prolonge jusqu'à zéro.
	for t in TERRASSES:
		for j in range(int(t["j0"]), int(t["j1"]) + 1):
			var b := bornes(t, j)
			for d in range(10, 22):
				_flanc(v, Vector2i(b.x - d, j), palier_du_flanc(palier_de(t), d))
				_flanc(v, Vector2i(b.y + d, j), palier_du_flanc(palier_de(t), d))
	# Le versant nord, derrière le sommet : la colline retombe vers le bord.
	var haut: Dictionary = TERRASSES[TERRASSES.size() - 1]
	for j in range(0, int(haut["j0"])):
		var reste := palier_du_flanc(palier_de(haut), int(haut["j0"]) - j)
		for i in range(int(haut["i0"]) - 3, int(haut["i1"]) + 4):
			_flanc(v, Vector2i(i, j), reste)
	# Le pied des terrasses basses, côté ville : une amorce d'herbe entre le
	# mur de soutènement et la première rue de la ville basse.
	for i in v.taille.x:
		_flanc(v, Vector2i(i, J_BASSE), 0.55)

## ⚠ LE NEZ D'UNE TERRASSE N'EST PAS UNE RÈGLE. Cinq rectangles emboîtés font
## un gâteau de mariage, pas une colline : chaque RANGÉE gagne donc quelques
## cases à l'est et à l'ouest, selon une dent de scie fixe. Elle n'ôte jamais
## rien — les lots se posent dans le rectangle de base et ne risquent pas de
## se retrouver au bord du vide.
static func bornes(t: Dictionary, j: int) -> Vector2i:
	return Vector2i(int(t["i0"]) - _dent(j, 3), int(t["i1"]) + _dent(j, 11))

static func _dent(j: int, sel: int) -> int:
	return int(absf(sin(float(j * 7 + sel * 13) * 0.9)) * 3.4)

## ⚠ LA MARCHE TOMBE SUR UN PALIER ENTIER. Le sol est en gradins : la hauteur
## d'une case se VOIT, en pleine face, sur la jupe verticale du gradin. Une
## case à 3,4 paliers ferait une marche de deux unités à côté d'une marche de
## cinq, et le coteau bégaierait. On arrondit donc au palier.
static func _flanc(v: Ville2, c: Vector2i, palier_voulu: float) -> void:
	if not v.dedans(c): return
	# ⚠ L'HERBE SE POSE MÊME QUAND L'ALTITUDE NE BOUGE PAS. Le flanc ne peut
	# que MONTER (sinon il creuse une douve autour de la colline), et sans
	# relief il ne monte jamais : la sortie anticipée emportait alors la pose
	# de la matière, et tout le coteau sortait en BÉTON — un immense parking
	# autour des lotissements. Le coteau est de l'herbe, avec ou sans pente.
	v.poser_matiere(c, Ville2.M_HERBE)
	var y := maxf(roundf(palier_voulu), 0.0) * PALIER
	if y <= v.sol(c): return
	v.poser_terre(c, y)

static func _quartiers(v: Ville2) -> void:
	v.quartiers = [
		{"nom": "Bas-Coteau", "genre": Ville2.Q_CENTRE, "gang": ""},
		{"nom": "Les Terrasses", "genre": Ville2.Q_PAVILLONS, "gang": ""},
	]
	v.peindre_quartier(Rect2i(0, J_BASSE, v.taille.x, v.taille.y - J_BASSE), 0)
	v.peindre_quartier(Rect2i(0, 0, v.taille.x, J_BASSE), 1)

# ------------------------------------------------------------------ les routes

## La ville basse est une grille ordinaire ; la colline n'a qu'UNE SEULE route,
## qui monte d'un bout à l'autre en lacets. C'est volontaire : une seconde
## montée rendrait la première inutile, et le cahier demande « de longs lacets »,
## pas un réseau.
static func _routes(v: Ville2) -> Array:
	# La ville basse : deux rues est-ouest, quatre nord-sud.
	for j in [28, 33, 38]:
		v.ajouter_route(Ville2.R_AVENUE if j == 28 else Ville2.R_RUE,
			[Vector2i(0, j), Vector2i(v.taille.x - 1, j)],
			"Avenue du Port" if j == 28 else "Rue %s" % PRENOMS[j % PRENOMS.size()])
	for i in [4, 13, 22, 31, 37]:
		v.ajouter_route(Ville2.R_RUE, [Vector2i(i, J_BASSE + 1), Vector2i(i, v.taille.y - 1)],
			"Rue %s" % PRENOMS[i % PRENOMS.size()])

	# LA MONTÉE. Un seul tracé, du bas de la colline au belvédère : on longe
	# une terrasse, on monte par son extrémité, on repart dans l'autre sens.
	var pied := int(TERRASSES[0]["i0"]) + 2
	var points: Array = [Vector2i(pied, J_BASSE + 2)]
	for k in TERRASSES.size():
		var t: Dictionary = TERRASSES[k]
		var y := int(t["route"])
		var entree: int = int(LACETS[k - 1]["x"]) if k > 0 else pied
		var sortie: int = int(LACETS[k]["x"]) if k < LACETS.size() \
			else (int(t["i0"]) + int(t["i1"])) / 2
		points.append(Vector2i(entree, y))
		points.append(Vector2i(sortie, y))
	v.ajouter_route(Ville2.R_RUE, points, "Route du Belvédère")
	return Ville2.cases_de_route(v.routes[v.routes.size() - 1])

## ⚠ LA ROUTE IMPOSE SON SOL, PAS L'INVERSE. Une fois le lacet tracé, chaque
## case qu'il traverse reçoit le palier qu'il lui faut : celui de sa terrasse
## quand elle est dessus, et sinon une MARCHE PAR CASE dans le talus. C'est ce
## qui fait que `CarteVille.tuile()` y reconnaît une rampe (`road-slant`) et
## non un décrochement : la table du kit ne sait monter que d'un palier, ou de
## deux avec `road-slant-high`, et jamais dans un carrefour.
static func _marches(v: Ville2, cases: Array) -> void:
	var vise: Array[int] = []
	for c in cases:
		vise.append(_palier_de_terrasse(c))
	# Les cases hors terrasse (les talus) prennent la marche qui les relie.
	for k in vise.size():
		if vise[k] >= 0: continue
		var avant := k - 1
		while avant >= 0 and vise[avant] < 0: avant -= 1
		var apres := k + 1
		while apres < vise.size() and vise[apres] < 0: apres += 1
		var a: int = vise[avant] if avant >= 0 else 0
		var b: int = vise[apres] if apres < vise.size() else a
		var total := maxi(1, apres - avant)
		vise[k] = a + roundi(float(b - a) * float(k - avant) / float(total))
	# Une marche par case au plus : sinon le kit n'a pas la pièce.
	for k in range(1, vise.size()):
		vise[k] = clampi(vise[k], vise[k - 1] - 1, vise[k - 1] + 1)
	for k in cases.size():
		var c: Vector2i = cases[k]
		v.poser_terre(c, float(vise[k]) * PALIER)
		# Le bord de la chaussée suit la chaussée : sans ça, un lacet posé en
		# travers du talus a une roue en l'air et l'autre dans l'herbe.
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var voisin: Vector2i = c + d
			if not v.dedans(voisin): continue
			if _palier_de_terrasse(voisin) >= 0: continue
			if v.carte != null and v.carte.route(voisin): continue
			var y := float(vise[k]) * PALIER
			if absf(v.sol(voisin) - y) < PALIER * 1.6:
				v.poser_terre(voisin, y)

## Le palier de la terrasse qui porte cette case, ou −1 si la case est dans un
## talus, un flanc ou la ville basse.
static func _palier_de_terrasse(c: Vector2i) -> int:
	if c.y >= J_BASSE: return 0
	for t in TERRASSES:
		var b := bornes(t, c.y)
		if c.y >= int(t["j0"]) and c.y <= int(t["j1"]) and c.x >= b.x and c.x <= b.y:
			return roundi(palier_de(t))
	return -1

# ------------------------------------------------------------------ les lots

## Sur une terrasse, les maisons bordent la route des deux côtés — au nord
## adossées au mur de la terrasse du dessus, au sud le nez dans le vide, avec
## la vue. Dans la ville basse, des pâtés ordinaires.
##
## ⚠ LE GABARIT SUIT LA PENTE, ET IL SUIT AUSSI LE CÔTÉ DE LA RUE. Côté aval
## on a la vue et la place : c'est là que se posent les mas. Côté amont on est
## adossé au mur de soutènement de la terrasse du dessus, donc à l'ombre et à
## l'étroit : cabanons et remises. C'est ce qui fait qu'une rue de village n'a
## pas deux fronts identiques, et ça ne coûte qu'un sac de plus.
static func _lots(v: Ville2, alea: RandomNumberGenerator) -> void:
	for k in TERRASSES.size():
		var t: Dictionary = TERRASSES[k]
		var haute := k >= 2
		var route := int(t["route"])
		var i0 := int(t["i0"]) + 1
		var large := int(t["i1"]) - int(t["i0"]) - 1
		# Côté aval (au sud de la route) : la rangée qui a la vue.
		Lotisseur.aligner(v, alea, MAS if haute else MAISONS, "n",
			Vector2i(i0 * 2, (route + 1) * 2), large * 2,
			"mas" if haute else "maison", 0.86, 1)
		# Côté amont : plus dense en bas, plus clairsemé en haut.
		Lotisseur.aligner(v, alea, MAISONS if haute else CABANONS, "s",
			Vector2i(i0 * 2 + 2, route * 2), large * 2 - 2,
			"maison" if haute else "cabanon", 0.7 if haute else 0.9, 1)
	# LA VILLE BASSE : quatre pâtés bordés. Un pâté sur deux tire dans le sac
	# des mas, l'autre dans celui des maisons — deux sacs voisins, et le bas du
	# village cesse d'être quatre fois le même front.
	var pair := true
	for x in [4, 13, 22, 31]:
		for y in [28, 33]:
			var r := Rect2i(x, y, 9, 5)
			Lotisseur.border(v, r, alea, MAS if pair else MAISONS, 0.9,
				"mas" if pair else "maison")
			pair = not pair

# ------------------------------------------------------------------ les détails

## LES ESCALIERS ENTRE TERRASSES : un piéton ne fait pas le lacet. Entre deux
## terrasses, à l'opposé du demi-tour de la route, on pose une volée de marches
## — c'est le raccourci, et c'est aussi ce qui prouve que le mur de
## soutènement est franchissable à pied (cahier § 4).
##
## ⚠ ET C'EST LE ROCHER QUI LES FAIT ICI, PAS `pxl/escalier-de-ville`. Mesurés
## au GLB le 14/09 : l'escalier de ville monte UN palier (5,9 m) sur une case
## de long, un nez de terrasse en fait QUATRE — vingt mètres. Quatre modules à
## la file demanderaient quatre-vingts mètres de recul, c'est-à-dire les quatre
## cinquièmes de la terrasse d'en dessous, sa route comprise. `cliff_steps_rock`
## mesure la case en hauteur comme en longueur : c'est la seule pièce du dépôt
## qui franchisse un nez de terrasse d'un seul tenant. L'escalier de ville sert
## là où il est juste — les marches d'UN palier, au pied du coteau, et c'est
## `_soutenements` qui les pose.
##
## Rend LES CASES OÙ LE MUR DOIT S'OUVRIR : celle que l'escalier occupe. Sans
## ça la maçonnerie mure son propre raccourci, et rien dans l'image ne le dit.
static func _escaliers(v: Ville2) -> Dictionary:
	var ouvertures: Dictionary = {}
	for k in range(TERRASSES.size() - 1):
		var haut: Dictionary = TERRASSES[k + 1]
		# À l'opposé du lacet : si la route monte à l'est, l'escalier est à
		# l'ouest.
		var a_l_est: bool = int(LACETS[k]["x"]) > 20
		var i: int = int(haut["i0"]) + 3 if a_l_est else int(haut["i1"]) - 3
		var j := int(haut["j1"])
		var y_haut := palier_de(haut) * PALIER
		# ⚠ À L'ÉCHELLE DU KIT, SANS ÉTIREMENT. `cliff_steps_rock` mesure
		# exactement une case de haut (20 unités) : c'est la hauteur d'une
		# terrasse. Posé tel quel, il tombe pile entre les deux niveaux — c'est
		# pour ça que les terrasses font quatre paliers et pas trois.
		v.ajouter_objet("nature/cliff_steps_rock", (float(i) + 0.5) * CASE,
			(float(j) + 1.0) * CASE - 2.0, 0.0)
		v.objets[v.objets.size() - 1]["y_abs"] = y_haut - CASE
		v.ajouter_objet("lampadaire_parc", (float(i) + 0.5) * CASE - 8.0,
			(float(j) + 0.2) * CASE, 0.0)
		v.objets[v.objets.size() - 1]["y_abs"] = y_haut
		ouvertures[Vector2i(i, j + 1)] = true
	return ouvertures

# ----------------------------------------------------------- les soutènements

## ⚠⚠ LES MURS DE SOUTÈNEMENT — LA PIÈCE QUI FAIT LE VILLAGE PERCHÉ (demande du
## client, 14/09).
##
## Un gradin nu, c'est une jupe de terre verticale : le maillage du terrain
## monte tout droit sur un palier et le sol s'y étire en un aplat. On habillait
## jusqu'ici le nez des terrasses de panneaux de falaise du kit nature, ce qui
## était juste tant qu'on parlait d'une colline sauvage et faux depuis qu'on
## parle d'un village — le cahier (§ 4) dit « murs de soutènement : BÉTON EN
## VILLE, rochers hors ville », et une terrasse bâtie, c'est de la ville.
##
## `pxl/mur-soutenement` mesure 20 x 5 x 1 m : une case de long, UN PALIER de
## haut. Il n'y a donc rien à mettre à l'échelle et rien à étirer — on le pose
## bout à bout le long de la limite, et on l'EMPILE quand la marche vaut
## plusieurs paliers (le nez d'une terrasse en vaut quatre).
##
## ⚠ ON NE MURE QUE CE QUI EST BÂTI OU FOULÉ, et c'est la règle du cahier, pas
## une économie de polygones. « Toute limite entre deux paliers » couvrirait
## aussi les flancs est et ouest, qui descendent par redans de quatre paliers
## sur une vingtaine de cases de large : la colline entière sortirait en
## maçonnerie et deviendrait une forteresse. La terre qu'un village retient est
## celle qu'il a lui-même taillée — une terrasse, une rue, un lot. Le reste est
## du talus : il reste en herbe et en rochers (voir `_nature`).

## Les quatre voisins, et la ROTATION qui met la face du mur (son −Z au repos)
## dans cette direction-là. Vérifiée au calcul, pas à l'œil : une rotation de
## `r` autour de Y envoie −Z sur (−sin r, −cos r).
const VOISINS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const VERS_LE_VIDE := [-PI * 0.5, PI, PI * 0.5, 0.0]
## L'épaisseur du module, en mètres : de combien le mur déborde du côté du vide.
const EPAISSEUR_MUR := 1.0
## ⚠ QUATRE MODULES AU PLUS — vingt mètres, le nez d'une terrasse. Au-delà on
## n'est plus devant un mur mais devant une falaise, et aucun village n'en
## maçonne une.
const MUR_MAX := 4
## LES ESCALIERS DE VILLE : un sur cinq marches d'un palier, quatre au plus.
## « Pas plus d'une poignée » — un escalier public tous les cent mètres raconte
## un village, un tous les vingt raconte un stade.
const ESCALIER_TOUS_LES := 5
const ESCALIERS_MAX := 4

## Pose la maçonnerie de tout le coteau. `ouvertures` : les cases que les
## escaliers de terrasse occupent déjà (voir `_escaliers`).
static func _soutenements(v: Ville2, ouvertures: Dictionary) -> void:
	# 1. LE RELEVÉ. Une limite par case haute et par direction. On ne pose rien
	# encore : un escalier prend la place d'un mur, et on ne sait pas lesquels
	# avant de les avoir tous comptés.
	var murs: Dictionary = {}
	var marches: Array = []
	for j in v.taille.y:
		for i in v.taille.x:
			var haut := Vector2i(i, j)
			if not _porte_un_mur(v, haut): continue
			for k in VOISINS.size():
				var d: Vector2i = VOISINS[k]
				var bas: Vector2i = haut + d
				if ouvertures.has(bas): continue
				var n := _hauteur_du_mur(v, haut, bas)
				if n <= 0: continue
				murs[Vector3i(i, j, k)] = n
				# Une marche d'UN palier au bout d'une rue : c'est là, et
				# nulle part ailleurs, qu'un escalier public a un sens — il
				# faut bien qu'il mène quelque part.
				if n == 1 and _touche_une_rue(v, bas):
					marches.append(Vector3i(i, j, k))
	# 2. LES ESCALIERS, prélevés sur les murs d'un palier.
	#
	# ⚠ ON LES ÉTALE SUR TOUTE LA LISTE, ON N'EN PREND PAS LES QUATRE PREMIERS.
	# Le relevé est fait ligne par ligne : à pas fixe, les quatre escaliers
	# sortaient tous du même bout du pied de coteau, à cent mètres les uns des
	# autres, et les deux tiers du village n'en avaient aucun. Le pas se calcule
	# donc sur la longueur du relevé, sans jamais descendre sous les cinq murs
	# qui séparent deux escaliers.
	var pas := maxi(ESCALIER_TOUS_LES, marches.size() / maxi(1, ESCALIERS_MAX))
	var poses := 0
	for m in range(0, marches.size(), pas):
		if poses >= ESCALIERS_MAX: break
		var cle: Vector3i = marches[m]
		murs.erase(cle)
		_poser_escalier(v, Vector2i(cle.x, cle.y), cle.z)
		poses += 1
	# 3. LA POSE, les angles en dernier — ils ont besoin du relevé complet
	# pour savoir de quel côté le mur tourne.
	for cle2 in murs:
		var c3: Vector3i = cle2
		_poser_mur(v, Vector2i(c3.x, c3.y), c3.z, int(murs[c3]))
	_angles(v, murs)

## Vrai si cette case retient quelque chose : une terrasse, une chaussée, une
## dalle, un lot. C'est la règle « béton en ville, rochers hors ville ».
static func _porte_un_mur(v: Ville2, c: Vector2i) -> bool:
	if not v.dedans(c) or not v.terre(c): return false
	return v.plate(c) or _palier_de_terrasse(c) >= 0

## De combien de modules la limite entre `haut` et `bas` a besoin, ou 0 s'il
## n'y a rien à retenir — ou si la case basse n'est pas libre. Un mur planté
## dans une chaussée ou au travers d'une maison est pire que pas de mur.
static func _hauteur_du_mur(v: Ville2, haut: Vector2i, bas: Vector2i) -> int:
	if not v.dedans(bas) or not v.terre(bas): return 0
	if v.carte != null and (v.carte.route(bas) or v.carte.case_prise(bas)): return 0
	if v.lot_sur(bas) >= 0: return 0
	var chute := v.sol(haut) - v.sol(bas)
	# ⚠ UN DEMI-PALIER DE MARGE. Les altitudes sont toutes des multiples du
	# palier, sauf le bord de chaussée que `_marches` recale : un test strict à
	# `>= PALIER` laissait des trous d'un mur tous les dix mètres le long des
	# lacets.
	if chute < PALIER * 0.9: return 0
	return clampi(roundi(chute / PALIER), 1, MUR_MAX)

## Vrai si la case touche une chaussée — la condition pour qu'un escalier
## public mène quelque part.
static func _touche_une_rue(v: Ville2, c: Vector2i) -> bool:
	if v.carte == null: return false
	for d in VOISINS:
		var dd: Vector2i = d
		if v.dedans(c + dd) and v.carte.route(c + dd): return true
	return false

## Le point, en mètres, au milieu de la limite entre une case et son voisin,
## décalé de `dehors` mètres DU CÔTÉ DU VIDE : le dos du mur reste dans la
## terre qu'il retient, sa face couvre la jupe du gradin.
static func _bord(c: Vector2i, d: Vector2i, dehors: float) -> Vector2:
	return Vector2(float(c.x) + 0.5, float(c.y) + 0.5) * CASE \
		+ Vector2(d) * (CASE * 0.5 + dehors)

## ⚠ LE MUR SE POSE PAR LE HAUT. Son sommet affleure la case haute, et chaque
## module descend d'un palier — c'est l'inverse d'une pile de caisses, et c'est
## ce qui garde l'arase droite quand la case basse, elle, ne l'est pas.
static func _poser_mur(v: Ville2, haut: Vector2i, k: int, n: int) -> void:
	var d: Vector2i = VOISINS[k]
	var p := _bord(haut, d, EPAISSEUR_MUR * 0.5)
	var sommet := v.sol(haut)
	for m in n:
		v.ajouter_objet(MUR, p.x, p.y, float(VERS_LE_VIDE[k]))
		v.objets[v.objets.size() - 1]["y_abs"] = sommet - float(m + 1) * PALIER

## L'escalier de ville : il occupe la case basse en entier — il est dessiné
## pour monter une case — et son pied regarde le vide, comme la face du mur
## qu'il remplace.
static func _poser_escalier(v: Ville2, haut: Vector2i, k: int) -> void:
	var d: Vector2i = VOISINS[k]
	var bas: Vector2i = haut + d
	v.ajouter_objet(ESCALIER_DE_VILLE, (float(bas.x) + 0.5) * CASE,
		(float(bas.y) + 0.5) * CASE, float(VERS_LE_VIDE[k]))
	v.objets[v.objets.size() - 1]["y_abs"] = v.sol(bas)

## ⚠ LES ANGLES, ET POURQUOI IL EN FAUT DEUX SORTES. Deux modules droits qui se
## rencontrent à l'équerre laissent une arête vive et une fente de la largeur
## du mur — c'est exactement ce qui se voit sur une capture, parce que l'œil
## suit les lignes d'ombre. Le kit du client a les deux pièces : le coin
## SORTANT là où le vide fait le tour d'un éperon (les deux murs appartiennent
## à la MÊME case haute), le coin RENTRANT là où le mur entre dans une encoche
## (les deux murs appartiennent à DEUX cases hautes, de part et d'autre du
## vide).
static func _angles(v: Ville2, murs: Dictionary) -> void:
	var coins: Dictionary = {}
	for cle in murs:
		var m: Vector3i = cle
		var c := Vector2i(m.x, m.y)
		var k: int = m.z
		var s := (k + 1) % 4
		var dk: Vector2i = VOISINS[k]
		var ds: Vector2i = VOISINS[s]
		var voisin := Vector3i(c.x, c.y, s)
		# Le mur d'en face, de l'autre côté de l'encoche : il regarde la même
		# case basse que celui-ci, mais par son autre face.
		var diag: Vector2i = c + dk + ds
		var autre := Vector3i(diag.x, diag.y, (k + 3) % 4)
		var sortant := murs.has(voisin)
		if not sortant and not murs.has(autre): continue
		# La pièce d'angle ne monte pas plus haut que le plus bas des deux
		# murs qu'elle raccorde : sinon elle dépasse dans le vide.
		var n := int(murs[m])
		if sortant: n = mini(n, int(murs[voisin]))
		else: n = mini(n, int(murs[autre]))
		# Le coin, en mètres : le sommet de la case du côté des deux murs.
		var coin := Vector2(float(c.x) + 0.5, float(c.y) + 0.5) * CASE \
			+ Vector2(dk + ds) * DEMI
		# ⚠ UN SEUL ANGLE PAR COIN. Les deux murs d'un coin sortant le
		# demandent chacun leur tour, et deux pièces au même point font une
		# arête noire (elles se battent en profondeur).
		var repere := Vector2i(roundi(coin.x), roundi(coin.y))
		if coins.has(repere): continue
		coins[repere] = true
		# La face de l'angle regarde la DIAGONALE : entre les deux murs pour un
		# coin sortant, vers l'encoche pour un coin rentrant — un huitième de
		# tour de part et d'autre de la face du premier mur.
		var biais: float = -PI * 0.25 if sortant else PI * 0.25
		var sommet := v.sol(c)
		for e in n:
			v.ajouter_objet(ANGLE_SORTANT if sortant else ANGLE_RENTRANT,
				coin.x, coin.y, float(VERS_LE_VIDE[k]) + biais)
			v.objets[v.objets.size() - 1]["y_abs"] = sommet - float(e + 1) * PALIER

## LE PYLÔNE TÉLÉCOM, ET UN SEUL (demande du client, 14/09). Un relais
## hertzien se plante SUR LE POINT HAUT — c'est toute sa raison d'être, et
## c'est ce qui donne à la colline sa silhouette de loin : trente mètres
## d'acier au-dessus d'un village qui en fait vingt. Deux pylônes, et il n'y a
## plus de point haut.
##
## Il cherche sa place en partant du NORD de la terrasse sommitale : le
## belvédère est au sud, et on ne plante pas un relais devant la vue.
static func _pylone(v: Ville2) -> bool:
	var haut: Dictionary = TERRASSES[TERRASSES.size() - 1]
	for j in range(int(haut["j0"]), int(haut["j1"]) + 1):
		var b := bornes(haut, j)
		for i in range(b.x, b.y + 1):
			var c := Vector2i(i, j)
			if not v.dedans(c) or not v.terre(c): continue
			if v.carte != null and (v.carte.route(c) or v.carte.case_prise(c)): continue
			if v.lot_sur(c) >= 0 or not v.demi_libre(i * 2, j * 2, 2, 2): continue
			v.ajouter_objet(PYLONE, (float(i) + 0.5) * CASE, (float(j) + 0.5) * CASE)
			# ⚠ ON RÉSERVE SES QUATRE DEMI-CASES. Un pylône est un OBJET, et un
			# objet ne dit rien au lotisseur : sans cette ligne, la première
			# passe de lots venue lui pose un mas dans les pieds. `demi_prises`
			# est le registre vivant des emprises (voir `Lotisseur.terrain_libre`).
			for db in 2:
				for da in 2:
					v.demi_prises[Vector2i(i * 2 + da, j * 2 + db)] = true
			return true
	push_warning("pylône télécom : pas une case libre sur la terrasse sommitale")
	return false

## LES SENTIERS. Le kit nature a des tuiles de chemin d'une case exactement
## (`ground_pathStraight`, `Bend`, `Corner`, mesurées 20 × 1 × 20) : de quoi
## tracer à travers l'herbe ce que la route en lacets ne dessert pas. Un sentier
## part de chaque escalier et rejoint la route de la terrasse du dessous — c'est
## le raccourci du piéton, et ça donne à l'herbe une raison d'être traversée.
static func _sentiers(v: Ville2, alea: RandomNumberGenerator) -> void:
	for k in range(TERRASSES.size() - 1):
		var bas: Dictionary = TERRASSES[k]
		var haut: Dictionary = TERRASSES[k + 1]
		var a_l_est: bool = int(LACETS[k]["x"]) > 20
		var i: int = int(haut["i0"]) + 3 if a_l_est else int(haut["i1"]) - 3
		# Du pied de l'escalier jusqu'à la rue de la terrasse du dessous.
		for j in range(int(haut["j1"]) + 1, int(bas["route"])):
			var c := Vector2i(i, j)
			if not v.dedans(c): continue
			if v.carte != null and (v.carte.route(c) or v.lot_sur(c) >= 0): continue
			var m := "nature/ground_pathStraight"
			if j == int(bas["route"]) - 1: m = "nature/ground_pathEnd"
			v.ajouter_objet(m, (float(i) + 0.5) * CASE, (float(j) + 0.5) * CASE, 0.0)
			# ⚠ APLATIE. Ces tuiles sont dessinées pour être ENFONCÉES (leur
			# boîte est sous le niveau zéro) ; reposées base à zéro par le
			# chargeur, elles ressortent d'un mètre et le sentier devient une
			# dalle posée sur l'herbe. Voir `chemins.gd`.
			v.objets[v.objets.size() - 1]["aplat"] = CHEMINS.APLAT
			# Deux ou trois pierres plates le long du sentier.
			if alea.randf() < 0.4:
				v.ajouter_objet("nature/stone_smallFlatB",
					(float(i) + alea.randf_range(-0.35, 1.35)) * CASE,
					(float(j) + alea.randf()) * CASE, alea.randf() * TAU, 0.30)

## LA VÉGÉTATION. Les pins tiennent la crête et les flancs raides, les feuillus
## bordent les routes des terrasses, les rochers sortent là où la pente est
## forte — c'est-à-dire là où le sol n'est PAS plat.
static func _nature(v: Ville2, alea: RandomNumberGenerator) -> void:
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			if v.plate(c) or not v.terre(c): continue
			var raide := _raideur(v, c)
			var h := v.sol(c)
			var x := (float(i) + alea.randf_range(0.15, 0.85)) * CASE
			var z := (float(j) + alea.randf_range(0.15, 0.85)) * CASE
			if raide > PALIER * 0.9:
				# Un talus raide : des rochers, et rien qui pousse droit.
				if alea.randf() < 0.55:
					v.ajouter_objet(ROCHERS[alea.randi() % ROCHERS.size()], x, z,
						alea.randf() * TAU, alea.randf_range(1.2, 3.2))
				elif alea.randf() < 0.4:
					v.ajouter_objet("nature/stone_smallFlatB", x, z,
						alea.randf() * TAU, alea.randf_range(0.25, 0.45))
				continue
			if h > PALIER * 10.0:
				if alea.randf() < 0.42:
					v.ajouter_objet(PINS[alea.randi() % PINS.size()], x, z,
						alea.randf() * TAU, alea.randf_range(9.0, 15.0))
			elif alea.randf() < 0.3:
				v.ajouter_objet(FEUILLUS[alea.randi() % FEUILLUS.size()], x, z,
					alea.randf() * TAU, alea.randf_range(6.0, 9.0))
			elif alea.randf() < 0.34:
				v.ajouter_objet(BUISSONS[alea.randi() % BUISSONS.size()], x, z,
					alea.randf() * TAU, alea.randf_range(0.70, 1.40))
			elif alea.randf() < 0.45:
				# LE SOUS-BOIS : deux ou trois petites choses par case, jamais
				# au même endroit. C'est ce qui se voit à pied.
				for _n in alea.randi_range(1, 3):
					var k := alea.randi() % SOUS_BOIS.size()
					v.ajouter_objet(SOUS_BOIS[k],
						(float(i) + alea.randf_range(0.1, 0.9)) * CASE,
						(float(j) + alea.randf_range(0.1, 0.9)) * CASE,
						alea.randf() * TAU, float(H_SOUS_BOIS[k]))

## De combien le sol tombe entre cette case et sa voisine la plus basse.
static func _raideur(v: Ville2, c: Vector2i) -> float:
	var bas := v.sol(c)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if v.dedans(c + d): bas = minf(bas, v.sol(c + d))
	return v.sol(c) - bas

## Le mobilier : lampadaires le long de la montée, bancs et garde-corps au
## belvédère, voitures garées sur les terrasses.
static func _details(v: Ville2, alea: RandomNumberGenerator) -> void:
	for k in TERRASSES.size():
		var t: Dictionary = TERRASSES[k]
		var route := int(t["route"])
		var y := palier_de(t) * PALIER
		for i in range(int(t["i0"]) + 2, int(t["i1"]) - 1, 4):
			v.ajouter_objet("lampadaire", (float(i) + 0.1) * CASE,
				(float(route) + 0.12) * CASE, PI)
		# Les voitures garées, le long du trottoir aval.
		for i in range(int(t["i0"]) + 3, int(t["i1"]) - 2, 5):
			if alea.randf() > 0.55: continue
			var m: String = KitVille2.VOITURES[alea.randi() % KitVille2.VOITURES.size()]
			v.ajouter_objet(m, (float(i) + alea.randf_range(0.2, 0.7)) * CASE,
				(float(route) + 0.82) * CASE, PI * 0.5)
		if k == TERRASSES.size() - 1:
			# LE BELVÉDÈRE : la raison d'être de la colline. Des bancs qui
			# regardent la ville basse, et un garde-corps devant le vide.
			var milieu := float(int(t["i0"]) + int(t["i1"])) * 0.5
			for n in 4:
				v.ajouter_objet("banc", (milieu - 1.5 + float(n)) * CASE,
					(float(t["j1"]) + 0.62) * CASE, PI)
			v.ajouter_objet("monument", milieu * CASE + 10.0,
				(float(t["j1"]) - 0.4) * CASE, 0.0)
			# ⚠ PAS UNE BARRIÈRE DE CHANTIER. `borne`, c'est le
			# `construction-barrier` du kit urbain — rouge et blanc, aligné sur
			# vingt-cinq cases au bord du belvédère d'un village de pierre. Le
			# garde-corps d'un point de vue est une murette basse, et le kit
			# nature en a une. Trois par case : la pièce fait six mètres une fois
			# à sa hauteur, pas vingt — espacée d'une case elle faisait des
			# pointillés.
			for i in range(int(t["i0"]) + 1, int(t["i1"]), 1):
				for n in 3:
					v.ajouter_objet("nature/fence_simpleLow",
						(float(i) + 0.17 + float(n) * 0.33) * CASE,
						(float(t["j1"]) + 0.95) * CASE, 0.0, 1.24)
			v.ajouter_lieu("belvedere", milieu * CASE, (float(t["j1"]) + 0.5) * CASE,
				{"nom": "Belvédère du Coteau", "y": y})

## Cherche une place pour un repère du client, en spirale autour du point voulu
## et dans les quatre orientations. Même règle partout : un repère qui abandonne
## au premier refus n'apparaît jamais, et rien ne le dit.
static func _poser_repere(v: Ville2, modele: String, depart: Vector2i, quarts: int,
		genre: String, nom: String, portee := 9) -> bool:
	for tour in [quarts, (quarts + 2) % 4, (quarts + 1) % 4, (quarts + 3) % 4]:
		var e := KitVille2.emprise_tournee(modele, tour)
		for rayon in range(0, portee):
			for dj in range(-rayon, rayon + 1):
				for di in range(-rayon, rayon + 1):
					if maxi(absi(di), absi(dj)) != rayon: continue
					var c := depart + Vector2i(di, dj)
					if c.x < 1 or c.y < 1: continue
					if not Lotisseur.terrain_libre(v, c.x * 2, c.y * 2, e): continue
					v.ajouter_lot(modele, c.x * 2, c.y * 2, e.x, e.y, tour, genre)
					v.ajouter_lieu(genre, (float(c.x) + float(e.x) * 0.25) * CASE,
						(float(c.y) + float(e.y) * 0.25) * CASE, {"nom": nom})
					return true
	push_warning("repère « %s » : pas de place" % nom)
	return false
