class_name PlanVille
extends RefCounted
## Le plan de la ville de CARNAGE, déduit du CODE de la manche.
##
## Rien de tout ceci ne circule sur le réseau : même code, même ville, chez
## tout le monde et à tout instant. Diffuser un plan de quarante-huit par
## trente-six tuiles coûterait des dizaines de kilo-octets par partie et
## ajouterait un cas de plus pour qui rejoint en retard.
##
## La ville est PROCÉDURALE et par QUARTIERS : un centre d'affaires neutre, et
## autour, trois territoires qui ne se ressemblent pas — la zone industrielle
## des Braises, les rues commerçantes de La Fonte, la banlieue pavillonnaire du
## Lierre — plus des parcs semés au hasard. C'est le décor qui dit chez qui on
## est, avant la jauge de respect. Chaque quartier a ses immeubles (quatre kits
## Kenney, CC0), ses voitures garées, ses passants et ses repaires de gang.
##
## ⚠ Les collisions ne balayent PAS une liste de rectangles. La ville en
## compte près de mille ; avec quatre-vingt-dix piétons, trois cents voitures
## et des projectiles, un balayage linéaire coûterait des centaines de
## milliers de tests par image. Une tuile se déduit d'une position par deux
## divisions : on ne teste jamais plus des quatre tuiles qui touchent le
## cercle.

const TUILE := 14.0                          ## côté d'une tuile, en unités 3D
const PAS := TUILE / Decor.ECHELLE           ## le même, en pixels de jeu
const COLONNES := 48
const LIGNES := 36
const CEINTURE := 3                          ## anneau de verdure autour de la ville
const RETRAIT := 22.0                        ## le mur est un peu en retrait de la tuile
const RAYON_CENTRE := 6.5                    ## en tuiles : le centre d'affaires, neutre

## Les quartiers. Chacun a sa liste de bâtiments, sa densité de passants, ses
## voitures et sa part de places de stationnement le long des rues.
enum { CENTRE, COMMERCE, INDUSTRIE, BANLIEUE, PARC }
const NOMS_QUARTIERS := ["centre d'affaires", "rues commerçantes", "zone industrielle",
	"banlieue pavillonnaire", "parc"]

## Trois gangs, trois territoires, trois façons de bâtir. La couleur du gang
## n'est jamais SÉRIE : le bleu est à la police, et on ne confond pas celui qui
## vous verbalise avec celui qui vous canarde.
const GANGS := [
	{"nom": "Les Braises", "couleur": Palette.CRITIQUE, "quartier": INDUSTRIE},
	{"nom": "La Fonte", "couleur": Palette.SERIEUX, "quartier": COMMERCE},
	{"nom": "Le Lierre", "couleur": Palette.BON, "quartier": BANLIEUE},
]

const VILLE := "res://modeles/ville/"
const COMMERCE_KIT := "res://modeles/commerce/"
const INDUSTRIE_KIT := "res://modeles/industrie/"
const BANLIEUE_KIT := "res://modeles/banlieue/"

## Le kit de Kenney est clair : cette teinte le refroidit à peine, juste assez
## pour qu'il tienne dans la palette sombre de la maison. Elle MULTIPLIE
## l'atlas de couleurs plutôt que de le remplacer.
const TEINTE_VILLE := Color(0.82, 0.85, 0.92)

