extends SceneTree
## ⭐⭐ LE BANC DES LIEUX DU PAYS — `godot --headless -s outils/verifier_lieux_pays.gd`
##
## Un lieu du jeu (`Plan.lieux_autour`) n'est pas un bâtiment : c'est un point
## dans un casier de secteur, et c'est lui qui décide de tout ce qu'on peut
## FAIRE. Pas de supérette, on meurt de faim ; pas d'hôpital, on rouvre les
## yeux au hasard ; pas de cabine, aucun contrat ; pas de repaire, aucun gang ;
## **pas d'arène, aucun joueur ne peut en toucher un autre** (`Carnage` n'admet
## le tir ami que dans une arène, et ne compte un frag qu'au même prix).
##
## Trois de ces sept genres ont déjà manqué en silence sur le pays — les
## supérettes (mauvais pluriel), tous les repères (cases absolues prises pour
## des cases locales), les cabines (règle morte) — et à chaque fois le jeu
## tournait sans rien dire. Ce banc les compte, autour de trois points du pays,
## et nomme celui qui manque.
##
##     --autour=x,y   (en cases du monde ; par défaut le coeur)
##     --rayon=4000   (en pixels de jeu ; 20 px = un mètre, 200 = une case)
const PLAN := preload("res://commun/ville2/plan_pays.gd")
const PLAN_JEU := preload("res://commun/ville2/plan_jeu_pays.gd")

## Ce qu'il faut trouver autour de soi pour que le jeu soit jouable là.
##
## ⚠ PAS LES ARÈNES : « il ne faut qu'une arène dans le jeu, elle sera au
## milieu du stade » (client, 21/09). Une arène par quartier serait la faute,
## pas le contrôle. Le banc l'AFFICHE quand elle est là, et c'est tout.
const EXIGES := ["cabines", "hopitaux", "repaires", "superettes", "garages"]

func _arg(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_args():
		if a.begins_with("--" + nom + "="): return a.trim_prefix("--" + nom + "=")
	return defaut

func _init() -> void:
	var plan: Dictionary = PLAN.charger()
	if plan.is_empty():
		print("plan absent : %s" % PLAN.PLAN_CUIT)
		quit(1)
		return
	var f := FenetresPays.new()
	f.regler(plan)
	var jeu = PLAN_JEU.new("banc", f, plan)
	var rayon := float(_arg("rayon", "4000"))
	var points: Array = []
	var ou := _arg("autour", "")
	if ou != "":
		var m := ou.split(",")
		if m.size() == 2:
			points.append(["demandé", jeu.centre_case(Vector2i(int(m[0]), int(m[1])))])
	if points.is_empty():
		points.append(["départ", jeu.coeur()])
		points.append(["capitale", jeu.centre_case(Vector2i(500, 505))])
		points.append(["île du nord", jeu.centre_case(Vector2i(430, 210))])
	var fautes := 0
	for e in points:
		var p: Array = e
		var point: Vector2 = p[1]
		# ⚠ ON EXIGE LA FENÊTRE D'ABORD. `lieux_autour` lit des casiers ; il ne
		# fabrique rien. Sans cet appel, un point dont la tuile n'est pas
		# encore là rend SEPT LISTES VIDES — un pays parfaitement équipé
		# passerait pour un désert.
		var c0: Vector2i = jeu.case_de_point(point)
		for dj in [-20, 0, 20]:
			for di in [-20, 0, 20]:
				var voisine: Vector2i = c0 + Vector2i(di, dj)
				f.exiger(voisine)
				jeu.terre_de_case(voisine)
		var t0 := Time.get_ticks_msec()
		var lieux: Dictionary = jeu.lieux_autour(point, rayon)
		var ligne := "%s (%s) à %d px : " % [String(p[0]), jeu.case_de_point(point), int(rayon)]
		var manque: Array = []
		for g in PLAN_JEU.GENRES_LIEUX:
			ligne += "%s=%d " % [String(g).substr(0, 3), (lieux[g] as Array).size()]
			if g in EXIGES and (lieux[g] as Array).is_empty(): manque.append(String(g))
		print(ligne + "— %d ms" % (Time.get_ticks_msec() - t0))
		print("    quartier : %s" % jeu.nom_du_quartier(point))
		if manque.is_empty():
			print("    OK — tout ce qui fait jouer est là")
		else:
			fautes += 1
			print("    ⚠ MANQUE : " + ", ".join(manque))
		# La plus proche de chaque genre : un lieu à trois kilomètres ne sert
		# à rien, et le chiffre brut ne le dit pas.
		for g in EXIGES + ["arenes"]:
			var d := INF
			for l in lieux[g]:
				d = minf(d, Vector2((l as Dictionary)["p"]).distance_to(point))
			if d < INF:
				print("    %-11s la plus proche à %4d px (%.1f cases)" % [g, int(d), d / 200.0])
	print("LIEUX DU PAYS : %d point(s) fautif(s)" % fautes)
	quit(1 if fautes > 0 else 0)
