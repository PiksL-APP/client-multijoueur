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

## LES PEINTURES DU GARAGE (§1.3). Le garage effaçait le casier et rendait la
## voiture telle quelle : GTA 2 la REPEINT, et c'est ce qui fait qu'une voiture
## qui sort du garage n'est plus celle que la police cherchait — la mécanique
## et l'image racontent enfin la même chose.
##
## ⚠ AUCUNE COULEUR DE GANG dans cette liste. Une voiture repeinte aux couleurs
## des Braises serait prise pour une voiture des Braises — par les joueurs, qui
## apprennent à les reconnaître, et bientôt par eux-mêmes qui se demanderaient
## pourquoi on ne la vole pas. Les bannières sont réservées.
const PEINTURES := [
	Color("#e8e4d8"), Color("#2b2b2f"), Color("#b8322a"), Color("#274e8a"),
	Color("#e2a72e"), Color("#5c8a3e"), Color("#7a4a8e"), Color("#d96a2a"),
	Color("#3e9c8c"), Color("#8b6a4a"),
]

static func peinture_au_hasard(rng: RandomNumberGenerator, sauf: Color) -> Color:
	# Jamais deux fois la même à la suite : un garage qui rend la voiture de
	# la même couleur qu'à l'entrée, c'est un garage qui n'a rien fait.
	for _essai in 8:
		var c: Color = PEINTURES[rng.randi_range(0, PEINTURES.size() - 1)]
		if not c.is_equal_approx(sauf):
			return c
	return PEINTURES[0]

## Le parc automobile : dix gabarits de voitures en voxels (`VoxelsCarnage`).
## L'indice est ce qui circule sur le réseau — un joueur qui vole un taxi doit
## être vu dans un taxi par les trois autres, pas dans une berline générique.
const MODELES_VOITURES := ["berline", "berline sport", "compacte", "4x4", "4x4 de luxe",
	"taxi", "fourgon", "camion de livraison", "camion", "police",
	"coupé", "break", "pick-up", "bus", "limousine", "ambulance",
	"moto", "moto de course", "camion de pompiers",
	# Le reste du Car Kit, longtemps resté dans le dossier faute d'indice : la
	# voiture de course, le tracteur, la benne à ordures et le plateau. Quatre
	# carrosseries dessinées qui ne roulaient nulle part.
	"voiture de course", "tracteur", "benne à ordures", "plateau de livraison",
	# LA FLOTTE. Un bateau est un véhicule comme un autre — même indice sur le
	# réseau, même `E` pour monter, même identifiant de dormante — mais il ne
	# roule que sur l'eau, et la ville ne l'amarre qu'au bord d'un quai.
	"chaloupe", "vedette", "vedette rapide", "barque de pêche", "remorqueur"]
## Les deux-roues : ils accélèrent et tournent mieux, mais on n'a pas de tôle
## autour de soi — un choc, et on est à terre.
const MODELES_MOTOS := [16, 17]

static func est_moto(indice: int) -> bool:
	return indice in MODELES_MOTOS
const MODELE_POLICE := 9
## Le taxi. C'est LUI qui ouvre les courses (guide §4.3) : un métier attaché à
## une carrosserie, pas un menu — on devient chauffeur en volant un taxi.
const MODELE_TAXI := 5
## Ce que chaque quartier gare et fait rouler. Le centre roule en taxi, la zone
## industrielle en fourgon, la banlieue en break : c'est ce qui fait qu'on sait
## où l'on est en regardant ce qui passe.
const VOITURES_PAR_QUARTIER := {
	PlanVille.CENTRE: [0, 1, 4, 5, 5, 5, 1, 14, 13, 10, 16, 17, 19],
	PlanVille.AFFAIRES: [0, 1, 4, 4, 5, 1, 0, 14, 13, 10, 16, 19],
	PlanVille.COMMERCE: [0, 0, 1, 4, 5, 6, 2, 11, 13, 15, 16, 16, 21],
	PlanVille.VIEUX: [0, 2, 2, 0, 5, 3, 6, 10, 11, 16, 21],
	PlanVille.RESIDENCES: [0, 0, 2, 3, 6, 0, 2, 11, 12, 13, 16, 21],
	PlanVille.INDUSTRIE: [6, 6, 7, 7, 8, 8, 3, 12, 12, 16, 21, 22, 22],
	PlanVille.PORT: [7, 8, 8, 6, 3, 7, 6, 12, 17, 22, 22],
	PlanVille.BANLIEUE: [0, 0, 3, 3, 2, 6, 4, 11, 11, 12, 10, 17, 20, 21],
	# Le tracteur ne se gare pas au centre-ville : il vit au parc et au bout de
	# la banlieue, et c'est ce qui le rend drôle à trouver.
	PlanVille.PARC: [0, 2, 3, 13, 17, 20, 20],
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
	19: "race", 20: "tractor", 21: "garbage-truck", 22: "delivery-flat",
}
const CHEMIN_VOITURES := "res://modeles/kenney/voitures/"

## Les coques du Watercraft Pack, dans le même espace d'indices que les
## carrosseries : c'est ce qui fait qu'un bateau traverse le réseau, la nappe
## du morceau et le vol de véhicule SANS UNE LIGNE de code en plus.
const KENNEY_BATEAUX := {
	23: "boat-row-large", 24: "boat-speed-a", 25: "boat-speed-c",
	26: "boat-fishing-small", 27: "boat-tug-a",
}
const CHEMIN_BATEAUX := "res://modeles/kenney/bateaux/"
## Ce qui s'amarre au bord d'un quai. La chaloupe et les vedettes partout, le
## remorqueur et la barque plus rarement : un port où chaque anneau porte un
## remorqueur ne ressemble pas à un port.
const FLOTTE_AMARREE := [23, 24, 24, 25, 25, 26, 23, 27]

static func est_bateau(indice: int) -> bool:
	return KENNEY_BATEAUX.has(indice)

static func modele_kenney_de(indice: int) -> String:
	if KENNEY_BATEAUX.has(indice):
		return CHEMIN_BATEAUX + String(KENNEY_BATEAUX[indice]) + ".glb"
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
	var i := clampi(indice, 0, MODELES_VOITURES.size() - 1)
	return KENNEY_VOITURES.has(i) or KENNEY_BATEAUX.has(i)

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
	# LE FAISCEAU : un coin de lumière qui part des phares, à hauteur de
	# calandre, et retombe vers le sol en s'élargissant. Il tient au même nœud
	# que la tache au sol, pour s'éteindre avec elle quand la voiture est garée.
	# ⚠ Enfant de « Phares » et pas frère : `_placer_les_autos` allume et
	# éteint « Phares » par son nom, et un frère serait resté allumé au parking.
	var fs := SurfaceTool.new()
	fs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var teinte := Color(1.0, 0.86, 0.6, 0.42)
	var pres := [Vector3(avant + 0.2, 0.9, -1.7), Vector3(avant + 0.2, 0.9, 1.7)]
	var loin := [Vector3(avant + 15.0, 0.15, -5.2), Vector3(avant + 15.0, 0.15, 5.2)]
	var sommets := [pres[0], pres[1], loin[1], pres[0], loin[1], loin[0]]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]
	for k in sommets.size():
		fs.set_color(teinte)
		fs.set_uv(uvs[k])
		fs.set_normal(Vector3.UP)
		fs.add_vertex(sommets[k])
	var faisceau := MeshInstance3D.new()
	faisceau.mesh = fs.commit()
	faisceau.material_override = MatieresCarnage.faisceau()
	faisceau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	faisceau.name = "Faisceau"
	noeud.add_child(faisceau)

