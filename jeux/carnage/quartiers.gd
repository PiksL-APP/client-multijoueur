class_name Quartiers
extends RefCounted
## LA VILLE DESSINÉE À LA MAIN, comme les intérieurs de repaire.
##
## Trois maquettes générées ont été refusées : le procédural sait remplir, il
## ne sait pas avoir du goût. On reprend donc ici EXACTEMENT le geste des
## intérieurs (`jeux/carnage/interieurs.gd`) : le plan est un DESSIN, un
## caractère par case, qu'on relit d'un coup d'œil et où déplacer une rue est
## un caractère dans le diff. Une photo suffit à vérifier
## (`outils/carte.sh <quartier>`).
##
## UNE CASE = VINGT UNITÉS = deux tuiles de jeu = une tuile du City Kit: Roads
## à l'échelle UNIFORME. Rien n'est jamais étiré : c'est ce qui bavait sur les
## marquages et les trottoirs des premières maquettes.
##
## LA VILLE EST FAITE DE QUARTIERS QUI N'ONT PAS LA MÊME TRAME. Chacun a son
## origine et son ANGLE ; entre deux quartiers il y a de l'eau, une falaise ou
## un parc — jamais un raccord de tuiles. C'est la seule chose qui casse
## vraiment le damier : une grille reste une grille, si irrégulière soit-elle.
##
## ─────────────────────────── LE DESSIN ───────────────────────────
##
##   .   l'eau (rien du tout)
##   ,   pelouse, terrain nu
##   ;   sable — le bord de mer
##   o   esplanade pavée, place, parvis
##   P   parking
##   #   rue — les tuiles se raccordent TOUTES SEULES (droite, virage, T,
##       carrefour, impasse) et grimpent en rampe là où le relief monte
##   =   pont
##   O   rond-point : posé sur son CENTRE, il mange 3 x 3 cases
##   ^   bosquet d'arbres        '   buissons et hautes herbes
##   ~   plan d'eau du port : pas de terre, mais un bateau amarré. LA LONGUEUR
##       DE LA FILE DE `~` CHOISIT LE BATEAU — cinq cases d'affilée valent un
##       cargo, deux un remorqueur, une un canot. On dessine un mouillage, pas
##       un bateau à la fois.
##   X   dépôt : conteneurs, cuves, palettes — le sol d'un port
##   %   chantier : barrières, cônes, palissade
##   P   parking : le sol est pavé et il y a des voitures dessus
##
##   T tour   B bureau   C commerce   M maison   V vieille ville   H hangar
##   Un BLOC de lettres identiques est UN SEUL bâtiment qui remplit exactement
##   ce rectangle : c'est ce qui donne des fronts de rue continus au lieu
##   d'immeubles semés sur une pelouse. Pour en mettre deux côte à côte sans
##   qu'ils fusionnent, alterner MAJUSCULE et minuscule : `TTtt` fait deux
##   immeubles, `TTTT` un seul.
##
## ─────────────────────────── LE RELIEF ───────────────────────────
##
## Une deuxième grille, même taille, un CHIFFRE par case : le palier, cinq
## unités par cran (c'est exactement ce dont `road-slant` grimpe en une case —
## d'où le choix du cran). Espace ou absence = palier zéro.

const CASE := CarteVille.CASE
const PALIER := CarteVille.PALIER
const ROUTES := CarteVille.CHEMIN_ROUTES

const CHAUSSEE := "#=O"
const PAVE := "oP"
const FAMILLES := {
	"T": PlanVille.F_TOUR, "B": PlanVille.F_BUREAUX, "C": PlanVille.F_COMMERCE,
	"M": PlanVille.F_MAISON, "V": PlanVille.F_VIEUX, "H": PlanVille.F_HANGAR,
}

const TEINTE_ROUTE := Color("#8e929c")
const TEINTE_PAVE := Color("#b9b6ac")
const TEINTE_SABLE := Color("#d9c9a2")


# ------------------------------------------------------------ LE CATALOGUE

## LES QUARTIERS. Chacun a son origine (en cases, dans le monde), son ANGLE,
## son dessin et son relief. C'est CE BLOC qu'on reprend à la main : déplacer
## une rue, c'est déplacer des `#` ; poser un immeuble, c'est écrire des
## lettres ; creuser un port, c'est écrire des points.
##
## ⚠ Les deux grilles d'un quartier doivent faire la MÊME taille, sinon le
## relief est lu à zéro là où il manque — ce qui se voit comme une falaise
## sans raison.
## LA VILLE. ⚠ UN SEUL QUARTIER, UNE SEULE TRAME, AUCUN ANGLE.
##
## La version précédente en portait six, chacun avec son angle : c'était le
## parti « moins carré » — deux quartiers voisins qui ne sont pas d'accord sur
## la direction du nord cassent le damier mieux que n'importe quelle rue
## courbe. Le client l'a tranché autrement : tout doit être droit et sur le
## même plan. Les six quartiers inclinés sont dans l'historique du dépôt
## (commit f3081cd) — ils ne sont pas perdus, ils ne sont plus la ville.
##
## Ce qui remplace l'angle pour casser le damier : le RYTHME D'ÎLOTS. Le centre
## est tramé en 6 × 4, le résidentiel en 8 × 6, l'industrie en 12 × 8, et les
## chenaux passent en biais à travers les trois. Vu d'avion, les trois secteurs
## ne se ressemblent pas — et c'était tout ce qu'on demandait aux angles.
##
## Le dessin lui-même est dans `PlanPikstown` : 215 lignes de 225 caractères ne
## tiennent pas au milieu d'un fichier de code qu'on relit.
const CATALOGUE := {
	"pikstown": {
		"nom": "Pikstown", "origine": Vector2(0.0, 0.0), "angle": 0.0, "graine": 2609,
		"herbe": Color("#7f9464"), "roche": Color("#8b8578"),
		"hauteurs": {"T": [46.0, 88.0], "B": [24.0, 42.0], "C": [15.0, 24.0],
			"M": [10.0, 15.0], "V": [12.0, 18.0], "H": [14.0, 20.0]},
		# ⚠ `source` DIT OÙ LE DESSIN VIT VRAIMENT. Sans elle, l'éditeur
		# ressortait un bloc `"plan": [...]` à recoller dans ce fichier-ci — or
		# le dessin n'y est plus depuis qu'il fait 96 000 caractères. Un export
		# qu'on ne peut recoller nulle part, c'est un éditeur qui ne sert à rien.
		"source": "PlanPikstown",
		"plan": PlanPikstown.PLAN,
		"relief": PlanPikstown.RELIEF,
	},
}

