class_name PlanV2
extends PlanVille
## LA VILLE V2, VUE PAR LE JEU.
##
## Le jeu — circulation, collisions, radar, gangs, planques, missions — pose
## ses questions à `PlanVille`. Cette classe y répond depuis un `Ville2` (le
## modèle du cahier : terrain, routes, lots, objets, lieux), exactement comme
## `PlanDessine` le faisait depuis le dessin de Pikstown. Rien du jeu n'est
## réécrit : `dans_un_batiment`, `degager`, `point_de_rue`, `lieux_autour`…
## restent ceux de `PlanVille`, qui ne lisent que `tuile()`.
##
## ⚠ LES DEUX ÉCHELLES. Le jeu compte en PIXELS et en TUILES de cent pixels
## (dix unités 3D) ; la ville compte en CASES de vingt unités. Une case = deux
## tuiles, une rue d'une case = deux tuiles de large, la largeur des rues de
## `PlanVille` — c'est ce qui garde le moteur de circulation tel quel. Et un
## lot v2 se pose sur la grille des DEMI-cases : une demi-case = une tuile,
## donc un lot bloque des tuiles entières, sans fente ni débord.

const CASE_PX := 200.0                 ## une case, en pixels de jeu (2 tuiles)
const TUILES_PAR_CASE := 2
const CHEMIN_PAR_DEFAUT := "res://cartes/temoin-centre.json"

## Les genres de quartier du cahier, traduits en districts du jeu.
const DISTRICT_DE := {
	Ville2.Q_CENTRE: CENTRE, Ville2.Q_PLAGE: PORT, Ville2.Q_PORT: PORT,
	Ville2.Q_PAVILLONS: BANLIEUE, Ville2.Q_INDUSTRIE: INDUSTRIE,
	Ville2.Q_VIEILLE_VILLE: VIEUX, Ville2.Q_CHAUD: COMMERCE, Ville2.Q_CAMPUS: RESIDENCES,
	Ville2.Q_BIDONVILLE: INDUSTRIE, Ville2.Q_PARC: PARC,
}

## Les objets que les voitures cognent (cahier § 7) : un petit carré bloqué,
## en pixels, autour du pied. Les autres (bancs, buissons, poubelles) se
## traversent pour l'instant.
const OBSTACLES := {"lampadaire": 14.0, "lampadaire_double": 14.0, "lampadaire_parc": 12.0,
	"feu": 12.0, "arbre": 18.0, "arbre_oak": 16.0, "arbre_rond": 16.0, "arbre_petit": 14.0,
	"palmier": 16.0, "monument": 22.0, "res://modeles/ville/pavement-fountain.glb": 80.0}

var ville: Ville2
var carte: CarteVille
var cases_x := 0
var cases_y := 0
var _tuiles: Dictionary = {}          ## indice de tuile -> fiche
var _lieux_par_secteur: Dictionary = {}
var _lieux_prets := false
var _coeur_d := Vector2.ZERO
var _obstacles_par_case: Dictionary = {}   ## Vector2i -> [Rect2] en pixels

func _init(code_de_manche: String, chemin: String = CHEMIN_PAR_DEFAUT) -> void:
	super(code_de_manche)
	ville = Ville2.charger(chemin)
	carte = ville.carte
	cases_x = ville.taille.x
	cases_y = ville.taille.y
	_classer_obstacles()

## `PlanVille` trace ses boulevards libres dès la construction ; ici il n'y en
## a pas — tout est case.
func _tracer_les_voies_libres() -> void:
	pass

# ------------------------------------------------------------ dimensions

func colonnes() -> int:
	return cases_x * TUILES_PAR_CASE

func lignes() -> int:
	return cases_y * TUILES_PAR_CASE

func etendue() -> Vector2:
	return Vector2(colonnes(), lignes()) * PAS

func banlieue() -> float:
	return 3.0 * PAS

static func case_de_tuile(colonne: int, ligne: int) -> Vector2i:
	return Vector2i(floori(float(colonne) / TUILES_PAR_CASE), floori(float(ligne) / TUILES_PAR_CASE))