## LE GYROPHARE TOURNE : bleu puis rouge, quatre fois par seconde, feu du toit
## et lueur au sol ensemble. `allume` à faux (voiture garée) : les deux feux
## restent allumés fixes et les lueurs s'éteignent — une patrouille au parking
## n'est pas en poursuite.
static func clignoter_gyrophare(racine: Node3D, temps: float, allume: bool) -> void:
	var rampe := racine.get_node_or_null("Gyrophare") as Node3D
	if rampe == null:
		return
	var bleu := fmod(temps, 0.5) < 0.25
	for nom: String in ["Bleu", "Rouge", "LueurBleue", "LueurRouge"]:
		var feu := rampe.get_node_or_null(nom) as Node3D
		if feu == null:
			continue
		var est_bleu: bool = nom.contains("Bleu")
		var lueur: bool = nom.begins_with("Lueur")
		feu.visible = (est_bleu == bleu) if allume else not lueur

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
			# ⚠ UN MODÈLE VOXEL PORTE SA COULEUR AU SOMMET, PAS DANS SA MATIÈRE.
			# Les arbres, pins et rochers de `modeles/voxel/` sortent de
			# MagicaVoxel : une seule matière blanche, et toute la palette
			# dans `COLOR_0`. Ne lire que l'albédo de la matière les faisait
			# tous sortir BLANCS — une crête de pins en sucre. Si la surface a
			# ses couleurs, on les garde, teintées par la matière.
			var src_col: PackedColorArray = arrays[Mesh.ARRAY_COLOR] \
				if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var decalage := sommets.size()
			for q in pos.size():
				sommets.append(t * pos[q])
				normales.append((t.basis * (nor[q] if q < nor.size() else Vector3.UP)).normalized())
				uvs.append(uv[q] if q < uv.size() else Vector2.ZERO)
				couleurs.append(teinte * src_col[q] if q < src_col.size() else teinte)
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
			or chemin_modele.contains("/pavillons/") or chemin_modele.contains("/industriel/"),
			chemin_modele.contains("/voitures/") or chemin_modele.contains("/bateaux/"))
	else:
		# Pas d'atlas (le Nature Kit) : la couleur de sommet porte tout.
		var simple := StandardMaterial3D.new()
		simple.vertex_color_use_as_albedo = true
		simple.roughness = 0.9
		simple.specular = 0.15
		m = simple
	_matieres_kenney[chemin_modele] = m
	return m

## LA COULEUR D'UNE VOITURE, UNE FOIS POUR TOUTES. La nappe des dormantes, le
## trafic qui roule, la voiture qu'on vole et celle qu'on rend passent tous
## ici. La peinture du garage d'abord (elle voyage sur le réseau, `teinte`) ;
## la bannière d'un gang ensuite ; sinon la couleur tirée de l'IDENTIFIANT —
## la même que la nappe a peinte, pour que la voiture qu'on prend soit celle
## qu'on regardait. Le blanc veut dire « livrée d'usine » (taxi, police).
static func couleur_de_l_auto(carte: PlanVille, modele: int, id: int, de_gang: bool,
		gang: int, teinte: int) -> Color:
	if teinte != 0:
		return Color.hex(teinte)
	if de_gang:
		return carte.couleur_du_gang(gang)
	# La voiture de départ d'un joueur (modèle -1) n'a pas de couleur à elle :
	# blanc, et c'est la couleur du joueur qui la peint (`_batir_voiture_de`).
	if modele < 0:
		return Color.WHITE
	return VoxelsCarnage.peinture(modele, id)

## Une matière par (modèle, peinture), partagée : dix peintures de trafic,
## dix du garage, sept de gang — et pas un duplicata par voiture. Le blanc
## rend la matière du kit telle quelle (couleur d'usine).
static var _matieres_peintes: Dictionary = {}

static func matiere_peinte(chemin_modele: String, couleur: Color) -> Material:
	if couleur == Color.WHITE:
		return matiere_kenney(chemin_modele)
	var cle := "%s|%d" % [chemin_modele, couleur.to_rgba32()]
	if _matieres_peintes.has(cle):
		return _matieres_peintes[cle]
	var matiere: Material = matiere_kenney(chemin_modele).duplicate()
	if matiere is ShaderMaterial:
		(matiere as ShaderMaterial).set_shader_parameter("teinte", couleur)
		MatieresCarnage.suivre_kenney(matiere)
	elif matiere is BaseMaterial3D:
		(matiere as BaseMaterial3D).albedo_color = couleur
	_matieres_peintes[cle] = matiere
	return matiere

