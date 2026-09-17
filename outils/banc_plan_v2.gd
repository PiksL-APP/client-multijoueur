extends SceneTree
## LE BANC DU PLAN V2 — `godot --headless -s outils/banc_plan_v2.gd`
##
## Le jeu ne parle jamais à `Ville2` : il parle à `PlanVille`, et c'est `PlanV2`
## qui répond. Ce banc pose au plan, sur chacun des neuf témoins, EXACTEMENT les
## questions que le jeu pose — l'eau, le relief, les tuiles, les districts, les
## lieux, la chaussée — et en imprime un relevé chiffré.
##
## ⚠ SA RAISON D'ÊTRE : le relevé doit rester IDENTIQUE au caractère près quand
## on touche à `PlanV2`. C'est le filet sous la table pendant le branchement du
## pays (le décalage de fenêtre) : tant que `decalage` vaut zéro, rien du jeu
## d'aujourd'hui n'a le droit de bouger.

const TEMOINS := ["centre", "banlieue", "industrie", "plage", "campus",
	"chaud", "vieille-ville", "bidonville", "colline"]

func _init() -> void:
	for nom in TEMOINS:
		var chemin := "res://cartes/temoin-%s.json" % nom
		if not FileAccess.file_exists(chemin):
			print("%-14s ABSENT" % nom)
			continue
		_relever(nom, chemin)
	quit()

func _relever(nom: String, chemin: String) -> void:
	var plan := PlanV2.new("banc", chemin)
	var lignes: Array = []
	lignes.append("%d x %d cases, %d x %d tuiles" % [plan.cases_x, plan.cases_y,
		plan.colonnes(), plan.lignes()])
	var coeur: Vector2 = plan.coeur()
	lignes.append("coeur %.1f,%.1f  quartier %s  gang %d" % [coeur.x, coeur.y,
		plan.nom_du_quartier(coeur), plan.territoire(coeur)])
	# Les tuiles : ce que la physique lit, une sur quatre.
	var eau := 0
	var bloc := 0
	var rue := 0
	var sols := 0
	for l in range(0, plan.lignes(), 2):
		for c in range(0, plan.colonnes(), 2):
			var f: Dictionary = plan.tuile(c, l)
			sols += int(f["sol"])
			if int(f["sol"]) == PlanVille.S_EAU: eau += 1
			elif bool(f["bloc"]): bloc += 1
			elif int(f["sol"]) == PlanVille.S_ROUTE: rue += 1
	lignes.append("tuiles 1/4 : %d eau, %d bloquees, %d rue, somme des sols %d" % [eau, bloc, rue, sols])
	# Le relief et la chaussée, au centre de chaque case.
	var somme := 0.0
	var chaussee := 0
	var rails := 0
	var districts: Dictionary = {}
	for j in plan.cases_y:
		for i in plan.cases_x:
			var c := Vector2i(i, j)
			var p: Vector2 = plan.centre_case(c)
			somme += plan.hauteur_en(p)
			if plan.sur_la_chaussee(p): chaussee += 1
			var d: int = plan.district_de_case(c)
			districts[d] = int(districts.get(d, 0)) + 1
	# ⚠ `sur_le_rail` balaie toute la voie à chaque appel : on l'échantillonne.
	for j in range(0, plan.cases_y, 8):
		for i in range(0, plan.cases_x, 8):
			if plan.sur_le_rail(i * 2, j * 2): rails += 1
	lignes.append("altitudes cumulees %.2f  chaussee %d  rail %d" % [somme, chaussee, rails])
	var cles: Array = districts.keys()
	cles.sort()
	var resume := ""
	for d in cles: resume += "%d:%d " % [d, districts[d]]
	lignes.append("districts " + resume.strip_edges())
	# Les lieux, tels que le jeu les cherche.
	var lieux: Dictionary = plan.lieux_autour(plan.centre(), plan.etendue().length())
	var genres: Array = lieux.keys()
	genres.sort()
	var compte := ""
	for g in genres: compte += "%s:%d " % [g, (lieux[g] as Array).size()]
	lignes.append("lieux " + compte.strip_edges())
	# Les départs : le jeu s'en sert pour poser les joueurs.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for place in 4:
		var d: Dictionary = plan.depart(place, rng)
		var p: Vector2 = d["p"]
		lignes.append("depart %d : %.1f,%.1f  rue=%s" % [place, p.x, p.y,
			plan.sur_une_rue(p)])
	# Le carrefour le plus proche, depuis quelques points fixes.
	for k in 4:
		var p: Vector2 = plan.centre() + Vector2(137.0 * float(k + 1), 91.0 * float(k + 1))
		var cp: Vector2 = plan.carrefour_proche(p)
		lignes.append("carrefour %d : %.1f,%.1f" % [k, cp.x, cp.y])
	print("--- %s" % nom)
	for l in lignes: print("    " + String(l))
