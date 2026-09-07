class_name VoxelsCarnage
extends RefCounted
## La ville en VOXELS : tout ce qui est bâti ou posé est fait de cubes.
##
## Pourquoi des cubes : le client veut une ville qui CASSE — une roquette qui
## troue une façade, une voiture lancée qui défonce une devanture. Une boîte
## texturée ne se troue pas ; une pile de cubes, si : on retire des cubes, on
## dévoile ceux de derrière. Et un cube ne coûte rien : douze triangles, une
## couleur, une échelle — tout un morceau de ville tient en UNE nappe
## d'instances, quelle que soit la forme des immeubles, des arbres ou des
## lampadaires.
##
## Deux tailles : les immeubles en cubes de deux unités (un étage, une fenêtre),
## le mobilier en cubes d'une unité. La même nappe porte les deux : l'échelle
## est dans la transformation de l'instance.
##
## La COULEUR d'instance dit aussi la matière, dans son alpha : 1 = mur,
## 0,5 = lumière (fenêtre allumée, lampe, enseigne : émissif, plus fort la
## nuit), 0,1 = vitre éteinte (sombre et brillante). C'est le seul canal par
## instance dont on soit sûr en mode compatibilité.

const V := 2.0                 ## côté d'un voxel d'immeuble, en unités 3D
const PETIT := 1.0             ## côté d'un voxel de mobilier
const MUR := 1.0
const LUMIERE := 0.5
const VITRE := 0.1

## Ce qu'une fiche d'immeuble devient : ses dimensions en voxels, le coin
## minimal en unités 3D, l'occupation (1 = plein) et la couleur de chaque voxel.
## `indice(i, j, k)` = (i * nz + j) * ny + k.
## L'intérieur est plein mais gris : on ne le voit qu'une fois la façade partie.
## La grille seule : dimensions, coin, taille — ce dont l'hôte a besoin pour
## dire quel cube une balle a touché, sans rien dessiner.
static func grille(b: Dictionary) -> Dictionary:
	var nx: int = max(1, int(round(float(b["w"]) * Decor.ECHELLE / V)))
	var nz: int = max(1, int(round(float(b["d"]) * Decor.ECHELLE / V)))
	var ny: int = max(1, int(round(float(b["h"]) / V)))
	# Un volume plat (toit de maison, auvent, flèche de grue) garde sa hauteur
	# réelle : on l'aplatit dans la transformation, pas dans la grille.
	var plat: bool = float(b["h"]) < V * 0.75
	if plat:
		ny = 1
	var origine := Decor.vers3d(Vector2(b["p"]) - Vector2(float(b["w"]), float(b["d"])) * 0.5, float(b["y"]))
	return {"nx": nx, "nz": nz, "ny": ny, "origine": origine, "taille": V,
		"hauteur": (float(b["h"]) if plat else V), "plat": plat}

static func centre_voxel(g: Dictionary, i: int, j: int, k: int) -> Vector3:
	return (g["origine"] as Vector3) + Vector3((i + 0.5) * float(g["taille"]), (k + 0.5) * float(g["hauteur"]), (j + 0.5) * float(g["taille"]))

static func cle_locale(i: int, j: int, k: int) -> int:
	return (i * 16 + j) * 32 + k

## Le voxel de la grille le plus proche d'un point 3D (occupation ignorée).
static func voxel_proche_de(b: Dictionary, point: Vector3) -> int:
	var g := grille(b)
	var o: Vector3 = g["origine"]
	var i: int = clamp(int(floor((point.x - o.x) / float(g["taille"]))), 0, int(g["nx"]) - 1)
	var j: int = clamp(int(floor((point.z - o.z) / float(g["taille"]))), 0, int(g["nz"]) - 1)
	var k: int = clamp(int(floor((point.y - o.y) / float(g["hauteur"]))), 0, int(g["ny"]) - 1)
	return cle_locale(i, j, k)

## Les voxels de la grille à moins de `rayon` d'un point (occupation ignorée).
static func voxels_autour_de(b: Dictionary, point: Vector3, rayon: float) -> Array:
	var g := grille(b)
	var liste: Array = []
	for i in int(g["nx"]):
		for j in int(g["nz"]):
			for k in int(g["ny"]):
				if centre_voxel(g, i, j, k).distance_to(point) <= rayon:
					liste.append(cle_locale(i, j, k))
	return liste

static func immeuble(b: Dictionary, graine: int) -> Dictionary:
	var g := grille(b)
	var nx := int(g["nx"])
	var nz := int(g["nz"])
	var ny := int(g["ny"])
	var plat := bool(g["plat"])
	var style := int(b["style"])
	var teinte: Color = b["c"]
	var origine: Vector3 = g["origine"]
	var solide := PackedByteArray()
	solide.resize(nx * nz * ny)
	solide.fill(1)
	var couleurs := PackedColorArray()
	couleurs.resize(nx * nz * ny)
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	# Le toit : sa couleur vient du style, pas du mur — une façade ocre sous
	# un toit de tuiles, un bureau clair sous du gravier. La caméra voit les
	# toits avant les façades : c'est eux qui colorent la ville vue d'en haut.
	var toits: Array = PlanVille.TOITS_PAR_STYLE.get(style, PlanVille.TOITS_PAR_STYLE[PlanVille.F_PLEIN])
	var toit: Color = toits[rng.randi_range(0, toits.size() - 1)]
	var interieur := Color(0.42, 0.40, 0.38)
	var part := _part_allumee(style)
	for i in nx:
		for j in nz:
			for k in ny:
				var facade := i == 0 or i == nx - 1 or j == 0 or j == nz - 1
				var couleur := teinte
				if k == ny - 1 and not plat:
					# Toute la dernière couche est du toit, intérieur compris :
					# c'est sa face du dessus qu'on voit. Un grain de deux tons.
					couleur = toit.lightened(rng.randf_range(-0.05, 0.05))
					if not facade and rng.randf() < 0.12:
						couleur = toit.darkened(0.2)
				elif not facade:
					couleur = interieur
				elif plat:
					couleur = teinte
				else:
					couleur = _facade(style, teinte, i, j, k, nx, nz, ny, part, rng)
					# La crasse du bas : une façade est plus sombre au ras du
					# trottoir qu'au dernier étage. Sur les murs seulement — une
					# fenêtre allumée ne se salit pas.
					if couleur.a > 0.75 and ny > 1:
						couleur = couleur.darkened(0.16 * (1.0 - float(k) / float(ny - 1)))
				couleurs[(i * nz + j) * ny + k] = couleur
	return {"nx": nx, "nz": nz, "ny": ny, "origine": origine, "taille": V,
		"hauteur": float(g["hauteur"]), "solide": solide, "couleurs": couleurs, "style": style,
		"teinte": teinte, "plat": plat}

