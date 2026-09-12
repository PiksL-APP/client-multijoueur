class_name Gps
extends RefCounted
## L'ITINÉRAIRE PAR LES RUES : d'où l'on est au point qu'on a cliqué sur la
## carte, en suivant la chaussée — pas à vol d'oiseau, on ne conduit pas à
## travers les pâtés.
##
## Le réseau routier de Pikstown est une GRILLE (`PlanVille`) : une rue toutes
## les `PERIODE` tuiles, dans les deux sens, et des tronçons fermés ici et là
## (`rue_fermee_v`, `rue_fermee_h`) ou noyés (`eau`). Les carrefours sont donc
## les nœuds (k, l) d'un quadrillage, et un tronçon relie deux carrefours
## voisins quand il n'est ni fermé ni sous l'eau. C'est le même dessin que
## celui du radar — on cherche le chemin sur ce qu'on montre.
##
## ⚠ LA PREMIÈRE VERSION ÉTAIT « N'IMPORTE QUOI », et le client l'a dit :
##  • elle partait du JOUEUR VERS LE CARREFOUR le plus proche en ligne droite
##    — à travers l'immeuble qu'il y avait entre les deux — et finissait de
##    même vers le point cliqué. On PROJETTE maintenant le départ et l'arrivée
##    sur la rue la plus proche, et la route ne quitte jamais la chaussée ;
##  • elle testait l'eau sur UNE tuile par tronçon, au milieu. Un tronçon qui
##    entre dans la rivière par son bout passait pour ouvert, et la route
##    coupait à travers le bras d'eau là où il n'y a pas de pont. On teste
##    maintenant TOUTES les tuiles du tronçon, une fois, et on s'en souvient ;
##  • un parcours en largeur ne sait pas partir du MILIEU d'un tronçon : il
##    faut un Dijkstra, qui part des deux carrefours du tronçon de départ avec
##    la distance déjà parcourue, et arrive par l'un ou l'autre bout du
##    tronçon d'arrivée.

const P := PlanVille.PERIODE

## L'axe du carrefour (k, l), en pixels de jeu : le milieu de la rue, entre ses
## deux tuiles — là où le radar trace ses lignes.
static func carrefour(k: int, l: int) -> Vector2:
	return Vector2(float(k * P + 1), float(l * P + 1)) * PlanVille.PAS

static func _kx() -> int:
	return PlanVille.COLONNES / P + 1

static func _ky() -> int:
	return PlanVille.LIGNES / P + 1

# ------------------------------------------------------------ les tronçons

## La ville ne change pas pendant la manche : ce qu'un tronçon coûte à tester
## (une douzaine de tuiles d'eau, chacune avec ses bras de rivière), on ne le
## paie qu'une fois. La table est vidée si la carte change d'instance.
static var _cache_pour: int = 0
static var _ouverts_v: Dictionary = {}
static var _ouverts_h: Dictionary = {}

static func _preparer(carte: PlanVille) -> void:
	if _cache_pour != carte.get_instance_id():
		_cache_pour = carte.get_instance_id()
		_ouverts_v.clear()
		_ouverts_h.clear()
		_chauffe = 0

## Peut-on rouler du carrefour (k, l) vers le sud, le long du pâté l ? Les
## DEUX tuiles de la rue, sur toute la longueur du tronçon, doivent être hors
## de l'eau : un pont est une avenue, ses tuiles ne sont pas de l'eau.
static func _vers_le_sud(carte: PlanVille, k: int, l: int) -> bool:
	if l + 1 >= _ky() or k >= _kx():
		return false
	var cle := k + l * 4096
	if _ouverts_v.has(cle):
		return _ouverts_v[cle]
	var ouvert := not carte.rue_fermee_v(k, l)
	if ouvert:
		# Quatre rangées sur les sept du tronçon, les deux voies à chaque fois :
		# un bras d'eau fait plusieurs tuiles de large, il n'échappe pas à ce
		# peigne, et `eau()` est ce qui coûte ici.
		for y in [l * P, l * P + 2, l * P + 4, l * P + 6]:
			if carte.eau(k * P, y) or carte.eau(k * P + 1, y):
				ouvert = false
				break
	_ouverts_v[cle] = ouvert
	return ouvert

## … et vers l'est, le long du pâté k ?
static func _vers_l_est(carte: PlanVille, k: int, l: int) -> bool:
	if k + 1 >= _kx() or l >= _ky():
		return false
	var cle := k + l * 4096
	if _ouverts_h.has(cle):
		return _ouverts_h[cle]
	var ouvert := not carte.rue_fermee_h(l, k)
	if ouvert:
		for x in [k * P, k * P + 2, k * P + 4, k * P + 6]:
			if carte.eau(x, l * P) or carte.eau(x, l * P + 1):
				ouvert = false
				break
	_ouverts_h[cle] = ouvert
	return ouvert