# ------------------------------------------------------------ lecture du dessin

static func _lettre(c: String) -> String:
	return c.to_upper() if FAMILLES.has(c.to_upper()) else ""

static func _car(dessin: Array, i: int, j: int) -> String:
	if j < 0 or j >= dessin.size(): return "."
	var ligne: String = dessin[j]
	if i < 0 or i >= ligne.length(): return "."
	return ligne[i]

static func _niveau(relief: Array, i: int, j: int) -> int:
	if j < 0 or j >= relief.size(): return 0
	var ligne: String = relief[j]
	if i < 0 or i >= ligne.length(): return 0
	var c := ligne[i]
	return int(c) if c >= "0" and c <= "9" else 0

## Le dessin devient une carte : terre, paliers, chaussée. Le pavage des rues
## et les rampes se déduisent ensuite tout seuls (`CarteVille.tuile`).
static func carte_de(fiche: Dictionary) -> CarteVille:
	var dessin: Array = fiche["plan"]
	var relief: Array = fiche.get("relief", [])
	var carte := CarteVille.new()
	var large := 0
	for l in dessin:
		large = maxi(large, String(l).length())
	for j in dessin.size():
		for i in large:
			var c := _car(dessin, i, j)
			if c == "." or c == "~":
				continue
			carte.poser_sol(Vector2i(i, j), _niveau(relief, i, j))
			if c in CHAUSSEE:
				carte.poser_route(Vector2i(i, j), true)
	# Les ronds-points APRÈS : ils ont besoin que leurs neuf cases existent.
	for j in dessin.size():
		for i in large:
			if _car(dessin, i, j) == "O":
				if not carte.poser_piece("road-roundabout", Vector2i(i - 1, j - 1), 3, 0):
					push_warning("rond-point refusé en (%d,%d) : il lui faut 3x3 cases de terre au même palier" % [i, j])
	return carte

# ------------------------------------------------------------ les bâtiments

## Les rectangles de lettres. On balaye ; à la première case non vue, on étire
## vers l'est tant que c'est la même lettre, puis vers le sud tant que la
## rangée entière l'est aussi. Le dessinateur trace des rectangles : inutile
## d'aller chercher des formes en L qu'il ne dessinera jamais.
static func batiments(dessin: Array) -> Array:
	var vus: Dictionary = {}
	var sortie: Array = []
	var large := 0
	for l in dessin:
		large = maxi(large, String(l).length())
	for j in dessin.size():
		for i in large:
			var cle := Vector2i(i, j)
			if vus.has(cle): continue
			var c := _car(dessin, i, j)
			if _lettre(c) == "": continue
			var w := 1
			while _car(dessin, i + w, j) == c and not vus.has(Vector2i(i + w, j)):
				w += 1
			var h := 1
			while true:
				var entier := true
				for k in w:
					if _car(dessin, i + k, j + h) != c or vus.has(Vector2i(i + k, j + h)):
						entier = false
						break
				if not entier: break
				h += 1
			for a in w:
				for b in h:
					vus[Vector2i(i + a, j + b)] = true
			sortie.append({"lettre": _lettre(c), "i": i, "j": j, "w": w, "h": h})
	return sortie

# ------------------------------------------------------------ vérification

## LES FAUTES D'UN PLAN, en un seul endroit — le banc (`outils/verifier.gd`) et
## l'éditeur s'en servent tous les deux. Écrites deux fois, elles auraient
## divergé au premier ajout, et l'éditeur aurait laissé passer ce que le banc
## refuse.
## Trois fautes, qui ne se voient QUE sur la photo et trop tard :
##  1. une marche de relief au pied d'un carrefour, d'un virage ou d'un T : le
##     kit n'a pas de croisement en pente, la rue fait un ressaut ;
##  2. une marche de plus de deux paliers : la rampe la plus raide du kit
##     (`road-slant-high`) en monte deux, pas trois ;
##  3. un bâtiment à cheval sur deux paliers : il se pose sur le plus haut et
##     flotte au-dessus du plus bas.
## Plus un compte : un rond-point qui n'a pas trouvé ses 3 x 3 cases disparaît
## sans bruit.
static func fautes(fiche: Dictionary) -> Array:
	var dessin: Array = fiche["plan"]
	var carte := carte_de(fiche)
	var liste: Array = []
	for c in carte.cases.keys():
		if not carte.route(c) or carte.case_prise(c): continue
		var m := carte.masque(c)
		for k in 4:
			var v: Vector2i = c + CarteVille.COTES[k]
			if not carte.route(v): continue
			var ecart: int = carte.palier(v) - carte.palier(c)
			if ecart <= 0: continue
			var selon_axe := ((m & 5) == 0 and (k == 1 or k == 3)) \
				or ((m & 10) == 0 and (k == 0 or k == 2))
			if not selon_axe:
				liste.append({"i": c.x, "j": c.y,
					"texte": "marche de %d au pied d'un croisement" % ecart})
			elif ecart > 2:
				liste.append({"i": c.x, "j": c.y,
					"texte": "marche de %d : le kit monte de deux paliers au plus" % ecart})
	for b in batiments(dessin):
		var niv := -99
		var faute := false
		for a in int(b["w"]):
			for d in int(b["h"]):
				var cc := Vector2i(int(b["i"]) + a, int(b["j"]) + d)
				if not carte.terre(cc): continue
				if niv == -99: niv = carte.palier(cc)
				elif niv != carte.palier(cc): faute = true
		if faute:
			liste.append({"i": int(b["i"]), "j": int(b["j"]),
				"texte": "bâtiment %s à cheval sur deux paliers" % b["lettre"]})
	var demandes := 0
	for l in dessin:
		demandes += String(l).count("O")
	if demandes != carte.pieces.size():
		liste.append({"i": -1, "j": -1, "texte": "%d rond(s)-point(s) demandé(s), %d posé(s) : il leur faut 3x3 cases de terre au même palier" % [demandes, carte.pieces.size()]})
	return liste

