class_name GenerateurCentre
extends RefCounted
## LE QUARTIER TÉMOIN : LE CENTRE. Tours, avenue, place, gare — cahier § 11.
##
## Ordre du cahier (§ 10) : terrain → côtes → axes → quartiers → rues → lots →
## détails. Ici le terrain est un plateau (§ 4 : « en ville, pas de pente sous
## les quartiers bâtis »), les axes sont deux avenues qui se croisent près de
## la place, les rues une grille (§ 5 : « grille au centre »), les lots sont
## remplis pâté par pâté avec les modèles du kit posés tels quels, et les
## détails — feux, stops, lampadaires, arbres d'alignement, bancs, voitures
## garées — suivent les règles du cahier § 5 et § 8.
##
## Tout est piloté par une graine et des curseurs ; relancer avec la même
## graine redonne la même ville.

## Les courbes larges et le rond-point (cahier § 5) : brique commune, appelée
## par `preload` — un `class_name` neuf n'existe pas dans l'export web.
const ANGLES := preload("res://commun/ville2/angles.gd")

const CASE := Ville2.CASE
const DEMI := Ville2.DEMI

## Les positions MESURÉES du mobilier sur une tuile de rue, en cases depuis le
## centre de la tuile (reprises de `Quartiers`, validées à l'image) : le coin
## du trottoir, et le bord d'un tronçon droit.
const COIN := 0.38
const BORD := 0.42
## Où se gare une voiture : contre le trottoir, sur la bande de chaussée.
const STATIONNEMENT := 0.21

## Les quatre côtés d'un pâté et le quart de tour qui met la FAÇADE (−Z du
## modèle) vers ce côté : nord 0, est 3, sud 2, ouest 1.
const VERS := {"n": 0, "e": 3, "s": 2, "o": 1}

const PRENOMS_RUES := ["de la Gare", "des Lilas", "Victor-Hugo", "de la République",
	"du Commerce", "des Halles", "Pasteur", "de Verdun", "Jean-Jaurès", "du Port",
	"des Écoles", "Gambetta", "de la Paix", "Molière", "des Tanneurs", "Saint-Michel"]

