extends Node2D
## LE BANC DE LA FERME : les six fonctions de `Terrain` que la ferme appelle et
## qui avaient disparu — `nappe`, `parcelle`, `detail`, `DETAILS`, `cageot`,
## `dernier_stade`.
##
## ⚠ POURQUOI CE BANC EXISTE. La réécriture de `commun/terrain.gd` pour Serene
## Village les a laissées derrière elle. `scenes/ferme.gd` ne se chargeait plus
## DU TOUT — six « Static function not found » à l'ouverture de l'écran — et
## personne ne l'a vu pendant des jours : un jeu qu'on n'ouvre pas ne dit rien.
## Ici on les appelle toutes, et on les photographie.
##
##   outils/ferme.sh [sortie]

var _sortie := "/tmp/ferme/banc.png"

func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--sortie="): _sortie = a.trim_prefix("--sortie=")

	# La pelouse, telle que la ferme la pose.
	add_child(Terrain.nappe(640, 360, Terrain.HERBE, 20260907))

	# Les parcelles : une isolée, puis une bande de quatre qui se raccordent.
	# ⚠ C'est LE cas qui se voit : deux parcelles côte à côte doivent perdre
	# leur liseré d'herbe entre elles, sinon le champ est une mosaïque.
	var isolee := Terrain.parcelle(32, 1, false, 0)
	isolee.position = Vector2(48, 64)
	add_child(isolee)
	for i in 4:
		# ⚠ Le masque dit où la terre CONTINUE — y compris vers la rangée du
		# dessous (bit 2). Oublié au premier jet, il laissait un liseré d'herbe
		# EN TRAVERS du champ : le banc accusait `case_de_terre`, alors que
		# c'était lui qui décrivait mal le champ.
		var masque := (4 if i > 0 else 0) | (8 if i < 3 else 0) | 2
		var p := Terrain.parcelle(32, 2 + i, i == 2, masque)
		p.position = Vector2(140 + i * 32, 64)
		add_child(p)
	# Une seconde rangée collée sous la première : le raccord vertical.
	for i in 4:
		var masque2 := (1) | (4 if i > 0 else 0) | (8 if i < 3 else 0)
		var p2 := Terrain.parcelle(32, 10 + i, false, masque2)
		p2.position = Vector2(140 + i * 32, 96)
		add_child(p2)

	# Les plants, du premier stade au dernier.
	for stade in Terrain.STADES:
		var plant := Terrain.plant(2, stade)
		plant.position = Vector2(60 + stade * 24, 190)
		add_child(plant)

	# Les détails semés sur la pelouse.
	for i in Terrain.DETAILS.size():
		var brin := Terrain.detail(i)
		brin.position = Vector2(40 + i * 22, 230)
		add_child(brin)

	# Les cageots, un par culture.
	for c in Terrain.CULTURES.size():
		var cageot := Terrain.cageot(c)
		cageot.position = Vector2(60 + c * 40, 310)
		add_child(cageot)
		var mot := Label.new()
		mot.text = String(Terrain.CULTURES[c]["nom"])
		mot.position = Vector2(38 + c * 40, 312)
		mot.add_theme_font_size_override("font_size", 8)
		add_child(mot)

	var camera := Camera2D.new()
	camera.zoom = Vector2(2, 2)
	camera.position = Vector2(320, 180)
	add_child(camera)
	camera.make_current()

	print("dernier stade : %d, %d détails, %d cultures"
		% [Terrain.dernier_stade(), Terrain.DETAILS.size(), Terrain.CULTURES.size()])
	DirAccess.make_dir_recursive_absolute(_sortie.get_base_dir())
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_sortie)
	print("photo %s" % _sortie)
	get_tree().quit()
