class_name PlanVille
extends RefCounted
## Le plan de la ville de CARNAGE, déduit du CODE de la manche.
##
## Rien de tout ceci ne circule sur le réseau : même code, même ville, chez
## tout le monde et à tout instant. Diffuser un plan de vingt-six par vingt
## tuiles coûterait plusieurs kilo-octets par partie et ajouterait un cas de
## plus pour qui rejoint en retard.
##
## Ce que le plan sait, et que les autres modules lui demandent :
## où sont les murs, où sont les rues, à quel gang appartient un pâté de
## maisons, où l'on repeint une voiture, où le tir ami s'allume.
##
## ⚠ Les collisions ne balayent PAS une liste de rectangles. La ville en
## compte plus de trois cents ; avec quatre-vingts piétons, vingt voitures et
## des projectiles, un balayage linéaire coûtait vingt mille tests par image
## et l'hôte perdait ses trames. Une tuile se déduit d'une position par deux
## divisions : on ne teste jamais plus des quatre tuiles qui touchent le
## cercle.

const TUILE := 14.0                          ## côté d'une tuile, en unités 3D
const PAS := TUILE / Decor.ECHELLE           ## le même, en pixels de jeu
const COLONNES := 26
const LIGNES := 20
const CEINTURE := 3                          ## anneau de verdure autour de la ville
const RETRAIT := 22.0                        ## le mur est un peu en retrait de la tuile

const VILLE := "res://modeles/ville/"
## Le kit de Kenney est clair : cette teinte le refroidit à peine, juste assez
## pour qu'il tienne dans la palette sombre de la maison. Elle MULTIPLIE
## l'atlas de couleurs plutôt que de le remplacer — trop appuyée, elle
## éteindrait les pelouses, les fontaines et le marquage au sol.
const TEINTE_VILLE := Color(0.82, 0.85, 0.92)
const IMMEUBLES := ["building-small-a", "building-small-b", "building-small-c",
	"building-small-d", "building-garage"]

## Trois gangs, trois bandes de ville. La couleur du gang n'est jamais SÉRIE :
## le bleu est à la police, et on ne confond pas celui qui vous verbalise avec
## celui qui vous canarde. Elle n'est pas non plus la seule marque — un membre
## de gang porte un fanion à sa couleur ET le nom de son gang s'affiche dans
## l'état du joueur quand on entre sur son territoire.
const GANGS := [
	{"nom": "Les Braises", "couleur": Palette.CRITIQUE},
	{"nom": "La Fonte", "couleur": Palette.SERIEUX},
	{"nom": "Le Lierre", "couleur": Palette.BON},
]
const BORNES_TERRITOIRE := [9, 18]           ## colonnes de séparation des trois bandes

## Les arènes enjambent une frontière de territoire : elles sont contestées par
## construction, et personne n'y entre « chez lui ».
const ARENES := [Vector2i(10, 6), Vector2i(18, 14)]
const RAYON_ARENE := 200.0

## Garages de peinture : une tuile par territoire, choisie en coin de pâté
## (colonne et ligne à un pas d'une rue) pour qu'on puisse y entrer sans
## manœuvrer. La tuile n'est PAS bloquante : on entre dedans, c'est tout le
## principe.
const GARAGES := [Vector2i(1, 13), Vector2i(13, 1), Vector2i(21, 9)]
const RAYON_GARAGE := 74.0

## Cabines : une par territoire, posée à l'angle d'un carrefour. Décalée du
## centre, sinon toute voiture qui tourne l'emporte.
const CABINES := [Vector2i(4, 4), Vector2i(12, 12), Vector2i(20, 4)]
const RAYON_CABINE := 68.0

var code := ""
var nappes: Dictionary = {}                  ## modèle de tuile -> Array[Transform3D]

var _largeur := COLONNES + CEINTURE * 2
var _hauteur := LIGNES + CEINTURE * 2
var _bloc := PackedByteArray()               ## 1 = la tuile porte un mur

# ------------------------------------------------------------ construction

func _init(code_de_manche: String) -> void:
	code = code_de_manche
	_bloc.resize(_largeur * _hauteur)
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

func est_garage(colonne: int, ligne: int) -> bool:
	return Vector2i(colonne, ligne) in GARAGES

func est_arene(colonne: int, ligne: int) -> bool:
	for a: Vector2i in ARENES:
		if absi(colonne - a.x) <= 1 and absi(ligne - a.y) <= 1:
			return true
	return false

