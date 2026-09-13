class_name AffichesVille2
extends RefCounted
## LES PANNEAUX PUBLICITAIRES, PARTOUT — pas seulement au centre.
##
## ⚠ POURQUOI CE FICHIER EXISTE. La pose des affiches vivait dans le seul
## générateur du centre. Résultat : le centre en était tapissé et les quatre
## autres quartiers n'en avaient AUCUNE (« il y a peut-être trop de panneaux
## publicitaires en ville et pas assez ailleurs », puis « je n'ai toujours
## aucune pub nulle part », client, 12/09 — la seconde phrase visant les
## quartiers neufs, où il n'y en avait effectivement pas une).
##
## Le cahier (§ 7) en fait une règle de VILLE, pas de quartier : « sur les toits
## des immeubles moyens, en façade des pignons aveugles, grands panneaux le long
## des voies rapides ; plus jamais sur pieds au milieu d'un trottoir ». Une
## règle de ville se pose une fois, ici, et chaque générateur l'appelle.
##
## LES TROIS SUPPORTS, dans l'ordre où on les essaie :
##
## 1. LE TOIT d'un bâtiment de hauteur moyenne qui donne sur un axe. Trop bas,
##    le panneau ne dépasse de rien ; trop haut, personne ne le lit.
## 2. LE PIGNON AVEUGLE : un côté du bâtiment qui n'est ni sa façade ni son
##    arrière, assez large, et dont la case d'en face est de la chaussée.
## 3. LE BORD DE ROUTE, sur pieds — mais SEULEMENT le long des axes, et jamais
##    sur le trottoir. C'est le seul support des quartiers sans immeuble : une
##    banlieue de plain-pied n'a ni toit assez haut ni pignon assez large.

const CASE := Ville2.CASE

## Les bornes d'un panneau de toit, en cases de hauteur de bâtiment.
const TOIT_MIN := 0.8
const TOIT_MAX := 3.2
## La largeur maximale d'une affiche, en unités.
const LARGE_MAX := 26.0
## Le pied d'un panneau de toit.
const PIED := 3.0
## La hauteur du bas d'un panneau mural, et son plafond.
const BAS := 4.0
const HAUT_MAX := 26.0
## De combien un panneau mural déborde du mur.
const DEBORD := 0.6
## La largeur de mur minimale pour porter une affiche.
const MUR_MIN := 14.0

## ⚠ L'ÉCART SE COMPTE EN DENSITÉ, PAS EN NOMBRE. À écart égal, un quartier
## dense porte mécaniquement quatre fois plus d'affiches qu'un quartier lâche :
## c'est ce qui avait tapissé le centre. Chaque générateur passe donc l'écart
## qui convient à SA densité — large en ville, plus serré en périphérie où il y
## a moins de supports.
const ECART_DEFAUT := 110.0

## Sème les affiches sur une ville finie. À appeler APRÈS la dernière
## `rasteriser()`, et avant la passe de propreté.
##
## `genres` : les genres de lot qui peuvent porter une affiche ("" = tous).
## `bord_de_route` : combien de panneaux sur pieds planter le long des axes.
static func semer(v: Ville2, alea: RandomNumberGenerator, ecart := ECART_DEFAUT,
		genres: Array = [], bord_de_route := 0) -> int:
	var poses: Array = []
	var image := 0
	var pris: Dictionary = {}
	for l in v.lots:
		if not genres.is_empty() and not genres.has(String(l.get("genre", ""))): continue
		var m := String(l["m"])
		var t := KitVille2.taille(m)
		var q := int(l["q"])
		var centre := v.centre_du_lot(l)
		var ici := Vector2i(floori(centre.x / CASE), floori(centre.z / CASE))
		var facade := Vector2i(0, -1)
		for _k in q: facade = Vector2i(facade.y, -facade.x)
		if not _assez_loin(poses, centre.x, centre.z, ecart): continue
		if _sur_le_toit(v, l, t, q, centre, ici, facade, pris, alea, image):
			poses.append(Vector2(centre.x, centre.z))
			image += 1
			continue
		if _sur_le_pignon(v, t, q, centre, ici, facade, pris, alea, image):
			poses.append(Vector2(centre.x, centre.z))
			image += 1
	if bord_de_route > 0:
		image += _au_bord_des_axes(v, alea, ecart, poses, image, bord_de_route)
	return image

static func _assez_loin(poses: Array, x: float, z: float, ecart: float) -> bool:
	for p in poses:
		if (p as Vector2).distance_to(Vector2(x, z)) < ecart: return false
	return true

