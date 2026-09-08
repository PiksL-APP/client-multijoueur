extends Node3D
## Visionneuse de modèles voxel : `outils/voir.sh arbre_0,maison_taverne` — pose
## les modèles en ligne sur une pelouse, les éclaire, et capture une image.
func _ready() -> void:
	var noms: PackedStringArray = []
	var ecart := 8.0
	var sortie := "/tmp/t2d/voxel.png"
	for a in OS.get_cmdline_args():
		if a.begins_with("--voir="):
			noms = a.trim_prefix("--voir=").split(",")
		if a.begins_with("--ecart="):
			ecart = float(a.trim_prefix("--ecart="))
		if a.begins_with("--sortie="):
			sortie = a.trim_prefix("--sortie=")
	var sol := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(200, 200); sol.mesh = pm
	var ms := StandardMaterial3D.new(); ms.albedo_color = Color(0.38, 0.66, 0.29); sol.material_override = ms
	add_child(sol)
	# `etalon` : un mât de deux unités, gradué chaque demi-unité — c'est lui
	# qui donne l'échelle d'un modèle qu'on découvre. `k:<peau>` sort un
	# personnage du casting Kenney plutôt qu'un voxel.
	var x := 0.0
	for nom in noms:
		if String(nom) == "etalon":
			for k in 4:
				var barre := MeshInstance3D.new()
				var bm := BoxMesh.new(); bm.size = Vector3(0.18, 0.5, 0.18); barre.mesh = bm
				var bmat := StandardMaterial3D.new()
				bmat.albedo_color = Color.RED if k % 2 == 0 else Color.WHITE
				barre.material_override = bmat
				barre.position = Vector3(x, 0.25 + k * 0.5, 0)
				add_child(barre)
			x += ecart
			continue
		if String(nom).begins_with("k:"):
			var perso := Personnages.creer(String(nom).substr(2))
			perso.position = Vector3(x, 0, 0)
			add_child(perso)
			x += ecart
			continue
		var scene: PackedScene = load("res://modeles/voxel/%s.glb" % nom)
		var inst := scene.instantiate() as Node3D
		inst.position = Vector3(x, 0, 0)
		add_child(inst)
		x += ecart
	var env := WorldEnvironment.new()
	var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.55, 0.75, 0.95); e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.8, 0.85, 1.0); e.ambient_light_energy = 0.6
	env.environment = e; add_child(env)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-55, -35, 0); l.shadow_enabled = true; l.light_energy = 1.1; add_child(l)
	var cam := Camera3D.new(); add_child(cam)
	var centre := Vector3((x - ecart) * 0.5, 1.1, 0)
	var dist := maxf(4.0, x * 0.5)
	cam.position = centre + Vector3(0, dist * 0.34, dist * 0.94)
	cam.look_at(centre)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(sortie)
	get_tree().quit()
