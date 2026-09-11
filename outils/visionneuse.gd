extends Node3D
## Visionneuse de modèles voxel : `outils/voir.sh arbre_0,k:zombieA` — pose
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
	# La pelouse est posée APRÈS, une fois qu'on sait ce que la rangée mesure :
	# à deux cents unités de côté elle s'arrêtait au milieu du parc automobile,
	# et la moitié des véhicules flottaient dans le ciel.
	var sol := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(200, 200); sol.mesh = pm
	var ms := StandardMaterial3D.new(); ms.albedo_color = Color(0.38, 0.66, 0.29); sol.material_override = ms
	add_child(sol)
	var _sol_pm := pm
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
		# `v:<indice>` sort un VÉHICULE du parc de Carnage, bâti comme le jeu le
		# bâtit (`FormesCarnage.voiture_kit`). Le parc n'avait aucun banc : c'est
		# exactement pour ça que quatre carrosseries du Car Kit sont restées dans
		# le dossier sans jamais rouler. `v:*` les sort toutes.
		if String(nom).begins_with("v:"):
			var quoi := String(nom).substr(2)
			var indices: Array = []
			if quoi.begins_with("*"):
				for k2 in FormesCarnage.MODELES_VOITURES.size():
					indices.append(k2)
			else:
				indices.append(int(quoi.rstrip("+")))
			# `v:<indice>+` sort la carrosserie AVEC sa mitrailleuse de toit.
			# Elle se juge sur plusieurs gabarits ou pas du tout : sa hauteur
			# est mesurée sur la coque, et c'est exactement le genre de calcul
			# qui tombe juste sur une berline et plante le canon dans le
			# pare-brise d'un bus.
			var armee := quoi.ends_with("+")
			for indice in indices:
				var auto := FormesCarnage.voiture_kit(int(indice))
				FormesCarnage.armer_la_voiture(auto, armee)
				auto.position = Vector3(x, 0, 0)
				add_child(auto)
				var etiquette := Label3D.new()
				etiquette.text = "%d %s" % [int(indice),
					String(FormesCarnage.MODELES_VOITURES[int(indice)])]
				etiquette.font_size = 96
				etiquette.pixel_size = 0.006
				etiquette.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				etiquette.position = Vector3(x, 3.2, 0)
				add_child(etiquette)
				x += ecart
			continue
		# `d:<chose>` sort un DÉCOR de la ville : la dalle d'un atelier, une
		# mine, une flaque. Bâti par la fonction du jeu, pas par le banc —
		# c'est la seule façon de voir ce que le joueur verra.
		if String(nom).begins_with("d:"):
			var quoi := String(nom).substr(2)
			var piece: Node3D = FormesCarnage.dalle_garage()
			match quoi:
				"atelier": piece = FormesCarnage.dalle_atelier()
				"mine": piece = FormesCarnage.mine()
				"huile": piece = FormesCarnage.flaque_huile()
				"char": piece = FormesCarnage.char_arme()
				"colis": piece = FormesCarnage.colis()
				"frenzy": piece = FormesCarnage.icone_frenzy()
			piece.position = Vector3(x, 0, 0)
			add_child(piece)
			x += ecart
			continue
		# `c:<niveau>` sort une CABINE de ce palier — `c:2-` la sort éteinte,
		# comme le jeu l'éteint quand il manque du respect. Le banc ne peint
		# rien lui-même : il prend un vrai numéro de cabine de ce palier et
		# laisse `FormesCarnage.cabine()` faire, sinon la photo prouverait
		# seulement que le banc sait choisir une couleur.
		if String(nom).begins_with("c:"):
			var arg := String(nom).substr(2)
			var eteinte := arg.ends_with("-")
			var palier := int(arg.rstrip("-"))
			var id := 0
			while FormesCarnage.niveau_de_cabine(id) != palier and id < 4000:
				id += 1
			var poste := FormesCarnage.cabine(id)
			poste.position = Vector3(x, 0, 0)
			add_child(poste)
			if eteinte:
				var ens := poste.get_node_or_null("Enseigne") as MeshInstance3D
				var t: Color = FormesCarnage.CABINES[palier]["couleur"]
				ens.material_override = Decor.matiere_lumineuse(t,
					FormesCarnage.CABINE_ETEINTE)
				var h := poste.get_node_or_null("Halo") as Node3D
				if h: h.visible = false
			var sous := Decor.etiquette(
				"n°%d — %s" % [id, "fermée" if eteinte else "ouverte"],
				Palette.ENCRE_DOUCE, 18)
			sous.position = Vector3(x, 0.6, 1.2)
			add_child(sous)
			x += ecart
			continue
		# `t:` sort la RAME DE TRAIN, `t:quai` le quai. Le train n'est visible
		# en partie qu'au moment où il passe, à neuf cents pixels par seconde :
		# sans ce banc on ne le jugerait jamais autrement qu'en photo floue.
		if String(nom).begins_with("t:"):
			var quoi_t := String(nom).substr(2)
			var piece_t: Node3D = FormesCarnage.rame_de_train(VilleVivante.WAGONS)
			if quoi_t == "quai":
				piece_t = FormesCarnage.quai()
			elif quoi_t == "casse":
				piece_t = FormesCarnage.compacteur()
			piece_t.position = Vector3(x, 0, 0)
			add_child(piece_t)
			x += ecart
			continue
		# `u:<corps>` sort un UNIFORME : police, SWAT, agent, armée.
		if String(nom).begins_with("u:"):
			var corps := int(String(nom).substr(2))
			var homme := FormesCarnage.uniforme(corps)
			homme.position = Vector3(x, 0, 0)
			homme.rotation.y = PI
			add_child(homme)
			var mot := Decor.etiquette(String(VilleVivante.CORPS[corps]["nom"]).to_upper(),
				FormesCarnage.TENUES_CORPS[corps].lightened(0.35), 20)
			mot.position = Vector3(x, 3.2, 0)
			add_child(mot)
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
	_sol_pm.size = Vector2(maxf(200.0, x * 1.3), maxf(200.0, x * 1.3))
	sol.position = Vector3(centre.x, 0, 0)
	var dist := maxf(4.0, x * 0.5)
	cam.position = centre + Vector3(0, dist * 0.34, dist * 0.94)
	cam.look_at(centre)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(sortie)
	get_tree().quit()