## Les ORNEMENTS d'un immeuble : ce qui dépasse de la grille et n'en fait pas
## partie — corniche au dernier étage, balcons sous les fenêtres, stores au-
## dessus des vitrines, et sur le toit : climatiseurs, citerne, antenne, cage
## d'escalier, cheminées. Liste de [centre, taille (Vector3), couleur]. Ce
## n'est pas cassable : une balle ne vise pas une corniche.
static func ornements(imm: Dictionary, graine: int) -> Array:
	var liste: Array = []
	if bool(imm["plat"]):
		return liste
	var nx := int(imm["nx"])
	var nz := int(imm["nz"])
	var ny := int(imm["ny"])
	var style := int(imm["style"])
	var teinte: Color = imm["teinte"]
	var o: Vector3 = imm["origine"]
	var rng := RandomNumberGenerator.new()
	rng.seed = graine + 77
	var haut := o.y + float(ny) * V
	var clair := teinte.lightened(0.18)
	var sombre := teinte.darkened(0.25)

	# La corniche : une lame qui court au sommet, en saillie d'un demi-voxel.
	var corniche := style in [PlanVille.F_VIEUX, PlanVille.F_LOGEMENTS, PlanVille.F_COMMERCE, PlanVille.F_BUREAUX] and ny >= 2
	if corniche:
		var e := 0.5 * V
		var y := haut - 0.3 * V
		var lx := float(nx) * V + 2.0 * e
		var lz := float(nz) * V + 2.0 * e
		liste.append([Vector3(o.x + float(nx) * V * 0.5, y, o.z - e * 0.5), Vector3(lx, 0.6 * V, e), clair])
		liste.append([Vector3(o.x + float(nx) * V * 0.5, y, o.z + float(nz) * V + e * 0.5), Vector3(lx, 0.6 * V, e), clair])
		liste.append([Vector3(o.x - e * 0.5, y, o.z + float(nz) * V * 0.5), Vector3(e, 0.6 * V, lz), clair])
		liste.append([Vector3(o.x + float(nx) * V + e * 0.5, y, o.z + float(nz) * V * 0.5), Vector3(e, 0.6 * V, lz), clair])

	# Les balcons : sous une fenêtre sur trois des étages supérieurs, une
	# dalle qui dépasse et un garde-corps.
	if style in [PlanVille.F_LOGEMENTS, PlanVille.F_VIEUX] and ny >= 3:
		for k in range(1, ny - 1):
			for cote in 4:
				var le_long := nx if cote < 2 else nz
				for m in le_long:
					if posmod(m, 2) != 1 or rng.randf() > 0.3:
						continue
					var centre: Vector3
					var taille: Vector3
					match cote:
						0: centre = Vector3(o.x + (m + 0.5) * V, o.y + k * V + 0.15 * V, o.z - 0.3 * V); taille = Vector3(V, 0.3 * V, 0.6 * V)
						1: centre = Vector3(o.x + (m + 0.5) * V, o.y + k * V + 0.15 * V, o.z + nz * V + 0.3 * V); taille = Vector3(V, 0.3 * V, 0.6 * V)
						2: centre = Vector3(o.x - 0.3 * V, o.y + k * V + 0.15 * V, o.z + (m + 0.5) * V); taille = Vector3(0.6 * V, 0.3 * V, V)
						_: centre = Vector3(o.x + nx * V + 0.3 * V, o.y + k * V + 0.15 * V, o.z + (m + 0.5) * V); taille = Vector3(0.6 * V, 0.3 * V, V)
					liste.append([centre, taille, sombre])
					# Le garde-corps : une lame fine au bord extérieur.
					var dehors := (centre - Vector3(o.x + nx * V * 0.5, 0, o.z + nz * V * 0.5))
					dehors.y = 0.0
					var n := Vector3(signf(dehors.x), 0, 0) if cote >= 2 else Vector3(0, 0, signf(dehors.z))
					liste.append([centre + n * 0.25 * V + Vector3(0, 0.45 * V, 0),
						Vector3(0.1 * V, 0.6 * V, V) if cote >= 2 else Vector3(V, 0.6 * V, 0.1 * V), Color(0.15, 0.15, 0.17)])

	# Les stores des vitrines : une lame de couleur au-dessus du rez-de-chaussée.
	if style == PlanVille.F_COMMERCE and ny >= 2:
		var store: Color = PlanVille.NEONS[rng.randi_range(0, PlanVille.NEONS.size() - 1)]
		store = store.lerp(Color(0.9, 0.9, 0.85), 0.35)
		var y := o.y + 1.0 * V - 0.1 * V
		for cote in 4:
			if rng.randf() > 0.7:
				continue
			match cote:
				0: liste.append([Vector3(o.x + nx * V * 0.5, y, o.z - 0.45 * V), Vector3(float(nx) * V - V, 0.2 * V, 0.9 * V), store])
				1: liste.append([Vector3(o.x + nx * V * 0.5, y, o.z + nz * V + 0.45 * V), Vector3(float(nx) * V - V, 0.2 * V, 0.9 * V), store])
				2: liste.append([Vector3(o.x - 0.45 * V, y, o.z + nz * V * 0.5), Vector3(0.9 * V, 0.2 * V, float(nz) * V - V), store])
				_: liste.append([Vector3(o.x + nx * V + 0.45 * V, y, o.z + nz * V * 0.5), Vector3(0.9 * V, 0.2 * V, float(nz) * V - V), store])

	# Le toit : ce que la caméra voit le plus. Un parapet sur les immeubles
	# sans corniche, puis du désordre — climatiseurs, citerne, antenne, cage
	# d'escalier, cheminées selon le style.
	if not corniche and style != PlanVille.F_MAISON and ny >= 2:
		var y := haut + 0.2 * V
		var pe := 0.35 * V
		liste.append([Vector3(o.x + nx * V * 0.5, y, o.z + pe * 0.5), Vector3(float(nx) * V, 0.4 * V, pe), sombre])
		liste.append([Vector3(o.x + nx * V * 0.5, y, o.z + nz * V - pe * 0.5), Vector3(float(nx) * V, 0.4 * V, pe), sombre])
		liste.append([Vector3(o.x + pe * 0.5, y, o.z + nz * V * 0.5), Vector3(pe, 0.4 * V, float(nz) * V), sombre])
		liste.append([Vector3(o.x + nx * V - pe * 0.5, y, o.z + nz * V * 0.5), Vector3(pe, 0.4 * V, float(nz) * V), sombre])
	if nx >= 2 and nz >= 2 and style != PlanVille.F_MAISON:
		var libre := func() -> Vector3:
			return Vector3(o.x + rng.randf_range(0.7, float(nx) - 0.7) * V, haut, o.z + rng.randf_range(0.7, float(nz) - 0.7) * V)
		var gris := Color(0.62, 0.63, 0.65)
		var combien := rng.randi_range(1, 2 if nx * nz < 12 else 4)
		for c in combien:
			var t := rng.randf()
			var ou: Vector3 = libre.call()
			if t < 0.4:
				# Un climatiseur : une boîte claire, une grille sombre dessus.
				liste.append([ou + Vector3(0, 0.3 * V, 0), Vector3(0.9 * V, 0.6 * V, 0.9 * V), gris])
				liste.append([ou + Vector3(0, 0.62 * V, 0), Vector3(0.7 * V, 0.06 * V, 0.7 * V), Color(0.2, 0.2, 0.22)])
			elif t < 0.6 and ny >= 4:
				# Une citerne sur ses pieds.
				liste.append([ou + Vector3(0, 0.3 * V, 0), Vector3(0.5 * V, 0.6 * V, 0.5 * V), Color(0.3, 0.3, 0.33)])
				liste.append([ou + Vector3(0, 1.1 * V, 0), Vector3(1.1 * V, 1.0 * V, 1.1 * V), Color(0.55, 0.42, 0.32)])
			elif t < 0.8:
				# La cage d'escalier, dans la teinte du mur, avec sa porte.
				liste.append([ou + Vector3(0, 0.55 * V, 0), Vector3(1.4 * V, 1.1 * V, 1.1 * V), teinte.darkened(0.08)])
			else:
				# Une antenne : un mât fin, une traverse.
				liste.append([ou + Vector3(0, 0.9 * V, 0), Vector3(0.12 * V, 1.8 * V, 0.12 * V), Color(0.35, 0.35, 0.38)])
				liste.append([ou + Vector3(0, 1.6 * V, 0), Vector3(0.7 * V, 0.08 * V, 0.08 * V), Color(0.35, 0.35, 0.38)])
	if style in [PlanVille.F_VIEUX, PlanVille.F_MAISON] and rng.randf() < 0.7:
		var ou := Vector3(o.x + rng.randf_range(0.5, float(nx) - 0.5) * V, haut, o.z + rng.randf_range(0.5, float(nz) - 0.5) * V)
		liste.append([ou + Vector3(0, 0.5 * V, 0), Vector3(0.4 * V, 1.0 * V, 0.4 * V), Color(0.5, 0.32, 0.26)])
	return liste

