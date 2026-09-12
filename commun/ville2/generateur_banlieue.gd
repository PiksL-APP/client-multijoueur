class_name GenerateurBanlieue
extends RefCounted
## LE QUATRIÈME QUARTIER TÉMOIN : LA BANLIEUE PAVILLONNAIRE (cahier § 3).
##
## Les trois premiers témoins ont éprouvé la ville dense (le centre), la côte
## (la plage) et le relief (la colline). Celui-ci éprouve LE CONTRAIRE DE LA
## GRILLE — c'est le seul quartier du cahier dont le tracé n'est pas régulier :
##
## * « tracé : grille au centre, ORGANIQUE ailleurs » (§ 5) → une boucle qui
##   serpente et des impasses qui s'en détachent, jamais deux rues parallèles ;
## * « impasses partout où c'est utile, mais jamais sans raison » (§ 5) → une
##   impasse dessert un chapelet de pavillons et finit sur une raquette de
##   retournement, comme dans une vraie banlieue ;
## * « maisons avec jardin, clôture, allée et voiture devant » (§ 3) → chaque
##   pavillon a sa parcelle clôturée, son allée goudronnée et souvent sa
##   voiture ;
## * « piscines, barbecues, trampolines » (§ 3) → dans les jardins arrière,
##   c'est-à-dire du côté opposé à la rue ;
## * « école, église, terrain de sport » et « petits commerces (épicerie,
##   station-service) » (§ 3) → un pôle de quartier sur la route d'entrée.
##
## ⚠ CE QUI FAIT UNE BANLIEUE, C'EST LA PARCELLE, PAS LA MAISON. Une rangée de
## pavillons collés les uns aux autres est un lotissement de promoteur vu de
## haut, pas une banlieue : ce qu'on reconnaît, c'est le rythme maison / jardin
## / clôture / maison. On pose donc la PARCELLE d'abord (une largeur tirée au
## sort), la maison dedans, et le reste est du jardin.
##
## L'ordre du cahier (§ 10) est respecté : terrain → axes → quartiers → rues →
## lots → détails.

## Les courbes larges (cahier § 5) : brique commune, appelée par `preload` — un
## `class_name` neuf n'existe pas dans l'export web.
const ANGLES := preload("res://commun/ville2/angles.gd")

const CASE := Ville2.CASE
const DEMI := Ville2.DEMI

## La route d'entrée du quartier, d'ouest en est : c'est par là qu'on arrive
## du centre, et c'est elle qui porte les commerces.
const J_ENTREE := 31

## LA BOUCLE. Une banlieue américaine se dessine autour d'une `loop road` : une
## seule rue qui part de l'entrée, fait le tour du quartier et y revient. Les
## impasses s'y greffent. Les points sont les sommets du tracé — les segments
## sont droits (le modèle refuse la diagonale), et `ANGLES.arrondir` passe
## derrière pour adoucir les coudes.
const BOUCLE := [
	Vector2i(7, 31), Vector2i(7, 24), Vector2i(4, 24), Vector2i(4, 13),
	Vector2i(11, 13), Vector2i(11, 6), Vector2i(24, 6), Vector2i(24, 11),
	Vector2i(31, 11), Vector2i(31, 19), Vector2i(35, 19), Vector2i(35, 27),
	Vector2i(28, 27), Vector2i(28, 31),
]

## LES IMPASSES : le point de greffe sur la boucle, le sens où elles partent et
## leur longueur en cases. Une impasse trop longue n'est plus une impasse, c'est
## une rue qu'on a oublié de finir.
const IMPASSES := [
	{"de": Vector2i(4, 20), "vers": Vector2i(1, 0), "long": 6},
	{"de": Vector2i(4, 16), "vers": Vector2i(1, 0), "long": 5},
	{"de": Vector2i(15, 13), "vers": Vector2i(0, -1), "long": 5},
	{"de": Vector2i(20, 13), "vers": Vector2i(0, 1), "long": 7},
	{"de": Vector2i(24, 9), "vers": Vector2i(1, 0), "long": 6},
	{"de": Vector2i(31, 15), "vers": Vector2i(-1, 0), "long": 6},
	{"de": Vector2i(35, 23), "vers": Vector2i(-1, 0), "long": 7},
	{"de": Vector2i(28, 29), "vers": Vector2i(-1, 0), "long": 8},
	{"de": Vector2i(11, 9), "vers": Vector2i(-1, 0), "long": 5},
]

## LE PARC DU QUARTIER (cahier § 3 : « banlieue pavillonnaire + parcs »), au
## creux de la boucle, et LE TERRAIN DE SPORT à côté de l'école.
const PARC := Rect2i(14, 16, 9, 8)
const ECOLE := Rect2i(13, 27, 8, 3)

