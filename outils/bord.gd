extends Node3D
## LE BANC DE LA CORNICHE. Tout ce qui se pose AU BORD DU VIDE, dans une seule
## image : la raquette panoramique, le rond-point de corniche, le quai de dépôt,
## le chantier du bord de mer. C'est-à-dire les glissières que le kit fournit et
## que la ville ne demandait jamais.
##
## ⚠ CE QUI SE JUGE ICI, C'EST LA RAMBARDE. Elle ne se pose que là où la rue
## SURPLOMBE quelque chose ; une photo de Pikstown coûte trois minutes et montre
## la corniche gros comme un ongle. Ce banc coûte deux secondes.
##
##     ./outils/bord.sh [sortie.png]

func _ready() -> void:
	# Une presqu'île : la mer au sud et à l'ouest, la ville au nord-est.
	# Une langue de terre entre deux mers : la corniche nord en haut, la
	# corniche sud en bas, et sur chacune tout ce qui a besoin du vide.
	#   ligne 1  rue de bord, la mer AU NORD → le dépôt est au SUD : entrée
	#   ligne 8  rue de bord, la mer AU SUD  → le dépôt est au NORD : sortie
	#   col 3 et 13, ligne 9  deux éperons d'une case : les raquettes
	#   col 8,    ligne 8     le rond-point, son carré de neuf cases au ras de l'eau
	var plan := [
		"....................",
		"#########,,,,,,,,,,#",
		",,XX,,,%%,,,,,,,,,,#",
		"BBB,,,,,,,,,,,,,,,,#",
		"#######,,,,,,,,,,,,#",
		"#,,,,,#,,,,,,,,,,,,#",
		"#,,,,,#,,,,,,,,,,,,#",
		",,XX,,,,,,,,%%,,,,,#",
		"########O###########",
		"...#...,,,...#......",
		"....................",
		"....................",
	]
	var g: Array[String] = []
	for l in plan: g.append(String(l))
	var relief: Array = []
	for j in g.size():
		var l := ""
		for i in String(g[j]).length():
			l += "1"
		relief.append(l)
	var fiche := {"nom": "bord", "origine": Vector2.ZERO, "angle": 0.0, "graine": 11,
		"herbe": Color("#7f9464"), "roche": Color("#8b8578"),
		"plan": g, "relief": relief}
	for l in g: print(l)
	add_child(Quartiers.batir_fiche(fiche, "bord"))

	var mer := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60.0 * 20.0, 60.0 * 20.0)
	mer.mesh = pm
	# Le large : la MÊME matière que la nappe du rivage (posée par la passe
	# `P_EAU` du quartier), mais sans découpe — personne ne va au large, et une
	# couture de teinte à l'horizon se verrait de partout.
	mer.material_override = MatieresCarnage.eau()
	mer.position = Vector3(9.0 * 20.0, -2.85, 5.0 * 20.0)
	add_child(mer)

	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#bcd3e4")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.92, 0.95, 1.0)
	e.ambient_light_energy = 0.85
	var we := WorldEnvironment.new(); we.environment = e; add_child(we)
	var l2 := DirectionalLight3D.new()
	l2.rotation_degrees = Vector3(-38, -48, 0)
	l2.light_energy = 1.25
	l2.shadow_enabled = true
	add_child(l2)

	var sortie := "/tmp/photo/banc_bord.png"
	var recul := 9.0
	for a in OS.get_cmdline_args():
		if a.begins_with("--sortie="): sortie = a.trim_prefix("--sortie=")
		elif a.begins_with("--recul="): recul = float(a.trim_prefix("--recul="))
	var vise := Vector3(9.0 * 20.0, 0.0, 5.5 * 20.0)
	for a in OS.get_cmdline_args():
		if a.begins_with("--vise="):
			var m: PackedStringArray = a.trim_prefix("--vise=").split(",")
			vise = Vector3(float(m[0]) * 20.0, 0.0, float(m[1]) * 20.0)
	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.position = vise + Vector3(-1.0, 1.15, 2.2).normalized() * (recul * 20.0)
	add_child(cam)
	cam.look_at(vise)
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(sortie.get_base_dir())
	get_viewport().get_texture().get_image().save_png(sortie)
	get_tree().quit()
