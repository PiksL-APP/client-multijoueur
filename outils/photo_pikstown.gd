extends Node3D
## Photographie la grande île d'un seul coup, à la verticale. C'est le seul
## moyen de juger un dessin de 48 000 cases : à hauteur d'homme on ne voit
## qu'un pâté, et dans l'éditeur on ne voit que la mini-carte.

var _images := 0
var _attendre := 10
var _sortie := "/tmp/pikstown.png"

func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--sortie="): _sortie = a.trim_prefix("--sortie=")
		if a.begins_with("--images="): _attendre = int(a.trim_prefix("--images="))
	var fiche: Dictionary = Quartiers.CATALOGUE["pikstown"]
	# ⚠ L'HEURE SE CHOISIT. Le banc photographiait toujours à 0,12 — l'aube :
	# tout sortait bleu nuit, et un défaut de chaussée ne se voit pas dans le
	# bleu. `--heure=0.5` donne le plein jour, qui est l'heure où l'on juge.
	var heure := 0.12
	for a in OS.get_cmdline_args():
		if a.begins_with("--heure="): heure = float(a.trim_prefix("--heure="))
	MatieresCarnage.nuit_forcee = heure
	var amb: Array = MatieresCarnage.ambiance()
	for n in amb: add_child(n)
	MatieresCarnage.regler_heure(amb[0], amb[1], amb[2], heure)
	MatieresCarnage.regler_nuit(heure)
	var env: Environment = (amb[0] as WorldEnvironment).environment
	env.fog_density *= 0.04
	(amb[1] as DirectionalLight3D).directional_shadow_max_distance = 9000.0

	# ⚠ LE LARGE ET LE RIVAGE NE SONT PAS LA MÊME EAU. Le rivage est bâti par
	# la passe `P_EAU` du quartier — une nappe découpée en facettes, qui ondule.
	# Le large, lui, n'a pas besoin d'onduler : personne n'y va. Il garde donc
	# un aplat, mais AVEC LA MÊME MATIÈRE, sinon la couture se voit à dix
	# kilomètres. Il se pose un poil plus bas pour que la houle du rivage passe
	# par-dessus au lieu de batailler avec lui au pixel près.
	var mer := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3000.0 * Quartiers.CASE, 3000.0 * Quartiers.CASE)
	mer.mesh = pm
	mer.material_override = MatieresCarnage.eau()
	mer.position = Vector3(0, -2.85, 0)
	add_child(mer)

	var t0 := Time.get_ticks_msec()
	add_child(Quartiers.batir_fiche(fiche, "pikstown"))
	print("bati en %d ms" % (Time.get_ticks_msec() - t0))

	# ⚠ LA TAILLE VIENT DU DESSIN, elle n'est pas écrite ici. Le banc a menti une
	# fois, en cadrant 225 × 215 sur une ville qui en faisait 320 × 300 : le
	# tiers de la carte était hors champ et rien ne le disait.
	var large := 0
	for ligne in fiche["plan"]:
		large = maxi(large, String(ligne).length())
	var lx := float(large) * Quartiers.CASE
	var lz := float((fiche["plan"] as Array).size()) * Quartiers.CASE
	var cam := Camera3D.new()
	cam.far = 60000.0
	add_child(cam)
	var vise := Vector3(lx * 0.5, 0, lz * 0.5)
	# `--vise=i,j` en CASES et `--recul=<cases>` : sans eux, la seule vue
	# possible est celle de toute la ville, où cinq paliers de dénivelé ne font
	# qu'un frisson. Le relief se juge sur un quartier, pas sur une carte.
	var recul := maxf(lx, lz) * 0.78
	for a in OS.get_cmdline_args():
		if a.begins_with("--vise="):
			var m: PackedStringArray = a.trim_prefix("--vise=").split(",")
			if m.size() == 2:
				vise = Vector3(float(m[0]) * Quartiers.CASE, 0, float(m[1]) * Quartiers.CASE)
		if a.begins_with("--recul="):
			recul = float(a.trim_prefix("--recul=")) * Quartiers.CASE
	# `--oblique=<azimut°>` : une vue rasante, la seule où le RELIEF se lit. Vue
	# du dessus à la verticale, une ville en pente et une ville plate rendent
	# exactement la même image.
	var oblique := -1.0
	for a in OS.get_cmdline_args():
		if a.begins_with("--oblique="): oblique = float(a.trim_prefix("--oblique="))
	if oblique >= 0.0:
		cam.fov = 42.0
		var az := deg_to_rad(oblique)
		var pente := 0.36
		for a2 in OS.get_cmdline_args():
			if a2.begins_with("--pente="): pente = float(a2.trim_prefix("--pente="))
		cam.look_at_from_position(vise + Vector3(sin(az) * recul, recul * pente, cos(az) * recul),
			vise + Vector3(0, 20.0, 0), Vector3.UP)
	else:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = maxf(lx, lz) * 1.04
		cam.look_at_from_position(Vector3(lx * 0.5, 9000.0, lz * 0.5 + 0.1),
			vise, Vector3(0, 0, -1))
	cam.make_current()
	get_tree().process_frame.connect(_declic)

func _declic() -> void:
	_images += 1
	if _images < _attendre: return
	DirAccess.make_dir_recursive_absolute(_sortie.get_base_dir())
	get_viewport().get_texture().get_image().save_png(_sortie)
	print("photo ", _sortie)
	get_tree().quit()