static func generer(graine := 1, taille := Vector2i(40, 40), curseurs := {}) -> Ville2:
	var v := Ville2.new(taille)
	v.nom = String(curseurs.get("nom", "temoin-centre"))
	v.graine = graine
	var alea := RandomNumberGenerator.new()
	alea.seed = graine
	var pas := int(curseurs.get("pas", 5))            # une rue toutes les 5 cases
	var densite := float(curseurs.get("densite", 1.0))

	# 1. Le terrain : un plateau à zéro. (Les côtes viendront avec le 2e témoin.)
	for j in taille.y:
		for i in taille.x:
			v.poser_terre(Vector2i(i, j), 0.0)

	# 2. Le quartier : tout le témoin est « Le Centre ».
	v.quartiers.append({"nom": "Le Centre", "genre": Ville2.Q_CENTRE, "gang": -1})
	v.peindre_quartier(Rect2i(Vector2i.ZERO, taille), 0)

	# 3. Les axes et les rues : une grille de période `pas`, deux avenues.
	var xs: Array[int] = []
	var x := 2
	while x < taille.x - 1:
		xs.append(x)
		x += pas
	var ys: Array[int] = []
	var y := 2
	while y < taille.y - 1:
		ys.append(y)
		y += pas
	# Le pâté du milieu et ses voisins : la place au centre, la gare au nord.
	var kx := xs.size() / 2          # l'indice de la rue au centre
	var ky := ys.size() / 2
	var avenues_x: Array[int] = [xs[kx - 1], xs[kx]]
	var avenues_y: Array[int] = [ys[ky]]
	# La place : deux pâtés fusionnés à l'ouest de l'avenue centrale, juste au
	# nord de l'avenue est-ouest. La rue qui les séparait est effacée.
	var place := Rect2i(xs[kx - 2] + 1, ys[ky - 1] + 1, 2 * pas - 1, pas - 1)
	# La gare : deux pâtés fusionnés au nord, jusqu'au bord — la voie ferrée
	# passe derrière le hall, les quais entre les deux.
	var gare := Rect2i(xs[kx - 2] + 1, 0, 2 * pas - 1, ys[1])

	var nx := 0
	for xr in xs:
		var genre := Ville2.R_AVENUE if xr in avenues_x else Ville2.R_RUE
		var nom_rue: String = ("Avenue " if genre == Ville2.R_AVENUE else "Rue ") + String(PRENOMS_RUES[nx % PRENOMS_RUES.size()])
		nx += 1
		# Une rue coupée par la place ou la gare est tracée en deux morceaux.
		var trous: Array = []
		if xr > place.position.x and xr < place.end.x:
			trous.append([place.position.y, place.end.y - 1])
		if xr > gare.position.x and xr < gare.end.x:
			trous.append([gare.position.y, gare.end.y - 1])
		trous.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
		for s in _segments(trous, taille.y):
			v.ajouter_route(genre, [Vector2i(xr, int(s[0])), Vector2i(xr, int(s[1]))], nom_rue)
	for yr in ys:
		var genre := Ville2.R_AVENUE if yr in avenues_y else Ville2.R_RUE
		var nom_rue: String = ("Avenue " if genre == Ville2.R_AVENUE else "Rue ") + String(PRENOMS_RUES[nx % PRENOMS_RUES.size()])
		nx += 1
		var trous: Array = []
		if yr > gare.position.y and yr < gare.end.y:
			trous.append([gare.position.x, gare.end.x - 1])
		for s in _segments(trous, taille.x):
			v.ajouter_route(genre, [Vector2i(int(s[0]), yr), Vector2i(int(s[1]), yr)], nom_rue)

	# 4. La voie ferrée : le long du bord nord, à une case de la première rue.
	v.rail.append({"points": [Vector2i(0, 1), Vector2i(taille.x - 1, 1)], "niveau": 0})
	v.rasteriser()

	# 4 bis. LE ROND-POINT ET LES COURBES LARGES (cahier § 5), AVANT LES LOTS :
	# une grosse pièce mange trois cases sur trois, et un immeuble déjà posé
	# dessus la ferait refuser. Le rond-point va au croisement d'avenues le plus
	# loin de la place — au centre il y a déjà la fontaine, et deux ronds-points
	# à trois cases l'un de l'autre feraient un circuit.
	var loin := Vector2i(-1, -1)
	var mieux := -1.0
	for ax in avenues_x:
		for ay in avenues_y:
			var d := Vector2(float(ax), float(ay)).distance_to(
				Vector2(float(place.position.x), float(place.position.y)))
			if d > mieux:
				mieux = d
				loin = Vector2i(int(ax), int(ay))
	if loin.x >= 0:
		ANGLES.rond_point(v, loin)
	ANGLES.arrondir(v, alea, 0.8)
	v.rasteriser()

	# 5. Les lots, pâté par pâté.
	var pates: Array = []
	for a in range(xs.size() - 1):
		for b in range(ys.size() - 1):
			var r := Rect2i(xs[a] + 1, ys[b] + 1, xs[a + 1] - xs[a] - 1, ys[b + 1] - ys[b] - 1)
			if r.intersects(place) or r.intersects(gare): continue
			pates.append(r)
	# Les tours : autour de la place et de l'avenue centrale.
	var tours: Array = []
	for r in pates:
		var dx := absi(r.position.x - place.position.x)
		var dy := absi(r.position.y - place.position.y)
		if (dx <= pas and dy <= pas) and not r.position == place.position:
			tours.append(r)
	for r in pates:
		if r in tours:
			_pate_de_tours(v, r, alea)
		else:
			_pate_d_immeubles(v, r, alea, densite)
	_la_place(v, place, alea)
	_la_gare(v, gare, alea)
	v.rasteriser()

	# 6. Les détails de rue.
	_mobilier(v, alea, avenues_x, avenues_y)
	_voitures_garees(v, alea, place, gare)
	_panneaux_pub(v, alea, avenues_x, avenues_y, pas)
	v.rasteriser()
	return v

## Les morceaux d'une rue de 0 à `longueur − 1`, une fois ôtés les `trous`
## ([début, fin] inclus). Un morceau d'une seule case ne vaut pas une rue.
static func _segments(trous: Array, longueur: int) -> Array:
	var debut := 0
	var segments: Array = []
	for t in trous:
		if int(t[0]) - 1 - debut >= 1:
			segments.append([debut, int(t[0]) - 1])
		debut = int(t[1]) + 1
	if longueur - 1 - debut >= 1:
		segments.append([debut, longueur - 1])
	return segments

# ------------------------------------------------------------------ pâtés

