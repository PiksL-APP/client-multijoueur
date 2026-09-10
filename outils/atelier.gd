extends SceneTree
## LE BANC DE L'ATELIER : les cinq baies, les mines, l'huile, la bombe et les
## plaques. Sans image — ce sont des règles, pas des volumes.
##
## ⚠ On appelle les fonctions DU JEU : `FormesCarnage.baie_sous` pour savoir
## ce qu'on achète, `VilleVivante.poser_piege` et son tour d'horloge pour
## savoir ce qui saute. Un banc qui referait le calcul à sa façon vérifierait
## sa propre copie.
##
##   godot --headless -s outils/atelier.gd [-- --code=ESSAI]

var _fautes := 0

func _init() -> void:
	var code := "ATELIER"
	for a in OS.get_cmdline_args():
		if a.begins_with("--code="): code = a.trim_prefix("--code=")
	var carte := PlanVille.new(code)
	print("── code %s" % code)
	_baies(carte)
	_mines(carte)
	_huile(carte)
	_bombe(carte)
	_plaques(carte)
	print("── %s" % ("TOUT PASSE" if _fautes == 0 else "%d FAUTE(S)" % _fautes))
	quit(1 if _fautes > 0 else 0)

func _dire(vrai: bool, texte: String) -> void:
	if not vrai:
		_fautes += 1
	print("   %s %s" % ["ok " if vrai else "RATÉ", texte])

# ------------------------------------------------------------------ les baies

func _baies(carte: PlanVille) -> void:
	print("\n1. UN GARAGE SUR DEUX, CINQ BAIES")
	var garages := 0
	var ateliers := 0
	for sy in PlanVille.LIGNES / PlanVille.SECTEUR:
		for sx in PlanVille.COLONNES / PlanVille.SECTEUR:
			for g in carte.lieux_autour(
					PlanVille.centre_tuile(sx * PlanVille.SECTEUR + 2, sy * PlanVille.SECTEUR + 2),
					PlanVille.SECTEUR * PlanVille.PAS)["garages"]:
				garages += 1
				if FormesCarnage.est_atelier(int(g["id"])):
					ateliers += 1
	var part := float(ateliers) / maxf(1.0, float(garages))
	print("   %d garages, dont %d ateliers" % [garages, ateliers])
	_dire(part > 0.4 and part < 0.7, "un garage sur deux vend : %.0f %%" % (part * 100.0))

	# La baie qu'on désigne en se garant dessus. C'est LA question du système :
	# si deux baies se confondent, on achète des mines en croyant payer des
	# plaques, et on ne s'en aperçoit qu'en appuyant sur ESPACE.
	var centre := carte.centre()
	var justes := 0
	for i in FormesCarnage.ATELIER.size():
		var sur := centre + FormesCarnage.baie_atelier(i)
		if FormesCarnage.baie_sous(sur, centre) == i:
			justes += 1
	_dire(justes == FormesCarnage.ATELIER.size(),
		"chaque pastille se désigne elle-même (%d/%d)" % [justes, FormesCarnage.ATELIER.size()])
	# Et à mi-chemin de deux pastilles, on tombe sur l'une des deux, jamais sur
	# une troisième : sinon la marche à suivre serait « viser juste ».
	var voisines := 0
	for i in FormesCarnage.ATELIER.size():
		var j := (i + 1) % FormesCarnage.ATELIER.size()
		var milieu := centre + (FormesCarnage.baie_atelier(i) + FormesCarnage.baie_atelier(j)) * 0.5
		var trouve := FormesCarnage.baie_sous(milieu, centre)
		if trouve == i or trouve == j:
			voisines += 1
	_dire(voisines == FormesCarnage.ATELIER.size(), "entre deux pastilles, c'est l'une des deux")
	for fiche in FormesCarnage.ATELIER:
		print("   %-14s $%-5d %s" % [String(fiche["nom"]), int(fiche["prix"]), String(fiche["mot"])])

# ------------------------------------------------------------------ les mines

func _mines(carte: PlanVille) -> void:
	print("\n2. LA MINE S'AMORCE, PUIS ELLE MORD")
	var ville := _ville(carte)
	var ou := carte.centre()
	ville.poser_piege("moi", ou, VilleVivante.MINE)
	var auto := _une_auto(ville, ou)
	ville._animer_les_pieges(0.2, {})
	_dire(int(auto["genre"]) != VilleVivante.EPAVE, "elle ne saute pas sous celui qui la pose")
	_dire(ville.pieges.size() == 1, "elle est toujours là")
	ville._animer_les_pieges(VilleVivante.AMORCE_MINE, {})
	_dire(int(auto["genre"]) == VilleVivante.EPAVE, "amorcée, elle détruit la voiture")
	_dire(ville.pieges.is_empty(), "et elle disparaît : une mine ne saute qu'une fois")
	var marque := false
	for e in ville.sortants:
		if String(e["e"]) == "k" and String(e["c"].get("j", "")) == "moi":
			marque = true
	_dire(marque, "le poseur marque sa victime")

	# Le plafond : au-delà, la plus vieille s'efface.
	var ville2 := _ville(carte)
	for i in VilleVivante.PIEGES_MAX + 6:
		ville2.poser_piege("moi", ou + Vector2(i * 400.0, 0.0), VilleVivante.MINE)
	_dire(ville2.pieges.size() == VilleVivante.PIEGES_MAX,
		"la ville ne porte pas plus de %d pièges" % VilleVivante.PIEGES_MAX)