func case_de_point(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CASE_PX), floori(p.y / CASE_PX))

func centre_case(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * CASE_PX

# ------------------------------------------------------------ l'eau et le relief

func eau(colonne: int, ligne: int) -> bool:
	return not carte.terre(case_de_tuile(colonne, ligne))

func sur_le_rail(colonne: int, ligne: int) -> bool:
	var c := case_de_tuile(colonne, ligne)
	for r in ville.rail:
		for rc in Ville2.cases_de_route(r):
			if rc == c: return true
	return false

## Le premier point de voie, pour le train du jeu ; hors carte s'il n'y en a pas.
func rail() -> Vector3:
	if ville.rail.is_empty():
		return Vector3(0.0, 1.0, -1.0e9)
	var p: Vector2i = ville.rail[0]["points"][0]
	return Vector3((float(p.x) + 0.5) * CASE_PX, 1.0, (float(p.y) + 0.5) * CASE_PX)

## L'altitude du sol en un point, en unités 3D. Sur une rampe, on interpole
## entre le bas et le haut de la case dans le sens de la montée.
func hauteur_en(p: Vector2) -> float:
	var c := case_de_point(p)
	if not carte.terre(c):
		return Quartiers.NIVEAU_MER
	var y := carte.hauteur(c)
	if not carte.route(c):
		return y
	for d in CarteVille.COTES:
		var v: Vector2i = c + d
		if not carte.route(v): continue
		var ecart := carte.palier(v) - carte.palier(c)
		if ecart <= 0 or ecart > 2: continue
		var t: float = ((p.x / CASE_PX - float(c.x)) if d.x != 0 else (p.y / CASE_PX - float(c.y)))
		if d.x < 0 or d.y < 0: t = 1.0 - t
		return y + float(ecart) * CarteVille.PALIER * clampf(t, 0.0, 1.0)
	return y

# ------------------------------------------------------------ districts et gangs

func district_de_case(c: Vector2i) -> int:
	if not ville.dedans(c): return EAU
	if not ville.terre(c): return EAU
	var g := ville.genre_du_quartier(c)
	return int(DISTRICT_DE.get(g, PARC))

func gang_de_case(c: Vector2i) -> int:
	var q := ville.quartier_en(c)
	if q < 0 or q >= ville.quartiers.size(): return -1
	return int(ville.quartiers[q].get("gang", -1))

func quartier(point: Vector2) -> int:
	return district_de_case(case_de_point(point))

func territoire(point: Vector2) -> int:
	return gang_de_case(case_de_point(point))

func nom_du_quartier(point: Vector2) -> String:
	var q := ville.quartier_en(case_de_point(point))
	if q >= 0 and q < ville.quartiers.size():
		return String(ville.quartiers[q].get("nom", ""))
	return NOMS_QUARTIERS[quartier(point)]

## Un « pâté » est une case ici.
func quartier_du_pate(pate: Vector2i) -> int:
	return district_de_case(pate)

func territoire_du_pate(pate: Vector2i) -> int:
	return gang_de_case(pate)

func _pate_proche_de(colonne: int, ligne: int) -> Vector2i:
	return case_de_tuile(colonne, ligne)

func _pate_proche(point: Vector2) -> Vector2i:
	return case_de_point(point)

# ------------------------------------------------------------ le centre

func centre() -> Vector2:
	return etendue() * 0.5

## Le coeur : la case de rue la plus proche du centre géométrique. C'est
## autour de lui que naissent les joueurs.
func coeur() -> Vector2:
	if _coeur_d != Vector2.ZERO:
		return _coeur_d
	var c0 := Vector2i(cases_x / 2, cases_y / 2)
	_coeur_d = centre()
	var meilleur := 1.0e18
	for j in cases_y:
		for i in cases_x:
			var c := Vector2i(i, j)
			if not carte.route(c) or carte.case_prise(c): continue
			var d := Vector2(c - c0).length_squared()
			if d < meilleur:
				meilleur = d
				_coeur_d = centre_case(c)
	return _coeur_d

func un_pont() -> Vector2:
	for o in ville.ouvrages:
		if String(o["t"]) == "road-bridge":
			return centre_case(Vector2i(int(o["i"]), int(o["j"])))
	return coeur()

func meme_terre(a: Vector2, b: Vector2) -> bool:
	var pas := int(ceilf(a.distance_to(b) / (PAS * 0.5)))
	for i in range(1, maxi(2, pas)):
		var p: Vector2 = a.lerp(b, float(i) / float(pas))
		if not carte.terre(case_de_point(p)):
			return false
	return true

# ------------------------------------------------------------ les tuiles

## Les obstacles, rangés par case, une fois pour toutes.
func _classer_obstacles() -> void:
	for o in ville.objets:
		var m := String(o["m"])
		if not OBSTACLES.has(m): continue
		var demi: float = float(OBSTACLES[m]) * 0.5
		var p := Vector2(float(o["x"]), float(o["z"])) / Decor.ECHELLE
		var r := Rect2(p - Vector2(demi, demi), Vector2(demi, demi) * 2.0)
		var c := case_de_point(p)
		if not _obstacles_par_case.has(c): _obstacles_par_case[c] = []
		(_obstacles_par_case[c] as Array).append(r)

## La fiche d'une tuile : c'est TOUT ce que la physique lit. Une tuile sous un
## lot est bloquée en entier — le lot est sur la grille des tuiles ; une tuile
## de rue est de la chaussée ; le reste est de l'esplanade (le trottoir du
## kit), avec ses obstacles.
func tuile(colonne: int, ligne: int) -> Dictionary:
	if colonne < 0 or ligne < 0 or colonne >= colonnes() or ligne >= lignes():
		return _mer(colonne, ligne)
	var indice := ligne * colonnes() + colonne
	if _tuiles.has(indice):
		return _tuiles[indice]
	var c := case_de_tuile(colonne, ligne)
	var f: Dictionary
	if not carte.terre(c):
		f = _mer(colonne, ligne)
	elif carte.route(c) or carte.case_prise(c) and carte.piece_sur(c).get("r", false):
		f = _vierge(colonne, ligne, S_ROUTE)
	else:
		var lot := _lot_de_tuile(colonne, ligne)
		if lot >= 0:
			f = _vierge(colonne, ligne, S_BETON)
			_bloquer(f, Rect2(Vector2(colonne, ligne) * PAS, Vector2(PAS, PAS)))
		else:
			var sol := S_ESPLANADE
			match district_de_case(c):
				PARC: sol = S_HERBE
				BANLIEUE: sol = S_HERBE
				INDUSTRIE: sol = S_TERRE
			f = _vierge(colonne, ligne, sol)
			var t := Rect2(Vector2(colonne, ligne) * PAS, Vector2(PAS, PAS))
			for r in _obstacles_par_case.get(c, []):
				if (r as Rect2).intersects(t):
					_bloquer(f, (r as Rect2).intersection(t))
	_tuiles[indice] = f
	return f

## Le lot qui couvre une tuile : les lots sont en demi-cases, une demi-case
## est une tuile.
func _lot_de_tuile(colonne: int, ligne: int) -> int:
	var c := case_de_tuile(colonne, ligne)
	var k := ville.lot_sur(c)
	if k < 0: return -1
	var l: Dictionary = ville.lots[k]
	if colonne >= int(l["x"]) and colonne < int(l["x"]) + int(l["w"]) \
			and ligne >= int(l["y"]) and ligne < int(l["y"]) + int(l["h"]):
		return k
	# La case est partagée entre deux lots : on cherche parmi tous.
	for i in ville.lots.size():
		var m: Dictionary = ville.lots[i]
		if colonne >= int(m["x"]) and colonne < int(m["x"]) + int(m["w"]) \
				and ligne >= int(m["y"]) and ligne < int(m["y"]) + int(m["h"]):
			return i
	return -1

func fiches_en_cache() -> int:
	return _tuiles.size()

## Ni voitures dormantes ni immeubles cassables pour l'instant : les voitures
## garées sont du décor (elles viendront), les immeubles ne cassent pas (§ 7).
func dormante(_id: int) -> Dictionary:
	return {}

func dormantes_autour(_point: Vector2, _rayon: float) -> Array:
	return []

func immeuble_a(_point: Vector2, _marge: float = 8.0) -> Dictionary:
	return {}

func eventrer(_id: int) -> void:
	pass

# ------------------------------------------------------------ la voirie

func voie_libre(_colonne: int, _ligne: int) -> Dictionary:
	return {}

func voie_libre_en(_point: Vector2) -> Dictionary:
	return {}

func sorties_de_la_place(_e: int) -> Array:
	return []

func lignes_libres() -> PackedVector4Array:
	return PackedVector4Array()

func origines_libres() -> PackedVector4Array:
	return PackedVector4Array()

func anneaux_libres() -> PackedVector4Array:
	return PackedVector4Array()

func etoiles_libres() -> PackedVector4Array:
	return PackedVector4Array()

func place_etoile() -> Vector2:
	return coeur()

func sur_la_chaussee(point: Vector2) -> bool:
	var c := case_de_point(point)
	if not carte.route(c): return false
	var f: Array = carte.tuile(c)
	var selon_x: bool = int(f[1]) % 2 == 0
	var centre_c := centre_case(c)
	var ecart: float = absf(point.y - centre_c.y) if selon_x else absf(point.x - centre_c.x)
	return ecart < CASE_PX * 0.30 or carte.masque(c) not in [5, 10]

func sur_une_rue(point: Vector2, tolerance: float = 0.0) -> bool:
	var c := case_de_point(point)
	if carte.route(c): return true
	if tolerance <= 0.0: return false
	for d in CarteVille.COTES:
		if carte.route(c + d):
			var bord := centre_case(c + d)
			if absf(point.x - bord.x) <= CASE_PX * 0.5 + tolerance \
					and absf(point.y - bord.y) <= CASE_PX * 0.5 + tolerance:
				return true
	return false

## L'axe de la rue et le prochain carrefour, le long de la rue où l'on est.
func carrefour_proche(point: Vector2) -> Vector2:
	var c := case_de_point(point)
	if not carte.route(c):
		var meilleur := c
		var dist := 1.0e18
		for dj in range(-2, 3):
			for di in range(-2, 3):
				var v := c + Vector2i(di, dj)
				if not carte.route(v): continue
				var d := centre_case(v).distance_squared_to(point)
				if d < dist:
					dist = d
					meilleur = v
		c = meilleur
		if not carte.route(c):
			return point
	var m := carte.masque(c)
	if m != 5 and m != 10:
		return centre_case(c)
	var axe: Vector2i = CarteVille.E if m == 10 else CarteVille.S
	var proche := centre_case(c)
	var dist := 1.0e18
	for sens in [1, -1]:
		var v := c
		for k in range(1, 40):
			v += axe * sens
			if not carte.route(v): break
			var mv := carte.masque(v)
			if mv != 5 and mv != 10:
				var d := centre_case(v).distance_squared_to(point)
				if d < dist:
					dist = d
					proche = centre_case(v)
				break
	if m == 10:
		return Vector2(proche.x, centre_case(c).y)
	return Vector2(centre_case(c).x, proche.y)

func voie_proche(valeur: float) -> float:
	return (floorf(valeur / CASE_PX) + 0.5) * CASE_PX

func rue_fermee_v(_k: int, _py: int) -> bool:
	return false

func rue_fermee_h(_kl: int, _px: int) -> bool:
	return false

# ------------------------------------------------------------ le départ

func depart(place: int, rng: RandomNumberGenerator) -> Dictionary:
	var angle := TAU * float(posmod(place, 4)) / 4.0
	var ancre := coeur()
	var p := ancre
	for essai in 12:
		var vers := ancre + Vector2.RIGHT.rotated(angle) * 420.0
		p = point_de_rue(rng, vers, 0.0, 240.0)
		if meme_terre(ancre, p):
			break
		angle += PI * 0.25
	return {"p": p, "a": angle + PI}

# ------------------------------------------------------------ les lieux

const GENRES_LIEUX := ["garages", "cabines", "arenes", "repaires", "hopitaux", "planques", "superettes"]
const PLURIELS := {"garage": "garages", "cabine": "cabines", "arene": "arenes", "repaire": "repaires",
	"hopital": "hopitaux", "planque": "planques", "superette": "superettes"}

## Les lieux viennent du modèle (`ville.lieux`, posés par le générateur ou
## l'éditeur), rangés par secteur pour que `lieux_autour` reste local.
func _preparer_lieux() -> void:
	if _lieux_prets: return
	_lieux_prets = true
	var id := 0
	for l in ville.lieux:
		# Le modèle nomme au singulier, le jeu au pluriel.
		var pluriel := String(PLURIELS.get(String(l["genre"]), ""))
		if pluriel == "": continue
		var p := Vector2(float(l["x"]), float(l["z"])) / Decor.ECHELLE
		var lieu := {"p": p, "id": id, "pate": case_de_point(p)}
		id += 1
		if pluriel == "planques":
			lieu["prix"] = int(l.get("prix", PRIX_PLANQUE[posmod(id, PRIX_PLANQUE.size())]))
		if pluriel == "repaires":
			lieu["gang"] = int(l.get("gang", -1))
		var s := _secteur_de(p)
		if not _lieux_par_secteur.has(s):
			_lieux_par_secteur[s] = _lieux_vides()
		_lieux_par_secteur[s][pluriel].append(lieu)

func _lieux_vides() -> Dictionary:
	var d := {}
	for g in GENRES_LIEUX: d[g] = []
	return d

func _lieux_du_secteur(secteur: Vector2i) -> Dictionary:
	_preparer_lieux()
	return _lieux_par_secteur.get(secteur, _lieux_vides())

func lieux_autour(point: Vector2, rayon: float) -> Dictionary:
	var resultat := _lieux_vides()
	var s0 := _secteur_de(point - Vector2(rayon, rayon))
	var s1 := _secteur_de(point + Vector2(rayon, rayon))
	for sy in range(s0.y, s1.y + 1):
		for sx in range(s0.x, s1.x + 1):
			var fiche := _lieux_du_secteur(Vector2i(sx, sy))
			for genre in resultat:
				for lieu in fiche[genre]:
					if Vector2(lieu["p"]).distance_to(point) <= rayon:
						resultat[genre].append(lieu)
	return resultat

# ------------------------------------------------------------ la carte du radar

## Un pixel par tuile : la case donne quatre pixels de la même couleur.
func peindre_pate(image: Image, indice: int) -> void:
	var i := posmod(indice, cases_x)
	var j := indice / cases_x
	if j >= cases_y: return
	var c := Vector2i(i, j)
	var couleur: Color
	if not carte.terre(c):
		couleur = CARTE_EAU
	elif carte.route(c):
		couleur = CARTE_AVENUE if ville.genre_de_route(c) == Ville2.R_AVENUE else CARTE_RUE
	else:
		var d := district_de_case(c)
		couleur = COULEURS_CARTE.get(d, COULEURS_CARTE[PARC])
		var g := gang_de_case(c)
		if g >= 0:
			couleur = couleur.lerp(couleur_du_gang(g), 0.25)
		if ville.lot_sur(c) < 0:
			couleur = couleur.darkened(0.15)
	for dj in TUILES_PAR_CASE:
		for di in TUILES_PAR_CASE:
			var x := i * TUILES_PAR_CASE + di
			var y := j * TUILES_PAR_CASE + dj
			if x < image.get_width() and y < image.get_height():
				image.set_pixel(x, y, couleur)

func nombre_de_pates() -> int:
	return cases_x * cases_y
