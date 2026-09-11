extends SceneTree
## LE BANC DU RESPECT : les sept gangs tiennent-ils trois par district, les
## cinq paliers font-ils ce qu'ils annoncent, et un allié tire-t-il vraiment ?
##
## Pourquoi un banc SANS IMAGE ici : le respect est une table de nombres et
## une poignée de seuils. Une capture d'écran ne prouverait rien — elle
## montrerait la barre que le tableau de bord veut bien peindre, pas la
## décision que le gang prend. On interroge donc `VilleVivante` et `PlanVille`
## directement, avec les MÊMES fonctions que le jeu appelle.
##
##   godot --headless -s outils/respect.gd [-- --code=ESSAI]

var _fautes := 0

func _init() -> void:
	var code := "RESPECT"
	for a in OS.get_cmdline_args():
		if a.begins_with("--code="): code = a.trim_prefix("--code=")
	var carte := PlanVille.new(code)
	print("── code %s — %d gangs" % [code, PlanVille.GANGS.size()])

	_trios(carte)
	_paliers(carte)
	_contrats(carte)
	_main_forte(carte)
	_repaires(carte)
	_voitures_de_gang(carte)

	print("── %s" % ("TOUT PASSE" if _fautes == 0 else "%d FAUTE(S)" % _fautes))
	quit(1 if _fautes > 0 else 0)

func _dire(vrai: bool, texte: String) -> void:
	if not vrai:
		_fautes += 1
	print("   %s %s" % ["ok " if vrai else "RATÉ", texte])

# ---------------------------------------------------------------- les trios

## Trois gangs par district : on balaye un rectangle de pâtés et on regarde
## QUI tient quoi. Ce qu'on vérifie n'est pas que les sept existent — c'est
## qu'aucun pâté ne soit tenu par un gang étranger à son secteur, autrement
## dit qu'un joueur ne puisse jamais croiser plus de trois bannières dans un
## même district.
func _trios(carte: PlanVille) -> void:
	print("\n1. TROIS GANGS PAR DISTRICT")
	var compte := {}
	var par_secteur := {0: {}, 1: {}, 2: {}}
	var intrus := 0
	var pates := 0
	# ⚠ LA VILLE ENTIÈRE, pas un carré de quarante pâtés : le premier jet du
	# banc balayait un coin de la carte, n'y trouvait qu'un secteur, et
	# annonçait fièrement que deux districts sur trois n'avaient aucun gang.
	print("   %d × %d pâtés" % [PlanVille.pates_x(), PlanVille.pates_y()])
	for py in PlanVille.pates_y():
		for px in PlanVille.pates_x():
			var pate := Vector2i(px, py)
			var gang := carte.territoire_du_pate(pate)
			if gang < 0:
				continue
			pates += 1
			compte[gang] = int(compte.get(gang, 0)) + 1
			var sect := carte.secteur_du_pate(pate)
			par_secteur[sect][gang] = int(par_secteur[sect].get(gang, 0)) + 1
			if not (gang in PlanVille.TRIOS[sect]):
				intrus += 1
	for g in PlanVille.GANGS.size():
		print("   %-14s %4d pâtés" % [carte.nom_du_gang(g), int(compte.get(g, 0))])
	_dire(intrus == 0, "aucun pâté tenu hors de son trio (%d/%d)" % [intrus, pates])
	for sect in [0, 1, 2]:
		var vus: Array = par_secteur[sect].keys()
		vus.sort()
		_dire(vus.size() <= 3, "secteur %d : %d bannières %s" % [sect, vus.size(), str(vus)])
		_dire(PlanVille.CONSORTIUM in vus,
			"secteur %d : Le Consortium y tient du terrain" % sect)
	# Le commun est partout, mais il ne doit pas être le premier propriétaire
	# de la ville : c'est un intrus toléré, pas le maître des lieux.
	var part := float(compte.get(PlanVille.CONSORTIUM, 0)) / maxf(1.0, float(pates))
	_dire(part > 0.08 and part < 0.34, "part du Consortium : %.0f %%" % (part * 100.0))