## CHAUFFER LA TABLE PENDANT LA MANCHE, par petits lots : vingt-huit mille
## tronçons à tester d'un coup, c'est trois secondes de gel au premier clic.
## Appelée à chaque image avec un budget en microsecondes, elle rend vrai
## quand tout est connu. Comme la carte de la ville, qui se peint par lots.
static var _chauffe := 0

static func chauffer(carte: PlanVille, budget_usec: int = 2500) -> bool:
	# La ville dessinée n'a rien à chauffer : une case de rue est une entrée
	# de dictionnaire, pas un bras de rivière à tester.
	if carte is PlanDessine or carte is PlanV2:
		return true
	_preparer(carte)
	var total := _kx() * _ky()
	var depart := Time.get_ticks_usec()
	while _chauffe < total and Time.get_ticks_usec() - depart < budget_usec:
		var k := _chauffe % _kx()
		var l := _chauffe / _kx()
		_vers_le_sud(carte, k, l)
		_vers_l_est(carte, k, l)
		_chauffe += 1
	return _chauffe >= total

static func _voisins(carte: PlanVille, k: int, l: int) -> Array:
	var out: Array = []
	if _vers_le_sud(carte, k, l):
		out.append(Vector2i(k, l + 1))
	if l > 0 and _vers_le_sud(carte, k, l - 1):
		out.append(Vector2i(k, l - 1))
	if _vers_l_est(carte, k, l):
		out.append(Vector2i(k + 1, l))
	if k > 0 and _vers_l_est(carte, k - 1, l):
		out.append(Vector2i(k - 1, l))
	return out

# ------------------------------------------------------------ se mettre sur la rue

## LE TRONÇON LE PLUS PROCHE d'un point, et la projection du point dessus :
## {"a": Vector2i, "b": Vector2i, "p": Vector2}. On regarde les deux rues qui
## encadrent le point dans chaque sens (quatre axes), on ne garde que les
## tronçons ouverts, et l'on prend celui dont l'axe est le plus près. Un
## point au milieu d'un pâté tombe ainsi sur la rue d'à côté ; un point dans
## l'eau, sur le quai.
static func troncon_proche(carte: PlanVille, p: Vector2) -> Dictionary:
	var t := p / PlanVille.PAS
	var mieux := {}
	var d_mieux := INF
	var k0 := int(floor((t.x - 1.0) / float(P)))
	var l0 := int(floor((t.y - 1.0) / float(P)))
	for dk in range(-1, 3):
		for dl in range(-1, 3):
			var k := k0 + dk
			var l := l0 + dl
			if k < 0 or l < 0 or k >= _kx() or l >= _ky():
				continue
			# le tronçon vertical qui part de (k, l) vers le sud
			if _vers_le_sud(carte, k, l):
				var a := carrefour(k, l)
				var b := carrefour(k, l + 1)
				var q := Geometry2D.get_closest_point_to_segment(p, a, b)
				var d := q.distance_squared_to(p)
				if d < d_mieux:
					d_mieux = d
					mieux = {"a": Vector2i(k, l), "b": Vector2i(k, l + 1), "p": q}
			# et l'horizontal vers l'est
			if _vers_l_est(carte, k, l):
				var a := carrefour(k, l)
				var b := carrefour(k + 1, l)
				var q := Geometry2D.get_closest_point_to_segment(p, a, b)
				var d := q.distance_squared_to(p)
				if d < d_mieux:
					d_mieux = d
					mieux = {"a": Vector2i(k, l), "b": Vector2i(k + 1, l), "p": q}
	return mieux

# ------------------------------------------------------------ le chemin

## Un tas binaire minimal sur [coût, nœud] : GDScript n'en a pas, et un
## Dijkstra sans tas sur quatorze mille carrefours se sentirait au clic.
static func _pousser(tas: Array, e: Array) -> void:
	tas.append(e)
	var i := tas.size() - 1
	while i > 0:
		var parent := (i - 1) / 2
		if float(tas[parent][0]) <= float(tas[i][0]):
			break
		var tmp = tas[parent]
		tas[parent] = tas[i]
		tas[i] = tmp
		i = parent

static func _tirer(tas: Array) -> Array:
	var haut: Array = tas[0]
	var dernier: Array = tas.pop_back()
	if not tas.is_empty():
		tas[0] = dernier
		var i := 0
		var n := tas.size()
		while true:
			var g := 2 * i + 1
			var d := g + 1
			var m := i
			if g < n and float(tas[g][0]) < float(tas[m][0]):
				m = g
			if d < n and float(tas[d][0]) < float(tas[m][0]):
				m = d
			if m == i:
				break
			var tmp = tas[m]
			tas[m] = tas[i]
			tas[i] = tmp
			i = m
	return haut

