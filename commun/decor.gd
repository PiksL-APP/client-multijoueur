class_name Decor
extends RefCounted
## Fabrique du décor 3D. Tout le jeu se joue sur un plan — la simulation reste
## en deux dimensions — mais se REGARDE en perspective : caméra inclinée,
## lumière rasante, ombres portées, volumes qui ont une hauteur.
##
## Pourquoi une échelle : les coordonnées de jeu sont en pixels (une arène fait
## 2 200 de large). Gardées telles quelles en unités 3D, la portée d'ombre et
## le plan lointain de la caméra deviennent ingérables et la précision de la
## carte d'ombre s'effondre. Un facteur dix ramène tout à des dimensions
## ordinaires.
const ECHELLE := 0.1

static func vers3d(plan: Vector2, hauteur: float = 0.0) -> Vector3:
	return Vector3(plan.x * ECHELLE, hauteur, plan.y * ECHELLE)

# ------------------------------------------------------------ matières

static func matiere(couleur: Color, rugosite: float = 0.65, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = rugosite
	m.metallic = metal
	return m

## Matière lumineuse : le portail, les dalles actives, les traînées. L'émission
## ne dépend pas de la lumière, donc ces éléments restent lisibles même dans
## l'ombre — c'est ce qui fait qu'un portail se repère de loin.
## Une matière qui ignore l'éclairage et rend EXACTEMENT sa couleur.
##
## L'émission d'une matière ordinaire s'ajoute à l'albédo : un anneau
## #3987e5 émettant #3987e5 ressort en cyan pâle, et le portail perd la
## couleur qui l'identifie. Sans éclairage à calculer, la teinte de la palette
## arrive intacte à l'écran — c'est aussi moins cher.
static func matiere_lumineuse(couleur: Color, force: float = 1.0, opacite: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var teinte := couleur
	if force < 1.0:
		teinte = couleur.darkened(1.0 - force)
	elif force > 1.0:
		teinte = couleur.lightened(min(0.35, (force - 1.0) * 0.3))
	m.albedo_color = Color(teinte, opacite)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if opacite < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

static func matiere_voile(couleur: Color, opacite: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(couleur, opacite)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

# ------------------------------------------------------------ volumes

static func boite(dimensions: Vector3, couleur: Color, ombre: bool = true) -> MeshInstance3D:
	var maillage := BoxMesh.new()
	maillage.size = dimensions
	return _instance(maillage, matiere(couleur), ombre)

static func cylindre(rayon: float, hauteur: float, couleur: Color, ombre: bool = true) -> MeshInstance3D:
	var maillage := CylinderMesh.new()
	maillage.top_radius = rayon
	maillage.bottom_radius = rayon
	maillage.height = hauteur
	maillage.radial_segments = 20
	return _instance(maillage, matiere(couleur), ombre)

static func sphere(rayon: float, couleur: Color, ombre: bool = true) -> MeshInstance3D:
	var maillage := SphereMesh.new()
	maillage.radius = rayon
	maillage.height = rayon * 2.0
	maillage.radial_segments = 16
	maillage.rings = 8
	return _instance(maillage, matiere(couleur), ombre)

static func anneau(rayon: float, epaisseur: float, couleur: Color, force: float = 1.0) -> MeshInstance3D:
	var maillage := TorusMesh.new()
	maillage.inner_radius = max(0.01, rayon - epaisseur)
	maillage.outer_radius = rayon
	maillage.rings = 32
	maillage.ring_segments = 10
	return _instance(maillage, matiere_lumineuse(couleur, force), false)

static func _instance(maillage: Mesh, matiere_appliquee: Material, ombre: bool) -> MeshInstance3D:
	var noeud := MeshInstance3D.new()
	noeud.mesh = maillage
	noeud.material_override = matiere_appliquee
	noeud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ombre else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return noeud

# ------------------------------------------------------------ carrosserie

## Le seul maillage importé du projet : une Volvo 242, fournie en STL de
## modélisme, décimée de 44 000 à 5 900 triangles et réorientée (le STL est
## en Y-longueur/Z-hauteur, le jeu en X-avant/Y-haut). Quatre voitures et
## soixante-dix monstres dans un moteur en mode compatibilité ne supportent
## pas la densité d'origine.
##
## Le maillage est mis en cache : instancier la scène glTF à chaque voiture
## coûterait un chargement complet par joueur et par manche.
const CARROSSERIE := "res://modeles/volvo-242.glb"
static var _maillages: Dictionary = {}

## Le maillage d'un glTF, mis en cache. Instancier la scène à chaque usage
## coûterait un chargement complet par voiture et par tuile de ville.
static func maillage(chemin: String) -> Mesh:
	if not _maillages.has(chemin):
		var scene: PackedScene = load(chemin)
		var racine := scene.instantiate()
		_maillages[chemin] = _premier_maillage(racine)
		racine.queue_free()
	return _maillages[chemin]

## Une nappe de tuiles identiques en UN seul objet de rendu. Une ville de
## quatre cents tuiles posées une par une, c'est quatre cents appels de dessin
## par image — sur un moteur en mode compatibilité, dans un navigateur, ça ne
## passe pas. Regroupées par modèle, il en reste une quinzaine.
## `teinte` multiplie la texture d'origine au lieu de la remplacer : c'est ce
## qui permet de faire passer un kit d'un blanc éclatant dans une palette
## sombre sans perdre son atlas de couleurs. Un `material_override` posé avec
## une matière neuve, lui, effacerait tout le décor peint.
static func nappe(chemin: String, transformations: Array, ombre: bool = true,
		teinte: Color = Color.WHITE) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = maillage(chemin)
	multi.instance_count = transformations.size()
	for i in transformations.size():
		multi.set_instance_transform(i, transformations[i])
	var noeud := MultiMeshInstance3D.new()
	noeud.multimesh = multi
	if teinte != Color.WHITE:
		var origine := multi.mesh.surface_get_material(0)
		# glTF importé : la matière peut être une StandardMaterial3D ou une
		# ORMMaterial3D selon les canaux du fichier. Ne tester que la première
		# laissait le kit blanc, sans le moindre message d'erreur.
		if origine is BaseMaterial3D:
			var copie := (origine as BaseMaterial3D).duplicate() as BaseMaterial3D
			copie.albedo_color = teinte
			copie.roughness = 0.85
			noeud.material_override = copie
	noeud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ombre \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return noeud

const PERSONNAGE := "res://modeles/personnages/character.glb"
const PIECE := "res://modeles/personnages/coin.glb"

## Un modèle du kit, teinté sans perdre sa peinture.
##
## La teinte MULTIPLIE l'atlas : à pleine saturation elle noie les détails du
## personnage dans un aplat, donc on la ramène vers le blanc. On garde le
## modèle reconnaissable ET la couleur d'équipe lisible d'un coup d'œil.
static func modele(chemin: String, couleur: Color = Color.WHITE, force: float = 0.35) -> MeshInstance3D:
	var noeud := MeshInstance3D.new()
	noeud.mesh = maillage(chemin)
	if couleur != Color.WHITE:
		var origine := noeud.mesh.surface_get_material(0)
		if origine is BaseMaterial3D:
			var copie := (origine as BaseMaterial3D).duplicate() as BaseMaterial3D
			copie.albedo_color = couleur.lerp(Color.WHITE, force)
			noeud.material_override = copie
	return noeud

## Instancie un modèle ENTIER, avec toutes ses parties et son animation.
##
## `modele()` ne rend que le premier maillage : pour une tuile de ville, qui
## n'en a qu'un, c'est parfait et c'est ce qui permet de les grouper en nappes.
## Un personnage, lui, est fait de jambes, d'un torse, de bras et d'une
## antenne — on n'affichait qu'une jambe. Le teintage descend sur chaque
## partie, sinon seule la première change de couleur.
static func instance(chemin: String, couleur: Color = Color.WHITE, force: float = 0.35) -> Node3D:
	var racine := ((load(chemin) as PackedScene).instantiate()) as Node3D
	if couleur != Color.WHITE:
		_teinter(racine, couleur.lerp(Color.WHITE, force))
	return racine

static func _teinter(noeud: Node, teinte: Color) -> void:
	if noeud is MeshInstance3D:
		var mi := noeud as MeshInstance3D
		if mi.mesh != null and mi.mesh.get_surface_count() > 0:
			var origine := mi.mesh.surface_get_material(0)
			if origine is BaseMaterial3D:
				var copie := (origine as BaseMaterial3D).duplicate() as BaseMaterial3D
				copie.albedo_color = teinte
				mi.material_override = copie
	for enfant in noeud.get_children():
		_teinter(enfant, teinte)

static func animateur(noeud: Node) -> AnimationPlayer:
	if noeud is AnimationPlayer:
		return noeud as AnimationPlayer
	for enfant in noeud.get_children():
		var trouve := animateur(enfant)
		if trouve != null:
			return trouve
	return null

static func personnage(couleur: Color, taille: float = 3.2) -> Node3D:
	var pivot := Node3D.new()
	var corps := instance(PERSONNAGE, couleur)
	corps.scale = Vector3.ONE * taille
	corps.name = "Corps"
	pivot.add_child(corps)
	var lecteur := animateur(corps)
	if lecteur:
		lecteur.name = "Animateur"
		# Les pistes du kit ne bouclent pas d'origine : sans ça, le
		# personnage fait un pas puis se fige pour toujours.
		for nom in lecteur.get_animation_list():
			lecteur.get_animation(nom).loop_mode = Animation.LOOP_LINEAR
		lecteur.play("idle")
	return pivot

## Change la démarche sans relancer la même piste à chaque image.
static func demarche(porteur: Node3D, nom: String) -> void:
	var lecteur := animateur(porteur)
	if lecteur and lecteur.current_animation != nom:
		lecteur.play(nom, 0.2)

static func carrosserie(couleur: Color) -> MeshInstance3D:
	var noeud := MeshInstance3D.new()
	noeud.mesh = maillage(CARROSSERIE)
	# `material_override` écrase la couleur par sommet du glTF : c'est ce qui
	# permet de teindre la même carrosserie aux quatre couleurs de joueur.
	# Métallicité à zéro : en mode compatibilité il n'y a ni ciel ni sonde de
	# réflexion, alors une carrosserie métallique n'a rien à réfléchir et
	# vire au noir. On l'a vue noire sur fond de rue avant de comprendre.
	noeud.material_override = matiere(couleur, 0.45, 0.0)
	noeud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return noeud

static func _premier_maillage(noeud: Node) -> Mesh:
	if noeud is MeshInstance3D:
		return (noeud as MeshInstance3D).mesh
	for enfant in noeud.get_children():
		var trouve := _premier_maillage(enfant)
		if trouve != null:
			return trouve
	return null

# ------------------------------------------------------------ le sol

## Sol quadrillé. La trame est une texture générée, pas des milliers de traits :
## un damier de lignes en 128×128 répété par les coordonnées de texture. Sans
## repère au sol, un déplacement en perspective ne se sent pas.
## `debord` élargit le plan au-delà du terrain : une caméra inclinée regarde
## toujours un peu plus loin que l'enceinte, et sans débord elle tombe sur du
## vide noir qui coupe l'image en deux.
static func sol(taille: Vector2, pas_en_pixels: float = 100.0, teinte: Color = Color("#111110"), debord: float = 1400.0) -> MeshInstance3D:
	var plan := PlaneMesh.new()
	plan.size = Vector2((taille.x + debord) * ECHELLE, (taille.y + debord) * ECHELLE)
	plan.subdivide_width = 4
	plan.subdivide_depth = 4

	var noeud := MeshInstance3D.new()
	noeud.mesh = plan
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.albedo_texture = _texture_trame(teinte)
	m.uv1_scale = Vector3((taille.x + debord) / pas_en_pixels, (taille.y + debord) / pas_en_pixels, 1.0)
	m.roughness = 0.9
	m.metallic = 0.0
	noeud.material_override = m
	noeud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return noeud

static func _texture_trame(teinte: Color) -> ImageTexture:
	var cote := 128
	var image := Image.create(cote, cote, false, Image.FORMAT_RGBA8)
	image.fill(teinte)
	var ligne := teinte.lightened(0.28)
	for i in cote:
		image.set_pixel(i, 0, ligne)
		image.set_pixel(0, i, ligne)
		image.set_pixel(i, 1, teinte.lightened(0.10))
		image.set_pixel(1, i, teinte.lightened(0.10))
	return ImageTexture.create_from_image(image)

# ------------------------------------------------------------ ambiance

## L'ambiance : ciel, brume, exposition.
##
## Un fond de couleur unie donne un horizon plat et une lumière d'ambiance
## fausse — tout ce qui n'est pas face au soleil tombe dans le même gris. Un
## ciel dégradé coûte le même prix à l'affichage et fournit en plus l'ambiante,
## donc des ombres bleutées et des hauts de mur chauds.
static func ambiance(fond: Color = Palette.FOND, brouillard: bool = true, ambiante: float = 0.34,
		ciel: bool = true, halo: bool = true) -> WorldEnvironment:
	var environnement := Environment.new()

	if ciel:
		var matiere_ciel := ProceduralSkyMaterial.new()
		matiere_ciel.sky_top_color = Color("#0a1020")
		matiere_ciel.sky_horizon_color = Color("#25334a")
		matiere_ciel.sky_curve = 0.18
		matiere_ciel.ground_bottom_color = Color("#07090c")
		matiere_ciel.ground_horizon_color = Color("#1b2230")
		matiere_ciel.sun_angle_max = 24.0
		matiere_ciel.sun_curve = 0.08
		var voute := Sky.new()
		voute.sky_material = matiere_ciel
		environnement.background_mode = Environment.BG_SKY
		environnement.sky = voute
		environnement.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		environnement.ambient_light_sky_contribution = 1.0
		environnement.ambient_light_energy = ambiante * 2.4
	else:
		environnement.background_mode = Environment.BG_COLOR
		environnement.background_color = fond
		environnement.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environnement.ambient_light_color = Color("#1a212b")
		environnement.ambient_light_energy = ambiante

	if brouillard:
		# Le brouillard sert la profondeur : sans lui, le fond du terrain a
		# exactement le même contraste que le premier plan et la perspective
		# se lit mal.
		environnement.fog_enabled = true
		environnement.fog_light_color = Color("#131a26")
		environnement.fog_density = 0.010

	if halo:
		# Le halo ne sert pas à « faire joli » : il rend les émissifs
		# reconnaissables du premier coup d'œil — portails, phares, dalles
		# actives — là où un aplat de couleur se confond avec un mur clair.
		environnement.glow_enabled = true
		environnement.glow_intensity = 0.55
		environnement.glow_bloom = 0.08
		environnement.glow_hdr_threshold = 1.0
		environnement.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	# Sans courbe de rendu, les blancs du kit de ville s'écrasent en aplats.
	environnement.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environnement.tonemap_exposure = 1.0
	environnement.tonemap_white = 4.0

	var noeud := WorldEnvironment.new()
	noeud.environment = environnement
	return noeud

static func lumiere(energie: float = 1.12) -> DirectionalLight3D:
	var soleil := DirectionalLight3D.new()
	soleil.light_color = Color("#e8ecf5")
	soleil.light_energy = energie
	# Soleil haut : en ville, un éclairage rasant projette des ombres longues
	# dans lesquelles la voiture du joueur disparaît complètement. On perd un
	# peu de relief, on gagne de pouvoir se voir.
	soleil.rotation_degrees = Vector3(-66, -38, 0)
	# Les ombres portées sont le premier réglage qu'on coupe sur une
	# machine lente : elles se décident dans les options, pas ici.
	soleil.shadow_enabled = reglage("ombres", true)
	soleil.directional_shadow_max_distance = 260.0
	soleil.shadow_bias = 0.04
	return soleil

## Un réglage des options, lu SANS nommer l'autoload. ⚠ `Reglages` n'existe que
## dans le jeu : les ateliers et les bancs lancés en `-s script.gd` n'en ont
## pas, et une référence directe fait tomber `Decor` — donc tout ce qui s'en
## sert — en panne de compilation, sans que le message dise lequel. On va donc
## le chercher dans l'arbre, et on retombe sur la valeur d'usine s'il n'y est
## pas.
static func reglage(nom: String, defaut: bool) -> bool:
	var boucle := Engine.get_main_loop()
	if boucle == null or not (boucle is SceneTree):
		return defaut
	var noeud := (boucle as SceneTree).root.get_node_or_null("/root/Reglages")
	return bool(noeud.get(nom)) if noeud != null else defaut

## Deuxième source, froide et sans ombre, côté opposé : elle empêche les faces
## non éclairées de tomber au noir pur, où l'on ne distingue plus les volumes.
static func contre_jour() -> DirectionalLight3D:
	var lueur := DirectionalLight3D.new()
	lueur.light_color = Palette.SERIE
	lueur.light_energy = 0.30
	lueur.rotation_degrees = Vector3(-24, 145, 0)
	lueur.shadow_enabled = false
	return lueur

static func camera(inclinaison: float = 56.0, distance: float = 78.0, champ: float = 52.0) -> Camera3D:
	var cam := Camera3D.new()
	cam.fov = champ
	cam.near = 0.5
	cam.far = 900.0
	cam.rotation_degrees = Vector3(-inclinaison, 0, 0)
	cam.position = Vector3(0, sin(deg_to_rad(inclinaison)) * distance, cos(deg_to_rad(inclinaison)) * distance)
	return cam

## Place la caméra au-dessus d'un point du plan, en gardant son inclinaison.
static func viser(cam: Camera3D, point: Vector2, inclinaison: float, distance: float) -> Vector3:
	var cible := vers3d(point)
	return cible + Vector3(0, sin(deg_to_rad(inclinaison)) * distance, cos(deg_to_rad(inclinaison)) * distance)

# ------------------------------------------------------------ jauges

## Une barre de vie, posée à plat au-dessus d'un objet.
##
## Pas de panneau publicitaire : une jauge orientée vers la caméra doit être
## réancrée à gauche à chaque image, et l'ancrage se fait alors en espace
## MONDE — la barre se viderait par le milieu. À la verticale d'une caméra
## inclinée à septante degrés, un quadrilatère couché se lit très bien, et son
## remplissage est une simple mise à l'échelle locale.
static func barre(largeur: float = 3.0, couleur: Color = Palette.BON) -> Node3D:
	var racine := Node3D.new()
	racine.add_child(_plaque(largeur + 0.22, 0.62, Color(0, 0, 0, 0.55), "Fond"))
	var jauge := _plaque(largeur, 0.44, couleur, "Jauge")
	jauge.position = Vector3(0, 0.02, 0)
	racine.add_child(jauge)
	racine.set_meta("largeur", largeur)
	return racine

static func _plaque(largeur: float, profondeur: float, couleur: Color, nom: String) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(largeur, profondeur)
	var noeud := MeshInstance3D.new()
	noeud.name = nom
	noeud.mesh = quad
	noeud.rotation_degrees = Vector3(-90, 0, 0)   # couché, face au ciel
	noeud.material_override = matiere_voile(couleur, couleur.a)
	noeud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return noeud

## Remplit la jauge de la gauche vers la droite et vire au rouge quand ça
## devient sérieux — la couleur ne porte jamais seule le sens, la LONGUEUR
## reste l'information principale.
static func remplir(barre_noeud: Node3D, part: float) -> void:
	var jauge := barre_noeud.get_node_or_null("Jauge") as MeshInstance3D
	if jauge == null:
		return
	var largeur: float = barre_noeud.get_meta("largeur", 3.0)
	var reste: float = clamp(part, 0.0, 1.0)
	jauge.scale.x = max(reste, 0.001)
	jauge.position.x = -largeur * 0.5 * (1.0 - reste)
	var couleur := Palette.BON if reste > 0.55 else (Palette.AVERTISSEMENT if reste > 0.25 else Palette.CRITIQUE)
	jauge.material_override = matiere_voile(couleur, 0.95)

# ------------------------------------------------------------ étiquettes

static func etiquette(texte: String, couleur: Color = Palette.ENCRE_DOUCE, taille: int = 48) -> Label3D:
	var e := Label3D.new()
	e.text = texte
	e.font_size = taille
	e.modulate = couleur
	e.outline_size = 10
	e.outline_modulate = Color(0, 0, 0, 0.85)
	e.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	e.no_depth_test = true
	e.pixel_size = 0.022
	e.fixed_size = false
	return e
