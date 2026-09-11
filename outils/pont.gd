extends Node3D
## LE BANC DU PONT. Un chenal, un tablier, vus DE PRÈS ET DE BIAIS.
##
## ⚠ UN PONT NE SE JUGE PAS D'AVION. Vu du dessus, on ne voit que la chaussée
## et tout va bien ; c'est par-dessous que se voient les piles, le chevêtre, la
## culée — c'est-à-dire tout ce qui fait qu'un pont ressemble à un pont plutôt
## qu'à une table. Photographier Pikstown coûte quarante-cinq secondes et donne
## la mauvaise image ; ce banc en coûte deux et donne la bonne.
##
##     ./outils/pont.sh [sortie.png]

func _ready() -> void:
	var plan := [
		",,,,,,,,,,,,,,",
		",,,,,,,,,,,,,,",
		"####,,,,,,####",
		"#TT#,,,,,,#BB#",
		"#TT#,,,,,,#BB#",
		"####,,,,,,####",
		",,,,,,,,,,,,,,",
		",,,,,,,,,,,,,,",
	]
	# Le chenal : six cases d'eau en travers, et le pont qui les franchit.
	var g: Array[String] = []
	for l in plan: g.append(String(l))
	for j in g.size():
		var t: String = g[j]
		var n := ""
		for i in t.length():
			var c := t[i]
			if i >= 4 and i <= 9:
				n += "=" if j == 4 else "."
			else:
				n += c
		g[j] = n
	var relief: Array = []
	for j in g.size():
		var l := ""
		for i in String(g[j]).length():
			l += "0" if (i >= 4 and i <= 9) else "1"
		relief.append(l)
	var fiche := {"nom": "pont", "origine": Vector2.ZERO, "angle": 0.0, "graine": 3,
		"herbe": Color("#7f9464"), "roche": Color("#8b8578"),
		"plan": g, "relief": relief}
	for l in g: print(l)
	add_child(Quartiers.batir_fiche(fiche, "pont"))

	var mer := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40.0 * 20.0, 40.0 * 20.0)
	mer.mesh = pm
	# Le large : la MÊME matière que la nappe du rivage (posée par la passe
	# `P_EAU` du quartier), mais sans découpe — personne ne va au large, et une
	# couture de teinte à l'horizon se verrait de partout.
	mer.material_override = MatieresCarnage.eau()
	mer.position = Vector3(7.0 * 20.0, -2.85, 4.0 * 20.0)
	add_child(mer)

	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#bcd3e4")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.92, 0.95, 1.0)
	e.ambient_light_energy = 0.85
	var we := WorldEnvironment.new(); we.environment = e; add_child(we)
	var l2 := DirectionalLight3D.new()
	l2.rotation_degrees = Vector3(-34, -52, 0)
	l2.light_energy = 1.25
	l2.shadow_enabled = true
	add_child(l2)

	var sortie := "/tmp/photo/banc_pont.png"
	for a in OS.get_cmdline_args():
		if a.begins_with("--sortie="): sortie = a.trim_prefix("--sortie=")
	var vise := Vector3(7.0 * 20.0, -2.0, 4.5 * 20.0)
	var cam := Camera3D.new()
	cam.fov = 36.0
	cam.position = vise + Vector3(-2.2, 1.5, 4.4).normalized() * (5.6 * 20.0)
	add_child(cam)
	cam.look_at(vise)
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(sortie.get_base_dir())
	get_viewport().get_texture().get_image().save_png(sortie)
	get_tree().quit()
