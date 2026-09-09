class_name CarteVille
extends RefCounted
## LA CARTE DESSINÉE À LA MAIN.
##
## Le plan procédural (`PlanVille`) déduit la ville d'un code de manche : il
## remplit vite et il remplit partout, mais il ne saura jamais faire une ville
## qui a l'air d'avoir été VÉCUE. Cette classe-ci porte l'autre voie : une
## carte posée case par case dans l'éditeur (`scenes/editeur.gd`), sauvée en
## JSON, et relue telle quelle par le jeu.
##
## L'UNITÉ EST LA CASE : vingt unités 3D de côté, soit DEUX tuiles du jeu —
## exactement une tuile du City Kit: Roads mise à l'échelle uniforme. C'est le
## seul découpage qui laisse les marquages et les trottoirs du kit à leurs
## proportions ; tout ce qu'on a étiré jusqu'ici sortait bavé.
##
## LE RELIEF SE COMPTE EN PALIERS de cinq unités (un quart de tuile Kenney,
## la hauteur exacte dont `road-slant` grimpe en une case). Une case porte son
## palier ; deux cases voisines qui n'ont pas le même reçoivent une rampe si
## une rue les joint, un mur de soutènement sinon.

const CASE := 20.0                     ## côté d'une case, en unités 3D
const PALIER := 5.0                    ## un cran de relief (= 0,25 tuile Kenney)
const CHEMIN_ROUTES := "res://modeles/kenney/routes/"

## Les quatre voisines, dans l'ordre des bits du masque de raccord.
const N := Vector2i(0, -1)
const E := Vector2i(1, 0)
const S := Vector2i(0, 1)
const O := Vector2i(-1, 0)
const COTES := [N, E, S, O]

## Une case : `n` le palier, `r` vrai s'il y a de la chaussée. Rien d'autre —
## tout ce qui est posé dessus (immeubles, arbres, mobilier) vit dans
## `objets`, en coordonnées libres : un arbre n'a aucune raison de tenir dans
## une grille, et l'y forcer donnait des alignements de cimetière.
var cases: Dictionary = {}             ## Vector2i -> {"n": int, "r": bool}
## Les GROSSES PIÈCES du kit : rond-point (3x3), courbe large (2x2). Elles ne
## se déduisent pas d'un masque de raccord, on les pose exprès. `i`,`j` est
## leur coin nord-ouest, `w` leur côté en cases.
var pieces: Array = []                 ## [{t, i, j, q, w}]
var objets: Array = []                 ## [{m, x, y, z, r, l, p, h, c}]
var nom := "sans-titre"

# ------------------------------------------------------------------ cases

func palier(c: Vector2i) -> int:
	var f = cases.get(c)
	return int(f["n"]) if f != null else -999

func terre(c: Vector2i) -> bool:
	return cases.has(c)

func route(c: Vector2i) -> bool:
	var f = cases.get(c)
	return f != null and bool(f["r"])

func hauteur(c: Vector2i) -> float:
	return float(palier(c)) * PALIER

## Le centre d'une case, en unités 3D. Le sol est en Y = palier x PALIER.
func centre(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * CASE, hauteur(c), (float(c.y) + 0.5) * CASE)

func poser_sol(c: Vector2i, niveau: int) -> void:
	if cases.has(c):
		cases[c]["n"] = niveau
	else:
		cases[c] = {"n": niveau, "r": false}

func effacer(c: Vector2i) -> void:
	cases.erase(c)
	_oter_pieces_sur(c)

func poser_route(c: Vector2i, oui: bool) -> void:
	if not cases.has(c):
		return
	cases[c]["r"] = oui
	if not oui:
		_oter_pieces_sur(c)

# --------------------------------------------------------- grosses pièces

func case_prise(c: Vector2i) -> bool:
	for p in pieces:
		if c.x >= int(p["i"]) and c.x < int(p["i"]) + int(p["w"]) \
				and c.y >= int(p["j"]) and c.y < int(p["j"]) + int(p["w"]):
			return true
	return false

## Ôte la grosse pièce qui couvre cette case, s'il y en a une.
func oter_piece(c: Vector2i) -> void:
	_oter_pieces_sur(c)

func _oter_pieces_sur(c: Vector2i) -> void:
	var restantes: Array = []
	for p in pieces:
		var dedans := c.x >= int(p["i"]) and c.x < int(p["i"]) + int(p["w"]) \
			and c.y >= int(p["j"]) and c.y < int(p["j"]) + int(p["w"])
		if not dedans:
			restantes.append(p)
	pieces = restantes

## Pose une grosse pièce si toutes ses cases sont de la terre au MÊME palier —
## un rond-point à cheval sur deux terrasses n'a aucun sens et le kit ne sait
## pas le dessiner.
func poser_piece(nom_tuile: String, coin: Vector2i, cote: int, quarts: int) -> bool:
	var niveau := palier(coin)
	for a in cote:
		for b in cote:
			var c := coin + Vector2i(a, b)
			if not terre(c) or palier(c) != niveau or case_prise(c):
				return false
	for a in cote:
		for b in cote:
			var c := coin + Vector2i(a, b)
			# Les bras d'un rond-point sont de la chaussée ; ses quartiers ne
			# le sont pas. Une courbe large, elle, n'occupe en chaussée que sa
			# colonne et sa rangée d'entrée — mais marquer tout le carré
			# fausserait le raccord des rues voisines.
			cases[c]["r"] = _piece_est_chaussee(nom_tuile, a, b, cote, quarts)
	pieces.append({"t": nom_tuile, "i": coin.x, "j": coin.y, "q": quarts, "w": cote})
	return true