const PRENOMS := ["des Tilleuls", "des Acacias", "du Verger", "des Pinsons",
	"de la Clairière", "des Écoliers", "du Moulin", "des Peupliers", "des Cerisiers",
	"du Petit Bois", "des Alouettes", "de la Fontaine"]
const IMPASSES_NOMS := ["Impasse des Roses", "Impasse du Lavoir", "Impasse des Mésanges",
	"Impasse du Puits", "Impasse des Lilas", "Impasse de la Grange", "Impasse du Clos",
	"Impasse des Vignes", "Impasse du Sentier"]

## ⚠ LES PAVILLONS, ET RIEN QUE LES PAVILLONS. Le kit `pavillons` a vingt et un
## modèles de maison ; le kit `batiments` en a de plus hauts, qui n'ont rien à
## faire ici. Mesurés, les pavillons vont de 0,92 à 1,83 case de large : c'est
## exactement la variété qu'on veut le long d'une rue.
const MAISONS := ["pavillons/building-type-a", "pavillons/building-type-c",
	"pavillons/building-type-e", "pavillons/building-type-g", "pavillons/building-type-h",
	"pavillons/building-type-i", "pavillons/building-type-j", "pavillons/building-type-k",
	"pavillons/building-type-l", "pavillons/building-type-m", "pavillons/building-type-o",
	"pavillons/building-type-p", "pavillons/building-type-q", "pavillons/building-type-r",
	"pavillons/building-type-s", "pavillons/building-type-u"]
## Les grandes maisons, réservées aux parcelles larges du fond des impasses.
const GRANDES := ["pavillons/building-type-b", "pavillons/building-type-d",
	"pavillons/building-type-f", "pavillons/building-type-n", "pavillons/building-type-t"]
## Le pôle de quartier, sur la route d'entrée.
const COMMERCES := ["batiments/building-c", "batiments/building-e", "batiments/building-k",
	"batiments/building-d", "batiments/building-g"]

## LES CLÔTURES, ET ELLES SONT DROITES.
##
## ⚠ `fence-1x2`, `-1x3`, `-1x4` DU KIT PAVILLONS SONT DES PANNEAUX PLIÉS.
## Mesurés : 0,875 × 0,27 × 0,438 — quatre dixièmes d'épaisseur là où un
## panneau droit en fait sept centièmes. Ce sont des ANGLES, dessinés pour
## tourner le coin d'une parcelle, et alignés bout à bout ils donnaient une
## clôture en zigzag (« utilise d'autres barrières, il y en a sans le pli,
## toutes droites », client, 12/09). Le kit nature a les bonnes : `fence_simple`
## et `fence_planks` font une case de long sur sept centièmes d'épaisseur.
##
## Et il a mieux : `fence_corner`, une pièce d'angle d'une case sur une case.
## On aligne donc des panneaux droits sur les côtés et on POSE UN ANGLE À
## CHAQUE COIN — c'est comme ça qu'on monte une clôture, et c'est ce que le
## client a dessiné.
##
## Les hauteurs restent imposées : à l'échelle du kit un panneau ferait sept
## unités de haut. Une clôture de jardin fait 1,10 m.
const H_CLOTURE := 1.10
const CLOTURES := ["nature/fence_simple", "nature/fence_planks", "nature/fence_simpleLow"]
const ANGLE_CLOTURE := "nature/fence_corner"
## Ce qu'on met dans un jardin de derrière.
const JARDIN := ["nature/plant_bushDetailed", "nature/plant_bushLarge", "nature/tree_default",
	"nature/tree_oak", "nature/tree_fat", "nature/grass_large", "nature/flower_redA",
	"nature/flower_yellowB", "nature/flower_purpleA", "nature/pot_large",
	"nature/stump_round", "nature/log_stack"]
const H_JARDIN = [0.90, 1.30, 7.60, 6.40, 6.00, 0.70, 0.45, 0.45, 0.45, 0.80, 0.50, 1.00]
## ⚠ L'AXE NATIF DU CHEMIN D'UNE TUILE `ground_path*` : le sens dans lequel
## court son chemin quand elle est posée SANS rotation. Tout le raccord des
## sentiers tient à cette seule constante — se tromper d'un quart de tour, et
## chaque tuile présente son chemin en travers de la précédente.
const AXE_DU_SENTIER := PI * 0.5

## Les arbres d'alignement de la banlieue : plus petits qu'en ville.
const ALIGNEMENT := ["nature/tree_small", "nature/tree_oak", "nature/tree_default",
	"nature/tree_plateau", "nature/tree_cone_dark"]

