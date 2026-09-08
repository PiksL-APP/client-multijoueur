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

const V := 1.0                 ## côté d'un voxel d'immeuble, en unités 3D
const E := 2.0                 ## échelle des ornements (corniches, balcons, toits) — l'ancienne taille de cube
const PETIT := 1.0             ## côté d'un voxel de mobilier
const MUR := 1.0
const LUMIERE := 0.5
const VITRE := 0.1
const ECLAIRE := 0.85          ## un mur qui reçoit la lumière d'une fenêtre allumée : s'éclaire la nuit, mur le jour
const BRUT := 0.95             ## une matière qui garde sa couleur quelle que soit la peinture (pneu, chrome, feu)
const ETAGE := 3               ## voxels par étage : une bande de plancher, deux de fenêtre

## Ce qu'une fiche d'immeuble devient : ses dimensions en voxels, le coin
## minimal en unités 3D, l'occupation (1 = plein) et ce qu'il faut pour colorer
## n'importe quelle cellule sans la stocker (`couleur_cellule`).
## `indice(i, j, k)` = (i * nz + j) * ny + k.
##
## Les voxels font UNE unité : un étage fait trois cubes, une fenêtre un cube
## de large sur deux de haut, en RETRAIT d'un cube dans la façade. À cette
## finesse on ne dessine plus un cube par instance — un morceau en aurait un
## million — mais des MAILLAGES FUSIONNÉS (`mailler`) : seules les faces
## visibles existent, et les faces de même couleur d'un mur se fondent en un
## rectangle. La casse enlève une cellule et refait le maillage du pâté.
## La grille seule : dimensions, coin, taille — ce dont l'hôte a besoin pour
## dire quel cube une balle a touché, sans rien dessiner.
static func grille(b: Dictionary) -> Dictionary:
	var nx: int = clamp(int(round(float(b["w"]) * Decor.ECHELLE / V)), 1, 31)
	var nz: int = clamp(int(round(float(b["d"]) * Decor.ECHELLE / V)), 1, 31)
	var ny: int = clamp(int(round(float(b["h"]) / V)), 1, 63)
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

## La clé LOCALE d'une cellule, celle qui voyage sur le réseau : i et j sur
## cinq bits (31 cellules, deux tuiles), k sur six (63, une tour de 34 unités).
static func cle_locale(i: int, j: int, k: int) -> int:
	return (i * 32 + j) * 64 + k

static func decoder_locale(locale: int) -> Vector3i:
	return Vector3i(locale / 2048, (locale / 64) % 32, locale % 64)

## Le voxel de la grille le plus proche d'un point 3D (occupation ignorée).
static func voxel_proche_de(b: Dictionary, point: Vector3) -> int:
	var g := grille(b)
	var o: Vector3 = g["origine"]
	var i: int = clamp(int(floor((point.x - o.x) / float(g["taille"]))), 0, int(g["nx"]) - 1)
	var j: int = clamp(int(floor((point.z - o.z) / float(g["taille"]))), 0, int(g["nz"]) - 1)
	var k: int = clamp(int(floor((point.y - o.y) / float(g["hauteur"]))), 0, int(g["ny"]) - 1)
	return cle_locale(i, j, k)

## Les voxels de la grille à moins de `rayon` d'un point (occupation ignorée).
## On ne parcourt que la boîte du rayon, pas l'immeuble : une roquette sur une
## tour de trente mille cellules ne coûte que celles qu'elle touche.
static func voxels_autour_de(b: Dictionary, point: Vector3, rayon: float) -> Array:
	var g := grille(b)
	var o: Vector3 = g["origine"]
	var t := float(g["taille"])
	var h := float(g["hauteur"])
	var liste: Array = []
	var i0: int = max(0, int(floor((point.x - rayon - o.x) / t)))
	var i1: int = min(int(g["nx"]) - 1, int(floor((point.x + rayon - o.x) / t)))
	var j0: int = max(0, int(floor((point.z - rayon - o.z) / t)))
	var j1: int = min(int(g["nz"]) - 1, int(floor((point.z + rayon - o.z) / t)))
	var k0: int = max(0, int(floor((point.y - rayon - o.y) / h)))
	var k1: int = min(int(g["ny"]) - 1, int(floor((point.y + rayon - o.y) / h)))
	for i in range(i0, i1 + 1):
		for j in range(j0, j1 + 1):
			for k in range(k0, k1 + 1):
				if centre_voxel(g, i, j, k).distance_to(point) <= rayon:
					liste.append(cle_locale(i, j, k))
	return liste

