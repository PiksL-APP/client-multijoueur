extends Node3D
## UN MORCEAU DE LA VILLE PROCÉDURALE, PHOTOGRAPHIÉ.
##
## La ville de Carnage n'avait aucun banc : on ne la voyait qu'en jouant, donc
## seulement là où le hasard d'une manche menait. C'est ainsi que quatre
## carrosseries du Car Kit sont restées inutilisées et qu'un port sans bateaux
## n'a choqué personne.
##
## Ici on bâtit UN morceau, à l'endroit demandé, avec l'ambiance du jeu, et on
## le regarde d'en haut.
##
##   outils/apercu.sh [code] [sortie] [x,y en tuiles | port] [hauteur]

const INCLINAISON := 62.0

var _sortie := "/tmp/apercu/ville.png"
var _images := 0
var _attente := 20

func _ready() -> void:
	var code := "APERCU"
	var ou := "port"
	var hauteur := 420.0
	var nuit := 0.35
	for a in OS.get_cmdline_args():
		if a.begins_with("--code="): code = a.trim_prefix("--code=")
		if a.begins_with("--sortie="): _sortie = a.trim_prefix("--sortie=")
		if a.begins_with("--ou="): ou = a.trim_prefix("--ou=")
		if a.begins_with("--hauteur="): hauteur = float(a.trim_prefix("--hauteur="))
		if a.begins_with("--nuit="): nuit = clampf(float(a.trim_prefix("--nuit=")), 0.0, 1.0)

	MatieresCarnage.nuit_forcee = nuit
	var carte := PlanVille.new(code)
	var amb := MatieresCarnage.ambiance()
	for n in amb:
		add_child(n)
	MatieresCarnage.regler_heure(amb[0], amb[1], amb[2], nuit)
	MatieresCarnage.regler_nuit(nuit)
	MatieresCarnage.sol().set_shader_parameter("rail", carte.rail())
	MatieresCarnage.sol().set_shader_parameter("lignes", carte.lignes_libres())
	MatieresCarnage.sol().set_shader_parameter("origines", carte.origines_libres())
	MatieresCarnage.sol().set_shader_parameter("anneaux", carte.anneaux_libres())
	MatieresCarnage.sol().set_shader_parameter("etoiles", carte.etoiles_libres())

	var tuile := _viser(carte, ou)
	print("[aperçu] %s — tuile (%d, %d)" % [code, tuile.x, tuile.y])
	var cle := Vector2i(tuile.x / PlanVille.MORCEAU, tuile.y / PlanVille.MORCEAU)
	# Le morceau et ses huit voisins : un morceau seul laisse un trou noir tout
	# autour, et on ne juge plus rien.
	for dj in range(-1, 2):
		for di in range(-1, 2):
			var m := MorceauVille.new()
			add_child(m)
			m.batir(carte, cle + Vector2i(di, dj), {})

	var cam := Decor.camera(INCLINAISON, 1.0, 52.0)
	add_child(cam)
	cam.far = 4000.0
	cam.make_current()
	var vise := Decor.vers3d(PlanVille.centre_tuile(tuile.x, tuile.y))
	cam.position = vise + Vector3(0.0, sin(deg_to_rad(INCLINAISON)) * hauteur,
		cos(deg_to_rad(INCLINAISON)) * hauteur)
	get_tree().process_frame.connect(_photographier)

## `port` : la première case d'eau qui porte un bateau amarré — c'est ce qu'on
## veut voir, et le chercher à la main sur six cent quatre-vingts tuiles n'est
## pas une façon de travailler.
func _viser(carte: PlanVille, ou: String) -> Vector2i:
	if ou != "port":
		var xy := ou.split(",")
		if xy.size() == 2:
			return Vector2i(int(xy[0]), int(xy[1]))
	for l in range(120, 400):
		for c in range(120, 560):
			if not carte.eau(c, l):
				continue
			if not (carte.tuile(c, l)["places"] as Array).is_empty():
				return Vector2i(c, l)
	return Vector2i(340, 260)

func _photographier() -> void:
	_images += 1
	if _images < _attente:
		return
	DirAccess.make_dir_recursive_absolute(_sortie.get_base_dir())
	get_viewport().get_texture().get_image().save_png(_sortie)
	print("photo ", _sortie)
	get_tree().quit()
