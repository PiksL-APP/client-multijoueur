class_name Personnages
extends RefCounted
## Le casting du jeu : douze habitants de Sunport, tous taillés dans le même
## bonhomme articulé.
##
## Les trois lots Kenney « animated characters » (protagonists, retro,
## survivors, CC0) partagent EXACTEMENT le même maillage et le même squelette
## de 58 os : `characterMedium.fbx`. Ce qui change d'un personnage à l'autre,
## c'est une image de 256 pixels dépliée sur le corps. Un seul modèle, douze
## textures — c'est ce qui permet d'embarquer tout le casting pour le poids
## d'un personnage, et de n'animer qu'un squelette.
##
## Les animations vivent dans leurs propres fichiers (`idle`, `run`, `jump`),
## sans maillage : on les greffe sur le bonhomme à la volée. Leurs pistes
## visent `Root/Skeleton3D:NomDeLOs` — donc un lecteur posé en enfant de la
## racine du modèle, avec `root_node` sur `..`, les résout sans rien réécrire.
##
## Godot 4.5 lit le FBX nativement (ufbx) : aucune conversion préalable, les
## fichiers du lot sont dans le dépôt tels que Kenney les publie.

const DOSSIER := "res://modeles/kenney/"
const MODELE := DOSSIER + "characterMedium.fbx"
const PEAUX := DOSSIER + "peaux/"

## Le modèle Kenney sort à près de quatre unités de haut — le chargeur FBX
## applique déjà son échelle de racine. Ramené ici, le bonhomme mesure 1,80
## unité : la taille d'un homme dans une ville dont la tuile en fait dix.
const ECHELLE := 0.47

## nom d'animation dans le jeu -> [fichier, nom de la piste dans le fichier, boucle]
const ANIMATIONS := {
	"repos": ["idle.fbx", "Root|Idle", true],
	"course": ["run.fbx", "Root|Run", true],
	"saut": ["jump.fbx", "Root|Jump", false],
}

## Le casting, dans l'ordre où il s'affiche. `cle` est ce qu'on écrit dans
## l'identité du joueur et ce qui voyage sur le réseau : il ne change jamais.
const LISTE: Array[Dictionary] = [
	{"cle": "criminalMaleA", "nom": "Le Braqueur", "lot": "Protagonistes"},
	{"cle": "skaterFemaleA", "nom": "La Skateuse", "lot": "Protagonistes"},
	{"cle": "skaterMaleA", "nom": "Le Skateur", "lot": "Protagonistes"},
	{"cle": "cyborgFemaleA", "nom": "La Cyborg", "lot": "Protagonistes"},
	{"cle": "humanMaleA", "nom": "Le Passant", "lot": "Rétro"},
	{"cle": "humanFemaleA", "nom": "La Passante", "lot": "Rétro"},
	{"cle": "survivorMaleB", "nom": "Le Survivant", "lot": "Survivants"},
	{"cle": "survivorFemaleA", "nom": "La Survivante", "lot": "Survivants"},
	{"cle": "zombieMaleA", "nom": "Le Revenant", "lot": "Rétro"},
	{"cle": "zombieFemaleA", "nom": "La Revenante", "lot": "Rétro"},
	{"cle": "zombieA", "nom": "L'Infecté", "lot": "Survivants"},
	{"cle": "zombieC", "nom": "Le Putréfié", "lot": "Survivants"},
]

## Le visage dans l'image de peau, en pixels de la texture de 256. Le dépliage
## est le même pour les douze — c'est le même maillage — donc une seule fenêtre
## suffit à en tirer douze portraits, sans rien rendre en 3D.
const VISAGE := Rect2(64, 26, 56, 56)