static func _part_allumee(style: int) -> float:
	match style:
		PlanVille.F_TOUR: return 0.45
		PlanVille.F_BUREAUX: return 0.45
		PlanVille.F_COMMERCE: return 0.6
		PlanVille.F_HANGAR: return 0.3
		PlanVille.F_MAISON: return 0.6
		PlanVille.F_PLEIN: return 0.0
	return 0.5

## La couleur d'un voxel de façade : mur, fenêtre allumée, vitre, porte,
## vitrine. Une fenêtre sur deux le long du mur, à chaque étage ; les tours
## sont tout en verre ; les hangars n'ont qu'un bandeau haut.
static func _facade(style: int, teinte: Color, i: int, j: int, k: int, nx: int, nz: int, ny: int,
		part: float, rng: RandomNumberGenerator) -> Color:
	var le_long := i if (j == 0 or j == nz - 1) else j
	var coin := (i == 0 or i == nx - 1) and (j == 0 or j == nz - 1)
	var chaud := Color(1.0, 0.82, 0.55)
	var froid := Color(0.65, 0.82, 1.0)
	var vitre := Color(0.09, 0.11, 0.16, VITRE)
	var fenetre := false
	match style:
		PlanVille.F_PLEIN:
			return teinte
		PlanVille.F_TOUR:
			fenetre = not coin
		PlanVille.F_HANGAR:
			fenetre = k >= ny - 2 and k > 0 and posmod(le_long, 2) == 1
		PlanVille.F_COMMERCE:
			if k == 0:
				# La vitrine : du verre allumé, sauf aux angles.
				if coin:
					return teinte.darkened(0.2)
				return Color(chaud.lerp(Color.WHITE, 0.3), LUMIERE) if rng.randf() < 0.75 else vitre
			fenetre = posmod(le_long, 2) == 1 and not coin
		_:
			if k == 0 and posmod(le_long, 3) == 1 and not coin and rng.randf() < 0.4:
				return teinte.darkened(0.55)      # une porte
			fenetre = posmod(le_long, 2) == 1 and not coin and k > 0
	if not fenetre:
		return teinte.lightened(rng.randf_range(-0.04, 0.04))
	if rng.randf() < part:
		var lum := chaud if rng.randf() < 0.72 else froid
		return Color(lum.lerp(Color.WHITE, rng.randf_range(0.0, 0.25)), LUMIERE)
	return vitre

