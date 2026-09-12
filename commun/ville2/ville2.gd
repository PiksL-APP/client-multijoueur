class_name Ville2
extends RefCounted
## LA VILLE, VERSION 2 — le modèle de données du cahier des charges du 12/09.
##
## Plus de grille de caractères. Une ville est faite de :
##   - un TERRAIN : une altitude par case (en unités 3D), de l'eau ou de la
##     terre, et le quartier auquel la case appartient ;
##   - des ROUTES : des polylignes de points sur la grille des cases, chacune
##     avec son genre (avenue, rue, voie rapide) et son nom ;
##   - des OUVRAGES : les grosses pièces du kit qui ne se déduisent pas d'un
##     raccord (rond-point 3 x 3, courbe large 2 x 2, rampe douce 2 x 1) ;
##   - des LOTS : un bâtiment = un modèle du kit posé TEL QUEL, à l'échelle
##     commune (une unité Kenney = une case), sur une grille de DEMI-cases.
##     « Le lot s'adapte au modèle, jamais l'inverse » (cahier, § 7) ;
##   - des OBJETS : lampadaires, feux, arbres, bancs, voitures garées… en
##     coordonnées libres (unités 3D), aimantés au sol ;
##   - des LIEUX de jeu : garages, cabines, planques, supérettes, arènes,
##     repaires, hôpitaux, gares ;
##   - le RAIL : des polylignes de voie et des gares.
##
## Tout est sauvé en JSON (`cartes/<nom>.json`) : l'éditeur Godot, l'éditeur
## du navigateur et le jeu lisent le même fichier.
##
## Le jeu, lui, continue de parler à `PlanVille`. `PlanV2` (commun/ville2/
## plan_v2.gd) répond à ses questions à partir d'ici ; pour les rues, il
## s'appuie sur `CarteVille` — la table de pavage MESURÉE au banc (quelle
## tuile, quel quart de tour) y vit déjà, et on ne la remesure pas.

const VERSION := 2
const CASE := CarteVille.CASE          ## 20 unités : une tuile Kenney
const PALIER := CarteVille.PALIER      ## 5 unités : une rampe du kit
const DEMI := CASE * 0.5               ## la grille de pose des lots

## Les genres de route. L'avenue a des feux et des arbres d'alignement, la rue
## des stops, la voie rapide des glissières et pas de trottoir.
const R_RUE := "rue"
const R_AVENUE := "avenue"
const R_VOIE_RAPIDE := "voie_rapide"

## Les genres de quartier du cahier (§ 3).
const Q_CENTRE := "centre"
const Q_PLAGE := "plage"
const Q_PAVILLONS := "pavillons"
const Q_INDUSTRIE := "industrie"
const Q_VIEILLE_VILLE := "vieille_ville"
const Q_CHAUD := "chaud"
const Q_CAMPUS := "campus"
const Q_BIDONVILLE := "bidonville"
const Q_PARC := "parc"
const Q_PORT := "port"

var nom := "sans-titre"
var graine := 1
var taille := Vector2i(40, 40)
## Une entrée par case, ligne par ligne (`j * taille.x + i`).
var altitude := PackedFloat32Array()   ## le sol, en unités 3D
var eau := PackedByteArray()           ## 1 : de l'eau
var quartier_de := PackedInt32Array()  ## l'indice dans `quartiers`, −1 : aucun
var quartiers: Array = []              ## [{nom, genre, gang}]
var routes: Array = []                 ## [{genre, nom, points: [Vector2i], niveau}]
var ouvrages: Array = []               ## [{t, i, j, q, w, h}]
var lots: Array = []                   ## [{m, x, y, w, h, q, genre}] en demi-cases
var objets: Array = []                 ## [{m, x, z, r, h, c}] en unités
var lieux: Array = []                  ## [{genre, x, z, ...}] en unités
var rail: Array = []                   ## [{points: [Vector2i], niveau}]
var gares: Array = []                  ## [{nom, x, z, principale}]

## La carte de rues dérivée (voir `rasteriser`). Le rendu et `PlanV2` lisent
## `carte.tuile(c)`, `carte.route(c)`, `carte.palier(c)`.
var carte: CarteVille
## Le lot qui couvre chaque case, −1 sinon (dérivé).
var _lot_de: PackedInt32Array
## Le genre de la route qui passe par chaque case ("" sinon), dérivé : la
## voie rapide l'emporte sur l'avenue, l'avenue sur la rue.
var _genre_de: PackedStringArray

func _init(t: Vector2i = Vector2i(40, 40)) -> void:
	redimensionner(t)

func redimensionner(t: Vector2i) -> void:
	taille = t
	var n := t.x * t.y
	altitude.resize(n)
	altitude.fill(0.0)
	eau.resize(n)
	eau.fill(0)
	quartier_de.resize(n)
	quartier_de.fill(-1)

# ------------------------------------------------------------------ cases

