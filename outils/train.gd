extends SceneTree
## LE BANC DU TRAIN (guide §1.3). Ce qu'il doit prouver, dans cet ordre :
##
##   1. la voie tombe DANS la ville — c'est le piège du passage d'unités
##      (`rail()` travaille en unités 3D, la simulation en pixels) ;
##   2. les rames circulent, marquent l'arrêt aux quais, et repartent ;
##   3. elles font demi-tour au terminus au lieu de sortir de la carte ;
##   4. elles fauchent ce qui est sur la voie, et RIEN à côté ;
##   5. un train à l'arrêt ne fauche personne et se laisse prendre ;
##   6. la casse (§1.3) tient sur le ballast, paie, et ne coûte pas une étoile.
##
## ⚠ La montée et le voyage vivent chez le CLIENT (`jeux/carnage.gd`, qui n'a
## pas de `class_name` et ne se charge pas hors scène). Ce banc vérifie donc ce
## que l'hôte en décide — `rame_a_quai` — et le reste se juge à l'écran.
##
##   godot --headless -s outils/train.gd [-- --code=ESSAI]

var _fautes := 0

func _init() -> void:
	var code := "TRAIN"
	for a in OS.get_cmdline_args():
		if a.begins_with("--code="): code = a.trim_prefix("--code=")
	var carte := PlanVille.new(code)
	print("── code %s" % code)
	_la_voie(carte)
	_la_circulation(carte)
	_le_fauchage(carte)
	_la_casse(carte)
	print("── %s" % ("TOUT PASSE" if _fautes == 0 else "%d FAUTE(S)" % _fautes))
	quit(1 if _fautes > 0 else 0)

func _dire(vrai: bool, texte: String) -> void:
	if not vrai:
		_fautes += 1
	print("   %s %s" % ["ok " if vrai else "RATÉ", texte])

func _ville(carte: PlanVille, graine: int) -> VilleVivante:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	return VilleVivante.new(carte, rng)

# ------------------------------------------------------------------ la voie

func _la_voie(carte: PlanVille) -> void:
	print("\n1. LA VOIE TOMBE DANS LA VILLE")
	var ville := _ville(carte, 5)
	var v := ville.voie()
	var largeur := float(PlanVille.COLONNES) * PlanVille.PAS
	var hauteur := float(PlanVille.LIGNES) * PlanVille.PAS
	var longueur: float = float(v["t1"]) - float(v["t0"])
	# ⚠ Le vrai piège est ici : `rail()` donne l'équation en unités 3D (une
	# tuile = 10), la simulation travaille en pixels (une tuile = 100). Sans la
	# division par ECHELLE, la voie faisait un dixième de la ville et les deux
	# rames tournaient dans le coin nord-ouest.
	_dire(longueur > largeur * 0.8,
		"la voie traverse la ville : %d px de long pour %d de large" % [int(longueur), int(largeur)])
	var dedans := 0
	var echantillons := 60
	for k in echantillons:
		var p := ville.point_de_voie(lerpf(float(v["t0"]), float(v["t1"]), float(k) / float(echantillons - 1)))
		if p.x >= 0.0 and p.y >= 0.0 and p.x <= largeur and p.y <= hauteur:
			dedans += 1
	_dire(dedans == echantillons, "%d points sur %d tombent dans la carte" % [dedans, echantillons])
	# Le sol peint les rails avec la MÊME équation. Un point de la voie doit
	# donc être sur du ballast, sinon le train roule sur le bitume.
	var sur_le_ballast := 0
	for k in echantillons:
		var p := ville.point_de_voie(lerpf(float(v["t0"]) + 400.0, float(v["t1"]) - 400.0,
			float(k) / float(echantillons - 1)))
		if carte.sur_le_rail(int(p.x / PlanVille.PAS), int(p.y / PlanVille.PAS)):
			sur_le_ballast += 1
	_dire(sur_le_ballast == echantillons,
		"%d points sur %d sont sur le ballast que le nuanceur dessine" % [sur_le_ballast, echantillons])
	var quais := ville.gares()
	_dire(quais.size() >= 3, "%d quais le long de la ligne" % quais.size())

