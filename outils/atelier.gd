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
	_canon_a_eau(carte)
	_lance_flammes(carte)
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
	print("\n4. LA BOMBE SAUTE AU DÉTONATEUR, OU SOUS UN VOLEUR")
	var ville := _ville(carte)
	var ou := carte.centre()
	var auto := _une_auto(ville, ou)
	var autre := _une_auto(ville, ou + Vector2(400.0, 0.0))
	ville.armer_bombe("moi", int(auto["id"]))
	ville.armer_bombe("moi", int(autre["id"]))
	ville._animer_les_bombes(30.0)
	_dire(int(auto["genre"]) != VilleVivante.EPAVE and ville.bombes.size() == 2,
		"armée, elle attend — trente secondes plus tard, rien n'a sauté")
	# Le poseur remonte dans sa propre voiture : elle ne saute pas.
	ville.accorder_vehicule("moi", int(auto["id"]), auto["p"])
	_dire(String(auto["pilote"]) == "moi" and int(auto["genre"]) != VilleVivante.EPAVE and ville.bombes.has(int(auto["id"])),
		"le poseur remonte dedans sans qu'elle saute, et elle reste armée")
	auto["pilote"] = ""
	# Un voleur prend le volant de l'autre : elle saute sous lui.
	ville.sortants.clear()
	ville.accorder_vehicule("lui", int(autre["id"]), autre["p"])
	var tue := false
	var prevenu := {}
	for e in ville.sortants:
		if String(e["e"]) == "deg" and String(e["c"].get("j", "")) == "lui" and int(e["c"].get("d", 0)) >= 100:
			tue = true
		if String(e["e"]) == "deto":
			prevenu = e["c"]
	_dire(String(autre["pilote"]) == "" and int(autre["genre"]) == VilleVivante.EPAVE,
		"un voleur prend le volant de l'autre : elle saute, il n'a pas le véhicule")
	_dire(tue, "et il y reste")
	_dire(String(prevenu.get("j", "")) == "moi" and String(prevenu.get("vol", "")) == "lui" and int(prevenu.get("id", -1)) == int(autre["id"]),
		"le poseur en est prévenu, avec le nom du voleur")
	_dire(not ville.bombes.has(int(autre["id"])), "et l'amorce est oubliée")
	# Le détonateur : ce qui reste piégé saute d'un coup, où que ce soit.
	ville.sortants.clear()
	var loin := _une_auto(ville, ou + Vector2(3000.0, 3000.0))
	ville.armer_bombe("moi", int(loin["id"]))
	var combien := ville.declencher_les_bombes("moi")
	_dire(combien == 2 and int(auto["genre"]) == VilleVivante.EPAVE and int(loin["genre"]) == VilleVivante.EPAVE,
		"le détonateur : les deux voitures piégées sautent, même à trois mille pixels")
	_dire(ville.bombes.is_empty() and int(_dernier_deto(ville).get("n", 0)) == 2, "plus rien d'armé, et l'hôte le dit (n = 2)")
	_dire(ville.declencher_les_bombes("moi") == 0, "appuyer encore ne fait rien sauter")
	# Une voiture brûlée autrement s'oublie aussi.
	var brulee := _une_auto(ville, ou + Vector2(0.0, 300.0))
	ville.armer_bombe("moi", int(brulee["id"]))
	ville.detruire_auto(brulee, "personne")
	ville._animer_les_bombes(0.1)
	_dire(ville.bombes.is_empty(), "une voiture piégée qui brûle autrement ne compte plus")

func _dernier_deto(ville: VilleVivante) -> Dictionary:
	var trouve := {}
	for e in ville.sortants:
		if String(e["e"]) == "deto":
			trouve = e["c"]
	return trouve

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

# ------------------------------------------------------------ le canon à eau

