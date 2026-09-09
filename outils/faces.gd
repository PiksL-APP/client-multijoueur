extends Node3D
## Le sens de chaque modèle du kit : on photographie les mêmes meubles DEUX
## fois, une fois depuis le nord (−Z) et une fois depuis le sud (+Z).
##
## Pourquoi : le Furniture Kit n'a AUCUNE convention. `toilet` sort vers +Z,
## `toiletSquare` vers −Z, et rien dans le fichier ne dit où est la porte d'un
## placard. Déduire le devant de l'emprise, c'est se tromper une fois sur deux —
## et un quart de tour à l'envers ne se voit pas sur une vue de trois quarts.
## La seule source sûre, c'est l'image : celle où l'on voit la façade donne le
## sens, et cette table-là ne bouge plus.
const COLONNES := 10
const PIXELS := 190
const PAS := 1.0

func _ready() -> void:
	var noms: PackedStringArray = []
	var cote := "nord"
	var sortie := "res://_transfert/vitrine/faces.png"
	for a in OS.get_cmdline_args():
		if a.begins_with("--modeles="): noms = a.trim_prefix("--modeles=").split(",")
		if a.begins_with("--cote="): cote = a.trim_prefix("--cote=")
		if a.begins_with("--sortie="): sortie = a.trim_prefix("--sortie=")
	var lignes := int(ceil(float(noms.size()) / float(COLONNES)))
	print("noms=%d lignes=%d" % [noms.size(), lignes])
	var vue := SubViewport.new()
	vue.size = Vector2i(COLONNES * PIXELS, lignes * PIXELS)
	vue.transparent_bg = true
	vue.own_world_3d = true
	vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vue)
	var monde := Node3D.new()
	vue.add_child(monde)

	# Chaque modèle dans sa case, ramené à la même taille : on compare des
	# façades, pas des encombrements.
	for i in noms.size():
		var nom := String(noms[i])
		var b := Interieurs.gabarit(nom)
		var noeud := Interieurs._instancier(nom, {})
		var grand: float = maxf(maxf(b.size.x, b.size.z), maxf(b.size.y, 0.001))
		noeud.scale *= PAS * 0.62 / grand
		# Les rangées sont EMPILÉES EN HAUTEUR, pas en profondeur : vue de côté,
		# une grille posée à plat se recouvre rangée sur rangée.
		noeud.position = Vector3((i % COLONNES + 0.5) * PAS, float(lignes - 1 - i / COLONNES) * PAS, 0.0)
		if i % 12 == 0: print("  %d %s -> %s" % [i, nom, noeud.position])
		monde.add_child(noeud)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#eceff4")
	e.ambient_light_energy = 0.5
	env.environment = e
	monde.add_child(env)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-26, 200 if cote == "nord" else 20, 0)
	l.light_energy = 1.0
	monde.add_child(l)

	# Presque de face, à peine plongeante : c'est l'angle où une porte, un
	# écran ou une assise se reconnaissent.
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = lignes * PAS
	cam.near = 0.01
	cam.far = 80.0
	var sens := -1.0 if cote == "nord" else 1.0
	# Caméra STRICTEMENT de niveau : la moindre plongée sur une caméra
	# orthogonale décale tout le cadre le long de l'axe de visée, et il ne
	# reste qu'une rangée sur huit dans l'image.
	cam.position = Vector3(COLONNES * PAS * 0.5, (lignes - 1) * PAS * 0.5 + 0.31, sens * 30.0)
	cam.rotation_degrees = Vector3(0, 0 if cote == "sud" else 180, 0)
	monde.add_child(cam)

	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	vue.get_texture().get_image().save_png(sortie)
	print("faces : %d modèles vus du %s" % [noms.size(), cote])
	get_tree().quit()