func dedans(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < taille.x and c.y < taille.y

func indice(c: Vector2i) -> int:
	return c.y * taille.x + c.x

func terre(c: Vector2i) -> bool:
	return dedans(c) and eau[indice(c)] == 0

func sol(c: Vector2i) -> float:
	return altitude[indice(c)] if dedans(c) else 0.0

func palier(c: Vector2i) -> int:
	return roundi(sol(c) / PALIER)

func poser_terre(c: Vector2i, y: float) -> void:
	if not dedans(c): return
	eau[indice(c)] = 0
	altitude[indice(c)] = y

func poser_eau(c: Vector2i) -> void:
	if not dedans(c): return
	eau[indice(c)] = 1

func quartier_en(c: Vector2i) -> int:
	return quartier_de[indice(c)] if dedans(c) else -1

func genre_du_quartier(c: Vector2i) -> String:
	var q := quartier_en(c)
	return String(quartiers[q]["genre"]) if q >= 0 and q < quartiers.size() else ""

func peindre_quartier(zone: Rect2i, q: int) -> void:
	for j in range(zone.position.y, zone.end.y):
		for i in range(zone.position.x, zone.end.x):
			if dedans(Vector2i(i, j)):
				quartier_de[j * taille.x + i] = q

# ------------------------------------------------------------------ routes

## Une route = une suite de points de grille reliés par des segments DROITS,
## horizontaux ou verticaux. Un segment en diagonale est refusé : le kit ne
## sait pas le paver. (L'éditeur, lui, découpe un tracé en escalier.)
func ajouter_route(genre: String, points: Array, nom_rue := "", niveau := 0) -> int:
	var pts: Array = []
	for p in points:
		pts.append(Vector2i(p))
	for k in range(1, pts.size()):
		var a: Vector2i = pts[k - 1]
		var b: Vector2i = pts[k]
		if a.x != b.x and a.y != b.y:
			push_warning("route « %s » : segment en diagonale %s -> %s, refusé" % [nom_rue, a, b])
			return -1
	routes.append({"genre": genre, "nom": nom_rue, "points": pts, "niveau": niveau})
	return routes.size() - 1

## Toutes les cases d'une route, dans l'ordre du tracé.
static func cases_de_route(r: Dictionary) -> Array:
	var pts: Array = r["points"]
	var cases: Array = []
	if pts.is_empty(): return cases
	cases.append(Vector2i(pts[0]))
	for k in range(1, pts.size()):
		var a := Vector2i(pts[k - 1])
		var b := Vector2i(pts[k])
		var d := (b - a).sign()
		var c := a
		while c != b:
			c += d
			cases.append(c)
	return cases

# ------------------------------------------------------------------ lots

## Un lot en DEMI-cases : `x`,`y` son coin nord-ouest, `w`,`h` son emprise
## déjà tournée. Le modèle est posé au centre du lot, à l'échelle CASE.
func ajouter_lot(modele: String, x: int, y: int, w: int, h: int, quarts: int, genre := "") -> int:
	lots.append({"m": modele, "x": x, "y": y, "w": w, "h": h, "q": quarts, "genre": genre})
	return lots.size() - 1

## Le centre d'un lot, en unités 3D (le sol vient de la case du centre).
func centre_du_lot(l: Dictionary) -> Vector3:
	var cx := (float(l["x"]) + float(l["w"]) * 0.5) * DEMI
	var cz := (float(l["y"]) + float(l["h"]) * 0.5) * DEMI
	var c := Vector2i(floori(cx / CASE), floori(cz / CASE))
	return Vector3(cx, float(palier(c)) * PALIER, cz)

## Les cases (entières) que couvre un lot.
static func cases_du_lot(l: Dictionary) -> Array:
	var cases: Array = []
	var i0 := floori(float(l["x"]) * 0.5)
	var j0 := floori(float(l["y"]) * 0.5)
	var i1 := ceili((float(l["x"]) + float(l["w"])) * 0.5)
	var j1 := ceili((float(l["y"]) + float(l["h"])) * 0.5)
	for j in range(j0, j1):
		for i in range(i0, i1):
			cases.append(Vector2i(i, j))
	return cases

func lot_sur(c: Vector2i) -> int:
	if _lot_de.is_empty() or not dedans(c): return -1
	return _lot_de[indice(c)]

# ------------------------------------------------------------------ objets

## `h` : la hauteur voulue en unités (0 : celle du catalogue) ; `r` en radians.
func ajouter_objet(modele: String, x: float, z: float, r := 0.0, h := 0.0, teinte := "") -> void:
	var o := {"m": modele, "x": x, "z": z, "r": r, "h": h}
	if teinte != "": o["c"] = teinte
	objets.append(o)

func ajouter_lieu(genre: String, x: float, z: float, extra := {}) -> void:
	var l := {"genre": genre, "x": x, "z": z}
	l.merge(extra)
	lieux.append(l)

# ------------------------------------------------------------------ dérivés

## Reconstruit `carte` (les rues en cases, avec paliers et grosses pièces) et
## `_lot_de`. À rappeler après toute modification du modèle.
func rasteriser() -> CarteVille:
	carte = CarteVille.new()
	carte.nom = nom
	for j in taille.y:
		for i in taille.x:
			var c := Vector2i(i, j)
			if terre(c):
				carte.poser_sol(c, palier(c))
	_genre_de.resize(taille.x * taille.y)
	_genre_de.fill("")
	for r in routes:
		var g := String(r["genre"])
		for c in cases_de_route(r):
			if carte.terre(c):
				carte.poser_route(c, true)
			if dedans(c):
				var k := indice(c)
				var ici := _genre_de[k]
				if ici == "" or g == R_VOIE_RAPIDE or (g == R_AVENUE and ici == R_RUE):
					_genre_de[k] = g
	for o in ouvrages:
		carte.poser_piece(String(o["t"]), Vector2i(int(o["i"]), int(o["j"])),
			Vector2i(int(o["w"]), int(o.get("h", o["w"]))), int(o["q"]),
			String(o["t"]).begins_with("road-slant"))
	_lot_de.resize(taille.x * taille.y)
	_lot_de.fill(-1)
	for k in lots.size():
		for c in cases_du_lot(lots[k]):
			if dedans(c):
				_lot_de[indice(c)] = k
	return carte

## Le genre de la route qui passe par cette case ("" si aucune).
func genre_de_route(c: Vector2i) -> String:
	if _genre_de.is_empty() or not dedans(c): return ""
	return _genre_de[indice(c)]

# ------------------------------------------------------------------ JSON

func vers_json() -> String:
	var rts: Array = []
	for r in routes:
		var pts: Array = []
		for p in r["points"]:
			pts.append([int((p as Vector2i).x), int((p as Vector2i).y)])
		rts.append({"genre": r["genre"], "nom": r["nom"], "points": pts, "niveau": int(r["niveau"])})
	var rl: Array = []
	for r in rail:
		var pts: Array = []
		for p in r["points"]:
			pts.append([int((p as Vector2i).x), int((p as Vector2i).y)])
		rl.append({"points": pts, "niveau": int(r.get("niveau", 0))})
	var alt: Array = []
	for a in altitude: alt.append(snappedf(a, 0.01))
	var e: Array = []
	for b in eau: e.append(int(b))
	var q: Array = []
	for b in quartier_de: q.append(int(b))
	return JSON.stringify({
		"version": VERSION, "nom": nom, "graine": graine,
		"taille": [taille.x, taille.y], "case": CASE, "palier": PALIER,
		"altitude": alt, "eau": e, "quartier_de": q, "quartiers": quartiers,
		"routes": rts, "ouvrages": ouvrages, "lots": lots, "objets": objets,
		"lieux": lieux, "rail": rl, "gares": gares,
	})

static func depuis_json(texte: String) -> Ville2:
	var brut = JSON.parse_string(texte)
	if typeof(brut) != TYPE_DICTIONARY:
		push_warning("ville v2 illisible")
		return Ville2.new()
	var t: Array = brut.get("taille", [40, 40])
	var v := Ville2.new(Vector2i(int(t[0]), int(t[1])))
	v.nom = String(brut.get("nom", "sans-titre"))
	v.graine = int(brut.get("graine", 1))
	var alt: Array = brut.get("altitude", [])
	for k in mini(alt.size(), v.altitude.size()): v.altitude[k] = float(alt[k])
	var e: Array = brut.get("eau", [])
	for k in mini(e.size(), v.eau.size()): v.eau[k] = int(e[k])
	var q: Array = brut.get("quartier_de", [])
	for k in mini(q.size(), v.quartier_de.size()): v.quartier_de[k] = int(q[k])
	v.quartiers = Array(brut.get("quartiers", []))
	for r in Array(brut.get("routes", [])):
		var pts: Array = []
		for p in r["points"]: pts.append(Vector2i(int(p[0]), int(p[1])))
		v.routes.append({"genre": String(r["genre"]), "nom": String(r.get("nom", "")),
			"points": pts, "niveau": int(r.get("niveau", 0))})
	for r in Array(brut.get("rail", [])):
		var pts: Array = []
		for p in r["points"]: pts.append(Vector2i(int(p[0]), int(p[1])))
		v.rail.append({"points": pts, "niveau": int(r.get("niveau", 0))})
	v.ouvrages = Array(brut.get("ouvrages", []))
	v.lots = Array(brut.get("lots", []))
	v.objets = Array(brut.get("objets", []))
	v.lieux = Array(brut.get("lieux", []))
	v.gares = Array(brut.get("gares", []))
	v.rasteriser()
	return v

static func charger(chemin: String) -> Ville2:
	if not FileAccess.file_exists(chemin):
		push_warning("ville introuvable : " + chemin)
		return Ville2.new()
	return depuis_json(FileAccess.get_file_as_string(chemin))

func enregistrer(chemin: String) -> bool:
	DirAccess.make_dir_recursive_absolute(chemin.get_base_dir())
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	if f == null: return false
	f.store_string(vers_json())
	return true