## Un bruit déterministe par cellule : c'est lui qui décide des portes, des
## fenêtres allumées, des tons — sans générateur à dérouler dans l'ordre, pour
## qu'une cellule se colore seule, quand on la dessine.
static func _bruit(graine: int, a: int, b: int, c: int) -> float:
	return float(hash(Vector4i(a, b, c, graine)) & 0x7FFFFF) / 8388608.0

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
	var trous := PackedInt32Array()        # les cellules vides DANS la boîte : retraits, creux, fenêtres, casse
	var fonds: Dictionary = {}             # indice -> couleur du fond d'une fenêtre en retrait
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	# Le toit : sa couleur vient du style, pas du mur — une façade ocre sous
	# un toit de tuiles, un bureau clair sous du gravier. La caméra voit les
	# toits avant les façades : c'est eux qui colorent la ville vue d'en haut.
	var toits: Array = PlanVille.TOITS_PAR_STYLE.get(style, PlanVille.TOITS_PAR_STYLE[PlanVille.F_PLEIN])
	var toit: Color = toits[rng.randi_range(0, toits.size() - 1)]
	# Les TOITS EN PENTE font partie de la grille : des rangs de cellules qui se
	# resserrent d'un cube par rang jusqu'au faîte, dans la couleur des tuiles,
	# maillés avec le reste — une pyramide lisse, pas un empilement de lames
	# posées dessus. `ny_mur` est le dernier rang de façade ; au-dessus, le toit.
	var creux_possible := style in [PlanVille.F_LOGEMENTS, PlanVille.F_VIEUX, PlanVille.F_COMMERCE] and nx >= 10 and nz >= 10
	var retrait_possible := style in [PlanVille.F_TOUR, PlanVille.F_BUREAUX] and ny >= 15 and nx >= 8 and nz >= 8
	var tirage_retrait := rng.randf()
	var tirage_creux := rng.randf()
	var tirage_pente := rng.randf()
	var pente: bool = not plat and not (retrait_possible and tirage_retrait < 0.7) and not (creux_possible and tirage_creux < 0.45) \
		and min(nx, nz) <= 12 and ((style in [PlanVille.F_VIEUX, PlanVille.F_LOGEMENTS] and min(nx, nz) >= 6 and tirage_pente < 0.75)
			or (style == PlanVille.F_MAISON and min(nx, nz) >= 4 and tirage_pente < 0.85))
	var ny_mur := ny
	var faite_x := nx >= nz               # le faîte court le long du côté le plus long
	var rangs_toit := 0
	if pente:
		rangs_toit = (nz if faite_x else nx) / 2
		ny = min(63, ny_mur + rangs_toit)
		rangs_toit = ny - ny_mur
		solide.resize(nx * nz * ny)
		solide.fill(1)
	var imm := {"nx": nx, "nz": nz, "ny": ny, "ny_mur": ny_mur, "origine": origine, "taille": V,
		"hauteur": float(g["hauteur"]), "solide": solide, "trous": trous, "fonds": fonds, "style": style,
		"teinte": teinte, "toit": toit, "plat": plat, "retrait": -1, "creux": false, "graine": graine,
		"pente": pente, "faite_x": faite_x, "cheminee": Vector2i(-1, -1),
		"part": _part_allumee(style), "porte": rng.randi_range(2, max(2, nx - 3)),
		"vitre_teinte": Color(0.09, 0.11, 0.16, VITRE)}
	if plat:
		return imm
	if pente:
		# On creuse ce qui dépasse de la pente : au rang r du toit, il reste
		# les cellules à plus de r du bord, de part et d'autre du faîte.
		for r in range(1, rangs_toit + 1):
			var k := ny_mur + r - 1
			for i in nx:
				for j in nz:
					var d: int = min(j, nz - 1 - j) if faite_x else min(i, nx - 1 - i)
					if d < r - 1:
						_creuser(imm, i, j, k)
		# Une cheminée en briques sur le faîte, deux cubes au-dessus.
		if rng.randf() < 0.8 and ny <= 61:
			var ci := rng.randi_range(1, nx - 2) if faite_x else nx / 2
			var cj := nz / 2 if faite_x else rng.randi_range(1, nz - 2)
			imm["cheminee"] = Vector2i(ci, cj)
			var haut_faite := ny
			ny = min(63, ny + 2)
			imm["ny"] = ny
			solide.resize(nx * nz * ny)
			# Le redimensionnement décale l'indexation : on rebâtit la grille.
			var neuf := PackedByteArray()
			neuf.resize(nx * nz * ny)
			for i in nx:
				for j in nz:
					for k in haut_faite:
						neuf[(i * nz + j) * ny + k] = solide[(i * nz + j) * haut_faite + k]
					for k in range(haut_faite, ny):
						neuf[(i * nz + j) * ny + k] = 1 if (i == ci and j == cj) else 0
			solide = neuf
			imm["solide"] = solide
			# Les trous ont été calculés dans l'ancienne indexation : on les refait —
			# y compris le vide autour de la cheminée, sinon le faîte, qui n'est
			# plus le dernier rang, n'aurait pas de dessus.
			var trous_neufs := PackedInt32Array()
			for i in nx:
				for j in nz:
					for k in ny:
						if neuf[(i * nz + j) * ny + k] == 0:
							trous_neufs.append((i * nz + j) * ny + k)
			imm["trous"] = trous_neufs

	# La SILHOUETTE : une tour ou un immeuble de bureaux assez haut se rétrécit
	# au dernier tiers (un retrait d'un cube tout autour, puis un attique) ; un
	# immeuble de logements assez large perd un angle sur toute sa hauteur —
	# une cour, un L. Sans ça, la ville n'est qu'un alignement de boîtes.
	if retrait_possible and tirage_retrait < 0.7:
		var retrait := int(float(ny) * 0.8)
		imm["retrait"] = retrait
		for k in range(retrait, ny):
			for i in nx:
				for j in nz:
					if i == 0 or i == nx - 1 or j == 0 or j == nz - 1:
						_creuser(imm, i, j, k)
	if creux_possible and tirage_creux < 0.45:
		imm["creux"] = true
		var cx := rng.randi_range(0, 1)
		var cz := rng.randi_range(0, 1)
		var lx := rng.randi_range(3, nx / 2)
		var lz := rng.randi_range(3, nz / 2)
		for i in nx:
			for j in nz:
				var dans_x := (i < lx) if cx == 0 else (i >= nx - lx)
				var dans_z := (j < lz) if cz == 0 else (j >= nz - lz)
				if dans_x and dans_z:
					for k in ny:
						_creuser(imm, i, j, k)

	# Les fenêtres en RETRAIT : sur chaque façade — les quatre côtés de la
	# boîte ET les parois de la cour d'un immeuble en L —, la cellule de la
	# fenêtre se vide et la cellule derrière elle prend la couleur du verre (ou
	# de la lumière). Les flancs des cellules voisines font l'encadrement.
	if style != PlanVille.F_PLEIN and style != PlanVille.F_TOUR and nx >= 3 and nz >= 3:
		# ⚠ Le dehors se juge sur la silhouette D'AVANT les fenêtres : sinon la
		# cellule derrière une fenêtre se voit un côté vide, s'ouvre à son tour,
		# et l'immeuble se creuse jusqu'au cœur.
		var silhouette := solide.duplicate()
		for k in range(1, ny_mur - 1):
			for i in nx:
				for j in nz:
					var idx := (i * nz + j) * ny + k
					if solide[idx] == 0:
						continue
					var dehors: Vector2i = _dehors(imm, silhouette, i, j, k)
					if dehors == Vector2i.ZERO:
						continue
					var f := _ouverture(imm, i, j, k, dehors)
					if f == 0:
						continue
					# La cellule derrière : à l'opposé du dehors.
					var bi: int = i - dehors.x
					var bj: int = j - dehors.y
					if bi < 0 or bj < 0 or bi >= nx or bj >= nz:
						continue
					var bidx: int = (bi * nz + bj) * ny + k
					if solide[bidx] == 0 or fonds.has(bidx):
						continue
					_creuser(imm, i, j, k)
					fonds[bidx] = _couleur_ouverture(imm, f, i, j, k)
	return imm

## La direction du DEHORS d'une cellule de façade : le côté où il n'y a rien
## (hors de la boîte, ou une cellule creusée par la cour). Zéro si la cellule
## est intérieure, ou si c'est un angle (deux côtés dehors : pas de fenêtre).
static func _dehors(imm: Dictionary, solide: PackedByteArray, i: int, j: int, k: int) -> Vector2i:
	var nx := int(imm["nx"])
	var nz := int(imm["nz"])
	var ny := int(imm["ny"])
	var trouve := Vector2i.ZERO
	var combien := 0
	for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var vi: int = i + d.x
		var vj: int = j + d.y
		var vide := vi < 0 or vj < 0 or vi >= nx or vj >= nz or solide[(vi * nz + vj) * ny + k] == 0
		if vide:
			trouve = d
			combien += 1
	return trouve if combien == 1 else Vector2i.ZERO

static func _creuser(imm: Dictionary, i: int, j: int, k: int) -> void:
	var idx := (i * int(imm["nz"]) + j) * int(imm["ny"]) + k
	var solide: PackedByteArray = imm["solide"]
	if solide[idx] == 1:
		solide[idx] = 0
		# ⚠ Un tableau compact lu dans un dictionnaire puis allongé n'allonge
		# qu'une copie : on le réécrit dans la fiche. Sans ça, aucun trou n'avait
		# de face et les fenêtres étaient des puits noirs.
		var trous: PackedInt32Array = imm["trous"]
		trous.append(idx)
		imm["trous"] = trous

## Ce qu'une cellule de façade ouvre : 0 rien, 1 fenêtre, 2 vitrine, 3 porte.
## `dehors` : le côté de la rue.
static func _ouverture(imm: Dictionary, i: int, j: int, k: int, dehors: Vector2i) -> int:
	var nx := int(imm["nx"])
	var nz := int(imm["nz"])
	var ny := int(imm.get("ny_mur", imm["ny"]))
	var style := int(imm["style"])
	if k >= ny - 1:
		return 0
	var le_long := i if dehors.y != 0 else j
	var longueur := nx if dehors.y != 0 else nz
	# La porte : sur les façades nord et ouest seulement, une par immeuble.
	var cote_porte := dehors == Vector2i(0, -1) or dehors == Vector2i(-1, 0)
	var etage := k % ETAGE
	if etage == 0:
		return 0
	match style:
		PlanVille.F_HANGAR:
			# Un bandeau de fenêtres sous le toit, une grande porte au milieu.
			if k >= ny - 3 and posmod(le_long, 2) == 1:
				return 1
			if k <= 3 and abs(le_long - longueur / 2) <= 1 and cote_porte:
				return 3
			return 0
		PlanVille.F_COMMERCE:
			if k <= 2:
				if posmod(le_long, 4) == 0:
					return 0            # un pilier entre deux vitrines
				if le_long == int(imm["porte"]) and cote_porte:
					return 3
				return 2
			return 1 if posmod(le_long, 3) != 0 else 0
		_:
			if k <= 2 and le_long == int(imm["porte"]) and cote_porte:
				return 3
			# Des fenêtres de DEUX cubes de large, un trumeau entre deux : une
			# baie qui se lit, pas une meurtrière.
			return 1 if posmod(le_long, 3) != 0 else 0

static func _couleur_ouverture(imm: Dictionary, f: int, i: int, j: int, k: int) -> Color:
	var graine := int(imm["graine"])
	var chaud := Color(1.0, 0.82, 0.55)
	var froid := Color(0.65, 0.82, 1.0)
	match f:
		3:
			return (imm["teinte"] as Color).darkened(0.6)
		2:
			if _bruit(graine, i, j, 1) < 0.75:
				return Color(chaud.lerp(Color.WHITE, 0.3), LUMIERE)
			return imm["vitre_teinte"]
		_:
			# Une même fenêtre (deux cubes de large, deux de haut) est allumée ou
			# éteinte d'un bloc : on la repère par sa travée, pas par sa cellule.
			var kf := k - (k % ETAGE)
			var wi := i / 3
			var wj := j / 3
			if _bruit(graine, wi + wj * 37, kf, 2) < float(imm["part"]):
				var lum := chaud if _bruit(graine, wi, kf + wj, 3) < 0.72 else froid
				return Color(lum.lerp(Color.WHITE, _bruit(graine, wj, kf + wi, 4) * 0.25), LUMIERE)
			return imm["vitre_teinte"]

