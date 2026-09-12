class_name TerrainV2
extends RefCounted
## LE TERRAIN EN GRADINS.
##
## ⚠ CE FICHIER A CHANGÉ D'ÉCOLE LE 12/09. Il maillait un terrain CONTINU,
## lissé aux coins — une belle colline ronde. Le client l'a refusé net : « je
## ne veux pas de pente lissée, on les verra plus tard », après avoir constaté
## que les objets flottaient. Il avait raison, et la raison est géométrique :
## sur une case en pente le sol n'a pas UNE hauteur mais une par point, donc
## l'arbre qu'on y pose ne peut être posé qu'en un seul endroit — partout
## ailleurs il flotte ou s'enterre.
##
## Désormais : UNE CASE DE TERRE = UN PLATEAU. Un carré plat à l'altitude de
## la case, et des jupes verticales qui le rattachent à ses voisins plus bas.
## Le relief se lit en marches nettes, comme le diorama du kit Kenney — et
## `hauteur_en()` rend une hauteur exacte en tout point, donc RIEN NE PEUT
## PLUS FLOTTER.
##
## Seul LE FOND DE LA MER garde le maillage lissé d'avant : on n'y pose rien,
## et une plage doit entrer dans l'eau sans marche. `hauteur_coin` et
## `couleur_coin` ne servent plus qu'à lui.
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
## L'altitude du DESSUS d'une case plate, celle sur laquelle la tuile est
## posée. Le rendu pose une chaussée au palier arrondi et une dalle à son sol
## exact : la nappe doit suivre la même règle, sinon elle perce la tuile.
## De combien la nappe passe SOUS la tuile du kit : assez pour que la tuile
## gagne toujours, assez peu pour que la rainure reste bouchée.
const SOUS_LA_TUILE := 0.12

static func hauteur_plate(ville: Ville2, c: Vector2i) -> float:
	if ville.carte != null and ville.carte.route(c):
		return float(ville.carte.palier(c)) * Ville2.PALIER
	return ville.sol(c)

static func hauteur_coin(ville: Ville2, i: int, j: int) -> float:
	var haut := -1.0e9
	var somme := 0.0
	var n := 0
	for dj in 2:
		for di in 2:
			var c := Vector2i(i - 1 + di, j - 1 + dj)
			if not ville.dedans(c): continue
			if ville.plate(c):
				# Une chaussée est posée au palier ARRONDI (c'est la tuile du
				# kit qui commande) ; une autre case plate suit son sol exact.
				haut = maxf(haut, hauteur_plate(ville, c))
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

## ⚠ LA NAPPE PREND LA COULEUR DE CE QUI EST POSÉ DESSUS. Sous une chaussée,
## elle est de la couleur du BITUME ; partout ailleurs, de celle de sa matière.
## Sans ça, le cheveu qui reste au joint de deux tuiles laisse voir du gris
## clair au milieu du noir : un liseré, et la route se lit en dalles séparées.
const TEINTE_BITUME := Color("#79808f")

static func _couleur_case(ville: Ville2, c: Vector2i) -> Color:
	if ville.carte != null and ville.carte.route(c):
		return TEINTE_BITUME
	if not ville.terre(c):
		# Le fond marin : sable près du bord, vase au large.
		var p := clampf(-ville.sol(c) / FOND_PROFOND, 0.0, 1.0)
		return COULEURS[Ville2.M_SABLE].lerp(TEINTE_FOND, p)
	return COULEURS.get(ville.matiere_de(c), COULEURS[Ville2.M_HERBE])

## L'ALTITUDE EXACTE DU SOL en un point du monde. À TERRE, C'EST CELLE DE LA
## CASE, ET RIEN D'AUTRE : le sol est en gradins, une case = un plateau, donc
## tout point de la case est à la même hauteur. C'est là toute la vertu du
## gradin — un objet posé n'importe où dans la case est POSÉ, jamais à moitié
## enterré ni en l'air. Seul le fond de la mer reste interpolé : on n'y pose
## rien, et une plage doit entrer dans l'eau sans marche.
static func hauteur_en(ville: Ville2, x: float, z: float) -> float:
	var i := floori(x / CASE)
	var j := floori(z / CASE)
	var c := Vector2i(i, j)
	if ville.terre(c):
		return dessus(ville, c)
	var u := x / CASE - float(i)
	var w := z / CASE - float(j)
	var h00 := hauteur_coin(ville, i, j)
	var h10 := hauteur_coin(ville, i + 1, j)
	var h01 := hauteur_coin(ville, i, j + 1)
	var h11 := hauteur_coin(ville, i + 1, j + 1)
	return lerpf(lerpf(h00, h10, u), lerpf(h01, h11, u), w)

