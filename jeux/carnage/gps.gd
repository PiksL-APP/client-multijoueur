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
## voisins quand il n'est ni fermé ni sous l'eau. C'est exactement ce que le
## radar dessine, segment par segment — on cherche le chemin sur le même
## dessin que celui qu'on montre.
##
## ⚠ Tous les tronçons ont la même longueur, donc le plus court chemin en
## NOMBRE de tronçons est aussi le plus court en mètres : un parcours en
## largeur suffit, et il visite ses quatorze mille carrefours en quelques
## millisecondes. Un A* serait plus malin et pas plus court.

const P := PlanVille.PERIODE

## L'axe du carrefour (k, l), en pixels de jeu : le milieu de la rue, entre ses
## deux tuiles — là où le radar trace ses lignes.
static func carrefour(k: int, l: int) -> Vector2:
	return Vector2(float(k * P + 1), float(l * P + 1)) * PlanVille.PAS

static func _kx() -> int:
	return PlanVille.COLONNES / P + 1

static func _ky() -> int:
	return PlanVille.LIGNES / P + 1

## Peut-on rouler du carrefour (k, l) vers le sud, le long du pâté l ?
static func _vers_le_sud(carte: PlanVille, k: int, l: int) -> bool:
	if l + 1 >= _ky():
		return false
	return not carte.rue_fermee_v(k, l) and not carte.eau(k * P, l * P + 3)

## … et vers l'est, le long du pâté k ?
static func _vers_l_est(carte: PlanVille, k: int, l: int) -> bool:
	if k + 1 >= _kx():
		return false
	return not carte.rue_fermee_h(l, k) and not carte.eau(k * P + 3, l * P)

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

## Le carrefour DESSERVI le plus proche d'un point : le plus proche qui ait au
## moins un tronçon ouvert. Un point cliqué au milieu d'un pâté ou dans l'eau
## tombe ainsi sur la rue d'à côté au lieu de n'avoir aucun chemin.
static func carrefour_proche(carte: PlanVille, p: Vector2) -> Vector2i:
	var t := p / PlanVille.PAS
	var k0 := clampi(int(round((t.x - 1.0) / float(P))), 0, _kx() - 1)
	var l0 := clampi(int(round((t.y - 1.0) / float(P))), 0, _ky() - 1)
	var mieux := Vector2i(-1, -1)
	var d_mieux := INF
	for rayon in 4:
		for dl in range(-rayon, rayon + 1):
			for dk in range(-rayon, rayon + 1):
				if maxi(absi(dk), absi(dl)) != rayon:
					continue
				var k := k0 + dk
				var l := l0 + dl
				if k < 0 or l < 0 or k >= _kx() or l >= _ky():
					continue
				if _voisins(carte, k, l).is_empty():
					continue
				var d := carrefour(k, l).distance_squared_to(p)
				if d < d_mieux:
					d_mieux = d
					mieux = Vector2i(k, l)
		if mieux.x >= 0:
			return mieux
	return mieux

## L'itinéraire, en pixels de jeu : [départ, carrefour, …, carrefour, arrivée].
## Vide s'il n'existe pas (une île sans pont, un point hors carte).
static func itineraire(carte: PlanVille, depart: Vector2, arrivee: Vector2) -> PackedVector2Array:
	var a := carrefour_proche(carte, depart)
	var b := carrefour_proche(carte, arrivee)
	if a.x < 0 or b.x < 0:
		return PackedVector2Array()
	var kx := _kx()
	var origine := a.x + a.y * kx
	var but := b.x + b.y * kx
	var venu: Dictionary = {origine: -1}
	var file: Array = [a]
	var tete := 0
	var trouve := origine == but
	while tete < file.size() and not trouve:
		var c: Vector2i = file[tete]
		tete += 1
		for v in _voisins(carte, c.x, c.y):
			var vi: Vector2i = v
			var id := vi.x + vi.y * kx
			if venu.has(id):
				continue
			venu[id] = c.x + c.y * kx
			if id == but:
				trouve = true
				break
			file.append(vi)
	if not trouve:
		return PackedVector2Array()
	var chemin: Array = []
	var courant := but
	while courant >= 0:
		chemin.append(carrefour(courant % kx, courant / kx))
		courant = int(venu[courant])
	chemin.reverse()
	var out := PackedVector2Array()
	out.append(depart)
	# ⚠ Les carrefours en ligne droite se fondent : trois cents points pour un
	# boulevard rectiligne, c'est trois cents segments à dessiner sur le radar
	# à chaque image pour rien.
	for i in chemin.size():
		if i > 0 and i < chemin.size() - 1:
			var avant: Vector2 = chemin[i - 1]
			var apres: Vector2 = chemin[i + 1]
			var ici: Vector2 = chemin[i]
			if is_zero_approx((ici - avant).cross(apres - ici)):
				continue
		out.append(chemin[i])
	out.append(arrivee)
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
