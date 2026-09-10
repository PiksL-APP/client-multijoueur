extends SceneTree
## LE BANC DES À-CÔTÉS (guide §4.3) : les colis, le Kill Frenzy, la course de
## taxi et les cascades.
##
## ⚠ Le taxi et les frôlements vivent chez le CLIENT (`jeux/carnage.gd`, qui
## n'a pas de `class_name` et ne se charge pas hors scène). Ce banc vérifie
## donc ce que l'hôte en voit : le paiement, le client qui quitte le trottoir,
## et les règles de la ville. La conduite, elle, se juge à l'écran.
##
##   godot --headless -s outils/missions.gd [-- --code=ESSAI]

var _fautes := 0

func _init() -> void:
	var code := "MISSIONS"
	for a in OS.get_cmdline_args():
		if a.begins_with("--code="): code = a.trim_prefix("--code=")
	var carte := PlanVille.new(code)
	print("── code %s" % code)
	_semailles(carte)
	_colis(carte)
	_frenzy(carte)
	_taxi(carte)
	print("── %s" % ("TOUT PASSE" if _fautes == 0 else "%d FAUTE(S)" % _fautes))
	quit(1 if _fautes > 0 else 0)

func _dire(vrai: bool, texte: String) -> void:
	if not vrai:
		_fautes += 1
	print("   %s %s" % ["ok " if vrai else "RATÉ", texte])

func _ville(carte: PlanVille) -> VilleVivante:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	return VilleVivante.new(carte, rng)

# ------------------------------------------------------------- les semailles

func _semailles(carte: PlanVille) -> void:
	print("\n1. LA VILLE SÈME SES À-CÔTÉS")
	var ville := _ville(carte)
	var ou := carte.centre()
	var joueurs := {"moi": {"p": ou, "vie": 100.0, "pied": true}}
	for _t in 400:
		ville.simuler(0.2, 0.0, joueurs)
	var colis := 0
	var frenzy := 0
	var loin_min := INF
	var loin_max := 0.0
	for r in ville.ramassages:
		if int(r["genre"]) == VilleVivante.R_COLIS:
			colis += 1
		else:
			frenzy += 1
		var d: float = (r["p"] as Vector2).distance_to(ou)
		loin_min = min(loin_min, d)
		loin_max = max(loin_max, d)
	_dire(colis == VilleVivante.COLIS_EN_VILLE, "%d colis posés" % colis)
	_dire(frenzy == VilleVivante.FRENZY_EN_VILLE, "%d icônes de frenzy" % frenzy)
	# ⚠ Ni sous le capot, ni à l'autre bout de la carte.
	_dire(loin_min > 300.0, "le plus proche est à %d px" % int(loin_min))
	_dire(loin_max < 2200.0, "le plus loin est à %d px" % int(loin_max))
	var sur_la_route := true
	for r in ville.ramassages:
		if not carte.sur_la_chaussee(r["p"]) and carte.degager(r["p"], 20.0)[1]:
			sur_la_route = false
	_dire(sur_la_route, "et aucun n'est posé dans un mur")

# ------------------------------------------------------------------ les colis

func _colis(carte: PlanVille) -> void:
	print("\n2. LES COLIS SE COMPTENT")
	var ville := _ville(carte)
	var ou := carte.centre()
	var gains := 0
	for i in VilleVivante.COLIS_OBJECTIF:
		var id := ville._id()
		ville.ramassages.append({"id": id, "p": ou, "genre": VilleVivante.R_COLIS, "arme": ""})
		ville.sortants.clear()
		ville.ramasser_a_cote(id, "moi", ou)
		for e in ville.sortants:
			if String(e["e"]) == "k":
				gains += int(e["c"].get("p", 0))
		if i == 0:
			_dire(int(ville.colis.get("moi", 0)) == 1, "le premier compte pour un")
	_dire(int(ville.colis["moi"]) == VilleVivante.COLIS_OBJECTIF,
		"les dix sont trouvés (%d)" % int(ville.colis["moi"]))
	var attendu := VilleVivante.PRIME_COLIS * VilleVivante.COLIS_OBJECTIF + VilleVivante.PRIME_COLLECTION
	_dire(gains == attendu, "et ils rapportent $%d, prime de collection comprise" % gains)
	var fini := false
	for e in ville.sortants:
		if String(e["e"]) == "colis" and bool(e["c"].get("fini", false)):
			fini = true
	_dire(fini, "la collection s'annonce")
	# Un colis ramassé ne se ramasse pas deux fois.
	var id2 := ville._id()
	ville.ramassages.append({"id": id2, "p": ou, "genre": VilleVivante.R_COLIS, "arme": ""})
	ville.ramasser_a_cote(id2, "moi", ou)
	ville.ramasser_a_cote(id2, "moi", ou)
	_dire(int(ville.colis["moi"]) == VilleVivante.COLIS_OBJECTIF + 1,
		"et un colis pris deux fois ne compte qu'une")