static func _sur_le_toit(v: Ville2, l: Dictionary, t: Vector3, q: int, centre: Vector3,
		ici: Vector2i, facade: Vector2i, pris: Dictionary,
		alea: RandomNumberGenerator, image: int) -> bool:
	if t.y < TOIT_MIN or t.y > TOIT_MAX: return false
	var devant := ici + facade
	if not v.carte.route(devant) or pris.has(devant): return false
	if alea.randf() > 0.6: return false
	pris[devant] = true
	var mur_f := (t.x if q % 2 == 0 else t.z) * CASE
	var large := minf(mur_f * 0.82, LARGE_MAX)
	v.objets.append({"m": "pub", "x": centre.x, "z": centre.z, "r": _vers(facade),
		"h": 0.0, "y": t.y * CASE, "w": large, "hh": large * 9.0 / 16.0,
		"pied": PIED, "image": image})
	return true

static func _sur_le_pignon(v: Ville2, t: Vector3, q: int, centre: Vector3, ici: Vector2i,
		facade: Vector2i, pris: Dictionary, alea: RandomNumberGenerator, image: int) -> bool:
	var hauteur := t.y * CASE
	for cote in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if cote == facade or cote == -facade: continue
		var mur := ((t.x if (cote.x != 0) == (q % 2 == 1) else t.z)) * CASE
		if mur < MUR_MIN: continue
		var demi_dehors := ((t.x if (cote.x != 0) == (q % 2 == 0) else t.z)) * CASE * 0.5
		var face := Vector2i(floori((centre.x + float(cote.x) * (demi_dehors + 2.0)) / CASE),
			floori((centre.z + float(cote.y) * (demi_dehors + 2.0)) / CASE))
		if face == ici or pris.has(face): continue
		if not v.carte.route(face) or v.lot_sur(face) >= 0: continue
		if alea.randf() > 0.5: continue
		var large := minf(mur * 0.7, LARGE_MAX)
		var haut := large * 9.0 / 16.0
		var bas := clampf(hauteur * 0.45, BAS, maxf(BAS, HAUT_MAX - haut))
		if bas + haut > hauteur - 1.0: bas = maxf(1.5, hauteur - haut - 1.5)
		if bas < 1.0: continue
		pris[face] = true
		v.objets.append({"m": "pub",
			"x": centre.x + float(cote.x) * (demi_dehors + DEBORD),
			"z": centre.z + float(cote.y) * (demi_dehors + DEBORD), "r": _vers(cote),
			"h": 0.0, "y": bas, "w": large, "hh": haut, "pied": 0.0, "image": image})
		return true
	return false

## ⚠ LE PANNEAU DE BORD DE ROUTE SE PLANTE SUR L'ACCOTEMENT, PAS SUR LE
## TROTTOIR (cahier § 7 : « plus jamais sur pieds au milieu d'un trottoir »).
## On longe donc les AVENUES et on plante dans la case d'à côté, celle qui
## n'est ni route ni bâtie — l'herbe du bas-côté. Sans lui, une banlieue ou une
## zone industrielle n'a aucune affiche : leurs bâtiments sont trop bas pour un
## panneau de toit et trop étroits pour un pignon.
static func _au_bord_des_axes(v: Ville2, alea: RandomNumberGenerator, ecart: float,
		poses: Array, image0: int, combien: int) -> int:
	var image := 0
	var candidats: Array = []
	for r in v.routes:
		if String(r.get("genre", "")) != Ville2.R_AVENUE: continue
		var cases := Ville2.cases_de_route(r)
		for k in range(2, cases.size() - 2):
			var c: Vector2i = cases[k]
			for cote in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var b: Vector2i = c + cote
				if not v.dedans(b) or not v.terre(b): continue
				if v.carte.route(b) or v.lot_sur(b) >= 0 or v.carte.case_prise(b): continue
				candidats.append([b, -cote])
	if candidats.is_empty(): return 0
	# On mélange avec NOTRE hasard : `shuffle()` prend celui du moteur, et la
	# ville ne serait plus reproductible à graine égale.
	for k in range(candidats.size() - 1, 0, -1):
		var j := alea.randi() % (k + 1)
		var t: Variant = candidats[k]
		candidats[k] = candidats[j]
		candidats[j] = t
	for f in candidats:
		if image >= combien: break
		var b: Vector2i = f[0]
		var vers: Vector2i = f[1]
		var x := (float(b.x) + 0.5) * CASE
		var z := (float(b.y) + 0.5) * CASE
		if not _assez_loin(poses, x, z, ecart): continue
		poses.append(Vector2(x, z))
		v.objets.append({"m": "pub", "x": x, "z": z, "r": _vers(vers), "h": 0.0,
			"y": 0.0, "w": 18.0, "hh": 10.0, "pied": 5.0, "image": image0 + image})
		image += 1
	return image

## L'angle qui met le +Z d'un panneau (sa face imprimée) vers cette direction.
static func _vers(d: Vector2i) -> float:
	return atan2(float(d.x), float(d.y))
