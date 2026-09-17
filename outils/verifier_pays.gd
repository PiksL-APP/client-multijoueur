extends SceneTree
## ⭐ LE CONTRÔLE D'UNE FENÊTRE DU PAYS. Quatre fautes que le client a vues à
## l'œil et qu'aucun rendu ne signalait : bâtiments qui se chevauchent, maisons
## sur la voie ferrée, viaduc qui traverse des maisons, et chaussée du viaduc
## qui n'est pas une pièce du kit.
const PLAN := preload("res://commun/ville2/plan_pays.gd")
const PAYS := preload("res://commun/ville2/generateur_pays.gd")

## ⚠ LA TOLÉRANCE N'EST PAS ARBITRAIRE, C'EST LA PRÉCISION DU FICHIER.
## `Ville2.vers_json` arrondit chaque altitude au centième (`snappedf(a, 0.01)`)
## — un choix délibéré, qui divise par trois le poids d'une carte. Mon premier
## contrôle comparait au millième et annonçait « aller-retour PERDU » sur 61
## cases d'un lit de rivière dont l'altitude avait bougé de CINQ MILLIMÈTRES.
## Comparer plus finement que ce qu'on écrit, c'est mesurer sa propre règle.
const PAS_ALTITUDE := 0.01

func _init() -> void:
	var plan := PLAN.charger()
	var ctx := PLAN.contexte(plan)
	var f := Rect2i(460, 470, 110, 110)
	var v: Ville2 = PAYS.fenetre(plan, ctx, f, {"nom": "controle"})
	print("fenêtre %s : %d lots, %d objets" % [f, v.lots.size(), v.objets.size()])

	# 1. CHEVAUCHEMENTS entre lots, en demi-cases.
	var prises := {}
	var doubles := 0
	var lots_fautifs := {}
	for k in v.lots.size():
		var l: Dictionary = v.lots[k]
		for b in int(l["h"]):
			for a in int(l["w"]):
				var c := Vector2i(int(l["x"]) + a, int(l["y"]) + b)
				if prises.has(c):
					doubles += 1
					lots_fautifs[k] = true
					lots_fautifs[prises[c]] = true
				else:
					prises[c] = k
	print("1. chevauchements : %d demi-cases, %d lots concernés" % [doubles, lots_fautifs.size()])

	# 2. LOTS SUR LE RAIL.
	var rails := {}
	for r in v.rail:
		var fr: Dictionary = r
		var pts: Array = fr["points"]
		for i in range(1, pts.size()):
			var a2 := _case(pts[i - 1])
			var b2 := _case(pts[i])
			var pas := (b2 - a2).sign()
			var c2 := a2
			rails[c2] = true
			while c2 != b2:
				c2 += pas
				rails[c2] = true
	var sur_rail := 0
	for l2 in v.lots:
		var m: Dictionary = l2
		for b3 in int(m["h"]):
			for a3 in int(m["w"]):
				var c3 := Vector2i(floori(float(int(m["x"]) + a3) * 0.5),
					floori(float(int(m["y"]) + b3) * 0.5))
				if rails.has(c3):
					sur_rail += 1
					break
	print("2. lots posés sur la voie ferrée : %d (rail : %d cases)" % [sur_rail, rails.size()])

	# 3. LOTS SOUS LE VIADUC.
	var sous := {}
	var tabliers := 0
	# ⚠ LE TABLIER EST FAIT DE PIÈCES DU KIT DEPUIS LE 17/09 — il n'y a plus
	# d'objet « viaduc » du tout. Une case de tablier, c'est désormais une pièce
	# de voie rapide posée EN L'AIR : on les reconnaît à leur modèle et à leur
	# `y_abs` au-dessus du sol. Chercher l'ancien nom ne mesurait plus rien.
	var PIECES_AUTO := ["routes/road-straight", "routes/road-bend",
		"routes/road-slant-flat-curve"]
	for o in v.objets:
		var fo: Dictionary = o
		if not PIECES_AUTO.has(String(fo.get("m", ""))): continue
		if not fo.has("y_abs"): continue
		var c4 := Vector2i(floori(float(fo["x"]) / 20.0), floori(float(fo["z"]) / 20.0))
		if float(fo["y_abs"]) - v.carte.hauteur(c4) < 2.0: continue
		tabliers += 1
		for dj in [-1, 0, 1]:
			for di in [-1, 0, 1]:
				sous[c4 + Vector2i(di, dj)] = true
	var sous_viaduc := 0
	for l3 in v.lots:
		var m2: Dictionary = l3
		for b4 in int(m2["h"]):
			for a4 in int(m2["w"]):
				var c5 := Vector2i(floori(float(int(m2["x"]) + a4) * 0.5),
					floori(float(int(m2["y"]) + b4) * 0.5))
				if sous.has(c5):
					sous_viaduc += 1
					break
	print("3. lots sous le viaduc : %d (tablier : %d cases)" % [sous_viaduc, tabliers])

	# 4. MOBILIER POSÉ DANS UN BÂTIMENT. « Certains bâtiments se chevauchent » —
	# et quand ce ne sont pas deux lots, c'est un banc, un arbre ou une voiture
	# planté au milieu d'un mur. Le lotisseur connaît les lots ; le mobilier,
	# lui, ne consultait personne.
	var dedans := 0
	var coupables := {}
	for o2 in v.objets:
		var fo2: Dictionary = o2
		# Ce qui est EN L'AIR n'est pas dans un bâtiment : viaduc, piles,
		# chaussée d'autoroute, panneaux. On ne compte que ce qui est au sol.
		if fo2.has("y_abs") or bool(fo2.get("zone", false)): continue
		var c6 := Vector2i(floori(float(fo2["x"]) / 20.0), floori(float(fo2["z"]) / 20.0))
		if not v.dedans(c6): continue
		if v.lot_sur(c6) >= 0:
			dedans += 1
			coupables[String(fo2.get("m", "?"))] = int(coupables.get(String(fo2.get("m", "?")), 0)) + 1
	var pire: Array = []
	for cle in coupables: pire.append([int(coupables[cle]), String(cle)])
	pire.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
	print("4. objets plantés dans un bâtiment : %d" % dedans)
	for t in mini(6, pire.size()):
		print("     %5d  %s" % [int((pire[t] as Array)[0]), String((pire[t] as Array)[1])])

	# 5. LOTS FLOTTANTS. Un bâtiment est posé sur le palier de son coin ; si une
	# autre de ses cases est plus basse, ce coin-là est en l'air.
	var flottants := 0
	var pire_creux := 0
	for l4 in v.lots:
		var m3: Dictionary = l4
		var cx := floori(float(int(m3["x"])) * 0.5)
		var cy := floori(float(int(m3["y"])) * 0.5)
		var ref := v.carte.palier(Vector2i(cx, cy))
		var bas := ref
		for b5 in int(m3["h"]):
			for a5 in int(m3["w"]):
				var c7 := Vector2i(floori(float(int(m3["x"]) + a5) * 0.5),
					floori(float(int(m3["y"]) + b5) * 0.5))
				var pp := v.carte.palier(c7)
				if pp > -900: bas = mini(bas, pp)
		if ref - bas >= 1:
			flottants += 1
			pire_creux = maxi(pire_creux, ref - bas)
	print("5. lots dont un coin est en l\'air : %d (pire creux : %d paliers)"
		% [flottants, pire_creux])

	# 6. L'ALLER-RETOUR. Une fenêtre du pays retouchée dans l'éditeur doit
	# revenir telle quelle : c'est la condition pour que le Ctrl+S serve à
	# quelque chose. On vérifie le compte, mais SURTOUT le terrain — c'est lui
	# qui pèse, et c'est lui qu'on perd sans s'en apercevoir, parce qu'une carte
	# au bon nombre de lots posés sur un sol plat a l'air correcte jusqu'au
	# moment où l'on regarde le relief.
	var ou := "user://cartes/controle-aller-retour.json"
	if not v.enregistrer(ou):
		print("6. aller-retour : ÉCHEC — écriture impossible")
		quit()
		return
	var r := Ville2.charger(ou)
	if r == null:
		print("6. aller-retour : ÉCHEC — relecture impossible")
		quit()
		return
	var memes := 0
	var cases := 0
	for j2 in mini(v.taille.y, r.taille.y):
		for i2 in mini(v.taille.x, r.taille.x):
			var c8 := Vector2i(i2, j2)
			cases += 1
			if absf(v.sol(c8) - r.sol(c8)) <= PAS_ALTITUDE and v.terre(c8) == r.terre(c8):
				memes += 1
	var bon := r.lots.size() == v.lots.size() and r.objets.size() == v.objets.size() \
		and r.rail.size() == v.rail.size() and r.taille == v.taille and memes == cases
	print("6. aller-retour : %s — %d/%d lots, %d/%d objets, terrain %d/%d cases"
		% ["OK" if bon else "PERDU", r.lots.size(), v.lots.size(),
			r.objets.size(), v.objets.size(), memes, cases])

	# 7. LE RÉSEAU TIENT-IL EN UN SEUL MORCEAU ?
	# « Sois sûr que tout le réseau routier soit connecté à quelque chose »
	# (client, 17/09). Une rue qui ne touche rien n'est pas une rue : c'est une
	# bande de bitume au milieu d'un pâté. On compte les morceaux connexes de la
	# chaussée, et ce qui vit hors du plus gros.
	var rues: Dictionary = {}
	for j3 in v.taille.y:
		for i3 in v.taille.x:
			var c9 := Vector2i(i3, j3)
			if v.carte.route(c9): rues[c9] = -1
	var morceaux: Array = []
	var g3 := 0
	for cle in rues.keys():
		var depart: Vector2i = cle
		if int(rues[depart]) >= 0: continue
		var pile: Array = [depart]
		rues[depart] = g3
		var combien := 0
		while not pile.is_empty():
			var p3: Vector2i = pile.pop_back()
			combien += 1
			for d3 in CarteVille.COTES:
				var q3: Vector2i = p3 + d3
				if rues.has(q3) and int(rues[q3]) < 0:
					rues[q3] = g3
					pile.append(q3)
		morceaux.append(combien)
		g3 += 1
	morceaux.sort()
	morceaux.reverse()
	var gros: int = int(morceaux[0]) if not morceaux.is_empty() else 0
	var dehors: int = rues.size() - gros
	# Un cul-de-sac : une case de rue qui n'a qu'une seule voisine de rue.
	var bouts := 0
	for cle2 in rues.keys():
		var c10: Vector2i = cle2
		var voisines := 0
		for d4 in CarteVille.COTES:
			if rues.has(c10 + d4): voisines += 1
		if voisines <= 1: bouts += 1
	print("7. réseau : %d cases de chaussée en %d morceau(x) ; %d hors du réseau, %d culs-de-sac"
		% [rues.size(), morceaux.size(), dehors, bouts])
	quit()

## ⚠ LES POINTS DU RAIL SONT DES `Vector2i`, PAS DES `[x, y]`. Les routes du
## PLAN sont rangées en JSON (donc en tableaux) ; le rail d'une fenêtre est
## construit en mémoire et garde ses vecteurs. Les deux se croisent ici.
func _case(p) -> Vector2i:
	if typeof(p) == TYPE_VECTOR2I: return p
	var t: Array = p
	return Vector2i(int(t[0]), int(t[1]))