## Un pâté d'immeubles : les façades sur les quatre rues, une cour au milieu.
## Chaque modèle est posé à sa taille ; on avance le long du trottoir d'autant.
static func _pate_d_immeubles(v: Ville2, r: Rect2i, alea: RandomNumberGenerator, densite: float) -> void:
	var occupe: Dictionary = {}
	var hx0 := r.position.x * 2
	var hy0 := r.position.y * 2
	var hx1 := r.end.x * 2
	var hy1 := r.end.y * 2
	var choix: Array = KitVille2.IMMEUBLES.duplicate()
	choix.append_array(KitVille2.COMMERCES)
	# Nord et sud : on marche selon X.
	for cote in ["n", "s"]:
		var q: int = VERS[cote]
		var hx := hx0
		while hx < hx1:
			var m := _modele_qui_tient(choix, q, hx1 - hx, alea)
			if m == "":
				hx += 1
				continue
			var e := KitVille2.emprise_tournee(m, q)
			var hy := hy0 if cote == "n" else hy1 - e.y
			if _libre(occupe, hx, hy, e) and alea.randf() < densite:
				_prendre(occupe, hx, hy, e)
				v.ajouter_lot(m, hx, hy, e.x, e.y, q, "immeuble")
			hx += e.x
	# Est et ouest : on marche selon Y, entre les coins déjà pris.
	for cote in ["o", "e"]:
		var q: int = VERS[cote]
		var hy := hy0
		while hy < hy1:
			var m := _modele_qui_tient(choix, q, hy1 - hy, alea)
			if m == "":
				hy += 1
				continue
			var e := KitVille2.emprise_tournee(m, q)
			var hx := hx0 if cote == "o" else hx1 - e.x
			if _libre(occupe, hx, hy, e) and alea.randf() < densite:
				_prendre(occupe, hx, hy, e)
				v.ajouter_lot(m, hx, hy, e.x, e.y, q, "immeuble")
				hy += e.y
			else:
				hy += 1
	# La cour (cahier § 3 : « parkings et arrière-cours, jardins intérieurs ») :
	# un pâté sur deux a un parking (voitures, bennes, escalier de secours en
	# moins), l'autre un jardin (pelouse, arbres, banc).
	var cx := (float(hx0 + hx1) * 0.5) * DEMI
	var cz := (float(hy0 + hy1) * 0.5) * DEMI
	if (r.position.x + r.position.y) % 2 == 0:
		for k in 3:
			if alea.randf() < 0.75:
				v.ajouter_objet(KitVille2.VOITURES[alea.randi() % KitVille2.VOITURES.size()],
					cx - 9.0 + float(k) * 9.0, cz + 7.0, PI * 0.5 + alea.randf_range(-0.05, 0.05))
		v.ajouter_objet("benne", cx - 12.0, cz - 9.0, 0.0)
		v.ajouter_objet("benne", cx - 7.0, cz - 9.0, 0.0)
		v.ajouter_objet("poubelle", cx + 12.0, cz - 9.0, alea.randf() * TAU)
		v.ajouter_objet("arbre_oak", cx + 11.0, cz + 2.0, alea.randf() * TAU)
	else:
		v.objets.append({"m": "pelouse", "x": cx, "z": cz, "r": 0.0, "h": 0.0, "w": 30.0, "d": 30.0})
		v.ajouter_objet("arbre", cx - 8.0, cz - 7.0, alea.randf() * TAU)
		v.ajouter_objet("arbre_rond", cx + 9.0, cz + 6.0, alea.randf() * TAU)
		v.ajouter_objet("buisson", cx + 8.0, cz - 9.0, alea.randf() * TAU)
		v.ajouter_objet("banc", cx - 6.0, cz + 8.0, PI)
		v.ajouter_objet("lampadaire_parc", cx + 2.0, cz - 2.0, alea.randf() * TAU)