static func generer(graine := 4, taille := Vector2i(40, 40), curseurs := {}) -> Ville2:
	var v := Ville2.new(taille)
	v.nom = String(curseurs.get("nom", "temoin-banlieue"))
	v.graine = graine
	var alea := RandomNumberGenerator.new()
	alea.seed = graine

	_terrain(v)
	_quartiers(v)
	_rues(v)
	v.rasteriser()
	# Les coudes de la boucle s'arrondissent AVANT les maisons : une courbe
	# large mange quatre cases, et si les lots sont posés il n'en reste aucune.
	ANGLES.arrondir(v, alea, 0.85)
	v.rasteriser()
	_parcelles(v, alea)
	v.rasteriser()
	_le_pole(v, alea)
	v.rasteriser()
	_le_parc(v, alea)
	_les_jardins(v, alea)
	_details(v, alea)
	return v

# ------------------------------------------------------------------ 1. le terrain

## ⚠ PLAT, ET EN HERBE. Une banlieue est bâtie sur du plat (cahier § 4 : « pas
## de pente sous les quartiers bâtis »), et son sol est de l'herbe, pas du
## béton : c'est même ce qui la distingue du centre d'un seul coup d'œil. Les
## trottoirs viennent des tuiles de route ; tout le reste est pelouse.
static func _terrain(v: Ville2) -> void:
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			v.poser_terre(c, 0.0)
			v.poser_matiere(c, Ville2.M_HERBE)

static func _quartiers(v: Ville2) -> void:
	v.quartiers.append({"nom": "Les Jardins", "genre": Ville2.Q_PAVILLONS, "gang": -1})
	v.quartiers.append({"nom": "Parc des Tilleuls", "genre": Ville2.Q_PARC, "gang": -1})
	v.peindre_quartier(Rect2i(Vector2i.ZERO, v.taille), 0)
	v.peindre_quartier(PARC, 1)

# ------------------------------------------------------------------ 2. les rues

static func _rues(v: Ville2) -> void:
	# La route d'entrée : la seule qui traverse, et la seule en avenue.
	v.ajouter_route(Ville2.R_AVENUE,
		[Vector2i(0, J_ENTREE), Vector2i(v.taille.x - 1, J_ENTREE)],
		"Route de la Ville")
	# LA BOUCLE, en un seul tracé : c'est ce qui lui donne un nom unique sur la
	# carte et ce qui garantit qu'elle se referme.
	var points: Array = BOUCLE.duplicate()
	v.ajouter_route(Ville2.R_RUE, points, "Rue du Grand Tour")
	# Les impasses.
	for k in IMPASSES.size():
		var im: Dictionary = IMPASSES[k]
		var de: Vector2i = im["de"]
		var vers: Vector2i = im["vers"]
		var bout: Vector2i = de + vers * int(im["long"])
		v.ajouter_route(Ville2.R_RUE, [de, bout], IMPASSES_NOMS[k % IMPASSES_NOMS.size()])

# ------------------------------------------------------------------ 3. les parcelles

## De combien la maison recule par rapport au bord de la chaussée, en
## demi-cases : le devant de jardin.
const RECUL := 1
## La largeur d'une parcelle, en demi-cases — tirée dans cette fourchette.
const PARCELLE_MINI := 4
const PARCELLE_MAXI := 8

## ⚠ ON POSE LA PARCELLE, PUIS LA MAISON DEDANS. `Lotisseur.aligner` colle les
## façades les unes aux autres : parfait pour une rue commerçante, faux pour
## une banlieue, où le vide entre deux maisons compte autant que les maisons.
## On découpe donc le bord de rue en parcelles de largeur variable, on centre
## la maison dans la sienne, et ce qui reste devient jardin et clôture.
static func _parcelles(v: Ville2, alea: RandomNumberGenerator) -> void:
	for r in v.routes.duplicate():
		if String(r["nom"]) == "Route de la Ville": continue
		var cases := Ville2.cases_de_route(r)
		if cases.size() < 3: continue
		# Les deux bords de la rue, chacun avec le sens où regarde la façade.
		for cote in [1, -1]:
			_border_la_rue(v, cases, cote, alea)