## La couleur d'une cellule, calculée quand on la dessine : toit, fond de
## fenêtre, façade (avec la bande de plancher, la crasse du bas, la façade de
## verre des tours) ou intérieur gris.
static func couleur_cellule(imm: Dictionary, i: int, j: int, k: int) -> Color:
	var nx := int(imm["nx"])
	var nz := int(imm["nz"])
	var ny := int(imm["ny"])
	var teinte: Color = imm["teinte"]
	if bool(imm["plat"]):
		return teinte
	var idx := (i * nz + j) * ny + k
	var fonds: Dictionary = imm["fonds"]
	if fonds.has(idx):
		return fonds[idx]
	var ny_mur := int(imm.get("ny_mur", ny))
	if k >= ny_mur:
		# Le toit en pente : des tuiles, un ton plus clair par rang vers le
		# faîte ; la cheminée en briques sombres.
		var cheminee: Vector2i = imm.get("cheminee", Vector2i(-1, -1))
		if cheminee.x == i and cheminee.y == j and k >= ny - 2:
			return Color(0.36, 0.24, 0.2)
		return (imm["toit"] as Color).darkened(0.18).lightened(0.02 * float(k - ny_mur))
	var bord := i == 0 or i == nx - 1 or j == 0 or j == nz - 1
	var retrait := int(imm["retrait"])
	var sommet := k == ny_mur - 1 or (retrait >= 0 and k == retrait - 1 and bord)
	if bool(imm.get("pente", false)) and k == ny_mur - 1:
		sommet = false                      # sous un toit en pente, le dernier rang est encore du mur
	if sommet:
		# La dernière couche est du toit ; son anneau extérieur, un parapet dans
		# la couleur du mur.
		# ⚠ Le plein soleil tombe à pic sur les toits : sans les assombrir, un
		# gravier gris sortait blanc en photo.
		if k == ny_mur - 1 and retrait < 0:
			# Au dernier rang il n'y a pas de fenêtre : un voisin vide est la rue
			# ou la cour, et la cellule est un parapet.
			var solide_h: PackedByteArray = imm["solide"]
			var parapet := bord
			if not parapet:
				for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					if solide_h[((i + d.x) * nz + j + d.y) * ny + k] == 0:
						parapet = true
						break
			if parapet:
				# Clair sur un toit sombre : c'est le trait qui dessine le contour
				# de l'immeuble vu d'en haut.
				return teinte.lightened(0.22)
		return (imm["toit"] as Color).darkened(0.28)
	var style := int(imm["style"])
	if not bord:
		# Une façade intérieure (le creux d'un L) se colore comme une façade ;
		# le reste est le gris des intérieurs, qu'on ne voit qu'une fois le mur
		# parti.
		var solide: PackedByteArray = imm["solide"]
		var expose := (i > 0 and solide[((i - 1) * nz + j) * ny + k] == 0) or (i < nx - 1 and solide[((i + 1) * nz + j) * ny + k] == 0) \
			or (j > 0 and solide[(i * nz + j - 1) * ny + k] == 0) or (j < nz - 1 and solide[(i * nz + j + 1) * ny + k] == 0)
		if not expose or bool(imm["creux"]) == false:
			return Color(0.42, 0.40, 0.38)
	if style == PlanVille.F_TOUR:
		# La tour : un mur-rideau de verre, ses meneaux tous les trois cubes.
		var le_long := i if (j == 0 or j == nz - 1) else j
		if k % ETAGE == 0 or posmod(le_long, 3) == 0:
			return teinte.darkened(0.35)
		return _couleur_ouverture(imm, 1, i, j, k)
	var couleur := teinte
	if k % ETAGE == 0:
		couleur = teinte.darkened(0.07)          # la bande de plancher
	if k == ny_mur - 2:
		couleur = couleur.darkened(0.08)         # sous la corniche
	# La crasse du bas : une façade est plus sombre au ras du trottoir qu'au
	# dernier étage.
	if ny_mur > 1:
		couleur = couleur.darkened(0.16 * (1.0 - float(k) / float(ny_mur - 1)))
	return couleur

static func _part_allumee(style: int) -> float:
	match style:
		PlanVille.F_TOUR: return 0.45
		PlanVille.F_BUREAUX: return 0.45
		PlanVille.F_COMMERCE: return 0.6
		PlanVille.F_HANGAR: return 0.3
		PlanVille.F_MAISON: return 0.6
		PlanVille.F_PLEIN: return 0.0
	return 0.5

# ------------------------------------------------------------ le maillage

