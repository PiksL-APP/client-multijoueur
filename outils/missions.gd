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
	_bonus(carte)
	_repaire(carte)
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

# --------------------------------------------------------- les bonus nommés

## Les séries passent par les mêmes fonctions que le jeu : `_abattre` avec
## `ecrase` à vrai pour un passant écrasé, `detruire_auto` pour une épave.
func _bonus(carte: PlanVille) -> void:
	print("\n5. LES BONUS NOMMÉS")
	var ville := _ville(carte)
	var ou := carte.centre()
	var joueurs := {"moi": {"p": ou, "vie": 100.0, "pied": false, "d": Vector2.RIGHT}}
	# Cinq passants sous les roues, d'un coup : MEDICAL EMERGENCY.
	for i in 5:
		_passant(ville, ou + Vector2(30.0 * i, 0.0))
	ville.sortants.clear()
	var avant := ville.gens.size()
	for i in 5:
		ville._abattre(ville.gens[0], "moi", true)
	_dire(ville.gens.size() == avant - 5, "cinq passants écrasés")
	var noms: Array = []
	var prime := 0
	for e in ville.sortants:
		if String(e["e"]) == "bonus":
			noms.append(String(e["c"].get("n", "")))
		if String(e["e"]) == "k" and String(e["c"].get("q", "")) == "bonus":
			prime += int(e["c"].get("p", 0))
	_dire(noms == ["MEDICAL EMERGENCY"], "un seul MEDICAL EMERGENCY (%s)" % str(noms))
	_dire(prime == int(VilleVivante.SERIES["ecrases"]["prime"]), "payé $%d par le guichet commun" % prime)
	# Le sixième ne rejoue pas le bonus : la série est repartie de zéro.
	_passant(ville, ou)
	ville.sortants.clear()
	ville._abattre(ville.gens[ville.gens.size() - 1], "moi", true)
	var rejoue := false
	for e in ville.sortants:
		if String(e["e"]) == "bonus":
			rejoue = true
	_dire(not rejoue, "le sixième ne rejoue pas le bonus")
	# Abattus et non écrasés : rien. À la roquette, cinq passants ne sont pas
	# un exploit.
	var ville2 := _ville(carte)
	for i in 5:
		_passant(ville2, ou + Vector2(30.0 * i, 0.0))
	ville2.sortants.clear()
	for i in 5:
		ville2._abattre(ville2.gens[0], "moi", false)
	var abattus_bonus := false
	for e in ville2.sortants:
		if String(e["e"]) == "bonus":
			abattus_bonus = true
	_dire(not abattus_bonus, "cinq passants ABATTUS ne font pas de MEDICAL EMERGENCY")

	# Trois voitures détruites d'un coup : WIPE OUT.
	var ville3 := _ville(carte)
	for i in 3:
		ville3._naitre_auto(joueurs, VilleVivante.CIVILE, "moi")
	_dire(ville3.autos.size() >= 3, "trois voitures en ville")
	ville3.sortants.clear()
	var detruites := 0
	for auto in ville3.autos:
		if int(auto["genre"]) == VilleVivante.CIVILE and detruites < 3:
			ville3.detruire_auto(auto, "moi")
			detruites += 1
	var wipe := 0
	for e in ville3.sortants:
		if String(e["e"]) == "bonus" and String(e["c"].get("n", "")) == "WIPE OUT":
			wipe += 1
	_dire(detruites == 3 and wipe == 1, "trois épaves -> un WIPE OUT")

## Un passant posé là, comme la ville les pose (`_id`, les mêmes champs).
# --------------------------------------------------- les missions du repaire

