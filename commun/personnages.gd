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

static var _bibliotheque: AnimationLibrary = null
static var _matieres: Dictionary = {}
static var _portraits: Dictionary = {}

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
static func creer(cle: String, echelle: float = ECHELLE) -> Node3D:
	var racine := (load(MODELE) as PackedScene).instantiate() as Node3D
	racine.scale = Vector3.ONE * echelle
	habiller(racine, cle)

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