# ------------------------------------------------------------ le mobilier

## Les cubes d'un accessoire : une liste de [centre (Vector3), côté, couleur].
## `p` en pixels, `a` l'angle (tour de la rue), `s` l'échelle de la fiche.
static func mobilier(nom: String, p: Vector2, a: float, s: float, graine: int) -> Array:
	var base := Decor.vers3d(p)
	var cubes: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var avant := Vector3(cos(a), 0.0, sin(a))          # +X local, vers le trottoir
	var cote := Vector3(-avant.z, 0.0, avant.x)
	match nom:
		"lampadaire", "lampadaire_parc":
			var h := 4.8 if nom == "lampadaire" else 3.2
			var fut := Color(0.22, 0.24, 0.28)
			var n := int(h / 0.6)
			for k in n:
				cubes.append([base + Vector3(0, 0.3 + 0.6 * k, 0), 0.6, fut])
			# Le bras vers la rue (local -X), la lampe au bout.
			var portee := 1.15 if nom == "lampadaire" else 0.8
			cubes.append([base - avant * portee * 0.5 + Vector3(0, h - 0.3, 0), 0.6, fut])
			cubes.append([base - avant * portee + Vector3(0, h - 0.4, 0), 0.7, Color(1.0, 0.9, 0.7, LUMIERE)])
		"feu":
			for k in 5:
				cubes.append([base + Vector3(0, 0.3 + 0.6 * k, 0), 0.6, Color(0.2, 0.2, 0.22)])
			cubes.append([base + Vector3(0, 3.4, 0), 1.0, Color(0.15, 0.15, 0.17)])
			var vert := rng.randf() < 0.5
			cubes.append([base + avant * 0.35 + Vector3(0, 3.4, 0), 0.5,
				Color(0.2, 0.95, 0.35, LUMIERE) if vert else Color(1.0, 0.25, 0.2, LUMIERE)])
		"borne":
			cubes.append([base + Vector3(0, 0.45, 0), 0.9, Color(0.85, 0.2, 0.15)])
			cubes.append([base + Vector3(0, 1.05, 0), 0.5, Color(0.85, 0.2, 0.15)])
		"poubelle":
			cubes.append([base + Vector3(0, 0.5, 0), 1.0, Color(0.62, 0.5, 0.35)])
		"banc":
			var bois := Color(0.55, 0.38, 0.22)
			for m in [-1.0, 0.0, 1.0]:
				cubes.append([base + cote * m * 0.8 + Vector3(0, 0.5, 0), 0.8, bois])
				cubes.append([base + cote * m * 0.8 + avant * 0.35 + Vector3(0, 1.15, 0), 0.6, bois])
		"benne":
			var vert_benne := Color(0.2, 0.42, 0.25)
			for x in 3:
				for z in 2:
					for y in 2:
						cubes.append([base + avant * (x - 1.0) + cote * (z - 0.5) + Vector3(0, 0.5 + y, 0), 1.0,
							vert_benne if y == 0 else vert_benne.darkened(0.25)])
		"buisson":
			var feuille := Color(0.22, 0.5, 0.2)
			for x in 2:
				for z in 2:
					cubes.append([base + Vector3(x - 0.5, 0.45, z - 0.5) * 0.9 * s, 0.9 * s, feuille.lightened(rng.randf_range(-0.08, 0.08))])
			cubes.append([base + Vector3(0, 1.2 * s, 0), 0.8 * s, feuille.lightened(0.1)])
		"arbre", "arbre_petit":
			# Un arbre en cubes fins (un demi-voxel) : un tronc de quatre cubes de
			# section, une couronne en boule irrégulière où un cube sur six manque
			# et où deux verts se mêlent, plus claire vers le haut. Une boîte de
			# feuilles se lit comme une boîte ; une boule trouée se lit comme un
			# arbre — et il y a dix fois plus de cubes.
			var grand := nom == "arbre"
			var r := 0.55 * s
			var tronc := Color(0.4, 0.28, 0.16)
			var feuille := Color(0.18, 0.45, 0.16).lightened(rng.randf_range(-0.05, 0.1))
			var feuille2 := feuille.lerp(Color(0.34, 0.54, 0.14), 0.6)
			var h_tronc := (2.4 if grand else 1.6) * s
			var n_tronc := int(ceil(h_tronc / r))
			for k in n_tronc:
				for dx in 2:
					for dz in 2:
						cubes.append([base + Vector3((dx - 0.5) * r, (k + 0.5) * r, (dz - 0.5) * r), r, tronc.lightened(0.05 * (k % 2))])
			var rayon := (1.8 if grand else 1.2) * s
			var y0 := h_tronc + rayon * 0.9
			var n_c := int(ceil(rayon / r))
			for y in range(-n_c, n_c + 1):
				for x in range(-n_c, n_c + 1):
					for z in range(-n_c, n_c + 1):
						var d := Vector3(x, y * 1.15, z).length() * r
						if d > rayon + r * 0.3:
							continue
						# On ne garde que l'écorce de la boule : l'intérieur ne se voit
						# jamais et coûterait deux fois plus.
						if d < rayon - r * 1.4:
							continue
						if rng.randf() < 0.16:
							continue
						var vert := feuille if rng.randf() < 0.6 else feuille2
						cubes.append([base + Vector3(x * r, y0 + y * r, z * r), r,
							vert.lightened(0.12 * float(y) / float(n_c) + rng.randf_range(-0.05, 0.05))])
		"conteneur_a", "conteneur_b":
			var teintes := [Color(0.8, 0.35, 0.15), Color(0.2, 0.4, 0.7), Color(0.25, 0.55, 0.3), Color(0.6, 0.15, 0.15), Color(0.7, 0.7, 0.72)]
			var c: Color = teintes[rng.randi_range(0, teintes.size() - 1)]
			for x in 5:
				for z in 2:
					for y in 2:
						cubes.append([base + avant * (x - 2.0) + cote * (z - 0.5) + Vector3(0, 0.5 + y, 0), 1.0,
							c.lightened(rng.randf_range(-0.03, 0.03))])
		"citerne":
			var blanc := Color(0.78, 0.78, 0.75)
			for y in 3:
				for x in range(-2, 3):
					for z in range(-2, 3):
						if abs(x) == 2 and abs(z) == 2:
							continue
						cubes.append([base + Vector3(x, 0.5 + y, z), 1.0, blanc.lightened(-0.05 * y)])
			for x in range(-1, 2):
				for z in range(-1, 2):
					cubes.append([base + Vector3(x, 3.5, z), 1.0, blanc.darkened(0.2)])
		"cheminee":
			var brique := Color(0.55, 0.3, 0.22)
			for y in 8:
				for x in 2:
					for z in 2:
						cubes.append([base + Vector3(x - 0.5, 0.45 + 0.9 * y, z - 0.5) * 0.9 + Vector3(0, 0, 0), 0.9,
							brique.lightened(0.02 * y)])
			cubes.append([base + Vector3(0, 7.7, 0), 0.6, Color(0.9, 0.5, 0.2, LUMIERE)])
		"chateau_eau":
			var acier := Color(0.35, 0.36, 0.4)
			for x in [-1.2, 1.2]:
				for z in [-1.2, 1.2]:
					for y in 6:
						cubes.append([base + Vector3(x, 0.3 + 0.6 * y, z), 0.6, acier])
			for x in range(-1, 2):
				for z in range(-1, 2):
					for y in 2:
						cubes.append([base + Vector3(x * 1.2, 4.2 + y * 1.2, z * 1.2), 1.2, Color(0.5, 0.52, 0.55)])
			cubes.append([base + Vector3(0, 6.8, 0), 1.0, Color(0.3, 0.3, 0.33)])
		"monument":
			# L'obélisque de la place en étoile : trois marches de pierre, un
			# fût qui s'affine, une pointe dorée qui prend la lumière la nuit.
			var pierre_m := Color(0.62, 0.60, 0.56)
			for marche in 3:
				var demi := 3 - marche
				for x in range(-demi, demi + 1):
					for z in range(-demi, demi + 1):
						cubes.append([base + Vector3(x, 0.5 + marche, z), 1.0, pierre_m.lightened(0.04 * marche)])
			var fut_m := Color(0.70, 0.68, 0.62)
			for y in 14:
				var cote_f := 1.6 if y < 4 else (1.3 if y < 9 else 1.0)
				cubes.append([base + Vector3(0, 3.5 + y * 0.9, 0), cote_f, fut_m.lightened(-0.02 * y)])
			cubes.append([base + Vector3(0, 16.2, 0), 0.8, Color(0.95, 0.8, 0.35, LUMIERE)])
			for x in [-2.5, 2.5]:
				for z in [-2.5, 2.5]:
					cubes.append([base + Vector3(x, 3.6, z), 0.6, Color(0.22, 0.24, 0.28)])
					cubes.append([base + Vector3(x, 4.3, z), 0.7, Color(1.0, 0.9, 0.7, LUMIERE)])
		"fontaine":
			var pierre := Color(0.6, 0.58, 0.55)
			for x in range(-2, 3):
				for z in range(-2, 3):
					if abs(x) < 2 and abs(z) < 2:
						if x == 0 and z == 0:
							continue
						cubes.append([base + Vector3(x, 0.25, z) * 0.9 + Vector3(0, 0.0, 0), 0.9, Color(0.35, 0.65, 0.85, LUMIERE)])
						continue
					cubes.append([base + Vector3(x, 0.45, z) * 0.9, 0.9, pierre])
			cubes.append([base + Vector3(0, 0.6, 0), 0.8, pierre])
			cubes.append([base + Vector3(0, 1.4, 0), 0.8, pierre.darkened(0.1)])
			cubes.append([base + Vector3(0, 2.1, 0), 0.7, Color(0.45, 0.75, 0.95, LUMIERE)])
	return cubes

