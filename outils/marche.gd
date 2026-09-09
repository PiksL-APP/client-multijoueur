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
	_traverser(id, depart, libre, atteints)

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

## LA MARCHE POUR DE VRAI : on part de la porte et on va au coffre, au pas du
## jeu, à travers `Interieurs.degager` — la même fonction que Carnage appelle.
## L'inondation dit qu'un chemin EXISTE ; celle-ci dit qu'on l'emprunte avec les
## constantes réelles. Deux questions différentes, et c'est la seconde qui
## casse : un pas trop long saute par-dessus une porte d'une tuile, et le joueur
## rebondit contre le chambranle sans jamais entrer.
const PAS_DEDANS := 2.0                ## tuiles/s — la valeur de `Carnage.PAS_DEDANS`
const PORTEE_COFFRE := 0.9
const IMAGE := 1.0 / 60.0

func _traverser(id: String, depart: Vector2, libre: Dictionary, atteints: Dictionary) -> void:
	var c: Dictionary = Interieurs.coffre(id)
	if c.is_empty():
		return
	var but := Vector2(c["p"])
	# Le chemin : un parcours en largeur sur la grille inondée. Un cap DIRECT
	# sur le coffre se coince au premier mur, et on mesurerait la bêtise du
	# guidage au lieu de la praticabilité.
	var cible := Vector2i(int(but.x * FIN), int(but.y * FIN))
	if not atteints.has(cible):
		cible = _plus_proche(atteints, cible)
	var chemin := _remonter(libre, atteints, Vector2i(int(depart.x * FIN), int(depart.y * FIN)), cible)
	if chemin.is_empty():
		print("  ⚠ pas de chemin de la porte au coffre")
		return
	var p := Interieurs.degager(id, depart)
	var t := 0.0
	var k := 0
	var cogne := 0
	while t < 60.0:
		while k < chemin.size() - 1 and p.distance_to(_point(chemin[k].x, chemin[k].y)) < 0.25:
			k += 1
		var vers: Vector2 = _point(chemin[k].x, chemin[k].y) - p
		if vers.length() < 0.001:
			k += 1
			continue
		var avant := p
		p = Interieurs.degager(id, p + vers.normalized() * PAS_DEDANS * IMAGE)
		if p.distance_to(avant) < PAS_DEDANS * IMAGE * 0.4:
			cogne += 1
			if cogne > 90:
				print("  ⚠ COINCÉ en route vers le coffre, vers (%.1f, %.1f)" % [p.x, p.y])
				return
		else:
			cogne = 0
		t += IMAGE
		if p.distance_to(but) < PORTEE_COFFRE:
			# ⚠ Un coffre à portée de la porte, c'est un coffre qu'on ouvre sans
			# entrer chez soi : l'appartement ne sert plus à rien, et la règle
			# du catalogue (« jamais dans une file de meubles », au fond) est
			# perdue. On le signale sans en faire une faute — c'est un choix de
			# décoration, pas un défaut de praticabilité.
			var loin := depart.distance_to(but)
			var mot := "  de la porte au coffre en %.1f s (%.1f tuiles)" % [t, loin]
			if loin < 1.6:
				mot += "  ⚠ TROP PRÈS DE LA PORTE : on dépose sans entrer"
			print(mot)
			return
	print("  ⚠ le coffre n'est pas atteint en une minute de marche")

## Le chemin sur la grille inondée, par un parcours en largeur. On le refait ici
## plutôt que de garder les parents de l'inondation : celle-ci sert à COMPTER,
## et lui faire porter deux rôles la rendrait fausse le jour où on l'optimise.
func _remonter(libre: Dictionary, atteints: Dictionary, depart: Vector2i, cible: Vector2i) -> Array:
	if not atteints.has(depart):
		depart = _plus_proche(atteints, depart)
	var parent := {depart: depart}
	var file: Array = [depart]
	var tete := 0
	while tete < file.size():
		var c: Vector2i = file[tete]
		tete += 1
		if c == cible:
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var v: Vector2i = c + d
			if libre.has(v) and atteints.has(v) and not parent.has(v):
				parent[v] = c
				file.append(v)
	if not parent.has(cible):
		return []
	var chemin: Array = []
	var p := cible
	while p != depart:
		chemin.append(p)
		p = parent[p]
	chemin.reverse()
	return chemin

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