## Ce que chaque kit pose, avec son échelle : les kits n'ont pas la même
## unité. Le kit de ville fait une tuile par unité ; les immeubles de commerce
## font ~1,3 de côté, les pavillons jusqu'à 1,8 — mis à la même échelle, ils
## déborderaient sur la rue. `y` tasse la hauteur : à l'échelle du sol, une
## tour de cinq unités et demie monterait à cinquante-cinq — plus haut que la
## caméra. Une ville écrasée se survole ; une ville haute se subit.
const KITS := {
	COMMERCE: {"dossier": COMMERCE_KIT, "xz": 10.0, "y": 0.5,
		"immeubles": ["building-a", "building-b", "building-c", "building-d", "building-f",
			"building-g", "building-h", "building-i", "building-l", "building-m"],
		"tours": ["building-skyscraper-a", "building-skyscraper-c",
			"building-skyscraper-d", "building-skyscraper-e"]},
	INDUSTRIE: {"dossier": INDUSTRIE_KIT, "xz": 10.0, "y": 0.6,
		"immeubles": ["building-e", "building-f", "building-g", "building-m"],
		"larges": ["building-a", "building-b", "building-c", "building-l", "building-q", "building-r"],
		"details": ["shipping-container-a", "shipping-container-b", "detail-tank-large",
			"water-tower", "chimney-large"]},
	BANLIEUE: {"dossier": BANLIEUE_KIT, "xz": 7.5, "y": 0.75,
		"immeubles": ["building-type-a", "building-type-b", "building-type-c", "building-type-d",
			"building-type-e", "building-type-f", "building-type-j", "building-type-n",
			"building-type-o", "building-type-s", "building-type-t"],
		"arbres": ["tree-large", "tree-small"]},
}

const RAYON_ARENE := 200.0
const RAYON_GARAGE := 74.0
const RAYON_CABINE := 68.0
const RAYON_REPAIRE := 230.0

var code := ""
## Chemin complet d'un modèle -> {"t": Array[Transform3D], "c": Array[Color]}
var nappes: Dictionary = {}
## Les places de stationnement : {p, a, quartier, territoire}. C'est l'hôte qui
## en fait des voitures ; le plan ne fait que dire où elles dorment.
var stationnements: Array = []
## Les repaires : {p, gang}. Là où les gars traînent et où leurs voitures dorment.
var repaires: Array = []

var _arenes: Array = []       ## Vector2 (centres)
var _garages: Array = []      ## Vector2
var _cabines: Array = []      ## Vector2
var _largeur := COLONNES + CEINTURE * 2
var _hauteur := LIGNES + CEINTURE * 2
var _bloc := PackedByteArray()               ## 1 = la tuile porte un mur
var _quartier := PackedByteArray()           ## par pâté : son type
var _territoire := PackedByteArray()         ## par pâté : gang + 1 (0 = neutre)
var _graine := RandomNumberGenerator.new()

# ------------------------------------------------------------ construction

func _init(code_de_manche: String) -> void:
	code = code_de_manche
	_graine.seed = hash(code)
	_bloc.resize(_largeur * _hauteur)
	_quartier.resize(pates_x() * pates_y())
	_territoire.resize(pates_x() * pates_y())
	_zoner()
	_placer_les_lieux()
	_batir()

func etendue() -> Vector2:
	return Vector2(COLONNES, LIGNES) * PAS

func centre() -> Vector2:
	return etendue() * 0.5

func banlieue() -> float:
	return CEINTURE * PAS

## Vrai si cette colonne (ou cette ligne) porte une rue. Une rue tous les
## quatre pas : des pâtés de trois sur trois, assez grands pour se cacher
## derrière, assez petits pour qu'un carrefour ne soit jamais loin.
static func est_voie(indice: int) -> bool:
	return posmod(indice, 4) == 0

static func centre_tuile(colonne: int, ligne: int) -> Vector2:
	return Vector2(colonne + 0.5, ligne + 0.5) * PAS

static func pates_x() -> int:
	return COLONNES / 4

static func pates_y() -> int:
	return LIGNES / 4

## Le pâté (3×3 tuiles entre les rues) qui contient une tuile, ou (-1,-1).
static func pate_de(colonne: int, ligne: int) -> Vector2i:
	if colonne < 0 or ligne < 0 or colonne >= COLONNES or ligne >= LIGNES:
		return Vector2i(-1, -1)
	if est_voie(colonne) or est_voie(ligne):
		return Vector2i(-1, -1)
	return Vector2i(colonne / 4, ligne / 4)

static func centre_pate(pate: Vector2i) -> Vector2:
	return centre_tuile(pate.x * 4 + 2, pate.y * 4 + 2)