## LE CARTON SUR LA TÊTE. Tout le monde à Pikstown porte une boîte en kraft
## sur le crâne, avec un logo au marqueur sur la face avant — c'est ça, le
## visage qu'on choisit, et c'est ce qui se lit d'une caméra qui regarde de
## haut. Les logos sont sur une seule planche (`outils/cartons.py`) : 8 × 8
## tuiles de 128, les 55 premières dessinées, puis le carton nu, le dessus
## avec son ruban et le dessous avec ses rabats. Une texture, une matière,
## et un petit maillage par logo — six faces qui piochent chacune leur tuile.
const CARTONS := "res://modeles/cartons/"
const PLANCHE := CARTONS + "planche.png"
const CATALOGUE := CARTONS + "cartons.json"
const COLONNES := 8
const TUILE_NU := 55
const TUILE_DESSUS := 56
const TUILE_DESSOUS := 57
## La boîte, dans l'espace de l'os `Head` : là, une unité vaut cent unités
## du modèle brut (la racine `Root` porte l'échelle ×100), et le crâne va de
## l'origine à 0,010 le long de Y, large de 0,009, profond de 0,010. La boîte
## l'enferme au plus juste — un carton de déménagement, pas un frigo — et
## descend sur le menton.
const CARTON_DEMI := Vector3(0.0054, 0.0058, 0.0058)
const CARTON_CENTRE := Vector3(0.0, 0.0052, 0.0)
## Le sommet de la boîte, en unités du modèle brut, depuis les pieds : c'est
## là que se pose ce qu'on met par-dessus (la casquette d'un gang).
const SOMMET_CARTON := 2.7 + (CARTON_CENTRE.y + CARTON_DEMI.y) * 100.0

static var _bibliotheque: AnimationLibrary = null
static var _matieres: Dictionary = {}
static var _portraits: Dictionary = {}
static var _cartons: Array = []
static var _matiere_carton: StandardMaterial3D = null
static var _boites: Dictionary = {}

## Le portrait d'un personnage : sa peau recadrée sur le visage. Douze petites
## fenêtres 3D côte à côte coûteraient douze mondes et douze caméras ; ici on
## découpe une texture déjà chargée.
static func portrait(cle: String) -> Texture2D:
	if _portraits.has(cle):
		return _portraits[cle]
	var atlas := AtlasTexture.new()
	var chemin := PEAUX + cle + ".png"
	if ResourceLoader.exists(chemin):
		atlas.atlas = load(chemin)
		atlas.region = VISAGE
	_portraits[cle] = atlas
	return atlas

## Vrai si la clé désigne quelqu'un du casting.
static func existe(cle: String) -> bool:
	for fiche in LISTE:
		if fiche["cle"] == cle:
			return true
	return false

static func fiche(cle: String) -> Dictionary:
	for f in LISTE:
		if f["cle"] == cle:
			return f
	return LISTE[0]

static func nom(cle: String) -> String:
	return String(fiche(cle)["nom"])

## Le personnage qu'un identifiant désigne par défaut, quand le joueur n'a
## rien choisi. Le calcul est le même chez tous les clients : chacun voit
## l'autre sous le même trait.
static func par_defaut(identifiant: String) -> String:
	return String(LISTE[absi(identifiant.hash()) % LISTE.size()]["cle"])

## Un personnage prêt à poser : le maillage, sa peau, son squelette et un
## lecteur d'animations qui connaît « repos », « course » et « saut ».
## Le nœud rendu est à l'échelle du jeu, les pieds sur le zéro.
## `carton` est l'indice du logo sur la boîte ; en dessous de zéro, c'est la
## peau qui le désigne — le même calcul partout, donc le même carton partout.
static func creer(cle: String, echelle: float = ECHELLE, carton: int = -1) -> Node3D:
	var racine := (load(MODELE) as PackedScene).instantiate() as Node3D
	racine.scale = Vector3.ONE * echelle
	habiller(racine, cle)
	coiffer(racine, carton if carton >= 0 else carton_par_defaut(cle))

	var lecteur := AnimationPlayer.new()
	lecteur.name = "Animations"
	# `..` : la racine du modèle, celle qui porte `Root/Skeleton3D` — le
	# chemin que visent les pistes des fichiers d'animation.
	lecteur.root_node = NodePath("..")
	lecteur.add_animation_library("", _lire_les_animations())
	racine.add_child(lecteur)
	lecteur.play("repos")
	return racine

