extends Node3D
## LE BANC DE PHOTO DE LA CARTE — le pendant de `outils/vitrine.sh` pour la
## ville. Le rendu se REGARDE : c'est la seule façon de voir qu'une rue tombe
## dans l'eau ou qu'un immeuble est à cheval sur une falaise.
##
## `outils/carte.sh [quartier|ville] [sortie] [azimut] [inclinaison] [zoom]`
##
## Le cadrage est CALCULÉ sur l'emprise de ce qu'on a bâti : un quartier qu'on
## agrandit ne sort pas du cadre, et on n'a pas à régler la distance à chaque
## fois qu'on ajoute une rue.

var _images := 0
var _sortie := "/tmp/carte/ville.png"

func _ready() -> void:
	var quoi := "ville"
	var azimut := 214.0
	var inclinaison := 34.0
	var zoom := 1.0
	var nuit := 0.12
	for a in OS.get_cmdline_args():
		if a.begins_with("--quartier="): quoi = a.trim_prefix("--quartier=")
		if a.begins_with("--sortie="): _sortie = a.trim_prefix("--sortie=")
		if a.begins_with("--azimut="): azimut = float(a.trim_prefix("--azimut="))
		if a.begins_with("--inclinaison="): inclinaison = float(a.trim_prefix("--inclinaison="))
		if a.begins_with("--zoom="): zoom = float(a.trim_prefix("--zoom="))
		if a.begins_with("--nuit="): nuit = float(a.trim_prefix("--nuit="))

	MatieresCarnage.nuit_forcee = nuit
	var amb: Array = MatieresCarnage.ambiance()
	for n in amb: add_child(n)
	MatieresCarnage.regler_heure(amb[0], amb[1], amb[2], nuit)
	MatieresCarnage.regler_nuit(nuit)
	# La brume du jeu est réglée pour une caméra à trente unités du sol ; à vol
	# d'oiseau elle efface la ville. Et deux cent vingt unités d'ombres ne
	# couvrent qu'un pâté : sans ombre lointaine, le relief ne se lit plus.
	var env: Environment = (amb[0] as WorldEnvironment).environment
	env.fog_density *= 0.15
	(amb[1] as DirectionalLight3D).directional_shadow_max_distance = 2600.0

	var sujet: Node3D
	if quoi == "ville":
		sujet = Quartiers.ville()
	else:
		sujet = Node3D.new()
		var mer := MeshInstance3D.new()
		var plan := PlaneMesh.new()
		plan.size = Vector2(600.0 * Quartiers.CASE, 600.0 * Quartiers.CASE)
		mer.mesh = plan
		var eau := StandardMaterial3D.new()
		eau.albedo_color = Color("#2b5f7a")
		eau.roughness = 0.15
		eau.metallic = 0.25
		mer.material_override = eau
		mer.position = Vector3(0, -2.4, 0)
		sujet.add_child(mer)
		sujet.add_child(Quartiers.batir(quoi))
	add_child(sujet)

	# L'emprise de ce qu'on a bâti, la mer exceptée — elle est immense et
	# emporterait le cadrage à l'horizon.
	var boite := _emprise(sujet, Transform3D.IDENTITY, 200.0 * Quartiers.CASE)
	var centre := boite.get_center()
	var rayon: float = maxf(boite.size.length() * 0.5, 60.0)
	var cam := Camera3D.new()
	cam.fov = 48.0
	cam.far = 20000.0
	add_child(cam)
	var a := deg_to_rad(azimut)
	var b := deg_to_rad(inclinaison)
	var distance := rayon / tan(deg_to_rad(cam.fov * 0.5)) * 1.05 / maxf(zoom, 0.05)
	var oeil := centre + Vector3(sin(a) * cos(b), sin(b), cos(a) * cos(b)) * distance
	cam.look_at_from_position(oeil, centre, Vector3.UP)
	cam.make_current()
	print("cadré sur %s : centre %.0f,%.0f rayon %.0f" % [quoi, centre.x, centre.z, rayon])
	get_tree().process_frame.connect(_photographier)

func _emprise(n: Node, t: Transform3D, plafond: float) -> AABB:
	var tot := AABB()
	var vu := false
	var t2 := t
	if n is Node3D: t2 = t * (n as Node3D).transform
	if n is VisualInstance3D:
		var b: AABB = t2 * (n as VisualInstance3D).get_aabb()
		if b.size.x < plafond and b.size.z < plafond:
			tot = b; vu = true
	for e in n.get_children():
		var s := _emprise(e, t2, plafond)
		if s.size == Vector3.ZERO: continue
		if vu: tot = tot.merge(s)
		else: tot = s; vu = true
	return tot if vu else AABB()

func _photographier() -> void:
	_images += 1
	if _images < 12: return
	DirAccess.make_dir_recursive_absolute(_sortie.get_base_dir())
	get_viewport().get_texture().get_image().save_png(_sortie)
	print("photo ", _sortie)
	get_tree().quit()
