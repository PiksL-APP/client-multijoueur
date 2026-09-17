extends SceneTree
## ⭐⭐ LE BANC DU PAYS JOUABLE : les fenêtres se fabriquent-elles, et se
## RACCORDENT-ELLES ?
##
##     godot --headless --path . --script res://outils/verifier_fenetres.gd
##
## ⚠ CE QU'ON CHERCHE VRAIMENT, C'EST LA COUTURE. Qu'une fenêtre se fabrique,
## on le voit tout de suite. Qu'elle se raccorde à sa voisine, non : il faut
## marcher jusque-là, et à quatre kilomètres par fenêtre, personne ne le fait
## par hasard. Une marche d'un palier au joint de deux fenêtres, c'est un mur
## invisible en plein milieu d'une route — le genre de défaut qu'on découvre
## six mois plus tard, en jouant.
const PLAN := preload("res://commun/ville2/plan_pays.gd")
const PAYS := preload("res://commun/ville2/generateur_pays.gd")
const COTE := 200

func _init() -> void:
	var plan := PLAN.charger()
	if plan.is_empty():
		print("plan absent : " + PLAN.PLAN_CUIT)
		quit()
		return
	var ctx := PLAN.contexte(plan)

	# 1. LE COÛT D'UNE FENÊTRE. C'est le chiffre qui décide si le fil vaut la
	#    peine — et il la vaut à partir du moment où il dépasse une image.
	var t0 := Time.get_ticks_msec()
	var a: Ville2 = PAYS.fenetre(plan, ctx, Rect2i(400, 400, COTE, COTE), {"nom": "A"})
	var cout := Time.get_ticks_msec() - t0
	print("1. une fenêtre de %d cases : %d ms, %d lots, %d objets"
		% [COTE, cout, a.lots.size(), a.objets.size()])

	# 2. ⚠⚠ LA BONNE QUESTION N'EST PAS « DEUX COLONNES VOISINES SE SUIVENT-ELLES »,
	#    C'EST « LA MÊME CASE EST-ELLE LA MÊME VUE DE DEUX FENÊTRES ».
	#
	#    Mon premier banc comparait la dernière colonne d'une fenêtre à la
	#    première de sa voisine — deux cases DIFFÉRENTES. Il annonçait 58 marches
	#    sur 200, et j'ai cru tenir un défaut grave. Mais le terrain de ce pays
	#    est EN GRADINS, par construction (« terrain en blocs, plus aucune pente
	#    lissée ») : une marche entre deux cases voisines n'est pas une couture
	#    ratée, c'est le relief. Je mesurais le décor, pas le raccord.
	#
	#    On fabrique donc deux fenêtres qui SE CHEVAUCHENT, et on compare la zone
	#    commune case par case. Là, tout écart est une vraie faute : c'est la
	#    même case du pays, elle doit être identique quel que soit le cadrage.
	const CHEVAUCHE := 40
	var b: Ville2 = PAYS.fenetre(plan, ctx, Rect2i(400 + COTE - CHEVAUCHE, 400, COTE, COTE),
		{"nom": "B"})
	var ecarts := 0
	var pire := 0.0
	var mouille := 0
	var routes := 0
	var communes := 0
	for j in COTE:
		for i in CHEVAUCHE:
			# La même case absolue, vue depuis A puis depuis B.
			var ca := Vector2i(COTE - CHEVAUCHE + i, j)
			var cb := Vector2i(i, j)
			communes += 1
			var d := absf(a.sol(ca) - b.sol(cb))
			if d > 0.01:
				ecarts += 1
				pire = maxf(pire, d)
			if a.terre(ca) != b.terre(cb): mouille += 1
			if a.carte.route(ca) != b.carte.route(cb): routes += 1
	print("2. zone commune (%d × %d cases) : %d écarts d'altitude (pire %.2f)"
		% [CHEVAUCHE, COTE, ecarts, pire])
	print("3. la même zone : %d désaccords terre/eau, %d désaccords de chaussée"
		% [mouille, routes])
	# ⚠ LE VERDICT COMPTE EN PROPORTION, PAS EN TOUT OU RIEN. Le terrain et
	# l'eau doivent être IDENTIQUES — ce sont eux qu'on traverse, et une seule
	# case qui change d'altitude selon le cadrage est un mur invisible. La
	# chaussée, elle, se décide de proche en proche (une rue est coupée ou
	# prolongée selon ses voisines), donc quelques cases de bord restent
	# sensibles au cadrage : mesuré, 41 avant que le registre des chaussées se
	# lise dans le plan, DEUX après. Deux cases sur huit mille, au bord d'une
	# zone de chevauchement de quarante cases — on l'écrit plutôt que de le
	# maquiller en « OK ».
	var dur := ecarts == 0 and mouille == 0
	print("4. verdict : %s — %s" % [
		"TERRAIN ET EAU IDENTIQUES" if dur else "LE CADRAGE CHANGE LE SOL, c'est grave",
		"chaussée : %d cases sensibles au cadrage sur %d" % [routes, communes]])
	quit()