# ---------------------------------------------------------- la circulation

func _la_circulation(carte: PlanVille) -> void:
	print("\n2. LES RAMES CIRCULENT ET MARQUENT L'ARRÊT")
	var ville := _ville(carte, 7)
	ville._mettre_les_rames_en_ligne()
	_dire(ville.trains.size() == VilleVivante.TRAINS, "%d rames en ligne" % ville.trains.size())
	var sens: Array = []
	for t in ville.trains:
		sens.append(float(t["sens"]))
	_dire(sens.has(1.0) and sens.has(-1.0), "elles ne partent pas dans le même sens")

	# Cinq minutes de service, à la cadence du jeu. On ne triche pas sur le
	# pas de temps : un train qui ne marche qu'à gros delta serait un train
	# qui ne marche pas.
	var arrets := 0
	var demi_tours := 0
	var sens_avant := float(ville.trains[0]["sens"])
	var v_max := 0.0
	var immobile_total := 0.0
	var pas := 1.0 / 60.0
	for image in 18000:
		ville._animer_les_trains(pas, {})
		var t: Dictionary = ville.trains[0]
		v_max = maxf(v_max, float(t["v"]))
		if float(t["arret"]) > 0.0:
			immobile_total += pas
		# ⚠ On compte l'IMAGE OÙ L'ARRÊT EST POSÉ, pas « arret proche de sept » :
		# à un soixantième près, la deuxième image d'un arrêt vaut encore
		# 6,983 et chaque halte se comptait deux fois.
		if float(t["arret"]) == VilleVivante.ARRET_EN_GARE:
			arrets += 1
		if float(t["sens"]) != sens_avant:
			demi_tours += 1
			sens_avant = float(t["sens"])
	# Un saut de quai à quai : onze mille pixels à neuf cent quarante, plus
	# sept secondes portes ouvertes — une vingtaine de secondes. Quinze haltes
	# en cinq minutes, c'est le compte.
	_dire(arrets >= 10 and arrets <= 20, "%d arrêts en cinq minutes" % arrets)
	_dire(v_max > VilleVivante.VITESSE_TRAIN * 0.98,
		"elle atteint sa vitesse de croisière (%d px/s)" % int(v_max))
	_dire(immobile_total > 5.0, "elle passe %d s à quai, portes ouvertes" % int(immobile_total))
	var v := ville.voie()
	var dehors := false
	for t in ville.trains:
		if float(t["s"]) < float(v["t0"]) - 1.0 or float(t["s"]) > float(v["t1"]) + 1.0:
			dehors = true
	# ⚠ Deux demi-tours, pas cinquante. Une rame qui se retourne à chaque
	# image au bout du quai passe le banc « elle ne sort pas de la ligne » sans
	# jamais quitter le terminus.
	_dire(not dehors, "aucune rame n'est sortie de la ligne")
	_dire(demi_tours <= 4, "%d demi-tour(s) au terminus, pas un tic nerveux" % demi_tours)

	# À quai, on doit pouvoir monter — et seulement là. C'est la fonction que
	# le client interroge, pas une copie.
	var a_quai := {}
	for image in 6000:
		ville._animer_les_trains(pas, {})
		if float(ville.trains[0]["arret"]) > 1.0:
			a_quai = ville.trains[0]
			break
	_dire(not a_quai.is_empty(), "une rame finit par s'arrêter à quai")
	if not a_quai.is_empty():
		var tete: Vector2 = ville.point_de_voie(float(a_quai["s"]))
		_dire(not ville.rame_a_quai(tete).is_empty(), "debout à la portière, on peut monter")
		var cote: Vector2 = tete + Vector2(ville.voie()["n"]) * (VilleVivante.QUAI + 60.0)
		_dire(ville.rame_a_quai(cote).is_empty(),
			"à %d px de la voie, non — un quai n'est pas un aimant" % int(VilleVivante.QUAI + 60.0))

# ------------------------------------------------------------- le fauchage