# ------------------------------------------------------------ les voitures

const VOXEL_VOITURE := 0.34

## Les gabarits, en voxels FINS (trois par unité) : longueur, largeur, hauteur
## de caisse, l'habitacle (début, fin), et la forme du capot (« sport » =
## capot plongeant, « haut » = fourgon carré). Une berline fait quatorze
## voxels de long, six de large : à peu près une Volvo vue de dessus.
const GABARITS := {
	0: {"l": 14, "w": 6, "hc": 3, "cab": [4, 11], "forme": "berline"},
	1: {"l": 14, "w": 6, "hc": 3, "cab": [5, 11], "forme": "sport"},
	2: {"l": 12, "w": 6, "hc": 3, "cab": [3, 10], "forme": "berline"},
	3: {"l": 14, "w": 6, "hc": 4, "cab": [3, 12], "forme": "haut"},
	4: {"l": 15, "w": 6, "hc": 4, "cab": [3, 13], "forme": "haut"},
	5: {"l": 14, "w": 6, "hc": 3, "cab": [4, 11], "forme": "berline"},
	6: {"l": 15, "w": 6, "hc": 4, "cab": [2, 15], "forme": "fourgon"},
	7: {"l": 17, "w": 6, "hc": 4, "cab": [4, 17], "forme": "camion"},
	8: {"l": 18, "w": 6, "hc": 4, "cab": [5, 18], "forme": "camion"},
	9: {"l": 14, "w": 6, "hc": 3, "cab": [4, 11], "forme": "berline"},
}