# ------------------------------------------------------------ construction

## Bâtit un quartier. Le nœud rendu porte déjà son origine et son ANGLE : on
## l'ajoute tel quel, et deux quartiers voisins n'ont aucune raison d'être
## d'accord sur la direction du nord.
static func batir(id: String) -> Node3D:
	var fiche: Dictionary = CATALOGUE.get(id, {})
	if fiche.is_empty():
		push_error("Quartier inconnu : " + id)
		return Node3D.new()
	return batir_fiche(fiche, id)

## ⚠ L'ÉDITEUR passe par ici, pas par une copie : une fiche qu'on vient de
## modifier à la souris doit se bâtir EXACTEMENT comme celle du catalogue,
## sinon l'éditeur montre une ville et le jeu en bâtit une autre.
## ⚠ `zone` EST CE QUI REND LA GRANDE ÎLE POSSIBLE. Pikstown fait 48 375 cases :
## la bâtir d'un bloc coûte six secondes et soixante mille nœuds en natif, donc
## une bonne minute et un onglet mort dans le navigateur. On la bâtit donc par
## MORCEAUX (`VilleMorcelee`), et un morceau n'est rien d'autre que cette même
## fonction bornée à un rectangle de cases. La CARTE, elle, est toujours
## calculée en entier : c'est une table, elle coûte des microsecondes, et sans
## elle une rue ne saurait pas qu'elle continue dans le morceau d'à côté — les
## raccords tomberaient en impasse à chaque bord de morceau.
##
## Une zone vide (taille nulle) veut dire « tout », pour que les vieux appels
## et le banc photo n'aient rien à changer.
## ⚠ `prete` : LA CARTE ET LA LISTE DES BÂTIMENTS, CALCULÉES UNE FOIS. Elles ne
## dépendent que du dessin, pas du morceau qu'on bâtit — mais les recalculer à
## chaque morceau coûtait plus cher que de poser les meshes. Sur Pikstown, cent
## morceaux × (une carte de 28 000 cases + un balayage des bâtiments), c'est la
## différence entre une ville qui se charge et une ville qui rame.
## ⚠ LES BÂTIMENTS SONT RANGÉS PAR SEAUX DE SEIZE CASES. Pikstown en compte
## 15 901 : les parcourir tous pour bâtir un morceau de 24 × 24 — qui en
## contient une centaine — coûtait à lui seul la moitié des 354 ms d'un
## morceau. Un bâtiment est inscrit dans chaque seau qu'il touche ; bâtir un
## morceau ne lit plus que les seaux qui le recouvrent.
const SEAU := 16

static func preparer(fiche: Dictionary) -> Dictionary:
	var carte := carte_de(fiche)
	_depots_caches[carte] = _compter_depots(carte, fiche["plan"])
	var liste: Array = batiments(fiche["plan"])
	var seaux: Dictionary = {}
	for k in liste.size():
		var b: Dictionary = liste[k]
		var i0: int = int(b["i"]) / SEAU
		var j0: int = int(b["j"]) / SEAU
		var i1: int = (int(b["i"]) + int(b["w"]) - 1) / SEAU
		var j1: int = (int(b["j"]) + int(b["h"]) - 1) / SEAU
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var cle := Vector2i(i, j)
				if not seaux.has(cle): seaux[cle] = PackedInt32Array()
				seaux[cle].append(k)
	return {"carte": carte, "batiments": liste, "seaux": seaux}

## Les bâtiments qui peuvent toucher la zone. Une zone vide vaut « tous ».
static func _batiments_de(listes: Array, seaux: Dictionary, zone: Rect2i) -> Array:
	if zone.size == Vector2i.ZERO or seaux.is_empty():
		return listes
	var rangs: Dictionary = {}
	var i0 := zone.position.x / SEAU
	var j0 := zone.position.y / SEAU
	var i1 := (zone.position.x + zone.size.x - 1) / SEAU
	var j1 := (zone.position.y + zone.size.y - 1) / SEAU
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var cle := Vector2i(i, j)
			if not seaux.has(cle): continue
			for k in (seaux[cle] as PackedInt32Array):
				rangs[k] = true
	var sortie: Array = []
	for k in rangs.keys():
		sortie.append(listes[k])
	return sortie

static var _depots_caches: Dictionary = {}

static func depots_de(carte: CarteVille, dessin: Array) -> int:
	if _depots_caches.has(carte): return int(_depots_caches[carte])
	var n := _compter_depots(carte, dessin)
	_depots_caches[carte] = n
	return n

static func _compter_depots(carte: CarteVille, dessin: Array) -> int:
	var n := 0
	for c in carte.cases.keys():
		if _car(dessin, c.x, c.y) == "X": n += 1
	return n

## LES PASSES. Un morceau se bâtit en quatre fois plutôt qu'en une : le coût est
## le même, mais il se répartit sur quatre images au lieu d'en figer une seule.
## Soixante-quatre millisecondes d'un coup, c'est quatre images sautées au
## franchissement de chaque bord de morceau — et on en franchit un toutes les
## trois secondes en voiture. Étalé, ça ne se voit plus : le sol paraît, puis la
## chaussée, puis les façades, puis les arbres. C'est aussi l'ordre dans lequel
## on veut qu'ils paraissent si on regarde.
enum {
	P_SOLS = 1, P_CHAUSSEES = 2, P_BATIMENTS = 4, P_VERDURE = 8,
	P_MOBILIER = 16, P_BATEAUX = 32,
}
const P_TOUT := 63

