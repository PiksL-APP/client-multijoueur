class_name PlanDessine
extends PlanVille
## LA VILLE DESSINÉE, VUE PAR LE JEU.
##
## `PlanVille` est la ville procédurale de Carnage : six cent quatre-vingts
## tuiles sur cinq cent vingt, tirées d'un bruit, une grille de rues à période
## fixe. Tout le jeu — la circulation, les collisions, le radar, les gangs, les
## planques, les missions — lui pose ses questions par cent trente-six
## fonctions. Pikstown, la ville DESSINÉE case par case dans `PlanPikstown` et
## bâtie par `Quartiers`, ne vivait que dans l'éditeur : le jeu ne savait pas
## la lire.
##
## Cette classe répond aux MÊMES questions, mais chaque réponse vient du
## dessin. Elle ne réécrit rien du jeu : `dans_un_batiment`, `degager`,
## `point_de_rue`, `lieux_autour`… restent ceux de `PlanVille`, qui ne lisent
## que `tuile()`. On remplace la source, pas les consommateurs.
##
## ⚠ LES DEUX ÉCHELLES. Le jeu compte en PIXELS et en TUILES de cent pixels
## (dix unités 3D) ; le dessin compte en CASES de vingt unités. Une case fait
## donc exactement DEUX tuiles de côté, et une rue d'une case fait deux tuiles
## de large — précisément la largeur des rues de `PlanVille`. Cette coïncidence
## n'en est pas une : c'est ce qui permet de garder le moteur de circulation
## tel quel.
##
## ⚠ LE RELIEF EST NOUVEAU POUR LE JEU. `PlanVille` est plate : tout se joue à
## y = 0. Pikstown a dix paliers. La simulation reste en deux dimensions (une
## voiture sur un pont est sur une case de rue, point), mais le rendu lit
## `hauteur_en(p)` pour poser chaque chose à l'altitude du sol.

const CASE_PX := 200.0                 ## une case, en pixels de jeu (2 tuiles)
const TUILES_PAR_CASE := 2

var carte: CarteVille
var dessin: Array
var fiche_ville: Dictionary
var cases_x := 0
var cases_y := 0
## Le district de chaque case, déduit des lettres et étalé sur les rues.
var _district: PackedInt32Array
## Le gang de chaque case (−1 : neutre), par île.
var _gang: PackedInt32Array
var _tuiles: Dictionary = {}          ## indice de tuile -> fiche
var _lieux_par_secteur: Dictionary = {}
var _lieux_prets := false
var _coeur_d := Vector2.ZERO

func _init(code_de_manche: String, id_ville: String = "pikstown") -> void:
	super(code_de_manche)
	fiche_ville = Quartiers.CATALOGUE[id_ville]
	dessin = fiche_ville["plan"]
	carte = Quartiers.carte_de(fiche_ville)
	cases_y = dessin.size()
	for l in dessin:
		cases_x = maxi(cases_x, String(l).length())
	_classer()

## `PlanVille` trace ses boulevards libres dès la construction ; ici il n'y en
## a pas — les courbes sont des cases comme les autres.
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

func _car(i: int, j: int) -> String:
	if j < 0 or j >= cases_y: return "."
	var l := String(dessin[j])
	return l[i] if i >= 0 and i < l.length() else "."

# ------------------------------------------------------------ l'eau et le relief

func eau(colonne: int, ligne: int) -> bool:
	var c := case_de_tuile(colonne, ligne)
	return not carte.terre(c)

func sur_le_rail(_colonne: int, _ligne: int) -> bool:
	return false

## Pas de voie ferrée dans le dessin : on la renvoie hors carte, et le train ne
## trouve jamais de rail sous ses roues.
func rail() -> Vector3:
	return Vector3(0.0, 1.0, -1.0e9)