static func _border_la_rue(v: Ville2, cases: Array, cote: int,
		alea: RandomNumberGenerator) -> void:
	var k := 1
	while k < cases.size() - 1:
		var a: Vector2i = cases[k - 1]
		var b: Vector2i = cases[k]
		var d: Vector2i = b - a
		# Un coude : on saute. Une parcelle à cheval sur un virage n'a pas de
		# façade sur rue, et le lotisseur la refuserait de toute façon.
		if d == Vector2i.ZERO or (cases[mini(k + 1, cases.size() - 1)] - b) != d:
			k += 1
			continue
		# La normale à la rue, du côté demandé.
		var n := Vector2i(-d.y, d.x) * cote
		var large := alea.randi_range(PARCELLE_MINI, PARCELLE_MAXI)
		var choix: Array = GRANDES if large >= PARCELLE_MAXI else MAISONS
		var m: String = choix[alea.randi() % choix.size()]
		var q := _face_vers(-n)
		var e := KitVille2.emprise_tournee(m, q)
		# ⚠ LE COIN SE CALCULE DEPUIS LE BORD DE LA CASE DE RUE, PAS DEPUIS SON
		# MILIEU. Tout est en demi-cases : la case de rue (i, j) occupe les
		# demi-cases 2i et 2i+1. Une maison à l'EST commence donc en 2(i+1),
		# plus le recul ; une maison à l'OUEST FINIT en 2i moins le recul, donc
		# son coin est encore `e.x` plus loin. Mélanger les deux donnait des
		# maisons plantées dans la chaussée, que `terrain_libre` refusait — d'où
		# une banlieue à moitié vide au premier jet.
		var cx := b.x * 2
		var cy := b.y * 2
		if n.x > 0: cx = (b.x + 1) * 2 + RECUL
		elif n.x < 0: cx = b.x * 2 - RECUL - e.x
		if n.y > 0: cy = (b.y + 1) * 2 + RECUL
		elif n.y < 0: cy = b.y * 2 - RECUL - e.y
		if Lotisseur.terrain_libre(v, cx, cy, e) and alea.randf() < 0.93:
			var k_lot := v.ajouter_lot(m, cx, cy, e.x, e.y, q, "pavillon")
			# ⚠ LA PARCELLE ET SON OUVERTURE SE NOTENT SUR LE LOT. La clôture
			# est posée plus tard (`_les_jardins`), et il lui faut deux choses
			# que seul ce moment-ci connaît : DE QUEL CÔTÉ EST LA RUE, et OÙ
			# L'ALLÉE la traverse. Sans le premier elle ferme la parcelle du
			# mauvais côté ; sans le second elle barre l'entrée du garage.
			v.lots[k_lot]["rue"] = [n.x, n.y]
			v.lots[k_lot]["allee"] = _devant_de_maison(v, Vector2i(cx, cy), e, n, alea)
			# On avance de la parcelle : l'emprise de la maison, plus le jardin
			# latéral. C'est ce vide-là qui fait la banlieue.
			var emprise := e.x if d.x != 0 else e.y
			k += maxi(2, (maxi(large, emprise) + 1) / 2)
		else:
			k += 2

## Le quart de tour qui met la façade (le −Z du modèle) dans ce sens.
static func _face_vers(sens: Vector2i) -> int:
	if sens == Vector2i(0, -1): return 0
	if sens == Vector2i(1, 0): return 3
	if sens == Vector2i(0, 1): return 2
	return 1

## L'ALLÉE ET LA VOITURE DEVANT (cahier § 3). L'allée part du trottoir et
## rejoint la maison ; la voiture est dessus, une fois sur deux.
## Rend le décalage de l'allée le long de la façade, en unités : c'est là que
## la clôture devra s'ouvrir.
static func _devant_de_maison(v: Ville2, coin: Vector2i, e: Vector2i, n: Vector2i,
		alea: RandomNumberGenerator) -> float:
	var cx := (float(coin.x) + float(e.x) * 0.5) * DEMI
	var cz := (float(coin.y) + float(e.y) * 0.5) * DEMI
	# Le milieu de la façade, décalé d'un quart de largeur : une allée au
	# milieu de la façade passe par la porte d'entrée.
	var travers := Vector2(float(-n.y), float(n.x))
	var biais := (alea.randf_range(0.22, 0.34)) * float(e.x if n.y != 0 else e.y) * DEMI
	var ax := cx - float(n.x) * float(e.x) * 0.5 * DEMI + travers.x * biais
	var az := cz - float(n.y) * float(e.y) * 0.5 * DEMI + travers.y * biais
	var vers_rue := atan2(float(n.x), float(n.y))
	# Deux dalles d'allée : le kit en a une longue et une courte, à l'échelle
	# du kit (elles pavent le sol, comme les tuiles de sentier).
	for t in 2:
		v.ajouter_objet("pavillons/driveway-long",
			ax + float(n.x) * float(t) * DEMI * 0.8,
			az + float(n.y) * float(t) * DEMI * 0.8, vers_rue)
	if alea.randf() < 0.55:
		var m: String = KitVille2.VOITURES[alea.randi() % KitVille2.VOITURES.size()]
		v.ajouter_objet(m, ax + float(n.x) * DEMI * 0.4, az + float(n.y) * DEMI * 0.4,
			vers_rue + PI * 0.5)
	# La boîte aux lettres et un arbre d'alignement au bord du trottoir.
	if alea.randf() < 0.5:
		v.ajouter_objet("borne", ax + float(n.x) * DEMI * 1.5 - travers.x * 6.0,
			az + float(n.y) * DEMI * 1.5 - travers.y * 6.0, 0.0)
	if alea.randf() < 0.45:
		var arbre: String = ALIGNEMENT[alea.randi() % ALIGNEMENT.size()]
		v.ajouter_objet(arbre, ax + float(n.x) * DEMI * 1.6 + travers.x * 9.0,
			az + float(n.y) * DEMI * 1.6 + travers.y * 9.0,
			alea.randf() * TAU, alea.randf_range(4.5, 7.0))
	return biais