# ------------------------------------------------------------------ l'huile

func _huile(carte: PlanVille) -> void:
	print("\n3. L'HUILE FAIT PERDRE LE CAP, PAS LA VIE")
	var ville := _ville(carte)
	var ou := carte.centre()
	ville.poser_piege("moi", ou, VilleVivante.HUILE)
	var auto := _une_auto(ville, ou)
	auto["vitesse"] = 200.0
	var cap: Vector2 = auto["d"]
	var pv := float(auto["pv"])
	ville._animer_les_pieges(0.2, {"moi": {"p": ou, "vie": 100.0, "pied": false}})
	_dire(Vector2(auto["d"]).angle_to(cap) != 0.0, "la voiture part de travers")
	_dire(float(auto["pv"]) == pv, "et elle n'a pas une égratignure")
	_dire(float(auto["vitesse"]) < 200.0, "elle a perdu de la vitesse")
	var glisse := false
	for e in ville.sortants:
		if String(e["e"]) == "glisse" and String(e["c"].get("j", "")) == "moi":
			glisse = true
	_dire(glisse, "et elle glisse aussi sous celui qui l'a posée")
	_dire(ville.pieges.size() == 1, "la flaque reste : elle sert plusieurs fois")

# ------------------------------------------------------------------ la bombe

func _bombe(carte: PlanVille) -> void:
	print("\n4. LA BOMBE ATTEND QU'ON SOIT SORTI")
	var ville := _ville(carte)
	var auto := _une_auto(ville, carte.centre())
	ville.armer_bombe("moi", int(auto["id"]))
	ville._animer_les_bombes(VilleVivante.BOMBE_DELAI - 1.0)
	_dire(int(auto["genre"]) != VilleVivante.EPAVE, "elle laisse le temps de s'éloigner")
	ville._animer_les_bombes(1.2)
	_dire(int(auto["genre"]) == VilleVivante.EPAVE, "puis la voiture saute")
	_dire(ville.bombes.is_empty(), "et l'amorce est oubliée")

# ---------------------------------------------------------------- les plaques

func _plaques(carte: PlanVille) -> void:
	print("\n5. LES PLAQUES GÈLENT LA RECHERCHE")
	var ville := _ville(carte)
	ville.crime("moi", "flic")
	var avant := ville.etoiles("moi")
	_dire(avant > 0, "abattre un flic met %d étoile(s)" % avant)
	ville.plaques["moi"] = 45.0
	for _i in 6:
		ville.crime("moi", "flic")
	_dire(ville.etoiles("moi") == avant, "plaques posées, la jauge ne monte plus")
	_dire(ville.etoiles("moi") > 0, "mais elle ne redescend pas non plus : ce n'est pas le garage")
	# ⚠ On compte la CHALEUR, pas les étoiles : quarante-six secondes de ville
	# calme, c'est le refroidissement qui remet le compteur à zéro, et un flic
	# abattu redonne pile la même étoile qu'au début. Le banc annonçait donc
	# une faute là où le jeu faisait exactement ce qu'il fallait.
	for _t in 46:
		ville.simuler(1.0, 0.0, {})
	_dire(float(ville.plaques.get("moi", 0.0)) == 0.0, "au bout de quarante-cinq secondes, elles tombent")
	var froid := float(ville.chaleur.get("moi", 0.0))
	ville.crime("moi", "flic")
	_dire(float(ville.chaleur.get("moi", 0.0)) > froid,
		"et la police recommence à chauffer (%d -> %d)" % [int(froid), int(ville.chaleur.get("moi", 0.0))])

# ------------------------------------------------------------------ l'outil

func _ville(carte: PlanVille) -> VilleVivante:
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	return VilleVivante.new(carte, rng)

func _une_auto(ville: VilleVivante, ou: Vector2) -> Dictionary:
	var auto := {"id": ville._id(), "p": ou, "d": Vector2.RIGHT, "a": 0.0, "vitesse": 0.0,
		"genre": VilleVivante.CIVILE, "gang": -1, "pv": VilleVivante.PV_AUTO,
		"pilote": "", "cible": "", "minuterie": 0.0, "modele": 0, "garee": false}
	ville.autos.append(auto)
	return auto