## L'itinéraire, en pixels de jeu : [départ, point sur la rue, carrefour, …,
## carrefour, point sur la rue]. Il ne va PAS jusqu'au point cliqué s'il est
## hors de la chaussée : on s'arrête au bord de la rue en face, comme un GPS.
## Vide s'il n'existe pas (une île sans pont, un point hors carte).
static func itineraire(carte: PlanVille, depart: Vector2, arrivee: Vector2) -> PackedVector2Array:
	if carte is PlanDessine or carte is PlanV2:
		return _itineraire_dessine(carte, depart, arrivee)
	_preparer(carte)
	var td := troncon_proche(carte, depart)
	var ta := troncon_proche(carte, arrivee)
	if td.is_empty() or ta.is_empty():
		return PackedVector2Array()
	var pd: Vector2 = td["p"]
	var pa: Vector2 = ta["p"]
	var out := PackedVector2Array()
	out.append(depart)
	# Même tronçon : on y va tout droit, sans passer par un carrefour.
	if (td["a"] == ta["a"] and td["b"] == ta["b"]):
		out.append(pd)
		out.append(pa)
		return out
	var kx := _kx()
	var but_a: int = int(ta["a"].x) + int(ta["a"].y) * kx
	var but_b: int = int(ta["b"].x) + int(ta["b"].y) * kx
	# Dijkstra depuis les deux bouts du tronçon de départ.
	# A* : on trie par g + h, h étant la distance à vol d'oiseau jusqu'à
	# l'arrivée — jamais plus que la vraie, donc le chemin reste le plus court,
	# et l'on visite dix fois moins de carrefours qu'un Dijkstra nu.
	var cout: Dictionary = {}
	var venu: Dictionary = {}
	var tas: Array = []
	for bout in [td["a"], td["b"]]:
		var id: int = int(bout.x) + int(bout.y) * kx
		var ici0 := carrefour(int(bout.x), int(bout.y))
		var c := pd.distance_to(ici0)
		cout[id] = c
		venu[id] = -1
		_pousser(tas, [c + ici0.distance_to(pa), id, c])
	var meilleur := INF
	var fin := -1
	while not tas.is_empty():
		var e := _tirer(tas)
		var c: float = e[2]
		var id: int = e[1]
		if c > float(cout.get(id, INF)) + 0.001:
			continue
		if float(e[0]) >= meilleur:
			break
		# Arrivé sur un bout du tronçon d'arrivée : il reste le bout de rue
		# jusqu'à la projection. On garde le meilleur des deux bouts.
		if id == but_a or id == but_b:
			var reste := carrefour(id % kx, id / kx).distance_to(pa)
			if c + reste < meilleur:
				meilleur = c + reste
				fin = id
		var k := id % kx
		var l := id / kx
		var ici := carrefour(k, l)
		for v in _voisins(carte, k, l):
			var vi: Vector2i = v
			var vid := vi.x + vi.y * kx
			var nc := c + ici.distance_to(carrefour(vi.x, vi.y))
			if nc < float(cout.get(vid, INF)):
				cout[vid] = nc
				venu[vid] = id
				_pousser(tas, [nc + carrefour(vi.x, vi.y).distance_to(pa), vid, nc])
	if fin < 0:
		return PackedVector2Array()
	var chemin: Array = []
	var courant := fin
	while courant >= 0:
		chemin.append(carrefour(courant % kx, courant / kx))
		courant = int(venu[courant])
	chemin.reverse()
	out.append(pd)
	# ⚠ Les carrefours en ligne droite se fondent : un boulevard rectiligne
	# n'est pas trois cents segments à dessiner sur le radar à chaque image.
	for i in chemin.size():
		if i > 0 and i < chemin.size() - 1:
			var avant: Vector2 = chemin[i - 1]
			var apres: Vector2 = chemin[i + 1]
			var ici: Vector2 = chemin[i]
			if is_zero_approx((ici - avant).cross(apres - ici)):
				continue
		out.append(chemin[i])
	out.append(pa)
	return _nettoyer(out)