func quartier_du_pate(pate: Vector2i) -> int:
	if pate.x < 0 or pate.y < 0 or pate.x >= pates_x() or pate.y >= pates_y():
		return PARC
	return _quartier[pate.y * pates_x() + pate.x]

func territoire_du_pate(pate: Vector2i) -> int:
	if pate.x < 0 or pate.y < 0 or pate.x >= pates_x() or pate.y >= pates_y():
		return -1
	return int(_territoire[pate.y * pates_x() + pate.x]) - 1

# ------------------------------------------------------------ le zonage

## Qui tient quoi. Le centre est neutre ; autour, chaque pâté revient au gang
## dont le fief est le plus proche — avec un peu de bruit, pour que la
## frontière ne soit pas une droite qu'on lit comme un défaut de génération.
func _zoner() -> void:
	var milieu := Vector2(pates_x(), pates_y()) * 0.5
	var fiefs: Array = []
	for g in 3:
		var angle := -PI * 0.5 + TAU * float(g) / 3.0
		fiefs.append(milieu + Vector2.RIGHT.rotated(angle) * Vector2(pates_x(), pates_y()) * 0.36)

	for py in pates_y():
		for px in pates_x():
			var ici := Vector2(px + 0.5, py + 0.5)
			var indice := py * pates_x() + px
			var au_centre: float = (ici - milieu).length() * 4.0   # en tuiles
			if au_centre < RAYON_CENTRE:
				_quartier[indice] = CENTRE
				_territoire[indice] = 0
				continue
			var gang := 0
			var meilleure := INF
			for g in 3:
				var d: float = (ici - Vector2(fiefs[g])).length() + _graine.randf_range(-0.9, 0.9)
				if d < meilleure:
					meilleure = d
					gang = g
			_territoire[indice] = gang + 1
			var type := int(GANGS[gang]["quartier"])
			# Le premier anneau autour du centre reste commerçant, quel que soit
			# le gang : une ville a un dégradé, pas une frontière au carrefour.
			if au_centre < RAYON_CENTRE + 4.0 and _graine.randf() < 0.55:
				type = COMMERCE
			elif _graine.randf() < 0.09:
				type = PARC
			_quartier[indice] = type

## Les lieux qui font quelque chose : arènes sur une frontière, garage et
## cabine par territoire, deux repaires par gang.
func _placer_les_lieux() -> void:
	var frontieres: Array = []
	var par_gang: Dictionary = {0: [], 1: [], 2: []}
	for py in pates_y():
		for px in pates_x():
			var pate := Vector2i(px, py)
			var t := territoire_du_pate(pate)
			if t < 0 or quartier_du_pate(pate) == PARC:
				continue
			par_gang[t].append(pate)
			for voisin in [Vector2i(1, 0), Vector2i(0, 1)]:
				var autre := territoire_du_pate(pate + voisin)
				if autre >= 0 and autre != t:
					frontieres.append(pate)
					break

	# Deux arènes, aux frontières, loin l'une de l'autre.
	frontieres.shuffle()
	var premiere: Vector2i = frontieres[0] if not frontieres.is_empty() else Vector2i(2, 2)
	var seconde: Vector2i = premiere
	var ecart := -1.0
	for pate: Vector2i in frontieres:
		var d := float((pate - premiere).length())
		if d > ecart:
			ecart = d
			seconde = pate
	_arenes = [centre_pate(premiere), centre_pate(seconde)]
	var pris: Array = [premiere, seconde]

	for g in 3:
		var candidats: Array = par_gang[g].duplicate()
		candidats.shuffle()
		var poses := 0
		for pate: Vector2i in candidats:
			if pate in pris:
				continue
			pris.append(pate)
			# Le garage occupe la tuile d'angle nord-ouest du pâté : colonne et
			# ligne à un pas d'une rue, on y entre sans manœuvrer.
			if poses == 0:
				_garages.append(centre_tuile(pate.x * 4 + 1, pate.y * 4 + 1))
			elif poses == 1:
				# La cabine, à l'angle du carrefour nord-ouest du pâté, décalée
				# du centre : au milieu du carrefour, la première voiture qui
				# tourne l'emporte.
				_cabines.append(centre_tuile(pate.x * 4, pate.y * 4) + Vector2(PAS, PAS) * 0.34)
			else:
				repaires.append({"p": centre_pate(pate), "gang": g, "pate": pate})
			poses += 1
			if poses >= 4:
				break

