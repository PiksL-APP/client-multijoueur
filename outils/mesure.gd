extends Node3D
## ⚠ LE BANC D'ÉQUIVALENCE. Optimiser `carte_de` et `batiments` sans prouver que
## la sortie est identique, c'est déplacer une rue d'une case sans le savoir sur
## 96 000 cases. On garde donc ICI les anciennes implémentations, et on compare.

## L'ANCIENNE `batiments` — deux balayages, clés Vector2i hachées.
static func batiments_lent(dessin: Array) -> Array:
	var vus: Dictionary = {}
	var sortie: Array = []
	var large := 0
	for l in dessin:
		large = maxi(large, String(l).length())
	for j in dessin.size():
		for i in large:
			var cle := Vector2i(i, j)
			if vus.has(cle): continue
			var c := _car(dessin, i, j)
			if Quartiers._lettre(c) == "": continue
			var w := 1
			while _car(dessin, i + w, j) == c and not vus.has(Vector2i(i + w, j)):
				w += 1
			var h := 1
			while true:
				var entier := true
				for k in w:
					if _car(dessin, i + k, j + h) != c or vus.has(Vector2i(i + k, j + h)):
						entier = false
						break
				if not entier: break
				h += 1
			for a in w:
				for b in h:
					vus[Vector2i(i + a, j + b)] = true
			sortie.append({"lettre": Quartiers._lettre(c), "i": i, "j": j, "w": w, "h": h})
	return sortie

static func _car(dessin: Array, i: int, j: int) -> String:
	if j < 0 or j >= dessin.size(): return "."
	var ligne: String = dessin[j]
	if i < 0 or i >= ligne.length(): return "."
	return ligne[i]

## L'ANCIENNE `carte_de` — deux balayages complets.
static func carte_lente(fiche: Dictionary) -> CarteVille:
	var dessin: Array = fiche["plan"]
	var relief: Array = fiche.get("relief", [])
	var carte := CarteVille.new()
	var large := 0
	for l in dessin:
		large = maxi(large, String(l).length())
	for j in dessin.size():
		for i in large:
			var c := _car(dessin, i, j)
			if c == "." or c == "~":
				continue
			carte.poser_sol(Vector2i(i, j), Quartiers._niveau(relief, i, j))
			if c in "#=O":
				carte.poser_route(Vector2i(i, j), true)
	for j in dessin.size():
		for i in large:
			if _car(dessin, i, j) == "O":
				carte.poser_piece("road-roundabout", Vector2i(i - 1, j - 1), Vector2i(3, 3), 0)
	return carte

func _ready() -> void:
	var fiche: Dictionary = Quartiers.CATALOGUE["pikstown"]
	var dessin: Array = fiche["plan"]

	# ── batiments ────────────────────────────────────────────────────────────
	var t0 := Time.get_ticks_msec()
	var lent: Array = batiments_lent(dessin)
	var ms_lent := Time.get_ticks_msec() - t0
	t0 = Time.get_ticks_msec()
	var vite: Array = Quartiers.batiments(dessin)
	var ms_vite := Time.get_ticks_msec() - t0
	var pareil := lent.size() == vite.size()
	var premier := -1
	if pareil:
		for k in lent.size():
			if lent[k] != vite[k]:
				pareil = false
				premier = k
				break
	print("BATIMENTS  %d ms -> %d ms | %d rectangles | %s" % [ms_lent, ms_vite, vite.size(),
		"IDENTIQUE" if pareil else "*** DIFFERENT au rang %d ***" % premier])
	if premier >= 0:
		print("   ancien ", lent[premier], "  nouveau ", vite[premier])

	# ── carte_de ─────────────────────────────────────────────────────────────
	# ⚠ EN ALTERNANCE ET TROIS FOIS. Mesurée une seule fois et en second, la
	# nouvelle version sortait « plus lente » : elle payait les allocations
	# laissées par la précédente. Un banc qui appelle A puis B une fois mesure
	# l'ordre, pas le code.
	var mc_lent := 999999
	var mc_vite := 999999
	var cl: CarteVille = null
	var cv: CarteVille = null
	for tour in 3:
		t0 = Time.get_ticks_msec()
		cl = carte_lente(fiche)
		mc_lent = mini(mc_lent, Time.get_ticks_msec() - t0)
		t0 = Time.get_ticks_msec()
		cv = Quartiers.carte_de(fiche)
		mc_vite = mini(mc_vite, Time.get_ticks_msec() - t0)
	var memes := cl.cases.size() == cv.cases.size() and cl.pieces.size() == cv.pieces.size()
	var faute_case := Vector2i(-1, -1)
	if memes:
		for c in cl.cases.keys():
			if not cv.cases.has(c) or cv.cases[c]["n"] != cl.cases[c]["n"] \
					or cv.cases[c]["r"] != cl.cases[c]["r"]:
				memes = false
				faute_case = c
				break
	print("CARTE_DE   %d ms -> %d ms | %d cases, %d pièces | %s" % [mc_lent, mc_vite,
		cv.cases.size(), cv.pieces.size(),
		"IDENTIQUE" if memes else "*** DIFFERENT en %s ***" % faute_case])

	# ── ce que coûte un coup de pinceau, avant / après ───────────────────────
	t0 = Time.get_ticks_msec()
	var prete := Quartiers.preparer(fiche)
	var f2: Array = Quartiers.fautes(fiche, prete)
	print("UN GESTE   preparer + fautes(prete) = %d ms (%d fautes)"
		% [Time.get_ticks_msec() - t0, f2.size()])
	get_tree().quit()