# ------------------------------------------------------------------ 4. le pôle

## L'ÉCOLE, LE TERRAIN DE SPORT ET LES COMMERCES (cahier § 3), sur la route
## d'entrée : c'est le seul endroit du quartier où l'on ne vient pas que pour
## rentrer chez soi.
static func _le_pole(v: Ville2, alea: RandomNumberGenerator) -> void:
	# Les commerces bordent la route d'entrée, au sud.
	Lotisseur.aligner(v, alea, COMMERCES, "n",
		Vector2i(4 * 2, (J_ENTREE + 1) * 2), 18 * 2, "commerce", 0.8, 1)
	# L'école : un bâtiment large, face à la route.
	var m := "batiments/building-n"
	if not ResourceLoader.exists(KitVille2.chemin(m)): m = "batiments/building-l"
	var e := KitVille2.emprise_tournee(m, 2)
	if Lotisseur.terrain_libre(v, ECOLE.position.x * 2, ECOLE.position.y * 2, e):
		v.ajouter_lot(m, ECOLE.position.x * 2, ECOLE.position.y * 2, e.x, e.y, 2, "ecole")
		v.ajouter_lieu("ecole", (float(ECOLE.position.x) + 2.0) * CASE,
			(float(ECOLE.position.y) + 1.5) * CASE, {"nom": "École des Tilleuls"})
	# LE TERRAIN DE SPORT : une dalle et une clôture autour. Le kit n'a pas de
	# terrain tout fait — c'est le grillage qui le dessine.
	var t := Rect2i(ECOLE.position.x + 6, ECOLE.position.y - 4, 6, 4)
	for j in range(t.position.y, t.end.y):
		for i in range(t.position.x, t.end.x):
			v.poser_matiere(Vector2i(i, j), Ville2.M_TERRE)
	_clore(v, t, alea, 1.9, "urbain/construction-fence")
	v.ajouter_lieu("sport", (float(t.position.x) + 3.0) * CASE,
		(float(t.position.y) + 2.0) * CASE, {"nom": "Stade du Quartier"})

# ------------------------------------------------------------------ 5. le parc