## Le maillage voxel d'une voiture, en couleurs de sommet. La caisse est
## BLANCHE : c'est la couleur d'instance (ou la matière) qui la peint, roues,
## vitres et pare-chocs restent sombres quelle que soit la peinture. L'avant
## regarde +X. Un capot qui plonge, des passages de roue, des rétroviseurs,
## des pare-chocs : c'est ce qui sépare une voiture d'un pain de savon.
static func voiture(indice: int) -> ArrayMesh:
	var g: Dictionary = GABARITS.get(indice, GABARITS[0])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var L := int(g["l"])
	var W := int(g["w"])
	var HC := int(g["hc"])
	var cab: Array = g["cab"]
	var forme := String(g["forme"])
	var v := VOXEL_VOITURE
	var blanc := Color(1, 1, 1, MUR)
	var vitre := Color(0.10, 0.13, 0.18, VITRE)
	var noir := Color(0.05, 0.05, 0.06, MUR)
	var chrome := Color(0.75, 0.76, 0.78, MUR)
	var x0 := -float(L) * 0.5 * v
	var z0 := -float(W) * 0.5 * v
	var y_sol := 0.42                    # le dessous de la caisse
	var pose := func(x: int, y: int, z: int, c: Color) -> void:
		_cube(st, Vector3(x0 + (x + 0.5) * v, y_sol + (y + 0.5) * v, z0 + (z + 0.5) * v), v, c)
	var roues_x := [2, L - 3]            # centre des roues (deux voxels de large)
	for x in L:
		for z in W:
			for y in HC:
				var c := blanc
				# Le capot plonge : la rangée du haut disparaît sur les trois
				# derniers voxels à l'avant (et deux à l'arrière pour une sportive).
				var avant := L - 1 - x
				if forme == "berline" and y == HC - 1 and (avant < 3):
					continue
				if forme == "sport" and y == HC - 1 and (avant < 4 or x < 2):
					continue
				if forme == "berline" and y == HC - 1 and x < 1:
					continue
				# Les passages de roue : rien au ras du sol autour des roues.
				if y == 0 and (z == 0 or z == W - 1) and (abs(x - roues_x[0]) <= 1 or abs(x - roues_x[1]) <= 1):
					continue
				# Les pare-chocs : la rangée du bas, aux deux bouts, en sombre.
				if y == 0 and (x == 0 or x == L - 1):
					c = Color(0.16, 0.16, 0.18, MUR)
				if indice == 9 and y == HC - 1 and x >= 4 and x <= 9:
					c = Color(0.2, 0.35, 0.85, MUR)            # la bande de la police
				if indice == 7 and x >= int(cab[0]) and y >= 1:
					c = Color(0.92, 0.92, 0.9, MUR)             # la caisse de livraison
				if indice == 5 and y == HC - 1 and posmod(x + z, 2) == 0 and x > 2 and x < L - 3:
					c = Color(0.1, 0.1, 0.1, MUR)               # le damier du taxi
				pose.call(x, y, z, c)
	# L'habitacle : deux rangées de plus, en verre sur les côtés et aux bouts,
	# les montants en tôle. Les camions : une cabine courte et la caisse.
	var y_cab := HC
	var hauteur_cab := 2 if forme != "haut" else 2
	for x in range(int(cab[0]), int(cab[1])):
		for z in W:
			for y in range(y_cab, y_cab + hauteur_cab):
				var bord := z == 0 or z == W - 1 or x == int(cab[0]) or x == int(cab[1]) - 1
				var montant := (x == int(cab[0]) or x == int(cab[1]) - 1) and (z == 0 or z == W - 1)
				var c := vitre if (bord and not montant) else blanc
				if forme == "camion":
					var caisse := x >= int(cab[0]) + 3
					if caisse:
						c = Color(0.92, 0.92, 0.9, MUR) if indice == 7 else Color(0.85, 0.35, 0.25, MUR)
				elif forme == "fourgon" and x >= int(cab[0]) + 3:
					c = blanc
				pose.call(x, y, z, c)
	# Le toit.
	var toit_y := y_cab + hauteur_cab
	for x in range(int(cab[0]) + (0 if forme in ["camion", "fourgon"] else 1), int(cab[1]) - (0 if forme in ["camion", "fourgon"] else 1)):
		for z in range(1, W - 1):
			pose.call(x, toit_y, z, blanc)
	# Une caisse de camion plus haute encore.
	if forme == "camion":
		for x in range(int(cab[0]) + 3, int(cab[1])):
			for z in range(0, W):
				pose.call(x, toit_y, z, Color(0.92, 0.92, 0.9, MUR) if indice == 7 else Color(0.85, 0.35, 0.25, MUR))
	# Les rétroviseurs.
	pose.call(int(cab[1]) - 1, y_cab, -1, noir)
	pose.call(int(cab[1]) - 1, y_cab, W, noir)
	# Les roues : deux voxels de large, une jante claire au milieu.
	for x in roues_x:
		for z in [-1, W]:
			for dx in [-1, 0, 1]:
				for dy in [0, 1]:
					if abs(dx) == 1 and dy == 1:
						continue
					_cube(st, Vector3(x0 + (x + dx + 0.5) * v, 0.16 + (dy + 0.5) * v, z0 + (z + 0.5) * v), v, noir)
			_cube(st, Vector3(x0 + (x + 0.5) * v, 0.16 + 0.5 * v, z0 + (z + 0.5) * v + (0.12 if z < 0 else -0.12)), v * 0.6, chrome)
	# Phares et feux : deux cubes lumineux à chaque bout, une calandre chromée.
	for z in [0, W - 1]:
		_cube(st, Vector3(x0 + L * v + 0.03, y_sol + 1.5 * v, z0 + (z + 0.5) * v), v * 0.8, Color(1.0, 0.95, 0.75, LUMIERE))
		_cube(st, Vector3(x0 - 0.03, y_sol + 1.5 * v, z0 + (z + 0.5) * v), v * 0.8, Color(1.0, 0.2, 0.15, LUMIERE))
	for z in range(1, W - 1):
		_cube(st, Vector3(x0 + L * v + 0.02, y_sol + 1.5 * v, z0 + (z + 0.5) * v), v * 0.7, chrome.darkened(0.3))
	if indice == 5:
		_cube(st, Vector3(x0 + (int(cab[0]) + 2.0) * v, y_sol + (toit_y + 1.4) * v, 0.0), v * 1.6, Color(1.0, 0.85, 0.3, LUMIERE))
	if indice == 9:
		_cube(st, Vector3(x0 + (int(cab[0]) + 2.0) * v, y_sol + (toit_y + 1.3) * v, -0.4), v * 1.2, Color(0.3, 0.5, 1.0, LUMIERE))
		_cube(st, Vector3(x0 + (int(cab[0]) + 2.0) * v, y_sol + (toit_y + 1.3) * v, 0.4), v * 1.2, Color(1.0, 0.25, 0.25, LUMIERE))
	var maillage := st.commit()
	return maillage