## Un aller-retour au départ (on projette sur la rue, puis le premier
## carrefour est derrière soi) donne un crochet d'un pixel : on retire les
## points qui reviennent sur leurs pas et ceux qui se confondent.
static func _nettoyer(chemin: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in chemin:
		if out.is_empty() or out[out.size() - 1].distance_to(p) > 1.0:
			out.append(p)
	var i := 1
	while i < out.size() - 1:
		var a := out[i - 1]
		var b := out[i]
		var c := out[i + 1]
		# b entre a et c sur la même droite, mais c revient vers a : on saute b
		# ET on coupe le retour en se plaçant directement.
		if is_zero_approx((b - a).cross(c - b)) and (b - a).dot(c - b) < 0.0:
			out.remove_at(i)
			continue
		i += 1
	return out

## La longueur d'un itinéraire, en pixels de jeu.
static func longueur(chemin: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, chemin.size()):
		total += chemin[i - 1].distance_to(chemin[i])
	return total

## À quelle distance du tracé se trouve un point : c'est ce qui dit qu'on s'en
## est écarté et qu'il faut recalculer.
static func ecart(chemin: PackedVector2Array, p: Vector2) -> float:
	var mini := INF
	for i in range(1, chemin.size()):
		var q := Geometry2D.get_closest_point_to_segment(p, chemin[i - 1], chemin[i])
		mini = minf(mini, q.distance_to(p))
	return mini

## Le bout de la route : là où l'on « arrive ».
static func bout(chemin: PackedVector2Array) -> Vector2:
	return chemin[chemin.size() - 1] if not chemin.is_empty() else Vector2.ZERO

# ------------------------------------------------------------ la ville dessinée

## PIKSTOWN N'A PAS DE GRILLE. Ses rues sont des CASES (`CarteVille.route(c)`,
## deux tuiles de côté), qui tournent, se croisent et montent comme l'éditeur
## les a posées. Le graphe est donc celui des cases de rue, quatre voisines
## chacune, et le chemin va de centre de case en centre de case — c'est l'axe
## de la chaussée, une case de rue faisant exactement la largeur d'une rue.
## Même A*, même tas, autre graphe : la seule chose que `carte is PlanDessine`
## change, comme pour le fond du radar.

## La case de rue la plus proche d'un point, en spirale, jusqu'à six cases :
## un clic au milieu d'un îlot ou dans l'eau tombe sur la rue d'à côté.
## `plan` : un `PlanDessine` ou un `PlanV2` — mêmes `carte`, `cases_x`, `centre_case`.
static func _case_de_rue_proche(plan, p: Vector2) -> Vector2i:
	var c0: Vector2i = plan.case_de_point(p)
	var mieux := Vector2i(-1, -1)
	var d_mieux := INF
	for rayon in 7:
		for dl in range(-rayon, rayon + 1):
			for dk in range(-rayon, rayon + 1):
				if maxi(absi(dk), absi(dl)) != rayon:
					continue
				var c: Vector2i = c0 + Vector2i(dk, dl)
				if not plan.carte.route(c):
					continue
				var d: float = plan.centre_case(c).distance_squared_to(p)
				if d < d_mieux:
					d_mieux = d
					mieux = c
		if mieux.x >= 0:
			return mieux
	return mieux

static func _itineraire_dessine(plan, depart: Vector2, arrivee: Vector2) -> PackedVector2Array:
	var a := _case_de_rue_proche(plan, depart)
	var b := _case_de_rue_proche(plan, arrivee)
	if a.x < 0 or b.x < 0:
		return PackedVector2Array()
	var pa: Vector2 = plan.centre_case(b)
	var large: int = plan.cases_x + 2
	var origine := a.x + a.y * large
	var but := b.x + b.y * large
	var cout: Dictionary = {origine: 0.0}
	var venu: Dictionary = {origine: -1}
	var tas: Array = [[plan.centre_case(a).distance_to(pa), origine, 0.0]]
	var trouve := false
	while not tas.is_empty():
		var e := _tirer(tas)
		var id: int = e[1]
		var c: float = e[2]
		if c > float(cout.get(id, INF)) + 0.001:
			continue
		if id == but:
			trouve = true
			break
		var ici := Vector2i(id % large, id / large)
		for d in CarteVille.COTES:
			var v: Vector2i = ici + d
			if not plan.carte.route(v):
				continue
			var vid := v.x + v.y * large
			var nc := c + PlanDessine.CASE_PX
			if nc < float(cout.get(vid, INF)):
				cout[vid] = nc
				venu[vid] = id
				_pousser(tas, [nc + plan.centre_case(v).distance_to(pa), vid, nc])
	if not trouve:
		return PackedVector2Array()
	var chemin: Array = []
	var courant := but
	while courant >= 0:
		chemin.append(plan.centre_case(Vector2i(courant % large, courant / large)))
		courant = int(venu[courant])
	chemin.reverse()
	var out := PackedVector2Array()
	out.append(depart)
	for i in chemin.size():
		if i > 0 and i < chemin.size() - 1:
			var avant: Vector2 = chemin[i - 1]
			var apres: Vector2 = chemin[i + 1]
			var ici: Vector2 = chemin[i]
			if is_zero_approx((ici - avant).cross(apres - ici)):
				continue
		out.append(chemin[i])
	return _nettoyer(out)