func _le_fauchage(carte: PlanVille) -> void:
	print("\n3. RIEN NE L'ARRÊTE, ET IL NE FAUCHE QUE LA VOIE")
	var ville := _ville(carte, 9)
	ville._mettre_les_rames_en_ligne()
	# On lance la rame à pleine vitesse : à l'arrêt elle ne doit rien faire,
	# et c'est justement ce qu'on vérifie juste après.
	var t: Dictionary = ville.trains[0]
	t["v"] = VilleVivante.VITESSE_TRAIN
	t["arret"] = 0.0
	var v := ville.voie()
	var sur := ville.point_de_voie(float(t["s"]) - float(t["sens"]) * 40.0)
	var a_cote := sur + Vector2(v["n"]) * (VilleVivante.LARGEUR_TRAIN + 60.0)
	ville.gens.append({"id": ville._id(), "p": sur, "d": Vector2.RIGHT, "genre": VilleVivante.PIETON,
		"gang": 0, "pv": 3, "etat": 0, "a": 0.0, "minuterie": 0.0, "recharge": 0.0})
	ville.gens.append({"id": ville._id(), "p": a_cote, "d": Vector2.RIGHT, "genre": VilleVivante.PIETON,
		"gang": 0, "pv": 3, "etat": 0, "a": 0.0, "minuterie": 0.0, "recharge": 0.0})
	ville.autos.append({"id": ville._id(), "p": sur, "d": Vector2.RIGHT, "a": 0.0,
		"genre": VilleVivante.CIVILE, "pv": 100.0, "pilote": "", "cible": "", "vitesse": 0.0,
		"minuterie": 0.0, "modele": 0, "garee": true})
	var joueurs := {
		"passager": {"p": sur, "vie": 100.0, "pied": true, "train": true, "d": Vector2.RIGHT,
			"a": 0.0, "v": 0.0, "seuil": 999.0, "arene": -1},
		"badaud": {"p": sur, "vie": 100.0, "pied": true, "train": false, "d": Vector2.RIGHT,
			"a": 0.0, "v": 0.0, "seuil": 999.0, "arene": -1},
	}
	ville.sortants.clear()
	ville._faucher(t, joueurs)
	_dire(ville.gens.size() == 1, "le piéton sur la voie est fauché, celui d'à côté non")
	if ville.gens.size() == 1:
		_dire(Vector2(ville.gens[0]["p"]) == a_cote, "  (et c'est bien celui d'à côté qui reste)")
	_dire(int(ville.autos[0]["genre"]) == VilleVivante.EPAVE, "la voiture en travers est détruite")
	var touches: Array = []
	for e in ville.sortants:
		if String(e["e"]) == "deg":
			touches.append(String(e["c"]["j"]))
	_dire(touches == ["badaud"], "le badaud prend le train, le passager non : %s" % str(touches))

	# ⚠ À L'ARRÊT, IL NE FAUCHE PLUS. Sans cette règle la portière ouverte
	# tuait celui qui vient la prendre : on ne pouvait tout simplement pas
	# monter dans le train.
	var immobile := _ville(carte, 11)
	immobile._mettre_les_rames_en_ligne()
	var t2: Dictionary = immobile.trains[0]
	t2["v"] = 0.0
	var ici := immobile.point_de_voie(float(t2["s"]) - float(t2["sens"]) * 40.0)
	immobile.gens.append({"id": immobile._id(), "p": ici, "d": Vector2.RIGHT,
		"genre": VilleVivante.PIETON, "gang": 0, "pv": 3, "etat": 0, "a": 0.0,
		"minuterie": 0.0, "recharge": 0.0})
	immobile._faucher(t2, {})
	_dire(immobile.gens.size() == 1, "un train à l'arrêt ne fauche personne")

# --------------------------------------------------------------- la casse

