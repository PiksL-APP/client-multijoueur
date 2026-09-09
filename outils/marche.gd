extends SceneTree
## LE BANC DE MARCHE DES REPAIRES.
##
## Une photo dit si un appartement est beau ; elle ne dit pas s'il est
## PRATICABLE. Ce banc inonde chaque intérieur depuis sa porte, avec le gabarit
## du joueur, et répond aux trois seules questions qui comptent :
##
##   1. peut-on entrer ?
##   2. le coffre est-il atteignable ? (c'est LE meuble du repaire)
##   3. reste-t-il des morceaux de sol coupés du reste ?
##
## Le troisième point est celui qui se voit le moins et coûte le plus : une
## table poussée de vingt centimètres suffit à condamner une chambre, et rien
## dans l'image ne le montre.
##
##   godot --headless -s outils/marche.gd
##   godot --headless -s outils/marche.gd -- --plan     (dessine les cartes)

## Échantillons par tuile. Six donne des cases de 33 cm : assez fin pour voir
## un passage bouché, assez grossier pour tenir dans un terminal.
const FIN := 6

func _init() -> void:
	var dessiner := "--plan" in OS.get_cmdline_args()
	var fautes := 0
	for id in Interieurs.liste():
		fautes += _un(String(id), dessiner)
	print("")
	if fautes == 0:
		print("REPAIRES PRATICABLES.")
	else:
		print("%d défaut(s) de praticabilité." % fautes)
	quit(0 if fautes == 0 else 1)

func _un(id: String, dessiner: bool) -> int:
	var murs := Interieurs.murs(id)
	var large := int(murs["large"])
	var haut := int(murs["haut"])
	var nom := String(Interieurs.CATALOGUE[id]["nom"])
	print("\n── %s (%s, %d × %d tuiles)" % [id, nom, large, haut])

	var lx := large * FIN
	var ly := haut * FIN
	var libre := {}
	for j in ly:
		for i in lx:
			if Interieurs.libre(id, _point(i, j)):
				libre[Vector2i(i, j)] = true

	var depart := Interieurs.entree(id)
	var d0 := Vector2i(int(depart.x * FIN), int(depart.y * FIN))
	# La porte tombe parfois sur un échantillon collé au chambranle : on prend
	# le plus proche qui soit libre, sinon l'inondation part de rien et tout
	# l'appartement est déclaré inatteignable pour un demi-centimètre.
	if not libre.has(d0):
		d0 = _plus_proche(libre, d0)

	var atteints := {}
	if libre.has(d0):
		var file: Array = [d0]
		atteints[d0] = true
		while not file.is_empty():
			var c: Vector2i = file.pop_back()
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var v: Vector2i = c + d
				if libre.has(v) and not atteints.has(v):
					atteints[v] = true
					file.append(v)

	var fautes := 0
	if atteints.is_empty():
		print("  ⚠ ON N'ENTRE PAS : aucune case libre à la porte (%s)" % depart)
		fautes += 1
	else:
		print("  entrée en (%.1f, %.1f)" % [depart.x, depart.y])

	var c: Dictionary = Interieurs.coffre(id)
	if c.is_empty():
		fautes += 1
	else:
		var pres := false
		for k: Vector2i in atteints.keys():
			if _point(k.x, k.y).distance_to(c["p"]) < 0.9:
				pres = true
				break
		if pres:
			print("  coffre atteint")
		else:
			print("  ⚠ COFFRE INATTEIGNABLE en (%.2f, %.2f)" % [c["p"].x, c["p"].y])
			fautes += 1

	# Une POCHE de quelques cases — le coin derrière un canapé, le dessous d'une
	# table — n'est pas un défaut : personne n'ira jamais s'y mettre, et les
	# compter en faute rendrait le banc inutilisable (les huit repaires en ont).
	# ⚠ On mesure donc la PLUS GROSSE poche, pas leur total : trois recoins de
	# sept cases dans trois pièces différentes faisaient sonner l'alarme comme
	# une chambre condamnée, et c'est le contraire d'un banc utile.
	var poches := _poches(libre, atteints)
	var perdues := libre.size() - atteints.size()
	# UNE TUILE. En dessous, ce n'est pas un endroit : c'est le jour entre un
	# lit et un bureau, ou le coin derrière un canapé — deux mètres carrés où
	# personne ne va, et qu'aucun joueur ne remarquera jamais. Au-dessus, c'est
	# une pièce qu'on a condamnée en meublant, et ça se corrige.
	# La plus grosse poche est affichée dans tous les cas, même sous le seuil :
	# un banc qui tait ce qu'il a mesuré ne sert qu'une fois.
	var seuil := FIN * FIN
	var pire := 0
	for p in poches:
		pire = maxi(pire, (p as Array).size())
	if pire >= seuil:
		for p in poches:
			var liste: Array = p
			if liste.size() < seuil:
				continue
			var milieu := Vector2.ZERO
			for k: Vector2i in liste:
				milieu += _point(k.x, k.y)
			milieu /= float(liste.size())
			print("  ⚠ POCHE COUPÉE de %d cases autour de (%.1f, %.1f) tuiles" % [liste.size(), milieu.x, milieu.y])
		fautes += 1
	elif perdues > 0:
		var ou := Vector2.ZERO
		for p2 in poches:
			if (p2 as Array).size() != pire:
				continue
			for k: Vector2i in p2:
				ou += _point(k.x, k.y)
			ou /= float(pire)
			break
		print("  tout se tient, à %d case(s) de recoin près (plus grand : %d, vers (%.1f, %.1f))"
			% [perdues, pire, ou.x, ou.y])
	else:
		print("  tout le sol praticable se tient (%d cases)" % atteints.size())

	if dessiner or pire >= seuil or atteints.is_empty():
		for j in ly:
			var ligne := "  "
			for i in lx:
				var k := Vector2i(i, j)
				ligne += "·" if atteints.has(k) else ("?" if libre.has(k) else "█")
			print(ligne)
	return fautes

## Les morceaux de sol libre que l'inondation n'a pas touchés, un tableau par
## morceau. C'est la seule mesure qui distingue un recoin d'une pièce perdue.
func _poches(libre: Dictionary, atteints: Dictionary) -> Array:
	var vus := {}
	var poches: Array = []
	for depart: Vector2i in libre.keys():
		if atteints.has(depart) or vus.has(depart):
			continue
		var poche: Array = []
		var file: Array = [depart]
		vus[depart] = true
		while not file.is_empty():
			var c: Vector2i = file.pop_back()
			poche.append(c)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var v: Vector2i = c + d
				if libre.has(v) and not atteints.has(v) and not vus.has(v):
					vus[v] = true
					file.append(v)
		poches.append(poche)
	return poches

func _point(i: int, j: int) -> Vector2:
	return Vector2(float(i) + 0.5, float(j) + 0.5) / float(FIN)

func _plus_proche(libre: Dictionary, c: Vector2i) -> Vector2i:
	var mieux := c
	var trouve := false
	for k: Vector2i in libre.keys():
		if not trouve or Vector2(k).distance_to(Vector2(c)) < Vector2(mieux).distance_to(Vector2(c)):
			mieux = k
			trouve = true
	return mieux if trouve else c