static func batir_fiche(fiche: Dictionary, id: String = "atelier",
		zone: Rect2i = Rect2i(), prete: Dictionary = {}, passes: int = P_TOUT,
		racine: Node3D = null) -> Node3D:
	# ⚠ `racine` non nulle = on CONTINUE un morceau commencé. Sans ce paramètre,
	# chaque passe fabriquerait son propre nœud et le morceau sortirait en
	# quatre exemplaires superposés.
	if racine == null:
		racine = Node3D.new()
		racine.name = "Quartier_" + id
		var org: Vector2 = fiche.get("origine", Vector2.ZERO)
		racine.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(fiche.get("angle", 0.0)))),
			Vector3(org.x * CASE, 0, org.y * CASE))
	var carte: CarteVille = prete.get("carte", null) if prete.has("carte") else carte_de(fiche)
	var listes: Array = prete.get("batiments", [])
	var seaux: Dictionary = prete.get("seaux", {})
	var dessin: Array = fiche["plan"]
	var alea := RandomNumberGenerator.new()
	alea.seed = int(fiche.get("graine", 1))

	if passes & P_SOLS: _poser_sols(racine, carte, dessin, fiche, zone)
	if passes & P_CHAUSSEES: _poser_chaussees(racine, carte, zone)
	if passes & P_BATIMENTS: _poser_batiments(racine, carte, dessin, fiche, alea, zone, listes, seaux)
	if passes & P_VERDURE: _poser_verdure(racine, carte, dessin, alea, zone)
	if passes & P_MOBILIER: _poser_mobilier(racine, carte, dessin, alea, zone)
	if passes & P_BATEAUX: _poser_bateaux(racine, dessin, alea, zone)
	return racine

## Une zone de taille nulle vaut « toute la grille ».
static func _dedans(zone: Rect2i, c: Vector2i) -> bool:
	return zone.size == Vector2i.ZERO or zone.has_point(c)

## ⚠ LES CASES DE LA ZONE, PAS TOUTES LES CASES FILTRÉES. Première version :
## chaque poseur balayait les 28 581 cases de la ville et jetait celles qui
## n'étaient pas dans le morceau. Quatre poseurs × 28 581 × cent morceaux, ça
## faisait onze millions d'itérations pour poser cinquante mille objets — et
## un morceau coûtait 302 ms, soit un à-coup visible à chaque pas du joueur.
## En parcourant le rectangle et en demandant à la table si la case existe, un
## morceau ne regarde plus que ses 576 cases.
static func _cases_de(carte: CarteVille, zone: Rect2i) -> Array:
	if zone.size == Vector2i.ZERO:
		return carte.cases.keys()
	var liste: Array = []
	for j in range(zone.position.y, zone.position.y + zone.size.y):
		for i in range(zone.position.x, zone.position.x + zone.size.x):
			var c := Vector2i(i, j)
			if carte.cases.has(c): liste.append(c)
	return liste

## ⚠ LE TIRAGE DOIT DÉPENDRE DE LA CASE, PAS DE L'ORDRE. Tant que la ville se
## bâtissait d'un bloc, tirer les hauteurs et les essences à la file donnait un
## résultat stable. Bâtie par morceaux, la même case reçoit un tirage différent
## selon les cases construites avant elle : un pâté rebâti après une retouche
## changeait d'immeubles, et deux morceaux voisins ne se raccordaient plus.
## On resème donc à chaque case, sur (graine, i, j).
static func _resemer(alea: RandomNumberGenerator, base: int, c: Vector2i) -> void:
	alea.seed = hash(Vector3i(base, c.x, c.y))

static func _poser_sols(racine: Node3D, carte: CarteVille, dessin: Array, fiche: Dictionary,
		zone: Rect2i = Rect2i()) -> void:
	var herbe: Color = fiche.get("herbe", Color("#7f9464"))
	var roche: Color = fiche.get("roche", Color("#8b8578"))
	for c in _cases_de(carte, zone):
		var y := carte.hauteur(c)
		var centre := Vector3((float(c.x) + 0.5) * CASE, y, (float(c.y) + 0.5) * CASE)
		var car := _car(dessin, c.x, c.y)
		if not carte.route(c):
			# TOUT CE QUI PORTE UN BÂTIMENT EST PAVÉ. C'était le défaut le plus
			# criant des maquettes : des immeubles posés sur une pelouse. Dans
			# une ville, l'herbe est l'exception, pas le fond.
			var teinte := herbe
			if car in PAVE or _lettre(car) != "": teinte = TEINTE_PAVE
			elif car == ";": teinte = TEINTE_SABLE
			_tuile(racine, "tile-low", centre, 0, teinte)
		# ⚠ LE TALUS DESCEND JUSQU'AU VOISIN LE PLUS BAS, PAS JUSQU'À LA MER.
		# Tant que la ville était plate, les deux revenaient au même : seules
		# les cases du rivage avaient un voisin plus bas. Avec cinq paliers de
		# dénivelé, une terrasse au palier 5 posée contre une terrasse au
		# palier 4 sortait un mur de six étages dont cinq étaient sous terre —
		# des dizaines de milliers de boîtes invisibles, et la moitié du coût
		# d'un morceau.
		var plus_bas := 99
		var sur_mer := false
		for d in CarteVille.COTES:
			var v: Vector2i = c + d
			if not carte.cases.has(v):
				sur_mer = true
			else:
				plus_bas = mini(plus_bas, carte.palier(v))
		if sur_mer or plus_bas < carte.palier(c):
			_falaise(racine, centre, y, roche,
				-2.6 if sur_mer else float(plus_bas) * PALIER)

## LA FALAISE. Un seul bloc du sol jusqu'à la mer donnait un mur de plâtre de
## quarante unités : la ville avait l'air posée sur un socle de maquette. On la
## dessine en STRATES d'un palier, chacune rentrée d'un poil et un ton plus
## sombre que celle du dessus — c'est ce qui fait lire une falaise plutôt
## qu'une découpe, et ça ne coûte que quelques boîtes de plus par case de bord.
## ⚠ UNE MATIÈRE ET UN MAILLAGE PARTAGÉS, PAS UN PAR BOÎTE. Chaque strate de
## talus fabriquait son propre `BoxMesh` et son propre `StandardMaterial3D` :
## sur une ville plate ça passait (seul le rivage a des talus), sur une ville à
## cinq paliers c'était la moitié du temps de construction d'un morceau, et
## autant d'appels de rendu que de boîtes. Il n'y a que huit teintes possibles,
## et une seule boîte.
static var _boites: BoxMesh = null
static var _roches: Dictionary = {}

static func _boite_talus() -> BoxMesh:
	if _boites == null:
		_boites = BoxMesh.new()
		_boites.size = Vector3(CASE, 1.0, CASE)
	return _boites