func _la_casse(carte: PlanVille) -> void:
	print("\n4. LA CASSE TIENT SUR LE BALLAST ET NE COÛTE PAS UNE ÉTOILE")
	var ville := _ville(carte, 13)
	var casses := ville.casses()
	_dire(casses.size() >= 4, "%d casses le long de la voie" % casses.size())

	# ⚠ Le vrai piège : la bande du ballast fait 110 px de chaque côté de
	# l'axe. Écartée de 200 px, la casse se posait ENTIÈREMENT sur le pâté
	# d'à côté, par-dessus les immeubles — et rien dans le code ne s'en
	# plaignait, il fallait la voir.
	var v := ville.voie()
	var dedans := 0
	for c in casses:
		var ecart: float = absf((Vector2(c["p"]) - Vector2(v["o"])).dot(Vector2(v["n"])))
		var bord: float = ecart + VilleVivante.RAYON_CASSE
		if bord <= PlanVille.LARGEUR_RAIL * 0.5 * PlanVille.PAS + 20.0:
			dedans += 1
	_dire(dedans == casses.size(),
		"%d/%d dalles tiennent dans la bande de ballast (±%d px)" % [dedans, casses.size(),
			int(PlanVille.LARGEUR_RAIL * 0.5 * PlanVille.PAS)])

	# ⚠ Et l'autre bout du même réglage : une dalle collée à l'axe se ferait
	# balayer par le convoi, voiture garée comprise.
	var au_large := 0
	for c in casses:
		var ecart: float = absf((Vector2(c["p"]) - Vector2(v["o"])).dot(Vector2(v["n"])))
		if ecart - VilleVivante.RAYON_CASSE * 0.5 > VilleVivante.LARGEUR_TRAIN:
			au_large += 1
	_dire(au_large == casses.size(), "et aucune n'est sous le convoi (%d px de large)"
		% int(VilleVivante.LARGEUR_TRAIN))

	var sur := Vector2(casses[0]["p"])
	_dire(ville.casse_de(sur) == 0, "garé sur la dalle, la casse répond")
	_dire(ville.casse_de(sur + Vector2(v["d"]) * (VilleVivante.RAYON_CASSE + 40.0)) < 0,
		"quarante pixels plus loin, non")

	# Le tarif suit la longueur du gabarit : une citadine ne vaut pas un camion.
	var citadine := ville.prix_de_la_casse(2)
	var camion := ville.prix_de_la_casse(8)
	_dire(camion > citadine, "la benne paie plus que la citadine : $%d contre $%d" % [camion, citadine])

	# Le broyage lui-même. Ce qui compte : la voiture DISPARAÎT (pas d'épave,
	# pas de brasier), la somme part au bon joueur, une caisse d'arme reste au
	# sol, et la police ne bouge pas — c'est la seule sortie propre d'un vol.
	var moi := "essai"
	var id := ville._id()
	ville.autos.append({"id": id, "p": sur, "d": Vector2.RIGHT, "a": 0.0,
		"genre": VilleVivante.CIVILE, "pv": 100.0, "pilote": moi, "cible": "", "vitesse": 0.0,
		"minuterie": 0.0, "modele": 8, "garee": false})
	var caisses_avant := ville.caisses.size()
	var etoiles_avant := ville.etoiles(moi)
	ville.sortants.clear()
	ville.broyer(moi, id, sur)
	_dire(ville.auto_par_id(id).is_empty(), "la voiture a disparu de la ville")
	_dire(ville.feux.is_empty(), "et elle ne laisse pas de brasier — ce n'est pas une explosion")
	_dire(ville.etoiles(moi) == etoiles_avant,
		"la police ne bouge pas (%d étoile(s) avant, %d après)" % [etoiles_avant, ville.etoiles(moi)])
	_dire(ville.caisses.size() == caisses_avant + 1, "une caisse d'arme reste sur le tapis")
	var paye := {}
	for e in ville.sortants:
		if String(e["e"]) == "broye":
			paye = e["c"]
	_dire(int(paye.get("m", 0)) == camion,
		"et la somme annoncée est celle du gabarit : $%d" % int(paye.get("m", 0)))
	_dire(String(paye.get("j", "")) == moi, "au bon joueur")
	_dire(ville.reveillees.has(id), "la dormante broyée ne repoussera pas")