# --------------------------------------------------------------- les paliers

func _paliers(carte: PlanVille) -> void:
	print("\n2. LES CINQ PALIERS")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ville := VilleVivante.new(carte, rng)
	var moi := "essai"
	_dire(ville.respect_pour(moi, 0) == VilleVivante.RESPECT_DEPART,
		"on commence inconnu : %d" % int(ville.respect_pour(moi, 0)))
	_dire(ville.humeur(moi, 0) == VilleVivante.H_NEUTRE, "et donc neutre")

	# Trois morts, trois paliers. On prend un pâté RÉELLEMENT tenu par le gang
	# pour que la répercussion sur les rivaux soit celle du bon secteur.
	var ou := _un_pate_de(carte, 0)
	var attendus := [VilleVivante.H_HOSTILE, VilleVivante.H_HOSTILE, VilleVivante.H_VUE]
	for mort in 3:
		ville._repercuter(moi, 0, ou, VilleVivante.RESPECT_PERDU, VilleVivante.RESPECT_GAGNE)
		var etat := ville.humeur(moi, 0)
		print("   mort %d : %d points, %s" % [mort + 1, int(ville.respect_pour(moi, 0)),
			String(VilleVivante.NOMS_HUMEUR[etat])])
		_dire(etat == attendus[mort], "palier attendu après %d mort(s)" % (mort + 1))
	_dire(ville.gang_hostile(moi, 0), "au bout de trois, ils tirent à vue")

	# Ce que les rivaux en pensent : ils ont gagné, et EUX SEULS.
	var amis: Array = carte.rivaux(0, ou)
	for a in amis:
		_dire(ville.respect_pour(moi, int(a)) > VilleVivante.RESPECT_DEPART,
			"%s y a gagné (%d)" % [carte.nom_du_gang(int(a)), int(ville.respect_pour(moi, int(a)))])
	var lointain := -1
	for g in PlanVille.GANGS.size():
		if g != 0 and not (g in amis):
			lointain = g
			break
	_dire(ville.respect_pour(moi, lointain) == VilleVivante.RESPECT_DEPART,
		"%s, d'un autre district, n'en sait rien" % carte.nom_du_gang(lointain))

	# Le haut de l'échelle.
	ville._ajuster_respect(moi, 1, 40.0)
	_dire(ville.humeur(moi, 1) == VilleVivante.H_ALLIE and ville.gang_allie(moi, 1),
		"à 90, on est allié")
	ville._ajuster_respect(moi, 1, 999.0)
	_dire(ville.respect_pour(moi, 1) == 100.0, "la jauge plafonne à cent")
	ville._ajuster_respect(moi, 1, -999.0)
	_dire(ville.respect_pour(moi, 1) == 0.0, "et bute à zéro")

## Un pâté tenu par CE gang-là, où qu'il soit. ⚠ Le banc cherchait d'abord
## dans un coin de la carte et retombait sur le centre-ville, qui n'appartient
## à personne : il testait alors les contrats d'un gang tiré au sort et
## s'étonnait que le respect ne bouge pas.
func _un_pate_de(carte: PlanVille, gang: int) -> Vector2:
	for py in PlanVille.pates_y():
		for px in PlanVille.pates_x():
			if carte.territoire_du_pate(Vector2i(px, py)) == gang:
				return PlanVille.centre_pate(Vector2i(px, py))
	push_error("aucun pâté tenu par le gang %d" % gang)
	return carte.centre()

# -------------------------------------------------------------- les contrats

