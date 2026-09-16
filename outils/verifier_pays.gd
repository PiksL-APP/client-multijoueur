extends SceneTree
## ⭐ LE CONTRÔLE D'UNE FENÊTRE DU PAYS. Quatre fautes que le client a vues à
## l'œil et qu'aucun rendu ne signalait : bâtiments qui se chevauchent, maisons
## sur la voie ferrée, viaduc qui traverse des maisons, et chaussée du viaduc
## qui n'est pas une pièce du kit.
const PLAN := preload("res://commun/ville2/plan_pays.gd")
const PAYS := preload("res://commun/ville2/generateur_pays.gd")

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
	for o in v.objets:
		var fo: Dictionary = o
		if String(fo.get("m", "")) != "viaduc": continue
		tabliers += 1
		var c4 := Vector2i(floori(float(fo["x"]) / 20.0), floori(float(fo["z"]) / 20.0))
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
	quit()

## ⚠ LES POINTS DU RAIL SONT DES `Vector2i`, PAS DES `[x, y]`. Les routes du
## PLAN sont rangées en JSON (donc en tableaux) ; le rail d'une fenêtre est
## construit en mémoire et garde ses vecteurs. Les deux se croisent ici.
func _case(p) -> Vector2i:
	if typeof(p) == TYPE_VECTOR2I: return p
	var t: Array = p
	return Vector2i(int(t[0]), int(t[1]))
