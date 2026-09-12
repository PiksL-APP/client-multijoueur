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
## ils descendent en herbe et en rochers, et c'est là qu'on voit que la
## colline est une colline et non un escalier.

const CASE := Ville2.CASE
const DEMI := Ville2.DEMI
const PALIER := Ville2.PALIER

## LES TERRASSES, du bas vers le haut : la bande de cases (j0..j1 compris), le
## palier, la largeur (i0..i1 compris) et la ligne de la route. Chaque terrasse
## est plus étroite que celle d'en dessous : c'est ce qui donne une silhouette
## de colline plutôt qu'un gâteau de mariage.
const TERRASSES := [
	{"j0": 21, "j1": 25, "i0": 4, "i1": 36, "p": 3, "route": 23},
	{"j0": 16, "j1": 20, "i0": 6, "i1": 34, "p": 6, "route": 18},
	{"j0": 11, "j1": 15, "i0": 8, "i1": 32, "p": 9, "route": 13},
	{"j0": 6, "j1": 10, "i0": 11, "i1": 29, "p": 12, "route": 8},
	{"j0": 2, "j1": 5, "i0": 14, "i1": 26, "p": 15, "route": 4},
]

## LA VILLE BASSE : tout ce qui est au sud de la première terrasse.
const J_BASSE := 26
## ⚠ TROIS PALIERS D'UNE TERRASSE À L'AUTRE, pas deux. À deux (dix unités,
## cinq mètres), le coteau passait entièrement derrière les maisons : vue du
## ciel comme depuis la ville basse, la colline ressemblait à une plaine. À
## trois, le mur de soutènement se voit, la vue se gagne, et le sommet est à
## soixante-quinze unités — trente-sept mètres, la « colline de 30-50 m avec
## vue sur la baie » du cahier (§ 4).
const PENTE_FLANC := 0.85              ## la descente du flanc, en palier par case

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

## Les familles : des villas et des pavillons sur les terrasses hautes, des
## immeubles de rapport en bas — une ville où l'on monte est une ville où
## l'habitat s'allège à mesure qu'on gagne la vue.
const VILLAS := ["pavillons/building-type-b", "pavillons/building-type-d",
	"pavillons/building-type-f", "pavillons/building-type-g", "pavillons/building-type-n",
	"pavillons/building-type-t", "pavillons/building-type-u", "pavillons/building-type-a"]
const RAPPORT := ["batiments/building-c", "batiments/building-e", "batiments/building-f",
	"batiments/building-a", "batiments/building-b", "batiments/building-h",
	"batiments/building-i"]
const COMMERCES := ["batiments/building-d", "batiments/building-g", "batiments/building-k"]

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
## Les hauteurs voulues, dans le même ordre que `SOUS_BOIS` : une fleur fait
## une unité, un tronc couché deux, une souche une et demie.
const H_SOUS_BOIS := [0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 1.0, 1.1, 1.1, 1.4, 1.5, 1.3, 1.8,
	0.7, 0.8, 0.9]

static func generer(graine := 3, taille := Vector2i(40, 40), curseurs := {}) -> Ville2:
	var v := Ville2.new(taille)
	v.nom = String(curseurs.get("nom", "temoin-colline"))
	v.graine = graine
	var alea := RandomNumberGenerator.new()
	alea.seed = graine

	_terrain(v)
	_quartiers(v)
	var montee := _routes(v)
	_marches(v, montee)
	v.rasteriser()
	_lots(v, alea)
	v.rasteriser()
	_escaliers(v)
	_nature(v, alea)
	_details(v, alea)
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
				v.poser_terre(Vector2i(i, j), float(t["p"]) * PALIER)
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
				_flanc(v, Vector2i(b.x - d, j), float(t["p"]) - float(d) * PENTE_FLANC)
				_flanc(v, Vector2i(b.y + d, j), float(t["p"]) - float(d) * PENTE_FLANC)
	# Le versant nord, derrière le sommet : la colline retombe vers le bord.
	var haut: Dictionary = TERRASSES[TERRASSES.size() - 1]
	for j in range(0, int(haut["j0"])):
		var reste := float(haut["p"]) - float(int(haut["j0"]) - j) * 2.3
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

static func _flanc(v: Ville2, c: Vector2i, palier_voulu: float) -> void:
	if not v.dedans(c): return
	var y := maxf(palier_voulu, 0.0) * PALIER
	if y <= v.sol(c): return
	v.poser_terre(c, y)
	v.poser_matiere(c, Ville2.M_HERBE)

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
		v.poser_matiere(c, Ville2.M_DALLE)
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
			return int(t["p"])
	return -1