## Le maillage FUSIONNÉ d'un immeuble, ajouté aux tableaux donnés (sommets,
## normales, couleurs, UV, indices) : les six faces de la boîte en rectangles
## gloutons — les cellules voisines de même couleur se fondent — et, pour
## chaque trou (fenêtre, retrait, casse), les faces des cellules pleines qui
## le bordent, une à une. C'est ce qui rend l'unité de voxel abordable : un mur
## de trente sur seize n'est plus quatre cent quatre-vingts cubes de douze
## triangles mais une trentaine de rectangles.
static func mailler(imm: Dictionary, sommets: PackedVector3Array, normales: PackedVector3Array,
		couleurs: PackedColorArray, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	var nx := int(imm["nx"])
	var nz := int(imm["nz"])
	var ny := int(imm["ny"])
	var o: Vector3 = imm["origine"]
	var h := float(imm["hauteur"])
	var solide: PackedByteArray = imm["solide"]
	var tableaux := [sommets, normales, couleurs, uvs, indices]
	# Les cinq faces de la boîte (le dessous ne se voit jamais).
	# -X : tranche i = 0, a = j, b = k.
	_tranche(imm, tableaux, 0, -1, nz, ny, o, Vector3(0, 0, 1), Vector3(0, h, 0), Vector3(-1, 0, 0))
	_tranche(imm, tableaux, 0, 1, nz, ny, o + Vector3(nx, 0, 0), Vector3(0, 0, 1), Vector3(0, h, 0), Vector3(1, 0, 0))
	# -Z / +Z : tranche j, a = i, b = k.
	_tranche(imm, tableaux, 1, -1, nx, ny, o, Vector3(1, 0, 0), Vector3(0, h, 0), Vector3(0, 0, -1))
	_tranche(imm, tableaux, 1, 1, nx, ny, o + Vector3(0, 0, nz), Vector3(1, 0, 0), Vector3(0, h, 0), Vector3(0, 0, 1))
	# +Y : le toit, a = i, b = j.
	_tranche(imm, tableaux, 2, 1, nx, nz, o + Vector3(0, ny * h, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))
	# Les trous : chaque cellule pleine qui borde un vide montre sa face.
	var trous: PackedInt32Array = imm["trous"]
	for idx in trous:
		var i := idx / (nz * ny)
		var j := (idx / ny) % nz
		var k := idx % ny
		if i > 0 and solide[idx - nz * ny] == 1:
			_face(imm, tableaux, i - 1, j, k, Vector3(1, 0, 0))
		if i < nx - 1 and solide[idx + nz * ny] == 1:
			_face(imm, tableaux, i + 1, j, k, Vector3(-1, 0, 0))
		if j > 0 and solide[idx - ny] == 1:
			_face(imm, tableaux, i, j - 1, k, Vector3(0, 0, 1))
		if j < nz - 1 and solide[idx + ny] == 1:
			_face(imm, tableaux, i, j + 1, k, Vector3(0, 0, -1))
		if k > 0 and solide[idx - 1] == 1:
			_face(imm, tableaux, i, j, k - 1, Vector3(0, 1, 0), _appui(imm, i, j, k))
		if k < ny - 1 and solide[idx + 1] == 1:
			_face(imm, tableaux, i, j, k + 1, Vector3(0, -1, 0))

## Une tranche de la boîte : masque des cellules pleines (par couleur), puis
## rectangles gloutons. `axe` : 0 = tranche en i, 1 = en j, 2 = en k (toit).
static func _tranche(imm: Dictionary, tableaux: Array, axe: int, sens: int, du: int, dv: int,
		origine: Vector3, ua: Vector3, vb: Vector3, normale: Vector3) -> void:
	var nx := int(imm["nx"])
	var nz := int(imm["nz"])
	var ny := int(imm["ny"])
	var solide: PackedByteArray = imm["solide"]
	# ⚠ 64 bits : `to_rgba32` dépasse le signé 32 bits, un PackedInt32Array le
	# tronquerait en négatif et la clé ne retrouverait plus sa couleur.
	var masque := PackedInt64Array()
	masque.resize(du * dv)
	var teintes: Dictionary = {}          # clé rgba -> Color
	var d := 0
	if sens > 0:
		d = [nx - 1, nz - 1, ny - 1][axe]
	for bb in dv:
		for aa in du:
			var i: int
			var j: int
			var k: int
			match axe:
				0: i = d; j = aa; k = bb
				1: i = aa; j = d; k = bb
				_: i = aa; j = bb; k = d
			var idx := (i * nz + j) * ny + k
			if solide[idx] == 0:
				masque[bb * du + aa] = 0
				continue
			var c := couleur_cellule(imm, i, j, k)
			var cle := c.to_rgba32() | 1
			masque[bb * du + aa] = cle
			if not teintes.has(cle):
				teintes[cle] = c
	# Fusion gloutonne : on étend à droite tant que la couleur tient, puis vers
	# le haut tant que toute la ligne tient.
	for bb in dv:
		var aa := 0
		while aa < du:
			var c := masque[bb * du + aa]
			if c == 0:
				aa += 1
				continue
			var w := 1
			while aa + w < du and masque[bb * du + aa + w] == c:
				w += 1
			var hh := 1
			var ok := true
			while bb + hh < dv and ok:
				var base := (bb + hh) * du + aa
				for x in w:
					if masque[base + x] != c:
						ok = false
						break
				if ok:
					hh += 1
			for y in hh:
				var base2 := (bb + y) * du + aa
				for x in w:
					masque[base2 + x] = 0
			_quad(tableaux, origine + ua * aa + vb * bb, ua * w, vb * hh, normale, teintes[c], Vector2(aa, bb))
			aa += w

## L'APPUI d'une fenêtre : le dessus de la cellule sous le trou. C'est ce que
## la caméra, presque à la verticale, voit d'une fenêtre en retrait — la vitre
## du fond, elle, se cache dans l'embrasure. Si la fenêtre est allumée, l'appui
## reçoit sa lumière (classe ECLAIRE : mur le jour, lueur la nuit) ; sinon rien
## de spécial (alpha 0 : la couleur ordinaire).
static func _appui(imm: Dictionary, i: int, j: int, k: int) -> Color:
	var nx := int(imm["nx"])
	var nz := int(imm["nz"])
	var ny := int(imm["ny"])
	var fonds: Dictionary = imm["fonds"]
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var bi: int = i + d.x
		var bj: int = j + d.y
		if bi < 0 or bj < 0 or bi >= nx or bj >= nz:
			continue
		var bidx: int = (bi * nz + bj) * ny + k
		if fonds.has(bidx):
			var f: Color = fonds[bidx]
			if is_equal_approx(f.a, LUMIERE):
				var teinte: Color = imm["teinte"]
				return Color(teinte.lerp(Color(f.r, f.g, f.b), 0.85), ECLAIRE)
			return Color(0, 0, 0, 0)
	return Color(0, 0, 0, 0)

## La face d'une cellule pleine tournée vers `normale` ; `forcee` (alpha > 0)
## remplace la couleur calculée.
static func _face(imm: Dictionary, tableaux: Array, i: int, j: int, k: int, normale: Vector3, forcee: Color = Color(0, 0, 0, 0)) -> void:
	var o: Vector3 = imm["origine"]
	var h := float(imm["hauteur"])
	var c := couleur_cellule(imm, i, j, k) if forcee.a == 0.0 else forcee
	var coin := o + Vector3(i, k * h, j)
	if normale.x != 0.0:
		_quad(tableaux, coin + Vector3(1.0 if normale.x > 0.0 else 0.0, 0, 0), Vector3(0, 0, 1), Vector3(0, h, 0), normale, c, Vector2(j, k))
	elif normale.z != 0.0:
		_quad(tableaux, coin + Vector3(0, 0, 1.0 if normale.z > 0.0 else 0.0), Vector3(1, 0, 0), Vector3(0, h, 0), normale, c, Vector2(i, k))
	else:
		_quad(tableaux, coin + Vector3(0, h if normale.y > 0.0 else 0.0, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), normale, c, Vector2(i, j))

## Un rectangle : `p` son coin, `a` et `b` ses côtés (en unités), la normale
## décide de l'ordre des sommets (face vue de l'extérieur). Les UV portent la
## POSITION EN CELLULES sur la face (`uv0` le coin, puis la taille en unités) :
## le shader y lit les arêtes de chaque cube d'une unité et un grain par cube,
## sans dépendre de l'origine de l'immeuble qui n'est pas alignée sur l'unité.
static func _quad(tableaux: Array, p: Vector3, a: Vector3, b: Vector3, normale: Vector3, c: Color, uv0: Vector2 = Vector2.ZERO) -> void:
	var sommets: PackedVector3Array = tableaux[0]
	var normales: PackedVector3Array = tableaux[1]
	var couleurs: PackedColorArray = tableaux[2]
	var uvs: PackedVector2Array = tableaux[3]
	var indices: PackedInt32Array = tableaux[4]
	var n0 := sommets.size()
	var direct := a.cross(b).dot(normale) > 0.0
	sommets.append(p)
	sommets.append(p + a)
	sommets.append(p + a + b)
	sommets.append(p + b)
	for q in 4:
		normales.append(normale)
		couleurs.append(c)
	uvs.append(uv0)
	uvs.append(uv0 + Vector2(a.length(), 0))
	uvs.append(uv0 + Vector2(a.length(), b.length()))
	uvs.append(uv0 + Vector2(0, b.length()))
	if direct:
		indices.append_array(PackedInt32Array([n0, n0 + 2, n0 + 1, n0, n0 + 3, n0 + 2]))
	else:
		indices.append_array(PackedInt32Array([n0, n0 + 1, n0 + 2, n0, n0 + 2, n0 + 3]))

## Le maillage prêt à poser, à partir des tableaux remplis par `mailler`.
static func maillage_depuis(sommets: PackedVector3Array, normales: PackedVector3Array,
		couleurs: PackedColorArray, uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	if sommets.is_empty():
		return null
	var tableaux := []
	tableaux.resize(Mesh.ARRAY_MAX)
	tableaux[Mesh.ARRAY_VERTEX] = sommets
	tableaux[Mesh.ARRAY_NORMAL] = normales
	tableaux[Mesh.ARRAY_COLOR] = couleurs
	tableaux[Mesh.ARRAY_TEX_UV] = uvs
	tableaux[Mesh.ARRAY_INDEX] = indices
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tableaux)
	return m

## Les ORNEMENTS d'un immeuble : ce qui dépasse de la grille et n'en fait pas
## partie — corniche au dernier étage, balcons sous les fenêtres, stores au-
## dessus des vitrines, toits en pente à gradins, et sur les toits plats :
## climatiseurs, citerne, antenne, cage d'escalier, cheminées. Liste de
## [centre, taille (Vector3), couleur], posée en instances. Ce n'est pas
## cassable : une balle ne vise pas une corniche. Les tailles sont à l'échelle
## E (deux unités), pas à celle du voxel : une corniche d'un demi-cube d'une
## unité, personne ne la verrait.
static func ornements(imm: Dictionary, graine: int) -> Array:
	var liste: Array = []
	if bool(imm["plat"]):
		return liste
	var nx := int(imm["nx"])
	var nz := int(imm["nz"])
	var ny := int(imm.get("ny_mur", imm["ny"]))   # le haut des murs : le toit en pente est dans la grille
	var style := int(imm["style"])
	var teinte: Color = imm["teinte"]
	var o: Vector3 = imm["origine"]
	var rng := RandomNumberGenerator.new()
	rng.seed = graine + 77
	var retrait := int(imm["retrait"])
	var creux := bool(imm["creux"])
	var pente := bool(imm.get("pente", false))
	var lx := float(nx) * V
	var lz := float(nz) * V
	var cx := o.x + lx * 0.5
	var cz := o.z + lz * 0.5
	# Le « haut » de la boîte pleine : le sommet, ou la terrasse du retrait.
	var haut := o.y + float(ny if retrait < 0 else retrait) * V
	var sommet := o.y + float(ny) * V
	var clair := teinte.lightened(0.18)
	var sombre := teinte.darkened(0.25)

	# La corniche : une lame qui court au sommet (ou au bord de la terrasse),
	# en saillie. Pas sur un immeuble en L : elle couperait la cour.
	var corniche := style in [PlanVille.F_VIEUX, PlanVille.F_LOGEMENTS, PlanVille.F_COMMERCE, PlanVille.F_BUREAUX] and ny >= 4 and not creux
	if corniche:
		# Une lame fine : plus épaisse, elle doublait le parapet vu d'en haut.
		var e := 0.3 * E
		var y := haut - 0.2 * E
		liste.append([Vector3(cx, y, o.z - e * 0.5), Vector3(lx + 2.0 * e, 0.35 * E, e), clair])
		liste.append([Vector3(cx, y, o.z + lz + e * 0.5), Vector3(lx + 2.0 * e, 0.35 * E, e), clair])
		liste.append([Vector3(o.x - e * 0.5, y, cz), Vector3(e, 0.35 * E, lz + 2.0 * e), clair])
		liste.append([Vector3(o.x + lx + e * 0.5, y, cz), Vector3(e, 0.35 * E, lz + 2.0 * e), clair])

	# Les BANDEAUX d'étage : une fine saillie au niveau de chaque plancher,
	# sur les quatre faces. Vu de haut, c'est ce qui strie une façade et lui
	# donne ses étages ; sans eux, un mur n'est qu'un aplat troué.
	if style in [PlanVille.F_BUREAUX, PlanVille.F_LOGEMENTS, PlanVille.F_VIEUX, PlanVille.F_COMMERCE] and ny >= 7 and not creux:
		var eb := 0.15 * E
		var k_max := ny if retrait < 0 else retrait
		for k in range(ETAGE, k_max - 1, ETAGE):
			var y := o.y + float(k) * V + 0.5 * V
			liste.append([Vector3(cx, y, o.z - eb * 0.5), Vector3(lx + 2.0 * eb, 0.25 * E, eb), clair])
			liste.append([Vector3(cx, y, o.z + lz + eb * 0.5), Vector3(lx + 2.0 * eb, 0.25 * E, eb), clair])
			liste.append([Vector3(o.x - eb * 0.5, y, cz), Vector3(eb, 0.25 * E, lz + 2.0 * eb), clair])
			liste.append([Vector3(o.x + lx + eb * 0.5, y, cz), Vector3(eb, 0.25 * E, lz + 2.0 * eb), clair])

	# Les balcons : sous une fenêtre sur deux des étages supérieurs (les
	# fenêtres sont tous les trois cubes, aux rangs 1 et 2 de chaque étage),
	# une dalle qui dépasse et un garde-corps.
	if style in [PlanVille.F_LOGEMENTS, PlanVille.F_VIEUX] and ny >= 7 and not creux:
		for k in range(ETAGE, ny - 2, ETAGE):
			for cote in 4:
				var le_long := nx if cote < 2 else nz
				for m in le_long:
					if posmod(m, 3) != 1 or rng.randf() > 0.45:
						continue
					var y := o.y + (k + 1) * V - 0.15 * E
					var centre: Vector3
					var taille: Vector3
					var n: Vector3
					match cote:
						0: centre = Vector3(o.x + (m + 0.5) * V, y, o.z - 0.3 * E); taille = Vector3(1.4 * V, 0.25 * E, 0.6 * E); n = Vector3(0, 0, -1)
						1: centre = Vector3(o.x + (m + 0.5) * V, y, o.z + lz + 0.3 * E); taille = Vector3(1.4 * V, 0.25 * E, 0.6 * E); n = Vector3(0, 0, 1)
						2: centre = Vector3(o.x - 0.3 * E, y, o.z + (m + 0.5) * V); taille = Vector3(0.6 * E, 0.25 * E, 1.4 * V); n = Vector3(-1, 0, 0)
						_: centre = Vector3(o.x + lx + 0.3 * E, y, o.z + (m + 0.5) * V); taille = Vector3(0.6 * E, 0.25 * E, 1.4 * V); n = Vector3(1, 0, 0)
					liste.append([centre, taille, sombre])
					liste.append([centre + n * 0.25 * E + Vector3(0, 0.45 * E, 0),
						Vector3(0.1 * E, 0.6 * E, 1.4 * V) if cote >= 2 else Vector3(1.4 * V, 0.6 * E, 0.1 * E), Color(0.15, 0.15, 0.17)])

	# Les stores des vitrines : une lame de couleur au-dessus du rez-de-chaussée.
	if style == PlanVille.F_COMMERCE and ny >= 4:
		var store: Color = PlanVille.NEONS[rng.randi_range(0, PlanVille.NEONS.size() - 1)]
		store = store.lerp(Color(0.9, 0.9, 0.85), 0.35)
		var y := o.y + float(ETAGE) * V - 0.1 * E
		for cote in 4:
			if rng.randf() > 0.7:
				continue
			match cote:
				0: liste.append([Vector3(cx, y, o.z - 0.45 * E), Vector3(lx - 1.0 * E, 0.2 * E, 0.9 * E), store])
				1: liste.append([Vector3(cx, y, o.z + lz + 0.45 * E), Vector3(lx - 1.0 * E, 0.2 * E, 0.9 * E), store])
				2: liste.append([Vector3(o.x - 0.45 * E, y, cz), Vector3(0.9 * E, 0.2 * E, lz - 1.0 * E), store])
				_: liste.append([Vector3(o.x + lx + 0.45 * E, y, cz), Vector3(0.9 * E, 0.2 * E, lz - 1.0 * E), store])

	# Les toits en pente sont dans la grille de l'immeuble (voir `immeuble`) :
	# rien à poser dessus, sauf une gouttière — la lame de la corniche suffit.

	# Le toit plat : ce que la caméra voit le plus. Du désordre — climatiseurs,
	# citerne, antenne, cage d'escalier — sur les immeubles assez grands.
	if nx >= 5 and nz >= 5 and style != PlanVille.F_MAISON and not creux and not pente:
		var marge := 1.2 if retrait < 0 else 2.2
		var libre := func() -> Vector3:
			return Vector3(o.x + rng.randf_range(marge, lx - marge), sommet, o.z + rng.randf_range(marge, lz - marge))
		var gris := Color(0.62, 0.63, 0.65)
		var combien := rng.randi_range(1, 2 if nx * nz < 150 else 4)
		for c in combien:
			var t := rng.randf()
			var ou: Vector3 = libre.call()
			if t < 0.4:
				# Un climatiseur : une boîte claire, une grille sombre dessus.
				liste.append([ou + Vector3(0, 0.3 * E, 0), Vector3(0.9 * E, 0.6 * E, 0.9 * E), gris])
				liste.append([ou + Vector3(0, 0.62 * E, 0), Vector3(0.7 * E, 0.06 * E, 0.7 * E), Color(0.2, 0.2, 0.22)])
			elif t < 0.6 and ny >= 8:
				# Une citerne sur ses pieds.
				liste.append([ou + Vector3(0, 0.3 * E, 0), Vector3(0.5 * E, 0.6 * E, 0.5 * E), Color(0.3, 0.3, 0.33)])
				liste.append([ou + Vector3(0, 1.1 * E, 0), Vector3(1.1 * E, 1.0 * E, 1.1 * E), Color(0.55, 0.42, 0.32)])
			elif t < 0.8:
				# La cage d'escalier, dans la teinte du mur.
				liste.append([ou + Vector3(0, 0.55 * E, 0), Vector3(1.4 * E, 1.1 * E, 1.1 * E), teinte.darkened(0.08)])
			else:
				# Une antenne : un mât fin, une traverse.
				liste.append([ou + Vector3(0, 0.9 * E, 0), Vector3(0.12 * E, 1.8 * E, 0.12 * E), Color(0.35, 0.35, 0.38)])
				liste.append([ou + Vector3(0, 1.6 * E, 0), Vector3(0.7 * E, 0.08 * E, 0.08 * E), Color(0.35, 0.35, 0.38)])
	if style in [PlanVille.F_VIEUX, PlanVille.F_MAISON, PlanVille.F_LOGEMENTS] and rng.randf() < 0.7:
		# La cheminée : au bord du toit, elle dépasse le faîte d'un toit en pente.
		var ou := Vector3(o.x + rng.randf_range(1.0, lx - 1.0), sommet, o.z + (1.0 if rng.randf() < 0.5 else lz - 1.0))
		var h_ch := 1.0 * E + (float(min(nx, nz) / 2) * V if pente else 0.0)
		liste.append([ou + Vector3(0, h_ch * 0.5, 0), Vector3(0.4 * E, h_ch, 0.4 * E), Color(0.5, 0.32, 0.26)])
		liste.append([ou + Vector3(0, h_ch + 0.1 * E, 0), Vector3(0.5 * E, 0.2 * E, 0.5 * E), Color(0.35, 0.3, 0.28)])
	return liste

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
			# Un fût qui s'affine, une embase, un bras coudé, une lanterne à
			# capot : tout en demi-cubes.
			var h := 4.8 if nom == "lampadaire" else 3.2
			var fut := Color(0.22, 0.24, 0.28)
			cubes.append([base + Vector3(0, 0.2, 0), 0.8, fut.darkened(0.2)])
			var n := int(h / 0.5)
			for k in n:
				cubes.append([base + Vector3(0, 0.25 + 0.5 * k, 0), 0.5 if k < n / 2 else 0.4, fut.lightened(0.03 * (k % 2))])
			# Le bras vers la rue (local -X), la lampe au bout.
			var portee := 1.15 if nom == "lampadaire" else 0.8
			for m in 3:
				cubes.append([base - avant * portee * (float(m) / 3.0) + Vector3(0, h - 0.4 + 0.15 * m, 0), 0.4, fut])
			cubes.append([base - avant * portee + Vector3(0, h + 0.05, 0), 0.9, fut.darkened(0.1)])      # le capot
			cubes.append([base - avant * portee + Vector3(0, h - 0.45, 0), 0.7, Color(1.0, 0.9, 0.7, LUMIERE)])
		"feu":
			for k in 7:
				cubes.append([base + Vector3(0, 0.25 + 0.5 * k, 0), 0.45, Color(0.2, 0.2, 0.22)])
			# Le boîtier : trois feux superposés, un seul allumé.
			var allume := rng.randi_range(0, 2)
			for f in 3:
				cubes.append([base + Vector3(0, 2.9 + 0.55 * f, 0), 0.7, Color(0.13, 0.13, 0.15)])
				var teinte_f: Color = [Color(1.0, 0.25, 0.2), Color(1.0, 0.7, 0.2), Color(0.2, 0.95, 0.35)][2 - f]
				cubes.append([base + avant * 0.3 + Vector3(0, 2.9 + 0.55 * f, 0), 0.4,
					Color(teinte_f, LUMIERE) if f == allume else teinte_f.darkened(0.6)])
			cubes.append([base + Vector3(0, 4.75, 0), 0.8, Color(0.13, 0.13, 0.15)])
		"borne":
			# Une borne d'incendie : le corps, le chapeau, deux bouches.
			var rouge := Color(0.85, 0.2, 0.15)
			for k in 3:
				cubes.append([base + Vector3(0, 0.25 + 0.5 * k, 0), 0.5, rouge.lightened(0.04 * k)])
			cubes.append([base + Vector3(0, 1.6, 0), 0.4, rouge.lightened(0.15)])
			cubes.append([base + cote * 0.35 + Vector3(0, 0.95, 0), 0.35, Color(0.7, 0.7, 0.72)])
			cubes.append([base - cote * 0.35 + Vector3(0, 0.95, 0), 0.35, Color(0.7, 0.7, 0.72)])
		"poubelle":
			# Un bac en demi-cubes, cerclé, avec son couvercle et un sac qui déborde.
			var tole := Color(0.3, 0.42, 0.32)
			for k in 3:
				for dx in 2:
					for dz in 2:
						cubes.append([base + Vector3((dx - 0.5) * 0.5, 0.25 + 0.5 * k, (dz - 0.5) * 0.5), 0.5,
							tole.darkened(0.15) if k == 1 else tole])
			cubes.append([base + Vector3(0, 1.6, 0), 1.05, tole.darkened(0.3)])
			if rng.randf() < 0.5:
				cubes.append([base + Vector3(0.2, 1.95, -0.1), 0.5, Color(0.15, 0.15, 0.17)])
		"banc":
			# Deux pieds en fonte, trois lattes d'assise, deux de dossier.
			var bois := Color(0.55, 0.38, 0.22)
			var fonte := Color(0.18, 0.18, 0.2)
			for m in [-1.0, 1.0]:
				cubes.append([base + cote * m * 0.9 + Vector3(0, 0.25, 0), 0.4, fonte])
				cubes.append([base + cote * m * 0.9 + avant * 0.4 + Vector3(0, 0.8, 0), 0.4, fonte])
			for latte in 3:
				for m in [-1.0, -0.5, 0.0, 0.5, 1.0]:
					cubes.append([base + cote * m * 0.5 + avant * (0.35 - 0.35 * latte) + Vector3(0, 0.6, 0), 0.4, bois.lightened(0.05 * latte)])
			for latte in 2:
				for m in [-1.0, -0.5, 0.0, 0.5, 1.0]:
					cubes.append([base + cote * m * 0.5 + avant * 0.45 + Vector3(0, 1.0 + 0.45 * latte, 0), 0.4, bois.lightened(0.08)])
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

## Les voitures sont en voxels FINS (un quart d'unité) et, surtout, MAILLÉES
## COMME LES IMMEUBLES : les faces voisines de même couleur se fondent, la
## carrosserie est un panneau lisse et non un quadrillage de petits cubes. Le
## relief vient de la forme — capot plus bas que le toit, pare-brise en
## escalier, passages de roue, rétroviseurs — et de la lumière sur chaque face,
## pas de traits dessinés. C'est ce qui sépare un jouet en voxels d'un tas de
## briques : on y voit une voiture avant d'y voir des cubes.
const VOXEL_VOITURE := 0.25

## Les gabarits : longueur, largeur, hauteur de caisse (en voxels), l'habitacle
## [début, fin) le long de la voiture (l'avant regarde +X), la hauteur de
## l'habitacle, et la forme. Une berline fait dix-neuf voxels de long, huit de
## large : quatre unités trois quarts, deux de large.
const GABARITS := {
	0: {"l": 19, "w": 8, "hc": 3, "cab": [6, 15], "ch": 3, "forme": "berline"},
	1: {"l": 19, "w": 8, "hc": 2, "cab": [7, 15], "ch": 2, "forme": "sport"},
	2: {"l": 15, "w": 8, "hc": 3, "cab": [4, 12], "ch": 3, "forme": "citadine"},
	3: {"l": 19, "w": 8, "hc": 4, "cab": [5, 16], "ch": 3, "forme": "haut"},        # 4×4
	4: {"l": 20, "w": 8, "hc": 3, "cab": [3, 18], "ch": 4, "forme": "haut"},        # monospace
	5: {"l": 19, "w": 8, "hc": 3, "cab": [6, 15], "ch": 3, "forme": "berline"},     # taxi
	6: {"l": 21, "w": 8, "hc": 4, "cab": [2, 20], "ch": 4, "forme": "fourgon"},
	7: {"l": 24, "w": 8, "hc": 4, "cab": [17, 22], "ch": 3, "forme": "camion"},     # livraison
	8: {"l": 25, "w": 8, "hc": 4, "cab": [18, 23], "ch": 3, "forme": "benne"},
	9: {"l": 19, "w": 8, "hc": 3, "cab": [6, 15], "ch": 3, "forme": "berline"},     # police
	10: {"l": 18, "w": 8, "hc": 2, "cab": [6, 13], "ch": 2, "forme": "sport"},      # coupé
	11: {"l": 20, "w": 8, "hc": 3, "cab": [6, 18], "ch": 3, "forme": "break"},
	12: {"l": 21, "w": 8, "hc": 3, "cab": [10, 16], "ch": 3, "forme": "pickup"},
	13: {"l": 34, "w": 9, "hc": 3, "cab": [1, 34], "ch": 5, "forme": "bus"},
	14: {"l": 27, "w": 8, "hc": 3, "cab": [8, 22], "ch": 3, "forme": "berline"},    # limousine
	15: {"l": 22, "w": 8, "hc": 4, "cab": [2, 21], "ch": 4, "forme": "fourgon"},    # ambulance
	16: {"l": 13, "w": 3, "hc": 3, "cab": [4, 9], "ch": 2, "forme": "moto"},        # moto de rue
	17: {"l": 14, "w": 3, "hc": 3, "cab": [3, 10], "ch": 2, "forme": "moto"},       # moto de course
}

## Le maillage d'une voiture, en couleurs de sommet. La caisse est BLANCHE :
## c'est la couleur d'instance (ou la matière) qui la peint ; roues, vitres,
## pare-chocs, feux gardent leur couleur quelle que soit la peinture.
static func voiture(indice: int) -> ArrayMesh:
	var g: Dictionary = GABARITS.get(indice, GABARITS[0])
	var L := int(g["l"])
	var W := int(g["w"])
	var HC := int(g["hc"])
	var CH := int(g["ch"])
	var cab0 := int(g["cab"][0])
	var cab1 := int(g["cab"][1])
	var forme := String(g["forme"])
	var v := VOXEL_VOITURE
	# La grille : une marge d'un voxel autour de la caisse (rétroviseurs), une
	# hauteur de caisse + habitacle + toit + accessoires.
	var marge := 1
	var nx := L + 2 * marge
	var nz := W + 2 * marge
	var ny := HC + CH + 4
	var grille := PackedInt64Array()
	grille.resize(nx * ny * nz)
	var teintes: Dictionary = {}
	var poser := func(x: int, y: int, z: int, c: Color) -> void:
		var gx := x + marge
		var gz := z + marge
		if gx < 0 or gz < 0 or y < 0 or gx >= nx or gz >= nz or y >= ny:
			return
		var cle := c.to_rgba32() | 1
		grille[(gx * ny + y) * nz + gz] = cle
		teintes[cle] = c
	var enlever := func(x: int, y: int, z: int) -> void:
		var gx := x + marge
		var gz := z + marge
		if gx < 0 or gz < 0 or y < 0 or gx >= nx or gz >= nz or y >= ny:
			return
		grille[(gx * ny + y) * nz + gz] = 0

	# Seule la CAISSE (alpha MUR) prend la peinture ; tout le reste est BRUT.
	var blanc := Color(1, 1, 1, BRUT)
	var caisse := Color(1, 1, 1, MUR)            # la tôle peinte
	var sombre := Color(0.13, 0.13, 0.15, BRUT)  # pare-chocs, bas de caisse, montants
	var vitre := Color(0.09, 0.12, 0.17, VITRE)
	var pneu := Color(0.05, 0.05, 0.06, BRUT)
	var jante := Color(0.82, 0.82, 0.84, BRUT)
	var phare := Color(1.0, 0.94, 0.72, ECLAIRE) # blanc chaud le jour, allumé la nuit
	var feu := Color(0.8, 0.08, 0.06, BRUT)
	var chrome := Color(0.72, 0.73, 0.76, BRUT)
	var utilitaire := forme in ["fourgon", "camion", "benne", "bus"]
	var caisse_h := HC + CH                      # le rang du toit

	# ---- la MOTO : pas de caisse, un cadre. Deux roues dans l'axe, un
	# réservoir, une selle, un guidon, un phare. Trois voxels de large : elle
	# se faufile, et on la reconnaît d'un coup d'œil de là-haut.
	if forme == "moto":
		var milieu := W / 2
		for x in range(3, L - 3):
			poser.call(x, 1, milieu, sombre)                       # le cadre
		for x in range(4, L - 5):
			for z in W:
				poser.call(x, 2, z, caisse)                        # le réservoir et la selle
		for x in range(L - 5, L - 3):
			poser.call(x, 3, milieu, caisse)                       # la bosse du réservoir
		# Le guidon, en travers.
		for z in W:
			poser.call(L - 4, 3, z, sombre)
		poser.call(L - 3, 3, milieu, phare)
		poser.call(1, 2, milieu, feu)
		# Les deux roues, dans l'axe, deux voxels de haut.
		for rx in [2, L - 3]:
			for dx in [-1, 0, 1]:
				for y in 2:
					poser.call(rx + dx, y, milieu, pneu)
			poser.call(rx, 1, milieu, jante)
		var origine_m := Vector3(-float(L) * 0.5 * v - marge * v, 0.16, -float(W) * 0.5 * v - marge * v)
		return mailler_grille(nx, ny, nz, grille, teintes, origine_m, v)

	# ---- la caisse : une boîte, puis on sculpte.
	for x in L:
		for z in W:
			for y in HC:
				poser.call(x, y, z, caisse)
	if not utilitaire:
		# Le capot plonge d'un rang sur les deux derniers voxels, le coffre sur
		# le dernier ; une sportive plonge sur quatre.
		var plongee := 4 if forme == "sport" else 2
		for z in W:
			for dx in plongee:
				enlever.call(L - 1 - dx, HC - 1, z)
			enlever.call(0, HC - 1, z)
	# Le bas de caisse sombre aux deux bouts : les pare-chocs.
	for z in W:
		poser.call(0, 0, z, sombre)
		poser.call(L - 1, 0, z, sombre)
	if forme == "bus":
		for x in L:
			for z in W:
				poser.call(x, 0, z, sombre)

	# ---- les roues : dans la largeur de la caisse, trois voxels de long, deux
	# de haut, la jante claire au milieu. Les longues en ont trois paires.
	var roues := [2, L - 4]
	if L >= 26:
		roues = [2, L / 2, L - 4]
	if forme in ["camion", "benne"]:
		roues = [3, 7, L - 4]
	for rx in roues:
		for z in [0, W - 1]:
			for dx in [-1, 0, 1]:
				for y in 2:
					poser.call(rx + dx, y, z, pneu)
			poser.call(rx, 0, z, jante)
			poser.call(rx, 1, z, jante)
			# Le passage de roue : la tôle au-dessus de la roue est en retrait
			# (le voxel du dessus, à la verticale de la roue, disparaît).
			if HC >= 3 and not utilitaire:
				enlever.call(rx - 1, 2, z)
				enlever.call(rx + 1, 2, z)
				poser.call(rx, 2, z, caisse)

	# ---- l'avant : calandre sombre, phares aux angles ; l'arrière : feux.
	var y_feux := 1
	for z in W:
		if z <= 1 or z >= W - 2:
			poser.call(L - 1, y_feux, z, phare)
			poser.call(0, y_feux, z, feu)
		else:
			poser.call(L - 1, y_feux, z, sombre if forme != "bus" else vitre)
	if not utilitaire:
		# Une baguette de chrome sur les flancs des berlines et limousines.
		if forme == "berline":
			for x in range(2, L - 2):
				poser.call(x, 1, 0, chrome)
				poser.call(x, 1, W - 1, chrome)

	# ---- l'habitacle : en retrait d'un voxel sur les flancs (pleine largeur
	# pour les utilitaires), le pare-brise et la lunette en escalier — un rang
	# de moins à l'avant par rang de hauteur, la lunette plus douce — et les
	# vitres sur toute la peau, les montants aux angles et à la portière.
	var z0 := 0 if utilitaire else 1
	var z1 := W - 1 if utilitaire else W - 2
	var pente_avant := 1.0 if not utilitaire else 0.34
	var pente_arriere := 0.5 if forme in ["berline", "sport", "citadine"] else 0.0
	if forme == "break" or forme == "haut":
		pente_arriere = 0.0
	var portiere := cab0 + (cab1 - cab0) / 2
	var xmins: Array = []
	var xmaxs: Array = []
	for r in CH + 1:
		var xmin := cab0 + int(floor(float(r) * pente_arriere + 0.001))
		var xmax := cab1 - int(floor(float(r) * pente_avant + 0.001))
		if forme in ["camion", "benne"]:
			xmin = cab0
		xmins.append(xmin)
		xmaxs.append(xmax)
	for r in CH:
		var y := HC + r
		var xmin: int = xmins[r]
		var xmax: int = xmaxs[r]
		for x in range(xmin, xmax):
			for z in range(z0, z1 + 1):
				var bord_x := x == xmin or x == xmax - 1
				var bord_z := z == z0 or z == z1
				var c := caisse
				if bord_x or bord_z:
					c = vitre
					# Les montants : les angles, la portière, et pour un bus ou un
					# fourgon un montant tous les quatre voxels.
					var montant := (bord_x and bord_z) or (bord_z and x == portiere)
					if utilitaire and bord_z and posmod(x - cab0, 4) == 0:
						montant = true
					if montant:
						c = caisse
					# Un utilitaire : la tôle sous les vitres, le pare-brise seul à l'avant.
					if utilitaire and r == 0:
						c = caisse if not (bord_x and x == xmax - 1) else vitre
					if utilitaire and r == CH - 1 and bord_z:
						c = caisse
					# La caisse d'un camion n'a pas de vitre.
					if forme in ["camion", "benne"] and x < cab0 + 0:
						c = caisse
				poser.call(x, y, z, c)
	# Le toit.
	for x in range(xmins[CH], xmaxs[CH]):
		for z in range(z0, z1 + 1):
			poser.call(x, caisse_h, z, caisse)
	# Les rétroviseurs, au pied du pare-brise.
	var x_retro: int = xmaxs[0] - 1
	poser.call(x_retro, HC, z0 - 1, caisse)
	poser.call(x_retro, HC, z1 + 1, caisse)

	# ---- par forme.
	match forme:
		"sport":
			# Un aileron sur le coffre.
			for z in range(1, W - 1):
				poser.call(0, HC, z, sombre)
			poser.call(0, HC - 1, 0, sombre)
			poser.call(0, HC - 1, W - 1, sombre)
		"break", "haut":
			# Les barres de toit.
			for x in range(xmins[CH] + 1, xmaxs[CH] - 1):
				poser.call(x, caisse_h + 1, z0, sombre)
				poser.call(x, caisse_h + 1, z1, sombre)
		"pickup":
			# La benne ouverte derrière la cabine : on creuse le rang du haut,
			# ridelles et hayon restent.
			for x in range(1, cab0 - 1):
				for z in range(1, W - 1):
					enlever.call(x, HC - 1, z)
					poser.call(x, HC - 2, z, sombre)
		"camion", "benne":
			# La caisse arrière : pleine largeur, plus haute que la cabine.
			var couleur_caisse := Color(0.94, 0.94, 0.92, BRUT) if forme == "camion" else Color(0.25, 0.26, 0.28, BRUT)
			for x in range(1, cab0 - 1):
				for z in W:
					for y in range(HC, caisse_h + 2):
						if forme == "benne" and y == caisse_h + 1 and z > 0 and z < W - 1 and x > 1 and x < cab0 - 2:
							continue           # la benne est ouverte
						poser.call(x, y, z, couleur_caisse)
			if forme == "camion":
				# Le trait des portes arrière.
				for y in range(HC, caisse_h + 2):
					poser.call(1, y, W / 2, sombre)
		"bus":
			# Le panneau de destination au-dessus du pare-brise, une porte
			# vitrée à l'avant droit.
			for z in range(2, W - 2):
				poser.call(L - 1, HC + CH - 1, z, Color(1.0, 0.75, 0.3, LUMIERE))
			for y in range(1, HC + CH - 1):
				poser.call(L - 6, y, 0, vitre)
				poser.call(L - 7, y, 0, vitre)
	match indice:
		5:
			# Le taxi : l'enseigne sur le toit et le damier sur les flancs.
			poser.call(portiere, caisse_h + 1, W / 2 - 1, Color(1.0, 0.85, 0.3, LUMIERE))
			poser.call(portiere, caisse_h + 1, W / 2, Color(1.0, 0.85, 0.3, LUMIERE))
			for x in range(2, L - 2):
				poser.call(x, 1, 0, sombre if posmod(x, 2) == 0 else blanc)
				poser.call(x, 1, W - 1, sombre if posmod(x, 2) == 0 else blanc)
		9:
			# La police : la bande bleue et les mots sur le capot ; la rampe est
			# un nœud à part (elle clignote).
			for x in range(2, L - 2):
				poser.call(x, 1, 0, Color(0.15, 0.32, 0.85, BRUT))
				poser.call(x, 1, W - 1, Color(0.15, 0.32, 0.85, BRUT))
			for z in range(2, W - 2):
				poser.call(L - 4, HC - 1, z, Color(0.15, 0.32, 0.85, BRUT))
		15:
			# L'ambulance : la bande rouge, la croix sur le toit, le gyrophare.
			for x in range(1, L - 1):
				poser.call(x, 2, 0, Color(0.85, 0.12, 0.12, BRUT))
				poser.call(x, 2, W - 1, Color(0.85, 0.12, 0.12, BRUT))
			var cx := (cab0 + cab1) / 2
			for d in range(-2, 3):
				poser.call(cx + d, caisse_h + 1, W / 2, Color(0.85, 0.12, 0.12, BRUT))
				poser.call(cx, caisse_h + 1, W / 2 + d, Color(0.85, 0.12, 0.12, BRUT))
			poser.call(cab1 - 2, caisse_h + 1, W / 2 - 1, Color(0.3, 0.5, 1.0, LUMIERE))
			poser.call(cab1 - 2, caisse_h + 1, W / 2, Color(0.3, 0.5, 1.0, LUMIERE))
		7:
			pass

	var origine := Vector3(-float(L) * 0.5 * v - marge * v, 0.16, -float(W) * 0.5 * v - marge * v)
	return mailler_grille(nx, ny, nz, grille, teintes, origine, v)

## Le mailleur GLOUTON d'une grille dense de couleurs (0 = vide) : pour chaque
## direction, les faces exposées d'une tranche se fondent en rectangles de même
## couleur. Les UV sont constants (le shader n'y dessine alors aucune arête) :
## c'est ce qui fait la peau lisse. Indice : `(x * ny + y) * nz + z`.
static func mailler_grille(nx: int, ny: int, nz: int, grille: PackedInt64Array, teintes: Dictionary,
		origine: Vector3, v: float) -> ArrayMesh:
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	var couleurs := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var tableaux := [sommets, normales, couleurs, uvs, indices]
	var dims := [nx, ny, nz]
	for axe in 3:
		var u := (axe + 1) % 3
		var w := (axe + 2) % 3
		var du: int = dims[u]
		var dw: int = dims[w]
		var da: int = dims[axe]
		var masque := PackedInt64Array()
		masque.resize(du * dw)
		for sens in [-1, 1]:
			for d in da:
				var vide := true
				for b in dw:
					for a in du:
						var p := [0, 0, 0]
						p[axe] = d
						p[u] = a
						p[w] = b
						var cle: int = grille[(p[0] * ny + p[1]) * nz + p[2]]
						if cle != 0:
							var q := p.duplicate()
							q[axe] = d + sens
							var voisin_plein: bool = q[axe] >= 0 and q[axe] < da and grille[(q[0] * ny + q[1]) * nz + q[2]] != 0
							if voisin_plein:
								cle = 0
						masque[b * du + a] = cle
						if cle != 0:
							vide = false
				if vide:
					continue
				var normale := Vector3.ZERO
				normale[axe] = float(sens)
				for b in dw:
					var a := 0
					while a < du:
						var c: int = masque[b * du + a]
						if c == 0:
							a += 1
							continue
						var larg := 1
						while a + larg < du and masque[b * du + a + larg] == c:
							larg += 1
						var haut := 1
						var ok := true
						while b + haut < dw and ok:
							for x in larg:
								if masque[(b + haut) * du + a + x] != c:
									ok = false
									break
							if ok:
								haut += 1
						for y in haut:
							for x in larg:
								masque[(b + y) * du + a + x] = 0
						var coin := [0.0, 0.0, 0.0]
						coin[axe] = float(d + (1 if sens > 0 else 0))
						coin[u] = float(a)
						coin[w] = float(b)
						var pa := Vector3.ZERO
						pa[u] = float(larg)
						var pb := Vector3.ZERO
						pb[w] = float(haut)
						_quad_lisse(tableaux, origine + Vector3(coin[0], coin[1], coin[2]) * v, pa * v, pb * v, normale, teintes[c])
						a += larg
	return maillage_depuis(sommets, normales, couleurs, uvs, indices)

## Un rectangle à UV constants : aucune arête dessinée par le shader.
static func _quad_lisse(tableaux: Array, p: Vector3, a: Vector3, b: Vector3, normale: Vector3, c: Color) -> void:
	var sommets: PackedVector3Array = tableaux[0]
	var normales: PackedVector3Array = tableaux[1]
	var couleurs: PackedColorArray = tableaux[2]
	var uvs: PackedVector2Array = tableaux[3]
	var indices: PackedInt32Array = tableaux[4]
	var n0 := sommets.size()
	var direct := a.cross(b).dot(normale) > 0.0
	for s in [p, p + a, p + a + b, p + b]:
		sommets.append(s)
		normales.append(normale)
		couleurs.append(c)
		uvs.append(Vector2(0.5, 0.5))
	if direct:
		indices.append_array(PackedInt32Array([n0, n0 + 2, n0 + 1, n0, n0 + 3, n0 + 2]))
	else:
		indices.append_array(PackedInt32Array([n0, n0 + 1, n0 + 2, n0, n0 + 2, n0 + 3]))

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
		13: return Color("#e6dcb0") if graine % 2 == 0 else Color("#3f7a5a")
		14: return Color("#141418") if graine % 3 != 0 else Color("#f0f0f2")
		15: return Color("#f4f4f2")
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
