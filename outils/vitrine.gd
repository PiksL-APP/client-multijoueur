extends Node3D
## Banc de photo des intérieurs de repaire : `outils/vitrine.sh taudis` bâtit
## l'appartement, l'éclaire et en sort une image.
##
## Pourquoi un banc plutôt qu'une capture en jeu : un intérieur se valide AVANT
## d'exister dans la ville. Ici il n'y a ni réseau, ni manche, ni joueur — on
## regarde le plan de haut, comme la boutique le montrera.
func _ready() -> void:
	var id := "taudis"
	var sortie := "/tmp/vitrine.png"
	var azimut := 34.0
	var inclinaison := 52.0
	for a in OS.get_cmdline_args():
		if a.begins_with("--interieur="): id = a.trim_prefix("--interieur=")
		if a.begins_with("--sortie="): sortie = a.trim_prefix("--sortie=")
		if a.begins_with("--azimut="): azimut = float(a.trim_prefix("--azimut="))
		if a.begins_with("--inclinaison="): inclinaison = float(a.trim_prefix("--inclinaison="))

	var appart := Interieurs.batir(id)
	add_child(appart)
	var fiche := Interieurs.plan(id)
	var lignes: Array = fiche["plan"]
	var large := float((String(lignes[0]).length() - 1) / 2) * Interieurs.ECHELLE
	var profond := float((lignes.size() - 1) / 2) * Interieurs.ECHELLE

	# Une dalle sombre sous l'appartement : sans elle l'image flotte sur le
	# fond et on ne lit plus les seuils de porte.
	var socle := MeshInstance3D.new()
	var pm := BoxMesh.new(); pm.size = Vector3(large + 1.2, 0.3, profond + 1.2); socle.mesh = pm
	var ms := StandardMaterial3D.new(); ms.albedo_color = Color("#15171a"); ms.roughness = 1.0
	socle.material_override = ms
	socle.position = Vector3(large * 0.5, -0.15, profond * 0.5)
	add_child(socle)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#0d0d0d")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#b9c6d8")
	e.ambient_light_energy = 0.52
	env.environment = e
	add_child(env)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-58, -128, 0)
	soleil.light_energy = 0.82
	soleil.shadow_enabled = true
	soleil.light_color = Color("#fff3e0")
	add_child(soleil)
	var appoint := DirectionalLight3D.new()
	appoint.rotation_degrees = Vector3(-24, 62, 0)
	appoint.light_energy = 0.35
	appoint.light_color = Color("#9fb8dd")
	add_child(appoint)

	var cam := Camera3D.new()
	cam.fov = 46.0
	add_child(cam)
	var haut := Interieurs.HAUT * Interieurs.ECHELLE
	var centre := Vector3(large * 0.5, haut * 0.35, profond * 0.5)
	var a := deg_to_rad(azimut)
	var i := deg_to_rad(inclinaison)
	var dir := Vector3(sin(a) * cos(i), sin(i), cos(a) * cos(i))
	cam.position = centre + dir
	cam.look_at(centre)
	# Le cadrage se CALCULE : à l'œil, un appartement sur deux sort du cadre par
	# un coin. On projette les huit sommets de la boîte dans le repère de la
	# caméra et on recule juste assez pour que le pire tienne.
	var b := cam.global_transform.basis
	var ecran := Vector2(get_viewport().size)
	var tv := tan(deg_to_rad(cam.fov) * 0.5)
	var th := tv * ecran.x / ecran.y
	var recul := 0.0
	for cx in [0.0, large]:
		for cy in [0.0, haut]:
			for cz in [0.0, profond]:
				var p := Vector3(cx, cy, cz) - centre
				recul = maxf(recul, b.z.dot(p) + absf(b.x.dot(p)) / th)
				recul = maxf(recul, b.z.dot(p) + absf(b.y.dot(p)) / tv)
	cam.position = centre + dir * (recul * 1.03 + 0.4)
	cam.look_at(centre)
	# On escamote les façades qui nous tournent le dos : elles sont entre la
	# caméra et la pièce, et une boîte fermée ne se valide pas.
	var vers_cam := Vector2(dir.x, dir.z)
	for n in appart.get_children():
		if not n.has_meta("dehors"):
			continue
		var d: Vector2 = n.get_meta("dehors")
		if d != Vector2.ZERO and d.dot(vers_cam) > 0.3:
			(n as Node3D).visible = false
	for n in appart.get_children():
		if not n.has_meta("aretes"):
			continue
		var reste := false
		for mur in n.get_meta("aretes"):
			reste = reste or (mur as Node3D).visible
		(n as Node3D).visible = reste
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_rogner(img, e.background_color).save_png(sortie)
	get_tree().quit()


## Rogner sur le sujet : quel que soit l'appartement, la photo arrive cadrée
## serrée. Calculé au cordeau, le recul laisse toujours une bande noire d'un
## côté — le format d'un plan n'est pas celui de l'écran.
func _rogner(img: Image, fond: Color, marge: int = 26) -> Image:
	# On cherche le sujet sur une VIGNETTE au quart : lire 1 440 000 pixels un
	# par un depuis GDScript prend plus d'une minute, la vignette en prend une
	# fraction et le cadre au pixel près n'a aucun intérêt ici.
	const PAS := 4
	var vignette := img.duplicate() as Image
	vignette.resize(img.get_width() / PAS, img.get_height() / PAS, Image.INTERPOLATE_NEAREST)
	var x0 := vignette.get_width()
	var y0 := vignette.get_height()
	var x1 := 0
	var y1 := 0
	for y in vignette.get_height():
		for x in vignette.get_width():
			var c := vignette.get_pixel(x, y)
			if absf(c.r - fond.r) + absf(c.g - fond.g) + absf(c.b - fond.b) < 0.06:
				continue
			x0 = mini(x0, x); y0 = mini(y0, y)
			x1 = maxi(x1, x); y1 = maxi(y1, y)
	if x1 <= x0 or y1 <= y0:
		return img
	var gx := maxi(0, x0 * PAS - marge)
	var gy := maxi(0, y0 * PAS - marge)
	return img.get_region(Rect2i(gx, gy,
		mini(img.get_width(), (x1 + 1) * PAS + marge) - gx,
		mini(img.get_height(), (y1 + 1) * PAS + marge) - gy))
