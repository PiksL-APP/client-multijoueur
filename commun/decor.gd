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

# ------------------------------------------------------------ le sol

## Sol quadrillé. La trame est une texture générée, pas des milliers de traits :
## un damier de lignes en 128×128 répété par les coordonnées de texture. Sans
## repère au sol, un déplacement en perspective ne se sent pas.
static func sol(taille: Vector2, pas_en_pixels: float = 100.0, teinte: Color = Color("#111110")) -> MeshInstance3D:
	var plan := PlaneMesh.new()
	plan.size = Vector2(taille.x * ECHELLE, taille.y * ECHELLE)
	plan.subdivide_width = 4
	plan.subdivide_depth = 4

	var noeud := MeshInstance3D.new()
	noeud.mesh = plan
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.albedo_texture = _texture_trame(teinte)
	m.uv1_scale = Vector3(taille.x / pas_en_pixels, taille.y / pas_en_pixels, 1.0)
	m.roughness = 0.9
	m.metallic = 0.0
	noeud.material_override = m
	noeud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return noeud

static func _texture_trame(teinte: Color) -> ImageTexture:
	var cote := 128
	var image := Image.create(cote, cote, false, Image.FORMAT_RGBA8)
	image.fill(teinte)
	var ligne := teinte.lightened(0.12)
	for i in cote:
		image.set_pixel(i, 0, ligne)
		image.set_pixel(0, i, ligne)
		image.set_pixel(i, 1, teinte.lightened(0.05))
		image.set_pixel(1, i, teinte.lightened(0.05))
	return ImageTexture.create_from_image(image)

# ------------------------------------------------------------ ambiance

static func ambiance(fond: Color = Palette.FOND, brouillard: bool = true) -> WorldEnvironment:
	var environnement := Environment.new()
	environnement.background_mode = Environment.BG_COLOR
	environnement.background_color = fond
	environnement.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# L'ambiante reste basse et à peine bleutée : montée trop haut, elle
	# éclaircit le sol jusqu'à un gris bleu qui n'est plus le #0d0d0d de la
	# palette, et toute la maison se reconnaît à ce noir-là.
	environnement.ambient_light_color = Color("#1a212b")
	environnement.ambient_light_energy = 0.22
	if brouillard:
		# Le brouillard sert la profondeur : sans lui, le fond du terrain a
		# exactement le même contraste que le premier plan et la perspective
		# se lit mal.
		environnement.fog_enabled = true
		environnement.fog_light_color = fond
		environnement.fog_density = 0.012
	var noeud := WorldEnvironment.new()
	noeud.environment = environnement
	return noeud

static func lumiere() -> DirectionalLight3D:
	var soleil := DirectionalLight3D.new()
	soleil.light_color = Color("#e8ecf5")
	soleil.light_energy = 1.05
	soleil.rotation_degrees = Vector3(-52, -38, 0)
	soleil.shadow_enabled = true
	soleil.directional_shadow_max_distance = 260.0
	soleil.shadow_bias = 0.04
	return soleil

## Deuxième source, froide et sans ombre, côté opposé : elle empêche les faces
## non éclairées de tomber au noir pur, où l'on ne distingue plus les volumes.
static func contre_jour() -> DirectionalLight3D:
	var lueur := DirectionalLight3D.new()
	lueur.light_color = Palette.SERIE
	lueur.light_energy = 0.22
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