func _batir() -> void:
	var graine := RandomNumberGenerator.new()
	graine.seed = hash(code)
	nappes.clear()

	for colonne in range(-CEINTURE, COLONNES + CEINTURE):
		for ligne in range(-CEINTURE, LIGNES + CEINTURE):
			var dedans := colonne >= 0 and colonne < COLONNES and ligne >= 0 and ligne < LIGNES
			var tuile := ""
			var rotation := 0.0
			var bloque := false

			if not dedans:
				# La ceinture : de l'herbe et des bosquets. Ils ferment
				# l'horizon sans qu'on ait à poser un mur.
				var t := graine.randf()
				tuile = "grass" if t < 0.62 else ("grass-trees" if t < 0.88 else "grass-trees-tall")
				bloque = t >= 0.62
			elif est_garage(colonne, ligne):
				# Un garage se traverse : c'est la seule façade dans laquelle
				# on entre. Le maillage reste, la collision part.
				tuile = "building-garage"
				rotation = PI * 0.5 * float(graine.randi_range(0, 3))
			elif est_arene(colonne, ligne):
				# L'arène est une esplanade : pas de mur, on y entre lancé et
				# on en ressort de même. Les pièges se posent tout seuls quand
				# quatre voitures s'y croisent.
				tuile = "pavement"
			elif est_voie(colonne) and est_voie(ligne):
				tuile = "road-intersection"
			elif est_voie(colonne):
				# La tuile de route droite est orientée selon Z, donc selon
				# l'axe Y du jeu : une avenue verticale se pose sans rotation.
				tuile = "road-straight-lightposts" if posmod(ligne, 3) == 1 else "road-straight"
			elif est_voie(ligne):
				tuile = "road-straight-lightposts" if posmod(colonne, 3) == 1 else "road-straight"
				rotation = PI * 0.5
			else:
				var t2 := graine.randf()
				if t2 < 0.62:
					tuile = String(IMMEUBLES[graine.randi_range(0, IMMEUBLES.size() - 1)])
					rotation = PI * 0.5 * float(graine.randi_range(0, 3))
					bloque = true
				elif t2 < 0.90:
					tuile = "pavement-fountain" if graine.randf() < 0.08 else "pavement"
					bloque = tuile == "pavement-fountain"
				else:
					tuile = "grass-trees"
					bloque = true

			if bloque:
				_marquer(colonne, ligne)

			if not nappes.has(tuile):
				nappes[tuile] = []
			# Les immeubles sont tassés en hauteur : à l'échelle du sol, le
			# kit monte à vingt-cinq unités et on ne voit plus que des toits.
			# Une ville écrasée se survole ; une ville haute se subit.
			var haut := tuile.begins_with("building")
			var elevation: float = TUILE * (0.5 if haut else 1.0)
			var base := Basis(Vector3.UP, rotation).scaled(Vector3(TUILE, elevation, TUILE))
			nappes[tuile].append(Transform3D(base, Decor.vers3d(centre_tuile(colonne, ligne))))

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
## remplace le balayage de trois cents rectangles.
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

## Un point libre dans une rue, autour d'un lieu. Douze essais puis on
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

## À qui appartient ce coin de ville. Trois bandes verticales : une frontière
## se lit à l'œil quand elle suit une avenue, pas quand elle serpente.
func territoire(point: Vector2) -> int:
	var colonne := int(floor(point.x / PAS))
	if colonne < BORNES_TERRITOIRE[0]:
		return 0
	if colonne < BORNES_TERRITOIRE[1]:
		return 1
	return 2

func nom_du_gang(indice: int) -> String:
	return String(GANGS[posmod(indice, GANGS.size())]["nom"])

func couleur_du_gang(indice: int) -> Color:
	return GANGS[posmod(indice, GANGS.size())]["couleur"]

func lieux(liste: Array) -> Array:
	var points: Array = []
	for t: Vector2i in liste:
		points.append(centre_tuile(t.x, t.y))
	return points

func garages() -> Array:
	return lieux(GARAGES)

func cabines() -> Array:
	# Décalée d'un quart de tuile vers l'angle : au centre du carrefour, elle
	# se fait faucher par la première voiture qui tourne.
	var points: Array = []
	for t: Vector2i in CABINES:
		points.append(centre_tuile(t.x, t.y) + Vector2(PAS, PAS) * 0.34)
	return points

func arenes() -> Array:
	return lieux(ARENES)

## Dans quelle arène se trouve ce point, ou -1. C'est cette réponse, et elle
## seule, qui autorise un joueur à en blesser un autre.
func arene_de(point: Vector2) -> int:
	var i := 0
	for centre_arene: Vector2 in arenes():
		if point.distance_to(centre_arene) <= RAYON_ARENE:
			return i
		i += 1
	return -1

func garage_de(point: Vector2) -> int:
	var i := 0
	for centre_garage: Vector2 in garages():
		if point.distance_to(centre_garage) <= RAYON_GARAGE:
			return i
		i += 1
	return -1

func cabine_de(point: Vector2) -> int:
	var i := 0
	for centre_cabine: Vector2 in cabines():
		if point.distance_to(centre_cabine) <= RAYON_CABINE:
			return i
		i += 1
	return -1

## Départs répartis sur un cercle, dans la rue : quatre voitures au même
## endroit se poussent mutuellement dans un mur avant même le décompte.
func depart(place: int, rng: RandomNumberGenerator) -> Dictionary:
	var angle := TAU * float(posmod(place, 4)) / 4.0
	var p := point_de_rue(rng, centre() + Vector2.RIGHT.rotated(angle) * 340.0, 0.0, 220.0)
	return {"p": p, "a": angle + PI}