static func _teinte_roche(roche: Color, strate: int) -> Material:
	var cle := roche.to_html() + str(strate)
	if _roches.has(cle): return _roches[cle]
	var m := StandardMaterial3D.new()
	m.albedo_color = roche.darkened(0.06 + 0.055 * float(strate))
	m.roughness = 1.0
	_roches[cle] = m
	return m

static func _falaise(racine: Node3D, centre: Vector3, y: float, roche: Color,
		fond: float = -2.6) -> void:
	var bas := fond
	var strates := maxi(1, ceili((y - bas) / PALIER))
	for k in strates:
		var haut: float = y - float(k) * PALIER
		var sous: float = maxf(bas, haut - PALIER)
		var n := MeshInstance3D.new()
		n.mesh = _boite_talus()
		n.material_override = _teinte_roche(roche, k)
		var e := 1.0 - 0.028 * float(k)     # chaque strate rentre un peu
		n.transform = Transform3D(Basis().scaled(Vector3(e, haut - sous, e)),
			centre + Vector3(0, (haut + sous) * 0.5 - y, 0))
		racine.add_child(n)

static func _poser_chaussees(racine: Node3D, carte: CarteVille, zone: Rect2i = Rect2i()) -> void:
	for c in _cases_de(carte, zone):
		if not carte.route(c) or carte.case_prise(c): continue
		var fiche: Array = carte.tuile(c)
		_tuile(racine, String(fiche[0]), carte.centre(c), int(fiche[1]), TEINTE_ROUTE)
	for p in carte.pieces:
		var cote := int(p["w"])
		var coin := Vector2i(int(p["i"]), int(p["j"]))
		if not _dedans(zone, coin): continue
		_tuile(racine, String(p["t"]),
			Vector3((float(coin.x) + float(cote) * 0.5) * CASE, carte.hauteur(coin),
				(float(coin.y) + float(cote) * 0.5) * CASE), int(p["q"]), TEINTE_ROUTE)

## ⚠ Une pièce du kit EST DÉJÀ à sa taille : `road-roundabout` mesure trois
## unités de côté. On multiplie par UNE case, jamais par son côté — le rond-
## point est sorti une fois à neuf cases de large, et ça s'est vu tout de suite.
static func _tuile(parent: Node3D, nom: String, ou: Vector3, quarts: int, teinte: Color) -> void:
	var chemin := ROUTES + nom + ".glb"
	if not ResourceLoader.exists(chemin): return
	var n := MeshInstance3D.new()
	n.mesh = FormesCarnage.maillage_kenney(chemin, 0.0, Vector3.AXIS_X, 0.0)
	n.material_override = _matiere(chemin, teinte)
	n.transform = Transform3D(Basis(Vector3.UP, PI * 0.5 * float(quarts)).scaled(Vector3.ONE * CASE), ou)
	parent.add_child(n)

static var _matieres: Dictionary = {}

static func _matiere(chemin: String, teinte: Color) -> Material:
	var cle := chemin + teinte.to_html()
	if _matieres.has(cle): return _matieres[cle]
	var m := FormesCarnage.matiere_kenney(chemin).duplicate()
	if m is ShaderMaterial:
		(m as ShaderMaterial).set_shader_parameter("teinte", teinte)
	elif m is BaseMaterial3D:
		(m as BaseMaterial3D).albedo_color = teinte
	_matieres[cle] = m
	return m

## Un bâtiment remplit SON rectangle, moins un retrait. Le retrait est ce qui
## fait qu'on voit le jour entre deux immeubles ; sans lui le pâté n'est plus
## qu'un bloc, et avec trop, la ville redevient un lotissement.
const RETRAIT := 0.10

## ⚠ L'EMPRISE MAXIMALE D'UN MODÈLE, en cases. Un pavillon Kenney est dessiné
## pour tenir sur une case ; étiré sur quatre, il devient un bungalow de
## quarante mètres avec une porte de garage de dix — c'est exactement ce qui
## rendait la vieille ville risible. Au-delà de son emprise, un rectangle de
## lettres est DÉCOUPÉ en autant de bâtiments qu'il faut : `MMMM` sur deux
## rangées ne fait pas une maison géante, il fait huit maisons mitoyennes.
const EMPRISES := {"T": 3.0, "B": 3.0, "C": 2.0, "V": 1.0, "M": 1.0, "H": 4.0}

static func _poser_batiments(racine: Node3D, carte: CarteVille, dessin: Array,
		fiche: Dictionary, alea: RandomNumberGenerator, zone: Rect2i = Rect2i(),
		listes: Array = [], seaux: Dictionary = {}) -> void:
	var etages: Dictionary = fiche.get("hauteurs", {})
	var base := int(fiche.get("graine", 1))
	var voulus: Array = _batiments_de(listes, seaux, zone) if not listes.is_empty() \
		else batiments(dessin)
	for b in voulus:
		if not _dedans(zone, Vector2i(int(b["i"]), int(b["j"]))): continue
		_resemer(alea, base, Vector2i(int(b["i"]), int(b["j"])))
		var lettre := String(b["lettre"])
		var style: int = FAMILLES.get(lettre, PlanVille.F_COMMERCE)
		var coin := Vector2i(int(b["i"]), int(b["j"]))
		var w := float(b["w"])
		var h := float(b["h"])
		# À cheval sur deux paliers, on prend le PLUS HAUT : un immeuble à
		# moitié enterré vaut mieux qu'un immeuble sur pilotis invisibles.
		var niveau := 0
		var pose := true
		for a in int(w):
			for c in int(h):
				var cc := coin + Vector2i(a, c)
				if not carte.terre(cc) or carte.case_prise(cc): pose = false
				niveau = maxi(niveau, carte.palier(cc))
		if not pose: continue
		var bornes: Array = etages.get(lettre, [14.0, 26.0])
		var emax: float = float(EMPRISES.get(lettre, 3.0))
		var na := maxi(1, ceili(w / emax - 0.001))
		var nb := maxi(1, ceili(h / emax - 0.001))
		var pas_a := w / float(na)
		var pas_b := h / float(nb)
		var precedent := ""
		for a in na:
			for c in nb:
				var hauteur: float = alea.randf_range(float(bornes[0]), float(bornes[1]))
				var larg := (pas_a - RETRAIT * 2.0) * CASE
				var prof := (pas_b - RETRAIT * 2.0) * CASE
				if larg < 3.0 or prof < 3.0: continue
				var chemin := FormesCarnage.batiment_kenney(style, minf(larg, prof), hauteur,
					alea.randi(), precedent)
				if chemin == "": continue
				precedent = chemin
				var teintes: Array = PlanVille.TEINTES.get(style, [Color.WHITE])
				var teinte: Color = teintes[alea.randi() % teintes.size()]
				var n := MeshInstance3D.new()
				n.mesh = FormesCarnage.maillage_batiment(chemin)
				n.material_override = _matiere(chemin, teinte)
				n.transform = Transform3D(Basis().scaled(Vector3(larg, hauteur, prof)),
					Vector3((float(coin.x) + (float(a) + 0.5) * pas_a) * CASE,
						float(niveau) * PALIER,
						(float(coin.y) + (float(c) + 0.5) * pas_b) * CASE))
				racine.add_child(n)