func _piece_est_chaussee(nom_tuile: String, a: int, b: int, cote: int, quarts: int) -> bool:
	if nom_tuile == "road-roundabout":
		return a == 1 or b == 1            # la croix des bras, pas les coins
	# La courbe large : sans rotation, sa chaussée est la colonne de gauche.
	# Un quart de tour envoie l'ouest au sud (mesuré, pas deviné).
	var local := Vector2i(a, b)
	for _k in posmod(quarts, 4):
		local = Vector2i(cote - 1 - local.y, local.x)
	return local.x == 0

# ------------------------------------------------------------ raccordement

## Le masque des voisines en chaussée : 1 nord, 2 est, 4 sud, 8 ouest.
func masque(c: Vector2i) -> int:
	var m := 0
	for k in 4:
		if route(c + COTES[k]):
			m |= 1 << k
	return m

## LA TABLE DE PAVAGE. Elle part des orientations MESURÉES au banc (voir
## `outils/raccords.gd`) : `road-straight` va selon X, `road-bend` raccorde
## OUEST et SUD sans rotation, `road-intersection` raccorde OUEST, EST et SUD,
## `road-end-round` s'ouvre à l'EST. Le reste s'en déduit par le fait qu'un
## quart de tour en Y envoie l'ouest au SUD — pas l'inverse ; l'avoir deviné
## à l'œil nous a valu une ville entière de virages qui raccordaient le vide.
const PAVAGE := {
	0: ["road-square", 0],
	1: ["road-end-round", 1], 2: ["road-end-round", 0],
	4: ["road-end-round", 3], 8: ["road-end-round", 2],
	3: ["road-bend", 2], 6: ["road-bend", 1], 12: ["road-bend", 0], 9: ["road-bend", 3],
	5: ["road-straight", 1], 10: ["road-straight", 0],
	7: ["road-intersection", 1], 14: ["road-intersection", 0],
	13: ["road-intersection", 3], 11: ["road-intersection", 2],
	15: ["road-crossroad", 0],
}

## La tuile d'une case de rue : son nom et ses quarts de tour. `pente` dit si
## la case grimpe (une voisine en chaussée est un palier plus haut) — la rampe
## du kit monte d'exactement un palier sur une case, ce qui est la raison
## d'être du palier.
## ⚠ UNE RAMPE NE SE POSE QUE SUR UN TRONÇON DROIT, ET DANS LE SENS DE LA RUE.
## La première version regardait les quatre voisines : une rue qui LONGEAIT un
## talus voyait la terrasse d'à côté plus haute et se mettait à grimper en
## travers. Le kit n'a d'ailleurs pas de carrefour en pente : un croisement
## doit être de plain-pied, et c'est au dessin de s'en assurer.
func tuile(c: Vector2i) -> Array:
	var m := masque(c)
	var n := palier(c)
	# L'axe de la rue : seulement est-ouest (donc aucun bit nord/sud), ou
	# seulement nord-sud. Ça couvre les tronçons droits ET les bouts de rue —
	# une rampe qui s'arrête au bord de l'eau est parfaitement lisible, alors
	# qu'un carrefour en pente n'existe pas dans le kit.
	if (m & 5) == 0 or (m & 10) == 0:
		var axes: Array = [1, 3] if (m & 5) == 0 else [2, 0]   # est/ouest ou sud/nord
		for k in axes:
			var v: Vector2i = c + COTES[k]
			if not route(v): continue
			var ecart := palier(v) - n
			# `road-slant` monte d'un palier vers l'EST sans rotation,
			# `road-slant-high` de deux (mesuré au banc, `outils/pente.gd`).
			if ecart == 1: return ["road-slant", [3, 0, 1, 2][k]]
			if ecart == 2: return ["road-slant-high", [3, 0, 1, 2][k]]
	var fiche: Array = PAVAGE.get(m, ["road-straight", 0])
	return [String(fiche[0]), int(fiche[1])]

# ------------------------------------------------------------------ JSON

func vers_json() -> String:
	var plates: Dictionary = {}
	for c in cases.keys():
		plates["%d,%d" % [c.x, c.y]] = [int(cases[c]["n"]), 1 if cases[c]["r"] else 0]
	return JSON.stringify({
		"version": 1, "nom": nom, "case": CASE, "palier": PALIER,
		"cases": plates, "pieces": pieces, "objets": objets,
	}, "\t")

static func depuis_json(texte: String) -> CarteVille:
	var brut = JSON.parse_string(texte)
	var carte := CarteVille.new()
	if typeof(brut) != TYPE_DICTIONARY:
		push_warning("carte illisible")
		return carte
	carte.nom = String(brut.get("nom", "sans-titre"))
	for cle in Dictionary(brut.get("cases", {})).keys():
		var xy := String(cle).split(",")
		if xy.size() != 2: continue
		var f: Array = brut["cases"][cle]
		carte.cases[Vector2i(int(xy[0]), int(xy[1]))] = {"n": int(f[0]), "r": int(f[1]) != 0}
	carte.pieces = Array(brut.get("pieces", []))
	carte.objets = Array(brut.get("objets", []))
	return carte

## L'emprise de la carte, en cases. Sert à cadrer la caméra à l'ouverture :
## rouvrir sa carte et ne rien voir parce qu'on est resté à l'origine, c'est
## le premier reproche qu'on fait à un éditeur.
func emprise() -> Rect2i:
	if cases.is_empty():
		return Rect2i(0, 0, 1, 1)
	var mn: Vector2i = cases.keys()[0]
	var mx := mn
	for c in cases.keys():
		mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
		mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
	return Rect2i(mn, mx - mn + Vector2i.ONE)
