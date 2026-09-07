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
	var x := 0.0
	for nom in noms:
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
	var centre := Vector3((x - ecart) * 0.5, 1.0, 0)
	var dist := maxf(5.0, x * 0.5)
	cam.position = centre + Vector3(0, dist * 0.7, dist * 0.8)
	cam.look_at(centre)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(sortie)
	get_tree().quit()