## L'altitude du sol en un point, en unités 3D — la seule chose que le rendu
## demande au relief. Sur une rampe, on interpole entre le bas et le haut de
## la case dans le sens de la montée ; sinon c'est le palier de la case.
func hauteur_en(p: Vector2) -> float:
	var c := case_de_point(p)
	if not carte.terre(c):
		return Quartiers.NIVEAU_MER
	var y := carte.hauteur(c)
	if not carte.route(c):
		return y
	# Une rue qui monte : le kit pose `road-slant` sur la case BASSE, et la
	# case suivante dans l'axe est d'un ou deux paliers plus haut.
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

## Les lettres du dessin disent le district ; les rues et les cours prennent
## celui de la lettre la plus proche. Le gang, lui, va avec l'île : trois îles,
## trois gangs — sauf le coeur du centre-ville, neutre, où l'on se rencontre.
func _classer() -> void:
	var n := cases_x * cases_y
	_district.resize(n)
	_gang.resize(n)
	var file: Array[int] = []
	for j in cases_y:
		for i in cases_x:
			var k := j * cases_x + i
			_district[k] = -1
			_gang[k] = -1
			var car := _car(i, j)
			var d := -1
			match car:
				"T": d = CENTRE
				"B", "b": d = AFFAIRES
				"C", "c", "S", "$": d = COMMERCE
				"V", "v": d = VIEUX
				"M", "m": d = BANLIEUE
				"t": d = RESIDENCES
				"H", "h", "X", "K", "%": d = INDUSTRIE
				"~": d = PORT
				"^": d = PARC
				".": d = EAU
			if d >= 0:
				_district[k] = d
				file.append(k)
	# Étaler aux cases sans lettre (rues, cours, sable), en largeur d'abord.
	var tete := 0
	while tete < file.size():
		var k: int = file[tete]
		tete += 1
		var i := posmod(k, cases_x)
		var j := k / cases_x
		for d: Vector2i in CarteVille.COTES:
			var a: int = i + d.x
			var b: int = j + d.y
			if a < 0 or b < 0 or a >= cases_x or b >= cases_y: continue
			var k2: int = b * cases_x + a
			if _district[k2] >= 0: continue
			_district[k2] = _district[k]
			file.append(k2)
	# Les gangs par île : on remplit chaque terre d'un seul tenant.
	var ile := 0
	var attribue := PackedByteArray()
	attribue.resize(n)
	var tailles: Array = []
	for j in cases_y:
		for i in cases_x:
			var k := j * cases_x + i
			if attribue[k] == 1 or not carte.terre(Vector2i(i, j)): continue
			var membres: Array[int] = [k]
			attribue[k] = 1
			var t2 := 0
			while t2 < membres.size():
				var m: int = membres[t2]
				t2 += 1
				var mi := posmod(m, cases_x)
				var mj := m / cases_x
				for d: Vector2i in CarteVille.COTES:
					var a: int = mi + d.x
					var b: int = mj + d.y
					if a < 0 or b < 0 or a >= cases_x or b >= cases_y: continue
					var k2: int = b * cases_x + a
					if attribue[k2] == 1 or not carte.terre(Vector2i(a, b)): continue
					attribue[k2] = 1
					membres.append(k2)
			tailles.append([membres.size(), ile, membres])
			ile += 1
	# Les trois plus grandes îles portent les trois gangs, du nord au sud ;
	# les îlots prennent celui de l'île la plus proche par leur premier point.
	tailles.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
	var grandes: Array = []
	for t in mini(3, tailles.size()):
		grandes.append(tailles[t])
	grandes.sort_custom(func(a, b): return int((a[2] as Array)[0]) < int((b[2] as Array)[0]))
	var ordre_gang := [1, 2, 0]   # nord : La Fonte (commerce), milieu : Le Lierre (banlieue), sud : Les Braises (industrie)
	for g in grandes.size():
		for m in (grandes[g][2] as Array):
			_gang[m] = ordre_gang[g]
	for t in tailles:
		if t in grandes: continue
		var premier: int = (t[2] as Array)[0]
		var pi := posmod(premier, cases_x)
		var pj := premier / cases_x
		var meilleur := 0
		var dist := 1.0e18
		for g in grandes.size():
			var q: int = (grandes[g][2] as Array)[0]
			var dd := Vector2(pi - posmod(q, cases_x), pj - q / cases_x).length_squared()
			if dd < dist:
				dist = dd
				meilleur = g
		for m in (t[2] as Array):
			_gang[m] = ordre_gang[meilleur]
	# Le coeur du centre-ville est neutre : les tours, personne ne les tient.
	for j in cases_y:
		for i in cases_x:
			var k := j * cases_x + i
			if _district[k] == CENTRE:
				_gang[k] = -1