## LE PARC DU QUARTIER : des allées de dalles, des massifs, des bancs, et
## surtout des ARBRES EN NOMBRE — un parc est d'abord une masse d'arbres.
static func _le_parc(v: Ville2, alea: RandomNumberGenerator) -> void:
	var r := PARC
	# ⚠ LES TUILES DE SENTIER SE RACCORDENT — C'ÉTAIT MA ROTATION QUI ÉTAIT
	# FAUSSE. Premier jet : le chemin de chaque tuile sortait EN TRAVERS de
	# l'allée, d'où un damier de bandes qui ne se suivaient pas (« tu vois bien
	# qu'aucune flèche ne se suit », client, 12/09, capture annotée). Le tort
	# n'était pas au kit : `ground_pathStraight` porte son chemin selon un axe
	# précis, et je l'avais posé de travers dans les deux branches.
	#
	# ⚠⚠ ET MON BANC D'ESSAI M'A MENTI. J'avais aligné trois tuiles sur la
	# planche d'échelle pour trancher — mais elle espace les modèles de trois
	# unités, et une tuile de sol en fait vingt : elles se chevauchaient, et le
	# résultat illisible m'a fait conclure qu'elles n'étaient pas modulaires.
	# UNE TUILE DE SOL NE SE TESTE QU'AU PAS DE LA CASE. Le client, lui, les
	# raccorde à la main sans difficulté : « si elles le sont, j'y arrive ».
	#
	# La croix : `ground_pathStraight` sur les branches, `ground_pathCross` au
	# croisement, `ground_pathEnd` aux quatre bouts.
	var jm := r.position.y + r.size.y / 2
	var im := r.position.x + r.size.x / 2
	for i in range(r.position.x, r.end.x):
		var m := "nature/ground_pathStraight"
		if i == im: m = "nature/ground_pathCross"
		elif i == r.position.x or i == r.end.x - 1: m = "nature/ground_pathEnd"
		var tour := AXE_DU_SENTIER + (PI if i == r.end.x - 1 else 0.0)
		v.ajouter_objet(m, (float(i) + 0.5) * CASE, (float(jm) + 0.5) * CASE, tour)
	for j in range(r.position.y, r.end.y):
		if j == jm: continue
		var m := "nature/ground_pathStraight"
		if j == r.position.y or j == r.end.y - 1: m = "nature/ground_pathEnd"
		var tour := AXE_DU_SENTIER + PI * 0.5 + (PI if j == r.position.y else 0.0)
		v.ajouter_objet(m, (float(im) + 0.5) * CASE, (float(j) + 0.5) * CASE, tour)
	var clairiere := Rect2i(r.position + Vector2i(1, 1), Vector2i(2, 2))
	# Les bancs, en bordure de la clairière, tournés vers elle.
	for k in 8:
		var a := TAU * float(k) / 8.0
		var x := (float(clairiere.position.x) + float(clairiere.size.x) * 0.5) * CASE \
			+ cos(a) * 2.2 * CASE
		var z := (float(clairiere.position.y) + float(clairiere.size.y) * 0.5) * CASE \
			+ sin(a) * 2.0 * CASE
		v.ajouter_objet("banc", x, z, -a + PI * 0.5)
	# Les arbres et les massifs, partout sauf dans la clairière.
	for j in range(r.position.y, r.end.y):
		for i in range(r.position.x, r.end.x):
			if i == im or j == jm: continue
			if clairiere.has_point(Vector2i(i, j)): continue
			if alea.randf() < 0.78:
				var m: String = ALIGNEMENT[alea.randi() % ALIGNEMENT.size()]
				v.ajouter_objet(m, (float(i) + alea.randf()) * CASE,
					(float(j) + alea.randf()) * CASE, alea.randf() * TAU,
					alea.randf_range(5.0, 8.5))
			if alea.randf() < 0.35:
				var f := ["nature/flower_redA", "nature/flower_yellowB",
					"nature/flower_purpleC", "nature/plant_bushDetailed"]
				v.ajouter_objet(f[alea.randi() % f.size()],
					(float(i) + alea.randf()) * CASE, (float(j) + alea.randf()) * CASE,
					alea.randf() * TAU, alea.randf_range(0.45, 0.90))
	# LE BASSIN (cahier § 7 : « grands parcs dessinés — allées, plans d'eau »),
	# dans le quart nord-est, avec ses nénuphars.
	var bx := (float(r.position.x) + float(r.size.x) * 0.78) * CASE
	var bz := (float(r.position.y) + float(r.size.y) * 0.25) * CASE
	v.ajouter_objet("pelouse", bx, bz, 0.0, 0.0, "#4fb3d9")
	v.objets[v.objets.size() - 1]["w"] = 2.2 * CASE
	v.objets[v.objets.size() - 1]["d"] = 1.6 * CASE
	for _k in 6:
		v.ajouter_objet("nenuphar", bx + alea.randf_range(-1.0, 1.0) * CASE,
			bz + alea.randf_range(-0.7, 0.7) * CASE, alea.randf() * TAU)
	v.ajouter_lieu("parc", (float(r.position.x) + float(r.size.x) * 0.5) * CASE,
		(float(r.position.y) + float(r.size.y) * 0.5) * CASE,
		{"nom": "Parc des Tilleuls"})

# ------------------------------------------------------------------ 6. les jardins

## LE JARDIN DE DERRIÈRE (cahier § 3 : « piscines, barbecues, trampolines »).
## On relit les lots posés et on meuble la bande qui se trouve DERRIÈRE la
## maison, c'est-à-dire du côté opposé à sa façade.
static func _les_jardins(v: Ville2, alea: RandomNumberGenerator) -> void:
	for l in v.lots:
		if String(l.get("genre", "")) != "pavillon": continue
		var rue: Array = l.get("rue", [0, 1])
		var n := Vector2(float(rue[0]), float(rue[1]))       # vers la rue
		var fond := -n
		var travers := Vector2(-n.y, n.x)
		var c := v.centre_du_lot(l)
		# LA PARCELLE : la maison, plus une marge de jardin tout autour. C'est
		# ce rectangle que la clôture suit.
		var large := float(l["w"]) * DEMI
		var profond := float(l["h"]) * DEMI
		var demi_lat := (large if absf(n.y) > 0.5 else profond) * 0.5 + MARGE_COTE
		var vers_rue := (profond if absf(n.y) > 0.5 else large) * 0.5 + MARGE_RUE
		var vers_fond := (profond if absf(n.y) > 0.5 else large) * 0.5 + MARGE_FOND
		var centre := Vector2(c.x, c.z)
		var allee := float(l.get("allee", 0.0))
		_clore_la_parcelle(v, centre, n, travers, demi_lat, vers_rue, vers_fond, allee, alea)
		_meubler_le_jardin(v, centre, fond, travers, demi_lat, vers_fond, alea)