## Un pâté de tours : deux tours au plus, le reste en immeubles hauts.
static func _pate_de_tours(v: Ville2, r: Rect2i, alea: RandomNumberGenerator) -> void:
	var occupe: Dictionary = {}
	var hx0 := r.position.x * 2
	var hy0 := r.position.y * 2
	var hx1 := r.end.x * 2
	var hy1 := r.end.y * 2
	var tours: Array = KitVille2.TOURS.duplicate()
	# Une tour sur la diagonale sud-ouest / nord-est, avec sa marge de trottoir.
	var m1: String = tours[alea.randi() % tours.size()]
	var e1 := KitVille2.emprise_tournee(m1, 2)
	_prendre(occupe, hx0 + 1, hy1 - e1.y - 1, e1)
	v.ajouter_lot(m1, hx0 + 1, hy1 - e1.y - 1, e1.x, e1.y, 2, "tour")
	var m2: String = tours[alea.randi() % tours.size()]
	if m2 == m1: m2 = tours[(alea.randi() + 1) % tours.size()]
	var e2 := KitVille2.emprise_tournee(m2, 0)
	if _libre(occupe, hx1 - e2.x - 1, hy0 + 1, e2):
		_prendre(occupe, hx1 - e2.x - 1, hy0 + 1, e2)
		v.ajouter_lot(m2, hx1 - e2.x - 1, hy0 + 1, e2.x, e2.y, 0, "tour")
	# Les deux autres coins : un immeuble haut chacun.
	var hauts: Array = KitVille2.IMMEUBLES_HAUTS
	var m3 := _modele_qui_tient(hauts, 0, hx1 - hx0 - e2.x - 1, alea)
	if m3 != "":
		var e3 := KitVille2.emprise_tournee(m3, 0)
		if _libre(occupe, hx0, hy0, e3):
			_prendre(occupe, hx0, hy0, e3)
			v.ajouter_lot(m3, hx0, hy0, e3.x, e3.y, 0, "immeuble")
	var m4 := _modele_qui_tient(hauts, 2, hx1 - hx0 - e1.x - 1, alea)
	if m4 != "":
		var e4 := KitVille2.emprise_tournee(m4, 2)
		if _libre(occupe, hx1 - e4.x, hy1 - e4.y, e4):
			_prendre(occupe, hx1 - e4.x, hy1 - e4.y, e4)
			v.ajouter_lot(m4, hx1 - e4.x, hy1 - e4.y, e4.x, e4.y, 2, "immeuble")
	# Le parvis des tours : arbres et bancs.
	var cx := (float(hx0 + hx1) * 0.5) * DEMI
	var cz := (float(hy0 + hy1) * 0.5) * DEMI
	v.ajouter_objet("arbre_rond", cx - 3.0, cz + 2.0, alea.randf() * TAU)
	v.ajouter_objet("banc", cx + 4.0, cz - 3.0, PI * 0.5)
	v.ajouter_objet("lampadaire_parc", cx + 1.0, cz - 6.0, 0.0)

## Le modèle dont la FAÇADE (largeur tournée) tient dans `longueur` demi-cases.
static func _modele_qui_tient(choix: Array, q: int, longueur: int, alea: RandomNumberGenerator) -> String:
	var candidats: Array = []
	for m in choix:
		if KitVille2.emprise_tournee(String(m), q).x <= longueur:
			candidats.append(m)
	if candidats.is_empty(): return ""
	return String(candidats[alea.randi() % candidats.size()])

static func _libre(occupe: Dictionary, hx: int, hy: int, e: Vector2i) -> bool:
	for b in e.y:
		for a in e.x:
			if occupe.has(Vector2i(hx + a, hy + b)): return false
	return true

static func _prendre(occupe: Dictionary, hx: int, hy: int, e: Vector2i) -> void:
	for b in e.y:
		for a in e.x:
			occupe[Vector2i(hx + a, hy + b)] = true

# ------------------------------------------------------------------ la place

