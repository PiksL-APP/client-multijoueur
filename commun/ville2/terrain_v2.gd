class_name TerrainV2
extends RefCounted
## LE TERRAIN CONTINU (cahier § 4 : « maillage lissé »).
##
## La ville est plate là où le kit pose ses tuiles : une rue, un ouvrage, un
## lot sont posés À PLAT au palier de leur case, et c'est ce qui garde les
## marquages et les trottoirs du kit à leurs proportions. Partout ailleurs —
## herbe, sable, terre, roche, et le fond de la mer — le sol est un MAILLAGE
## qui suit l'altitude case par case, lissé aux coins.
##
## ⚠ LA SOUDURE EST TOUTE LA DIFFICULTÉ. Un coin de grille touche quatre
## cases. Si l'une d'elles est PLATE (une tuile du kit), le coin prend SON
## altitude : le terrain vient mourir exactement au bord de la tuile, sans
## marche ni fente. Si aucune ne l'est, le coin prend la MOYENNE des quatre :
## c'est ce qui fait une colline lisse au lieu d'un escalier de cases. Deux
## morceaux voisins calculent le même coin à partir des mêmes cases : ils se
## rejoignent au millième près, et la couture ne se voit pas.
##
## ⚠ LA MER A UN FOND. Une plage « en pente douce où le sable entre dans
## l'eau » n'existe que si les cases d'eau portent une altitude négative : le
## sable descend sous la nappe au lieu de s'arrêter net sur une falaise de
## deux centimètres.

const CASE := Ville2.CASE

## La couleur de chaque matière. Elles viennent de la palette du jeu (le sable
## et la roche de `Quartiers`), pour que le terrain ne jure pas avec les kits.
const COULEURS := {
	Ville2.M_HERBE: Color("#5d9a3c"),
	Ville2.M_SABLE: Color("#e0cb9a"),
	Ville2.M_TERRE: Color("#6b5a44"),
	Ville2.M_ROCHE: Color("#a8a49c"),
	Ville2.M_DALLE: Color("#d9d6cf"),
}
## Le fond de la mer, là où l'on ne voit plus le sable.
const TEINTE_FOND := Color("#6f7a63")
## Au-delà de cette profondeur, la couleur du fond l'emporte sur le sable.
const FOND_PROFOND := 6.0

static var _matiere: StandardMaterial3D = null

static func matiere() -> StandardMaterial3D:
	if _matiere == null:
		_matiere = StandardMaterial3D.new()
		_matiere.vertex_color_use_as_albedo = true
		_matiere.roughness = 1.0
		_matiere.specular = 0.1
	return _matiere

## L'altitude d'un COIN de grille — le coin nord-ouest de la case (i, j).
## Voir l'avertissement en tête de fichier : une case plate impose la sienne.
static func hauteur_coin(ville: Ville2, i: int, j: int) -> float:
	var haut := -1.0e9
	var somme := 0.0
	var n := 0
	for dj in 2:
		for di in 2:
			var c := Vector2i(i - 1 + di, j - 1 + dj)
			if not ville.dedans(c): continue
			if ville.plate(c):
				haut = maxf(haut, ville.sol(c))
			else:
				somme += ville.sol(c)
				n += 1
	if haut > -1.0e8: return haut
	return somme / float(n) if n > 0 else 0.0

## La couleur d'un coin : la moyenne des cases de terrain qui le touchent.
## Un coin entre sable et herbe sort donc à mi-chemin, et la plage se fond
## dans la pelouse au lieu de se découper au couteau.
static func couleur_coin(ville: Ville2, i: int, j: int) -> Color:
	var somme := Color(0, 0, 0, 0)
	var n := 0
	for dj in 2:
		for di in 2:
			var c := Vector2i(i - 1 + di, j - 1 + dj)
			if not ville.dedans(c): continue
			somme += _couleur_case(ville, c)
			n += 1
	return somme / float(n) if n > 0 else COULEURS[Ville2.M_HERBE]

static func _couleur_case(ville: Ville2, c: Vector2i) -> Color:
	if not ville.terre(c):
		# Le fond marin : sable près du bord, vase au large.
		var p := clampf(-ville.sol(c) / FOND_PROFOND, 0.0, 1.0)
		return COULEURS[Ville2.M_SABLE].lerp(TEINTE_FOND, p)
	return COULEURS.get(ville.matiere_de(c), COULEURS[Ville2.M_HERBE])

## L'ALTITUDE EXACTE DU SOL en un point du monde — celle du maillage, pas
## celle de la case. Sur une pente, poser un arbre au palier de sa case
## l'enterrait d'un côté et le faisait flotter de l'autre : on interpole donc
## entre les quatre coins, comme le maillage lui-même.
static func hauteur_en(ville: Ville2, x: float, z: float) -> float:
	var i := floori(x / CASE)
	var j := floori(z / CASE)
	var c := Vector2i(i, j)
	if ville.plate(c):
		return ville.sol(c)
	var u := x / CASE - float(i)
	var w := z / CASE - float(j)
	var h00 := hauteur_coin(ville, i, j)
	var h10 := hauteur_coin(ville, i + 1, j)
	var h01 := hauteur_coin(ville, i, j + 1)
	var h11 := hauteur_coin(ville, i + 1, j + 1)
	return lerpf(lerpf(h00, h10, u), lerpf(h01, h11, u), w)