## Les trois téléphones du guide (§4.1). Ce que le banc doit prouver : la
## difficulté appartient à la CABINE et pas à l'humeur du joueur. Donc on prend
## trois numéros de cabine, un de chaque couleur, et on les appelle avec la
## MÊME jauge de respect — si le palier suivait encore le joueur, les trois
## rendraient le même contrat.
func _contrats(carte: PlanVille) -> void:
	print("\n3. LES CONTRATS SUIVENT LA COULEUR DE LA CABINE")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var ville := VilleVivante.new(carte, rng)
	var moi := "essai"
	var gang := 0
	var ou := _un_pate_de(carte, gang)
	_dire(carte.territoire(ou) == gang, "le banc travaille bien sur les terres %s" % carte.du_gang(gang))

	# Un numéro de chaque couleur. Ils se cherchent au lieu de s'écrire en dur :
	# le tirage est un hachage, le figer ici le ferait mentir au premier réglage.
	var numero := [-1, -1, -1]
	for id in 400:
		var n := FormesCarnage.niveau_de_cabine(id)
		if numero[n] < 0:
			numero[n] = id
	_dire(numero.min() >= 0, "trois cabines trouvées : %s" % str(numero))
	var compte := [0, 0, 0]
	for id in 4000:
		compte[FormesCarnage.niveau_de_cabine(id)] += 1
	_dire(compte[0] > compte[1] and compte[1] > compte[2],
		"la ville est surtout verte : %d vertes / %d jaunes / %d rouges sur 4000" % compte)

	# À cinquante — le respect de départ — seule la verte décroche.
	_dire(int(ville.respect_pour(moi, gang)) == 50, "on part à 50 de respect")
	for n in 3:
		ville.sortants.clear()
		ville.contrats.erase(moi)
		ville.proposer_contrat(moi, numero[n], ou)
		var pris := ville.contrats.has(moi)
		var attendu := n == 0
		_dire(pris == attendu, "cabine %s à 50 : %s" % [
			String(FormesCarnage.CABINES[n]["nom"]), "décroche" if pris else "raccroche"])
		if not pris:
			# Le refus doit dire le chiffre qui manque, sinon le joueur croit
			# à un bug de la cabine et n'y revient jamais.
			var texte := String(_dernier(ville, "ctr").get("t", ""))
			_dire(texte.contains(str(int(FormesCarnage.CABINES[n]["respect"]))),
				"  et il dit ce qu'il faut : « %s »" % texte)

	# La verte, elle, a bien rendu un contrat facile.
	ville.contrats.erase(moi)
	ville.proposer_contrat(moi, numero[0], ou)
	var c: Dictionary = ville.contrats.get(moi, {})
	_dire(int(c.get("employeur", -1)) == gang,
		"l'employeur est le gang du territoire (%s)" % carte.nom_du_gang(int(c.get("employeur", 0))))
	_dire(int(c.get("rival", -1)) in carte.rivaux(gang, ou), "le rival est un voisin, pas un inconnu")
	_dire(String(c.get("texte", "")).ends_with("(facile)"), "difficulté : %s" % String(c.get("texte", "")))
	var prime_base := int(c.get("prime", 0))

	# Le contrat rendu : l'employeur monte, le rival descend.
	var rival := int(c.get("rival", 0))
	var avant_rival := ville.respect_pour(moi, rival)
	ville._solder_contrat(moi, true)
	_dire(ville.respect_pour(moi, gang) > 50.0,
		"servi : %s monte à %d" % [carte.nom_du_gang(gang), int(ville.respect_pour(moi, gang))])
	_dire(ville.respect_pour(moi, rival) < avant_rival,
		"et %s le prend mal (%d)" % [carte.nom_du_gang(rival), int(ville.respect_pour(moi, rival))])

	# Le téléphone rouge, lui, ne bouge pas : c'est le joueur qui monte
	# jusqu'à lui. Une fois au-dessus de 82, la même cabine décroche — et
	# rend un travail plus long, mieux payé.
	ville._ajuster_respect(moi, gang, 40.0)
	ville.contrats.erase(moi)
	ville.proposer_contrat(moi, numero[2], ou)
	var d: Dictionary = ville.contrats.get(moi, {})
	_dire(ville.contrats.has(moi), "à %d, la rouge décroche enfin" % int(ville.respect_pour(moi, gang)))
	_dire(String(d.get("texte", "")).ends_with("(difficile)"), "  %s" % String(d.get("texte", "")))
	_dire(int(d.get("prime", 0)) > prime_base,
		"  et ça paie mieux : %d contre %d" % [int(d.get("prime", 0)), prime_base])

	# Le centre d'affaires n'appartient à personne : sans employeur de repli,
	# ses cabines ne sonneraient jamais. C'est le défaut que
	# `employeur_de_cabine` répare — le banc le garde sous surveillance.
	var neutre := _un_pate_neutre(carte)
	if neutre != Vector2.ZERO:
		var patron := carte.employeur_de_cabine(numero[0], neutre)
		_dire(patron >= 0 and patron in carte.trio(neutre),
			"en terrain neutre, c'est un des trois du secteur qui décroche (%s)"
				% carte.nom_du_gang(patron))

