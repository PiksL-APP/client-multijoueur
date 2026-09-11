extends SceneTree
## LE BANC DE LA RECHERCHE : six crans, quatre corps, un fourgon qui se vide,
## un char qui canonne, une voiture volée qui sème la police d'un cran et une
## peinture qui voyage avec la carrosserie (guide §5 et §1.3).
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
	_semer(carte)
	_peinture(carte)
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

# ---------------------------------------------------- changer de voiture sème

## Une dormante civile près du centre : c'est ce qu'on trouve sous la main
## quand on descend d'une voiture repérée. Le banc la RÉVEILLE par la même
## fonction que le jeu (`reveiller`), il ne la fabrique pas.
func _dormante_civile(carte: PlanVille) -> Dictionary:
	for rayon in [400.0, 900.0, 2000.0]:
		for d in carte.dormantes_autour(carte.centre(), rayon):
			if int(d.get("gang", -1)) < 0:
				return d
	return {}

func _semer(carte: PlanVille) -> void:
	print("\n6. CHANGER DE VOITURE SÈME LA POLICE D'UN CRAN")
	var ville := _ville(carte, 31)
	var moi := "essai"
	var d := _dormante_civile(carte)
	_dire(not d.is_empty(), "une berline civile garée près du centre")
	if d.is_empty():
		return
	var auto := ville.reveiller(int(d["id"]))
	ville.chaleur[moi] = ville.chaleur_pour(3)
	ville.sortants.clear()
	ville.accorder_vehicule(moi, int(auto["id"]), Vector2(auto["p"]))
	_dire(String(auto["pilote"]) == moi, "on prend le volant")
	_dire(ville.etoiles(moi) == 2, "trois étoiles -> %d : ils cherchent l'autre voiture" % ville.etoiles(moi))
	# Un cran, pas une amnistie : la prochaine faute nous renvoie au troisième.
	var seme := false
	for e in ville.sortants:
		if String(e["e"]) == "seme":
			seme = true
	_dire(seme, "et le client en est prévenu (événement « seme »)")
	ville.crime(moi, "pieton")
	_dire(ville.etoiles(moi) == 3, "le crime suivant nous y renvoie (%d)" % ville.etoiles(moi))

	# Une étoile : on retombe à zéro — mais pas en dessous, et pas de miracle
	# quand on n'était pas recherché.
	ville.rendre_vehicule(moi, int(auto["id"]), Vector2(auto["p"]), 0.0, 100.0)
	ville.chaleur[moi] = ville.chaleur_pour(1)
	ville.accorder_vehicule(moi, int(auto["id"]), Vector2(auto["p"]))
	_dire(ville.etoiles(moi) == 0, "une étoile -> %d" % ville.etoiles(moi))
	ville.rendre_vehicule(moi, int(auto["id"]), Vector2(auto["p"]), 0.0, 100.0)
	ville.chaleur[moi] = 0.0
	ville.sortants.clear()
	ville.accorder_vehicule(moi, int(auto["id"]), Vector2(auto["p"]))
	var annonce := false
	for e in ville.sortants:
		if String(e["e"]) == "seme":
			annonce = true
	_dire(not annonce, "sans étoile, rien à semer : pas d'annonce")

	# ⚠ Voler une PATROUILLE est un crime, pas une cachette : la recherche
	# monte au lieu de descendre.
	var joueurs := {moi: {"p": carte.centre(), "vie": 100.0, "pied": true, "d": Vector2.RIGHT}}
	ville.chaleur[moi] = ville.chaleur_pour(3)
	var avant := ville.autos.size()
	ville._naitre_auto(joueurs, VilleVivante.PATROUILLE, moi)
	_dire(ville.autos.size() == avant + 1, "une patrouille arrive")
	if ville.autos.size() == avant + 1:
		var flic: Dictionary = ville.autos[ville.autos.size() - 1]
		flic["pilote"] = ""
		var chaleur_avant: float = ville.chaleur[moi]
		ville.accorder_vehicule(moi, int(flic["id"]), Vector2(flic["p"]))
		_dire(String(flic["pilote"]) == moi and float(ville.chaleur[moi]) > chaleur_avant,
			"la voler fait MONTER la chaleur (%d -> %d)" % [int(chaleur_avant), int(ville.chaleur[moi])])

# ------------------------------------------------------- la peinture voyage

func _peinture(carte: PlanVille) -> void:
	print("\n7. LA PEINTURE RESTE SUR LA CARROSSERIE")
	var hote := _ville(carte, 12)
	var moi := "essai"
	var d := _dormante_civile(carte)
	if d.is_empty():
		_dire(false, "pas de berline civile à repeindre")
		return
	var auto := hote.reveiller(int(d["id"]))
	hote.accorder_vehicule(moi, int(auto["id"]), Vector2(auto["p"]))
	# Le client repeint chez lui, puis rend la voiture AVEC sa teinte — c'est
	# l'hôte qui la garde pour tout le monde.
	var rose := Color("#ff4fa3")
	var teinte := rose.to_rgba32()
	hote.rendre_vehicule(moi, int(auto["id"]), Vector2(auto["p"]), 0.0, 100.0, 3, VilleVivante.CIVILE, teinte)
	_dire(int(auto.get("teinte", 0)) == teinte, "l'hôte retient la teinte")
	# ⚠ `Color(int)` n'existe pas en 4.5 : c'est `Color.hex` qui refait le
	# chemin inverse de `to_rgba32`, et il doit retomber sur la même couleur.
	_dire(Color.hex(teinte).is_equal_approx(rose), "et elle se relit à l'identique (Color.hex)")

	# ⚠ L'instantané ne porte que ce qu'un joueur VOIT (`_regarde`) : sans
	# personne à côté de la voiture, le client ne recevait rien du tout — et le
	# banc croyait la teinte perdue en route.
	var client := _ville(carte, 13)
	var regard := {"autre": {"p": Vector2(auto["p"]), "vie": 100.0, "pied": true, "d": Vector2.RIGHT}}
	client.appliquer_instantane(hote.instantane(regard))
	var recue := client.auto_par_id(int(auto["id"]))
	_dire(not recue.is_empty() and int(recue.get("teinte", 0)) == teinte,
		"le client la reçoit dans l'instantané")
	# Et si on la reprend, l'événement « pris » l'annonce : le voleur roule
	# dans une voiture rose, pas dans une voiture repeinte en blanc d'usine.
	hote.sortants.clear()
	hote.accorder_vehicule("autre", int(auto["id"]), Vector2(auto["p"]))
	var t_annonce := -1
	for e in hote.sortants:
		if String(e["e"]) == "pris":
			t_annonce = int(e["c"].get("t", -1))
	_dire(t_annonce == teinte, "et qui la reprend l'emporte avec sa peinture")
