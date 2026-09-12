extends SceneTree
## BANC DU TRAFIC : `godot --headless -s outils/trafic.gd [--code=PIKSTOWN] [--duree=60] [--ou=pont]`
##
## Fait vivre la ville sans écran ni réseau — un joueur immobile au cœur de la
## carte, la simulation de l'hôte à soixante images par seconde — et MESURE
## ce que l'œil reproche au trafic : des voitures dans l'eau, des virages pris
## d'un coup, des voitures coincées, des passants dans les façades. Ce sont
## des chiffres, pas une impression : on les relit après chaque réglage.
##
## Ce qu'il imprime :
##   - voitures et passants nés dans l'eau ou dans un mur (doit être zéro) ;
##   - images où une voiture est dans l'eau (doit être zéro) ;
##   - le plus grand saut de cap en une image (doit rester sous ~0,1 rad) ;
##   - la part de voitures coincées (vitesse nulle sans obstacle) ;
##   - la part des passants sur un trottoir, la part en pause.

func _init() -> void:
	var code := "PIKSTOWN"
	var duree := 60.0
	for a in OS.get_cmdline_args():
		if String(a).begins_with("--code="):
			code = String(a).substr(7)
		if String(a).begins_with("--duree="):
			duree = float(String(a).substr(8))
	# `--traces=/tmp/traces.csv` : les positions des voitures et des passants,
	# une ligne sur trois images, pour les DESSINER (`outils/traces.py`).
	var chemin_traces := ""
	for a in OS.get_cmdline_args():
		if String(a).begins_with("--traces="):
			chemin_traces = String(a).substr(9)
	var traces: FileAccess = null
	if chemin_traces != "":
		traces = FileAccess.open(chemin_traces, FileAccess.WRITE)
		traces.store_line("genre;id;t;x;y;a")
	var plan := PlanVille.new(code)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ville := VilleVivante.new(plan, rng)
	var moi := plan.coeur()
	# `--ou=pont` : au bord de l'eau, là où l'ancien trafic se noyait.
	for a in OS.get_cmdline_args():
		if String(a) == "--ou=pont":
			moi = plan.un_pont()
	# Un joueur à pied, immobile, au cœur : c'est autour de lui que la ville
	# se peuple.
	var joueurs := {"banc": {"p": moi, "a": 0.0, "v": 0.0, "vie": 100.0, "pied": true,
		"seuil": VilleVivante.SEUIL_ECRASEMENT, "train": false, "arene": -1,
		"d": Vector2.RIGHT, "vm": -1}}

	var dt := 1.0 / 60.0
	var t := 0.0
	var pas := 0
	var caps: Dictionary = {}          # id -> dernier cap
	var pire_saut := 0.0
	var sauts_forts := 0
	var images_eau := 0
	var images_mur := 0
	var coincees := 0
	var mesures_autos := 0
	var sur_trottoir := 0
	var en_pause := 0
	var mesures_gens := 0
	var gens_eau := 0
	var nes: Dictionary = {}
	var nes_eau := 0
	var virages := 0
	var tournants_totaux := {0: 0, 1: 0, -1: 0, 2: 0}
	while t < duree:
		ville.simuler(dt, t, joueurs)
		t += dt
		pas += 1
		for auto in ville.autos:
			if bool(auto.get("garee", false)) or int(auto["genre"]) == VilleVivante.EPAVE:
				continue
			var id := int(auto["id"])
			var p: Vector2 = auto["p"]
			var c := int(floor(p.x / PlanVille.PAS))
			var l := int(floor(p.y / PlanVille.PAS))
			if not nes.has(id):
				nes[id] = true
				if plan.eau(c, l) or plan.dans_un_batiment(p, 10.0):
					nes_eau += 1
				if auto.has("tournant"):
					tournants_totaux[int(auto["tournant"])] += 1
			if plan.eau(c, l):
				images_eau += 1
			if plan.dans_un_batiment(p, 4.0):
				images_mur += 1
			var cap := float(auto["a"])
			if caps.has(id):
				var saut: float = abs(wrapf(cap - float(caps[id]), -PI, PI))
				pire_saut = maxf(pire_saut, saut)
				if saut > 0.12:
					sauts_forts += 1
				if saut > 0.01:
					virages += 1
			caps[id] = cap
			mesures_autos += 1
			if float(auto.get("vitesse", 0.0)) < 5.0 and float(auto.get("patience", 0.0)) <= 0.0 \
					and float(auto.get("bloque", 0.0)) > 0.0:
				coincees += 1
		if traces != null and pas % 3 == 0:
			for auto in ville.autos:
				if not bool(auto.get("garee", false)) and int(auto["genre"]) != VilleVivante.EPAVE:
					traces.store_line("auto;%d;%.2f;%.1f;%.1f;%.3f" % [int(auto["id"]), t, auto["p"].x, auto["p"].y, float(auto["a"])])
			for personne in ville.gens:
				traces.store_line("gens;%d;%.2f;%.1f;%.1f;%.3f" % [int(personne["id"]), t, personne["p"].x, personne["p"].y, float(personne["a"])])
		if pas % 10 == 0:
			for personne in ville.gens:
				var p: Vector2 = personne["p"]
				mesures_gens += 1
				if personne.has("route"):
					sur_trottoir += 1
				if float(personne.get("pause", 0.0)) > 0.0:
					en_pause += 1
				if plan.eau(int(floor(p.x / PlanVille.PAS)), int(floor(p.y / PlanVille.PAS))):
					gens_eau += 1
					if gens_eau <= 6:
						print("[trafic] passant dans l'eau : %s route=%s cote=%s but=%s genre=%d etat=%s fuite=%s attache=%s" % [str(p),
							str(personne.get("route")), str(personne.get("cote")), str(personne.get("but")), int(personne["genre"]),
							str(personne.get("etat")), str(personne.get("fuite")), str(personne.get("attache"))])
	print("[trafic] %s : %d s simulées, %d voitures nées, %d passants" % [code, int(duree), nes.size(), ville.gens.size()])
	print("[trafic] nées dans l'eau ou un mur : %d" % nes_eau)
	print("[trafic] images de voiture dans l'eau : %d · dans un mur : %d (sur %d)" % [images_eau, images_mur, mesures_autos])
	print("[trafic] pire saut de cap en une image : %.3f rad · sauts > 0,12 rad : %d · images en virage : %d" % [pire_saut, sauts_forts, virages])
	print("[trafic] voitures coincées (images) : %d / %d" % [coincees, mesures_autos])
	print("[trafic] tournants décidés à la naissance : %s" % str(tournants_totaux))
	print("[trafic] passants : %.0f %% sur un trottoir, %.0f %% en pause, %d mesures dans l'eau" % [
		100.0 * float(sur_trottoir) / maxf(1.0, float(mesures_gens)),
		100.0 * float(en_pause) / maxf(1.0, float(mesures_gens)), gens_eau])
	if traces != null:
		traces.close()
		# Le fond : les tuiles autour du joueur, pour lire les traces dessus.
		var fond := FileAccess.open(chemin_traces.get_basename() + "_fond.csv", FileAccess.WRITE)
		fond.store_line("c;l;sol")
		var c0 := int(floor((moi.x - 1500.0) / PlanVille.PAS))
		var l0 := int(floor((moi.y - 1500.0) / PlanVille.PAS))
		for l in range(l0, l0 + 31):
			for c in range(c0, c0 + 31):
				var sol := "rue"
				if plan.eau(c, l):
					sol = "eau"
				elif plan.bloquee(c, l):
					sol = "bati"
				elif not plan.voie_libre(c, l).is_empty():
					sol = "boulevard"
				elif not (PlanVille.est_voie(c) or PlanVille.est_voie(l)):
					sol = "pate"
				fond.store_line("%d;%d;%s" % [c, l, sol])
		fond.close()
	quit()
