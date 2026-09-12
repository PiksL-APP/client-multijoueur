class_name Lotisseur
extends RefCounted
## POSER DES BÂTIMENTS LE LONG D'UNE RUE — la brique commune des générateurs.
##
## « Le lot s'adapte au modèle, jamais l'inverse » (cahier § 7). On marche donc
## le long du trottoir et on avance de l'emprise RÉELLE du modèle qu'on vient
## de poser, jamais d'un pas fixe : c'est ce qui donne une rue dont les
## façades se suivent sans fente ni chevauchement, et dont les largeurs
## varient comme dans une vraie rue.
##
## Tout se compte en DEMI-CASES : une demi-case est une tuile du jeu, et un lot
## qui tombe sur cette grille bloque des tuiles entières.

## Le quart de tour qui met la FAÇADE d'un modèle (son −Z) vers ce côté.
const VERS := {"n": 0, "e": 3, "s": 2, "o": 1}

## Borde un pâté de bâtiments : les quatre côtés donnent sur la rue, le milieu
## reste libre (cour, jardin, parking — au générateur de le meubler). Rend la
## table des demi-cases occupées.
static func border(v: Ville2, r: Rect2i, alea: RandomNumberGenerator, choix: Array,
		densite: float, genre: String, cotes: Array = ["n", "s", "o", "e"]) -> Dictionary:
	var occupe: Dictionary = {}
	var hx0 := r.position.x * 2
	var hy0 := r.position.y * 2
	var hx1 := r.end.x * 2
	var hy1 := r.end.y * 2
	for cote in cotes:
		var q: int = VERS[cote]
		if cote == "n" or cote == "s":
			var hx := hx0
			while hx < hx1:
				var m := modele_qui_tient(choix, q, hx1 - hx, alea)
				if m == "":
					hx += 1
					continue
				var e := KitVille2.emprise_tournee(m, q)
				var hy := hy0 if cote == "n" else hy1 - e.y
				if libre(occupe, hx, hy, e) and alea.randf() < densite:
					prendre(occupe, hx, hy, e)
					v.ajouter_lot(m, hx, hy, e.x, e.y, q, genre)
				hx += e.x
		else:
			var hy := hy0
			while hy < hy1:
				var m := modele_qui_tient(choix, q, hy1 - hy, alea)
				if m == "":
					hy += 1
					continue
				var e := KitVille2.emprise_tournee(m, q)
				var hx := hx0 if cote == "o" else hx1 - e.x
				if libre(occupe, hx, hy, e) and alea.randf() < densite:
					prendre(occupe, hx, hy, e)
					v.ajouter_lot(m, hx, hy, e.x, e.y, q, genre)
					hy += e.y
				else:
					hy += 1
	return occupe

## Une file de bâtiments le long d'une ligne, tous tournés du même côté : la
## rangée d'hôtels d'un front de mer, les hangars d'un quai. `hy` est la
## demi-case du bord le plus au nord (ou à l'ouest) de la file.
static func aligner(v: Ville2, alea: RandomNumberGenerator, choix: Array, cote: String,
		depart: Vector2i, longueur: int, genre: String, densite := 1.0, ecart := 0) -> void:
	var q: int = VERS[cote]
	var selon_x := cote == "n" or cote == "s"
	var k := 0
	while k < longueur:
		var m := modele_qui_tient(choix, q, longueur - k, alea)
		if m == "":
			break
		var e := KitVille2.emprise_tournee(m, q)
		var pas := e.x if selon_x else e.y
		if alea.randf() < densite:
			var hx := depart.x + k if selon_x else depart.x
			var hy := depart.y if selon_x else depart.y + k
			# Une file tournée vers le sud ou l'est se cale sur son bord loin.
			if cote == "s": hy = depart.y - e.y
			if cote == "e": hx = depart.x - e.x
			v.ajouter_lot(m, hx, hy, e.x, e.y, q, genre)
		k += pas + ecart

## Le modèle dont la FAÇADE (sa largeur une fois tournée) tient dans
## `longueur` demi-cases.
static func modele_qui_tient(choix: Array, q: int, longueur: int, alea: RandomNumberGenerator) -> String:
	var candidats: Array = []
	for m in choix:
		if KitVille2.emprise_tournee(String(m), q).x <= longueur:
			candidats.append(m)
	if candidats.is_empty(): return ""
	return String(candidats[alea.randi() % candidats.size()])

static func libre(occupe: Dictionary, hx: int, hy: int, e: Vector2i) -> bool:
	for b in e.y:
		for a in e.x:
			if occupe.has(Vector2i(hx + a, hy + b)): return false
	return true

static func prendre(occupe: Dictionary, hx: int, hy: int, e: Vector2i) -> void:
	for b in e.y:
		for a in e.x:
			occupe[Vector2i(hx + a, hy + b)] = true