# ----------------------------------------------------------------- le frenzy

func _frenzy(carte: PlanVille) -> void:
	print("\n3. LE KILL FRENZY")
	var ville := _ville(carte)
	var ou := carte.centre()
	ville.lancer_frenzy("moi", "roquette")
	_dire(ville.frenzies.has("moi"), "le défi est lancé")
	_dire(String(_dernier(ville, "frenzy").get("a", "")) == "roquette",
		"avec son arme imposée")

	# Les victimes comptent — par le MÊME chemin que le score.
	for i in VilleVivante.OBJECTIF_FRENZY - 1:
		ville._avancer_frenzy("moi", ou)
	_dire(int(ville.frenzies["moi"]["fait"]) == VilleVivante.OBJECTIF_FRENZY - 1,
		"%d victimes comptées" % int(ville.frenzies["moi"]["fait"]))
	ville.sortants.clear()
	ville._avancer_frenzy("moi", ou)
	_dire(not ville.frenzies.has("moi"), "la dernière le solde")
	_dire(String(_dernier(ville, "frenzy").get("e", "")) == "gagne", "et il est gagné")
	var prime := 0
	for e in ville.sortants:
		if String(e["e"]) == "k":
			prime += int(e["c"].get("p", 0))
	_dire(prime == VilleVivante.PRIME_FRENZY, "la prime tombe : $%d" % prime)

	# Le chrono, lui, ne pardonne pas.
	var ville2 := _ville(carte)
	ville2.lancer_frenzy("moi", "mitraillette")
	ville2._avancer_frenzy("moi", ou)
	ville2.sortants.clear()
	ville2._avancer_les_frenzies(VilleVivante.DUREE_FRENZY + 0.1)
	_dire(not ville2.frenzies.has("moi"), "au bout du chrono, il s'arrête")
	_dire(String(_dernier(ville2, "frenzy").get("e", "")) == "perdu", "et il est perdu")

# ------------------------------------------------------------------- le taxi

func _taxi(carte: PlanVille) -> void:
	print("\n4. LA COURSE DE TAXI")
	var ville := _ville(carte)
	var ou := carte.centre()
	var joueurs := {"moi": {"p": ou, "vie": 100.0, "pied": false}}
	for _t in 40:
		ville.simuler(0.2, 0.0, joueurs)
	var client := {}
	for personne in ville.gens:
		if int(personne["genre"]) == VilleVivante.PIETON:
			client = personne
	_dire(not client.is_empty(), "il y a du monde sur le trottoir")
	if not client.is_empty():
		var avant := ville.gens.size()
		_dire(ville.embarquer_client(int(client["id"])), "le client monte")
		_dire(ville.gens.size() == avant - 1, "et quitte le trottoir")
		_dire(not ville.embarquer_client(int(client["id"])), "on ne le fait pas monter deux fois")

	# Le paiement passe par le même guichet que tout le reste.
	ville.sortants.clear()
	ville.payer("moi", ou, 480, "course")
	var paye := _dernier(ville, "k")
	_dire(int(paye.get("p", 0)) == 480, "la course paie $%d" % int(paye.get("p", 0)))
	_dire(String(paye.get("q", "")) == "course", "et le tableau sait que c'est une course")
	ville.sortants.clear()
	ville.payer("moi", ou, -10, "cascade")
	_dire(int(_dernier(ville, "k").get("p", -1)) == 0, "un montant négatif ne rapporte rien")

func _dernier(ville: VilleVivante, nom: String) -> Dictionary:
	var trouve := {}
	for e in ville.sortants:
		if String(e["e"]) == nom:
			trouve = e["c"]
	return trouve
