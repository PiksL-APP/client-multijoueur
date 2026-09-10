extends Node3D
## LA PLANCHE DU KIT DE ROUTES, POSÉE AU-DESSUS DE L'EAU.
##
## Pourquoi au-dessus de l'eau : plusieurs tuiles du kit ne remplissent pas
## leur carré. `road-bend` laisse un quart de disque VIDE dans son coin
## extérieur, `road-end-round` deux coins, `road-roundabout` ses quatre. Sur
## une ville plate posée sur un socle ça ne se voyait pas ; dès que le sol de
## la case est le seul plancher, le trou donne sur la mer, et on a des virages
## qui montrent l'eau dans le coin. Le bleu sous la planche est là pour que le
## trou se voie AVANT d'être dans la ville.
##
##     ./outils/pavage.sh                       -> /tmp/pavage/planche.png
##     ./outils/pavage.sh "road-bend,road-bend-sidewalk"
const CASE := CarteVille.CASE
const COLONNES := 6

## Le banc sert aussi à REGARDER un dossier de modèles quelconque —
## `--dossier=res://modeles/piksl/` — auquel cas chaque modèle est ramené à une
## case. C'est le seul moyen de voir qu'un `.glb` sort en gris uni parce que ses
## matières n'ont pas été lues : sur une vignette de trente-deux pixels au fond
## d'une colonne, un hôpital gris et un hôpital coloré se ressemblent beaucoup.
var _dossier := CarteVille.CHEMIN_ROUTES

func _ready() -> void:
	var noms: Array[String] = []
	var sortie := "/tmp/pavage/planche.png"
	for a in OS.get_cmdline_args():
		if a.begins_with("--dossier="): _dossier = a.trim_prefix("--dossier=")
		if a.begins_with("--tuiles="):
			for n in a.trim_prefix("--tuiles=").split(","):
				if String(n).strip_edges() != "": noms.append(String(n).strip_edges())
		if a.begins_with("--sortie="): sortie = a.trim_prefix("--sortie=")
	if noms.is_empty():
		var d := DirAccess.open(_dossier)
		for f in d.get_files():
			if f.ends_with(".glb"): noms.append(f.trim_suffix(".glb"))
		noms.sort()

	var lignes := int(ceil(float(noms.size()) / COLONNES))
	# La mer : un plan bleu franc, bien plus bas que les tuiles. Toute tache
	# bleue dans la planche est un trou.
	var mer := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(COLONNES * CASE * 2.0, lignes * CASE * 2.0)
	mer.mesh = pm
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color("#1b6fd0")
	mer.material_override = mm
	mer.position = Vector3((COLONNES - 1) * CASE * 0.75, -CASE * 0.5, (lignes - 1) * CASE * 0.75)
	add_child(mer)

	for k in noms.size():
		var i := k % COLONNES
		var j := k / COLONNES
		var ou := Vector3(float(i) * CASE * 1.5, 0.0, float(j) * CASE * 1.5)
		var chemin: String = _dossier + noms[k] + ".glb"
		if ResourceLoader.exists(chemin):
			var kit := _dossier == CarteVille.CHEMIN_ROUTES
			var n := MeshInstance3D.new()
			# Une tuile de route est déjà à sa taille (un côté = 1) ; un modèle
			# quelconque, non — on le ramène à la case par sa plus grande
			# dimension au sol.
			n.mesh = FormesCarnage.maillage_kenney(chemin, 0.0 if kit else CASE * 0.9,
				Vector3.AXIS_X, 0.0)
			var m := FormesCarnage.matiere_kenney(chemin).duplicate()
			# ⚠ ON NE TEINTE QUE LE KIT DE ROUTES. Teinter un modèle qui porte
			# ses propres couleurs, c'est exactement le bogue qu'on cherche.
			if kit:
				if m is ShaderMaterial:
					(m as ShaderMaterial).set_shader_parameter("teinte", Quartiers.TEINTE_ROUTE)
				elif m is BaseMaterial3D:
					(m as BaseMaterial3D).albedo_color = Quartiers.TEINTE_ROUTE
			n.material_override = m
			n.transform = Transform3D(Basis().scaled(Vector3.ONE * (CASE if kit else 1.0)), ou)
			add_child(n)
		var etiquette := Label3D.new()
		etiquette.text = noms[k]
		etiquette.font_size = 96
		etiquette.pixel_size = 0.011
		etiquette.rotation_degrees = Vector3(-90, 0, 0)
		etiquette.position = ou + Vector3(0, 0.6, CASE * 0.72)
		etiquette.modulate = Color.BLACK
		etiquette.outline_size = 22
		etiquette.outline_modulate = Color.WHITE
		add_child(etiquette)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#c8d6e2")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.9, 0.93, 1.0)
	e.ambient_light_energy = 0.85
	env.environment = e
	add_child(env)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-62, -38, 0)
	l.light_energy = 1.15
	add_child(l)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(COLONNES, lignes) * CASE * 1.62
	cam.position = Vector3((COLONNES - 1) * CASE * 0.75, 260.0, (lignes - 1) * CASE * 0.75 + 1.0)
	add_child(cam)
	cam.look_at(Vector3((COLONNES - 1) * CASE * 0.75, 0, (lignes - 1) * CASE * 0.75))
	print("planche : %d tuiles, %d colonnes" % [noms.size(), COLONNES])
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(sortie.get_base_dir())
	get_viewport().get_texture().get_image().save_png(sortie)
	get_tree().quit()
