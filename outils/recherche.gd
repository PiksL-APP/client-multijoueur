extends SceneTree
## LE BANC DE LA RECHERCHE : six crans, quatre corps, un fourgon qui se vide et
## un char qui canonne (guide §5).
##
## ⚠ Tout passe par `VilleVivante.simuler` ou par les fonctions qu'elle
## appelle. Fabriquer un flic à la main dans le banc pour vérifier qu'un flic
## tire, c'est vérifier que le banc sait fabriquer un flic.
##
##   godot --headless -s outils/recherche.gd [-- --code=ESSAI]

var _fautes := 0

func _init() -> void:
	var code := "RECHERCHE"
	for a in OS.get_cmdline_args():
		if a.begins_with("--code="): code = a.trim_prefix("--code=")
	var carte := PlanVille.new(code)
	print("── code %s" % code)
	_crans(carte)
	_corps(carte)
	_fourgon(carte)
	_char(carte)
	_reseau(carte)
	print("── %s" % ("TOUT PASSE" if _fautes == 0 else "%d FAUTE(S)" % _fautes))
	quit(1 if _fautes > 0 else 0)

func _dire(vrai: bool, texte: String) -> void:
	if not vrai:
		_fautes += 1
	print("   %s %s" % ["ok " if vrai else "RATÉ", texte])

func _ville(carte: PlanVille, graine: int = 4) -> VilleVivante:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	return VilleVivante.new(carte, rng)

# ------------------------------------------------------------------ les crans

func _crans(carte: PlanVille) -> void:
	print("\n1. SIX CRANS")
	var ville := _ville(carte)
	_dire(VilleVivante.PALIERS.size() == 6, "%d paliers" % VilleVivante.PALIERS.size())
	var monte := true
	for i in VilleVivante.PALIERS.size() - 1:
		if float(VilleVivante.PALIERS[i]) >= float(VilleVivante.PALIERS[i + 1]):
			monte = false
	_dire(monte, "et ils montent")
	for niveau in range(1, 7):
		ville.chaleur["moi"] = ville.chaleur_pour(niveau)
		_dire(ville.etoiles("moi") == niveau, "%d point(s) de chaleur -> %d étoile(s)"
			% [int(ville.chaleur["moi"]), ville.etoiles("moi")])

# ------------------------------------------------------------------ les corps

func _corps(carte: PlanVille) -> void:
	print("\n2. QUATRE CORPS, ET CHACUN SON CRAN")
	for c in VilleVivante.CORPS:
		print("   %-14s %2d pv, %.2f s, %2d dégâts, %d px"
			% [String(c["nom"]), int(c["pv"]), float(c["cadence"]), int(c["degat"]), int(c["portee"])])
	var dur := true
	for i in VilleVivante.CORPS.size() - 1:
		var a: Dictionary = VilleVivante.CORPS[i]
		var b: Dictionary = VilleVivante.CORPS[i + 1]
		if int(b["pv"]) <= int(a["pv"]) or float(b["degat"]) <= float(a["degat"]):
			dur = false
	_dire(dur, "chaque corps est plus dur que le précédent")

	# ⚠ LA question de la phase : est-ce qu'on peut tomber sur l'armée à deux
	# étoiles ? Mille tirages par cran, c'est peu cher et ça ne laisse pas
	# passer un `>=` écrit à l'envers.
	var ville := _ville(carte)
	for niveau in range(1, 7):
		var vus := {}
		for _t in 1000:
			vus[ville.corps_pour(niveau)] = true
		var noms: Array = []
		for c in vus.keys():
			noms.append(String(VilleVivante.CORPS[int(c)]["nom"]))
		noms.sort()
		var attendu := not (
			(VilleVivante.CORPS_SWAT in vus and niveau < VilleVivante.NIVEAU_SWAT)
			or (VilleVivante.CORPS_AGENT in vus and niveau < VilleVivante.NIVEAU_AGENTS)
			or (VilleVivante.CORPS_ARMEE in vus and niveau < VilleVivante.NIVEAU_ARMEE))
		_dire(attendu, "à %d étoile(s) : %s" % [niveau, ", ".join(noms)])
	var tout := {}
	for _t2 in 1000:
		tout[ville.corps_pour(6)] = true
	_dire(VilleVivante.CORPS_POLICE in tout, "et la police ordinaire reste de la partie à six")

# ---------------------------------------------------------------- le fourgon

