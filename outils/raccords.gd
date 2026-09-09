extends SceneTree
## RACCORDS : chaque pièce à l'essai, entourée de quatre tronçons droits aux
## quatre points cardinaux. La pièce raccorde ce qu'elle raccorde ; il suffit
## de regarder quels bras se prolongent. C'est la seule façon SÛRE de connaître
## l'orientation d'origine d'une tuile — la lire sur une planche isolée mène à
## des raccords faux qui ne se voient qu'une fois la ville bâtie.
## `road-straight` va selon X (bandes de trottoir en haut et en bas) : les bras
## est/ouest sont donc à l'endroit, les bras nord/sud d'un quart de tour.

const R := "res://modeles/kenney/routes/"
const PAS := 6.0
const PAR_LIGNE := 3

## nom, demi-emprise en cases (1 pour une tuile 1x1, 2 pour une 2x2, 3 pour 3x3)
const ESSAIS := [
	["road-bend", 1], ["road-intersection", 1], ["road-end-round", 1],
	["road-split", 1], ["road-side", 1], ["road-side-entry", 1],
	["road-curve", 2], ["road-curve-intersection", 2], ["road-roundabout", 3],
]

var _images := 0
var _sortie := "/tmp/raccords.png"

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="): _sortie = a.substr(9)
	var racine := Node3D.new()
	root.add_child(racine)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#20242a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#c8d4e2")
	e.ambient_light_energy = 1.0
	env.environment = e
	racine.add_child(env)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-70, -30, 0)
	racine.add_child(soleil)

	for i in ESSAIS.size():
		var nom: String = ESSAIS[i][0]
		var emp: int = ESSAIS[i][1]
		var c := Vector3((i % PAR_LIGNE) * PAS, 0, (i / PAR_LIGNE) * PAS)
		_poser(racine, nom, c, 0)
		var d := (float(emp) + 1.0) * 0.5      # où commence le premier bras
		for k in 2:
			_poser(racine, "road-straight", c + Vector3(d + k, 0, 0), 0)
			_poser(racine, "road-straight", c - Vector3(d + k, 0, 0), 0)
			_poser(racine, "road-straight", c + Vector3(0, 0, d + k), 1)
			_poser(racine, "road-straight", c - Vector3(0, 0, d + k), 1)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = PAR_LIGNE * PAS + 1.0
	var lignes := ceili(float(ESSAIS.size()) / PAR_LIGNE)
	var centre := Vector3((PAR_LIGNE - 1) * PAS * 0.5, 0, (lignes - 1) * PAS * 0.5)
	racine.add_child(cam)
	cam.look_at_from_position(centre + Vector3(0, 60, 0.01), centre, Vector3.UP)
	cam.make_current()
	process_frame.connect(_image)

func _poser(racine: Node3D, nom: String, ou: Vector3, quarts: int) -> void:
	var chemin := R + nom + ".glb"
	if not ResourceLoader.exists(chemin): return
	var n := MeshInstance3D.new()
	n.mesh = FormesCarnage.maillage_kenney(chemin, 0.0, Vector3.AXIS_X, 0.0)
	n.material_override = FormesCarnage.matiere_kenney(chemin)
	n.transform = Transform3D(Basis(Vector3.UP, PI * 0.5 * float(quarts)), ou)
	racine.add_child(n)

func _image() -> void:
	_images += 1
	if _images == 8:
		root.get_viewport().get_texture().get_image().save_png(_sortie)
		print("raccords ", _sortie)
		quit()
