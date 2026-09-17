extends SceneTree
## LE BANC DU PAYS JOUABLE — `godot --headless -s outils/verifier_plan_pays.gd`
##
## `PlanJeuPays` fait UNE chose : traduire une question posée en cases du MONDE
## en une question posée à la `Ville2` d'une fenêtre, qui compte depuis son
## propre coin. Tout le reste est hérité de `PlanV2`, déjà tenu par
## `outils/banc_plan_v2.gd`. Ce banc ne vérifie donc que la traduction, et il la
## vérifie de la seule façon qui prouve quelque chose : en posant LA MÊME
## question des deux côtés — au plan, en absolu ; à la `Ville2`, en local — et
## en comptant les désaccords. Zéro, ou le pays est décalé d'une fenêtre.
##
## Puis il traverse une couture : un joueur qui roule d'une fenêtre à l'autre
## ne doit voir ni marche d'altitude ni rue coupée.

const PLAN := preload("res://commun/ville2/plan_pays.gd")
const PLAN_JEU := preload("res://commun/ville2/plan_jeu_pays.gd")

func _init() -> void:
	var plan: Dictionary = PLAN.charger()
	if plan.is_empty():
		print("plan absent : %s" % PLAN.PLAN_CUIT)
		quit(1)
		return
	var f := FenetresPays.new()
	f.regler(plan)
	var jeu = PLAN_JEU.new("banc", f, plan)

	var t0 := Time.get_ticks_msec()
	var coeur: Vector2 = jeu.coeur()
	var c_coeur: Vector2i = jeu.case_de_point(coeur)
	print("coeur : %.0f,%.0f  case %s  rue=%s  altitude %.2f  (%d ms)" % [coeur.x, coeur.y,
		c_coeur, jeu.route_de_case(c_coeur), jeu.hauteur_en(coeur), Time.get_ticks_msec() - t0])
	print("quartier : %s" % jeu.nom_du_quartier(coeur))

	# 1. LA TRADUCTION. La fenêtre du coeur, lue des deux côtés.
	var cle: Vector2i = FenetresPays.cle_de_case(c_coeur)
	var coin: Vector2i = cle * FenetresPays.COTE
	var v: Ville2 = f.exiger(c_coeur)
	if v == null:
		print("fenêtre du coeur introuvable")
		quit(1)
		return
	var faux_terre := 0
	var faux_route := 0
	var faux_lot := 0
	var faux_alt := 0
	var testees := 0
	for j in range(0, v.taille.y, 3):
		for i in range(0, v.taille.x, 3):
			var lc := Vector2i(i, j)
			var ac: Vector2i = coin + lc
			testees += 1
			if jeu.terre_de_case(ac) != v.carte.terre(lc): faux_terre += 1
			if jeu.route_de_case(ac) != v.carte.route(lc): faux_route += 1
			if jeu.lot_de_case(ac) != v.lot_sur(lc): faux_lot += 1
			if not v.carte.terre(lc): continue
			var attendue: float = v.carte.hauteur(lc)
			if absf(jeu.hauteur_en(jeu.centre_case(ac)) - attendue) > 0.01: faux_alt += 1
	print("traduction sur %d cases : terre %d, rue %d, lot %d, altitude %d — tout doit être 0" % [
		testees, faux_terre, faux_route, faux_lot, faux_alt])

	# 2. LA COUTURE. On traverse la limite est de la fenêtre du coeur.
	var bord: int = coin.x + FenetresPays.COTE
	if f.exiger(Vector2i(bord, c_coeur.y)) == null:
		print("couture : pas de fenêtre à l'est, on saute")
	else:
		var marches := 0
		var pire := 0.0
		var precedente := jeu.hauteur_en(jeu.centre_case(Vector2i(bord - 12, c_coeur.y)))
		for k in range(-11, 12):
			var ac := Vector2i(bord + k, c_coeur.y)
			var y: float = jeu.hauteur_en(jeu.centre_case(ac))
			var saut: float = absf(y - precedente)
			# Une marche de plus d'un palier entre deux cases voisines, c'est une
			# couture ; le relief, lui, monte par paliers.
			if saut > CarteVille.PALIER + 0.01:
				marches += 1
				pire = maxf(pire, saut)
			precedente = y
		print("couture x=%d : %d marches au-delà d'un palier (pire %.2f)" % [bord, marches, pire])

	# 3. LES TUILES, ce que la physique lit vraiment, de part et d'autre.
	var eau := 0
	var rue := 0
	var bloc := 0
	for k in range(-40, 41):
		var col: int = (bord + k) * PlanV2.TUILES_PAR_CASE
		var lig: int = c_coeur.y * PlanV2.TUILES_PAR_CASE
		var t: Dictionary = jeu.tuile(col, lig)
		if int(t["sol"]) == PlanVille.S_EAU: eau += 1
		elif bool(t["bloc"]): bloc += 1
		elif int(t["sol"]) == PlanVille.S_ROUTE: rue += 1
	print("tuiles le long de la couture : %d eau, %d bloquées, %d rue" % [eau, bloc, rue])
	print("fenêtres : %s" % [f.etat()])
	quit()