## Les marges de la parcelle autour de la maison, en unités.
const MARGE_COTE := 4.0
const MARGE_RUE := 5.0
const MARGE_FOND := 9.0
## La largeur de l'ouverture laissée devant l'allée.
const PASSAGE := 9.0

## ⚠ LA CLÔTURE FAIT LE TOUR DE LA PARCELLE, PAS UN BOUT DE FOND DE JARDIN.
## Premier jet : trois panneaux au fond du jardin — ça donnait des morceaux de
## barrière posés dans l'herbe, sans rien clore. Le client a envoyé le dessin :
## un RECTANGLE autour de la propriété, ouvert là où l'allée traverse. C'est
## ce que fait cette fonction — les quatre côtés, panneaux bout à bout, et une
## brèche sur le côté rue.
static func _clore_la_parcelle(v: Ville2, centre: Vector2, n: Vector2, travers: Vector2,
		demi_lat: float, vers_rue: float, vers_fond: float, allee: float,
		alea: RandomNumberGenerator) -> void:
	var m: String = CLOTURES[alea.randi() % CLOTURES.size()]
	var pan := _longueur_de_cloture(m)
	# Les quatre coins de la parcelle, dans le repère (travers, n).
	var a := centre + travers * -demi_lat + n * vers_rue      # rue, gauche
	var b := centre + travers * demi_lat + n * vers_rue       # rue, droite
	var c2 := centre + travers * demi_lat - n * vers_fond     # fond, droite
	var d2 := centre + travers * -demi_lat - n * vers_fond    # fond, gauche
	# ⚠ LES ANGLES D'ABORD, LES CÔTÉS ENSUITE. Une pièce d'angle occupe une
	# case pleine : si on aligne les panneaux jusqu'au coin, ils la traversent.
	# On retire donc un demi-angle à chaque bout de côté.
	var angle_long := _longueur_de_cloture(ANGLE_CLOTURE)
	for coin in [[a, 0], [b, 1], [c2, 2], [d2, 3]]:
		var p: Vector2 = coin[0]
		v.ajouter_objet(ANGLE_CLOTURE, p.x, p.y,
			atan2(n.x, n.y) + PI * 0.5 * float(int(coin[1])), H_CLOTURE)
	# Le côté rue s'ouvre devant l'allée ; les trois autres sont pleins.
	var marge := angle_long * 0.5
	_un_cote(v, a, b, m, pan, allee, PASSAGE, marge)
	_un_cote(v, b, c2, m, pan, 0.0, 0.0, marge)
	_un_cote(v, c2, d2, m, pan, 0.0, 0.0, marge)
	_un_cote(v, d2, a, m, pan, 0.0, 0.0, marge)

## Un côté de clôture, de `a` à `b`, en panneaux bout à bout. `ouvre` est le
## décalage du centre de la brèche depuis le MILIEU du côté, `passage` sa
## largeur (0 : pas de brèche).
static func _un_cote(v: Ville2, a: Vector2, b: Vector2, modele: String, pan: float,
		ouvre: float, passage: float, marge := 0.0) -> void:
	var brut := a.distance_to(b)
	if brut < 0.5 or pan < 0.1: return
	var sens := (b - a) / brut
	# On s'arrête avant les pièces d'angle, à chaque bout.
	a += sens * marge
	var longueur := brut - marge * 2.0
	if longueur < pan * 0.5: return
	# On ajuste le pas pour tomber juste : mieux vaut des panneaux un chouïa
	# plus courts qu'un trou au coin.
	var combien := maxi(1, int(round(longueur / pan)))
	var pas := longueur / float(combien)
	var angle := atan2(sens.x, sens.y) + PI * 0.5
	for k in combien:
		var t := (float(k) + 0.5) * pas
		# La brèche se compte depuis le milieu du côté.
		if passage > 0.0 and absf(t - (longueur * 0.5 + ouvre)) < passage * 0.5: continue
		var p := a + sens * t
		v.ajouter_objet(modele, p.x, p.y, angle, H_CLOTURE)