## La grande place : une fontaine au milieu (la tuile-fontaine du kit), des
## bancs et des arbres tout autour, des lampadaires de parc.
static func _la_place(v: Ville2, place: Rect2i, alea: RandomNumberGenerator) -> void:
	var cx := (float(place.position.x) + float(place.size.x) * 0.5) * CASE
	var cz := (float(place.position.y) + float(place.size.y) * 0.5) * CASE
	# La fontaine occupe une case entière du kit : on la centre sur une case.
	var fc := Vector2i(floori(cx / CASE), floori(cz / CASE))
	var fx := (float(fc.x) + 0.5) * CASE
	var fz := (float(fc.y) + 0.5) * CASE
	v.ajouter_objet("res://modeles/ville/pavement-fountain.glb", fx, fz, 0.0)
	# Quatre lampadaires de parc autour de la fontaine, des bancs entre eux.
	for k in 4:
		var a := PI * 0.25 + PI * 0.5 * float(k)
		v.ajouter_objet("lampadaire_parc", fx + cos(a) * 1.3 * CASE, fz + sin(a) * 1.3 * CASE, -a)
		var b := PI * 0.5 * float(k)
		v.ajouter_objet("banc", fx + cos(b) * 1.1 * CASE, fz + sin(b) * 1.1 * CASE, -b + PI * 0.5)
	# Deux pelouses avec leur statue, aux deux bouts de la place.
	for s in [-1.0, 1.0]:
		var px: float = cx + float(s) * 2.6 * CASE
		v.objets.append({"m": "pelouse", "x": px, "z": cz, "r": 0.0, "h": 0.0, "w": 2.2 * CASE, "d": 1.6 * CASE})
		v.ajouter_objet("monument" if s < 0.0 else "statue", px, cz, 0.0)
		for k in 4:
			var a := PI * 0.25 + PI * 0.5 * float(k)
			v.ajouter_objet("buisson", px + cos(a) * 0.9 * CASE, cz + sin(a) * 0.6 * CASE, alea.randf() * TAU)
		# UN MASSIF DE FLEURS ET UNE ALLÉE DE DALLES (kit nature) : une pelouse
		# nue est un tapis vert, pas un jardin.
		for k in 10:
			v.ajouter_objet(FLEURS[alea.randi() % FLEURS.size()],
				px + alea.randf_range(-1.0, 1.0) * CASE,
				cz + alea.randf_range(-0.7, 0.7) * CASE, alea.randf() * TAU, 0.9)
		for k in 5:
			v.ajouter_objet("nature/path_stone", px - CASE + float(k) * 0.5 * CASE,
				cz + 0.75 * CASE, 0.0)
	# Les terrasses (cahier § 8 : « activités : bancs, terrasses ») le long du
	# côté est, face à l'avenue : parasols du kit et bancs, deux rangs.
	var xe := (float(place.end.x) - 0.7) * CASE
	for k in range(place.position.y, place.end.y):
		var az := (float(k) + 0.5) * CASE
		v.ajouter_objet("parasol", xe, az - 4.0, alea.randf() * TAU)
		v.ajouter_objet("parasol", xe - 7.0, az + 4.0, alea.randf() * TAU)
		v.ajouter_objet("banc", xe - 3.5, az, PI * 0.5)
	# Des jardinières aux quatre coins.
	for sx in [0.35, float(place.size.x) - 0.35]:
		for sy in [0.35, float(place.size.y) - 0.35]:
			v.ajouter_objet("res://modeles/kenney/pavillons/planter.glb",
				(float(place.position.x) + sx) * CASE, (float(place.position.y) + sy) * CASE, 0.0)
	# Une rangée d'arbres et de bancs le long des deux grands côtés.
	for k in range(place.position.x, place.end.x):
		var ax := (float(k) + 0.5) * CASE
		if k % 2 == 0:
			v.ajouter_objet("arbre", ax, (float(place.position.y) + 0.5) * CASE, alea.randf() * TAU)
			v.ajouter_objet("arbre", ax, (float(place.end.y) - 0.5) * CASE, alea.randf() * TAU)
		else:
			v.ajouter_objet("banc", ax, (float(place.position.y) + 0.5) * CASE, 0.0)
			v.ajouter_objet("banc", ax, (float(place.end.y) - 0.5) * CASE, PI)
			v.ajouter_objet("poubelle", ax + 5.0, (float(place.position.y) + 0.5) * CASE, 0.0)

# ------------------------------------------------------------------ la gare

