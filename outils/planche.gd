extends Node3D
## La planche de vignettes du kit : chaque modèle du Furniture Kit et du Food
## Kit photographié À LA VERTICALE, à sa vraie emprise, sur fond transparent.
##
## Pourquoi de dessus et pas en isométrie : ces vignettes servent d'icônes à
## l'éditeur de plan, qui travaille en vue de dessus. Une icône isométrique
## ment sur l'encombrement — on croit poser un canapé, on pose son ombre.
##
## Une case du damier vaut UNE unité de modèle ; le modèle est mis à l'échelle
## pour que sa plus grande dimension au sol remplisse la case à 90 %, centré sur
## son emprise comme `Interieurs` le pose. L'éditeur redessine donc la vignette
## dans un carré de côté `max(largeur, profondeur)` et la fait tourner : la
## silhouette tombe exactement sur le meuble.
const COLONNES := 16
const PIXELS := 128
const PAS := 1.0

func _ready() -> void:
	var noms: Array[String] = []
	for dossier in ["res://modeles/kenney/interieur/", "res://modeles/kenney/nourriture/",
			"res://modeles/interieur/"]:
		var d := DirAccess.open(dossier)
		var prefixe := "n:" if dossier.ends_with("nourriture/") else (
			"c:" if dossier == "res://modeles/interieur/" else "")
		for f in d.get_files():
			if f.ends_with(".glb"):
				noms.append(prefixe + f.trim_suffix(".glb"))
	noms.sort()

	var lignes := int(ceil(float(noms.size()) / COLONNES))
	var vue := SubViewport.new()
	vue.size = Vector2i(COLONNES * PIXELS, lignes * PIXELS)
	vue.transparent_bg = true
	vue.own_world_3d = true
	vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vue)

	var monde := Node3D.new()
	vue.add_child(monde)
	var gabarits := {}
	for i in noms.size():
		var nom := noms[i]
		var b := Interieurs.gabarit(nom)
		gabarits[nom] = {"l": snappedf(b.size.x, 0.001), "h": snappedf(b.size.y, 0.001),
			"p": snappedf(b.size.z, 0.001), "case": i}
		var noeud := Interieurs._instancier(nom, {})
		var cote: float = maxf(maxf(b.size.x, b.size.z), 0.001)
		noeud.scale *= PAS * 0.9 / cote
		noeud.position = Vector3((i % COLONNES + 0.5) * PAS, 0, (i / COLONNES + 0.5) * PAS)
		monde.add_child(noeud)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#e8ecf2")
	e.ambient_light_energy = 0.34
	env.environment = e
	monde.add_child(env)
	# Une lumière franchement inclinée : à la verticale, un plateau de table et
	# le sol qu'il cache rendent la même valeur et la silhouette disparaît.
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-62, -38, 0)
	l.light_energy = 1.05
	l.shadow_enabled = false
	monde.add_child(l)
	var appoint := DirectionalLight3D.new()
	appoint.rotation_degrees = Vector3(-40, 150, 0)
	appoint.light_energy = 0.32
	appoint.light_color = Color("#c8d6e8")
	appoint.shadow_enabled = false
	monde.add_child(appoint)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = lignes * PAS
	cam.near = 0.01
	cam.far = 60.0
	cam.position = Vector3(COLONNES * PAS * 0.5, 20.0, lignes * PAS * 0.5)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	monde.add_child(cam)
	vue.get_camera_3d()

	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	vue.get_texture().get_image().save_png("res://_transfert/vitrine/planche.png")
	var fic := FileAccess.open("res://_transfert/vitrine/gabarits.json", FileAccess.WRITE)
	fic.store_string(JSON.stringify({"colonnes": COLONNES, "pixels": PIXELS,
		"lignes": lignes, "modeles": gabarits}, "\t"))
	fic.close()
	print("planche : %d modèles, %d x %d" % [noms.size(), COLONNES, lignes])
	get_tree().quit()
