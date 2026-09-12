class_name ToitsVille2
extends RefCounted
## LES TOITS HABITÉS (cahier § 7 : « toits : climatiseurs, châteaux d'eau,
## antennes, escaliers ; panneaux pub »).
##
## Une brique commune aux trois témoins, appelée après les lots : elle relit
## `ville.lots`, mesure la hauteur RÉELLE de chaque modèle, et pose sur les
## toits assez hauts et assez larges de quoi les faire exister. Vu de la rue on
## ne voit presque rien ; vu d'une tour, d'un hélicoptère ou d'une capture en
## plongée — c'est-à-dire de là où le client regarde la ville — un toit nu se
## voit tout de suite.
##
## ⚠ ON NE POSE QUE CE QUI TIENT. Une cheminée d'usine sur un pavillon, un
## château d'eau sur trois mètres de large : le kit ne dit pas non, c'est ici
## que ça se refuse. Chaque pièce déclare la largeur de toit qu'elle exige.

const CASE := Ville2.CASE
const DEMI := Ville2.DEMI

## Ce qui peut monter sur un toit : le modèle, sa hauteur voulue en unités, la
## largeur de toit minimale (en unités) et le poids du tirage.
const PIECES := [
	# ⚠ LE PANNEAU SOLAIRE EST RARE. À poids égal il couvrait la ville entière
	# (« beaucoup trop de panneaux solaires », client, 12/09) : une ville n'est
	# pas une centrale. Ce qui domine un toit, ce sont les édicules — bouches
	# d'aération, cuves, cheminées.
	{"m": "industriel/solar-panel-flat", "h": 0.0, "large": 16.0, "poids": 2},
	{"m": "industriel/solar-panel-landscape-group", "h": 0.0, "large": 26.0, "poids": 1},
	{"m": "industriel/solar-panel-portrait", "h": 0.0, "large": 14.0, "poids": 1},
	{"m": "industriel/detail-tank", "h": 4.4, "large": 14.0, "poids": 6},
	{"m": "industriel/detail-tank-large", "h": 6.2, "large": 22.0, "poids": 3},
	{"m": "industriel/chimney-small", "h": 5.0, "large": 12.0, "poids": 7},
	{"m": "industriel/chimney-medium", "h": 6.5, "large": 16.0, "poids": 4},
	{"m": "industriel/chimney-basic", "h": 7.5, "large": 18.0, "poids": 3},
	{"m": "industriel/water-tower", "h": 13.0, "large": 34.0, "poids": 2},
	{"m": "nature/pot_large", "h": 2.0, "large": 16.0, "poids": 3},
	{"m": "nature/plant_bushLarge", "h": 2.4, "large": 16.0, "poids": 3},
	{"m": "nature/plant_bushDetailed", "h": 1.8, "large": 14.0, "poids": 2},
	{"m": "nature/fence_simpleLow", "h": 1.1, "large": 18.0, "poids": 2},
]

## En dessous, ce n'est pas un toit mais une maison : on n'y monte rien.
const HAUTEUR_MINI := 16.0
## La marge gardée au bord du toit — rien ne doit surplomber la façade.
const MARGE := 3.0

static func habiller(v: Ville2, alea: RandomNumberGenerator, densite := 0.75) -> void:
	for l in v.lots:
		if alea.randf() > densite: continue
		var m := String(l["m"])
		var haut := KitVille2.taille(m).y * CASE
		if haut < HAUTEUR_MINI: continue
		# ⚠ LE TOIT, PAS LE LOT. Le lot est la boîte arrondie à la demi-case ;
		# le bâtiment, lui, est souvent plus étroit. Mesurer sur le lot faisait
		# déborder les panneaux solaires dans le vide, au coin des immeubles.
		var boite := KitVille2.taille(m) * CASE
		var tourne := int(l["q"]) % 2 == 1
		var large := (boite.z if tourne else boite.x) - MARGE * 2.0
		var profond := (boite.x if tourne else boite.z) - MARGE * 2.0
		var tenable := minf(large, profond)
		if tenable < 8.0: continue
		var centre := v.centre_du_lot(l)
		var y := centre.y + haut
		var combien := 1 if tenable < 16.0 else alea.randi_range(1, 3)
		var pris: Array = []
		for _n in combien:
			var p := _tirer(alea, tenable)
			if p.is_empty(): continue
			# Un coin du toit, jamais deux fois le même.
			var coin := alea.randi() % 4
			var essais := 0
			while coin in pris and essais < 4:
				coin = (coin + 1) % 4
				essais += 1
			if coin in pris: continue
			pris.append(coin)
			# ⚠ LA PIÈCE A UNE TAILLE, ELLE AUSSI. Un panneau solaire posé à
			# l'échelle du kit fait une case de large : décalé d'un quart de
			# toit, il débordait dans le vide. On borne le décalage à ce qui
			# reste de toit une fois la pièce posée, et on renonce si elle ne
			# tient pas du tout.
			var demi := _demi_emprise(String(p["m"]), float(p["h"]))
			var jeu_x := large * 0.5 - demi
			var jeu_z := profond * 0.5 - demi
			if jeu_x < 0.0 or jeu_z < 0.0:
				# Trop grosse pour ce toit : une cheminée à la place, qui tient
				# partout — plutôt qu'un toit nu.
				p = {"m": "industriel/chimney-small", "h": 5.0}
				demi = _demi_emprise("industriel/chimney-small", 5.0)
				jeu_x = large * 0.5 - demi
				jeu_z = profond * 0.5 - demi
				if jeu_x < 0.0 or jeu_z < 0.0: continue
			var dx := minf(large * 0.25, jeu_x) * (1.0 if coin % 2 == 0 else -1.0)
			var dz := minf(profond * 0.25, jeu_z) * (1.0 if coin < 2 else -1.0)
			# Des quarts de tour, pas un angle libre : une cheminée de guingois
			# se voit, et le kit est dessiné pour la grille.
			v.ajouter_objet(String(p["m"]), centre.x + dx, centre.z + dz,
				float(alea.randi() % 4) * PI * 0.5, float(p["h"]))
			# ⚠ `y_abs` OU RIEN. Sans altitude imposée, l'objet se repose au
			# sol : on avait des châteaux d'eau au pied des tours.
			v.objets[v.objets.size() - 1]["y_abs"] = y

## La demi-emprise au sol d'une pièce de toit, en unités. Une pièce posée à
## l'échelle du kit garde sa taille ; une pièce mise à une hauteur voulue est
## mise à l'échelle dans les trois axes, son emprise suit.
static func _demi_emprise(modele: String, hauteur: float) -> float:
	var t := KitVille2.taille(modele) * CASE
	var facteur := 1.0
	if hauteur > 0.0 and t.y > 0.01:
		facteur = hauteur / t.y
	return maxf(t.x, t.z) * 0.5 * facteur

static func _tirer(alea: RandomNumberGenerator, large: float) -> Dictionary:
	var possibles: Array = []
	var total := 0
	for p in PIECES:
		if float(p["large"]) <= large + MARGE * 2.0:
			possibles.append(p)
			total += int(p["poids"])
	if total <= 0: return {}
	var tirage := alea.randi() % total
	for p in possibles:
		tirage -= int(p["poids"])
		if tirage < 0: return p
	return possibles[0]
