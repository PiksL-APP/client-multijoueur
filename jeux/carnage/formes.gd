class_name FormesCarnage
extends RefCounted
## Les volumes de CARNAGE. Depuis la v5, TOUT est en voxels : les voitures,
## les personnages, le butin, les barrages sortent de `jeux/carnage/voxels.gd`
## en cubes colorés ; plus un seul modèle importé ne roule dans la ville.
##
## Pourquoi un fichier à part : depuis que le jeu compte des piétons, des
## gangs, des flics, des voitures de patrouille, des barrages, des cabines et
## des garages, la fabrique pesait plus lourd que la partie. Séparée, elle se
## relit sans traverser la simulation.

## Le parc automobile : dix gabarits de voitures en voxels (`VoxelsCarnage`).
## L'indice est ce qui circule sur le réseau — un joueur qui vole un taxi doit
## être vu dans un taxi par les trois autres, pas dans une berline générique.
const MODELES_VOITURES := ["berline", "berline sport", "compacte", "4x4", "4x4 de luxe",
	"taxi", "fourgon", "camion de livraison", "camion", "police",
	"coupé", "break", "pick-up", "bus", "limousine", "ambulance",
	"moto", "moto de course", "camion de pompiers"]
## Les deux-roues : ils accélèrent et tournent mieux, mais on n'a pas de tôle
## autour de soi — un choc, et on est à terre.
const MODELES_MOTOS := [16, 17]

static func est_moto(indice: int) -> bool:
	return indice in MODELES_MOTOS
const MODELE_POLICE := 9
## Ce que chaque quartier gare et fait rouler. Le centre roule en taxi, la zone
## industrielle en fourgon, la banlieue en break : c'est ce qui fait qu'on sait
## où l'on est en regardant ce qui passe.
const VOITURES_PAR_QUARTIER := {
	PlanVille.CENTRE: [0, 1, 4, 5, 5, 5, 1, 14, 13, 10, 16, 17],
	PlanVille.AFFAIRES: [0, 1, 4, 4, 5, 1, 0, 14, 13, 10, 16],
	PlanVille.COMMERCE: [0, 0, 1, 4, 5, 6, 2, 11, 13, 15, 16, 16],
	PlanVille.VIEUX: [0, 2, 2, 0, 5, 3, 6, 10, 11, 16],
	PlanVille.RESIDENCES: [0, 0, 2, 3, 6, 0, 2, 11, 12, 13, 16],
	PlanVille.INDUSTRIE: [6, 6, 7, 7, 8, 8, 3, 12, 12, 16],
	PlanVille.PORT: [7, 8, 8, 6, 3, 7, 6, 12, 17],
	PlanVille.BANLIEUE: [0, 0, 3, 3, 2, 6, 4, 11, 11, 12, 10, 17],
	PlanVille.PARC: [0, 2, 3, 13, 17],
	PlanVille.EAU: [0],
}

## Le PARC AUTOMOBILE vient maintenant du Car Kit de Kenney : dix-sept
## carrosseries dessinées à la place de nos boîtes de voxels. Ce que le kit n'a
## pas — le bus, la limousine, les deux motos — reste en voxels : mieux vaut
## deux styles voisins qu'un bus manquant.
const KENNEY_VOITURES := {
	0: "sedan", 1: "sedan-sports", 2: "hatchback-sports", 3: "suv", 4: "suv-luxury",
	5: "taxi", 6: "van", 7: "delivery", 8: "truck", 9: "police",
	10: "sedan-sports", 11: "suv", 12: "truck-flat", 15: "ambulance", 18: "firetruck",
}
const CHEMIN_VOITURES := "res://modeles/kenney/voitures/"

static func modele_kenney_de(indice: int) -> String:
	if not KENNEY_VOITURES.has(indice):
		return ""
	return CHEMIN_VOITURES + String(KENNEY_VOITURES[indice]) + ".glb"

## Les carrosseries, un maillage par gabarit, mises en cache : la nappe des
## dormantes et les nœuds des voitures qui roulent lisent le même.
static var _carrosseries: Dictionary = {}

static func maillage_voiture(indice: int) -> Mesh:
	var i: int = clamp(indice, 0, MODELES_VOITURES.size() - 1)
	if not _carrosseries.has(i):
		var chemin := modele_kenney_de(i)
		if chemin == "":
			_carrosseries[i] = VoxelsCarnage.voiture(i)
		else:
			# La longueur reste celle du gabarit : les collisions, les places de
			# stationnement et le pare-buffle s'y réfèrent.
			var gabarit: Dictionary = VoxelsCarnage.GABARITS.get(i, VoxelsCarnage.GABARITS[0])
			var longueur := float(gabarit["l"]) * VoxelsCarnage.VOXEL_VOITURE
			# ⚠ Un quart de tour dans l'AUTRE sens que le reste du kit : les
			# carrosseries du Car Kit regardent +Z quand les props regardent
			# -Z. Avec la rotation commune, toute la ville roulait en marche
			# arrière — les phares derrière, la calandre au cul.
			_carrosseries[i] = maillage_kenney(chemin, longueur, Vector3.AXIS_Z, PI * 0.5)
	return _carrosseries[i]

## Vrai si ce gabarit est dessiné par un modèle Kenney (matière texturée) et
## non par nos voxels (matière à couleurs de sommet).
static func est_kenney(indice: int) -> bool:
	return KENNEY_VOITURES.has(clampi(indice, 0, MODELES_VOITURES.size() - 1))