## La gare : le grand hall du kit face à la rue, les quais derrière, la voie
## le long du bord. Un parvis avec taxis.
static func _la_gare(v: Ville2, gare: Rect2i, alea: RandomNumberGenerator) -> void:
	# Le hall est le modèle du client (`modeles/piksl/gare.glb`, 160 x 63
	# unités, façade vers −Z) : posé tel quel, façade au sud, l'auvent des
	# quais vers la voie.
	var m := "piksl/gare"
	var e := KitVille2.emprise_tournee(m, 2)
	var hx := gare.position.x * 2 + (gare.size.x * 2 - e.x) / 2
	var hy := gare.end.y * 2 - e.y - 2          # un parvis d'une case devant
	v.ajouter_lot(m, hx, hy, e.x, e.y, 2, "gare")
	var cx := (float(hx) + float(e.x) * 0.5) * DEMI
	v.gares.append({"nom": "Gare centrale", "x": cx, "z": (float(hy) + float(e.y) * 0.5) * DEMI, "principale": true})
	v.ajouter_lieu("gare", cx, float(gare.end.y) * CASE + 0.5 * CASE)
	# Les quais : entre l'auvent et la voie, bancs et lampadaires en file.
	var zq := (float(gare.position.y) + 2.2) * CASE
	for k in range(gare.position.x, gare.end.x):
		if k % 2 == 0:
			v.ajouter_objet("lampadaire", (float(k) + 0.5) * CASE, zq, 0.0)
		else:
			v.ajouter_objet("banc", (float(k) + 0.5) * CASE, zq + 3.0, 0.0)
	# Le parvis : des arbres aux deux bouts, des bancs, les taxis en file.
	var zp := (float(gare.end.y) - 0.5) * CASE
	for k in [gare.position.x, gare.position.x + 1, gare.end.x - 2, gare.end.x - 1]:
		v.ajouter_objet("arbre_rond", (float(k) + 0.5) * CASE, zp, alea.randf() * TAU)
	for k in range(gare.position.x + 2, gare.end.x - 2, 2):
		v.ajouter_objet("banc", (float(k) + 0.5) * CASE, zp - 4.0, 0.0)
		v.ajouter_objet("lampadaire", (float(k) + 1.5) * CASE, zp + 3.0, 0.0)
	var zt := (float(gare.end.y) + 0.5) * CASE
	for k in 4:
		v.ajouter_objet("voitures/taxi", cx - 12.0 + float(k) * 7.0, zt - STATIONNEMENT * CASE, PI)
	v.ajouter_lieu("taxis", cx, zt)

# ------------------------------------------------------------------ mobilier

## Feux aux carrefours d'avenues, stops aux petites rues, lampadaires à chaque
## coin, arbres d'alignement le long des avenues, plaques de rue (§ 5).
## Les arbres d'alignement et le petit mobilier de trottoir : deux tirages
## dans le kit élargi plutôt que deux modèles en dur.
## Les fleurs des massifs — le kit nature en a neuf, on en prend six.
const FLEURS := ["nature/flower_redA", "nature/flower_redC", "nature/flower_yellowB",
	"nature/flower_yellowC", "nature/flower_purpleA", "nature/flower_purpleC"]

const ALIGNEMENT := ["arbre_oak", "arbre_rond", "arbre", "arbre_plateau", "arbre_fin",
	"nature/tree_pineRoundC"]
const TROTTOIR := ["poubelle", "borne", "buisson_grand", "pot", "herbes"]

static func _mobilier(v: Ville2, alea: RandomNumberGenerator, avenues_x: Array, avenues_y: Array) -> void:
	var carte := v.carte
	var coins := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			if not carte.route(c) or carte.case_prise(c): continue
			var m := carte.masque(c)
			var centre := Vector2((float(i) + 0.5) * CASE, (float(j) + 0.5) * CASE)
			var branches := 0
			for k in 4:
				if m & (1 << k): branches += 1
			var avenue := (i in avenues_x) or (j in avenues_y)
			if branches >= 3:
				# Un carrefour : un lampadaire à chaque coin qui touche un
				# trottoir, et le feu ou le stop selon l'avenue.
				var grand := (i in avenues_x) and (j in avenues_y)
				for k in 4:
					var d: Vector2 = coins[k]
					var ou := centre + d * COIN * CASE
					# Le coin est pris par une rue voisine ? Rien.
					var vx := c + Vector2i(int(d.x), 0)
					var vy := c + Vector2i(0, int(d.y))
					if carte.route(vx) and carte.route(vy): continue
					# Le feu regarde le carrefour ; le lampadaire est sur le coin.
					var tourne := atan2(-d.x, -d.y)
					if grand:
						v.ajouter_objet("feu", ou.x, ou.y, tourne + PI)
					elif avenue and k % 2 == 0:
						v.ajouter_objet("lampadaire", ou.x, ou.y, tourne)
						if not (i in avenues_x): v.ajouter_objet("stop", ou.x + d.x * 2.0, ou.y - d.y * 2.0, tourne + PI * 0.5)
					else:
						if k % 2 == 0: v.ajouter_objet("lampadaire", ou.x, ou.y, tourne)
						else: v.ajouter_objet("plaque", ou.x, ou.y, tourne)
			elif m == 5 or m == 10:
				# Un tronçon droit : arbres d'alignement sur les avenues, un
				# lampadaire une case sur trois sur les rues.
				var selon_x := m == 10
				var normale := Vector2(0, 1) if selon_x else Vector2(1, 0)
				var pair := (i + j) % 3 == 0
				for s in [-1.0, 1.0]:
					var bord: Vector2 = centre + normale * float(s) * BORD * CASE
					if avenue and (i + j) % 2 == 0:
						# ⚠ UNE AVENUE N'EST PAS PLANTÉE D'UN SEUL ARBRE. Deux
						# essences en alternance, c'est un décor ; le kit nature
						# en a trois cents, on en prend six.
						v.ajouter_objet(ALIGNEMENT[alea.randi() % ALIGNEMENT.size()],
							bord.x, bord.y, alea.randf() * TAU)
					elif pair and s > 0.0:
						var lampe := "lampadaire_double" if avenue else "lampadaire"
						v.ajouter_objet(lampe, bord.x, bord.y,
							(PI * 0.5 if selon_x else 0.0) + (PI if s > 0 else 0.0))
					elif (i + j) % 7 == 0 and s < 0.0 and not avenue:
						# Un peu de vie de trottoir : poubelle, borne, cabine.
						v.ajouter_objet(TROTTOIR[alea.randi() % TROTTOIR.size()],
							bord.x, bord.y, alea.randf() * TAU)