## Change la peau d'un personnage déjà posé, sans le reconstruire : c'est ce
## qui fait défiler le casting sans à-coup dans l'écran de création.
static func habiller(racine: Node3D, cle: String) -> void:
	var maillage := racine.get_node_or_null("Root/Skeleton3D/characterMedium") as MeshInstance3D
	if maillage == null:
		return
	maillage.set_surface_override_material(0, matiere(cle))

## Les matières sont partagées : douze personnages de la même peau à l'écran
## ne coûtent qu'un envoi de texture.
static func matiere(cle: String) -> StandardMaterial3D:
	if _matieres.has(cle):
		return _matieres[cle]
	var m := StandardMaterial3D.new()
	var chemin := PEAUX + cle + ".png"
	if ResourceLoader.exists(chemin):
		m.albedo_texture = load(chemin)
	# Les peaux Kenney sont des aplats : un filtre au plus proche garde les
	# arêtes franches et va avec la typographie pixel du reste du jeu.
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	_matieres[cle] = m
	return m

## Les trois animations, lues une fois pour toute la partie.
static func _lire_les_animations() -> AnimationLibrary:
	if _bibliotheque != null:
		return _bibliotheque
	_bibliotheque = AnimationLibrary.new()
	for nom_jeu in ANIMATIONS:
		var f: Array = ANIMATIONS[nom_jeu]
		var scene := (load(DOSSIER + String(f[0])) as PackedScene).instantiate()
		var lecteur := scene.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if lecteur != null and lecteur.has_animation(String(f[1])):
			var animation: Animation = lecteur.get_animation(String(f[1])).duplicate()
			animation.loop_mode = Animation.LOOP_LINEAR if bool(f[2]) else Animation.LOOP_NONE
			_bibliotheque.add_animation(nom_jeu, animation)
		scene.queue_free()
	return _bibliotheque

# ── Le carton ────────────────────────────────────────────────────────────

## Le catalogue des logos : indice, clé, nom, phrase, groupe — celui que le
## kit web affiche aussi, dans le même ordre. Lu une fois.
static func cartons() -> Array:
	if not _cartons.is_empty():
		return _cartons
	var texte := ""
	if ResourceLoader.exists(CATALOGUE):
		var res = load(CATALOGUE)
		if res is JSON and (res as JSON).data is Array:
			_cartons = (res as JSON).data
			return _cartons
	if FileAccess.file_exists(CATALOGUE):
		texte = FileAccess.get_file_as_string(CATALOGUE)
	var lu = JSON.parse_string(texte)
	if lu is Array and not (lu as Array).is_empty():
		_cartons = lu
	else:
		_cartons = [{"indice": 0, "cle": "couronne", "nom": "Le Roi", "phrase": "", "groupe": "tag"}]
	return _cartons

## Combien de logos on peut porter.
static func nombre_de_cartons() -> int:
	return cartons().size()

## La fiche d'un logo, l'indice ramené dans le catalogue.
static func carton(indice: int) -> Dictionary:
	var liste := cartons()
	return liste[posmod(indice, liste.size())]

## Le logo qu'une chaîne désigne par défaut — un identifiant de joueur, une
## peau. Le calcul est le même chez tous les clients.
static func carton_par_defaut(graine: String) -> int:
	return absi(graine.hash()) % nombre_de_cartons()

## Le logo qu'un nombre désigne — l'identifiant d'un passant.
static func carton_de_graine(graine: int) -> int:
	return posmod(graine * 31 + 7, nombre_de_cartons())