func district_de_case(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= cases_x or c.y >= cases_y: return EAU
	var d: int = _district[c.y * cases_x + c.x]
	return d if d >= 0 else PARC

func gang_de_case(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= cases_x or c.y >= cases_y: return -1
	return _gang[c.y * cases_x + c.x]

func quartier(point: Vector2) -> int:
	return district_de_case(case_de_point(point))

func territoire(point: Vector2) -> int:
	return gang_de_case(case_de_point(point))

## Les pâtés n'existent pas ici ; un « pâté » est une case. Ces deux-là sont
## appelés avec un Vector2i par les consommateurs qui viennent de `pate_de`.
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

## Le coeur : la case de rue la plus proche du centre géométrique, sur la
## plus grande île. C'est autour de lui que naissent les joueurs.
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
	for j in cases_y:
		for i in cases_x:
			if _car(i, j) == "=":
				return centre_case(Vector2i(i, j))
	return coeur()

func meme_terre(a: Vector2, b: Vector2) -> bool:
	var pas := int(ceilf(a.distance_to(b) / (PAS * 0.5)))
	for i in range(1, maxi(2, pas)):
		var p: Vector2 = a.lerp(b, float(i) / float(pas))
		if not carte.terre(case_de_point(p)):
			return false
	return true

# ------------------------------------------------------------ les tuiles

## La fiche d'une tuile : c'est TOUT ce que la physique lit. Une case de
## bâtiment donne quatre tuiles bloquées ; le retrait ne se prend que sur les
## côtés qui donnent sur autre chose que le même bâtiment — sans quoi quatre
## tuiles laissaient entre elles des fentes de trente pixels, et une voiture
## de vingt-six de rayon s'y glissait.
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
	else:
		var car := _car(c.x, c.y)
		var lettre := Quartiers._lettre(car)
		if carte.route(c) or carte.case_prise(c) and carte.piece_sur(c).get("r", false):
			f = _vierge(colonne, ligne, S_ROUTE)
		elif lettre != "" and car != Quartiers.CABINE and car != Quartiers.CAISSE:
			f = _vierge(colonne, ligne, S_BETON)
			var r := Rect2(Vector2(colonne, ligne) * PAS, Vector2(PAS, PAS))
			# Le retrait, côté par côté.
			var di := posmod(colonne, TUILES_PAR_CASE)   # 0 : moitié ouest, 1 : est
			var dj := posmod(ligne, TUILES_PAR_CASE)
			if di == 0 and _car(c.x - 1, c.y) != car:
				r.position.x += RETRAIT; r.size.x -= RETRAIT
			if di == 1 and _car(c.x + 1, c.y) != car:
				r.size.x -= RETRAIT
			if dj == 0 and _car(c.x, c.y - 1) != car:
				r.position.y += RETRAIT; r.size.y -= RETRAIT
			if dj == 1 and _car(c.x, c.y + 1) != car:
				r.size.y -= RETRAIT
			_bloquer(f, r)
		else:
			var sol := S_HERBE
			match car:
				";": sol = S_TERRE
				"o": sol = S_ESPLANADE
				"P": sol = S_PARKING
				"X", "%": sol = S_BETON
			f = _vierge(colonne, ligne, sol)
	_tuiles[indice] = f
	return f

func fiches_en_cache() -> int:
	return _tuiles.size()

## Ni voitures dormantes ni immeubles casssables pour l'instant : les
## voitures garées de Pikstown sont du décor, et ses immeubles sont des
## modèles du kit. Les deux viendront ; en attendant, ces réponses vides
## rendent le vol de voiture et la casse simplement inopérants, sans faute.
func dormante(_id: int) -> Dictionary:
	return {}

func dormantes_autour(_point: Vector2, _rayon: float) -> Array:
	return []

func immeuble_a(_point: Vector2, _marge: float = 8.0) -> Dictionary:
	return {}

func eventrer(_id: int) -> void:
	pass

# ------------------------------------------------------------ la voirie

## Pas de voie libre : tout est case. Les courbes et les ronds-points se
## conduisent comme des rues de la grille — mur devant, on tourne.
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
	# Le trottoir fait 0,42 case de part et d'autre de l'axe... non : la
	# chaussée du kit occupe le milieu de la case, le trottoir le bord. On
	# est sur la chaussée à moins de 0,30 case de l'axe de la rue.
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

## L'AXE DE LA RUE ET LE PROCHAIN CARREFOUR. `PlanVille` renvoie le croisement
## des deux axes de grille les plus proches ; le trafic s'en sert pour DEUX
## choses — tenir sa file (la coordonnée de l'axe) et savoir s'il est à un
## carrefour (la distance). Ici : la case de rue où l'on est donne l'axe, et
## le carrefour est la jonction la plus proche LE LONG de cette rue.
func carrefour_proche(point: Vector2) -> Vector2:
	var c := case_de_point(point)
	if not carte.route(c):
		# Hors rue : la case de rue la plus proche dans un petit rayon.
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
		return centre_case(c)          # on EST à une jonction ou un virage
	# Sur une droite : la jonction la plus proche dans l'axe, d'un côté ou de
	# l'autre. La coordonnée perpendiculaire est celle de l'axe de la rue.
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
	# L'axe : la coordonnée fixe de la rue. Sur une rue selon X, le Y de la
	# case ; le X est celui du carrefour trouvé.
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

## Les lieux viennent des lettres du dessin, une fois pour toute la ville :
## garages `$`, cabines `?`, hôpitaux `+`, planques (une maison `M` sur
## quinze, en périphérie), repaires (un hangar ou un vieux bloc par gang tous
## les quarante cases), arènes (une esplanade `o` sur les frontières de gang).
## Ils sont rangés par secteur pour que `lieux_autour` reste local.
func _preparer_lieux() -> void:
	if _lieux_prets: return
	_lieux_prets = true
	var vus: Dictionary = {}
	var derniers := {"planques": [], "repaires": [], "arenes": []}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(code) + 4242
	for j in cases_y:
		for i in cases_x:
			var c := Vector2i(i, j)
			var car := _car(i, j)
			var id := j * cases_x + i
			var p := centre_case(c)
			var genre := ""
			var lieu := {}
			if car == "$" and not vus.has(id):
				genre = "garages"
			elif car == "?":
				genre = "cabines"
			elif car == "+" and not vus.has(id):
				genre = "hopitaux"
			elif car == "S" and not vus.has(id):
				# Le supermarché du dessin est la supérette du jeu (faim et soif).
				genre = "superettes"
			elif car == "M" and _bord_de_rue(c) and _loin(derniers["planques"], c, 36):
				genre = "planques"
				lieu = {"prix": PRIX_PLANQUE[posmod(id, PRIX_PLANQUE.size())]}
			elif (car == "H" or car == "V") and gang_de_case(c) >= 0 \
					and _bord_de_rue(c) and _loin(derniers["repaires"], c, 44):
				genre = "repaires"
				lieu = {"gang": gang_de_case(c)}
			elif car == "o" and _frontiere(c) and _loin(derniers["arenes"], c, 60):
				genre = "arenes"
			if genre == "": continue
			# Un bâtiment de plusieurs cases : une seule fiche, ancrée sur sa
			# première case (la plus au nord-ouest).
			if car in "$+S":
				var bloc := _bloc_de(c)
				for b in bloc: vus[b.y * cases_x + b.x] = true
				var somme := Vector2.ZERO
				for b in bloc: somme += centre_case(b)
				p = somme / float(bloc.size())
			lieu["p"] = p
			lieu["id"] = id
			lieu["pate"] = c
			if derniers.has(genre): derniers[genre].append(c)
			var s := _secteur_de(p)
			if not _lieux_par_secteur.has(s):
				_lieux_par_secteur[s] = {"garages": [], "cabines": [], "arenes": [], "repaires": [], "hopitaux": [], "planques": [], "superettes": []}
			_lieux_par_secteur[s][genre].append(lieu)

func _bord_de_rue(c: Vector2i) -> bool:
	for d in CarteVille.COTES:
		if carte.route(c + d): return true
	return false

func _loin(liste: Array, c: Vector2i, ecart: int) -> bool:
	for v in liste:
		if absi((v as Vector2i).x - c.x) + absi((v as Vector2i).y - c.y) < ecart:
			return false
	return true

func _frontiere(c: Vector2i) -> bool:
	var g := gang_de_case(c)
	for dj in range(-4, 5):
		for di in range(-4, 5):
			var v := c + Vector2i(di, dj)
			if v.x < 0 or v.y < 0 or v.x >= cases_x or v.y >= cases_y: continue
			if carte.terre(v) and gang_de_case(v) != g:
				return true
	return false

func _bloc_de(c: Vector2i) -> Array:
	var car := _car(c.x, c.y)
	var bloc: Array = [c]
	var vu := {c: true}
	var t := 0
	while t < bloc.size():
		var m: Vector2i = bloc[t]
		t += 1
		for d in CarteVille.COTES:
			var v: Vector2i = m + d
			if vu.has(v) or _car(v.x, v.y) != car: continue
			vu[v] = true
			bloc.append(v)
	return bloc

func _lieux_du_secteur(secteur: Vector2i) -> Dictionary:
	_preparer_lieux()
	return _lieux_par_secteur.get(secteur,
		{"garages": [], "cabines": [], "arenes": [], "repaires": [], "hopitaux": [], "planques": [], "superettes": []})

func lieux_autour(point: Vector2, rayon: float) -> Dictionary:
	var resultat := {"garages": [], "cabines": [], "arenes": [], "repaires": [], "hopitaux": [], "planques": [], "superettes": []}
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
	# `indice` compte les cases, ligne par ligne.
	var i := posmod(indice, cases_x)
	var j := indice / cases_x
	if j >= cases_y: return
	var c := Vector2i(i, j)
	var couleur: Color
	if not carte.terre(c):
		couleur = CARTE_EAU
	elif carte.route(c):
		couleur = CARTE_RUE
	else:
		var d := district_de_case(c)
		couleur = COULEURS_CARTE.get(d, COULEURS_CARTE[PARC])
		var g := gang_de_case(c)
		if g >= 0:
			couleur = couleur.lerp(couleur_du_gang(g), 0.25)
		if Quartiers._lettre(_car(i, j)) == "":
			couleur = couleur.darkened(0.15)
	for dj in TUILES_PAR_CASE:
		for di in TUILES_PAR_CASE:
			var x := i * TUILES_PAR_CASE + di
			var y := j * TUILES_PAR_CASE + dj
			if x < image.get_width() and y < image.get_height():
				image.set_pixel(x, y, couleur)

func nombre_de_pates() -> int:
	return cases_x * cases_y