## Quelques voitures garées le long des rues, contre le trottoir, dans le sens
## de la rue — « stationnement modéré » (§ 8).
static func _voitures_garees(v: Ville2, alea: RandomNumberGenerator, place: Rect2i, gare: Rect2i) -> void:
	var carte := v.carte
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			if not carte.route(c) or carte.case_prise(c): continue
			var m := carte.masque(c)
			if m != 5 and m != 10: continue
			if alea.randf() > 0.22: continue
			var selon_x := m == 10
			var s := -1.0 if alea.randf() < 0.5 else 1.0
			var centre := Vector2((float(i) + 0.5) * CASE, (float(j) + 0.5) * CASE)
			var normale := Vector2(0, 1) if selon_x else Vector2(1, 0)
			var ou: Vector2 = centre + normale * s * STATIONNEMENT * CASE
			# Le sens de la voie : à droite dans son sens de marche.
			var angle := (0.0 if s > 0.0 else PI) if selon_x else (PI * 0.5 if s < 0.0 else -PI * 0.5)
			v.ajouter_objet(KitVille2.VOITURES[alea.randi() % KitVille2.VOITURES.size()], ou.x, ou.y, angle)

# ------------------------------------------------------------------ les panneaux pub

## LES 24 VISUELS (cahier § 7). DEUX POSES, ET DEUX SEULEMENT :
##   - SUR UN TOIT, cadre et poteaux courts, sur un immeuble de hauteur
##     MOYENNE qui donne sur une avenue. Un panneau sur une tour ne se lit pas
##     d'en bas : on plafonne la hauteur du toit à `PUB_TOIT_MAX`.
##   - SUR UN PIGNON AVEUGLE, à plat contre le mur, le bas du panneau à
##     hauteur d'étage. Il faut un VRAI pignon : un mur large, qui donne sur
##     une rue DE L'AUTRE CÔTÉ, et rien devant.
##
## ⚠ CE QUI LES FAISAIT VOLER. Première version : on acceptait tout côté dont
## la demi-case voisine touchait une rue. Sur un pâté, la case « voisine » d'un
## petit immeuble est souvent la COUR ou la fente entre deux immeubles : le
## panneau se retrouvait suspendu dans une venelle, de travers, invisible de la
## rue et posé sur rien. Il faut donc que la case visée soit de la chaussée
## ET qu'aucun lot ne la touche.
const PUB_TOIT_MAX := 1.8              ## en cases : au-delà, c'est une tour
const PUB_TOIT_MIN := 1.15             ## en dessous, le panneau dépasse la rue
const PUB_PIED := 2.0                  ## les poteaux courts d'un panneau de toit
const PUB_LARGE_MAX := 17.0            ## 8,5 m : la largeur d'une affiche
const PUB_MUR_MIN := 15.0              ## un pignon plus étroit n'est pas un pignon
const PUB_BAS := 8.0                   ## le bas d'un panneau mural, en unités
const PUB_HAUT_MAX := 28.0             ## le haut : au-delà, on ne le lit plus
## ⚠ LE PANNEAU SORT DU MUR. Une descente d'eau Kenney dépasse de ~0,6 unité :
## à ras du mur, elle barrait l'affiche de haut en bas.
const PUB_DEBORD := 1.55

