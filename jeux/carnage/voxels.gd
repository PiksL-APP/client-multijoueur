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
	var toit := teinte.lerp(Color(0.25, 0.25, 0.27), 0.6)
	var interieur := Color(0.42, 0.40, 0.38)
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var part := _part_allumee(style)
	for i in nx:
		for j in nz:
			for k in ny:
				var facade := i == 0 or i == nx - 1 or j == 0 or j == nz - 1
				var couleur := teinte
				if not facade:
					couleur = interieur
				elif k == ny - 1 and not plat:
					couleur = toit
				elif plat:
					couleur = teinte
				else:
					couleur = _facade(style, teinte, i, j, k, nx, nz, ny, part, rng)
				couleurs[(i * nz + j) * ny + k] = couleur
	return {"nx": nx, "nz": nz, "ny": ny, "origine": origine, "taille": V,
		"hauteur": float(g["hauteur"]), "solide": solide, "couleurs": couleurs, "style": style,
		"teinte": teinte, "plat": plat}

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
			var grand := nom == "arbre"
			var tronc := Color(0.4, 0.28, 0.16)
			var feuille := Color(0.18, 0.45, 0.16).lightened(rng.randf_range(-0.05, 0.1))
			var ht := 3 if grand else 2
			for k in ht:
				cubes.append([base + Vector3(0, (0.35 + 0.7 * k) * s, 0), 0.7 * s, tronc])
			var y0 := (0.7 * ht + 0.5) * s
			if grand:
				# Une couronne de trois sur trois sur deux, sans les angles du haut,
				# et un cube au sommet : une boule de feuilles, pas une boîte.
				for x in range(-1, 2):
					for z in range(-1, 2):
						for y in 2:
							if y == 1 and abs(x) == 1 and abs(z) == 1:
								continue
							cubes.append([base + Vector3(x * s, y0 + y * s, z * s), 1.0 * s,
								feuille.lightened(0.12 * y + rng.randf_range(-0.04, 0.04))])
				cubes.append([base + Vector3(0, y0 + 2.0 * s, 0), 1.0 * s, feuille.lightened(0.25)])
			else:
				for x in [-0.5, 0.5]:
					for z in [-0.5, 0.5]:
						for y in 2:
							cubes.append([base + Vector3(x * s, y0 + y * s, z * s), 1.0 * s,
								feuille.lightened(0.12 * y + rng.randf_range(-0.04, 0.04))])
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

const VOXEL_VOITURE := 0.5

## Les gabarits : longueur, largeur, hauteur de caisse (en voxels), et où va
## l'habitacle (début, fin, hauteur). Le kit de Kenney a servi de mesure : une
## berline fait neuf voxels de long, quatre de large.
const GABARITS := {
	0: {"l": 9, "w": 4, "hc": 2, "cab": [2, 7, 1]},      # berline
	1: {"l": 9, "w": 4, "hc": 2, "cab": [3, 7, 1]},      # berline sport
	2: {"l": 8, "w": 4, "hc": 2, "cab": [2, 6, 1]},      # compacte
	3: {"l": 9, "w": 4, "hc": 3, "cab": [2, 8, 1]},      # 4x4
	4: {"l": 10, "w": 4, "hc": 3, "cab": [2, 9, 1]},     # 4x4 de luxe
	5: {"l": 9, "w": 4, "hc": 2, "cab": [2, 7, 1]},      # taxi
	6: {"l": 10, "w": 4, "hc": 3, "cab": [1, 10, 1]},    # fourgon
	7: {"l": 11, "w": 4, "hc": 3, "cab": [3, 11, 1]},    # camion de livraison
	8: {"l": 12, "w": 4, "hc": 3, "cab": [4, 12, 1]},    # camion
	9: {"l": 9, "w": 4, "hc": 2, "cab": [2, 7, 1]},      # police
}