const ARBRES := ["nature/tree_default", "nature/tree_oak", "nature/tree_fat",
	"nature/tree_detailed", "nature/tree_cone"]

## Le décor de sol : ce qui n'est ni rue ni bâtiment mais qui empêche une case
## d'être un trou. Un pâté vide se lit comme un bogue, et un port sans
## conteneurs n'est qu'un lotissement au bord de l'eau.
## ⚠ Les proportions, pas les modèles : à l'échelle du jeu une voiture fait dix
## unités de long, donc une unité vaut à peu près un demi-mètre. Un conteneur
## de deux mètres soixante fait SIX unités, pas neuf ; et une cuve à dix mètres
## en fait vingt — d'où la règle de ne pas en semer partout, sinon le port
## n'est plus qu'un champ de citernes plus hautes que ses hangars.
const DEPOT := [
	["industriel/shipping-container-a", 6.0], ["industriel/shipping-container-b", 6.0],
	["industriel/shipping-container-c", 6.0], ["industriel/shipping-container-a", 6.0],
	["industriel/shipping-container-b", 6.0], ["industriel/shipping-container-c", 6.0],
	["industriel/shipping-container-a", 6.0], ["industriel/shipping-container-b", 6.0],
	["industriel/solar-panel-flat", 2.4],
]
## ⚠ `urbain/`, PAS `routes/`. Ces cinq-là étaient cherchés dans le dossier des
## tuiles de chaussée, où ils n'ont jamais été : `_objet` ne trouvait rien et
## sortait EN SILENCE, si bien que les 201 cases de chantier de la ville ne
## posaient pas un cône. Trouvé en photographiant le pinceau « Chantier »
## (`outils/vignettes.gd`) : sa vignette est sortie vide, et une vignette vide
## ne se discute pas. Le cinquième modèle, `construction-light`, n'existe dans
## aucun dossier du kit — remplacé par un deuxième cône plutôt qu'inventé.
const CHANTIER := [
	["urbain/construction-barrier", 4.0], ["urbain/construction-cone", 2.6],
	["urbain/construction-fence", 6.0], ["urbain/construction-cone", 2.6],
	["urbain/dumpster", 5.0],
]

## Une cuve n'a le droit de sortir que si aucune autre n'est à moins de trois
## cases, et pas plus d'une pour dix cases de dépôt. Trois cuves côte à côte,
## ça ne fait pas un port : ça fait une usine à gaz.
const ECART_CUVES := 3
const PART_CUVES := 0.10

static func _cuve_ici(c: Vector2i, cuves: Array, alea: RandomNumberGenerator) -> bool:
	for v in cuves:
		if absi((v as Vector2i).x - c.x) < ECART_CUVES and absi((v as Vector2i).y - c.y) < ECART_CUVES:
			return false
	return alea.randf() < 0.5

static func _poser_verdure(racine: Node3D, carte: CarteVille, dessin: Array,
		alea: RandomNumberGenerator, zone: Rect2i = Rect2i()) -> void:
	var cuves: Array = []
	# ⚠ Le plafond de cuves est GLOBAL — il se compte sur toute la ville, pas
	# sur le morceau —, mais le recompter à chaque morceau coûtait un balayage
	# complet de plus. Il vient donc de `preparer`.
	var plafond := maxi(1, int(float(depots_de(carte, dessin)) * PART_CUVES))
	for c in _cases_de(carte, zone):
		_resemer(alea, 7717, c)
		var car := _car(dessin, c.x, c.y)
		var y := carte.hauteur(c)
		match car:
			"^":
				for k in 3:
					_objet(racine, ARBRES[alea.randi() % ARBRES.size()], _dans(c, y, alea),
						alea.randf_range(9.0, 15.0), alea.randf() * TAU)
			"\'":
				for k in 5:
					_objet(racine, "nature/plant_bushLarge", _dans(c, y, alea),
						alea.randf_range(2.2, 3.4), alea.randf() * TAU)
			"X":
				# Les conteneurs s'alignent sur la case, pas au hasard : un
				# dépôt, ça s'empile en rangées, sinon on dirait une décharge.
				if cuves.size() < plafond and _cuve_ici(c, cuves, alea):
					cuves.append(c)
					_objet(racine, "industriel/detail-tank-large",
						Vector3((float(c.x) + 0.5) * CASE, y, (float(c.y) + 0.5) * CASE), 19.0)
					continue
				for k in 3:
					for l in 2:
						if alea.randf() < 0.28: continue
						var f: Array = DEPOT[alea.randi() % DEPOT.size()]
						_objet(racine, String(f[0]),
							Vector3((float(c.x) + 0.2 + 0.3 * float(k)) * CASE, y,
								(float(c.y) + 0.28 + 0.44 * float(l)) * CASE),
							float(f[1]), 0.0)
			"%":
				for k in 4:
					var g: Array = CHANTIER[alea.randi() % CHANTIER.size()]
					_objet(racine, String(g[0]), _dans(c, y, alea), float(g[1]), alea.randf() * TAU)
			"P":
				# Un parking sans voitures n'est qu'une dalle grise.
				for k in 2:
					_voiture(racine, Vector3((float(c.x) + 0.3 + 0.4 * float(k)) * CASE, y,
						(float(c.y) + 0.5) * CASE), false, alea)