## Le maillage du terrain pour une zone (en cases). Rend `null` s'il n'y a
## rien à mailler — une zone entièrement pavée, par exemple.
static func maillage(ville: Ville2, zone: Rect2i) -> ArrayMesh:
	var sommets := PackedVector3Array()
	var couleurs := PackedColorArray()
	var indices := PackedInt32Array()
	## Les coins de la zone, +1 dans chaque sens ; −1 quand le coin n'a pas
	## encore servi (on ne crée que les coins des cases réellement maillées).
	var large := zone.size.x + 1
	var rang := PackedInt32Array()
	rang.resize(large * (zone.size.y + 1))
	rang.fill(-1)
	var coin := func(i: int, j: int) -> int:
		var k := (j - zone.position.y) * large + (i - zone.position.x)
		if rang[k] >= 0: return rang[k]
		rang[k] = sommets.size()
		sommets.append(Vector3(float(i) * CASE, hauteur_coin(ville, i, j), float(j) * CASE))
		couleurs.append(couleur_coin(ville, i, j))
		return rang[k]
	for j in range(zone.position.y, zone.end.y):
		for i in range(zone.position.x, zone.end.x):
			var c := Vector2i(i, j)
			if not ville.dedans(c) or ville.plate(c): continue
			var a: int = coin.call(i, j)
			var b: int = coin.call(i + 1, j)
			var d: int = coin.call(i + 1, j + 1)
			var e: int = coin.call(i, j + 1)
			# ⚠ GODOT VEUT LE SENS HORAIRE VU DE FACE. Nord-ouest, nord-est,
			# sud-est : vu du ciel, c'est bien le sens des aiguilles. Le sens
			# inverse compilait, s'affichait au banc… et disparaissait en jeu :
			# la plage était culled, et on voyait la mer à travers le sable.
			indices.append_array([a, b, d, a, d, e])
	if indices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = sommets
	arrays[Mesh.ARRAY_COLOR] = couleurs
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_NORMAL] = _normales(sommets, indices)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

## Les normales, accumulées par sommet : c'est ce qui donne une colline LISSE
## plutôt qu'un damier de facettes. `SurfaceTool` ferait la même chose, au
## prix d'une copie de tout le maillage.
static func _normales(sommets: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	var n := PackedVector3Array()
	n.resize(sommets.size())
	n.fill(Vector3.ZERO)
	for k in range(0, indices.size(), 3):
		var a := indices[k]
		var b := indices[k + 1]
		var c := indices[k + 2]
		# La normale qui va avec le sens horaire : (C−A) × (B−A) pointe au ciel.
		var f := (sommets[c] - sommets[a]).cross(sommets[b] - sommets[a])
		n[a] += f
		n[b] += f
		n[c] += f
	for k in n.size():
		n[k] = n[k].normalized() if n[k].length_squared() > 1.0e-9 else Vector3.UP
	return n

## LA NAPPE D'EAU d'une zone : un quadrillage à hauteur de mer au-dessus des
## cases d'eau. Elle est découpée en cases plutôt qu'en un grand rectangle
## pour qu'une baie ne recouvre pas la terre qui l'entoure.
const NIVEAU_MER := -2.85

static func maillage_eau(ville: Ville2, zone: Rect2i) -> ArrayMesh:
	var sommets := PackedVector3Array()
	var indices := PackedInt32Array()
	var large := zone.size.x + 1
	var rang := PackedInt32Array()
	rang.resize(large * (zone.size.y + 1))
	rang.fill(-1)
	var coin := func(i: int, j: int) -> int:
		var k := (j - zone.position.y) * large + (i - zone.position.x)
		if rang[k] >= 0: return rang[k]
		rang[k] = sommets.size()
		sommets.append(Vector3(float(i) * CASE, NIVEAU_MER, float(j) * CASE))
		return rang[k]
	for j in range(zone.position.y, zone.end.y):
		for i in range(zone.position.x, zone.end.x):
			var c := Vector2i(i, j)
			if not ville.dedans(c) or ville.terre(c): continue
			var a: int = coin.call(i, j)
			var b: int = coin.call(i + 1, j)
			var d: int = coin.call(i + 1, j + 1)
			var e: int = coin.call(i, j + 1)
			indices.append_array([a, b, d, a, d, e])
	if indices.is_empty():
		return null
	var normales := PackedVector3Array()
	normales.resize(sommets.size())
	normales.fill(Vector3.UP)
	var uv := PackedVector2Array()
	uv.resize(sommets.size())
	for k in sommets.size():
		uv[k] = Vector2(sommets[k].x, sommets[k].z) / CASE
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = sommets
	arrays[Mesh.ARRAY_NORMAL] = normales
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