func _est_lieu(pate: Vector2i) -> String:
	var c := centre_pate(pate)
	for a: Vector2 in _arenes:
		if a == c:
			return "arene"
	for r in repaires:
		if Vector2(r["p"]) == c:
			return "repaire"
	return ""

# ------------------------------------------------------------ la bâtisse

func _poser(chemin: String, transformation: Transform3D, couleur: Color = Color.WHITE) -> void:
	if not nappes.has(chemin):
		nappes[chemin] = {"t": [], "c": []}
	nappes[chemin]["t"].append(transformation)
	nappes[chemin]["c"].append(couleur)

func _tuile_ville(nom: String, colonne: int, ligne: int, rotation: float, couleur: Color,
		elevation: float = 1.0) -> void:
	var base := Basis(Vector3.UP, rotation).scaled(Vector3(TUILE, TUILE * elevation, TUILE))
	_poser(VILLE + nom + ".glb", Transform3D(base, Decor.vers3d(centre_tuile(colonne, ligne))), couleur)

## Un bâtiment d'un kit, posé au centre d'une tuile (ou entre deux, pour les
## larges). Le sol vient à part : ces kits n'ont pas de dalle, contrairement
## au kit de ville.
func _batiment(kit: int, nom: String, position: Vector2, rotation: float, echelle_y: float = -1.0) -> void:
	var fiche: Dictionary = KITS[kit]
	var xz := float(fiche["xz"])
	var y: float = xz * (float(fiche["y"]) if echelle_y < 0.0 else echelle_y)
	var base := Basis(Vector3.UP, rotation).scaled(Vector3(xz, y, xz))
	_poser(String(fiche["dossier"]) + nom + ".glb", Transform3D(base, Decor.vers3d(position)))

func _teinte_territoire(gang: int, force: float) -> Color:
	if gang < 0:
		return Color.WHITE
	return Color.WHITE.lerp(GANGS[gang]["couleur"], force)

func _batir() -> void:
	nappes.clear()
	stationnements.clear()

	for colonne in range(-CEINTURE, COLONNES + CEINTURE):
		for ligne in range(-CEINTURE, LIGNES + CEINTURE):
			var dedans := colonne >= 0 and colonne < COLONNES and ligne >= 0 and ligne < LIGNES
			if not dedans:
				# La ceinture : de l'herbe et des bosquets. Ils ferment
				# l'horizon sans qu'on ait à poser un mur.
				var t := _graine.randf()
				var nom := "grass" if t < 0.62 else ("grass-trees" if t < 0.88 else "grass-trees-tall")
				_tuile_ville(nom, colonne, ligne, 0.0, Color.WHITE)
				if t >= 0.62:
					_marquer(colonne, ligne)
				continue

			var pate := pate_de(colonne, ligne)
			if pate.x < 0:
				_rue(colonne, ligne)
				continue
			_tuile_de_pate(colonne, ligne, pate)

func _rue(colonne: int, ligne: int) -> void:
	# La rue prend une pointe de la couleur du territoire qu'elle traverse :
	# pas assez pour changer le bitume, assez pour lire la frontière au sol.
	var gang := territoire_du_pate(pate_de(colonne + 1, ligne + 1))
	if gang < 0:
		gang = territoire_du_pate(pate_de(colonne - 1, ligne - 1))
	var teinte := _teinte_territoire(gang, 0.10)
	if est_voie(colonne) and est_voie(ligne):
		_tuile_ville("road-intersection", colonne, ligne, 0.0, teinte)
	elif est_voie(colonne):
		# La tuile de route droite est orientée selon Z, donc selon l'axe Y
		# du jeu : une avenue verticale se pose sans rotation.
		_tuile_ville("road-straight-lightposts" if posmod(ligne, 3) == 1 else "road-straight",
			colonne, ligne, 0.0, teinte)
	else:
		_tuile_ville("road-straight-lightposts" if posmod(colonne, 3) == 1 else "road-straight",
			colonne, ligne, PI * 0.5, teinte)