## Un point DANS la case, mais rentré des bords : semé jusqu'au bord, un arbre
## déborde de moitié sur la case d'à côté — souvent un immeuble.
static func _dans(c: Vector2i, y: float, alea: RandomNumberGenerator) -> Vector3:
	return Vector3((float(c.x) + 0.22 + alea.randf() * 0.56) * CASE, y,
		(float(c.y) + 0.22 + alea.randf() * 0.56) * CASE)

const VOITURES := ["sedan", "suv", "taxi", "van", "delivery", "hatchback-sports",
	"sedan-sports", "police", "truck", "garbage-truck"]

## Ce qui donne l'ÉCHELLE : lampadaires, feux, arbres d'alignement, voitures.
## Sans eux la ville est une maquette d'architecte — c'est le reproche qu'on
## s'est pris sur la toute première.
static func _poser_mobilier(racine: Node3D, carte: CarteVille, dessin: Array,
		alea: RandomNumberGenerator, zone: Rect2i = Rect2i()) -> void:
	for c in _cases_de(carte, zone):
		_resemer(alea, 4242, c)
		if not carte.route(c) or carte.case_prise(c): continue
		var fiche: Array = carte.tuile(c)
		var nom := String(fiche[0])
		var y := carte.hauteur(c)
		var centre := carte.centre(c)
		var bord := CASE * 0.42
		if nom == "road-straight":
			var selon_x := int(fiche[1]) == 0
			var vers: Vector2i = CarteVille.S if selon_x else CarteVille.E
			var d := Vector3(0, 0, bord) if selon_x else Vector3(bord, 0, 0)
			var t := 0.0 if selon_x else PI * 0.5
			# Un lampadaire tient sur le trottoir ; un arbre, non : il ne se
			# plante que du côté où la case voisine est LIBRE.
			if alea.randf() < 0.30:
				# ⚠ `urbain/`, PAS `routes/` — même faute que pour le chantier, et
				# celle-ci coûtait plus cher : PAS UN SEUL LAMPADAIRE dans toute
				# la ville, alors que c'est le premier objet cité comme donnant
				# l'échelle. Un chemin de modèle qui n'existe pas ne fait rien
				# et ne dit rien ; c'est le banc de vignettes qui l'a montré.
				_objet(racine, "urbain/light-square", centre + d, 9.5, t, Color("#6e737c"))
				_objet(racine, "urbain/light-square", centre - d, 9.5, t + PI, Color("#6e737c"))
			if alea.randf() < 0.30:
				var libres: Array = []
				if _lettre(_car(dessin, c.x + vers.x, c.y + vers.y)) == "": libres.append(d)
				if _lettre(_car(dessin, c.x - vers.x, c.y - vers.y)) == "": libres.append(-d)
				if not libres.is_empty():
					_objet(racine, ARBRES[alea.randi() % ARBRES.size()],
						centre + libres[alea.randi() % libres.size()] * 0.82,
						alea.randf_range(8.0, 12.0), alea.randf() * TAU)
			if alea.randf() < 0.28:
				_voiture(racine, centre, selon_x, alea)
		elif nom == "road-crossroad" and alea.randf() < 0.65:
			for k in 4:
				var a := PI * 0.5 * float(k)
				_objet(racine, "routes/traffic-light",
					centre + Vector3(cos(a), 0, sin(a)) * bord, 8.0, a)

static func _voiture(racine: Node3D, ou: Vector3, selon_x: bool, alea: RandomNumberGenerator) -> void:
	var chemin := "res://modeles/kenney/voitures/%s.glb" % VOITURES[alea.randi() % VOITURES.size()]
	if not ResourceLoader.exists(chemin): return
	var n := MeshInstance3D.new()
	# ⚠ Les carrosseries du Car Kit regardent +Z là où le reste du kit regarde
	# −Z : un quart de tour dans l'AUTRE sens, sinon la ville roule à reculons.
	n.mesh = FormesCarnage.maillage_kenney(chemin, 10.0, Vector3.AXIS_Z, PI * 0.5)
	n.material_override = FormesCarnage.matiere_kenney(chemin)
	var voie := CASE * 0.16 * (1.0 if alea.randf() < 0.5 else -1.0)
	var sens := 0.0 if voie > 0.0 else PI
	var decal := alea.randf_range(-6.0, 6.0)
	n.transform = Transform3D(Basis(Vector3.UP, sens + (0.0 if selon_x else PI * 0.5)),
		ou + (Vector3(decal, 0, voie) if selon_x else Vector3(voie, 0, decal)))
	racine.add_child(n)

static func _objet(parent: Node3D, sous_chemin: String, ou: Vector3, hauteur: float,
		tourne: float = 0.0, teinte := Color.WHITE) -> void:
	var chemin := "res://modeles/kenney/" + sous_chemin + ".glb"
	if not ResourceLoader.exists(chemin): return
	var n := MeshInstance3D.new()
	n.mesh = FormesCarnage.maillage_kenney(chemin, hauteur, Vector3.AXIS_Y, 0.0)
	n.material_override = _matiere(chemin, teinte)
	n.transform = Transform3D(Basis(Vector3.UP, tourne), ou)
	parent.add_child(n)

# ------------------------------------------------------------ les bateaux

## LE MOUILLAGE. Une file de `~` est une place d'amarrage : sa LONGUEUR dit
## quel bateau vient s'y mettre. Écrire un modèle par case aurait demandé un
## caractère par bateau ; là, on dessine l'eau du port et la flotte suit.
## ⚠ Les coques du Watercraft Pack sont toutes longues selon Z (mesuré,
## `outils/bateaux.gd`) : on les tourne pour les aligner sur la file.
const FLOTTE := [
	# longueur mini de la file (en cases), modèle, longueur en unités de jeu
	[6, ["bateaux/ship-ocean-liner-small", 220.0], ["bateaux/ship-cargo-a", 200.0],
		["bateaux/ship-cargo-b", 200.0], ["bateaux/ship-large", 180.0]],
	[4, ["bateaux/ship-small", 140.0], ["bateaux/ship-cargo-b", 200.0]],
	[2, ["bateaux/boat-tug-a", 50.0], ["bateaux/boat-tug-b", 46.0],
		["bateaux/boat-fishing-small", 28.0]],
	[1, ["bateaux/boat-speed-a", 16.0], ["bateaux/boat-speed-c", 16.0],
		["bateaux/boat-sail-a", 24.0], ["bateaux/boat-row-large", 12.0],
		["bateaux/buoy", 5.0], ["bateaux/buoy-flag", 6.0]],
]
const NIVEAU_MER := -2.4

