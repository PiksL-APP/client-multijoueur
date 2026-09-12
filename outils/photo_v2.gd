extends Node3D
## PHOTOGRAPHIE LA VILLE V2. Trois caméras du cahier (§ 11) : `--vue=dessus`
## (verticale, tout le témoin), `--vue=oblique` (le diorama, 35°) et
## `--vue=derriere` (à hauteur de voiture, dans une rue). `--vise=i,j` en
## cases, `--recul=<cases>`, `--heure=0.0` (jour) … `0.5` (nuit).
##
##   ./outils/photo_v2.sh /tmp/v.png --vue=oblique --vise=20,20 --recul=18

var _images := 0
var _attendre := 10
var _sortie := "/tmp/ville2.png"

func _arg(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_args():
		if a.begins_with("--" + nom + "="):
			return a.trim_prefix("--" + nom + "=")
	return defaut

func _ready() -> void:
	_sortie = _arg("sortie", _sortie)
	_attendre = int(_arg("images", "10"))
	var heure := float(_arg("heure", "0.0"))
	MatieresCarnage.nuit_forcee = heure
	var amb: Array = MatieresCarnage.ambiance()
	for n in amb: add_child(n)
	MatieresCarnage.regler_heure(amb[0], amb[1], amb[2], heure)
	MatieresCarnage.regler_nuit(heure)
	var env: Environment = (amb[0] as WorldEnvironment).environment
	env.fog_density *= 0.04
	var soleil := amb[1] as DirectionalLight3D
	soleil.directional_shadow_max_distance = 3000.0
	# `--ambiance=diorama` : la lumière chaude et contrastée du cahier (§ 1,
	# « rendu low-poly diorama », « couchers de soleil Miami ») — un soleil
	# franc, une ambiante claire et peu bleue, des ombres nettes.
	if _arg("ambiance", "jeu") == "diorama" and heure < 0.3:
		soleil.light_color = Color("#fff3dc")
		soleil.light_energy = 1.75
		soleil.rotation_degrees = Vector3(-55.0, -30.0, 0)
		env.ambient_light_color = Color("#cfd6e4")
		env.ambient_light_energy = 0.55
		env.tonemap_exposure = 1.0
		var ciel := env.sky.sky_material as ProceduralSkyMaterial
		ciel.sky_top_color = Color("#3d8fd6")
		ciel.sky_horizon_color = Color("#bfe0f5")

	var mer := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3000.0 * Ville2.CASE, 3000.0 * Ville2.CASE)
	mer.mesh = pm
	mer.material_override = MatieresCarnage.eau()
	mer.position = Vector3(0, -2.85, 0)
	add_child(mer)

	var ville: Ville2
	var chemin := _arg("carte", "")
	if chemin != "":
		ville = Ville2.charger(chemin)
	else:
		ville = GenerateurCentre.generer(int(_arg("graine", "1")))
	var json := _arg("json", "")
	if json != "":
		ville.enregistrer(json)
		print("carte ", json, " (", ville.lots.size(), " lots, ", ville.objets.size(), " objets)")
	var t0 := Time.get_ticks_msec()
	RenduVille2.inventaire = true
	add_child(RenduVille2.batir(ville))
	print("bati en %d ms" % (Time.get_ticks_msec() - t0))

	var lx := float(ville.taille.x) * Ville2.CASE
	var lz := float(ville.taille.y) * Ville2.CASE
	var cam := Camera3D.new()
	cam.far = 60000.0
	add_child(cam)
	var vise := Vector3(lx * 0.5, 0, lz * 0.5)
	var m: PackedStringArray = _arg("vise", "").split(",")
	if m.size() == 2:
		vise = Vector3(float(m[0]) * Ville2.CASE, 0, float(m[1]) * Ville2.CASE)
	var recul := float(_arg("recul", str(maxf(lx, lz) / Ville2.CASE * 0.78))) * Ville2.CASE
	var vue := _arg("vue", "dessus")
	var az := deg_to_rad(float(_arg("oblique", "35")))
	match vue:
		"oblique":
			cam.fov = 42.0
			var pente := float(_arg("pente", "0.6"))
			cam.look_at_from_position(vise + Vector3(sin(az) * recul, recul * pente, cos(az) * recul),
				vise + Vector3(0, 10.0, 0), Vector3.UP)
		"derriere":
			# À hauteur de voiture : 8 unités au-dessus du sol, à `recul` derrière.
			cam.fov = 60.0
			cam.look_at_from_position(vise + Vector3(sin(az) * recul, 8.0, cos(az) * recul),
				vise + Vector3(0, 6.0, 0), Vector3.UP)
		_:
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = recul * 1.34
			cam.look_at_from_position(Vector3(vise.x, 9000.0, vise.z + 0.1), vise, Vector3(0, 0, -1))
	cam.make_current()
	get_tree().process_frame.connect(_declic)

func _declic() -> void:
	_images += 1
	if _images < _attendre: return
	DirAccess.make_dir_recursive_absolute(_sortie.get_base_dir())
	get_viewport().get_texture().get_image().save_png(_sortie)
	print("photo ", _sortie)
	get_tree().quit()