## Le DESSUS d'une case de terre : la tuile du kit si la case est plate, son
## sol sinon. C'est la seule altitude qu'une case possède.
static func dessus(ville: Ville2, c: Vector2i) -> float:
	return hauteur_plate(ville, c) if ville.plate(c) else ville.sol(c)

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
			if not ville.dedans(c): continue
			# ⚠ LE SOL EST CONTINU, CASES PLATES COMPRISES. Première version :
			# la nappe s'arrêtait au bord des tuiles, et l'on voyait le VIDE
			# dans la rainure entre deux tuiles du kit (leur dessus est biseauté
			# de deux centièmes) — « aucune route n'est collée, on voit l'écart
			# entre deux routes » (client, 12/09). Le même trou expliquait les
			# triangles sombres au bord des lacets.
			#
			# ⚠⚠ MAIS UNE CASE PLATE A SES QUATRE COINS À ELLE, PAS LES COINS
			# SOUDÉS. Soudés, le coin d'une rampe voisine tirait la nappe vers
			# le haut et elle passait PAR-DESSUS la chaussée : le lacet
			# disparaissait sous l'herbe. Une case plate reçoit donc un carré
			# plat, posé un cheveu sous la tuile, dans la couleur de son sol.
			#
			# ⚠⚠⚠ ET C'EST VRAI DE TOUTE CASE DE TERRE, PAS SEULEMENT DES
			# CASES PLATES (décision du client, 12/09 : « je ne veux pas de
			# pente lissée, on les verra plus tard »). Le maillage lissé était
			# joli et il était FAUX : sur une pente, le sol vaut une hauteur
			# différente à chaque point de la case, donc un objet posé au
			# milieu flotte d'un côté et s'enterre de l'autre. En gradins, une
			# case = un plateau = UNE hauteur : plus rien ne peut flotter. Le
			# relief se lit alors comme le diorama du kit — des plateaux nets
			# et des cassures franches, qu'on habille des falaises Kenney.
			if ville.terre(c):
				_gradin(ville, c, sommets, couleurs, indices)
				continue
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

## UN GRADIN : le plateau de la case, plus les jupes verticales qui le
## rattachent à ce qui est plus bas autour. Sans les jupes on verrait sous la
## colline — un plateau suspendu au-dessus du vide.
##
## ⚠ LA JUPE DESCEND UN PEU TROP BAS, EXPRÈS. Elle vise le dessus du voisin,
## puis s'enfonce de `ENFOUI` : à la jonction terre/mer le voisin n'est pas un
## gradin mais la nappe interpolée du fond, qui ne tombe pas exactement au même
## endroit. Un chevauchement d'un dixième d'unité ne se voit pas ; une fente
## d'un millième, si.
const ENFOUI := 0.1
## Le flanc d'un gradin est plus sombre que son dessus : c'est ce qui donne le
## relief sans avoir à calculer un éclairage par facette.
const OMBRE_DU_FLANC := 0.78

static func _gradin(ville: Ville2, c: Vector2i, sommets: PackedVector3Array,
		couleurs: PackedColorArray, indices: PackedInt32Array) -> void:
	var i := c.x
	var j := c.y
	var y := dessus(ville, c)
	# Une case plate porte une tuile du kit : la nappe passe juste dessous,
	# pour boucher la rainure sans percer la tuile.
	if ville.plate(c): y -= SOUS_LA_TUILE
	var teinte := _couleur_case(ville, c)
	var k0 := sommets.size()
	for p in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		sommets.append(Vector3((float(i) + p.x) * CASE, y, (float(j) + p.y) * CASE))
		couleurs.append(teinte)
	indices.append_array([k0, k0 + 1, k0 + 2, k0, k0 + 2, k0 + 3])
	# Les quatre côtés, dans l'ordre des coins ci-dessus : nord (0→1), est
	# (1→2), sud (2→3), ouest (3→0). Le voisin de chaque côté décide.
	var flanc := teinte * OMBRE_DU_FLANC
	flanc.a = teinte.a
	const COTES := [
		[Vector2i(0, -1), Vector2(0, 0), Vector2(1, 0)],
		[Vector2i(1, 0), Vector2(1, 0), Vector2(1, 1)],
		[Vector2i(0, 1), Vector2(1, 1), Vector2(0, 1)],
		[Vector2i(-1, 0), Vector2(0, 1), Vector2(0, 0)],
	]
	for k in COTES:
		var n: Vector2i = c + (k[0] as Vector2i)
		var bas := _pied_du_gradin(ville, n, y)
		if bas >= y - 0.001: continue
		var p0: Vector2 = k[1]
		var p1: Vector2 = k[2]
		var m0 := sommets.size()
		# ⚠ HAUT, BAS, BAS, HAUT — ET PAS HAUT, HAUT, BAS, BAS. Godot veut le
		# sens HORAIRE vu de face (même règle que le dessus, plus bas) : en
		# suivant le bord puis en descendant, on tourne dans l'autre sens et
		# toutes les jupes sortaient à l'envers. Elles étaient donc culled, on
		# voyait LA MER À TRAVERS LA COLLINE, et au fond la face intérieure du
		# mur d'en face — un coteau en lamelles flottantes. C'est exactement le
		# piège déjà payé sur le dessus de la plage, un cran plus bas.
		for t in [[p0, y], [p0, bas], [p1, bas], [p1, y]]:
			var p: Vector2 = t[0]
			sommets.append(Vector3((float(i) + p.x) * CASE, float(t[1]),
				(float(j) + p.y) * CASE))
			couleurs.append(flanc)
		indices.append_array([m0, m0 + 1, m0 + 2, m0, m0 + 2, m0 + 3])

## Jusqu'où descend la jupe de ce côté : au dessus du voisin, un doigt plus
## bas. Hors carte, on descend d'une case entière — le bord du monde est une
## falaise, pas une feuille de papier.
static func _pied_du_gradin(ville: Ville2, n: Vector2i, y: float) -> float:
	if not ville.dedans(n): return y - CASE
	if not ville.terre(n): return ville.sol(n) - ENFOUI
	return dessus(ville, n) - ENFOUI

## Les normales, accumulées par sommet. À terre les sommets ne sont PLUS
## partagés d'une case à l'autre (chaque gradin a les siens), donc chaque
## facette garde la sienne, bien nette — c'est ce qu'on veut. Le fond de la
## mer, lui, partage toujours ses coins : il reste lisse. `SurfaceTool` ferait la même chose, au
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