func _tuile_de_pate(colonne: int, ligne: int, pate: Vector2i) -> void:
	var quartier := quartier_du_pate(pate)
	var gang := territoire_du_pate(pate)
	var lieu := _est_lieu(pate)
	var centre_c := pate.x * 4 + 2
	var centre_l := pate.y * 4 + 2
	var au_milieu := colonne == centre_c and ligne == centre_l
	var sol := _teinte_territoire(gang, 0.16)
	var rotation := PI * 0.5 * float(_graine.randi_range(0, 3))

	# Les lieux d'abord : ils ont leur propre plan.
	if lieu == "arene":
		# L'arène est une esplanade : pas de mur, on y entre lancé et on en
		# ressort de même. Les pièges se posent tout seuls quand quatre
		# voitures s'y croisent.
		_tuile_ville("pavement", colonne, ligne, 0.0, sol)
		return
	if lieu == "repaire":
		if au_milieu:
			_tuile_ville("pavement", colonne, ligne, 0.0, _teinte_territoire(gang, 0.45))
			return
		# Autour du repaire : de la dalle et des voitures du gang — un squat,
		# pas une rue.
		if _graine.randf() < 0.45:
			_tuile_ville("pavement", colonne, ligne, 0.0, sol)
			_stationner(colonne, ligne, pate, quartier, gang, 0.0)
			return
	if Vector2(centre_tuile(colonne, ligne)) in _garages:
		# Un garage se traverse : c'est la seule façade dans laquelle on
		# entre. Le maillage reste, la collision part.
		_tuile_ville("building-garage", colonne, ligne, rotation, Color.WHITE, 0.5)
		return

	var t := _graine.randf()
	match quartier:
		PARC:
			if au_milieu:
				_tuile_ville("pavement-fountain", colonne, ligne, 0.0, sol)
				_marquer(colonne, ligne)
			elif t < 0.55:
				_tuile_ville("grass-trees" if t < 0.35 else "grass-trees-tall", colonne, ligne, rotation, sol)
				_marquer(colonne, ligne)
			else:
				_tuile_ville("grass", colonne, ligne, 0.0, sol)
		CENTRE, COMMERCE:
			if t < 0.70:
				_tuile_ville("pavement", colonne, ligne, 0.0, sol)
				var fiche: Dictionary = KITS[COMMERCE]
				var tour := quartier == CENTRE and _graine.randf() < 0.42
				var liste: Array = fiche["tours"] if tour else fiche["immeubles"]
				_batiment(COMMERCE, String(liste[_graine.randi_range(0, liste.size() - 1)]),
					centre_tuile(colonne, ligne), rotation, 0.4 if tour else -1.0)
				_marquer(colonne, ligne)
			elif t < 0.76:
				_tuile_ville("pavement-fountain", colonne, ligne, 0.0, sol)
				_marquer(colonne, ligne)
			else:
				_tuile_ville("pavement", colonne, ligne, 0.0, sol)
			_stationner(colonne, ligne, pate, quartier, gang, 0.42)
		INDUSTRIE:
			var fiche_i: Dictionary = KITS[INDUSTRIE]
			if t < 0.50:
				_tuile_ville("pavement", colonne, ligne, 0.0, sol)
				var liste_i: Array = fiche_i["immeubles"]
				_batiment(INDUSTRIE, String(liste_i[_graine.randi_range(0, liste_i.size() - 1)]),
					centre_tuile(colonne, ligne), rotation)
				_marquer(colonne, ligne)
			elif t < 0.70:
				_tuile_ville("pavement", colonne, ligne, 0.0, sol)
				var liste_d: Array = fiche_i["details"]
				_batiment(INDUSTRIE, String(liste_d[_graine.randi_range(0, liste_d.size() - 1)]),
					centre_tuile(colonne, ligne), rotation)
				_marquer(colonne, ligne)
			elif t < 0.82:
				_tuile_ville("grass", colonne, ligne, 0.0, sol)
			else:
				_tuile_ville("pavement", colonne, ligne, 0.0, sol)
			_stationner(colonne, ligne, pate, quartier, gang, 0.30)
		BANLIEUE:
			var fiche_b: Dictionary = KITS[BANLIEUE]
			if t < 0.56:
				_tuile_ville("grass", colonne, ligne, 0.0, sol)
				var liste_b: Array = fiche_b["immeubles"]
				_batiment(BANLIEUE, String(liste_b[_graine.randi_range(0, liste_b.size() - 1)]),
					centre_tuile(colonne, ligne), rotation)
				_marquer(colonne, ligne)
			elif t < 0.80:
				_tuile_ville("grass", colonne, ligne, 0.0, sol)
				var arbres: Array = fiche_b["arbres"]
				for i in _graine.randi_range(2, 4):
					var ou := centre_tuile(colonne, ligne) + Vector2(
						_graine.randf_range(-40.0, 40.0), _graine.randf_range(-40.0, 40.0))
					_batiment(BANLIEUE, String(arbres[_graine.randi_range(0, arbres.size() - 1)]),
						ou, _graine.randf() * TAU, 1.0)
				_marquer(colonne, ligne)
			else:
				_tuile_ville("grass", colonne, ligne, 0.0, sol)
			_stationner(colonne, ligne, pate, quartier, gang, 0.34)