## Pose la boîte sur la tête : attachée à l'os `Head`, elle suit le crâne dans
## toutes les animations. Rappelée sur un personnage déjà coiffé, elle change
## de logo sans rien reconstruire.
static func coiffer(racine: Node3D, indice: int) -> void:
	var squelette := racine.get_node_or_null("Root/Skeleton3D") as Skeleton3D
	if squelette == null:
		return
	var attache := squelette.get_node_or_null("Carton") as BoneAttachment3D
	if attache == null:
		attache = BoneAttachment3D.new()
		attache.name = "Carton"
		attache.bone_name = "Head"
		squelette.add_child(attache)
		var boite := MeshInstance3D.new()
		boite.name = "Boite"
		boite.material_override = matiere_carton()
		attache.add_child(boite)
	var boite := attache.get_node("Boite") as MeshInstance3D
	boite.mesh = maillage_carton(posmod(indice, nombre_de_cartons()))

## Le logo qu'un personnage porte, ou -1 s'il a la tête nue.
static func carton_de(racine: Node3D) -> int:
	var boite := racine.get_node_or_null("Root/Skeleton3D/Carton/Boite") as MeshInstance3D
	if boite == null or boite.mesh == null:
		return -1
	return int(boite.mesh.get_meta("carton", -1))

## Une matière pour toutes les boîtes : la planche entière, un filtre doux
## avec ses mipmaps — vue de haut, une boîte fait vingt pixels.
static func matiere_carton() -> StandardMaterial3D:
	if _matiere_carton != null:
		return _matiere_carton
	var m := StandardMaterial3D.new()
	if ResourceLoader.exists(PLANCHE):
		m.albedo_texture = load(PLANCHE)
	else:
		m.albedo_color = Color(0.79, 0.63, 0.43)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	_matiere_carton = m
	return m

## La boîte d'un logo : six faces, chacune sur sa tuile de la planche. Le
## logo devant (+Z, là où le bonhomme regarde), le ruban dessus, les rabats
## dessous, du kraft nu partout ailleurs. Une par logo, gardée.
static func maillage_carton(indice: int) -> ArrayMesh:
	if _boites.has(indice):
		return _boites[indice]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var d := CARTON_DEMI
	# (normale, droite vue de dehors, haut vu de dehors, tuile). Droite × haut
	# = normale : les sommets tournent dans le sens des aiguilles vus de
	# l'extérieur, le sens des faces avant en Godot.
	var faces := [
		[Vector3.FORWARD * -1.0, Vector3.RIGHT, Vector3.UP, indice],       # devant : +Z
		[Vector3.FORWARD, Vector3.LEFT, Vector3.UP, TUILE_NU],              # derrière : -Z
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP, TUILE_NU],             # +X
		[Vector3.LEFT, Vector3.FORWARD * -1.0, Vector3.UP, TUILE_NU],       # -X
		[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD, TUILE_DESSUS],         # dessus
		[Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD * -1.0, TUILE_DESSOUS], # dessous
	]
	var marge := 0.5 / (128.0 * COLONNES)
	for f in faces:
		var n: Vector3 = f[0]
		var droite: Vector3 = f[1] * Vector3(d.x, d.y, d.z).dot(f[1].abs())
		var haut: Vector3 = f[2] * Vector3(d.x, d.y, d.z).dot(f[2].abs())
		var centre: Vector3 = CARTON_CENTRE + n * Vector3(d.x, d.y, d.z).dot(n.abs())
		var t := int(f[3])
		var u0 := float(t % COLONNES) / COLONNES + marge
		var v0 := floorf(t / float(COLONNES)) / COLONNES + marge
		var u1 := u0 + 1.0 / COLONNES - 2.0 * marge
		var v1 := v0 + 1.0 / COLONNES - 2.0 * marge
		var coins := [centre - droite + haut, centre + droite + haut, centre + droite - haut, centre - droite - haut]
		var uvs := [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_uv(uvs[k])
			st.add_vertex(coins[k])
	var maillage := st.commit()
	maillage.set_meta("carton", indice)
	_boites[indice] = maillage
	return maillage