static func _poser_bateaux(racine: Node3D, dessin: Array, alea: RandomNumberGenerator,
		zone: Rect2i = Rect2i()) -> void:
	var vues: Dictionary = {}
	var large := 0
	for l in dessin:
		large = maxi(large, String(l).length())
	# ⚠ ON BORNE LE BALAYAGE À LA ZONE, ÉLARGIE DE DOUZE CASES. Une file de
	# mouillages fait au plus dix cases : douze suffisent pour qu'un morceau
	# voie entièrement une file qui commence chez son voisin. Sans cette borne,
	# chaque morceau relisait les 48 375 caractères du dessin pour poser zéro
	# bateau — la ville n'a qu'un port.
	var j0 := 0
	var j1 := dessin.size() - 1
	var i0 := 0
	var i1 := large - 1
	if zone.size != Vector2i.ZERO:
		j0 = maxi(0, zone.position.y - 12)
		j1 = mini(dessin.size() - 1, zone.position.y + zone.size.y + 12)
		i0 = maxi(0, zone.position.x - 12)
		i1 = mini(large - 1, zone.position.x + zone.size.x + 12)
	# Les files horizontales, puis les verticales : une place d'amarrage se lit
	# dans le sens du quai.
	for j in range(j0, j1 + 1):
		var i := i0
		while i <= i1:
			if _car(dessin, i, j) != "~" or vues.has(Vector2i(i, j)):
				i += 1
				continue
			var n := 0
			while _car(dessin, i + n, j) == "~" and not vues.has(Vector2i(i + n, j)):
				n += 1
			for k in n: vues[Vector2i(i + k, j)] = true
			# ⚠ Le bateau appartient au morceau qui contient le MILIEU de sa
			# file, et à lui seul : sinon une file à cheval sur deux morceaux
			# sort deux fois, et deux cargos se traversent au même quai.
			if _dedans(zone, Vector2i(i + n / 2, j)):
				_amarrer(racine, Vector2(float(i) + float(n) * 0.5, float(j) + 0.5), n, true, alea)
			i += n
	for i in range(i0, i1 + 1):
		var j := j0
		while j <= j1:
			if _car(dessin, i, j) != "~" or vues.has(Vector2i(i, j)):
				j += 1
				continue
			var n := 0
			while _car(dessin, i, j + n) == "~" and not vues.has(Vector2i(i, j + n)):
				n += 1
			for k in n: vues[Vector2i(i, j + k)] = true
			if _dedans(zone, Vector2i(i, j + n / 2)):
				_amarrer(racine, Vector2(float(i) + 0.5, float(j) + float(n) * 0.5), n, false, alea)
			j += n

static func _amarrer(racine: Node3D, centre: Vector2, longueur: int, selon_x: bool,
		alea: RandomNumberGenerator) -> void:
	for fiche in FLOTTE:
		if longueur < int(fiche[0]): continue
		var choix: Array = fiche[1 + alea.randi() % (fiche.size() - 1)]
		var chemin := "res://modeles/kenney/" + String(choix[0]) + ".glb"
		if not ResourceLoader.exists(chemin): return
		var n := MeshInstance3D.new()
		n.mesh = FormesCarnage.maillage_kenney(chemin, float(choix[1]), Vector3.AXIS_Z, 0.0)
		n.material_override = FormesCarnage.matiere_kenney(chemin)
		var tour := (PI * 0.5 if selon_x else 0.0) + alea.randf_range(-0.03, 0.03)
		n.transform = Transform3D(Basis(Vector3.UP, tour),
			Vector3(centre.x * CASE, NIVEAU_MER, centre.y * CASE))
		racine.add_child(n)
		return

# ------------------------------------------------------------ la ville entière

## ⚠ IL N'Y A PLUS DE PONTS EN MONDE. Ils existaient parce que deux quartiers
## d'angles différents ne pouvaient pas se raccorder dans une grille commune :
## le pont était forcément en biais, donc forcément hors des dessins. Avec une
## trame unique, un pont est un `=` dans le plan comme une rue est un `#` — il
## se dessine, se déplace et se vérifie comme le reste. Sept ponts franchissent
## les deux chenaux de Pikstown, tous dans `PlanPikstown.PLAN`.
const PONTS := []

static func ville() -> Node3D:
	var racine := Node3D.new()
	racine.name = "Ville"
	var mer := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(3000.0 * CASE, 3000.0 * CASE)
	mer.mesh = plan
	var eau := StandardMaterial3D.new()
	eau.albedo_color = Color("#2b5f7a")
	eau.roughness = 0.15
	eau.metallic = 0.25
	mer.material_override = eau
	mer.position = Vector3(0, -2.4, 0)
	racine.add_child(mer)
	for id in CATALOGUE.keys():
		racine.add_child(batir(String(id)))
	for p in PONTS:
		_pont(racine, Vector3(p[0].x * CASE, float(p[2]) * PALIER, p[0].y * CASE),
			Vector3(p[1].x * CASE, float(p[3]) * PALIER, p[1].y * CASE))
	return racine

static func _pont(racine: Node3D, a: Vector3, b: Vector3) -> void:
	var pas := maxf(1.0, a.distance_to(b) / CASE)
	var dir := (b - a).normalized()
	var angle := atan2(-dir.z, dir.x)
	for k in int(pas) + 1:
		var p := a.lerp(b, float(k) / pas)
		var n := MeshInstance3D.new()
		var chemin := ROUTES + "road-bridge.glb"
		n.mesh = FormesCarnage.maillage_kenney(chemin, 0.0, Vector3.AXIS_X, 0.0)
		n.material_override = _matiere(chemin, Color("#9aa0aa"))
		# Le tablier suit la CORDE, pas la grille — et chaque pièce est
		# allongée d'un poil, sinon deux voisines laissent une fente en biais.
		n.transform = Transform3D(Basis(Vector3.UP, angle).scaled(Vector3(CASE * 1.08, CASE, CASE)), p)
		racine.add_child(n)