## Une place de stationnement le long de la rue voisine, si la tuile en borde
## une. La voiture dort SUR la chaussée, contre le trottoir, dans le sens de la
## rue — c'est ce qui fait qu'une avenue a l'air habitée avant qu'on y croise
## quelqu'un. `chance` à zéro pose la place sans tirage (les repaires).
func _stationner(colonne: int, ligne: int, pate: Vector2i, quartier: int, gang: int, chance: float) -> void:
	var cotes: Array = []
	if colonne == pate.x * 4 + 1: cotes.append(Vector2(-1, 0))
	if colonne == pate.x * 4 + 3: cotes.append(Vector2(1, 0))
	if ligne == pate.y * 4 + 1: cotes.append(Vector2(0, -1))
	if ligne == pate.y * 4 + 3: cotes.append(Vector2(0, 1))
	for cote: Vector2 in cotes:
		if chance > 0.0 and _graine.randf() > chance:
			continue
		var p: Vector2 = centre_tuile(colonne, ligne) + cote * (PAS * 0.5 + 24.0)
		# Le long de la rue : perpendiculaire au côté par lequel on l'a atteinte.
		var direction := Vector2(-cote.y, cote.x)
		if _graine.randf() < 0.5:
			direction = -direction
		stationnements.append({"p": p, "a": direction.angle(), "quartier": quartier, "territoire": gang})

func _marquer(colonne: int, ligne: int) -> void:
	var indice := _indice(colonne, ligne)
	if indice >= 0:
		_bloc[indice] = 1

func _indice(colonne: int, ligne: int) -> int:
	var c := colonne + CEINTURE
	var l := ligne + CEINTURE
	if c < 0 or c >= _largeur or l < 0 or l >= _hauteur:
		return -1
	return l * _largeur + c

# ------------------------------------------------------------ collisions

func bloquee(colonne: int, ligne: int) -> bool:
	var indice := _indice(colonne, ligne)
	# Hors de la carte : rien ne bloque. La friche se garde autrement, par le
	# rappel vers le centre — un mur invisible passe pour un défaut.
	return indice >= 0 and _bloc[indice] == 1