## Les phares d'une voiture conduite : deux flaques chaudes devant, une lueur
## rouge derrière. Au crépuscule, c'est ce qui dit dans quel sens on roule et
## ce qu'on va percuter — bien avant la silhouette.
static func phares(racine: Node3D, avant: float, arriere: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_flaque(st, Vector3(avant + 4.6, 0.05, 0.0), Vector3(6.0, 0, 0), Vector3(0, 0, 4.4), Color(1.0, 0.82, 0.55, 0.55))
	_flaque(st, Vector3(arriere - 1.2, 0.05, 0.0), Vector3(1.8, 0, 0), Vector3(0, 0, 1.9), Color(1.0, 0.15, 0.1, 0.35))
	var noeud := MeshInstance3D.new()
	noeud.mesh = st.commit()
	noeud.material_override = MatieresCarnage.flaque()
	noeud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	noeud.name = "Phares"
	racine.add_child(noeud)

## Deux VRAIS phares — des projecteurs — pour la voiture du joueur seulement :
## le mode compatibilité n'admet que huit lumières par objet, deux suffisent à
## faire surgir les façades et les passants dans le faisceau, la nuit. Le jour,
## leur énergie est à zéro (`regler_phares`).
static func projecteurs(racine: Node3D, avant: float) -> void:
	for z in [-1.1, 1.1]:
		var spot := SpotLight3D.new()
		spot.name = "ProjecteurG" if z < 0.0 else "ProjecteurD"
		spot.position = Vector3(avant, 1.1, z)
		spot.rotation_degrees = Vector3(-8.0, -90.0, 0.0)
		spot.spot_range = 46.0
		spot.spot_angle = 26.0
		spot.spot_angle_attenuation = 0.8
		spot.light_color = Color(1.0, 0.9, 0.72)
		spot.light_energy = 0.0
		spot.shadow_enabled = false
		racine.add_child(spot)

static func regler_projecteurs(racine: Node3D, nuit: float) -> void:
	for nom in ["ProjecteurG", "ProjecteurD"]:
		var spot := racine.get_node_or_null(nom) as SpotLight3D
		if spot:
			spot.light_energy = 3.2 * clampf((nuit - 0.15) / 0.5, 0.0, 1.0)
			spot.visible = spot.light_energy > 0.01

## Les étincelles d'une tôle qui racle un mur : des grains jaunes, vifs, qui
## retombent vite.
static func etincelles() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 18
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = true
	p.local_coords = false
	var grain := BoxMesh.new()
	grain.size = Vector3(0.25, 0.25, 0.25)
	p.mesh = grain
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 14.0
	p.gravity = Vector3(0, -30.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var teinte := Gradient.new()
	teinte.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
	teinte.set_color(1, Color(1.0, 0.4, 0.1, 0.0))
	p.color_ramp = teinte
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = Color(1.0, 0.7, 0.3)
	m.emission_energy_multiplier = 1.5
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

## La poussière d'un cube qui part : une bouffée de grains dans la couleur du
## mur, qui retombe. Sans elle, un cube disparaît ; avec, il s'effondre.
static func poussiere(couleur: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.9
	p.emitting = true
	p.local_coords = false
	var grain := BoxMesh.new()
	grain.size = Vector3(0.5, 0.5, 0.5)
	p.mesh = grain
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.5
	p.gravity = Vector3(0, -3.0, 0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 2.2
	var teinte := Gradient.new()
	teinte.set_color(0, Color(couleur.r, couleur.g, couleur.b, 0.7).lightened(0.2))
	teinte.set_color(1, Color(couleur.r, couleur.g, couleur.b, 0.0))
	p.color_ramp = teinte
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
static func _flaque(st: SurfaceTool, centre: Vector3, dx: Vector3, dz: Vector3, couleur: Color) -> void:
	var p := [centre - dx - dz, centre + dx - dz, centre + dx + dz, centre - dx + dz]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_color(couleur)
		st.set_uv(uvs[k])
		st.set_normal(Vector3.UP)
		st.add_vertex(p[k])

## Une nappe d'instances d'un même modèle, avec UNE COULEUR PAR INSTANCE.
##
## `Decor.nappe` teinte toute la nappe d'un bloc. Ici il faut que chaque tuile
## porte la pointe de couleur de son territoire — c'est ce qui rend une
## frontière de gang lisible au sol sans planter un panneau. Le multi-maillage
## passe la couleur d'instance au shader, et `vertex_color_use_as_albedo` la
## MULTIPLIE avec l'atlas du kit. Sans ce drapeau, la couleur est simplement
## ignorée, sans message.
static func nappe(chemin: String, transformations: Array, couleurs: Array,
		ombre: bool, teinte: Color = Color.WHITE) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = Decor.maillage(chemin)
	multi.instance_count = transformations.size()
	for i in transformations.size():
		multi.set_instance_transform(i, transformations[i])
		multi.set_instance_color(i, couleurs[i] if i < couleurs.size() else Color.WHITE)
	var noeud := MultiMeshInstance3D.new()
	noeud.multimesh = multi
	var origine := multi.mesh.surface_get_material(0)
	if origine is BaseMaterial3D:
		var copie := (origine as BaseMaterial3D).duplicate() as BaseMaterial3D
		copie.albedo_color = teinte
		copie.roughness = 0.85
		copie.vertex_color_use_as_albedo = true
		noeud.material_override = copie
	noeud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ombre \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return noeud

# ------------------------------------------------------------ les kits Kenney

## Les kits Kenney (CC0, `modeles/kenney/`) remplacent une bonne part des
## volumes fabriqués en cubes : les voitures, le mobilier de rue, les arbres.
## Un modèle glTF arrive en SCÈNE (plusieurs `MeshInstance3D`, chacun avec sa
## transformation) ; nos nappes veulent UN maillage. `maillage_kenney` les
## fusionne une fois pour toutes, met le résultat à l'échelle du jeu, l'oriente
## (l'avant des modèles Kenney regarde +Z, le jeu roule vers +X) et le pose sur
## le sol. ⚠ Les glTF de Kenney référencent leur atlas `Textures/colormap.png`
## en fichier EXTERNE, et chaque kit a le sien : copier les seuls maillages
## donne des modèles entièrement blancs, sans le moindre message d'erreur.
static var _kenney: Dictionary = {}

## ⚠ La palette du Nature Kit est celle d'un jeu de cubes pastel : son feuillage
## est TURQUOISE (0,16 / 0,79 / 0,67) et son écorce ORANGE. Posés tels quels
## dans notre ville, les arbres sortaient en étoiles turquoise. On recolore par
## NOM de matière — le modèle reste celui de Kenney, la palette est la nôtre.
const TEINTES_KENNEY := {
	"leafsGreen": Color("#4a7f36"),
	"grass": Color("#4f8b3c"),
	"woodBark": Color("#6b4a32"),
	"wood": Color("#8a6242"),
	"dirt": Color("#6b5a44"),
	"stone": Color("#a8a49c"),
	"stoneDark": Color("#8a8880"),
	"_defaultMat": Color("#4a7f36"),
}

static func maillage_kenney(chemin: String, taille_voulue: float = 0.0,
		axe: int = Vector3.AXIS_Z, tourner: float = -PI * 0.5) -> ArrayMesh:
	var cle := "%s|%.2f|%d|%.2f" % [chemin, taille_voulue, axe, tourner]
	if _kenney.has(cle):
		return _kenney[cle]
	var scene: PackedScene = load(chemin)
	if scene == null:
		push_warning("modèle Kenney introuvable : " + chemin)
		return ArrayMesh.new()
	var racine: Node3D = scene.instantiate()
	var morceaux: Array = []
	_recolter_maillages(racine, Transform3D.IDENTITY, morceaux)
	# La boîte du modèle entier, pour l'échelle et pour le poser sur le sol.
	var boite := AABB()
	var premier := true
	for m in morceaux:
		var b: AABB = (m[1] as Transform3D) * ((m[0] as Mesh).get_aabb())
		if premier:
			boite = b
			premier = false
		else:
			boite = boite.merge(b)
	var facteur := 1.0
	if taille_voulue > 0.0 and boite.size[axe] > 0.001:
		facteur = taille_voulue / boite.size[axe]
	var pose := Transform3D(Basis(Vector3.UP, tourner).scaled(Vector3.ONE * facteur), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -Vector3(boite.get_center().x, boite.position.y, boite.get_center().z))

	# ⚠ Un modèle Kenney a plusieurs MATIÈRES (le tronc et le feuillage d'un
	# arbre, la caisse et les vitres d'une voiture) et nos nappes n'en portent
	# qu'une. On fond donc tout en UNE surface en écrivant la couleur de chaque
	# matière dans la COULEUR DE SOMMET ; les modèles à atlas gardent du blanc,
	# leur texture fait le travail. Sans ça, un arbre entier prenait la couleur
	# de son feuillage et sortait en étoile turquoise.
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	var uvs := PackedVector2Array()
	var couleurs := PackedColorArray()
	var indices := PackedInt32Array()
	var texture: Texture2D = null
	for m in morceaux:
		var maillage: Mesh = m[0]
		var t: Transform3D = pose * (m[1] as Transform3D)
		for si in maillage.get_surface_count():
			var arrays: Array = maillage.surface_get_arrays(si)
			var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if pos.is_empty():
				continue
			var nor: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var matiere = maillage.surface_get_material(si)
			var teinte := Color.WHITE
			if matiere is BaseMaterial3D:
				var base := matiere as BaseMaterial3D
				var albedo := base.albedo_texture
				if albedo != null:
					if texture == null:
						texture = albedo
				else:
					teinte = TEINTES_KENNEY.get(base.resource_name, base.albedo_color)
			var decalage := sommets.size()
			for q in pos.size():
				sommets.append(t * pos[q])
				normales.append((t.basis * (nor[q] if q < nor.size() else Vector3.UP)).normalized())
				uvs.append(uv[q] if q < uv.size() else Vector2.ZERO)
				couleurs.append(teinte)
			if idx.is_empty():
				for q in pos.size():
					indices.append(decalage + q)
			else:
				for q in idx.size():
					indices.append(decalage + idx[q])
	racine.queue_free()
	var surface := []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = sommets
	surface[Mesh.ARRAY_NORMAL] = normales
	surface[Mesh.ARRAY_TEX_UV] = uvs
	surface[Mesh.ARRAY_COLOR] = couleurs
	surface[Mesh.ARRAY_INDEX] = indices
	var fondu := ArrayMesh.new()
	if not sommets.is_empty():
		fondu.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	if not _textures_source.has(chemin):
		_textures_source[chemin] = texture
	_kenney[cle] = fondu
	return fondu

static func _recolter_maillages(n: Node, jusqu_ici: Transform3D, sortie: Array) -> void:
	var ici := jusqu_ici
	if n is Node3D:
		ici = jusqu_ici * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		sortie.append([(n as MeshInstance3D).mesh, ici])
	for e in n.get_children():
		_recolter_maillages(e, ici, sortie)

## La matière d'un kit : l'atlas du kit, la couleur d'instance en teinte (une
## voiture de gang, une carrosserie repeinte), et le grain mat du reste du jeu.
static var _matieres_kenney: Dictionary = {}
static var _textures_source: Dictionary = {}   ## chemin -> l'atlas du kit (ou null)

## La matière d'un kit : son atlas s'il en a un, la couleur de sommet sinon
## (elle porte la matière d'origine de chaque morceau du modèle), et le grain
## mat du reste du jeu.
static func matiere_kenney(chemin_modele: String) -> Material:
	if _matieres_kenney.has(chemin_modele):
		return _matieres_kenney[chemin_modele]
	maillage_kenney(chemin_modele)          # remplit `_textures_source` au passage
	var texture = _textures_source.get(chemin_modele)
	var m: Material
	if texture != null:
		# Un modèle à atlas passe par le shader des kits : il sait allumer les
		# fenêtres la nuit (seulement pour les bâtiments — une voiture dont les
		# vitres brillent, ça fait un sapin de Noël).
		m = MatieresCarnage.kenney(texture, chemin_modele.contains("/batiments/") \
			or chemin_modele.contains("/pavillons/") or chemin_modele.contains("/industriel/"))
	else:
		# Pas d'atlas (le Nature Kit) : la couleur de sommet porte tout.
		var simple := StandardMaterial3D.new()
		simple.vertex_color_use_as_albedo = true
		simple.roughness = 0.9
		simple.specular = 0.15
		m = simple
	_matieres_kenney[chemin_modele] = m
	return m

## LES IMMEUBLES viennent maintenant des City Kits : commercial pour le centre
## et les affaires, industriel pour les hangars, suburban pour les pavillons.
## Chaque entrée donne le ratio hauteur/largeur du modèle : on choisit celui
## qui ressemble le plus au volume demandé par le plan, puis on l'étire pour
## qu'il remplisse exactement l'emprise. Un modèle bien choisi s'étire peu.
## ⚠ Un modèle ne se casse PAS : tant que l'immeuble est intact, on pose le
## modèle ; au premier cube arraché, il disparaît et la grille de voxels prend
## le relais (voir `MorceauVille.casser`). C'est ce qui garde la destruction.
const BATIMENTS_KENNEY := {
	PlanVille.F_TOUR: [
		["batiments/building-skyscraper-a", 2.12], ["batiments/building-skyscraper-b", 3.29],
		["batiments/building-skyscraper-c", 3.19], ["batiments/building-skyscraper-d", 4.27],
		["batiments/building-skyscraper-e", 3.16], ["batiments/building-m", 2.54],
	],
	PlanVille.F_BUREAUX: [
		["batiments/building-f", 2.01], ["batiments/building-g", 1.74],
		["batiments/building-i", 1.35], ["batiments/building-l", 1.66],
		["batiments/building-n", 1.07], ["batiments/building-skyscraper-a", 2.12],
	],
	PlanVille.F_COMMERCE: [
		["batiments/building-a", 1.47], ["batiments/building-b", 1.33],
		["batiments/building-c", 1.01], ["batiments/building-d", 1.54],
		["batiments/building-e", 0.54], ["batiments/building-h", 1.47],
		["batiments/building-j", 0.81], ["batiments/building-k", 0.71],
	],
	PlanVille.F_LOGEMENTS: [
		["batiments/building-a", 1.47], ["batiments/building-b", 1.33],
		["batiments/building-d", 1.54], ["batiments/building-h", 1.47],
		["pavillons/building-type-b", 0.62], ["pavillons/building-type-n", 0.64],
		["pavillons/building-type-s", 0.81], ["pavillons/building-type-u", 0.80],
	],
	PlanVille.F_VIEUX: [
		["batiments/building-c", 1.01], ["batiments/building-e", 0.54],
		["batiments/building-k", 0.71], ["pavillons/building-type-f", 0.80],
		["pavillons/building-type-t", 0.89], ["pavillons/building-type-o", 0.90],
	],
	PlanVille.F_HANGAR: [
		["industriel/building-a", 0.71], ["industriel/building-b", 0.71],
		["industriel/building-c", 0.66], ["industriel/building-g", 0.76],
		["industriel/building-l", 0.92], ["industriel/building-q", 0.41],
		["industriel/building-r", 0.56], ["industriel/building-s", 0.40],
		["industriel/building-t", 0.59],
	],
	PlanVille.F_MAISON: [
		["pavillons/building-type-a", 0.64], ["pavillons/building-type-c", 0.80],
		["pavillons/building-type-e", 0.88], ["pavillons/building-type-g", 0.53],
		["pavillons/building-type-h", 0.57], ["pavillons/building-type-i", 0.57],
		["pavillons/building-type-j", 0.76], ["pavillons/building-type-m", 0.52],
		["pavillons/building-type-p", 0.74], ["pavillons/building-type-q", 0.74],
	],
}

## Le modèle qui va le mieux à ce volume : même famille que le style, et le
## ratio hauteur/largeur le plus proche (la graine départage les ex æquo, pour
## que deux immeubles voisins de même taille ne soient pas jumeaux).
## Combien de modèles se disputent une emprise donnée. ⚠ Prendre le SEUL
## meilleur ratio donnait des rues entières du même immeuble : deux voisins de
## même taille — et un pâté n'en fait pas d'autres — tombaient forcément sur le
## même modèle. On garde donc les cinq plus proches et on tire dedans par
## l'identifiant : deux immeubles voisins ont des identifiants voisins, donc
## des modèles différents, et le ratio reste presque aussi bien respecté.
const CANDIDATS_BATIMENT := 5

static func batiment_kenney(style: int, largeur: float, hauteur: float, graine: int,
		eviter: String = "") -> String:
	var famille: Array = BATIMENTS_KENNEY.get(style, [])
	if famille.is_empty() or largeur <= 0.01:
		return ""
	var voulu := hauteur / largeur
	var classement: Array = []
	for fiche in famille:
		classement.append([absf(float(fiche[1]) - voulu), String(fiche[0])])
	classement.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var combien: int = mini(CANDIDATS_BATIMENT, classement.size())
	var rang := posmod(_melanger(graine), combien)
	var chemin := "res://modeles/kenney/" + String(classement[rang][1]) + ".glb"
	# Le tirage seul laisse passer des doublons — une chance sur cinq, et il en
	# suffit d'un pour qu'une rue ait l'air copiée-collée. Le morceau dit donc
	# ce qu'il vient de poser, et on prend le candidat suivant.
	if eviter != "" and chemin == eviter and combien > 1:
		chemin = "res://modeles/kenney/" + String(classement[posmod(rang + 1, combien)][1]) + ".glb"
	return chemin

## ⚠ Un identifiant d'immeuble n'est PAS un nombre au hasard : il vaut
## `(colonne × lignes + ligne) × 8 + rang`, si bien que deux immeubles voisins
## d'une même rue diffèrent d'un multiple de huit fois le nombre de lignes —
## et tombaient sur le même reste, donc sur le même modèle, tout le long du
## trottoir. On le brasse d'abord.
static func _melanger(graine: int) -> int:
	return absi(hash(graine * 2654435761 + 1013904223))

## Le maillage d'un bâtiment, ramené à une BOÎTE UNITÉ posée sur le sol :
## l'instance porte ensuite l'emprise (largeur, hauteur, profondeur) du plan.
static var _unitaires: Dictionary = {}

static func maillage_batiment(chemin: String) -> ArrayMesh:
	if _unitaires.has(chemin):
		return _unitaires[chemin]
	var brut := maillage_kenney(chemin, 1.0, Vector3.AXIS_X, 0.0)
	var arrays := brut.surface_get_arrays(0) if brut.get_surface_count() > 0 else []
	if arrays.is_empty():
		_unitaires[chemin] = brut
		return brut
	var boite := brut.get_aabb()
	var sommets: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var facteur := Vector3(1.0 / maxf(boite.size.x, 0.001), 1.0 / maxf(boite.size.y, 0.001), 1.0 / maxf(boite.size.z, 0.001))
	for i in sommets.size():
		var v := sommets[i]
		sommets[i] = Vector3((v.x - boite.get_center().x) * facteur.x, (v.y - boite.position.y) * facteur.y,
			(v.z - boite.get_center().z) * facteur.z)
	arrays[Mesh.ARRAY_VERTEX] = sommets
	var unite := ArrayMesh.new()
	unite.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_unitaires[chemin] = unite
	return unite

## LE MOBILIER DE RUE et la NATURE viennent eux aussi des kits : lampadaires,
## feux, bennes, panneaux, arbres, buissons, bancs. Chaque entrée dit le
## modèle, la hauteur voulue en unités (les modèles Kenney font moins d'un
## mètre : ils sont dessinés pour une maquette, pas pour notre échelle) et la
## rotation qui met leur face vers +X comme le reste du jeu. Ce qui n'a pas de
## modèle — la borne, les conteneurs, la fontaine, le monument — reste en
## voxels : un kit ne remplace pas tout, et on ne pose rien d'approximatif.
const PROPS_KENNEY := {
	"lampadaire": {"m": "res://modeles/kenney/urbain/light-square.glb", "h": 5.6, "r": 0.0, "c": Color("#5a5f68")},
	"lampadaire_parc": {"m": "res://modeles/kenney/urbain/light-curved.glb", "h": 4.0, "r": 0.0, "c": Color("#5a5f68")},
	"feu": {"m": "res://modeles/kenney/urbain/traffic-light.glb", "h": 4.4, "r": 0.0},
	"poubelle": {"m": "res://modeles/kenney/urbain/dumpster.glb", "h": 1.5, "r": 0.0},
	"benne": {"m": "res://modeles/kenney/urbain/dumpster.glb", "h": 2.4, "r": 0.0},
	"arbre": {"m": "res://modeles/kenney/nature/tree_default.glb", "h": 7.6, "r": 0.0},
	"arbre_petit": {"m": "res://modeles/kenney/nature/tree_oak.glb", "h": 5.2, "r": 0.0},
	"buisson": {"m": "res://modeles/kenney/nature/plant_bushDetailed.glb", "h": 1.5, "r": 0.0},
	"banc": {"m": "res://modeles/kenney/nature/bench.glb", "h": 1.3, "r": 0.0},
	"monument": {"m": "res://modeles/kenney/nature/statue_column.glb", "h": 9.0, "r": 0.0},
}

static func prop_kenney(nom: String) -> Dictionary:
	return PROPS_KENNEY.get(nom, {})

## Le maillage d'un prop, mis à la hauteur voulue (l'axe Y, pas la longueur).
static func maillage_prop(nom: String) -> ArrayMesh:
	var fiche := prop_kenney(nom)
	if fiche.is_empty():
		return ArrayMesh.new()
	return maillage_kenney(String(fiche["m"]), float(fiche["h"]), Vector3.AXIS_Y, float(fiche["r"]))

# ------------------------------------------------------------ véhicules

## Une voiture en voxels. `halo` marque celles que quelqu'un conduit — sans
## lui, dans l'ombre d'un immeuble la carrosserie devient noire et on ne se
## retrouve plus. `couleur` peint la caisse (roues et vitres restent sombres) ;
## à blanc, la peinture d'usine du gabarit. La rampe de la police vient avec le
## gabarit 9. L'avant regarde +X, comme le jeu roule.
static func voiture(couleur: Color, pseudo: String = "", halo: bool = true,
		_gyrophare: bool = false) -> Node3D:
	return voiture_kit(0, couleur if couleur != Color.WHITE else VoxelsCarnage.peinture(0, 1), couleur, pseudo, halo)

static func voiture_kit(indice: int, couleur: Color = Color.WHITE, halo_couleur: Color = Color.WHITE,
		pseudo: String = "", halo: bool = false) -> Node3D:
	var racine := Node3D.new()
	var i: int = clamp(indice, 0, MODELES_VOITURES.size() - 1)

	if halo:
		var anneau := Decor.anneau(2.7, 0.22, halo_couleur, 0.95)
		anneau.rotation_degrees = Vector3(90, 0, 0)
		anneau.position = Vector3(0, 0.04, 0)
		anneau.name = "Halo"
		racine.add_child(anneau)

	var coque := MeshInstance3D.new()
	coque.name = "Coque"
	coque.mesh = maillage_voiture(i)
	var peinture := couleur if couleur != Color.WHITE else VoxelsCarnage.peinture(i, 7)
	# Un modèle Kenney porte son atlas : la peinture le TEINTE (vitres et pneus
	# sont sombres dans l'atlas, ils le restent en multipliant). Un modèle voxel
	# garde la matière à couleurs de sommet.
	if est_kenney(i):
		var matiere: Material = matiere_kenney(modele_kenney_de(i)).duplicate()
		var teinte_v := peinture if couleur != Color.WHITE else Color.WHITE
		if matiere is ShaderMaterial:
			(matiere as ShaderMaterial).set_shader_parameter("teinte", teinte_v)
		elif matiere is BaseMaterial3D:
			(matiere as BaseMaterial3D).albedo_color = teinte_v
		coque.material_override = matiere
	else:
		coque.material_override = MatieresCarnage.voxel_teinte(peinture)
	coque.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	racine.add_child(coque)

	# Les cubes bleus et rouges d'un toit de police clignotent : on les monte
	# sous un nœud à part pour pouvoir les cacher.
	if i == MODELE_POLICE:
		var rampe := Node3D.new()
		rampe.name = "Gyrophare"
		for cote in [-1.0, 1.0]:
			var feu := Decor.boite(Vector3(0.5, 0.3, 0.5), Palette.SERIE, false)
			feu.material_override = Decor.matiere_lumineuse(Palette.SERIE if cote < 0.0 else Palette.CRITIQUE, 1.5)
			feu.position = Vector3(-0.2, 2.75, cote * 0.55)
			rampe.add_child(feu)
		racine.add_child(rampe)

	# Le pare-buffle n'apparaît qu'avec l'éperon : il devient ainsi le signe
	# visible du bonus, au lieu d'un accessoire permanent qui alourdit la
	# silhouette d'une berline.
	var longueur := float(VoxelsCarnage.GABARITS.get(i, VoxelsCarnage.GABARITS[0])["l"]) * VoxelsCarnage.VOXEL_VOITURE
	var pare_buffle := Decor.boite(Vector3(0.3, 0.85, 2.2), Palette.SERIE)
	pare_buffle.material_override = Decor.matiere_lumineuse(Palette.SERIE, 1.1)
	pare_buffle.position = Vector3(longueur * 0.5 + 0.2, 0.75, 0)
	pare_buffle.name = "Buffle"
	pare_buffle.visible = false
	racine.add_child(pare_buffle)

	phares(racine, longueur * 0.5, -longueur * 0.5)

	var jauge := Decor.barre(3.4)
	jauge.name = "Vie"
	jauge.position = Vector3(0, 3.1, 0)
	racine.add_child(jauge)

	if pseudo != "":
		var nom_j := Decor.etiquette(pseudo, Palette.ENCRE_DOUCE, 32)
		nom_j.name = "Nom"
		nom_j.position = Vector3(0, 4.4, 0)
		racine.add_child(nom_j)
	return racine

## Le tag d'un repaire : la couleur du gang peinte au sol, son initiale, et une
## couronne. C'est le repère qu'on voit de loin — et ce qu'on vise quand on
## vient nettoyer.
static func tag_de_gang(couleur: Color, nom: String) -> Node3D:
	var racine := Node3D.new()
	var dalle := Decor.cylindre(PlanVille.RAYON_REPAIRE * Decor.ECHELLE * 0.5, 0.08, couleur, false)
	dalle.material_override = Decor.matiere_lumineuse(couleur, 0.55, 0.35)
	dalle.position = Vector3(0, 0.06, 0)
	racine.add_child(dalle)
	racine.add_child(racine_anneau(PlanVille.RAYON_REPAIRE * Decor.ECHELLE, couleur, 0.14))
	var initiale := Decor.etiquette(nom.substr(0, 1).to_upper() if nom.length() > 0 else "?", couleur, 96)
	initiale.rotation_degrees = Vector3(-90, 0, 0)
	initiale.position = Vector3(0, 0.12, 0)
	racine.add_child(initiale)
	var mot := Decor.etiquette("REPAIRE — " + nom.to_upper(), couleur, 30)
	mot.position = Vector3(0, 3.6, 0)
	racine.add_child(mot)
	return racine

## Une épave : une berline noircie, penchée, avec de la braise. Elle reste au
## sol quelques secondes — une voiture qui disparaît d'un coup laisse croire à
## un défaut d'affichage.
static func epave() -> Node3D:
	var racine := Node3D.new()
	var coque := MeshInstance3D.new()
	coque.mesh = maillage_voiture(0)
	if est_kenney(0):
		var brulee: Material = matiere_kenney(modele_kenney_de(0)).duplicate()
		if brulee is ShaderMaterial:
			(brulee as ShaderMaterial).set_shader_parameter("teinte", Color("#2a2624"))
		elif brulee is BaseMaterial3D:
			(brulee as BaseMaterial3D).albedo_color = Color("#2a2624")
		coque.material_override = brulee
	else:
		coque.material_override = MatieresCarnage.voxel_teinte(Color("#141414"))
	coque.rotation_degrees = Vector3(0, 0, 6)
	racine.add_child(coque)
	var braise := Decor.sphere(0.9, Palette.SERIEUX, false)
	braise.material_override = Decor.matiere_lumineuse(Palette.SERIEUX, 1.4)
	braise.position = Vector3(0, 1.4, 0)
	braise.name = "Braise"
	racine.add_child(braise)
	return racine

# ------------------------------------------------------------ personnages

## LES HABITANTS viennent du casting partagé (`commun/personnages.gd`) : un
## seul maillage habillé du kit « Animated Characters » de Kenney, douze peaux,
## et les trois animations du kit greffées dessus (repos, course, saut). Nos
## bonshommes en cubes ne tenaient plus la comparaison depuis que les voitures
## et les immeubles sont dessinés. C'est le MÊME casting qu'à la création de
## personnage : celui qu'on choisit dans le menu, c'est celui qui marche en
## ville.
##
## L'échelle : celle du modèle, un peu réduite. Le casting est réglé pour le
## village (1,80 unité, la taille d'un homme quand la tuile en fait dix) ; en
## ville, la tuile fait le triple et une berline dix unités de long — un
## piéton d'un mètre quatre-vingt y serait un insecte.
const TAILLE_HABITANT := 0.92
## Le sommet du crâne à cette échelle : la casquette s'y pose.
const HAUT_TETE := 3.0

## Les passants ordinaires : les huit vivants du casting, pour qu'un trottoir
## ne soit pas une file de jumeaux. L'ordre compte — on tire dedans par le
## reste d'un identifiant, donc un piéton garde sa tête tant qu'il vit.
const PEAUX_CIVILES := ["humanMaleA", "humanFemaleA", "skaterMaleA", "skaterFemaleA",
	"survivorFemaleA", "survivorMaleB", "cyborgFemaleA", "criminalMaleA"]
## Les hommes de main : le truand et les deux survivants. La casquette et le
## fanion disent le gang ; la peau dit seulement « pas un passant ».
const PEAUX_GANG := ["criminalMaleA", "survivorMaleB", "survivorFemaleA"]
## Les flics à pied : la cyborg, la plus « uniforme » du lot.
const PEAU_FLIC := "cyborgFemaleA"

static var _casquette: ArrayMesh

## La peau d'un passant, tirée de son identifiant.
static func peau_civile(graine: int) -> String:
	return PEAUX_CIVILES[posmod(graine, PEAUX_CIVILES.size())]

## Une silhouette habillée, tournée pour regarder +X comme tout le reste du
## jeu. Son lecteur d'animations s'appelle « Animations » : `demarche` lui
## demande « repos » ou « course », et rien d'autre ne bouge à la main.
static func silhouette_kenney(peau: String) -> Node3D:
	var noeud := Personnages.creer(peau, TAILLE_HABITANT)
	noeud.rotation.y = PI * 0.5
	return noeud

## La démarche : on change d'animation SEULEMENT quand elle change. Rappeler
## `play` sur l'animation en cours la relance à zéro, et toute la rue piétinait
## sur place, un pas commencé et jamais fini.
static func animer_kenney(silhouette: Node3D, marche: bool, _temps: float = 0.0,
		_vitesse: float = 0.0) -> void:
	if silhouette == null:
		return
	var lecteur := silhouette.get_node_or_null("Animations") as AnimationPlayer
	if lecteur == null:
		return
	var voulue := "course" if marche else "repos"
	if lecteur.current_animation != voulue and lecteur.has_animation(voulue):
		lecteur.play(voulue)

## La CASQUETTE : une calotte plate de la couleur du gang (ou de la place du
## joueur), posée sur le crâne. Vue de dessus — et la caméra ne voit à peu près
## que ça — c'est le seul endroit du corps qui se lise. Teinter la texture
## d'une tenue teindrait aussi la peau et les cheveux.
static func maillage_casquette() -> ArrayMesh:
	if _casquette != null:
		return _casquette
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rayon := 0.58
	var haut := 0.2
	var cotes := 10
	for i in cotes:
		var a0 := TAU * float(i) / float(cotes)
		var a1 := TAU * float(i + 1) / float(cotes)
		var p0 := Vector3(cos(a0) * rayon, 0.0, sin(a0) * rayon)
		var p1 := Vector3(cos(a1) * rayon, 0.0, sin(a1) * rayon)
		for p in [Vector3(0, haut, 0), p0 + Vector3(0, haut * 0.72, 0), p1 + Vector3(0, haut * 0.72, 0)]:
			st.set_normal(Vector3.UP)
			st.add_vertex(p)
		for p in [p0, p1, p1 + Vector3(0, haut * 0.72, 0), p0, p1 + Vector3(0, haut * 0.72, 0), p0 + Vector3(0, haut * 0.72, 0)]:
			st.set_normal(Vector3(p.x, 0, p.z).normalized())
			st.add_vertex(p)
	# La visière, vers l'avant (+X).
	var v := [Vector3(rayon * 0.5, 0.03, -0.42), Vector3(rayon * 1.45, 0.03, -0.28),
		Vector3(rayon * 1.45, 0.03, 0.28), Vector3(rayon * 0.5, 0.03, 0.42)]
	for k in [0, 1, 2, 0, 2, 3, 0, 2, 1, 0, 3, 2]:
		st.set_normal(Vector3.UP)
		st.add_vertex(v[k])
	st.generate_tangents()
	_casquette = st.commit()
	return _casquette

## Un piéton, un membre de gang, un flic ou un joueur à pied. Le corps vient du
## casting, la casquette porte la couleur, le fanion distingue un homme de main
## d'un passant : la couleur seule ne suffit pas, une silhouette de trois pixels
## dans une rue sombre ne se lit pas.
static func pieton(couleur: Color, fanion: bool = false, pseudo: String = "",
		halo: bool = false, peau: String = "") -> Node3D:
	var racine := Node3D.new()
	var corps := silhouette_kenney(peau if peau != "" else PEAUX_CIVILES[0])
	corps.name = "Silhouette"
	racine.add_child(corps)

	# La casquette : seuls ceux qui portent une couleur en ont une. Un passant
	# reste tête nue — c'est ce qui rend les autres repérables.
	if fanion or halo:
		var calotte := MeshInstance3D.new()
		calotte.mesh = maillage_casquette()
		calotte.material_override = MatieresCarnage.voxel_teinte(couleur)
		calotte.position = Vector3(0, HAUT_TETE, 0)
		calotte.name = "Casquette"
		racine.add_child(calotte)

	if halo:
		var anneau := Decor.anneau(1.5, 0.16, couleur, 0.95)
		anneau.rotation_degrees = Vector3(90, 0, 0)
		anneau.position = Vector3(0, 0.05, 0)
		anneau.name = "Halo"
		racine.add_child(anneau)

	if fanion:
		# Le fanion se dresse AU-DESSUS du crâne : planté à hauteur d'épaule,
		# il passait devant le visage et la rue devenait illisible.
		var hampe := Decor.boite(Vector3(0.08, 0.9, 0.08), Palette.ENCRE_FAIBLE, false)
		hampe.position = Vector3(-0.34, 3.7, 0)
		racine.add_child(hampe)
		var etoffe := Decor.boite(Vector3(0.06, 0.34, 0.5), couleur, false)
		etoffe.material_override = Decor.matiere_lumineuse(couleur, 1.0)
		etoffe.position = Vector3(-0.34, 4.0, 0.25)
		racine.add_child(etoffe)

	var jauge := Decor.barre(1.6)
	jauge.name = "Vie"
	jauge.position = Vector3(0, 3.9, 0)
	racine.add_child(jauge)

	if pseudo != "":
		var nom := Decor.etiquette(pseudo, Palette.ENCRE_DOUCE, 28)
		nom.name = "Nom"
		nom.position = Vector3(0, 4.9, 0)
		racine.add_child(nom)
	return racine

# ------------------------------------------------------------ les lieux

## Le sol d'un garage de peinture : une dalle lumineuse sous la façade. Sans
## marque au sol, une porte de garage dans laquelle on peut entrer ressemble à
## un mur — et on ne l'essaie jamais.
static func dalle_garage() -> Node3D:
	var racine := Node3D.new()
	var dalle := Decor.cylindre(PlanVille.RAYON_GARAGE * Decor.ECHELLE, 0.1, Palette.SERIE, false)
	dalle.material_override = Decor.matiere_lumineuse(Palette.SERIE, 0.5, 0.42)
	dalle.position = Vector3(0, 0.06, 0)
	racine.add_child(racine_anneau(PlanVille.RAYON_GARAGE * Decor.ECHELLE, Palette.SERIE, 0.16))
	racine.add_child(dalle)
	var enseigne := Decor.etiquette("PEINTURE", Palette.SERIE, 30)
	enseigne.position = Vector3(0, 3.2, 0)
	racine.add_child(enseigne)
	return racine

## L'HÔPITAL : une dalle blanche, une croix rouge posée à plat (on la voit de
## la caméra) et l'enseigne. On y est recousu contre argent, et c'est là qu'on
## rouvre les yeux quand on tombe.
static func dalle_hopital() -> Node3D:
	var racine := Node3D.new()
	var rayon := PlanVille.RAYON_HOPITAL * Decor.ECHELLE
	racine.add_child(racine_anneau(rayon, Color("#e8f0f4"), 0.2))
	var dalle := Decor.cylindre(rayon, 0.1, Color("#e8f0f4"), false)
	dalle.material_override = Decor.matiere_lumineuse(Color("#e8f0f4"), 0.35, 0.4)
	dalle.position = Vector3(0, 0.05, 0)
	racine.add_child(dalle)
	# La croix, en cubes couchés : deux barres qui se croisent.
	var croix: Array = []
	for d in range(-2, 3):
		croix.append([Vector3(float(d) * 0.62, 0.14, 0.0), 0.6, Color(0.85, 0.12, 0.12, VoxelsCarnage.LUMIERE)])
		if d != 0:
			croix.append([Vector3(0.0, 0.14, float(d) * 0.62), 0.6, Color(0.85, 0.12, 0.12, VoxelsCarnage.LUMIERE)])
	racine.add_child(cubes(croix))
	var mot := Decor.etiquette("HÔPITAL", Color("#f4a0a0"), 30)
	mot.position = Vector3(0, 3.2, 0)
	racine.add_child(mot)
	return racine

## La PLANQUE : le pas de porte de la maison qu'on peut acheter. Un tapis, une
## porte lumineuse, et l'écriteau qui dit le prix — ou le nom du propriétaire.
static func porte_planque(prix: int) -> Node3D:
	var racine := Node3D.new()
	var rayon := PlanVille.RAYON_PLANQUE * Decor.ECHELLE
	var couleur := Color("#b070d0")
	racine.add_child(racine_anneau(rayon, couleur, 0.18))
	var tapis := Decor.cylindre(rayon, 0.1, couleur, false)
	tapis.material_override = Decor.matiere_lumineuse(couleur, 0.3, 0.35)
	tapis.position = Vector3(0, 0.05, 0)
	racine.add_child(tapis)
	var porte := cubes([[Vector3(0, 0.9, 0), 1.8, Color(couleur.darkened(0.45), VoxelsCarnage.MUR)],
		[Vector3(0, 2.0, 0), 1.0, Color(couleur, VoxelsCarnage.LUMIERE)]])
	racine.add_child(porte)
	var mot := Decor.etiquette("À VENDRE  $%d" % prix, couleur, 28)
	mot.name = "Mot"
	mot.position = Vector3(0, 3.4, 0)
	racine.add_child(mot)
	return racine

## L'enceinte d'une arène : un anneau au sol, quatre bornes, et le mot. Le tir
## ami s'y allume — il faut donc qu'on sache qu'on y entre AVANT d'y être.
static func cercle_arene(numero: int) -> Node3D:
	var racine := Node3D.new()
	var rayon := PlanVille.RAYON_ARENE * Decor.ECHELLE
	racine.add_child(racine_anneau(rayon, Palette.CRITIQUE, 0.34))
	racine.add_child(racine_anneau(rayon * 0.62, Palette.CRITIQUE, 0.14))
	for i in 4:
		var angle := TAU * float(i) / 4.0 + PI * 0.25
		var borne := cubes([[Vector3(0, 0.6, 0), 1.2, Color(Palette.CRITIQUE.darkened(0.3), VoxelsCarnage.MUR)],
			[Vector3(0, 1.6, 0), 0.8, Color(Palette.CRITIQUE, VoxelsCarnage.LUMIERE)]])
		borne.position = Vector3(cos(angle) * rayon, 0.0, sin(angle) * rayon)
		racine.add_child(borne)
	var mot := Decor.etiquette("ARÈNE %d — TIR AMI" % (numero + 1), Palette.CRITIQUE, 34)
	mot.position = Vector3(0, 4.0, 0)
	racine.add_child(mot)
	return racine

## Une cabine : un caisson, une antenne, un halo. Elle sonne quand un contrat
## attend — c'est le halo qui clignote, pas la cabine qui bouge : un objet qui
## se déplace en ville se prend pour une cible.
static func cabine(numero: int) -> Node3D:
	var racine := Node3D.new()
	var caisson := Decor.boite(Vector3(1.1, 2.4, 1.1), Palette.SURFACE.lightened(0.1))
	caisson.position = Vector3(0, 1.2, 0)
	racine.add_child(caisson)
	var vitre := Decor.boite(Vector3(0.9, 1.1, 0.9), Palette.SERIE, false)
	vitre.material_override = Decor.matiere_voile(Palette.SERIE, 0.4)
	vitre.position = Vector3(0, 1.7, 0)
	racine.add_child(vitre)
	# L'ENSEIGNE dit d'un coup d'œil ce que le gang du quartier pense de vous :
	# verte il vous embauche, jaune il tolère, rouge il vous tire dessus. C'est
	# ce qui rend la jauge de respect lisible depuis la rue.
	var enseigne := Decor.boite(Vector3(1.3, 0.34, 1.3), Palette.AVERTISSEMENT, false)
	enseigne.material_override = Decor.matiere_lumineuse(Palette.AVERTISSEMENT, 1.4)
	enseigne.position = Vector3(0, 2.6, 0)
	enseigne.name = "Enseigne"
	racine.add_child(enseigne)
	var halo := Decor.anneau(PlanVille.RAYON_CABINE * Decor.ECHELLE, 0.14, Palette.AVERTISSEMENT, 1.0)
	halo.rotation_degrees = Vector3(90, 0, 0)
	halo.position = Vector3(0, 0.06, 0)
	halo.name = "Halo"
	racine.add_child(halo)
	var mot := Decor.etiquette("CONTRAT %d" % (numero + 1), Palette.AVERTISSEMENT, 26)
	mot.name = "Mot"
	mot.position = Vector3(0, 3.4, 0)
	racine.add_child(mot)
	return racine

## Un barrage de police : deux blocs en travers de la rue. Ils bloquent pour de
## vrai — c'est le seul obstacle du jeu que la police ajoute, et il doit se
## contourner, pas se traverser.
static func barrage() -> Node3D:
	var racine := Node3D.new()
	for cote in [-1.0, 1.0]:
		var liste: Array = []
		for x in 2:
			for y in 2:
				for z in 3:
					liste.append([Vector3(x - 0.5, 0.5 + y, (z - 1.0)), 1.0,
						Color(Palette.SERIE.lerp(Color.WHITE, 0.5) if (x + y + z) % 2 == 0 else Palette.SERIE, VoxelsCarnage.MUR)])
		var bloc := cubes(liste)
		bloc.position = Vector3(0, 0, cote * 2.6)
		racine.add_child(bloc)
	var gyro := Decor.sphere(0.4, Palette.SERIE, false)
	gyro.material_override = Decor.matiere_lumineuse(Palette.SERIE, 1.6)
	gyro.position = Vector3(0, 2.4, 0)
	gyro.name = "Gyro"
	racine.add_child(gyro)
	return racine

## L'hélicoptère de la police : une cellule, une queue, un rotor qui tourne et un
## projecteur au sol. Le projecteur est ce qui compte : c'est lui qu'on voit
## arriver de loin sur la chaussée, avant même d'entendre les pales.
static func helico() -> Node3D:
	var racine := Node3D.new()
	var corps := Node3D.new()
	corps.name = "Cellule"
	corps.position = Vector3(0, 26.0, 0)
	var cellule := Decor.boite(Vector3(3.6, 1.6, 1.8), Palette.SERIE.darkened(0.55))
	cellule.position = Vector3(0, 0, 0)
	corps.add_child(cellule)
	var queue := Decor.boite(Vector3(3.4, 0.5, 0.5), Palette.SERIE.darkened(0.55))
	queue.position = Vector3(-3.2, 0.3, 0)
	corps.add_child(queue)
	var rotor := Node3D.new()
	rotor.name = "Rotor"
	rotor.position = Vector3(0, 1.1, 0)
	for i in 2:
		var pale := Decor.boite(Vector3(7.0, 0.08, 0.4), Palette.ENCRE_FAIBLE, false)
		pale.rotation.y = PI * 0.5 * float(i)
		rotor.add_child(pale)
	corps.add_child(rotor)
	var feu := Decor.sphere(0.35, Palette.SERIE, false)
	feu.material_override = Decor.matiere_lumineuse(Palette.SERIE, 1.6)
	feu.position = Vector3(0, -0.9, 0)
	feu.name = "Feu"
	corps.add_child(feu)
	racine.add_child(corps)

	# Le faisceau : un cône de voile du ciel au sol, et une flaque de lumière.
	var faisceau := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.6
	cone.bottom_radius = 7.0
	cone.height = 26.0
	faisceau.mesh = cone
	faisceau.material_override = Decor.matiere_voile(Palette.ENCRE, 0.09)
	faisceau.position = Vector3(0, 13.0, 0)
	faisceau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	racine.add_child(faisceau)
	var flaque := Decor.cylindre(7.0, 0.06, Palette.ENCRE, false)
	flaque.material_override = Decor.matiere_lumineuse(Palette.ENCRE, 0.5, 0.35)
	flaque.position = Vector3(0, 0.08, 0)
	racine.add_child(flaque)
	return racine

## Une caisse d'arme : un socle lumineux au sol, l'objet qui flotte au-dessus.
## C'est la grammaire habituelle du ramassage, et elle se repère de loin dans
## une rue encombrée là où une caisse posée se confond avec le mobilier.
static func caisse(arme: String, couleur: Color) -> Node3D:
	var racine := Node3D.new()
	var socle := Decor.cylindre(1.9, 0.12, couleur, false)
	socle.material_override = Decor.matiere_lumineuse(couleur, 0.75, 0.5)
	socle.position = Vector3(0, 0.08, 0)
	racine.add_child(socle)
	racine.add_child(racine_anneau(2.1, couleur, 0.16))

	# L'objet : un cube lumineux de la couleur du butin, et un second plus
	# sombre en son cœur — une caisse, pas une balle.
	var objet := cubes([[Vector3.ZERO, 1.3, Color(couleur.darkened(0.35), VoxelsCarnage.MUR)],
		[Vector3.ZERO, 0.9, Color(couleur.lerp(Color.WHITE, 0.2), VoxelsCarnage.LUMIERE)],
		[Vector3(0, 0.75, 0), 0.5, Color(couleur, VoxelsCarnage.LUMIERE)]])
	objet.name = "Objet"
	objet.position = Vector3(0, 1.6, 0)
	racine.add_child(objet)
	return racine

## Un petit maillage de cubes : [centre, côté, couleur] chacun, en un nœud.
static func cubes(liste: Array) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cube in liste:
		VoxelsCarnage._cube(st, cube[0], float(cube[1]), cube[2])
	var noeud := MeshInstance3D.new()
	noeud.mesh = st.commit()
	noeud.material_override = MatieresCarnage.voxel()
	return noeud

## La fumée d'un pot d'échappement, ou d'un moteur qui souffre : un émetteur
## de particules processeur, ce que le mode compatibilité fait de mieux. Il ne
## tourne que quand on accélère — un panache permanent cache la voiture.
static func echappement(arriere: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Fumee"
	p.amount = 22
	p.lifetime = 0.9
	p.emitting = false
	p.local_coords = false
	var grain := SphereMesh.new()
	grain.radius = 0.22
	grain.height = 0.44
	grain.radial_segments = 6
	grain.rings = 3
	p.mesh = grain
	p.direction = Vector3(-1.0, 0.5, 0.0)
	p.spread = 22.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, 1.4, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	var teinte := Gradient.new()
	teinte.set_color(0, Color(0.8, 0.8, 0.82, 0.45))
	teinte.set_color(1, Color(0.6, 0.6, 0.64, 0.0))
	p.color_ramp = teinte
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = Vector3(arriere, 0.45, 0.6)
	return p

## Une explosion : une bouffée de feu qui vire au noir, tirée d'un coup. Le
## nœud se détruit tout seul à la fin de sa vie.
static func explosion() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 46
	p.lifetime = 1.3
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = true
	p.local_coords = false
	# Des cubes, pas des boules : une explosion en voxels dans une ville en voxels.
	var grain := BoxMesh.new()
	grain.size = Vector3(0.9, 0.9, 0.9)
	p.mesh = grain
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 16.0
	p.gravity = Vector3(0, -5.0, 0)
	p.damping_min = 3.0
	p.damping_max = 5.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.6
	var teinte := Gradient.new()
	teinte.add_point(0.0, Color(1.0, 0.85, 0.5, 1.0))
	teinte.set_color(1, Color(1.0, 0.45, 0.15, 0.95))
	teinte.add_point(0.45, Color(0.25, 0.22, 0.2, 0.8))
	teinte.add_point(1.0, Color(0.1, 0.1, 0.1, 0.0))
	p.color_ramp = teinte
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

## UN BRASIER : ce qu'on voit d'un incendie, réglé pour une caméra presque à
## la VERTICALE — c'est tout le problème du feu vu de dessus. Une colonne de
## fumée qui monte droit masque le quartier et rien d'autre ne se lit ; un
## brasier lisible d'en haut, c'est un cœur orange au sol qui bat, des langues
## courtes qui lèchent autour, et un filet de fumée qui part EN BIAIS pour
## sortir du champ au lieu de faire un couvercle.
static func brasier() -> Node3D:
	var racine := Node3D.new()

	# Le CŒUR : quatre cubes émissifs posés au sol, animés par `regler_brasier`.
	# En plein jour, des particules additives ne se voient pas ; ça, si.
	var coeur := Node3D.new()
	coeur.name = "Coeur"
	for i in 4:
		var braise := Decor.boite(Vector3(1.5, 0.9, 1.5), Color(1.0, 0.55, 0.12), false)
		braise.material_override = Decor.matiere_lumineuse(Color(1.0, 0.52 - 0.1 * float(i % 2), 0.12), 2.2)
		braise.position = Vector3(cos(TAU * float(i) / 4.0) * 1.1, 0.5, sin(TAU * float(i) / 4.0) * 1.1)
		braise.name = "Braise%d" % i
		coeur.add_child(braise)
	racine.add_child(coeur)

	var flammes := CPUParticles3D.new()
	flammes.name = "Flammes"
	flammes.amount = 22
	flammes.lifetime = 0.6
	flammes.local_coords = false
	var grain := BoxMesh.new()
	grain.size = Vector3(0.7, 0.7, 0.7)
	flammes.mesh = grain
	flammes.direction = Vector3(0, 1, 0)
	flammes.spread = 34.0
	flammes.initial_velocity_min = 2.0
	flammes.initial_velocity_max = 4.5
	flammes.gravity = Vector3(0, 0.8, 0)
	flammes.damping_min = 2.0
	flammes.damping_max = 4.0
	flammes.scale_amount_min = 0.5
	flammes.scale_amount_max = 1.3
	flammes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	flammes.emission_sphere_radius = 1.2
	var chaud := Gradient.new()
	chaud.add_point(0.0, Color(1.0, 0.95, 0.62, 1.0))
	chaud.set_color(1, Color(1.0, 0.5, 0.1, 0.95))
	chaud.add_point(0.6, Color(0.95, 0.28, 0.07, 0.75))
	chaud.add_point(1.0, Color(0.4, 0.14, 0.06, 0.0))
	flammes.color_ramp = chaud
	var mf := StandardMaterial3D.new()
	mf.vertex_color_use_as_albedo = true
	mf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flammes.material_override = mf
	flammes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	racine.add_child(flammes)

	# La fumée : peu nombreuse, translucide, et surtout COUCHÉE — elle file sur
	# le côté comme sous le vent, et le joueur voit toujours sa rue.
	var fumee := CPUParticles3D.new()
	fumee.name = "Fumee"
	fumee.amount = 18
	fumee.lifetime = 1.9
	fumee.local_coords = false
	var bouffee := BoxMesh.new()
	bouffee.size = Vector3(0.6, 0.6, 0.6)
	fumee.mesh = bouffee
	fumee.direction = Vector3(0.9, 0.9, 0.35)
	fumee.spread = 12.0
	fumee.initial_velocity_min = 4.0
	fumee.initial_velocity_max = 7.0
	fumee.gravity = Vector3(3.2, 1.4, 1.2)
	fumee.scale_amount_min = 0.6
	fumee.scale_amount_max = 1.6
	fumee.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	fumee.emission_sphere_radius = 1.0
	# ⚠ La rampe d'un CPUParticles MULTIPLIE la couleur de base : une rampe
	# sombre sur une base blanche ne suffisait pas — la fumée sortait blanche.
	# On peint la suie dans `color` et la rampe ne fait plus que l'alpha.
	fumee.color = Color(0.13, 0.12, 0.12)
	var suie := Gradient.new()
	suie.set_color(0, Color(1, 1, 1, 0.55))
	suie.set_color(1, Color(1, 1, 1, 0.0))
	fumee.color_ramp = suie
	var ms := StandardMaterial3D.new()
	ms.vertex_color_use_as_albedo = true
	ms.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ms.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fumee.material_override = ms
	fumee.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	racine.add_child(fumee)

	# La lueur au sol : le même quadrilatère additif que les lampadaires.
	var lueur := MeshInstance3D.new()
	lueur.name = "Lueur"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_flaque(st, Vector3(0, 0.05, 0), Vector3(5.0, 0, 0), Vector3(0, 0, 5.0), Color(1.0, 0.5, 0.16, 0.9))
	st.generate_normals()
	lueur.mesh = st.commit()
	lueur.material_override = MatieresCarnage.flaque()
	lueur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	racine.add_child(lueur)
	return racine

## La force du foyer, de 0 à 1 : le cœur bat, les flammes et la fumée suivent.
## ⚠ `amount_ratio` n'existe que sur les GPUParticles : sur des CPUParticles on
## module la TAILLE et la durée de vie, jamais le nombre (le changer réalloue
## tout le tableau à chaque image).
static func regler_brasier(brasier_noeud: Node3D, force: float, temps: float) -> void:
	var f: float = clampf(force, 0.0, 1.0)
	var coeur := brasier_noeud.get_node_or_null("Coeur") as Node3D
	if coeur != null:
		coeur.visible = f > 0.05
		for i in coeur.get_child_count():
			var braise := coeur.get_child(i) as Node3D
			# Chaque braise bat à son rythme : un feu régulier est un décor.
			var bat: float = 0.62 + 0.38 * sin(temps * (5.0 + 1.7 * float(i)) + float(i) * 2.1)
			var e: float = (0.45 + 0.85 * f) * bat
			braise.scale = Vector3(e, e * (0.7 + 0.7 * bat), e)
			braise.rotation.y = temps * (0.7 + 0.3 * float(i))
	var flammes := brasier_noeud.get_node_or_null("Flammes") as CPUParticles3D
	if flammes != null:
		flammes.emitting = f > 0.08
		flammes.scale_amount_min = 0.3 + 0.4 * f
		flammes.scale_amount_max = 0.7 + 1.1 * f
		flammes.lifetime = 0.4 + 0.35 * f
	var fumee := brasier_noeud.get_node_or_null("Fumee") as CPUParticles3D
	if fumee != null:
		fumee.emitting = f > 0.05
		fumee.scale_amount_min = 0.4 + 0.4 * f
		fumee.scale_amount_max = 1.0 + 1.0 * f
	var lueur := brasier_noeud.get_node_or_null("Lueur") as Node3D
	if lueur != null:
		# Le vacillement : la flaque respire, sinon la lueur est une décalcomanie.
		var vacille: float = 0.86 + 0.14 * sin(temps * 7.3) + 0.06 * sin(temps * 3.1)
		var echelle: float = (0.5 + 1.1 * f) * vacille
		lueur.scale = Vector3(echelle, 1.0, echelle)

## Un anneau posé à plat. Répété six fois dans ce fichier avant d'être extrait :
## la rotation de 90° s'oublie une fois sur deux et l'anneau part debout.
static func racine_anneau(rayon: float, couleur: Color, epaisseur: float) -> MeshInstance3D:
	var anneau := Decor.anneau(rayon, epaisseur, couleur, 1.0)
	anneau.rotation_degrees = Vector3(90, 0, 0)
	anneau.position = Vector3(0, 0.05, 0)
	return anneau