# ------------------------------------------------------------------ les lots

## Sur une terrasse, les maisons bordent la route des deux côtés — au nord
## adossées au mur de la terrasse du dessus, au sud le nez dans le vide, avec
## la vue. Dans la ville basse, des pâtés ordinaires.
static func _lots(v: Ville2, alea: RandomNumberGenerator) -> void:
	for k in TERRASSES.size():
		var t: Dictionary = TERRASSES[k]
		var haute := k >= 2
		var choix: Array = VILLAS if haute else RAPPORT
		var route := int(t["route"])
		var i0 := int(t["i0"]) + 1
		var large := int(t["i1"]) - int(t["i0"]) - 1
		# Côté aval (au sud de la route) : la rangée qui a la vue.
		Lotisseur.aligner(v, alea, choix, "n", Vector2i(i0 * 2, (route + 1) * 2),
			large * 2, "villa" if haute else "rapport", 0.86, 1)
		# Côté amont : plus dense en bas, plus clairsemé en haut.
		Lotisseur.aligner(v, alea, VILLAS if haute else COMMERCES, "s",
			Vector2i(i0 * 2 + 2, route * 2), large * 2 - 2,
			"villa" if haute else "commerce", 0.7 if haute else 0.9, 1)
	# La ville basse : quatre pâtés bordés.
	for x in [4, 13, 22, 31]:
		for y in [28, 33]:
			var r := Rect2i(x, y, 9, 5)
			Lotisseur.border(v, r, alea, RAPPORT, 0.9, "rapport")

# ------------------------------------------------------------------ les détails

## LES ESCALIERS : un piéton ne fait pas le lacet. Entre deux terrasses, à
## l'opposé du demi-tour de la route, on pose une volée de marches du kit —
## c'est le raccourci, et c'est aussi ce qui prouve que le mur de soutènement
## est franchissable à pied (cahier § 4).
static func _escaliers(v: Ville2) -> void:
	for k in range(TERRASSES.size() - 1):
		var bas: Dictionary = TERRASSES[k]
		var haut: Dictionary = TERRASSES[k + 1]
		# À l'opposé du lacet : si la route monte à l'est, l'escalier est à
		# l'ouest.
		var a_l_est: bool = int(LACETS[k]["x"]) > 20
		var i: int = int(haut["i0"]) + 3 if a_l_est else int(haut["i1"]) - 3
		var j := int(haut["j1"])
		var y_bas := float(bas["p"]) * PALIER
		var y_haut := float(haut["p"]) * PALIER
		# ⚠ UNE SEULE PIÈCE, MISE À LA HAUTEUR DU MUR. `cliff_steps_stone` est
		# un bloc d'une case de haut : posé tel quel sur un mur de deux paliers
		# il dépasserait de moitié. Mis à l'échelle par sa hauteur, il devient
		# une volée étroite qui tient exactement entre les deux terrasses.
		var haute := y_haut - y_bas
		v.ajouter_objet("nature/cliff_steps_stone", (float(i) + 0.5) * CASE,
			(float(j) + 1.0) * CASE, 0.0, haute, "#b4b2ab")
		v.objets[v.objets.size() - 1]["y_abs"] = y_bas
		v.ajouter_objet("lampadaire_parc", (float(i) + 0.5) * CASE - 8.0,
			(float(j) + 0.2) * CASE, 0.0)
		v.objets[v.objets.size() - 1]["y_abs"] = y_haut

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
						alea.randf() * TAU, alea.randf_range(3.0, 7.5))
				elif alea.randf() < 0.4:
					v.ajouter_objet("nature/stone_smallFlatB", x, z,
						alea.randf() * TAU, alea.randf_range(0.6, 1.2))
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
					alea.randf() * TAU, alea.randf_range(1.2, 2.4))
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
		var y := float(t["p"]) * PALIER
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
			for i in range(int(t["i0"]) + 1, int(t["i1"]), 1):
				v.ajouter_objet("borne", (float(i) + 0.5) * CASE,
					(float(t["j1"]) + 0.95) * CASE, 0.0)
			v.ajouter_lieu("belvedere", milieu * CASE, (float(t["j1"]) + 0.5) * CASE,
				{"nom": "Belvédère du Coteau", "y": y})