func rectangle_tuile(colonne: int, ligne: int) -> Rect2:
	# Un peu plus petit que la tuile : on doit pouvoir raser un immeuble sans
	# rester collé au trottoir.
	var cote := PAS - RETRAIT
	return Rect2(centre_tuile(colonne, ligne) - Vector2(cote, cote) * 0.5, Vector2(cote, cote))

## Les tuiles susceptibles de toucher un cercle. Au plus quatre : c'est ce qui
## remplace le balayage de mille rectangles.
func _tuiles_autour(point: Vector2, rayon: float) -> Array:
	var c0 := int(floor((point.x - rayon) / PAS))
	var c1 := int(floor((point.x + rayon) / PAS))
	var l0 := int(floor((point.y - rayon) / PAS))
	var l1 := int(floor((point.y + rayon) / PAS))
	var liste: Array = []
	for c in range(c0, c1 + 1):
		for l in range(l0, l1 + 1):
			if bloquee(c, l):
				liste.append(Vector2i(c, l))
	return liste

func dans_un_batiment(point: Vector2, marge: float = 0.0) -> bool:
	for t: Vector2i in _tuiles_autour(point, marge):
		if rectangle_tuile(t.x, t.y).grow(marge).has_point(point):
			return true
	return false

## Repousse un point hors des murs par le plus petit chevauchement.
## Renvoie [point corrigé, y a-t-il eu correction].
func degager(point: Vector2, rayon: float) -> Array:
	var corrige := point
	var touche := false
	for t: Vector2i in _tuiles_autour(point, rayon):
		var etendu := rectangle_tuile(t.x, t.y).grow(rayon)
		if not etendu.has_point(corrige):
			continue
		var gauche := corrige.x - etendu.position.x
		var droite := etendu.end.x - corrige.x
		var haut := corrige.y - etendu.position.y
		var bas := etendu.end.y - corrige.y
		var minimum: float = min(min(gauche, droite), min(haut, bas))
		if minimum == gauche: corrige.x = etendu.position.x
		elif minimum == droite: corrige.x = etendu.end.x
		elif minimum == haut: corrige.y = etendu.position.y
		else: corrige.y = etendu.end.y
		touche = true
	return [corrige, touche]

# ------------------------------------------------------------ les rues

## Position sur la voie la plus proche, dans l'axe demandé. Sert à remettre une
## voiture d'IA sur sa file après un choc.
func voie_proche(valeur: float) -> float:
	var indice := int(round(valeur / PAS / 4.0)) * 4
	return (float(indice) + 0.5) * PAS

func sur_une_rue(point: Vector2, tolerance: float = 0.0) -> bool:
	var colonne := int(floor(point.x / PAS))
	var ligne := int(floor(point.y / PAS))
	if est_voie(colonne) or est_voie(ligne):
		return true
	if tolerance <= 0.0:
		return false
	return abs(point.x - voie_proche(point.x)) < tolerance or abs(point.y - voie_proche(point.y)) < tolerance

## Le carrefour le plus proche : la maille des rues, arrondie.
func carrefour_proche(point: Vector2) -> Vector2:
	return Vector2(voie_proche(point.x), voie_proche(point.y))

## Un point libre dans une rue, autour d'un lieu. Quatorze essais puis on
## abandonne : insister davantage coûterait plus cher que le défaut à éviter.
func point_de_rue(rng: RandomNumberGenerator, autour: Vector2,
		rayon_min: float, rayon_max: float) -> Vector2:
	for essai in 14:
		var p: Vector2 = autour + Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(rayon_min, rayon_max)
		p.x = clamp(p.x, -banlieue() * 0.5, etendue().x + banlieue() * 0.5)
		p.y = clamp(p.y, -banlieue() * 0.5, etendue().y + banlieue() * 0.5)
		if not dans_un_batiment(p, 40.0):
			return p
	return autour + Vector2.RIGHT.rotated(rng.randf() * TAU) * rayon_min