func _un_pate_neutre(carte: PlanVille) -> Vector2:
	for py in PlanVille.pates_y():
		for px in PlanVille.pates_x():
			if carte.territoire_du_pate(Vector2i(px, py)) < 0:
				return PlanVille.centre_pate(Vector2i(px, py))
	return Vector2.ZERO

func _dernier(ville: VilleVivante, nom: String) -> Dictionary:
	var trouve := {}
	for e in ville.sortants:
		if String(e["e"]) == nom:
			trouve = e["c"]
	return trouve

# ------------------------------------------------------------- la main-forte

## L'aide en combat, jouée pour de vrai : un homme de gang allié, un flic à
## portée, un joueur recherché — et on fait tourner l'horloge de la ville.
## Ce n'est pas une vérification de seuil, c'est la boucle du jeu.
func _main_forte(carte: PlanVille) -> void:
	print("\n4. LES ALLIÉS PRÊTENT MAIN-FORTE")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var ville := VilleVivante.new(carte, rng)
	var moi := "essai"
	var ou := carte.point_de_rue(rng, carte.centre(), 0.0, 900.0)

	ville._ajuster_respect(moi, 0, 45.0)          # 95 : allié
	ville.chaleur[moi] = ville.chaleur_pour(2)    # deux étoiles : la police le cherche
	var garde := _quelqu_un(ville, VilleVivante.GANG, ou + Vector2(40, 0), 0)
	var flic := _quelqu_un(ville, VilleVivante.FLIC, ou + Vector2(150, 0), -1)
	var joueurs := {moi: {"p": ou, "vie": 100.0, "pied": true}}

	_dire(not ville._a_epauler(garde, {"cle": moi, "p": ou, "pied": true}).is_empty(),
		"l'allié voit le flic qui vous cherche")
	var tue := false
	var annonce := false
	for _pas in 240:
		ville.sortants.clear()
		ville._animer_les_gens(0.1, joueurs)
		for e in ville.sortants:
			if String(e["e"]) == "aide" and String(e["c"].get("j", "")) == moi:
				annonce = true
		if int(flic.get("pv", 0)) <= 0:
			tue = true
			break
	_dire(annonce, "le jeu annonce le coup de main")
	_dire(tue, "et le flic finit par tomber (pv %d)" % int(flic.get("pv", 0)))
	_dire(not ville.gens.has(flic), "il est retiré de la ville")
	# Personne n'a marqué : ce n'est pas le joueur qui a tiré.
	var marque := false
	for e in ville.sortants:
		if String(e["e"]) == "k":
			marque = true
	_dire(not marque, "et personne ne l'inscrit à son tableau")

	# Contre-épreuve : à cinquante de respect, le même gars ne bouge pas.
	var paisible := VilleVivante.new(carte, rng)
	paisible.chaleur[moi] = paisible.chaleur_pour(2)
	var badaud := _quelqu_un(paisible, VilleVivante.GANG, ou + Vector2(40, 0), 0)
	var flic2 := _quelqu_un(paisible, VilleVivante.FLIC, ou + Vector2(150, 0), -1)
	for _pas2 in 60:
		paisible._animer_les_gens(0.1, joueurs)
	_dire(int(flic2["pv"]) == VilleVivante.PV_FLIC,
		"un neutre, lui, laisse le flic tranquille (pv %d)" % int(flic2["pv"]))
	_dire(int(badaud["pv"]) == VilleVivante.PV_GANG, "et personne ne lui a rien fait non plus")