## Les peintures d'usine, par modèle : le taxi est jaune, la police blanche, le
## reste tiré parmi des teintes de carrosserie.
const PEINTURES := [Color("#c8c8cc"), Color("#2b2f38"), Color("#8a1e1e"), Color("#1f4a8a"), Color("#3a6b3a"),
	Color("#d9d9d4"), Color("#5a3a7a"), Color("#c96b1e"), Color("#7a7f88"), Color("#e0b23a")]

static func peinture(indice: int, graine: int) -> Color:
	match indice:
		5: return Color("#f2c21c")
		9: return Color("#f0f0f2")
		6: return Color("#e8e8e4") if graine % 3 != 0 else Color("#4a4a52")
		7: return Color("#d4d4d0")
	return PEINTURES[posmod(graine, PEINTURES.size())]

# ------------------------------------------------------------ les personnages

const VOXEL_PERSONNAGE := 0.24

## Un personnage en cubes FINS (un quart d'unité) : jambes articulées (nœuds
## « JambeG » et « JambeD » pivotés à la hanche, avec pantalon et chaussures),
## torse de la couleur donnée avec une ceinture, bras qui se balancent (« BrasG »,
## « BrasD »), tête couleur peau, cheveux, yeux. Il regarde +X. Sa hauteur :
## environ trois unités et demie, comme avant — seulement plus de cubes.
static func personnage(couleur: Color, peau: Color = Color(0.9, 0.72, 0.6), cheveux: Color = Color(0.25, 0.18, 0.12)) -> Node3D:
	var racine := Node3D.new()
	var v := VOXEL_PERSONNAGE
	var pantalon := Color(0.2, 0.22, 0.3, MUR)
	var chaussure := Color(0.12, 0.1, 0.1, MUR)
	var teinte := Color(couleur, MUR)
	var hanche := 6.0 * v
	for cote in [-1.0, 1.0]:
		var jambe := MeshInstance3D.new()
		jambe.name = "JambeG" if cote < 0.0 else "JambeD"
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Pivot à la hanche : deux voxels de large, six de haut, la chaussure
		# qui avance d'un voxel.
		for k in 6:
			for dz in 2:
				for dx in 2:
					_cube(st, Vector3((dx - 0.5) * v, -0.5 * v - k * v, (dz - 0.5) * v), v,
						pantalon.lightened(0.04 * (k % 2)) if k < 5 else chaussure)
		for dz in 2:
			_cube(st, Vector3(1.5 * v, -5.5 * v, (dz - 0.5) * v), v, chaussure)
		jambe.mesh = st.commit()
		jambe.material_override = matiere_voxel()
		jambe.position = Vector3(0, hanche, cote * 1.0 * v)
		racine.add_child(jambe)
	for cote in [-1.0, 1.0]:
		var bras := MeshInstance3D.new()
		bras.name = "BrasG" if cote < 0.0 else "BrasD"
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Pivot à l'épaule : la manche puis la main.
		for k in 5:
			_cube(st, Vector3(0, -0.5 * v - k * v, 0), v, teinte.darkened(0.15) if k < 4 else Color(peau, MUR))
		bras.mesh = st.commit()
		bras.material_override = matiere_voxel()
		bras.position = Vector3(0, hanche + 5.5 * v, cote * 2.5 * v)
		racine.add_child(bras)
	var corps := MeshInstance3D.new()
	corps.name = "Corps"
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Le torse : quatre de large, deux d'épais, six de haut ; une ceinture
	# sombre en bas, un col plus clair en haut.
	for k in 6:
		for z in range(-2, 2):
			for x in range(-1, 1):
				var c := teinte.lightened(0.05 * (k % 2)) if k > 0 else Color(0.15, 0.12, 0.1, MUR)
				if k == 5 and abs(z + 0.5) < 1.0:
					c = teinte.lightened(0.2)
				_cube(st2, Vector3((x + 0.5) * v, hanche + (k + 0.5) * v, (z + 0.5) * v), v, c)
	# Les épaules.
	for z in [-2.5, 2.5]:
		_cube(st2, Vector3(0, hanche + 5.5 * v, z * v), v, teinte.darkened(0.1))
	# Le cou, la tête (trois cubes de côté), les cheveux, les yeux, le nez.
	var y_tete := hanche + 6.0 * v
	_cube(st2, Vector3(0, y_tete + 0.5 * v, 0), v, Color(peau, MUR))
	for k in 3:
		for z in range(-1, 2):
			for x in range(-1, 2):
				_cube(st2, Vector3(x * v, y_tete + (1.5 + k) * v, z * v), v, Color(peau, MUR))
	for z in range(-1, 2):
		for x in range(-1, 2):
			_cube(st2, Vector3(x * v, y_tete + 4.5 * v, z * v), v, Color(cheveux, MUR))
		# La nuque : les cheveux descendent d'un cube à l'arrière.
		_cube(st2, Vector3(-1.0 * v, y_tete + 3.5 * v, z * v), v * 1.02, Color(cheveux, MUR))
	for z in [-1, 1]:
		_cube(st2, Vector3(1.55 * v, y_tete + 3.0 * v, z * 0.6 * v), v * 0.5, Color(0.08, 0.08, 0.1, MUR))
	_cube(st2, Vector3(1.6 * v, y_tete + 2.4 * v, 0), v * 0.5, Color(peau, MUR).darkened(0.1))
	corps.mesh = st2.commit()
	corps.material_override = matiere_voxel()
	racine.add_child(corps)
	return racine