## Le patron d'un repaire (guide §3) confie deux travaux qu'aucune cabine ne
## donne : la mallette d'un rival à rapporter, la tête de son lieutenant. On
## passe par `proposer_mission` comme le client le fait, avec le genre forcé —
## le jeu tire, le banc choisit.
func _repaire(carte: PlanVille) -> void:
	print("\n6. LES MISSIONS DU REPAIRE")
	var ville := _ville(carte)
	var moi := "moi"
	# Un repaire où l'on est allié, et un rival qui a le sien par ici.
	var repaires: Array = carte.lieux_autour(carte.centre(), PlanVille.SECTEUR * PlanVille.PAS * 2.0)["repaires"]
	_dire(not repaires.is_empty(), "%d repaire(s) autour du centre" % repaires.size())
	if repaires.is_empty():
		return
	var chez: Dictionary = repaires[0]
	var gang := int(chez["gang"])
	var tag: Vector2 = chez["p"]
	var joueurs := {moi: {"p": tag, "vie": 100.0, "pied": true, "d": Vector2.RIGHT}}

	# Le refus dit le chiffre, comme à la cabine.
	ville.proposer_mission(moi, gang, tag, "mallette")
	var refus := _dernier(ville, "ctr")
	_dire(String(refus.get("e", "")) == "refuse" and String(refus.get("t", "")).contains("80"),
		"sous 80 de respect, le patron refuse et le dit : %s" % String(refus.get("t", "")))
	ville._ajuster_respect(moi, gang, 45.0)          # 95 : allié
	ville.sortants.clear()

	# LA MALLETTE. Elle est posée chez le rival, au milieu de ses gars.
	ville.proposer_mission(moi, gang, tag, "mallette")
	var pris := _dernier(ville, "ctr")
	_dire(String(pris.get("e", "")) == "pris" and String(pris.get("k", "")) == "mallette",
		"la mission est prise : %s" % String(pris.get("t", "")))
	var c: Dictionary = ville.contrats.get(moi, {})
	var rival := int(c.get("rival", -1))
	_dire(rival >= 0 and rival != gang and rival in carte.rivaux(gang, tag), "le rival est un rival d'ici (%s)" % carte.nom_du_gang(rival))
	var chez_eux: Dictionary = carte.repaire_le_plus_proche(tag, rival)
	var mallette := {}
	for r in ville.ramassages:
		if int(r["genre"]) == VilleVivante.R_MALLETTE:
			mallette = r
	_dire(not mallette.is_empty() and String(mallette.get("pour", "")) == moi, "une mallette est posée, et elle est à nous")
	if not mallette.is_empty() and not chez_eux.is_empty():
		var d: float = Vector2(mallette["p"]).distance_to(chez_eux["p"])
		_dire(d >= VilleVivante.MALLETTE_PRES - 1.0 and d <= VilleVivante.MALLETTE_LOIN + 1.0,
			"à %d px du tag %s — chez eux, pas devant chez eux" % [int(d), carte.du_gang(rival)])
	_dire(pris.has("x") and int(pris["x"]) == int(Vector2(mallette.get("p", Vector2.ZERO)).x),
		"et le radar la pointe")
	# Un coéquipier qui passe dessus ne la prend pas.
	var avant := ville.ramassages.size()
	ville.ramasser_a_cote(int(mallette["id"]), "lui", mallette["p"])
	_dire(ville.ramassages.size() == avant and float(ville.contrats[moi]["fait"]) == 0.0,
		"un coéquipier qui passe dessus ne la prend pas")
	# Nous, si — et le repaire fouillé sort au complet.
	var gardes: Array = []
	for k in 3:
		var g := _quelqu_un(ville, VilleVivante.GANG, Vector2(chez_eux["p"]) + Vector2(20.0 * float(k), 30.0), rival)
		g["attache"] = chez_eux["p"]
		gardes.append(g)
	ville.sortants.clear()
	ville.ramasser_a_cote(int(mallette["id"]), moi, mallette["p"])
	var avance := _dernier(ville, "ctr")
	_dire(ville.ramassages.size() == avant - 1 and float(ville.contrats[moi]["fait"]) == 1.0,
		"nous, oui : la mallette est en main")
	_dire(String(avance.get("e", "")) == "avance" and int(avance.get("x", -1)) == int(tag.x),
		"le radar pointe maintenant le tag du patron : %s" % String(avance.get("t", "")))
	_dire(gardes[0].has("colere") and String(gardes[0]["colere"]["j"]) == moi,
		"et le repaire fouillé sort au complet (la colère)")
	# On la rapporte : sur le tag, la mission est soldée.
	var argent_avant := _gains(ville, moi)
	var resp_avant := ville.respect_pour(moi, gang)
	var resp_rival_avant := ville.respect_pour(moi, rival)
	joueurs[moi]["p"] = tag + Vector2(120.0, 0.0)
	ville._avancer_contrats(0.1, joueurs)
	var fin := _dernier(ville, "ctr")
	_dire(not ville.contrats.has(moi) and String(fin.get("e", "")) == "gagne", "rapportée sur le tag : gagnée")
	_dire(_gains(ville, moi) - argent_avant == VilleVivante.PRIME_MISSION["mallette"],
		"payée $%d" % (_gains(ville, moi) - argent_avant))
	_dire(is_equal_approx(ville.respect_pour(moi, gang) - resp_avant, min(VilleVivante.RESPECT_MISSION, 100.0 - resp_avant))
		and ville.respect_pour(moi, rival) < resp_rival_avant,
		"le patron vous en sait gré (+%d), le rival moins (%d)" % [
			int(ville.respect_pour(moi, gang) - resp_avant), int(ville.respect_pour(moi, rival) - resp_rival_avant)])

	# Une mission en main : le patron n'en donne pas deux.
	ville.proposer_mission(moi, gang, tag, "lieutenant")
	ville.sortants.clear()
	ville.proposer_mission(moi, gang, tag, "mallette")
	_dire(String(_dernier(ville, "ctr").get("e", "")) == "refuse", "une mission en main, le patron n'en donne pas deux")
	ville.contrats.erase(moi)
	# ⚠ Le lieutenant de la mission qu'on vient d'effacer reste marqué : c'est
	# `_solder_contrat` qui range, pas `erase`. On le nettoie à la main.
	for personne in ville.gens:
		personne.erase("lieutenant")

	# LE LIEUTENANT. Un homme du repaire rival, trois fois plus dur, marqué.
	ville.sortants.clear()
	ville.proposer_mission(moi, gang, tag, "lieutenant")
	pris = _dernier(ville, "ctr")
	_dire(String(pris.get("e", "")) == "pris" and String(pris.get("k", "")) == "lieutenant",
		"la mission est prise : %s" % String(pris.get("t", "")))
	var lieutenant := {}
	for personne in ville.gens:
		if VilleVivante.est_lieutenant(personne):
			lieutenant = personne
	_dire(not lieutenant.is_empty() and int(lieutenant.get("pv", 0)) == VilleVivante.PV_LIEUTENANT
		and lieutenant.has("attache"),
		"un lieutenant à %d points de tôle, attaché à son repaire" % int(lieutenant.get("pv", 0)))
	var instantane := ville.instantane({moi: {"p": lieutenant["p"], "vie": 100.0, "pied": true}})
	var marque := false
	for entree in instantane.get("g", []):
		if int(entree[0]) == int(lieutenant["id"]):
			marque = entree.size() > 8 and int(entree[8]) == 1
	_dire(marque, "l'instantané le marque pour les clients")
	# Le blesser suffit à sortir ses gars.
	var copain := _quelqu_un(ville, VilleVivante.GANG, Vector2(lieutenant["p"]) + Vector2(40.0, 0.0), rival)
	copain["attache"] = lieutenant["attache"]
	ville.abattre_par_id(int(lieutenant["id"]), moi, 0.0)
	_dire(int(lieutenant["pv"]) == VilleVivante.PV_LIEUTENANT - 1 and copain.has("colere"),
		"une balle : il tient, et ses gars sortent")
	# Un coéquipier l'achève : la mission est à nous quand même.
	argent_avant = _gains(ville, moi)
	for _b in VilleVivante.PV_LIEUTENANT:
		ville.abattre_par_id(int(lieutenant["id"]), "lui", 0.0)
	fin = _dernier(ville, "ctr")
	_dire(not ville.contrats.has(moi) and String(fin.get("e", "")) == "gagne",
		"il tombe sous les balles d'un coéquipier : gagnée quand même")
	_dire(_gains(ville, moi) - argent_avant == VilleVivante.PRIME_MISSION["lieutenant"],
		"payée $%d" % (_gains(ville, moi) - argent_avant))

	# Le chrono : au bout, la mallette disparaît et le lieutenant redevient
	# un homme comme les autres.
	ville.sortants.clear()
	ville.proposer_mission(moi, gang, tag, "mallette")
	var posees := 0
	for r in ville.ramassages:
		if int(r["genre"]) == VilleVivante.R_MALLETTE:
			posees += 1
	ville.contrats[moi]["reste"] = 0.05
	ville._avancer_contrats(0.1, joueurs)
	var restantes := 0
	for r in ville.ramassages:
		if int(r["genre"]) == VilleVivante.R_MALLETTE:
			restantes += 1
	_dire(String(_dernier(ville, "ctr").get("e", "")) == "perdu" and posees == 1 and restantes == 0,
		"au bout du chrono, perdue — et la mallette est ramassée par la ville")
	ville.sortants.clear()
	ville.proposer_mission(moi, gang, tag, "lieutenant")
	ville.contrats[moi]["reste"] = 0.05
	ville._avancer_contrats(0.1, joueurs)
	var marques := 0
	for personne in ville.gens:
		if VilleVivante.est_lieutenant(personne):
			marques += 1
	_dire(String(_dernier(ville, "ctr").get("e", "")) == "perdu" and marques == 0,
		"idem pour le lieutenant, qui perd sa marque")

## Ce que le guichet commun a versé à `cle` depuis le début.
func _gains(ville: VilleVivante, cle: String) -> int:
	var total := 0
	for e in ville.sortants:
		if String(e["e"]) == "k" and String(e["c"].get("j", "")) == cle:
			total += int(e["c"].get("p", 0))
	return total

func _quelqu_un(ville: VilleVivante, genre: int, ou: Vector2, gang: int) -> Dictionary:
	var fiche := {"id": ville._id(), "p": ou, "d": Vector2.RIGHT, "a": 0.0,
		"genre": genre, "gang": gang, "pv": VilleVivante.PV_GANG, "etat": 0, "minuterie": 9.0, "recharge": 0.0}
	ville.gens.append(fiche)
	return fiche

func _passant(ville: VilleVivante, ou: Vector2) -> Dictionary:
	var fiche := {"id": ville._id(), "p": ou, "d": Vector2.RIGHT, "a": 0.0,
		"genre": VilleVivante.PIETON, "gang": -1, "pv": VilleVivante.PV_PIETON,
		"etat": 0, "minuterie": 9.0, "recharge": 0.0}
	ville.gens.append(fiche)
	return fiche