func _quelqu_un(ville: VilleVivante, genre: int, ou: Vector2, gang: int) -> Dictionary:
	var pv := VilleVivante.PV_GANG
	if genre == VilleVivante.FLIC:
		pv = VilleVivante.PV_FLIC
	elif genre == VilleVivante.PIETON:
		pv = VilleVivante.PV_PIETON
	var fiche := {"id": ville._id(), "p": ou, "d": Vector2.RIGHT, "a": 0.0,
		"genre": genre, "gang": gang, "pv": pv, "etat": 0, "minuterie": 9.0, "recharge": 0.0}
	ville.gens.append(fiche)
	return fiche

# ------------------------------------------------------------- les repaires

## LES REPAIRES S'OUVRENT À QUATRE-VINGTS (§3). Jusqu'ici c'était du décor : un
## tag peint au sol, des hommes autour, et rien à y faire. Ce que le banc doit
## prouver : la porte trouve son gang, elle ne s'ouvre qu'au palier allié, et
## il y a bien quelque chose derrière.
func _repaires(carte: PlanVille) -> void:
	print("\n5. LES REPAIRES S'OUVRENT AU PALIER ALLIÉ")
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var ville := VilleVivante.new(carte, rng)
	var moi := "essai"

	# On cherche un repaire pour de vrai, dans les lieux que la ville engendre :
	# en écrire un à la main, c'est vérifier une constante et pas une carte.
	var trouve := {}
	for sy in range(0, PlanVille.LIGNES / PlanVille.SECTEUR):
		for sx in range(0, PlanVille.COLONNES / PlanVille.SECTEUR):
			var centre := Vector2((float(sx) + 0.5) * PlanVille.SECTEUR * PlanVille.PAS,
				(float(sy) + 0.5) * PlanVille.SECTEUR * PlanVille.PAS)
			for r in carte.lieux_autour(centre, PlanVille.SECTEUR * PlanVille.PAS)["repaires"]:
				if int(r["gang"]) >= 0:
					trouve = r
					break
			if not trouve.is_empty():
				break
		if not trouve.is_empty():
			break
	_dire(not trouve.is_empty(), "un repaire trouvé dans la ville engendrée")
	if trouve.is_empty():
		return
	var ou: Vector2 = trouve["p"]
	var chez := int(trouve["gang"])
	_dire(int(carte.repaire_de(ou).get("gang", -99)) == chez,
		"debout sur le tag, la porte sait chez qui l'on est (%s)" % carte.nom_du_gang(chez))
	# ⚠ Le rayon est celui du TAG PEINT, pas du pâté : une porte qui répond
	# ailleurs que là où la peinture est se cherche longtemps.
	_dire(carte.repaire_de(ou + Vector2(PlanVille.RAYON_REPAIRE + 60.0, 0.0)).is_empty(),
		"soixante pixels au-delà du tag, plus rien")

	_dire(ville.respect_pour(moi, chez) < VilleVivante.SEUIL_ALLIE,
		"à %d de respect, la porte reste fermée" % int(ville.respect_pour(moi, chez)))
	ville._ajuster_respect(moi, chez, 40.0)
	_dire(ville.gang_allie(moi, chez),
		"à %d, le gang vous couvre — la porte s'ouvre" % int(ville.respect_pour(moi, chez)))

	# Et derrière la porte : un intérieur par gang, avec son râtelier.
	var id := Interieurs.repaire_de(chez)
	_dire(Interieurs.est_repaire(id) and Interieurs.gang_du_repaire(id) == chez,
		"l'intérieur porte le numéro du gang (%s)" % id)
	_dire(not Interieurs.poste(id, "armurerie").is_empty(),
		"le râtelier y est, et c'est le seul comptoir d'armes du jeu")
	_dire(Interieurs.coffre(id).is_empty(),
		"pas de coffre : on n'habite pas chez un gang")

	# Sept teintes distinctes : un seul dessin, mais on doit reconnaître chez
	# qui l'on est en entrant. Deux gangs au même mur, et le repaire ne dit
	# plus rien.
	var murs := {}
	for gang in PlanVille.GANGS.size():
		var teinte: Color = Interieurs.plan(Interieurs.repaire_de(gang))["teintes"]["_defaultMat"]
		murs[teinte.to_html(false)] = true
	_dire(murs.size() == PlanVille.GANGS.size(),
		"%d murs de couleurs différentes pour %d gangs" % [murs.size(), PlanVille.GANGS.size()])

	# L'armurerie : chaque gang tient une arme, et les deux se trouvent.
	var vendues := {}
	for gang in PlanVille.GANGS.size():
		vendues[String(FormesCarnage.armurerie_du_gang(gang)["arme"])] = true
	_dire(vendues.has("mitraillette") and vendues.has("roquette"),
		"les deux armes du jeu se vendent quelque part : %s" % str(vendues.keys()))