## Le maillage voxel d'une voiture, en couleurs de sommet. La caisse est
## BLANCHE : c'est la couleur d'instance (ou la matière) qui la peint, roues et
## vitres restent sombres quelle que soit la peinture. L'avant regarde +X.
static func voiture(indice: int) -> ArrayMesh:
	var g: Dictionary = GABARITS.get(indice, GABARITS[0])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var L := int(g["l"])
	var W := int(g["w"])
	var HC := int(g["hc"])
	var cab: Array = g["cab"]
	var v := VOXEL_VOITURE
	var blanc := Color(1, 1, 1, MUR)
	var vitre := Color(0.12, 0.15, 0.2, VITRE)
	var noir := Color(0.05, 0.05, 0.06, MUR)
	var x0 := -float(L) * 0.5 * v
	var z0 := -float(W) * 0.5 * v
	# La caisse.
	for x in L:
		for z in W:
			for y in HC:
				var c := blanc
				if indice == 9 and y == HC - 1 and (x == 3 or x == 4 or x == 5):
					c = Color(0.2, 0.35, 0.85, MUR)            # la bande de la police
				if indice == 7 and x >= int(cab[0]) and y >= 1:
					c = Color(0.92, 0.92, 0.9, MUR)             # la caisse de livraison
				_cube(st, Vector3(x0 + (x + 0.5) * v, 0.5 * v + y * v + 0.45, z0 + (z + 0.5) * v), v, c)
	# L'habitacle : une rangée de plus, en verre sur les côtés, en tôle au milieu.
	var y_cab := HC
	for x in range(int(cab[0]), int(cab[1])):
		for z in W:
			var bord := z == 0 or z == W - 1 or x == int(cab[0]) or x == int(cab[1]) - 1
			var c := vitre if bord else blanc
			if indice == 7 or indice == 8:
				if x >= int(cab[0]) + 1:
					c = Color(0.92, 0.92, 0.9, MUR) if indice == 7 else Color(0.85, 0.35, 0.25, MUR)
			_cube(st, Vector3(x0 + (x + 0.5) * v, 0.5 * v + y_cab * v + 0.45, z0 + (z + 0.5) * v), v, c)
	# Le toit sur l'habitacle.
	if indice != 7 and indice != 8:
		for x in range(int(cab[0]) + 1, int(cab[1]) - 1):
			for z in range(1, W - 1):
				_cube(st, Vector3(x0 + (x + 0.5) * v, 0.5 * v + (y_cab + 1) * v + 0.45, z0 + (z + 0.5) * v), v, blanc)
	# Quatre roues, qui dépassent sous la caisse.
	for x in [1, L - 2]:
		for z in [-0.35, W - 0.65]:
			_cube(st, Vector3(x0 + (x + 0.5) * v, 0.45, z0 + (z + 0.5) * v), v * 1.1, noir)
			_cube(st, Vector3(x0 + (x + 0.5) * v, 0.45, z0 + (z + 0.5) * v + (0.3 if z < 0.0 else -0.3)), v * 0.6, Color(0.6, 0.6, 0.62, MUR))
	# Phares et feux : des cubes lumineux aux quatre coins.
	for z in [0, W - 1]:
		_cube(st, Vector3(x0 + L * v + 0.05, 0.5 * v + 0.45, z0 + (z + 0.5) * v), v * 0.6, Color(1.0, 0.95, 0.75, LUMIERE))
		_cube(st, Vector3(x0 - 0.05, 0.5 * v + 0.45, z0 + (z + 0.5) * v), v * 0.6, Color(1.0, 0.2, 0.15, LUMIERE))
	if indice == 5:
		_cube(st, Vector3(x0 + (int(cab[0]) + 1.5) * v, 0.5 * v + (y_cab + 2) * v + 0.4, 0.0), v * 1.2, Color(1.0, 0.85, 0.3, LUMIERE))
	if indice == 9:
		_cube(st, Vector3(x0 + (int(cab[0]) + 1.5) * v, 0.5 * v + (y_cab + 2) * v + 0.35, -0.45), v * 0.8, Color(0.3, 0.5, 1.0, LUMIERE))
		_cube(st, Vector3(x0 + (int(cab[0]) + 1.5) * v, 0.5 * v + (y_cab + 2) * v + 0.35, 0.45), v * 0.8, Color(1.0, 0.25, 0.25, LUMIERE))
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

const VOXEL_PERSONNAGE := 0.42

## Un personnage en cubes : jambes articulées (nœuds « JambeG » et « JambeD »
## pivotés à la hanche), torse de la couleur donnée, tête couleur peau. Il
## regarde +X. Sa hauteur : environ trois unités et demie.
static func personnage(couleur: Color, peau: Color = Color(0.9, 0.72, 0.6), cheveux: Color = Color(0.25, 0.18, 0.12)) -> Node3D:
	var racine := Node3D.new()
	var v := VOXEL_PERSONNAGE
	var jambes := Color(0.2, 0.22, 0.3, MUR)
	for cote in [-1.0, 1.0]:
		var jambe := MeshInstance3D.new()
		jambe.name = "JambeG" if cote < 0.0 else "JambeD"
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Pivot à la hanche : les cubes descendent de zéro vers le bas.
		for k in 3:
			_cube(st, Vector3(0, -0.5 * v - k * v, 0), v, jambes if k < 2 else Color(0.12, 0.1, 0.1, MUR))
		jambe.mesh = st.commit()
		jambe.material_override = matiere_voxel()
		jambe.position = Vector3(0, 3.0 * v, cote * 0.5 * v)
		racine.add_child(jambe)
	var corps := MeshInstance3D.new()
	corps.name = "Corps"
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	var teinte := Color(couleur, MUR)
	for k in 3:
		for z in [-0.5, 0.5]:
			_cube(st2, Vector3(0, 3.0 * v + 0.5 * v + k * v, z * v), v, teinte if k < 2 else teinte.darkened(0.1))
	# Les bras, un peu en retrait.
	for z in [-1.5, 1.5]:
		for k in 3:
			_cube(st2, Vector3(0, 3.0 * v + 0.5 * v + k * v, z * v), v * 0.8, teinte.darkened(0.15) if k > 0 else Color(peau, MUR))
	# La tête et les cheveux.
	var y_tete := 6.0 * v + 0.6 * v
	_cube(st2, Vector3(0, y_tete, 0), v * 1.6, Color(peau, MUR))
	_cube(st2, Vector3(-0.1 * v, y_tete + 0.7 * v, 0), v * 1.5, Color(cheveux, MUR))
	# Les yeux : deux points sombres à l'avant, pour dire où il regarde.
	for z in [-0.35, 0.35]:
		_cube(st2, Vector3(0.75 * v, y_tete + 0.15 * v, z * v), v * 0.3, Color(0.08, 0.08, 0.1, MUR))
	corps.mesh = st2.commit()
	corps.material_override = matiere_voxel()
	racine.add_child(corps)
	return racine

## Balance les jambes d'un personnage qui marche ; les remet droites sinon.
static func animer(personnage_noeud: Node3D, marche: bool, temps: float, vitesse: float = 9.0) -> void:
	var g := personnage_noeud.get_node_or_null("JambeG") as Node3D
	var d := personnage_noeud.get_node_or_null("JambeD") as Node3D
	if g == null or d == null:
		return
	var angle := sin(temps * vitesse) * 0.7 if marche else 0.0
	g.rotation.z = angle
	d.rotation.z = -angle

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
