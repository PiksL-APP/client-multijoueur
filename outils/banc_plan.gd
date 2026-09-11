extends SceneTree
## LE BANC DU PLAN DESSINÉ — `godot --headless -s outils/banc_plan.gd`
## Le jeu pose ses questions à `PlanDessine` ; on vérifie qu'il répond juste,
## chiffres à l'appui, avant de le brancher sur une partie.

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var plan := PlanDessine.new("banc")
	print("construit en %d ms — %d x %d cases, %d x %d tuiles" % [
		Time.get_ticks_msec() - t0, plan.cases_x, plan.cases_y, plan.colonnes(), plan.lignes()])
	var coeur := plan.coeur()
	print("coeur : %s  (case %s, rue : %s)" % [coeur, plan.case_de_point(coeur), plan.carte.route(plan.case_de_point(coeur))])
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for place in 4:
		var d := plan.depart(place, rng)
		var c: Vector2i = plan.case_de_point(d["p"])
		print("départ %d : %s  case %s  rue=%s  bâtiment=%s  altitude %.1f" % [place, d["p"], c,
			plan.carte.route(c), plan.dans_un_batiment(d["p"], 20.0), plan.hauteur_en(d["p"])])
	# Les tuiles : combien bloquent, combien sont de l'eau, combien de rue.
	var bloc := 0
	var eau := 0
	var rue := 0
	var t1 := Time.get_ticks_msec()
	for l in range(0, plan.lignes(), 3):
		for c in range(0, plan.colonnes(), 3):
			var f := plan.tuile(c, l)
			if int(f["sol"]) == PlanVille.S_EAU: eau += 1
			elif bool(f["bloc"]): bloc += 1
			elif int(f["sol"]) == PlanVille.S_ROUTE: rue += 1
	print("tuiles (1/9) : %d eau, %d bloquées, %d rue — en %d ms" % [eau, bloc, rue, Time.get_ticks_msec() - t1])
	# Les lieux.
	var lieux := plan.lieux_autour(plan.centre(), 100000.0)
	var resume := ""
	for g in lieux: resume += "%s %d  " % [g, (lieux[g] as Array).size()]
	print("lieux : " + resume)
	# Le carrefour proche depuis une rue droite : doit rendre un point de rue.
	var c0 := plan.case_de_point(coeur)
	var cp := plan.carrefour_proche(coeur + Vector2(37.0, 11.0))
	print("carrefour_proche(coeur+ε) = %s  (case %s, rue=%s)" % [cp, plan.case_de_point(cp), plan.carte.route(plan.case_de_point(cp))])
	# Le dégagement : un point dans un bâtiment doit en sortir.
	var essais := 0
	var sortis := 0
	for j in range(0, plan.cases_y, 7):
		for i in range(0, plan.cases_x, 7):
			var car := Quartiers._car(plan.dessin, i, j)
			if Quartiers._lettre(car) == "" or car in "?*": continue
			essais += 1
			var p := plan.centre_case(Vector2i(i, j))
			var r := plan.degager(p, 26.0)
			if not plan.dans_un_batiment(r[0], 20.0): sortis += 1
	print("dégagement : %d / %d points de bâtiment ressortis dans la rue" % [sortis, essais])
	# Le relief le long d'une rampe.
	var rampes := 0
	for j in plan.cases_y:
		for i in plan.cases_x:
			var c := Vector2i(i, j)
			if not plan.carte.route(c): continue
			var y0 := plan.hauteur_en(plan.centre_case(c) - Vector2(90, 0))
			var y1 := plan.hauteur_en(plan.centre_case(c) + Vector2(90, 0))
			if absf(y1 - y0) > 0.5: rampes += 1
	print("cases de rue à altitude variable dans l'axe X : %d" % rampes)
	print("quartier au coeur : %s ; gang : %d" % [plan.nom_du_quartier(coeur), plan.territoire(coeur)])
	quit()