# --------------------------------------------------- les voitures de gang

## LES VOITURES DE GANG SONT ARMÉES (§1.3). Le guide le demandait ; les nôtres
## ne portaient que la couleur du gang, si bien qu'on les reconnaissait sans
## qu'elles vaillent rien de plus qu'une berline. Elles viennent maintenant
## avec leur mitrailleuse de toit — et la voler se paie en respect.
func _voitures_de_gang(carte: PlanVille) -> void:
	print("\n6. UNE VOITURE DE GANG EST ARMÉE, ET SE VOLER SE PAIE")
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var ville := VilleVivante.new(carte, rng)
	var moi := "essai"

	# On cherche une dormante de gang dans la ville engendrée, autour d'un
	# repaire — c'est là qu'elles se garent (`PlanVille._garer`).
	var trouvee := {}
	for sy in range(0, PlanVille.LIGNES / PlanVille.SECTEUR):
		for sx in range(0, PlanVille.COLONNES / PlanVille.SECTEUR):
			var centre := Vector2((float(sx) + 0.5) * PlanVille.SECTEUR * PlanVille.PAS,
				(float(sy) + 0.5) * PlanVille.SECTEUR * PlanVille.PAS)
			for r in carte.lieux_autour(centre, PlanVille.SECTEUR * PlanVille.PAS)["repaires"]:
				for d in carte.dormantes_autour(Vector2(r["p"]), 400.0):
					if int(d.get("gang", -1)) >= 0:
						trouvee = d
						break
				if not trouvee.is_empty():
					break
			if not trouvee.is_empty():
				break
		if not trouvee.is_empty():
			break
	_dire(not trouvee.is_empty(), "une voiture de gang garée près d'un repaire")
	if trouvee.is_empty():
		return

	var auto := ville.reveiller(int(trouvee["id"]))
	_dire(int(auto.get("genre", -1)) == VilleVivante.VOITURE_GANG,
		"réveillée, c'est bien une voiture de gang (%s)" % carte.nom_du_gang(int(auto["gang"])))
	var chez := int(auto["gang"])
	var avant := ville.respect_pour(moi, chez)
	ville.sortants.clear()
	ville.accorder_vehicule(moi, int(auto["id"]), Vector2(auto["p"]))
	_dire(String(auto["pilote"]) == moi, "on prend le volant")
	_dire(ville.respect_pour(moi, chez) < avant,
		"et %s le prend mal : %d au lieu de %d" % [carte.nom_du_gang(chez),
			int(ville.respect_pour(moi, chez)), int(avant)])
	# ⚠ C'est le GENRE annoncé dans l'événement qui décide, chez le client, de
	# monter la mitrailleuse. Sans lui, la voiture repart désarmée à l'écran et
	# armée dans les faits.
	var pris := _dernier(ville, "pris")
	_dire(int(pris.get("g", -1)) == VilleVivante.VOITURE_GANG,
		"l'événement dit le genre, c'est lui qui monte l'arme chez le client")

	# Et le rival du quartier s'en réjouit : c'est la même répercussion que
	# pour un mort, en plus doux.
	var rivaux: Array = carte.rivaux(chez, Vector2(auto["p"]))
	var content := false
	for r in rivaux:
		if ville.respect_pour(moi, int(r)) > 50.0:
			content = true
	_dire(content, "un rival du secteur y gagne (%s)" % carte.nom_du_gang(int(rivaux[0])))