## Un point de la chaussée, pour faire naître une voiture qui roule.
func point_de_chaussee(rng: RandomNumberGenerator, autour: Vector2,
		rayon_min: float, rayon_max: float) -> Dictionary:
	var p := point_de_rue(rng, autour, rayon_min, rayon_max)
	var carrefour := carrefour_proche(p)
	# On la pose sur l'axe le plus proche, et elle roulera le long de cet axe.
	var horizontal: bool = abs(p.y - carrefour.y) < abs(p.x - carrefour.x)
	var sens: float = 1.0 if rng.randf() < 0.5 else -1.0
	if horizontal:
		return {"p": Vector2(p.x, carrefour.y), "d": Vector2(sens, 0.0)}
	return {"p": Vector2(carrefour.x, p.y), "d": Vector2(0.0, sens)}

# ------------------------------------------------------------ les lieux

## À qui appartient ce coin de ville : le gang du pâté le plus proche. Sur une
## rue, on regarde le pâté d'à côté — une rue frontière appartient à qui la
## borde au sud-est, ce qui est arbitraire mais identique chez tout le monde.
func territoire(point: Vector2) -> int:
	return territoire_du_pate(_pate_proche(point))

func quartier(point: Vector2) -> int:
	return quartier_du_pate(_pate_proche(point))

func nom_du_quartier(point: Vector2) -> String:
	return String(NOMS_QUARTIERS[clamp(quartier(point), 0, NOMS_QUARTIERS.size() - 1)])

func _pate_proche(point: Vector2) -> Vector2i:
	var colonne: int = clamp(int(floor(point.x / PAS)), 0, COLONNES - 1)
	var ligne: int = clamp(int(floor(point.y / PAS)), 0, LIGNES - 1)
	var pate := pate_de(colonne, ligne)
	if pate.x >= 0:
		return pate
	# Sur une rue : le pâté au sud-est, sinon au nord-ouest.
	pate = pate_de(colonne + 1, ligne + 1)
	if pate.x >= 0:
		return pate
	return pate_de(max(1, colonne - 1), max(1, ligne - 1))

func nom_du_gang(indice: int) -> String:
	return String(GANGS[posmod(indice, GANGS.size())]["nom"])

## « de Le Lierre » ne se dit pas. Les noms de gang portent leur article : il
## faut contracter avant de les coller dans une phrase.
func du_gang(indice: int) -> String:
	var nom := nom_du_gang(indice)
	if nom.begins_with("Les "):
		return "des " + nom.substr(4)
	if nom.begins_with("Le "):
		return "du " + nom.substr(3)
	return "de " + nom

func couleur_du_gang(indice: int) -> Color:
	return GANGS[posmod(indice, GANGS.size())]["couleur"]

func garages() -> Array:
	return _garages

func cabines() -> Array:
	return _cabines

func arenes() -> Array:
	return _arenes

## Dans quelle arène se trouve ce point, ou -1. C'est cette réponse, et elle
## seule, qui autorise un joueur à en blesser un autre.
func arene_de(point: Vector2) -> int:
	var i := 0
	for centre_arene: Vector2 in _arenes:
		if point.distance_to(centre_arene) <= RAYON_ARENE:
			return i
		i += 1
	return -1

func garage_de(point: Vector2) -> int:
	var i := 0
	for centre_garage: Vector2 in _garages:
		if point.distance_to(centre_garage) <= RAYON_GARAGE:
			return i
		i += 1
	return -1

func cabine_de(point: Vector2) -> int:
	var i := 0
	for centre_cabine: Vector2 in _cabines:
		if point.distance_to(centre_cabine) <= RAYON_CABINE:
			return i
		i += 1
	return -1

## Départs répartis sur un cercle au centre, dans la rue : quatre voitures au
## même endroit se poussent mutuellement dans un mur avant même le décompte.
func depart(place: int, rng: RandomNumberGenerator) -> Dictionary:
	var angle := TAU * float(posmod(place, 4)) / 4.0
	var p := point_de_rue(rng, centre() + Vector2.RIGHT.rotated(angle) * 380.0, 0.0, 220.0)
	return {"p": p, "a": angle + PI}
