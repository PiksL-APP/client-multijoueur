extends SceneTree
## LE BANC DU RAIL ET DES RUES — `godot --headless -s outils/rail_et_rues.gd`
##
## « Une voie ferrée doit couper une route en passant par-dessus, mais jamais
## être étalée dessus » (client). Ce banc compte, sur une fenêtre du pays,
## combien de cases de voie portent aussi de la chaussée, et surtout QUELLE EST
## LA PLUS LONGUE SUITE — c'est elle qui dit si la voie COUPE une rue (une case,
## deux sur une avenue : un croisement) ou si elle est COUCHÉE DESSUS.
##
## Il imprime aussi, par genre de quartier, ce qui est rue et ce qui est loti :
## c'est ce qui fait voir d'un coup d'œil un quartier resté vide.
##
## MESURÉ (17/09, fenêtre 400,400,200,200) :
##   avant : 314 des 575 cases de voie sur de la chaussée — plus longue suite 37
##   après : 130 — plus longue suite 3
## Les 130 qui restent sont les croisements, et ils DOIVENT rester.
const PLAN := preload("res://commun/ville2/plan_pays.gd")
const PAYS := preload("res://commun/ville2/generateur_pays.gd")
func _init() -> void:
	var plan: Dictionary = PLAN.charger()
	var ctx: Dictionary = PLAN.contexte(plan)
	var v: Ville2 = PAYS.fenetre(plan, ctx, Rect2i(400, 400, 200, 200), {"nom": "m"})
	# 1. Le remplissage par quartier.
	var par_genre: Dictionary = {}
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			if not v.terre(c): continue
			var g: String = String(v.genre_du_quartier(c))
			var f: Array = par_genre.get(g, [0, 0, 0])
			f[0] += 1
			if v.carte.route(c): f[1] += 1
			elif v.lot_sur(c) >= 0: f[2] += 1
			par_genre[g] = f
	var cles: Array = par_genre.keys(); cles.sort()
	print("genre | cases | rue | loties | %% loti hors rue")
	for g in cles:
		var f: Array = par_genre[g]
		var hors: int = int(f[0]) - int(f[1])
		print("  %-14s | %5d | %5d | %5d | %.0f %%" % [g, f[0], f[1], f[2],
			100.0 * float(f[2]) / maxf(1.0, float(hors))])
	print("quartiers : %d" % v.quartiers.size())
	var noms: Dictionary = {}
	for q in v.quartiers:
		var d: Dictionary = q
		var gq := String(d.get("genre", "?")); noms[gq] = int(noms.get(gq, 0)) + 1
	print("par genre : %s" % [noms])
	# 2. Le rail SUR la chaussée : une case de rail qui est aussi une case de rue.
	var cases_rail: Dictionary = {}
	for r in v.rail:
		for rc in Ville2.cases_de_route(r):
			cases_rail[rc] = true
	var dessus := 0
	var total := cases_rail.size()
	var suite := 0
	var pire := 0
	for rc0 in cases_rail.keys():
		var rc: Vector2i = rc0
		if v.carte.route(rc): dessus += 1
	# Les bouts de rail POSÉS LE LONG d'une rue : une case de rail dont la
	# voisine dans l'axe du rail est elle aussi une case de rue.
	for r in v.rail:
		var pts: Array = Ville2.cases_de_route(r)
		suite = 0
		for p0 in pts:
			var p: Vector2i = p0
			if v.carte.route(p): suite += 1
			else:
				pire = maxi(pire, suite); suite = 0
		pire = maxi(pire, suite)
	# D'OÙ viennent les cases de rue en conflit ?
	var par_route: Dictionary = {}
	for r in v.routes:
		var d: Dictionary = r
		var cle := "%s / %s" % [String(d.get("genre", "?")), String(d.get("nom", ""))]
		for c0 in Ville2.cases_de_route(d):
			var c: Vector2i = c0
			if cases_rail.has(c):
				par_route[cle] = int(par_route.get(cle, 0)) + 1
	var tri: Array = par_route.keys()
	tri.sort_custom(func(a, b): return int(par_route[a]) > int(par_route[b]))
	print("-- les routes qui touchent le rail")
	for k in tri.slice(0, 12): print("   %-40s %d cases" % [k, par_route[k]])
	print("rail : %d cases, dont %d sur une case de rue (%.0f %%) ; plus longue suite : %d" % [
		total, dessus, 100.0 * float(dessus) / maxf(1.0, float(total)), pire])
	quit()