## LES IMMEUBLES viennent maintenant des City Kits : commercial pour le centre
## et les affaires, industriel pour les hangars, suburban pour les pavillons.
## Chaque entrée donne le ratio hauteur/largeur du modèle : on choisit celui
## qui ressemble le plus au volume demandé par le plan, puis on l'étire pour
## qu'il remplisse exactement l'emprise. Un modèle bien choisi s'étire peu.
## ⚠ Un modèle ne se casse PAS : tant que l'immeuble est intact, on pose le
## modèle ; au premier cube arraché, il disparaît et la grille de voxels prend
## le relais (voir `MorceauVille.casser`). C'est ce qui garde la destruction.
## ⚠ TOUT LE KIT Y PASSE, ET LES RATIOS SONT MESURÉS. La première version ne
## citait qu'une trentaine de modèles sur les cent et quelques que les kits
## contiennent : la moitié de la ville était bâtie avec le tiers du catalogue,
## et ça se voyait comme un copier-coller. Cette table-ci est ENGENDRÉE des
## boîtes englobantes des `.glb` : chaque entrée est
## `[chemin, hauteur / plus petit côté au sol]` — le même rapport que
## `_poser_batiments` calcule pour le rectangle du plan, sinon un pavillon
## sortirait à la place d'une tour.
## Un modèle peut servir dans plusieurs familles : `building-a` est un commerce
## en centre-ville et un logement en périphérie. Ce qui change, ce sont les
## teintes et les hauteurs du quartier, pas le maillage.
const BATIMENTS_KENNEY := {
	PlanVille.F_TOUR: [
		["batiments/low-detail-building-n", 1.40], ["batiments/building-l", 1.66],
		["batiments/building-g", 1.84], ["batiments/building-skyscraper-a", 2.12],
		["batiments/building-m", 2.54], ["batiments/low-detail-building-k", 3.10],
		["batiments/building-skyscraper-c", 3.19], ["batiments/building-skyscraper-e", 3.29],
		["batiments/building-skyscraper-b", 3.29], ["batiments/low-detail-building-j", 3.50],
		["batiments/low-detail-building-d", 3.50], ["batiments/low-detail-building-i", 3.55],
		["batiments/low-detail-building-e", 3.60], ["batiments/low-detail-building-l", 3.70],
		["batiments/low-detail-building-m", 3.95], ["batiments/low-detail-building-a", 4.00],
		["batiments/low-detail-building-f", 4.00], ["batiments/low-detail-building-g", 4.00],
		["batiments/low-detail-building-h", 4.20], ["batiments/building-skyscraper-d", 4.27],
		["batiments/low-detail-building-b", 4.45], ["batiments/low-detail-building-c", 4.50],
	],
	PlanVille.F_BUREAUX: [
		["batiments/building-i", 1.35], ["batiments/building-n", 1.36],
		["batiments/building-b", 1.38], ["batiments/building-h", 1.46],
		["batiments/building-d", 1.54], ["batiments/building-l", 1.66],
		["batiments/building-g", 1.84], ["batiments/building-f", 2.02],
		["batiments/building-skyscraper-a", 2.12], ["batiments/low-detail-building-wide-a", 2.20],
		["batiments/low-detail-building-wide-b", 2.30], ["batiments/building-skyscraper-c", 3.19],
	],
	PlanVille.F_COMMERCE: [
		["batiments/building-e", 0.89], ["batiments/building-c", 1.01],
		["batiments/building-j", 1.26], ["batiments/building-i", 1.35],
		["batiments/building-n", 1.36], ["batiments/building-b", 1.38],
		["batiments/building-a", 1.46], ["batiments/building-h", 1.46],
		["batiments/building-d", 1.54], ["batiments/building-k", 1.56],
		["batiments/low-detail-building-wide-a", 2.20], ["batiments/low-detail-building-wide-b", 2.30],
	],
	PlanVille.F_LOGEMENTS: [
		["pavillons/building-type-n", 0.83], ["pavillons/building-type-b", 1.00],
		["pavillons/building-type-l", 1.03], ["pavillons/building-type-u", 1.05],
		["pavillons/building-type-s", 1.05], ["pavillons/building-type-r", 1.12],
		["pavillons/building-type-d", 1.20], ["pavillons/building-type-k", 1.25],
		["batiments/building-i", 1.35], ["batiments/building-n", 1.36],
		["batiments/building-b", 1.38], ["batiments/building-a", 1.46],
		["batiments/building-h", 1.46], ["batiments/building-d", 1.54],
		["batiments/building-l", 1.66],
	],
	PlanVille.F_VIEUX: [
		["pavillons/building-type-m", 0.52], ["pavillons/building-type-g", 0.65],
		["pavillons/building-type-i", 0.72], ["pavillons/building-type-h", 0.81],
		["pavillons/building-type-f", 0.81], ["pavillons/building-type-a", 0.81],
		["pavillons/building-type-t", 0.88], ["batiments/building-e", 0.89],
		["pavillons/building-type-p", 0.93], ["pavillons/building-type-c", 1.01],
		["batiments/building-c", 1.01], ["pavillons/building-type-q", 1.04],
		["pavillons/building-type-o", 1.11], ["batiments/building-j", 1.26],
		["batiments/building-k", 1.56],
	],
	PlanVille.F_MAISON: [
		["pavillons/building-type-m", 0.52], ["pavillons/suburb-building-type-m", 0.52],
		["pavillons/building-type-g", 0.65], ["pavillons/building-type-i", 0.72],
		["pavillons/building-type-h", 0.81], ["pavillons/building-type-f", 0.81],
		["pavillons/suburb-building-type-f", 0.81], ["pavillons/building-type-a", 0.81],
		["pavillons/suburb-building-type-a", 0.81], ["pavillons/building-type-n", 0.83],
		["pavillons/building-type-t", 0.88], ["pavillons/building-type-p", 0.93],
		["pavillons/building-type-b", 1.00], ["pavillons/building-type-c", 1.01],
		["pavillons/suburb-building-type-c", 1.01], ["pavillons/building-type-l", 1.03],
		["pavillons/building-type-q", 1.04], ["pavillons/suburb-building-type-q", 1.04],
		["pavillons/building-type-u", 1.05], ["pavillons/building-type-s", 1.05],
		["pavillons/building-type-e", 1.11], ["pavillons/building-type-o", 1.11],
		["pavillons/building-type-r", 1.12], ["pavillons/building-type-j", 1.13],
		["pavillons/suburb-building-type-j", 1.13], ["pavillons/building-type-d", 1.20],
		["pavillons/building-type-k", 1.25],
	],
	PlanVille.F_HANGAR: [
		["industriel/building-q", 0.50], ["industriel/building-h", 0.56],
		["industriel/building-c", 0.67], ["industriel/building-i", 0.71],
		["industriel/building-p", 0.72], ["industriel/building-t", 0.73],
		["industriel/building-j", 0.84], ["industriel/building-k", 0.85],
		["industriel/building-s", 0.91], ["industriel/building-g", 1.00],
		["industriel/building-l", 1.03], ["industriel/building-o", 1.04],
		["industriel/building-r", 1.10], ["industriel/building-m", 1.15],
		["industriel/building-b", 1.16], ["industriel/building-a", 1.18],
		["industriel/building-e", 1.28], ["industriel/building-f", 1.50],
		["industriel/building-d", 1.60], ["industriel/building-n", 1.95],
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
const FENETRE_MAX_BATIMENT := 10

static func batiment_kenney(style: int, largeur: float, hauteur: float, graine: int,
		eviter: String = "") -> String:
	var famille: Array = BATIMENTS_KENNEY.get(style, [])
	if famille.is_empty() or largeur <= 0.01:
		return ""
	var voulu := hauteur / largeur
	var classement: Array = []
	for fiche in famille:
		# ⚠ LE DÉPARTAGE FAIT PARTIE DU TRI. Le kit contient des jumeaux exacts
		# (`suburb-building-type-j` a le ratio de `building-type-j` au
		# centième près) : à égalité, un tri stable donnait toujours le même,
		# et le jumeau ne sortait JAMAIS de la ville. Le nom entre donc dans la
		# clé, à un poids trop petit pour changer un classement réel.
		classement.append([absf(float(fiche[1]) - voulu)
			+ float(absi(hash(String(fiche[0]) + str(graine))) % 97) * 0.00002, String(fiche[0])])
	classement.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	# ⚠ CINQ CANDIDATS SUFFISAIENT QUAND UNE FAMILLE EN COMPTAIT SIX. Avec
	# vingt-sept pavillons, les cinq plus proches d'un ratio donné sont
	# toujours les mêmes cinq, et vingt-deux modèles ne sortaient jamais. La
	# fenêtre suit donc la taille de la famille.
	var combien: int = clampi(classement.size() / 3, CANDIDATS_BATIMENT,
		FENETRE_MAX_BATIMENT)
	combien = mini(combien, classement.size())
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
		var anneau := racine_anneau(2.7, halo_couleur, 0.22)
		anneau.position = Vector3(0, 0.04, 0)
		anneau.name = "Halo"
		racine.add_child(anneau)

	var coque := MeshInstance3D.new()
	coque.name = "Coque"
	coque.mesh = maillage_voiture(i)
	# BLANC = COULEUR D'USINE. Un modèle Kenney porte son atlas : la peinture
	# ne recouvre que sa TÔLE (voir `MatieresCarnage.KENNEY`), vitres, pneus et
	# chromes gardent leur gris. Un modèle voxel garde la matière à couleurs de
	# sommet. ⚠ Pour un modèle du kit, le blanc ne retombe plus sur l'orange
	# `VoxelsCarnage.peinture(i, 7)` : c'est l'appelant qui choisit la couleur
	# (`couleur_de_l_auto`), la même que la nappe des dormantes — sinon une
	# berline garée rouge démarrait orange, et c'est arrivé.
	var peinture := couleur if couleur != Color.WHITE else VoxelsCarnage.peinture(i, 7)
	if est_kenney(i):
		coque.material_override = matiere_peinte(modele_kenney_de(i), couleur)
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
			var teinte_feu: Color = Palette.SERIE if cote < 0.0 else Palette.CRITIQUE
			var feu := Decor.boite(Vector3(0.5, 0.3, 0.5), Palette.SERIE, false)
			feu.material_override = Decor.matiere_lumineuse(teinte_feu, 1.5)
			feu.position = Vector3(-0.2, 2.75, cote * 0.55)
			feu.name = "Bleu" if cote < 0.0 else "Rouge"
			rampe.add_child(feu)
			# LA LUEUR AU SOL du gyrophare : une flaque additive bleue, une
			# rouge, que `clignoter_gyrophare` allume à tour de rôle. Deux cubes
			# émissifs sur un toit ne se voient pas de soixante unités de haut ;
			# une rue qui passe au bleu puis au rouge, si. C'est ce qui fait
			# lire « poursuite » avant d'avoir compté les voitures.
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			_flaque(st, Vector3(-0.2, 0.06, cote * 1.4), Vector3(8.0, 0, 0), Vector3(0, 0, 6.0), Color(teinte_feu, 0.85))
			var lueur := MeshInstance3D.new()
			lueur.mesh = st.commit()
			lueur.material_override = MatieresCarnage.flaque()
			lueur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			lueur.name = "LueurBleue" if cote < 0.0 else "LueurRouge"
			rampe.add_child(lueur)
		racine.add_child(rampe)

	# LA MITRAILLEUSE DE BORD, sur le toit. Elle est posée ÉTEINTE et le jeu
	# la montre : voiture de gang (§1.3), ou atelier payé. C'est le seul signe
	# extérieur d'une arme montée — jusqu'ici elle n'existait que dans une puce
	# du tableau de bord, et deux voitures identiques n'en étaient pas.
	#
	# ⚠ LA HAUTEUR EST MESURÉE, PAS DEVINÉE. Vingt-huit carrosseries, d'un
	# coupé à un camion de pompiers : un chiffre en dur plantait le canon dans
	# le pare-brise de l'une et à un mètre au-dessus du toit de l'autre. C'est
	# exactement la faute du char, qui est sorti du banc en pick-up vert parce
	# que sa tourelle était à l'intérieur de la caisse.
	var haut_du_toit: float = 1.8
	if coque.mesh != null:
		var boite_c := coque.mesh.get_aabb()
		haut_du_toit = boite_c.position.y + boite_c.size.y
	racine.add_child(_mitrailleuse(haut_du_toit))

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

## LA MITRAILLEUSE DE BORD sur son affût : un socle, un tube, un chargeur. Elle
## se monte à `hauteur`, c'est-à-dire sur le toit de la carrosserie qui la
## porte — mesuré par l'appelant, jamais écrit en dur.
##
## Elle regarde +X comme tout le reste du parc : le canon braqué vers l'arrière
## serait drôle une seule fois.
static func _mitrailleuse(hauteur: float) -> Node3D:
	var racine := Node3D.new()
	racine.name = "Mitrailleuse"
	racine.visible = false
	var socle := Decor.cylindre(0.32, 0.22, Color("#2a2d31"), false)
	socle.position = Vector3(-0.3, hauteur + 0.11, 0)
	racine.add_child(socle)
	var bloc := Decor.boite(Vector3(0.7, 0.32, 0.34), Color("#3c4147"), false)
	bloc.position = Vector3(-0.15, hauteur + 0.38, 0)
	racine.add_child(bloc)
	var tube := Decor.boite(Vector3(1.5, 0.16, 0.16), Color("#1b1d20"), false)
	tube.position = Vector3(0.65, hauteur + 0.40, 0)
	racine.add_child(tube)
	# Le chargeur en travers : c'est lui qui fait lire « mitrailleuse » plutôt
	# que « antenne » sur une image de deux cents pixels.
	var chargeur := Decor.boite(Vector3(0.34, 0.26, 0.5), Palette.AVERTISSEMENT.darkened(0.3), false)
	chargeur.position = Vector3(-0.15, hauteur + 0.34, 0.3)
	racine.add_child(chargeur)
	return racine

## Montrer ou cacher la mitrailleuse d'une carrosserie. Une seule fonction
## partagée : le joueur qui l'achète à l'atelier, la voiture de gang qui la
## porte d'origine et le joueur distant qu'on voit passer doivent montrer la
## même chose — sinon on apprend à la reconnaître et elle ment une fois sur
## trois.
static func armer_la_voiture(carrosserie: Node3D, montee: bool) -> void:
	if carrosserie == null:
		return
	var arme := carrosserie.get_node_or_null("Mitrailleuse") as Node3D
	if arme != null:
		arme.visible = montee

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
	mot.name = "Mot"
	mot.position = Vector3(0, 3.6, 0)
	racine.add_child(mot)
	dalle.name = "Dalle"
	initiale.name = "Initiale"
	return racine

## REPEINDRE UN TAG. Un repaire PRIS (le raid, §3) passe aux couleurs de celui
## qui l'a pris, et l'écriteau le dit. On repeint plutôt que de rebâtir : le
## tag est enfant du morceau, et rebâtir un morceau pour trois nœuds, c'est
## une seconde d'arrêt au moment précis où le joueur vient de gagner.
##
## ⚠ L'ANNEAU N'EST PAS NOMMÉ (il vient de `racine_anneau`) : on le retrouve
## par son type. Le nommer aurait marché aussi, mais `racine_anneau` sert à
## huit endroits et lui donner un nom ici l'aurait donné partout.
static func repeindre_le_tag(tag: Node3D, couleur: Color, texte: String) -> void:
	if tag == null:
		return
	for enfant in tag.get_children():
		if enfant is MeshInstance3D and String(enfant.name) == "Dalle":
			(enfant as MeshInstance3D).material_override = Decor.matiere_lumineuse(couleur, 0.55, 0.35)
		elif enfant is Node3D and String(enfant.name) == "Mot":
			_ecrire(enfant as Node3D, texte, couleur)
		elif enfant is Node3D and String(enfant.name) == "Initiale":
			_ecrire(enfant as Node3D, texte.substr(0, 1).to_upper(), couleur)
		elif enfant is MeshInstance3D:
			var m := (enfant as MeshInstance3D).material_override
			if m is BaseMaterial3D:
				var copie := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				copie.albedo_color = couleur
				copie.emission = couleur
				(enfant as MeshInstance3D).material_override = copie

## Récrire une étiquette posée par `Decor.etiquette` : c'est un `Label3D`, ou un
## nœud qui en contient un.
static func _ecrire(noeud: Node3D, texte: String, couleur: Color) -> void:
	if noeud is Label3D:
		(noeud as Label3D).text = texte
		(noeud as Label3D).modulate = couleur
		return
	for enfant in noeud.get_children():
		if enfant is Node3D:
			_ecrire(enfant as Node3D, texte, couleur)

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

## LA CHAUSSÉE vient du City Kit: Roads. Une tuile du kit est une dalle de
## 1 × 1 unité posée au sol, trottoirs compris : on la POSE À L'ÉCHELLE de nos
## rues (deux tuiles de large, une de long), sans la déformer visiblement — une
## route droite s'étire dans son sens sans que rien ne se voie.
##
## ⚠ La route du modèle court selon X et ses trottoirs bordent en Z ; une rue
## verticale de la ville demande donc un quart de tour. Les carrefours, eux,
## sont symétriques et ne se tournent pas.
const CHEMIN_ROUTES := "res://modeles/kenney/routes/"
## ⚠ L'asphalte du kit est GRIS TRÈS CLAIR — posé tel quel, la ville entière
## passait au blanc. La teinte l'assombrit sans toucher au modèle, comme pour
## les lampadaires.
const TEINTE_ROUTE := Color("#8e929c")

static var _tapis: Dictionary = {}
static var _matiere_route: Material

## Le tapis d'une tuile de rue. Le modèle est déjà une dalle unité centrée : il
## n'y a rien à normaliser, l'instance porte la taille voulue.
static func maillage_route(nom: String) -> ArrayMesh:
	if _tapis.has(nom):
		return _tapis[nom]
	_tapis[nom] = maillage_kenney(CHEMIN_ROUTES + nom + ".glb", 0.0, Vector3.AXIS_X, 0.0)
	return _tapis[nom]

static func matiere_route() -> Material:
	if _matiere_route != null:
		return _matiere_route
	var m := matiere_kenney(CHEMIN_ROUTES + "road-straight.glb").duplicate()
	if m is ShaderMaterial:
		(m as ShaderMaterial).set_shader_parameter("teinte", TEINTE_ROUTE)
	elif m is BaseMaterial3D:
		(m as BaseMaterial3D).albedo_color = TEINTE_ROUTE
	_matiere_route = m
	return _matiere_route

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
## LES CINQ COULEURS DE L'HUMEUR D'UN GANG, du « il vous tire dessus » au
## « il se bat à côté de vous ». Une seule table pour toute la ville :
## l'enseigne d'une cabine et l'anneau sous un homme de main disent la même
## chose, elles ne peuvent pas se contredire.
##
## Le rouge n'est pas « pas de contrat » mais « on vous tire dessus » ; entre
## les deux, le brun dit qu'on vous parle encore mais qu'on ne vous confie
## rien. Sans ce cran intermédiaire, le joueur passait du vert au rouge sans
## avoir rien vu venir.
const COULEURS_HUMEUR := [
	Color("#d0402c"),   ## tire à vue
	Color("#a05a2c"),   ## hostile — aucun contrat
	Color("#e0b23a"),   ## neutre — contrats de base
	Color("#4cc25a"),   ## amical — contrats moyens
	Color("#7ef0a0"),   ## allié — contrats difficiles
]

## L'anneau posé sous un homme de gang quand son humeur n'est pas neutre.
##
## ⚠ À PLAT, ET SANS LE QUART DE TOUR. Le halo d'un joueur et celui d'une
## cabine tournent de 90° sur X — un `TorusMesh` est DÉJÀ couché dans le plan
## du sol, ce quart de tour le met donc DEBOUT, et l'anneau se lisait comme un
## cerceau planté en travers du bonhomme (mesuré au banc, `outils/tableau.sh`).
## Ici on le laisse au sol, où il fait ce qu'on lui demande : une pastille
## sous les pieds.
##
## Rayon 0,8 : plus petit que le halo d'un joueur (1,5), sinon deux hommes de
## main côte à côte ont des anneaux qui se chevauchent.
static func anneau_humeur(couleur: Color) -> MeshInstance3D:
	var anneau := Decor.anneau(0.8, 0.12, couleur, 1.6)
	anneau.position = Vector3(0, 0.06, 0)
	anneau.name = "Humeur"
	return anneau

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
		var anneau := racine_anneau(1.5, couleur, 0.16)
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
## L'ATELIER (guide §7.2). Ce n'est PAS un lieu de plus sur la carte : c'est un
## garage de peinture sur deux qui vend aussi des modifications. Deux raisons.
## D'abord GTA 2 fait pareil — on entre chez « Max Paynt » pour repeindre ET
## pour s'équiper. Ensuite, un septième genre de lieu, c'est une pastille de
## plus sur une carte qui en porte déjà six, et un joueur qui cherche un garage
## en trouve un sur deux qui ne repeint pas.
##
## ⚠ LE CHOIX SE FAIT AU VOLANT, pas dans un menu. Cinq pastilles peintes en
## couronne sur la dalle ; on se gare sur celle qu'on veut et `F` achète. À
## trois touches en tout dans ce jeu, ouvrir un menu déroulant au milieu d'une
## poursuite, c'est demander au joueur de mourir en lisant.
const ATELIER := [
	{"cle": "plaques", "nom": "PLAQUES", "prix": 450, "couleur": Color("#5aa0e0"),
		"mot": "la police perd votre description"},
	{"cle": "mitrailleuse", "nom": "MITRAILLEUSE", "prix": 950, "couleur": Color("#f2c53d"),
		"mot": "tir avant depuis le volant"},
	{"cle": "mines", "nom": "MINES", "prix": 750, "couleur": Color("#d0402c"),
		"mot": "F largue une mine derrière soi"},
	{"cle": "huile", "nom": "HUILE", "prix": 550, "couleur": Color("#6a5a7a"),
		"mot": "F répand une flaque"},
	{"cle": "bombe", "nom": "BOMBE", "prix": 650, "couleur": Color("#e07a3c"),
		"mot": "la voiture saute après votre départ"},
]

## Un garage sur deux, tiré de son PÂTÉ : la carte est engendrée, la liste des
## ateliers ne peut donc pas être écrite à la main — et elle doit tomber pareil
## chez les quatre joueurs sans passer par le réseau.
## L'ARMURERIE D'UN REPAIRE (§3) : ce que le gang vend à ceux qu'il couvre.
##
## Jusqu'ici le jeu n'avait AUCUN endroit où ACHETER une arme : elles ne
## tombaient que des caisses et des corps, c'est-à-dire du hasard. C'est ce qui
## rend le respect payant — à quatre-vingts, on ne se demande plus où trouver
## des roquettes, on sait chez qui aller.
##
## Deux armes seulement, parce que le jeu n'en a que deux à vendre (le pistolet
## ne s'épuise jamais, la mitrailleuse de bord se monte à l'atelier). Un gang
## en tient une, et c'est ce qui donne une raison de choisir SON gang plutôt
## qu'un autre.
const ARMURERIE := [
	{"arme": "mitraillette", "prix": 700, "mot": "chargeur plein"},
	{"arme": "roquette", "prix": 1700, "mot": "six tubes"},
]
## Qui vend quoi. Le Consortium (6) vend des roquettes : c'est le gang commun
## aux trois districts, celui qu'on peut fréquenter partout, et il vaut mieux
## que la marchandise rare ne soit pas celle du gang qu'on croise le plus.
const ARME_DU_GANG := [0, 1, 0, 1, 0, 1, 1]

static func armurerie_du_gang(gang: int) -> Dictionary:
	return ARMURERIE[int(ARME_DU_GANG[posmod(gang, ARME_DU_GANG.size())])]

static func est_atelier(id: int) -> bool:
	return posmod(hash(Vector2i(id, 7717)), 100) < 55

## Le centre d'une baie, en PIXELS et relatif au centre du garage. Le premier
## est au nord, puis on tourne dans le sens des aiguilles : c'est l'ordre du
## catalogue, et celui des étiquettes.
static func baie_atelier(indice: int) -> Vector2:
	var angle := -PI * 0.5 + TAU * float(posmod(indice, ATELIER.size())) / float(ATELIER.size())
	return Vector2.RIGHT.rotated(angle) * PlanVille.RAYON_GARAGE * 0.60

## Sur quelle baie se tient ce point : la plus proche, sans seuil. Un seuil
## laisserait le joueur au milieu de la dalle sans rien acheter et sans savoir
## pourquoi — là, il y a toujours une réponse, et l'écran la nomme.
static func baie_sous(point: Vector2, centre: Vector2) -> int:
	var meilleure := 0
	var distance := INF
	for i in ATELIER.size():
		var d: float = (centre + baie_atelier(i)).distance_to(point)
		if d < distance:
			distance = d
			meilleure = i
	return meilleure

## LES QUATRE TENUES (guide §5). Le bleu reste à la police ordinaire ; le SWAT
## est en bleu de nuit, l'agent spécial en noir, l'armée en olive. C'est ce qui
## dit, à l'écran et sans un mot, que la rue vient de changer de catégorie.
## L'ordre est celui de `VilleVivante.CORPS`.
const TENUES_CORPS := [Color("#3987e5"), Color("#243a5e"), Color("#191920"), Color("#5e6b38")]

## Un uniforme, tel que la rue le montre.
##
## ⚠ LA CASQUETTE NE SUFFIT PAS. Les quatre corps ont d'abord été distingués
## par la seule couleur passée à `pieton` — qui ne teint que la calotte et le
## fanion. Au banc, les quatre uniformes étaient RIGOUREUSEMENT identiques :
## le corps du personnage vient de l'atlas Kenney, il ne se teinte pas. D'où
## le GILET : une plaque de couleur sur le torse, large et haute, qui est
## précisément ce qu'une caméra en plongée voit d'un homme debout.
static func uniforme(corps: int) -> Node3D:
	var couleur: Color = TENUES_CORPS[posmod(corps, TENUES_CORPS.size())]
	var racine := pieton(couleur, true, "", false, PEAU_FLIC)
	var gilet := Decor.boite(Vector3(0.92, 0.85, 0.66), couleur, false)
	gilet.position = Vector3(0, 1.95, 0)
	gilet.name = "Gilet"
	racine.add_child(gilet)
	return racine

## LE CHAR (guide §5, niveau 6). Pas de modèle de char dans les kits : on
## prend le camion, on l'habille en olive, on lui pose deux chenilles et un
## CANON qui dépasse à l'avant. Vu de dessus — la seule vue du jeu — c'est
## exactement ce qui manquait pour ne pas le confondre avec un poids lourd.
##
## ⚠ Le canon est le repère qui compte : sans lui, le joueur voyait un camion
## vert, ne comprenait pas d'où venaient les obus, et cherchait un tireur sur
## les toits.
static func char_arme() -> Node3D:
	var racine := voiture_kit(8, Color("#5e6b38"))
	# ⚠ LES CHIFFRES SONT CEUX DE LA CAISSE, MESURÉS. Le camion du kit fait
	# 6,25 × 2,75 × 3,18 une fois posé (`get_aabb`) : la tourelle a d'abord été
	# plantée à 1,5 de haut, c'est-à-dire À L'INTÉRIEUR de la carrosserie, et
	# le char sortait du banc en simple pick-up vert. On ne devine pas la
	# taille d'un modèle importé, on la mesure.
	var tourelle := Decor.boite(Vector3(2.0, 0.85, 2.0), Color("#4a5530"), false)
	tourelle.position = Vector3(-0.2, 2.9, 0)
	racine.add_child(tourelle)
	# Le canon pointe vers +X : les carrosseries du kit regardent +X une fois
	# posées par `voiture_kit`, et un canon braqué sur l'arrière serait drôle
	# une seule fois. Il DÉPASSE du capot (3,125) — c'est à ça qu'on le
	# reconnaît de dessus.
	# ⚠ Il SORT DE LA TOURELLE. Posé trois unités devant, il flottait tout
	# seul en l'air avec un trou au milieu — on voyait une poutre, pas un char.
	var canon := Decor.boite(Vector3(3.6, 0.45, 0.45), Color("#3a4326"), false)
	canon.position = Vector3(2.4, 2.85, 0)
	racine.add_child(canon)
	# Les chenilles longent la caisse SANS déborder : à 0,75 de large posées à
	# 1,5 du milieu, elles dépassaient de la carrosserie (demi-largeur 1,59) et
	# le char portait une jupe noire.
	for cote in [-1.0, 1.0]:
		var chenille := Decor.boite(Vector3(6.0, 0.7, 0.5), Color("#23231f"), false)
		chenille.position = Vector3(0, 0.4, cote * 1.3)
		racine.add_child(chenille)
	return racine

## UNE RAME DE TRAIN (§1.3) : une motrice et deux voitures, en boîtes. Pas de
## modèle importé — le Car Kit n'a pas de train, et une rame est la seule chose
## de la ville qu'on voit toujours de haut et jamais de près.
##
## ⚠ Les chiffres sont ceux de la VOIE. Le nuanceur du sol trace les deux rails
## à ±0,75 unité de l'axe (`MatieresCarnage`) : une caisse plus large que ~2,6
## flotte à côté de ses rails, et l'illusion tombe d'un coup vue de dessus.
## La rame regarde +X, comme les carrosseries du kit — le jeu la tourne d'un
## seul angle, celui de la voie.
const LONG_WAGON_3D := 9.6        ## PlanVille.PAS en unités 3D : `VilleVivante.LONG_WAGON` / 10
const ECART_WAGON_3D := 1.2
const COULEUR_TRAIN := Color("#8f2f2a")
const COULEUR_TOIT := Color("#2c2f36")
## ⚠ Le quai doit connaître la longueur d'une rame, et `VilleVivante` connaît
## déjà `WAGONS`. On ne le lui demande PAS : les formes sont chargées par des
## bancs qui n'instancient pas la ville, et un `class_name` qui en appelle un
## autre pour trois wagons crée un aller-retour qu'on paie à chaque relecture.
const WAGONS_QUAI := 3

static func rame_de_train(wagons: int) -> Node3D:
	var racine := Node3D.new()
	for k in wagons:
		# La MOTRICE est en tête (k = 0) : c'est elle qui porte le phare et la
		# calandre, et c'est à ça qu'on voit dans quel sens la rame arrive.
		var motrice := k == 0
		var x := -float(k) * (LONG_WAGON_3D + ECART_WAGON_3D)
		var voiture := Node3D.new()
		voiture.position = Vector3(x, 0, 0)
		racine.add_child(voiture)
		var caisse := Decor.boite(Vector3(LONG_WAGON_3D, 2.3, 2.6),
			COULEUR_TRAIN if motrice else COULEUR_TRAIN.darkened(0.18))
		caisse.position = Vector3(0, 1.5, 0)
		voiture.add_child(caisse)
		var toit := Decor.boite(Vector3(LONG_WAGON_3D * 0.94, 0.35, 2.75), COULEUR_TOIT)
		toit.position = Vector3(0, 2.75, 0)
		voiture.add_child(toit)
		# Le bogie : une semelle sombre qui pose la caisse sur les rails. Sans
		# elle la caisse flottait au-dessus du ballast, et de haut ça se voit —
		# c'est l'ombre qui trahit, pas la caisse.
		var bogie := Decor.boite(Vector3(LONG_WAGON_3D * 0.8, 0.5, 1.7), Color("#191a1d"))
		bogie.position = Vector3(0, 0.3, 0)
		voiture.add_child(bogie)
		# Les FENÊTRES : deux bandes claires par flanc. C'est la seule chose qui
		# distingue un wagon d'un conteneur, vu d'en haut à trois cents pixels.
		for cote in [-1.0, 1.0]:
			var bande := Decor.boite(Vector3(LONG_WAGON_3D * 0.72, 0.7, 0.1),
				Palette.SERIE.lightened(0.25), false)
			bande.material_override = Decor.matiere_lumineuse(Palette.SERIE.lightened(0.3), 0.5)
			bande.position = Vector3(0, 1.95, cote * 1.32)
			voiture.add_child(bande)
		if motrice:
			var phare := Decor.boite(Vector3(0.3, 0.5, 1.4), Color("#ffeaa0"), false)
			phare.material_override = Decor.matiere_lumineuse(Color("#ffeaa0"), 2.2)
			phare.position = Vector3(LONG_WAGON_3D * 0.5, 1.6, 0)
			phare.name = "Phare"
			voiture.add_child(phare)
	return racine

## LE QUAI : la dalle où le train marque l'arrêt. Elle est POSÉE PAR LE JEU à
## l'abscisse que `VilleVivante.gares()` donne, pas dessinée dans la carte —
## la voie change avec le code de la manche, un quai dessiné à la main
## tomberait dans la rivière une manche sur deux.
static func quai() -> Node3D:
	var racine := Node3D.new()
	# ⚠ Le quai s'est d'abord peint avec la palette de l'interface
	# (`Palette.SURFACE`, `Palette.SERIE`) : une dalle NOIRE surmontée de deux
	# auvents bleu vif. La palette sert à l'écran, pas au béton — le décor de
	# la ville se peint avec les gris de la ville.
	# ⚠ LE QUAI FAIT LA LONGUEUR D'UNE RAME, pas seize unités. Trop court, il
	# ne passait que sous la motrice : le train s'arrêtait « à quai » avec ses
	# deux voitures dans le vide, et l'on montait à côté d'un bout de béton de
	# la taille d'un abribus. Une rame mesure trois wagons et deux écarts —
	# le quai les couvre, plus une marge de chaque bout.
	var long_quai: float = float(WAGONS_QUAI) * (LONG_WAGON_3D + ECART_WAGON_3D) + 6.0
	var dalle := Decor.boite(Vector3(long_quai, 0.5, 3.0), Color("#9a9890"))
	dalle.position = Vector3(0, 0.25, 3.4)
	racine.add_child(dalle)
	# La BANDE JAUNE au bord du quai : c'est le seul repère qui dise, de haut,
	# de quel côté le train passe.
	var bordure := Decor.boite(Vector3(long_quai, 0.16, 0.5), Palette.AVERTISSEMENT, false)
	bordure.material_override = Decor.matiere_lumineuse(Palette.AVERTISSEMENT, 0.7)
	bordure.position = Vector3(0, 0.55, 2.1)
	racine.add_child(bordure)
	for cote in [-1.0, 0.0, 1.0]:
		var abri := Decor.boite(Vector3(3.6, 0.3, 2.6), Color("#3d4148"))
		abri.position = Vector3(cote * long_quai * 0.33, 3.1, 4.0)
		racine.add_child(abri)
		for pied in [-1.5, 1.5]:
			var poteau := Decor.boite(Vector3(0.26, 3.0, 0.26), Color("#5c5f66"))
			poteau.position = Vector3(cote * long_quai * 0.33 + pied, 1.6, 4.9)
			racine.add_child(poteau)
	var mot := Decor.etiquette("GARE", Palette.AVERTISSEMENT, 34)
	mot.position = Vector3(0, 5.0, 3.4)
	racine.add_child(mot)
	return racine

## LE COMPACTEUR (§1.3) : une fosse de tôle entre deux mâchoires, au bord de la
## voie ferrée. On y entre au volant, on en ressort à pied.
##
## Il se lit de haut à trois choses : la DALLE rouillée (on n'a ça nulle part
## ailleurs en ville), les deux MÂCHOIRES qui l'encadrent, et le tapis jaune
## rayé qui dit où se garer. Sans le tapis, on tourne autour en cherchant le
## point exact — c'est la leçon des baies de l'atelier, qui ont mis trois
## essais à devenir visibles.
const COULEUR_CASSE := Color("#6b4a32")
const COULEUR_MACHOIRE := Color("#3a3d42")

static func compacteur() -> Node3D:
	var racine := Node3D.new()
	var rayon: float = VilleVivante.RAYON_CASSE * Decor.ECHELLE
	var dalle := Decor.boite(Vector3(rayon * 2.0, 0.24, rayon * 2.0), COULEUR_CASSE)
	dalle.position = Vector3(0, 0.12, 0)
	racine.add_child(dalle)
	# Le TAPIS : la place exacte, en jaune. Il est posé AU-DESSUS de la dalle
	# (0,26 contre 0,24) — glissé dedans, il disparaissait sous elle, ce qui est
	# arrivé aux pastilles de l'atelier avant qu'on ne les remonte.
	var tapis := Decor.boite(Vector3(rayon * 1.15, 0.08, rayon * 0.9),
		Palette.AVERTISSEMENT.darkened(0.15), false)
	tapis.material_override = Decor.matiere_lumineuse(Palette.AVERTISSEMENT, 0.55)
	tapis.position = Vector3(0, 0.28, 0)
	tapis.name = "Tapis"
	racine.add_child(tapis)
	# Les deux MÂCHOIRES, de part et d'autre. Elles ne bougent pas : le jeu les
	# abaisse au moment du broyage (`Machoire0` / `Machoire1`).
	for k in 2:
		var cote := -1.0 if k == 0 else 1.0
		var machoire := Decor.boite(Vector3(0.9, 3.4, rayon * 1.9), COULEUR_MACHOIRE)
		machoire.position = Vector3(cote * rayon * 0.72, 1.9, 0)
		machoire.name = "Machoire%d" % k
		racine.add_child(machoire)
		var verin := Decor.boite(Vector3(0.4, 4.4, 0.4), Color("#8d9199"))
		verin.position = Vector3(cote * rayon * 0.72, 2.4, rayon * 0.8)
		racine.add_child(verin)
	# Les carcasses déjà broyées, empilées au bord : c'est ce qui dit qu'on est
	# à la casse et pas devant un portail d'usine.
	for k in 4:
		var galette := Decor.boite(Vector3(1.9, 0.5, 1.0),
			Color("#7d6a55").darkened(0.08 * float(k)))
		galette.position = Vector3(rayon * 1.25, 0.35 + float(k) * 0.5,
			rayon * (-0.4 + 0.28 * float(k)))
		galette.rotation.y = 0.2 * float(k)
		racine.add_child(galette)
	var mot := Decor.etiquette("CASSE", Palette.AVERTISSEMENT, 30)
	mot.position = Vector3(0, 5.2, 0)
	racine.add_child(mot)
	return racine

## UNE MINE POSÉE : un palet sombre, un œil rouge qui clignote (c'est le jeu
## qui l'allume), et un anneau au sol. L'anneau n'est pas décoratif — sans lui
## on ne voit pas une mine de trois pixels dans une rue de nuit, et une arme
## qu'on ne voit pas n'est pas une arme, c'est un accident.
static func mine() -> Node3D:
	var racine := Node3D.new()
	var palet := Decor.cylindre(0.42, 0.22, Color("#2a2a2e"), false)
	palet.position = Vector3(0, 0.11, 0)
	racine.add_child(palet)
	var oeil := Decor.boite(Vector3(0.2, 0.12, 0.2), Palette.CRITIQUE, false)
	oeil.material_override = Decor.matiere_lumineuse(Palette.CRITIQUE, 2.2)
	oeil.position = Vector3(0, 0.28, 0)
	oeil.name = "Oeil"
	racine.add_child(oeil)
	racine.add_child(racine_anneau(PlanVille.RAYON_MINE * Decor.ECHELLE, Palette.CRITIQUE, 0.07))
	return racine

## UNE FLAQUE D'HUILE : un disque noir irisé, à peine bombé. Elle ne brille pas
## comme une mine — elle doit se voir sans crier au danger, puisqu'elle ne
## blesse personne.
static func flaque_huile() -> Node3D:
	var racine := Node3D.new()
	var flaque := Decor.cylindre(PlanVille.RAYON_HUILE * Decor.ECHELLE, 0.04, Color("#1a1620"), false)
	flaque.material_override = Decor.matiere_lumineuse(Color("#3a2f4a"), 0.25, 0.75)
	flaque.position = Vector3(0, 0.05, 0)
	racine.add_child(flaque)
	racine.add_child(racine_anneau(PlanVille.RAYON_HUILE * Decor.ECHELLE, Color("#6a5a7a"), 0.06))
	return racine

static func dalle_atelier() -> Node3D:
	var racine := dalle_garage()
	# L'enseigne du garage dit PEINTURE ; celle-ci dit ce qu'on trouve en plus.
	var enseigne := Decor.etiquette("ATELIER", Color("#f2c53d"), 26)
	enseigne.position = Vector3(0, 4.2, 0)
	racine.add_child(enseigne)
	for i in ATELIER.size():
		var fiche: Dictionary = ATELIER[i]
		var ou := baie_atelier(i) * Decor.ECHELLE
		var pastille := Decor.cylindre(PlanVille.RAYON_GARAGE * 0.26 * Decor.ECHELLE, 0.06,
			fiche["couleur"], false)
		# OPAQUE. À 0,55 d'opacité, la pastille laissait passer le bleu de la
		# dalle et le vert du sol : les cinq couleurs viraient toutes au même
		# kaki, et le joueur ne pouvait plus reconnaître sa baie de loin.
		pastille.material_override = Decor.matiere_lumineuse(fiche["couleur"], 0.85)
		# ⚠ AU-DESSUS DE LA DALLE, pas dedans. La dalle du garage va de 0,06 à
		# 0,16 : à 0,14 les pastilles étaient NOYÉES dans son bleu translucide
		# et ressortaient toutes de la même couleur délavée. C'est la deuxième
		# fois que ce piège se referme dans ce projet — la première, c'étaient
		# les marques des repaires dans l'épaisseur du plancher.
		pastille.position = Vector3(ou.x, 0.20, ou.y)
		racine.add_child(pastille)
		var anneau := racine_anneau(PlanVille.RAYON_GARAGE * 0.26 * Decor.ECHELLE,
			fiche["couleur"], 0.08)
		anneau.position = Vector3(ou.x, 0.23, ou.y)
		racine.add_child(anneau)
		# L'étiquette est BASSE : à trois mètres elle passait derrière
		# l'enseigne du garage et on lisait « MINES » à travers « PEINTURE ».
		var mot := Decor.etiquette(String(fiche["nom"]), fiche["couleur"], 15)
		mot.position = Vector3(ou.x, 1.1, ou.y)
		racine.add_child(mot)
	return racine

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

## LA SUPÉRETTE : la devanture de la boutique où l'on achète à manger et à
## boire. Une dalle claire, un auvent vert d'eau, deux vitrines éclairées et
## l'enseigne. C'est le seul commerce de la ville dans lequel on ENTRE.
##
## ⚠ La dalle déborde la tuile de la porte : `RAYON_SUPERETTE` fait 80 px, une
## tuile en fait 100. Un pas de porte plus petit que la portée du `F` et l'on
## se retrouve à acheter du pain debout au milieu de la rue, sans rien voir
## sous ses pieds qui le justifie.
## LE MODÈLE DU KIT (`ville/building-small-d`) : une boutique d'angle avec sa
## vitrine, son auvent et son enseigne, déjà dessinée par Kenney.
##
## ⚠ ELLE ÉTAIT BÂTIE EN BOÎTES. Un auvent, deux poteaux, deux carrés jaunes
## pour les vitrines : ça tenait de loin et ça ne tenait que de loin. Le kit de
## ville en a une vraie, et la ville entière est déjà faite de ses modèles —
## une façade à la main au milieu de deux cent trente-neuf modèles importés,
## c'est la seule qui ne ressemble pas aux autres.
const MODELE_SUPERETTE := "res://modeles/ville/building-small-d.glb"
## Le modèle fait UNE unité de côté (mesuré : 1,0 × 1,0 × 1,05) et une tuile en
## fait dix. À dix, il remplit exactement sa tuile ; à huit et demi, il laisse
## le trottoir devant, ce qu'il faut pour que le pas de porte se voie.
const ECHELLE_SUPERETTE := 8.5

static func devanture_de_superette() -> Node3D:
	var racine := Node3D.new()
	var rayon := PlanVille.RAYON_SUPERETTE * Decor.ECHELLE
	var couleur := PlanVille.COULEUR_SUPERETTE
	# LE PAS DE PORTE reste peint : c'est lui qui dit où le menu s'ouvre, et
	# c'est la même grammaire que le garage, l'hôpital et la planque. Un lieu
	# du jeu se reconnaît à son disque au sol, pas à sa façade.
	racine.add_child(racine_anneau(rayon, couleur, 0.18))
	var dalle := Decor.cylindre(rayon, 0.1, couleur, false)
	dalle.material_override = Decor.matiere_lumineuse(couleur, 0.3, 0.34)
	dalle.position = Vector3(0, 0.05, 0)
	racine.add_child(dalle)

	var boutique := Decor.instance(MODELE_SUPERETTE)
	boutique.scale = Vector3.ONE * ECHELLE_SUPERETTE
	# ⚠ REPOUSSÉE VERS LE FOND DE SA TUILE. Centrée, elle couvrait le pas de
	# porte : de dessus — et la caméra ne voit à peu près que ça — on n'avait
	# plus qu'un toit, sans le disque qui dit qu'on peut y entrer.
	boutique.position = Vector3(0, 0, -rayon * 0.42)
	racine.add_child(boutique)

	# Le CADDIE abandonné devant la porte, et l'enseigne au-dessus du toit : le
	# modèle du kit n'a pas de nom écrit dessus, et un joueur qui a faim doit
	# pouvoir lire « supérette » sans s'arrêter.
	var caddie := Decor.boite(Vector3(0.7, 0.6, 0.5), Palette.ENCRE_FAIBLE)
	caddie.position = Vector3(rayon * 0.6, 0.45, rayon * 0.5)
	caddie.rotation.y = 0.4
	racine.add_child(caddie)
	var mot := Decor.etiquette("SUPÉRETTE", couleur, 30)
	mot.position = Vector3(0, ECHELLE_SUPERETTE + 1.6, 0)
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
## LES TROIS TÉLÉPHONES (guide §4.1) : vert facile, jaune moyen, rouge
## difficile. La couleur d'une cabine est FIXE — elle tient à la cabine, pas à
## l'humeur du moment — et c'est ce qui en fait un repère : « le rouge des
## docks paie gros, mais il faut que Les Braises me tiennent en haute estime ».
##
## ⚠ La couleur ne dit plus ce que le gang pense de vous (c'était le cas
## depuis la phase 4). Ce qu'elle dit maintenant, c'est CE QU'ON Y TROUVE ; ce
## que le gang pense, l'anneau sous ses hommes et la ligne du tableau de bord
## le disent déjà, et deux choses à la même place n'en disent qu'une.
##
## Le niveau se tire du PÂTÉ, comme l'atelier : la carte est engendrée, la
## liste des cabines ne peut pas être écrite à la main, et elle doit tomber
## pareil chez les quatre joueurs sans passer par le réseau. Un téléphone sur
## deux est vert : c'est le seul qu'on puisse décrocher en arrivant.
const CABINES := [
	{"nom": "facile", "couleur": Color("#4cc25a"), "respect": 40.0},
	{"nom": "moyenne", "couleur": Color("#f2c53d"), "respect": 62.0},
	{"nom": "difficile", "couleur": Color("#d0402c"), "respect": 82.0},
]

## L'éclat de l'enseigne. C'est la SEULE chose qui bouge sur une cabine :
## allumée, on peut décrocher ; éteinte, il manque du respect (ou on a déjà un
## contrat en cours). La couleur, elle, ne change jamais — sinon on ne pourrait
## plus repérer un téléphone rouge de loin et revenir plus tard.
const CABINE_ETEINTE := 0.30
const CABINE_ALLUMEE := 1.4

static func niveau_de_cabine(id: int) -> int:
	var tirage := posmod(hash(Vector2i(id, 4231)), 100)
	if tirage < 50:
		return 0
	return 1 if tirage < 80 else 2

static func cabine(numero: int) -> Node3D:
	var racine := Node3D.new()
	var caisson := Decor.boite(Vector3(1.1, 2.4, 1.1), Palette.SURFACE.lightened(0.1))
	caisson.position = Vector3(0, 1.2, 0)
	racine.add_child(caisson)
	var vitre := Decor.boite(Vector3(0.9, 1.1, 0.9), Palette.SERIE, false)
	vitre.material_override = Decor.matiere_voile(Palette.SERIE, 0.4)
	vitre.position = Vector3(0, 1.7, 0)
	racine.add_child(vitre)
	# L'ENSEIGNE porte la couleur du TÉLÉPHONE : verte, jaune ou rouge. Le jeu
	# ne fait que l'allumer ou l'éteindre selon qu'on peut décrocher.
	var teinte: Color = CABINES[niveau_de_cabine(numero)]["couleur"]
	var enseigne := Decor.boite(Vector3(1.3, 0.34, 1.3), teinte, false)
	enseigne.material_override = Decor.matiere_lumineuse(teinte, CABINE_ALLUMEE)
	enseigne.position = Vector3(0, 2.6, 0)
	enseigne.name = "Enseigne"
	racine.add_child(enseigne)
	var halo := racine_anneau(PlanVille.RAYON_CABINE * Decor.ECHELLE, teinte, 0.14)
	halo.position = Vector3(0, 0.06, 0)
	halo.name = "Halo"
	racine.add_child(halo)
	var mot := Decor.etiquette(String(CABINES[niveau_de_cabine(numero)]["nom"]).to_upper(),
		teinte, 26)
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
## LE COLIS CACHÉ (guide §4.3) : une malle dorée cerclée de sombre, sur un
## anneau. Elle tourne et flotte comme une caisse d'arme — c'est le vocabulaire
## du jeu pour « ramasse-moi », et en inventer un second pour la même chose
## serait une leçon de plus à apprendre pour rien.
const OR_COLIS := Color("#f0c04a")
static func colis() -> Node3D:
	var racine := Node3D.new()
	racine.add_child(racine_anneau(1.7, OR_COLIS, 0.14))
	var objet := cubes([
		[Vector3.ZERO, 1.15, Color(OR_COLIS.darkened(0.4), VoxelsCarnage.MUR)],
		[Vector3(0, 0.35, 0), 1.25, Color(OR_COLIS, VoxelsCarnage.LUMIERE)],
		[Vector3(0, -0.3, 0), 1.25, Color(OR_COLIS.darkened(0.2), VoxelsCarnage.MUR)],
	])
	objet.name = "Objet"
	objet.position = Vector3(0, 1.5, 0)
	racine.add_child(objet)
	return racine

## L'ICÔNE DE KILL FRENZY : un crâne cubique sur un anneau rouge. Rouge et
## anguleux là où le colis est rond et doré : de loin, on doit savoir si l'on
## court vers de l'argent ou vers trente secondes de carnage.
static func icone_frenzy() -> Node3D:
	var racine := Node3D.new()
	racine.add_child(racine_anneau(2.0, Palette.CRITIQUE, 0.18))
	var socle := Decor.cylindre(1.8, 0.1, Palette.CRITIQUE, false)
	socle.material_override = Decor.matiere_lumineuse(Palette.CRITIQUE, 0.7, 0.45)
	socle.position = Vector3(0, 0.07, 0)
	racine.add_child(socle)
	var crane := cubes([
		[Vector3.ZERO, 1.2, Color(Color("#f2efe4"), VoxelsCarnage.LUMIERE)],
		[Vector3(-0.3, 0.1, 0.62), 0.34, Color(Color("#1a1a1a"), VoxelsCarnage.MUR)],
		[Vector3(0.3, 0.1, 0.62), 0.34, Color(Color("#1a1a1a"), VoxelsCarnage.MUR)],
		[Vector3(0, -0.62, 0.3), 0.55, Color(Color("#e2ded0"), VoxelsCarnage.MUR)],
	])
	crane.name = "Objet"
	crane.position = Vector3(0, 1.8, 0)
	racine.add_child(crane)
	return racine

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

## Un anneau posé à plat.
##
## ⚠ SANS QUART DE TOUR. C'est l'inverse de ce que ce fichier a cru pendant
## douze versions : un `TorusMesh` de Godot est DÉJÀ couché dans le plan du
## sol, et le `rotation_degrees = Vector3(90, 0, 0)` qu'on lui collait le
## mettait DEBOUT. Toutes les auréoles du jeu — garages, hôpitaux, arènes,
## repaires, cabines, joueurs — étaient des arceaux plantés en travers de la
## rue, hauts de six mètres et qui se croisaient d'un carrefour à l'autre.
## Personne ne l'avait vu parce que les bancs les photographiaient de face,
## où un arceau ressemble à un cercle. `outils/voir.sh d:atelier` les prend de
## trois quarts, et le doute n'est plus permis.
static func racine_anneau(rayon: float, couleur: Color, epaisseur: float) -> MeshInstance3D:
	var anneau := Decor.anneau(rayon, epaisseur, couleur, 1.0)
	anneau.position = Vector3(0, 0.05, 0)
	return anneau