## Au volant d'un camion de pompiers, la touche de tir arrose (guide §6.2) :
## le jet éteint ce qui brûle devant et couche les passants sans les blesser.
func _canon_a_eau(carte: PlanVille) -> void:
	print("\n6. LE CANON À EAU ÉTEINT ET COUCHE, SANS BLESSER")
	var ville := _ville(carte)
	var ou := carte.centre()
	# Un feu devant, un feu derrière : seul celui du cône baisse.
	ville.allumer(ou + Vector2(140.0, 0.0), 1.0)
	ville.allumer(ou - Vector2(140.0, 0.0), 1.0)
	var devant: Dictionary = ville.feu_le_plus_proche(ou + Vector2(140.0, 0.0))
	var derriere: Dictionary = ville.feu_le_plus_proche(ou - Vector2(140.0, 0.0))
	var force_devant := float(devant["force"])
	var force_derriere := float(derriere["force"])
	var touches := ville.arroser_devant(ou, 0.0, 0.5)
	_dire(int(touches["feux"]) == 1 and float(devant["force"]) < force_devant,
		"le feu devant baisse (%.2f -> %.2f)" % [force_devant, float(devant["force"])])
	_dire(float(derriere["force"]) == force_derriere, "celui derrière ne bouge pas")
	# Trois secondes de lance : il s'éteint.
	for _t in 6:
		ville.arroser_devant(ou, 0.0, 0.5)
	_dire(float(devant["force"]) <= 0.0, "trois secondes de lance, et il est éteint")
	# Un passant dans le jet est poussé, en fuite, et entier.
	var passant := _un_passant(ville, ou + Vector2(120.0, 10.0))
	var pv := int(passant["pv"])
	var avant: Vector2 = passant["p"]
	var un_autre := _un_passant(ville, ou + Vector2(120.0, 200.0))
	var la_bas: Vector2 = un_autre["p"]
	touches = ville.arroser_devant(ou, 0.0, 0.5)
	_dire(int(touches["gens"]) == 1 and (passant["p"] as Vector2).x > avant.x + 60.0,
		"le passant dans le jet recule de %d px" % int((passant["p"] as Vector2).x - avant.x))
	_dire(float(passant.get("fuite", 0.0)) > 0.0 and Vector2(passant["d"]).x > 0.9,
		"et il fuit dans le sens du jet")
	_dire(int(passant["pv"]) == pv, "sans une égratignure")
	_dire(un_autre["p"] == la_bas, "celui hors du cône n'a rien senti")
	# La portée : à trois cents pixels, rien.
	var loin := _un_passant(ville, ou + Vector2(300.0, 0.0))
	var p_loin: Vector2 = loin["p"]
	ville.arroser_devant(ou, 0.0, 0.5)
	_dire(loin["p"] == p_loin, "à trois cents pixels, le jet ne porte plus")

func _un_passant(ville: VilleVivante, ou: Vector2) -> Dictionary:
	var fiche := {"id": ville._id(), "p": ou, "d": Vector2.RIGHT, "a": 0.0,
		"genre": VilleVivante.PIETON, "gang": -1, "pv": VilleVivante.PV_PIETON,
		"etat": 0, "minuterie": 9.0, "recharge": 0.0}
	ville.gens.append(fiche)
	return fiche

# ------------------------------------------------------------ le lance-flammes

## Le patron d'un repaire laisse le lance-flammes à la première mission rendue
## (guide §6.2) ; au volant du camion, la lance crache alors du feu : les
## passants grillent, les voitures des autres brûlent, un foyer s'allume.
func _lance_flammes(carte: PlanVille) -> void:
	print("\n7. LE LANCE-FLAMMES, LAISSÉ PAR LE PATRON")
	var ville := _ville(carte)
	var ou := carte.centre()
	# Sans lui, la lance ne crache rien.
	var passant := _un_passant(ville, ou + Vector2(100.0, 0.0))
	var touches := ville.enflammer_devant("moi", ou, 0.0, 0.5)
	_dire(int(touches["gens"]) == 0 and int(passant["pv"]) == VilleVivante.PV_PIETON,
		"sans le lance-flammes, la lance ne crache rien")
	# Une mission rendue, et le patron le laisse.
	ville.contrats["moi"] = {"genre": "mallette", "employeur": 0, "rival": 3, "fait": 2.0,
		"reste": 30.0, "p": ou, "retour": ou, "prime": 100, "respect": 1.0, "objectif": 2}
	ville._solder_contrat("moi", true)
	var laisse := false
	for e in ville.sortants:
		if String(e["e"]) == "lance" and String(e["c"].get("j", "")) == "moi":
			laisse = true
	_dire(ville.a_le_lance_flammes("moi") and laisse, "une mission rendue : le patron laisse le lance-flammes, et le dit")
	ville.sortants.clear()
	# Le passant dans le cône grille en une seconde ; celui derrière, non.
	var derriere := _un_passant(ville, ou - Vector2(100.0, 0.0))
	var mienne := _une_auto(ville, ou + Vector2(120.0, 20.0))
	mienne["pilote"] = "moi"
	var sienne := _une_auto(ville, ou + Vector2(130.0, -20.0))
	var pv_sienne := float(sienne["pv"])
	var avant := ville.gens.size()
	for _t in 4:
		ville.enflammer_devant("moi", ou, 0.0, 0.25)
	_dire(ville.gens.size() == avant - 1 and derriere in ville.gens, "le passant dans le cône grille en une seconde, celui derrière non")
	_dire(float(mienne["pv"]) == VilleVivante.PV_AUTO, "sa propre voiture ne brûle pas")
	_dire(float(sienne["pv"]) < pv_sienne and float(sienne["pv"]) > 0.0,
		"celle d'un autre chauffe (%d)" % int(sienne["pv"]))
	for _t in 10:
		ville.enflammer_devant("moi", ou, 0.0, 0.25)
	_dire(int(sienne["genre"]) == VilleVivante.EPAVE, "et finit en épave")
	var foyer := false
	for f in ville.feux:
		if Vector2(f["p"]).distance_to(ou) < VilleVivante.PORTEE_FLAMME + 40.0:
			foyer = true
	_dire(foyer, "un foyer s'est allumé au bout du jet")
	_dire(ville.etoiles("moi") >= 1 or float(ville.chaleur.get("moi", 0.0)) > 0.0, "et la police a entendu")