## ⚠ UN PANNEAU PAR PÂTÉ, PAS UN PAR IMMEUBLE. Sans cette règle, chaque
## immeuble d'une même rue prenait le sien : trois panneaux côte à côte sur
## trois toits voisins, et la ville se lisait comme un bord de périphérique.
static func _panneaux_pub(v: Ville2, alea: RandomNumberGenerator, _avenues_x: Array, _avenues_y: Array,
		pas: int = 5) -> void:
	var image := 0
	var pris: Dictionary = {}          ## une pose par case visée : jamais deux face à face
	var toit_du_pate: Dictionary = {}  ## un panneau de toit par pâté
	var mur_du_pate: Dictionary = {}   ## un panneau mural par pâté
	for l in v.lots:
		if String(l["genre"]) != "immeuble": continue
		var m := String(l["m"])
		var t := KitVille2.taille(m)
		var hauteur := t.y * CASE
		var q := int(l["q"])
		var centre := v.centre_du_lot(l)
		var ici := Vector2i(floori(centre.x / CASE), floori(centre.z / CASE))
		# La façade du modèle regarde −Z, tournée de `q` quarts (Basis(UP, +90°)
		# envoie (x, z) sur (z, −x)).
		var facade := Vector2i(0, -1)
		for _k in q: facade = Vector2i(facade.y, -facade.x)
		# 1. LE TOIT, face à l'avenue, sur un immeuble de hauteur moyenne.
		var devant := ici + facade
		var pate := Vector2i(floori(float(ici.x) / float(pas)), floori(float(ici.y) / float(pas)))
		if v.genre_de_route(devant) == Ville2.R_AVENUE and t.y >= PUB_TOIT_MIN and t.y <= PUB_TOIT_MAX \
				and not pris.has(devant) and not toit_du_pate.has(pate) and alea.randf() < 0.8:
			pris[devant] = true
			toit_du_pate[pate] = true
			var mur_f := (t.x if q % 2 == 0 else t.z) * CASE
			var large := minf(mur_f * 0.82, PUB_LARGE_MAX)
			v.objets.append({"m": "pub", "x": centre.x, "z": centre.z, "r": _vers(facade),
				"h": 0.0, "y": hauteur, "w": large, "hh": large * 9.0 / 16.0,
				"pied": PUB_PIED, "image": image})
			image += 1
			continue
		# 2. UN PIGNON AVEUGLE : un côté (ni la façade, ni l'arrière) dont la
		# case d'en face est de la chaussée libre, et dont le mur est large.
		for cote in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if cote == facade or cote == -facade: continue
			var demi_mur := ((t.x if (cote.x != 0) == (q % 2 == 1) else t.z)) * CASE * 0.5
			var mur := demi_mur * 2.0
			if mur < PUB_MUR_MIN: continue
			var demi_dehors := ((t.x if (cote.x != 0) == (q % 2 == 0) else t.z)) * CASE * 0.5
			# La case que le panneau REGARDE : celle qui commence juste après le mur.
			var face := Vector2i(floori((centre.x + float(cote.x) * (demi_dehors + 2.0)) / CASE),
				floori((centre.z + float(cote.y) * (demi_dehors + 2.0)) / CASE))
			if face == ici: continue
			if not v.carte.route(face) or v.lot_sur(face) >= 0: continue
			if pris.has(face) or mur_du_pate.has(pate): continue
			if alea.randf() > 0.5: continue
			pris[face] = true
			mur_du_pate[pate] = true
			var large := minf(mur * 0.7, PUB_LARGE_MAX)
			var haut := large * 9.0 / 16.0
			# Le bas à hauteur d'étage, le haut plafonné : un panneau à
			# trente mètres ne se lit pas depuis le trottoir d'en face.
			var bas := clampf(hauteur * 0.45, PUB_BAS, maxf(PUB_BAS, PUB_HAUT_MAX - haut))
			if bas + haut > hauteur - 1.0:
				bas = maxf(1.5, hauteur - haut - 1.5)
			if bas < 1.0: continue
			v.objets.append({"m": "pub", "x": centre.x + float(cote.x) * (demi_dehors + PUB_DEBORD),
				"z": centre.z + float(cote.y) * (demi_dehors + PUB_DEBORD), "r": _vers(cote),
				"h": 0.0, "y": bas, "w": large, "hh": haut, "pied": 0.0, "image": image})
			image += 1
			break

## L'angle qui met le +Z d'un panneau (sa face imprimée) vers cette direction.
static func _vers(d: Vector2i) -> float:
	return atan2(float(d.x), float(d.y))