## Balance les jambes (et les bras, en opposition) d'un personnage qui
## marche ; les remet droits sinon.
static func animer(personnage_noeud: Node3D, marche: bool, temps: float, vitesse: float = 9.0) -> void:
	var g := personnage_noeud.get_node_or_null("JambeG") as Node3D
	var d := personnage_noeud.get_node_or_null("JambeD") as Node3D
	if g == null or d == null:
		return
	var angle := sin(temps * vitesse) * 0.7 if marche else 0.0
	g.rotation.z = angle
	d.rotation.z = -angle
	var bg := personnage_noeud.get_node_or_null("BrasG") as Node3D
	var bd := personnage_noeud.get_node_or_null("BrasD") as Node3D
	if bg and bd:
		bg.rotation.z = -angle * 0.8
		bd.rotation.z = angle * 0.8

# ------------------------------------------------------------ outils

## Un cube dans un SurfaceTool, ses six faces, une couleur (alpha = matière).
static func _cube(st: SurfaceTool, centre: Vector3, cote: float, couleur: Color) -> void:
	var h := cote * 0.5
	var faces := [
		[Vector3(-h, -h, h), Vector3(h, -h, h), Vector3(h, h, h), Vector3(-h, h, h), Vector3(0, 0, 1)],
		[Vector3(h, -h, -h), Vector3(-h, -h, -h), Vector3(-h, h, -h), Vector3(h, h, -h), Vector3(0, 0, -1)],
		[Vector3(-h, h, -h), Vector3(-h, h, h), Vector3(h, h, h), Vector3(h, h, -h), Vector3(0, 1, 0)],
		[Vector3(-h, -h, h), Vector3(-h, -h, -h), Vector3(h, -h, -h), Vector3(h, -h, h), Vector3(0, -1, 0)],
		[Vector3(-h, -h, -h), Vector3(-h, -h, h), Vector3(-h, h, h), Vector3(-h, h, -h), Vector3(-1, 0, 0)],
		[Vector3(h, -h, h), Vector3(h, -h, -h), Vector3(h, h, -h), Vector3(h, h, h), Vector3(1, 0, 0)],
	]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for face in faces:
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_color(couleur)
			st.set_uv(uvs[k])
			st.set_normal(face[4])
			st.add_vertex(centre + face[k])

static var _matiere: ShaderMaterial

## La matière des maillages voxel à couleurs de sommet (voitures, personnages) :
## le même shader que la nappe des immeubles, la couleur venant du sommet.
static func matiere_voxel() -> ShaderMaterial:
	if _matiere == null:
		_matiere = MatieresCarnage.voxel()
	return _matiere
