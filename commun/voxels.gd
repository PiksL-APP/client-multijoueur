class_name Voxels
extends RefCounted
## Fabrique de maillages en VOXELS : un dictionnaire `Vector3i -> couleur`
## devient un seul maillage, faces cachées retirées, occlusion ambiante cuite
## dans la couleur des sommets.
##
## Pourquoi cuire l'occlusion : en mode compatibilité il n'y a ni SSAO ni
## illumination globale, et sans elle un monde de cubes est un aplat où
## l'on ne distingue plus un creux d'une bosse. Trois cases de voisinage par
## sommet suffisent à donner du creux aux angles — c'est l'ombre « Minecraft ».
##
## La couleur d'un bloc est soit une `Color`, soit `[dessus, côtés]` : c'est
## ce qui fait qu'un bloc de sol est vert sur le dessus et terre sur les
## flancs sans doubler le nombre de blocs.

## Les six faces : normale, puis les quatre sommets en tour direct vu de
## l'extérieur, en coordonnées du cube unité.
const FACES := [
	[Vector3i(0, 1, 0), [Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)]],
	[Vector3i(0, -1, 0), [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]],
	[Vector3i(1, 0, 0), [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)]],
	[Vector3i(-1, 0, 0), [Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0)]],
	[Vector3i(0, 0, 1), [Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)]],
	[Vector3i(0, 0, -1), [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)]],
]
## Ombrage par direction, en plus de la lumière réelle : le dessus est franc,
## les flancs un peu retenus, le dessous sombre. Sans ça, deux faces
## adjacentes de même couleur se fondent l'une dans l'autre dès que le soleil
## est haut.
const OMBRE_FACE := [1.0, 0.55, 0.84, 0.80, 0.88, 0.76]

static var _matiere: StandardMaterial3D = null
static var _matiere_double: StandardMaterial3D = null

## Le maillage d'un nuage de blocs. `echelle` est la taille d'un bloc ;
## `sans_dessous` saute les faces tournées vers le bas (un sol vu de haut n'en
## montre jamais) ; `ancre` est retranché aux positions, pour poser un modèle
## sur ses pieds.
static func maillage(blocs: Dictionary, echelle: float = 1.0, sans_dessous: bool = false,
		ancre: Vector3 = Vector3.ZERO, occlusion: bool = true) -> ArrayMesh:
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := 0
	for position in blocs:
		var p: Vector3i = position
		var valeur = blocs[p]
		var dessus: Color = valeur[0] if valeur is Array else valeur
		var cotes: Color = valeur[1] if valeur is Array else valeur
		for indice in 6:
			if sans_dessous and indice == 1:
				continue
			var face: Array = FACES[indice]
			var normale: Vector3i = face[0]
			if blocs.has(p + normale):
				continue
			var teinte := (dessus if indice == 0 else cotes) * float(OMBRE_FACE[indice])
			teinte.a = 1.0
			var sommets: Array = face[1]
			var n := Vector3(normale)
			var origine := (Vector3(p) - ancre) * echelle
			var couleurs: Array[Color] = []
			for s in 4:
				var coin: Vector3 = sommets[s]
				var facteur := 1.0
				if occlusion:
					facteur = _occlusion(blocs, p, normale, coin)
				var c := teinte * facteur
				c.a = 1.0
				# Converti en linéaire ICI : le moteur en mode compatibilité lit
				# la couleur des sommets telle quelle, et la palette (en sRGB)
				# ressortait pastel et délavée, vu à l'image.
				couleurs.append(c.srgb_to_linear())
			# Deux triangles ; la diagonale suit l'occlusion pour éviter la
			# marche d'escalier visible sur les angles très occlus.
			# (Sommets listés en tour direct vu de dehors : Godot cache les faces
			# arrière, donc dans l'autre sens on ne verrait que l'intérieur.)
			var ordre := [0, 2, 1, 0, 3, 2]
			if couleurs[0].get_luminance() + couleurs[2].get_luminance() > couleurs[1].get_luminance() + couleurs[3].get_luminance():
				ordre = [1, 3, 2, 1, 0, 3]
			for i in ordre:
				outil.set_normal(n)
				outil.set_color(couleurs[i])
				outil.add_vertex(origine + (sommets[i] as Vector3) * echelle)
			faces += 1
	if faces == 0:
		return null
	return outil.commit()

## L'occlusion d'un sommet : combien des trois blocs qui l'entourent, dans
## le plan de la face, sont pleins.
static func _occlusion(blocs: Dictionary, p: Vector3i, normale: Vector3i, coin: Vector3) -> float:
	# Le sommet est à 0 ou 1 sur chaque axe : le décalage vers le voisin est
	# -1 (à 0) ou +1 (à 1), sauf le long de la normale.
	var d := Vector3i(-1 if coin.x < 0.5 else 1, -1 if coin.y < 0.5 else 1, -1 if coin.z < 0.5 else 1)
	var a := Vector3i.ZERO
	var b := Vector3i.ZERO
	if normale.x != 0:
		a = Vector3i(0, d.y, 0)
		b = Vector3i(0, 0, d.z)
	elif normale.y != 0:
		a = Vector3i(d.x, 0, 0)
		b = Vector3i(0, 0, d.z)
	else:
		a = Vector3i(d.x, 0, 0)
		b = Vector3i(0, d.y, 0)
	var base := p + normale
	var pleins := 0
	if blocs.has(base + a):
		pleins += 1
	if blocs.has(base + b):
		pleins += 1
	# Doux : à 0,55 dans les angles, un feuillage grignoté devenait un bloc
	# noir vu de dessus.
	if pleins == 2:
		return 0.70
	if blocs.has(base + a + b):
		pleins += 1
	return 1.0 - 0.10 * pleins