func _fourgon(carte: PlanVille) -> void:
	print("\n3. LE FOURGON DU SWAT SE VIDE")
	var ville := _ville(carte)
	var ou := carte.centre()
	var joueurs := {"moi": {"p": ou, "vie": 100.0, "pied": true, "d": Vector2.RIGHT}}
	ville.chaleur["moi"] = ville.chaleur_pour(VilleVivante.NIVEAU_SWAT)
	ville._naitre_auto(joueurs, VilleVivante.PATROUILLE, "moi", VilleVivante.CORPS_SWAT)
	var fourgon := {}
	for auto in ville.autos:
		if int(auto.get("corps", 0)) == VilleVivante.CORPS_SWAT:
			fourgon = auto
	_dire(not fourgon.is_empty(), "un fourgon est parti")
	if fourgon.is_empty():
		return
	_dire(int(fourgon["modele"]) == int(VilleVivante.CORPS[VilleVivante.CORPS_SWAT]["modele"]),
		"il a la carrosserie du fourgon (%d)" % int(fourgon["modele"]))
	var avant := ville.gens.size()
	# On le pose à portée : la conduite l'y amènerait, mais le banc n'a pas
	# trente secondes à perdre à regarder une voiture rouler.
	fourgon["p"] = ou + Vector2(VilleVivante.PORTEE_DEBARQUEMENT * 0.6, 0.0)
	ville._conduire_patrouille(fourgon, 0.1, joueurs)
	_dire(ville.gens.size() == avant + VilleVivante.DEBARQUEMENT,
		"il débarque %d hommes" % (ville.gens.size() - avant))
	var tous_swat := true
	for personne in ville.gens:
		if int(personne.get("corps", -1)) != VilleVivante.CORPS_SWAT:
			tous_swat = false
		if int(personne["pv"]) != int(VilleVivante.CORPS[VilleVivante.CORPS_SWAT]["pv"]):
			tous_swat = false
	_dire(tous_swat, "et ils sont du SWAT, avec ses points de vie")
	var encore := ville.gens.size()
	ville._conduire_patrouille(fourgon, 0.1, joueurs)
	_dire(ville.gens.size() == encore, "un fourgon ne se vide qu'une fois")

# -------------------------------------------------------------------- le char

func _char(carte: PlanVille) -> void:
	print("\n4. LE CHAR CANONNE")
	var ville := _ville(carte)
	var ou := carte.centre()
	var joueurs := {"moi": {"p": ou, "vie": 100.0, "pied": false, "d": Vector2.RIGHT}}
	ville.chaleur["moi"] = ville.chaleur_pour(6)
	ville._naitre_auto(joueurs, VilleVivante.PATROUILLE, "moi", VilleVivante.CORPS_ARMEE, true)
	var tank := {}
	for auto in ville.autos:
		if bool(auto.get("canon", false)):
			tank = auto
	_dire(not tank.is_empty(), "un char est arrivé")
	if tank.is_empty():
		return
	_dire(float(tank["pv"]) == VilleVivante.PV_CHAR, "il encaisse %d points" % int(tank["pv"]))

	# Trop loin : rien ne part.
	tank["p"] = ou + Vector2(VilleVivante.PORTEE_OBUS + 200.0, 0.0)
	ville.sortants.clear()
	ville._conduire_patrouille(tank, 0.1, joueurs)
	_dire(_compter(ville, "obus") == 0, "hors de portée, il ne tire pas")

	# À portée : un obus, puis la recharge.
	tank["p"] = ou + Vector2(300.0, 0.0)
	tank["recharge"] = 0.0
	ville.sortants.clear()
	ville._conduire_patrouille(tank, 0.1, joueurs)
	_dire(_compter(ville, "obus") == 1, "à portée, un obus part")
	ville.sortants.clear()
	ville._conduire_patrouille(tank, 0.1, joueurs)
	_dire(_compter(ville, "obus") == 0, "et il recharge avant le suivant")

	# Le souffle touche le joueur, même en voiture — mille tirs pour ne pas
	# dépendre de la dispersion.
	var touche := 0
	for _t in 200:
		tank["recharge"] = 0.0
		ville.sortants.clear()
		ville._conduire_patrouille(tank, 0.1, joueurs)
		for e in ville.sortants:
			if String(e["e"]) == "deg" and String(e["c"].get("k", "")) == "obus":
				touche += 1
	_dire(touche > 40, "le souffle touche %d fois sur 200 (dispersion)" % touche)
	_dire(touche < 200, "et il rate parfois : un obus qui tombe toujours dessus, c'est injouable")

func _compter(ville: VilleVivante, nom: String) -> int:
	var total := 0
	for e in ville.sortants:
		if String(e["e"]) == nom:
			total += 1
	return total

# ------------------------------------------------------------------- le réseau

## Ce que les AUTRES joueurs voient. Le corps et le canon ont été ajoutés aux
## lignes de l'instantané : s'ils ne voyagent pas, l'armée arrive en bleu chez
## le voisin et le char n'a pas de canon.
func _reseau(carte: PlanVille) -> void:
	print("\n5. LE CORPS VOYAGE")
	var hote := _ville(carte)
	var ou := carte.centre()
	var joueurs := {"moi": {"p": ou, "vie": 100.0, "pied": true, "d": Vector2.RIGHT}}
	hote.chaleur["moi"] = hote.chaleur_pour(6)
	hote._naitre_auto(joueurs, VilleVivante.PATROUILLE, "moi", VilleVivante.CORPS_ARMEE, true)
	hote._poser_uniforme(ou + Vector2(60, 0), VilleVivante.CORPS_AGENT)
	for auto in hote.autos:
		auto["p"] = ou

	var client := _ville(carte, 9)
	client.appliquer_instantane(hote.instantane(joueurs))
	var canon := false
	for auto in client.autos:
		if bool(auto.get("canon", false)) and int(auto.get("corps", -1)) == VilleVivante.CORPS_ARMEE:
			canon = true
	_dire(canon, "le char arrive avec son canon et sa tenue")
	var agent := false
	for personne in client.gens:
		if int(personne.get("corps", -1)) == VilleVivante.CORPS_AGENT:
			agent = true
	_dire(agent, "et l'agent spécial avec la sienne")