## Ce qu'il y a DANS la parcelle, derrière la maison : la piscine et le jardin.
static func _meubler_le_jardin(v: Ville2, centre: Vector2, fond: Vector2, travers: Vector2,
		demi_lat: float, vers_fond: float, alea: RandomNumberGenerator) -> void:
	# LA PISCINE, une fois sur cinq. Le kit n'a pas de piscine : c'est la même
	# brique de sol plat que les pelouses de la place du centre, teintée.
	if alea.randf() < 0.20:
		var p := centre + fond * (vers_fond * 0.6)
		v.ajouter_objet("pelouse", p.x, p.y, 0.0, 0.0, "#4fb3d9")
		v.objets[v.objets.size() - 1]["w"] = 11.0
		v.objets[v.objets.size() - 1]["d"] = 7.0
	for _k in alea.randi_range(3, 6):
		var n := alea.randi() % JARDIN.size()
		var q := centre + fond * (vers_fond * alea.randf_range(0.35, 0.9)) \
			+ travers * alea.randf_range(-0.8, 0.8) * demi_lat
		v.ajouter_objet(JARDIN[n], q.x, q.y, alea.randf() * TAU, float(H_JARDIN[n]))

## La longueur au sol d'un panneau de clôture posé à `H_CLOTURE`. Un modèle mis
## à une hauteur voulue est mis à l'échelle DANS LES TROIS AXES : sa longueur
## suit sa hauteur, et c'est elle qu'il faut connaître pour les aligner.
static func _longueur_de_cloture(modele: String) -> float:
	var t := KitVille2.taille(modele) * CASE
	if t.y < 0.01: return DEMI
	return maxf(t.x, t.z) * (H_CLOTURE / t.y)

# ------------------------------------------------------------------ 7. les détails

static func _details(v: Ville2, alea: RandomNumberGenerator) -> void:
	# Les lampadaires le long de la boucle, un carrefour sur deux.
	for r in v.routes:
		var cases := Ville2.cases_de_route(r)
		var pas := 6 if String(r["genre"]) == Ville2.R_AVENUE else 8
		for k in range(2, cases.size(), pas):
			var c: Vector2i = cases[k]
			v.ajouter_objet("lampadaire_parc", (float(c.x) + 0.12) * CASE,
				(float(c.y) + 0.12) * CASE, 0.0)
	# LA RAQUETTE DE RETOURNEMENT au bout de chaque impasse : quelques bornes
	# en arc. Sans elle, une impasse se lit comme une rue coupée.
	for im in IMPASSES:
		var de: Vector2i = im["de"]
		var vers: Vector2i = im["vers"]
		var bout: Vector2i = de + vers * int(im["long"])
		for k in 5:
			var a := PI * (0.25 + 0.5 * float(k) / 4.0) + atan2(float(vers.x), float(vers.y))
			v.ajouter_objet("borne", (float(bout.x) + 0.5) * CASE + cos(a) * 13.0,
				(float(bout.y) + 0.5) * CASE + sin(a) * 13.0, 0.0)
	# Un ou deux terrains vagues : une banlieue qui s'étend a toujours une
	# parcelle pas encore bâtie.
	for coin in [Vector2i(8, 27)]:
		for j in range(coin.y, coin.y + 3):
			for i in range(coin.x, coin.x + 3):
				var c := Vector2i(i, j)
				if not v.dedans(c) or v.lot_sur(c) >= 0: continue
				if v.carte != null and v.carte.route(c): continue
				v.poser_matiere(c, Ville2.M_TERRE)
				if alea.randf() < 0.4:
					v.ajouter_objet("nature/grass_large", (float(i) + alea.randf()) * CASE,
						(float(j) + alea.randf()) * CASE, alea.randf() * TAU, 0.70)
		_clore(v, Rect2i(coin, Vector2i(3, 3)), alea, 1.9, "urbain/construction-fence")

## Un grillage autour d'un rectangle de cases : un panneau par case de bord.
static func _clore(v: Ville2, r: Rect2i, alea: RandomNumberGenerator, hauteur: float,
		modele: String) -> void:
	for i in range(r.position.x, r.end.x):
		for j in [r.position.y, r.end.y - 1]:
			if alea.randf() < 0.12: continue          # une brèche de temps en temps
			v.ajouter_objet(modele, (float(i) + 0.5) * CASE,
				(float(j) + (0.02 if j == r.position.y else 0.98)) * CASE, 0.0, hauteur)
	for j in range(r.position.y, r.end.y):
		for i in [r.position.x, r.end.x - 1]:
			if alea.randf() < 0.12: continue
			v.ajouter_objet(modele, (float(i) + (0.02 if i == r.position.x else 0.98)) * CASE,
				(float(j) + 0.5) * CASE, PI * 0.5, hauteur)