static func matiere() -> StandardMaterial3D:
	if _matiere == null:
		_matiere = StandardMaterial3D.new()
		_matiere.vertex_color_use_as_albedo = true
		_matiere.roughness = 1.0
		_matiere.metallic = 0.0
	return _matiere

static func instance(blocs: Dictionary, echelle: float = 1.0, ombre: bool = true,
		sans_dessous: bool = false, ancre: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var noeud := MeshInstance3D.new()
	noeud.mesh = maillage(blocs, echelle, sans_dessous, ancre)
	noeud.material_override = matiere()
	noeud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ombre \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return noeud

# ------------------------------------------------------------ outils de dessin

## Remplit une boîte de blocs.
static func boite(blocs: Dictionary, depuis: Vector3i, taille: Vector3i, couleur) -> void:
	for x in range(depuis.x, depuis.x + taille.x):
		for y in range(depuis.y, depuis.y + taille.y):
			for z in range(depuis.z, depuis.z + taille.z):
				blocs[Vector3i(x, y, z)] = couleur

## Une boule approximative, pour les feuillages.
static func boule(blocs: Dictionary, centre: Vector3i, rayon: float, couleur, aplati: float = 1.0) -> void:
	var r := int(ceil(rayon))
	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			for z in range(-r, r + 1):
				var d := sqrt(float(x * x) + float(y * y) * aplati + float(z * z))
				if d <= rayon + 0.01:
					blocs[centre + Vector3i(x, y, z)] = couleur

## Décale et fusionne un modèle dans un nuage plus grand.
static func fondre(dans: Dictionary, modele: Dictionary, decalage: Vector3i) -> void:
	for p in modele:
		dans[(p as Vector3i) + decalage] = modele[p]

## Un hasard stable tiré d'une graine entière.
static func de(graine: int, sel: int) -> float:
	return float(hash(Vector2i(graine, sel)) % 10007) / 10007.0

## Une couleur légèrement variée, pour casser les aplats.
static func varier(couleur: Color, graine: int, sel: int, amplitude: float = 0.05) -> Color:
	var f := 1.0 + (de(graine, sel) - 0.5) * 2.0 * amplitude
	return Color(couleur.r * f, couleur.g * f, couleur.b * f, 1.0)

# ------------------------------------------------------------ la palette

## Les couleurs viennent de Serene Village (LimeZu), relevées sur la planche :
## c'est ce qui garde, en volume, la douceur du pixel art choisi par le client.
const HERBE_A := Color8(118, 197, 100)
const HERBE_B := Color8(123, 203, 105)
const TERRE := Color8(186, 140, 82)
const TERRE_SOMBRE := Color8(168, 118, 62)
const LABOUR := Color8(170, 118, 68)
const LABOUR_MOUILLE := Color8(112, 76, 48)
const SABLE := Color8(214, 190, 138)
const EAU := Color8(80, 167, 232)
const EAU_PROFONDE := Color8(56, 128, 204)
const TRONC := Color8(150, 95, 60)
const TRONC_SOMBRE := Color8(112, 70, 44)
const FEUILLAGES := [
	[Color8(112, 190, 90), Color8(84, 160, 84)],
	[Color8(96, 172, 112), Color8(70, 140, 100)],
	[Color8(156, 196, 78), Color8(118, 168, 66)],
	[Color8(84, 150, 104), Color8(62, 122, 90)],
]
const ROCHE := Color8(150, 140, 130)
const ROCHE_SOMBRE := Color8(110, 102, 96)
const FLEURS := [Color8(230, 80, 80), Color8(90, 150, 230), Color8(250, 200, 60), Color8(245, 245, 245), Color8(220, 120, 200)]
const MUR := Color8(222, 184, 135)
const MUR_SOMBRE := Color8(190, 150, 105)
const TOIT := Color8(206, 62, 58)
const TOIT_CLAIR := Color8(228, 84, 72)
const CADRE := Color8(58, 58, 80)
const PORTE := Color8(122, 74, 40)
const VITRE := Color8(140, 200, 236)
const BOIS := Color8(196, 150, 96)
const BOIS_SOMBRE := Color8(140, 100, 60)
const PEAU := Color8(238, 196, 160)
const CHEVEUX := Color8(96, 60, 36)

# ------------------------------------------------------------ modèles
#
# RÉSOLUTION : chaque objet est fait de BEAUCOUP de petits voxels, pas de
# quelques gros cubes — demande du client (« plus de voxels par objet »). Les
# échelles sont fixées ici et les modèles sont dessinés dans leur grille :
#   E_ARBRE  1/4  — arbres, rochers, buissons (4 voxels par case)
#   E_MAISON 1/4  — la maison
#   E_FIN    1/8  — clôture, fleurs, touffes, nénuphars, petit mobilier
#   E_PERSO  1/16 — héros, plants (16 voxels par case)
# Un arbre fait ainsi deux à trois mille voxels au lieu de soixante : son
# maillage est fabriqué UNE fois par variante et instancié (MultiMesh), pas
# fondu dans le sol comme avant.

const E_ARBRE := 0.25
const E_MAISON := 0.25
const E_FIN := 0.125
const E_PERSO := 0.0625

static var _cache: Dictionary = {}

## Un maillage mis en cache sous une clé : `fabrique` n'est appelée qu'une fois.
static func en_cache(cle: String, fabrique: Callable, echelle: float, sans_dessous: bool = false,
		ancre: Vector3 = Vector3.ZERO) -> ArrayMesh:
	if not _cache.has(cle):
		_cache[cle] = maillage(fabrique.call(), echelle, sans_dessous, ancre)
	return _cache[cle]

## Une boule dont la surface est grignotée au hasard : c'est ce qui fait
## d'une sphère de cubes un feuillage ou un caillou plutôt qu'un ballon.
static func boule_rugueuse(blocs: Dictionary, centre: Vector3i, rayon: Vector3, couleur, graine: int, sel: int, rugosite: float = 0.35) -> void:
	var r := Vector3i(int(ceil(rayon.x)), int(ceil(rayon.y)), int(ceil(rayon.z)))
	for x in range(-r.x, r.x + 1):
		for y in range(-r.y, r.y + 1):
			for z in range(-r.z, r.z + 1):
				var d := sqrt(pow(x / rayon.x, 2.0) + pow(y / rayon.y, 2.0) + pow(z / rayon.z, 2.0))
				if d > 1.0:
					continue
				if d > 0.82 and de(graine, sel + x * 131 + y * 17 + z * 1009) < rugosite:
					continue
				blocs[centre + Vector3i(x, y, z)] = couleur

## Un cylindre vertical d'axe (x, z), rayon en voxels.
static func cylindre(blocs: Dictionary, base: Vector3i, rayon: float, hauteur: int, couleur) -> void:
	var r := int(ceil(rayon))
	for x in range(-r, r + 1):
		for z in range(-r, r + 1):
			if x * x + z * z <= rayon * rayon + 0.3:
				for y in hauteur:
					blocs[base + Vector3i(x, y, z)] = couleur

## Un arbre en quarts de bloc : tronc à écorce striée, racines, deux ou trois
## branches, feuillage en quatre à six boules rugueuses dans trois verts —
## sombre dessous, moyen au milieu, clair aux touffes qui prennent le soleil.
## Ancré au pied du tronc, au centre de la case.
static func arbre(graine: int) -> Dictionary:
	var b: Dictionary = {}
	var palette: Array = FEUILLAGES[int(de(graine, 1) * FEUILLAGES.size()) % FEUILLAGES.size()]
	var sombre: Color = palette[1]
	var moyen: Color = palette[0]
	var clair: Color = palette[0].lightened(0.18)
	var haut := 14 + int(de(graine, 2) * 8.0)
	# Le tronc, un peu plus large au pied, écorce striée par colonne.
	for y in haut:
		var rayon := 1.9 if y < 3 else 1.45
		var r := int(ceil(rayon))
		for x in range(-r, r + 1):
			for z in range(-r, r + 1):
				if x * x + z * z <= rayon * rayon + 0.3:
					var strie := de(graine, 300 + x * 7 + z * 13) < 0.35
					b[Vector3i(x, y, z)] = TRONC_SOMBRE if strie else TRONC
	# Les racines : quatre bosses au pied.
	for d in [Vector3i(2, 0, 0), Vector3i(-2, 0, 0), Vector3i(0, 0, 2), Vector3i(0, 0, -2)]:
		b[d] = TRONC_SOMBRE
		b[d + Vector3i(0, 1, 0) if de(graine, 40 + d.x + d.z * 3) < 0.5 else d] = TRONC_SOMBRE
	# Les branches, vers les boules latérales.
	var nombre_boules := 4 + int(de(graine, 3) * 3.0)
	var centres: Array[Vector3i] = []
	var rayon_base := 5.0 + de(graine, 4) * 2.5
	centres.append(Vector3i(0, haut + int(rayon_base * 0.5), 0))
	for i in range(1, nombre_boules):
		var a := de(graine, 10 + i) * TAU
		var l := 2.5 + de(graine, 20 + i) * 3.5
		var c := Vector3i(int(round(cos(a) * l)), haut - 2 + int(de(graine, 30 + i) * 6.0), int(round(sin(a) * l)))
		centres.append(c)
		# Une branche du tronc vers la boule, en escalier.
		var pas := 8
		for k in pas:
			var t := float(k) / float(pas)
			var q := Vector3i(int(round(c.x * t)), haut - 4 + int(round((c.y - (haut - 4)) * t)), int(round(c.z * t)))
			b[q] = TRONC
	# Le feuillage : des boules en vert moyen, puis le dessous passe au sombre
	# et des touffes claires prennent le soleil sur le dessus. (Une coque
	# sombre sous une boule moyenne plus petite laissait le sombre partout
	# en surface : vus de dessus, les arbres étaient des rochers moussus.)
	for i in centres.size():
		var c := centres[i]
		var r := rayon_base * (1.0 if i == 0 else 0.6 + de(graine, 50 + i) * 0.3)
		boule_rugueuse(b, c, Vector3(r, r * 0.8, r), moyen, graine, 60 + i * 7, 0.22)
	var bas := haut - 1
	for p in b.keys():
		var q: Vector3i = p
		if b[q] == moyen and (q.y < bas + int(rayon_base * 0.35) or de(graine, 500 + q.x * 31 + q.y * 7 + q.z * 101) < 0.10):
			b[q] = sombre
	for i in 6 + int(de(graine, 5) * 5.0):
		var c := centres[int(de(graine, 100 + i) * centres.size()) % centres.size()]
		var r := rayon_base * 0.3
		var o := Vector3i(int(round((de(graine, 110 + i) - 0.5) * rayon_base * 1.3)), int(rayon_base * 0.4 + de(graine, 120 + i) * 2.0), int(round((de(graine, 130 + i) - 0.5) * rayon_base * 1.3)))
		boule_rugueuse(b, c + o, Vector3(r, r * 0.6, r), clair, graine, 140 + i * 7, 0.3)
	return b

## Un rocher en quarts de bloc : un galet aplati, gris nuancé, un peu de
## mousse sur le dessus, posé à plat.
static func rocher(graine: int) -> Dictionary:
	var b: Dictionary = {}
	var rx := 2.0 + de(graine, 1) * 2.0
	var ry := 1.6 + de(graine, 2) * 1.2
	var rz := 1.8 + de(graine, 3) * 2.0
	var centre := Vector3i(0, int(ry * 0.45), 0)
	boule_rugueuse(b, centre, Vector3(rx, ry, rz), ROCHE, graine, 10, 0.3)
	for p in b.keys():
		var q: Vector3i = p
		if q.y < 0:
			b.erase(q)
		elif de(graine, 200 + q.x * 31 + q.y * 7 + q.z * 101) < 0.3:
			b[q] = ROCHE_SOMBRE
		elif q.y >= centre.y + int(ry * 0.7) and de(graine, 400 + q.x * 3 + q.z * 5) < 0.25:
			b[q] = Color8(110, 160, 88)
	return b

## Un buisson en huitièmes : trois boules serrées, deux verts, quelques baies.
static func buisson(graine: int) -> Dictionary:
	var b: Dictionary = {}
	var palette: Array = FEUILLAGES[int(de(graine, 1) * FEUILLAGES.size()) % FEUILLAGES.size()]
	boule_rugueuse(b, Vector3i(0, 2, 0), Vector3(4.5, 3.2, 4.5), palette[1], graine, 5, 0.3)
	boule_rugueuse(b, Vector3i(2, 3, 1), Vector3(3.0, 2.6, 3.0), palette[0], graine, 15, 0.3)
	boule_rugueuse(b, Vector3i(-2, 3, -1), Vector3(2.6, 2.4, 2.6), palette[0], graine, 25, 0.3)
	for p in b.keys():
		if (p as Vector3i).y < 0:
			b.erase(p)
	for i in 5:
		var q := Vector3i(int((de(graine, 30 + i) - 0.5) * 7.0), 3 + int(de(graine, 40 + i) * 3.0), int((de(graine, 50 + i) - 0.5) * 7.0))
		if b.has(q):
			b[q] = Color8(220, 60, 70)
	return b

## Une maison en quarts de bloc : murs à planches, poteaux d'angle, porte à
## poignée sous un auvent, deux fenêtres à croisillons et appui, toit à
## pignon en tuiles alternées avec débord, cheminée à chapeau, perron.
## Origine au coin nord-ouest, façade (porte) au sud (z max).
static func maison() -> Dictionary:
	var b: Dictionary = {}
	var L := 28
	var P := 20
	var H := 15
	var planche_a := MUR
	var planche_b := MUR_SOMBRE.lerp(MUR, 0.55)
	# Les murs, pleins puis évidés : l'intérieur ne se voit jamais.
	for y in H:
		boite(b, Vector3i(0, y, 0), Vector3i(L, 1, P), planche_a if (y / 2) % 2 == 0 else planche_b)
	for x in range(2, L - 2):
		for y in range(1, H):
			for z in range(2, P - 2):
				b.erase(Vector3i(x, y, z))
	boite(b, Vector3i(0, 0, 0), Vector3i(L, 1, P), MUR_SOMBRE)
	for x in [0, L - 2]:
		for z in [0, P - 2]:
			boite(b, Vector3i(x, 0, z), Vector3i(2, H, 2), CADRE)
	# La porte, au milieu de la façade sud.
	var m := L / 2
	boite(b, Vector3i(m - 2, 1, P - 1), Vector3i(4, 9, 1), PORTE)
	boite(b, Vector3i(m - 3, 1, P - 1), Vector3i(1, 10, 1), CADRE)
	boite(b, Vector3i(m + 2, 1, P - 1), Vector3i(1, 10, 1), CADRE)
	boite(b, Vector3i(m - 3, 10, P - 1), Vector3i(6, 1, 1), CADRE)
	b[Vector3i(m + 1, 5, P)] = Color8(230, 190, 80)
	boite(b, Vector3i(m - 1, 2, P - 1), Vector3i(2, 6, 1), PORTE.darkened(0.15))
	# L'auvent au-dessus de la porte.
	boite(b, Vector3i(m - 4, 11, P - 1), Vector3i(8, 1, 3), TOIT)
	boite(b, Vector3i(m - 4, 12, P - 1), Vector3i(8, 1, 2), TOIT_CLAIR)
	# Le perron : deux marches.
	boite(b, Vector3i(m - 3, 0, P), Vector3i(6, 1, 2), MUR_SOMBRE)
	# Les fenêtres, une de chaque côté de la porte.
	for x0 in [4, L - 10]:
		boite(b, Vector3i(x0, 5, P - 1), Vector3i(6, 6, 1), CADRE)
		boite(b, Vector3i(x0 + 1, 6, P - 1), Vector3i(4, 4, 1), VITRE)
		boite(b, Vector3i(x0 + 3, 6, P - 1), Vector3i(1, 4, 1), CADRE)
		boite(b, Vector3i(x0 + 1, 8, P - 1), Vector3i(4, 1, 1), CADRE)
		boite(b, Vector3i(x0 - 1, 4, P - 1), Vector3i(8, 1, 2), MUR_SOMBRE)
		# Et un pot de fleurs sur l'appui.
		b[Vector3i(x0 + 1, 5, P)] = TERRE_SOMBRE
		b[Vector3i(x0 + 1, 6, P)] = Color8(230, 80, 90)
	# Une fenêtre sur chaque pignon.
	for x0 in [0, L - 1]:
		boite(b, Vector3i(x0, 6, P / 2 - 3), Vector3i(1, 5, 6), CADRE)
		boite(b, Vector3i(x0, 7, P / 2 - 2), Vector3i(1, 3, 4), VITRE)
	# Le toit : pente nord-sud, une marche de 2 tous les 2 voxels de hauteur,
	# tuiles alternées, débord de 2 sur les pignons.
	var z0 := -2
	var z1 := P + 1
	var etage := 0
	while z0 < z1:
		var teinte := TOIT if (etage / 2) % 2 == 0 else TOIT_CLAIR
		for y in 2:
			boite(b, Vector3i(-2, H + etage * 2 + y, z0), Vector3i(L + 4, 1, z1 - z0 + 1), teinte)
			if z0 + 2 < z1 - 2:
				# Le pignon, en planches, sous le toit.
				boite(b, Vector3i(0, H + etage * 2 + y, z0 + 2), Vector3i(L, 1, z1 - z0 - 3), planche_a if ((H + etage * 2 + y) / 2) % 2 == 0 else planche_b)
				for x in range(2, L - 2):
					for z in range(z0 + 3, z1 - 2):
						b.erase(Vector3i(x, H + etage * 2 + y, z))
		# Le rebord des tuiles, plus sombre.
		for x in range(-2, L + 2):
			b[Vector3i(x, H + etage * 2, z0)] = TOIT.darkened(0.25)
			b[Vector3i(x, H + etage * 2, z1)] = TOIT.darkened(0.25)
		z0 += 2
		z1 -= 2
		etage += 1
	# Le faîte.
	boite(b, Vector3i(-2, H + etage * 2, z0 - 1), Vector3i(L + 4, 1, 3), CADRE)
	# La cheminée avec son chapeau.
	boite(b, Vector3i(L - 8, H, 4), Vector3i(4, etage * 2 + 5, 4), CADRE)
	boite(b, Vector3i(L - 9, H + etage * 2 + 5, 3), Vector3i(6, 1, 6), ROCHE_SOMBRE)
	boite(b, Vector3i(L - 8, H + etage * 2 + 6, 4), Vector3i(4, 1, 4), Color8(30, 30, 34))
	return b

## Un morceau de clôture en huitièmes : poteaux 2 × 2 à chapeau tous les
## 8 voxels (une case), deux lisses. `longueur` en voxels.
static func cloture(longueur: int, le_long_de_x: bool) -> Dictionary:
	var b: Dictionary = {}
	for i in range(0, longueur + 1, 8):
		var p := Vector3i(i, 0, 0) if le_long_de_x else Vector3i(0, 0, i)
		boite(b, p, Vector3i(2, 8, 2), BOIS_SOMBRE)
		boite(b, p + Vector3i(0, 8, 0), Vector3i(2, 1, 2), BOIS_SOMBRE.darkened(0.2))
	for y in [2, 5]:
		if le_long_de_x:
			boite(b, Vector3i(0, y, 0), Vector3i(longueur + 2, 2, 1), BOIS)
		else:
			boite(b, Vector3i(0, y, 0), Vector3i(1, 2, longueur + 2), BOIS)
	return b

## Une fleur en huitièmes : tige, deux feuilles, corolle en croix, cœur.
static func fleur(graine: int) -> Dictionary:
	var b: Dictionary = {}
	var tige := Color8(80, 150, 66)
	var haut := 3 + int(de(graine, 3) * 3.0)
	for y in haut:
		b[Vector3i(0, y, 0)] = tige
	b[Vector3i(1, haut / 2, 0)] = tige
	b[Vector3i(-1, haut / 2 + 1, 0)] = tige
	var teinte: Color = FLEURS[int(de(graine, 1) * FLEURS.size()) % FLEURS.size()]
	for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		b[Vector3i(0, haut, 0) + d] = teinte
	b[Vector3i(0, haut, 0)] = Color8(250, 220, 90) if de(graine, 2) < 0.7 else teinte.lightened(0.3)
	return b

## Une touffe d'herbe en huitièmes : trois à cinq brins de hauteurs inégales.
static func touffe(graine: int) -> Dictionary:
	var b: Dictionary = {}
	var vert := Color8(96, 168, 82) if de(graine, 1) < 0.5 else Color8(140, 196, 96)
	for i in 3 + int(de(graine, 2) * 3.0):
		var x := int(de(graine, 10 + i) * 4.0)
		var z := int(de(graine, 20 + i) * 4.0)
		for y in 1 + int(de(graine, 30 + i) * 3.0):
			b[Vector3i(x, y, z)] = vert.darkened(y * 0.06)
	return b

## Un nénuphar en huitièmes : une feuille ronde échancrée, parfois une fleur.
static func nenuphar(graine: int) -> Dictionary:
	var b: Dictionary = {}
	var vert := Color8(70, 150, 80)
	for x in range(-3, 4):
		for z in range(-3, 4):
			if x * x + z * z <= 10:
				b[Vector3i(x, 0, z)] = vert if (x + z) % 2 == 0 else vert.lightened(0.08)
	b.erase(Vector3i(2, 0, 2))
	b.erase(Vector3i(3, 0, 3))
	b.erase(Vector3i(3, 0, 2))
	if de(graine, 2) < 0.3:
		boite(b, Vector3i(-1, 1, -1), Vector3i(2, 1, 2), Color8(245, 200, 225))
		b[Vector3i(0, 2, 0)] = Color8(250, 230, 120)
	return b

## Un nuage : deux ou trois galettes blanches superposées, bord irrégulier.
static func nuage(graine: int) -> Dictionary:
	var b: Dictionary = {}
	var blanc := Color8(250, 250, 252)
	var ombre := Color8(214, 222, 236)
	var longueur := 6 + int(de(graine, 1) * 8.0)
	var largeur := 3 + int(de(graine, 2) * 4.0)
	for x in longueur:
		for z in largeur:
			var bord := (x == 0 or x == longueur - 1 or z == 0 or z == largeur - 1)
			if bord and de(graine, 10 + x * 13 + z) < 0.45:
				continue
			b[Vector3i(x, 0, z)] = [blanc, ombre]
			if not bord and de(graine, 200 + x * 13 + z) < 0.55:
				b[Vector3i(x, 1, z)] = [blanc, ombre]
	return b

## Un plant en seizièmes de bloc, à un stade (0 graine … 4 mûr). `fiche`
## porte la couleur du légume, sa hauteur adulte (en huitièmes, doublée
## ici) et s'il pousse en terre.
static func plant(fiche: Dictionary, stade: int, graine: int) -> Dictionary:
	var b: Dictionary = {}
	var vert := Color8(88, 170, 70)
	var vert_sombre := Color8(60, 130, 55)
	var fruit: Color = fiche["teinte"]
	var haut_adulte: int = int(fiche["hauteur"]) * 2
	var racine := bool(fiche.get("racine", false))
	match stade:
		0:
			boite(b, Vector3i(-1, 0, -1), Vector3i(2, 1, 2), Color8(120, 90, 50))
		1:
			boite(b, Vector3i(0, 0, 0), Vector3i(1, 3, 1), vert_sombre)
			b[Vector3i(1, 2, 0)] = vert
			b[Vector3i(-1, 3, 0)] = vert
		_:
			var h := maxi(4, haut_adulte * (stade - 1) / 3)
			boite(b, Vector3i(0, 0, 0), Vector3i(1, h, 1), vert_sombre)
			# Des feuilles en petites croix le long de la tige.
			for i in 2 + stade * 2:
				var y := 1 + int(de(graine, i) * float(h - 1))
				var dx := int(round(de(graine, i + 7) * 2.0 - 1.0))
				var dz := int(round(de(graine, i + 3) * 2.0 - 1.0))
				var f := Vector3i(dx * 2, y, dz * 2)
				b[f] = vert
				b[f + Vector3i(dx, 0, dz)] = vert
				b[f + Vector3i(0, 1, 0)] = vert.lightened(0.15)
			if stade >= 4:
				if racine:
					boule_rugueuse(b, Vector3i(0, 1, 0), Vector3(2.5, 1.6, 2.5), fruit, graine, 40, 0.2)
				else:
					for i in 3:
						var c := Vector3i(int(round(de(graine, i + 20) * 4.0 - 2.0)), 2 + int(de(graine, i + 27) * float(h - 2)), int(round(de(graine, i + 23) * 4.0 - 2.0)))
						boite(b, c, Vector3i(2, 2, 2), fruit)
	return b

## Le héros en seizièmes de bloc : tête 12 × 12 avec yeux, bouche et cheveux,
## buste à ceinture et boucle aux couleurs du joueur, bras à mains, jambes à
## bottes, et la tenue de sa classe — chevalier, voleur, sorcier — comme au
## village. Retourne un dictionnaire de parties, chacune ancrée sur son pivot.
static func heros(classe: String, couleur: Color) -> Dictionary:
	var tenue := couleur
	var chapeau := Color8(90, 60, 140)
	match classe:
		"knight":
			tenue = Color8(160, 168, 180)
			chapeau = Color8(190, 60, 60)
		"rogue":
			tenue = Color8(70, 120, 70)
			chapeau = Color8(50, 90, 50)
		_:
			tenue = Color8(110, 60, 150)
			chapeau = Color8(92, 48, 130)
	var corps: Dictionary = {}
	boite(corps, Vector3i(-6, 0, -4), Vector3i(12, 12, 8), tenue)
	boite(corps, Vector3i(-6, 4, -4), Vector3i(12, 2, 8), CADRE)
	boite(corps, Vector3i(-1, 4, 4), Vector3i(2, 2, 1), Color8(230, 190, 80))
	boite(corps, Vector3i(-2, 6, 4), Vector3i(4, 5, 1), couleur)
	# Le col.
	boite(corps, Vector3i(-3, 11, -3), Vector3i(6, 1, 6), tenue.darkened(0.25))
	var tete: Dictionary = {}
	boite(tete, Vector3i(-6, 0, -6), Vector3i(12, 12, 12), PEAU)
	boite(tete, Vector3i(-6, 8, -6), Vector3i(12, 4, 12), CHEVEUX)
	boite(tete, Vector3i(-6, 6, -6), Vector3i(12, 2, 11), CHEVEUX)
	boite(tete, Vector3i(-7, 7, -7), Vector3i(14, 4, 14), CHEVEUX)
	# Yeux (blanc + pupille), bouche, joues.
	for x in [-4, 2]:
		boite(tete, Vector3i(x, 3, 6), Vector3i(2, 2, 1), Color8(250, 250, 250))
		tete[Vector3i(x + 1, 3, 6)] = CADRE
	boite(tete, Vector3i(-1, 1, 6), Vector3i(2, 1, 1), Color8(190, 110, 100))
	tete[Vector3i(-5, 2, 6)] = Color8(240, 170, 160)
	tete[Vector3i(4, 2, 6)] = Color8(240, 170, 160)
	match classe:
		"knight":
			boite(tete, Vector3i(-6, 0, -6), Vector3i(12, 12, 12), tenue)
			boite(tete, Vector3i(-7, 7, -7), Vector3i(14, 4, 14), tenue)
			boite(tete, Vector3i(-7, 6, -7), Vector3i(14, 1, 14), CADRE)
			boite(tete, Vector3i(-4, 3, 6), Vector3i(8, 2, 1), CADRE)
			boite(tete, Vector3i(-1, 11, -1), Vector3i(2, 6, 2), chapeau)
			boite(tete, Vector3i(-1, 13, -5), Vector3i(2, 3, 5), chapeau)
		"rogue":
			boite(tete, Vector3i(-7, 5, -7), Vector3i(14, 7, 14), chapeau)
			boite(tete, Vector3i(-6, 4, -6), Vector3i(12, 1, 12), chapeau)
			boite(tete, Vector3i(-3, 12, -7), Vector3i(6, 2, 8), chapeau)
			for x in [-4, 2]:
				boite(tete, Vector3i(x, 3, 6), Vector3i(2, 2, 1), Color8(250, 250, 250))
				tete[Vector3i(x + 1, 3, 6)] = CADRE
		_:
			boite(tete, Vector3i(-10, 12, -10), Vector3i(20, 2, 20), chapeau)
			boite(tete, Vector3i(-9, 12, -9), Vector3i(18, 1, 18), chapeau.lightened(0.1))
			boite(tete, Vector3i(-6, 14, -6), Vector3i(12, 4, 12), chapeau)
			boite(tete, Vector3i(-6, 14, -6), Vector3i(12, 1, 12), Color8(230, 190, 80))
			boite(tete, Vector3i(-4, 18, -4), Vector3i(8, 4, 8), chapeau)
			boite(tete, Vector3i(-2, 22, -2), Vector3i(4, 4, 4), chapeau)
			boite(tete, Vector3i(-1, 26, 0), Vector3i(2, 3, 2), chapeau)
			# Barbe blanche et moustache.
			boite(tete, Vector3i(-4, -3, 5), Vector3i(8, 4, 2), Color8(240, 240, 240))
			boite(tete, Vector3i(-2, -6, 6), Vector3i(4, 3, 1), Color8(240, 240, 240))
			boite(tete, Vector3i(-3, 1, 6), Vector3i(6, 1, 1), Color8(240, 240, 240))
	var bras: Dictionary = {}
	boite(bras, Vector3i(-2, -10, -2), Vector3i(4, 10, 4), tenue)
	boite(bras, Vector3i(-2, -10, -2), Vector3i(4, 3, 4), PEAU)
	boite(bras, Vector3i(-2, -7, -2), Vector3i(4, 1, 4), tenue.darkened(0.25))
	var jambe: Dictionary = {}
	boite(jambe, Vector3i(-2, -10, -2), Vector3i(5, 10, 5), Color8(70, 60, 80))
	boite(jambe, Vector3i(-2, -10, -2), Vector3i(5, 3, 6), CADRE)
	return {"corps": corps, "tete": tete, "bras": bras, "jambe": jambe}

## La boîte aux lettres en huitièmes : poteau, boîte rouge à porte claire, drapeau.
static func boite_aux_lettres() -> Dictionary:
	var b: Dictionary = {}
	boite(b, Vector3i(2, 0, 2), Vector3i(2, 9, 2), BOIS_SOMBRE)
	boite(b, Vector3i(0, 9, 0), Vector3i(6, 4, 7), TOIT)
	boite(b, Vector3i(1, 13, 1), Vector3i(4, 1, 5), TOIT_CLAIR)
	boite(b, Vector3i(1, 10, 7), Vector3i(4, 2, 1), TOIT_CLAIR)
	b[Vector3i(3, 10, 8)] = Color8(230, 190, 80)
	boite(b, Vector3i(6, 11, 2), Vector3i(1, 3, 1), Color8(230, 190, 80))
	return b

## La pancarte en huitièmes : poteau, planche à quatre lignes d'« écriture ».
static func pancarte() -> Dictionary:
	var b: Dictionary = {}
	boite(b, Vector3i(4, 0, 2), Vector3i(2, 12, 2), BOIS_SOMBRE)
	boite(b, Vector3i(0, 8, 1), Vector3i(10, 6, 1), BOIS)
	boite(b, Vector3i(0, 8, 1), Vector3i(10, 1, 1), BOIS_SOMBRE)
	boite(b, Vector3i(0, 13, 1), Vector3i(10, 1, 1), BOIS_SOMBRE)
	for y in [10, 12]:
		for x in range(2, 8):
			if (x + y) % 2 == 0:
				b[Vector3i(x, y, 1)] = CADRE
	return b

## Le foyer en huitièmes : un cercle de pierres, des bûches croisées, des braises.
static func foyer() -> Dictionary:
	var b: Dictionary = {}
	for i in 10:
		var a := float(i) * TAU / 10.0
		var c := Vector3i(6 + int(round(cos(a) * 5.0)), 0, 6 + int(round(sin(a) * 5.0)))
		boite(b, c, Vector3i(2, 1 + (i % 2), 2), ROCHE if i % 3 != 0 else ROCHE_SOMBRE)
	boite(b, Vector3i(2, 0, 6), Vector3i(9, 2, 2), TRONC_SOMBRE)
	boite(b, Vector3i(6, 1, 2), Vector3i(2, 2, 9), TRONC)
	boite(b, Vector3i(4, 0, 4), Vector3i(5, 1, 5), Color8(60, 40, 36))
	for i in 6:
		b[Vector3i(4 + int(de(7, i) * 5.0), 1, 4 + int(de(9, i) * 5.0))] = Color8(255, 120, 40)
	return b

## Le portail Aperture en huitièmes : deux montants en panneaux blancs à
## joints sombres, un linteau, une plaque bleue et un socle. Ancré au pied du
## montant gauche ; l'ouverture fait 2 cases de large sur 3 de haut.
static func portail() -> Dictionary:
	var b: Dictionary = {}
	var panneau := Color8(232, 234, 238)
	var joint := Color8(150, 154, 166)
	var sombre := Color8(70, 74, 86)
	var largeur := 8 * 3
	var hauteur := 8 * 3
	for x0 in [0, largeur - 4]:
		for y in hauteur:
			for x in 4:
				for z in 4:
					var bord := (y % 8 == 0) or (x == 0 or x == 3 or z == 0 or z == 3) and (y % 8 == 7)
					b[Vector3i(x0 + x, y, z)] = joint if bord else panneau
		# La bande bleue sur chaque montant.
		for y in range(6, hauteur - 4):
			b[Vector3i(x0 + (3 if x0 == 0 else 0), y, 4)] = Color8(57, 135, 229)
	# Le linteau.
	boite(b, Vector3i(0, hauteur, 0), Vector3i(largeur, 4, 4), panneau)
	boite(b, Vector3i(0, hauteur, 0), Vector3i(largeur, 1, 4), joint)
	boite(b, Vector3i(0, hauteur + 3, 0), Vector3i(largeur, 1, 4), joint)
	boite(b, Vector3i(largeur / 2 - 4, hauteur + 1, 4), Vector3i(8, 2, 1), sombre)
	# Le socle, une marche.
	boite(b, Vector3i(-1, 0, -1), Vector3i(largeur + 2, 1, 6), sombre)
	boite(b, Vector3i(4, 0, 0), Vector3i(largeur - 8, 1, 4), Color8(120, 126, 140))
	return b

## L'anneau du portail : un ovale bleu, plus clair au bord, dans l'ouverture.
static func anneau_portail(coeur: Color = Color8(40, 90, 200), bord: Color = Color8(120, 190, 255)) -> Dictionary:
	var b: Dictionary = {}
	for x in range(-6, 7):
		for y in range(0, 22):
			var d := pow(x / 6.5, 2.0) + pow((y - 11) / 10.5, 2.0)
			if d <= 1.0:
				b[Vector3i(x, y + 1, 0)] = bord if d > 0.7 else coeur
	return b

## Le cube d'Aperture en huitièmes : gris clair, angles sombres, un chevron
## orange sur chaque face. Une case de côté.
static func cube_aperture() -> Dictionary:
	var b: Dictionary = {}
	var gris := Color8(200, 204, 212)
	var sombre := Color8(90, 94, 106)
	var orange := Color8(236, 131, 90)
	boite(b, Vector3i(0, 0, 0), Vector3i(8, 8, 8), gris)
	for x in [0, 7]:
		for y in [0, 7]:
			boite(b, Vector3i(x, y, 0), Vector3i(1, 1, 8), sombre)
			boite(b, Vector3i(x, 0, y), Vector3i(1, 8, 1), sombre)
			boite(b, Vector3i(0, x, y), Vector3i(8, 1, 1), sombre)
	for face in 4:
		for i in 3:
			var d := 2 + i
			match face:
				0: boite(b, Vector3i(d, 2 + i, 7), Vector3i(1, 1, 1), orange)
				1: boite(b, Vector3i(d, 2 + i, 0), Vector3i(1, 1, 1), orange)
				2: boite(b, Vector3i(7, 2 + i, d), Vector3i(1, 1, 1), orange)
				3: boite(b, Vector3i(0, 2 + i, d), Vector3i(1, 1, 1), orange)
	boite(b, Vector3i(3, 7, 3), Vector3i(2, 1, 2), orange)
	return b

## La dalle de pression : un anneau plat, coloré par le moteur (rouge, vert).
static func dalle_pression() -> Dictionary:
	var b: Dictionary = {}
	boite(b, Vector3i(1, 0, 1), Vector3i(6, 1, 6), Color.WHITE)
	boite(b, Vector3i(2, 0, 2), Vector3i(4, 1, 4), Color(0.6, 0.6, 0.6))
	return b

## La porte de la salle : trois cases de large, quatre de haut, en panneaux
## rayés de sombre, qui descend dans le sol quand la dalle est active.
static func porte_aperture() -> Dictionary:
	var b: Dictionary = {}
	boite(b, Vector3i(0, 0, 0), Vector3i(8, 32, 24), Color8(200, 204, 212))
	for y in range(0, 32, 4):
		boite(b, Vector3i(0, y, 0), Vector3i(8, 1, 24), Color8(90, 94, 106))
	boite(b, Vector3i(3, 12, 0), Vector3i(2, 8, 24), Color8(236, 131, 90))
	return b

## L'écriteau « 01 » de la salle, en huitièmes, à accrocher au mur.
static func ecriteau_01() -> Dictionary:
	var b: Dictionary = {}
	boite(b, Vector3i(0, 0, 0), Vector3i(16, 10, 1), Color8(60, 64, 76))
	var blanc := Color8(240, 240, 244)
	# « 0 »
	boite(b, Vector3i(2, 1, 1), Vector3i(1, 8, 1), blanc)
	boite(b, Vector3i(6, 1, 1), Vector3i(1, 8, 1), blanc)
	boite(b, Vector3i(2, 1, 1), Vector3i(5, 1, 1), blanc)
	boite(b, Vector3i(2, 8, 1), Vector3i(5, 1, 1), blanc)
	# « 1 »
	boite(b, Vector3i(11, 1, 1), Vector3i(1, 8, 1), blanc)
	boite(b, Vector3i(9, 1, 1), Vector3i(5, 1, 1), blanc)
	b[Vector3i(10, 7, 1)] = blanc
	return b
