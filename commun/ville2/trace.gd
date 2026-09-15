extends RefCounted
## LE TRACÉ ORGANIQUE — comment une rue cesse d'être une droite.
##
## ⚠ POURQUOI CE FICHIER EXISTE. « Tous tes quartiers, rues, etc. sont carrés,
## ce n'est pas assez organique, avec des virages » (client, 14/09). Il a
## raison, et la cause est simple : les neuf générateurs tracent leurs rues
## avec `v.ajouter_route(genre, [a, b])`, deux points, une droite. Le cahier
## demande pourtant l'inverse — § 5 : « Tracé : par quartier, GRILLE AU CENTRE,
## ORGANIQUE AILLEURS. Une rue organique = enchaînement des virages du kit
## (escalier de tuiles). »
##
## Tout ce qu'il faut pour ça existe déjà, sauf une chose :
##   • `ajouter_route` accepte une POLYLIGNE, pas seulement deux points — elle
##     refuse juste la diagonale (le kit ne pave que les deux axes) ;
##   • `angles.gd` repasse ensuite et transforme chaque coude en COURBE LARGE
##     du kit, un vrai quart de tour en douceur.
## Il manquait la pièce du milieu : de quoi FABRIQUER la polyligne. C'est ici.
##
## ————————————————————————————————————————————————————————————————————————
## LES TROIS RÈGLES, ET ELLES SE PAYENT TOUTES LES TROIS SI ON LES OUBLIE
## ————————————————————————————————————————————————————————————————————————
##
## 1. UN ESCALIER À MARCHE CONSTANTE N'EST PAS UNE ROUTE, C'EST UNE DIAGONALE
##    RATÉE. Une marche tous les trois cases, invariablement, et l'œil lit un
##    escalier de pixels — exactement le défaut qu'on veut corriger, avec un
##    virage de plus. Il faut que les LONGUES lignes droites dominent et que
##    les décrochés soient rares et irréguliers. On ne tourne donc jamais deux
##    fois avant `pas_mini` cases.
##
## 2. LE DÉPORT LATÉRAL DOIT ÊTRE UNE COURBE, PAS DU BRUIT. Tirer le déport au
##    hasard à chaque pas donne une dent de scie : chaque virage annule le
##    précédent et la rue tremble. Ce qui se lit comme une route, c'est un
##    déport À BASSE FRÉQUENCE — la somme de deux sinusoïdes lentes — qui va
##    d'un côté pendant deux cents mètres, puis revient. Une route suit un
##    relief ou contourne un obstacle : elle a des raisons longues.
##
## 3. DEUX POINTS SUCCESSIFS AU MÊME DÉPORT DOIVENT FUSIONNER. Sans ça on
##    envoie à `ajouter_route` deux cents segments d'une case, `angles.gd`
##    trouve un coude à chaque case et la rue devient un serpentin de courbes
##    larges. On n'émet un point QUE lorsque le déport change.
##
## ————————————————————————————————————————————————————————————————————————
## COMMENT S'EN SERVIR
## ————————————————————————————————————————————————————————————————————————
##
##     const TRACE := preload("res://commun/ville2/trace.gd")
##     TRACE.serpenter(v, alea, Vector2i(2, 9), Vector2i(37, 12),
##         Ville2.R_AVENUE, "Route de la Corniche", 3.0)
##
## puis, comme pour toute route, `v.rasteriser()` et `ANGLES.arrondir(v, alea)`
## pour que les coudes deviennent des courbes.
##
## ⚠ CE FICHIER NE SAIT PAS OÙ VONT LES RUES. Il sait les DESSINER. Le choix
## des quartiers à laisser en grille (le centre, la vieille ville) et de ceux à
## faire serpenter (la colline, la campagne, le bidonville, le front de mer)
## appartient à chaque générateur : c'est un parti pris de quartier, pas une
## règle de tracé.

const CASE := Ville2.CASE

## L'écart minimal entre deux décrochés, en cases. En dessous, on fabrique un
## escalier ; au-dessus de sept ou huit, la rue redevient droite.
const PAS_MINI := 4

# ------------------------------------------------------------------ la courbe

## LE DÉPORT, à l'abscisse `t` (0 au départ, 1 à l'arrivée), en cases.
##
## Somme de deux sinusoïdes de fréquences différentes, sous une enveloppe
## `sin(PI·t)` qui la ramène à zéro AUX DEUX BOUTS : une rue doit arriver
## exactement sur son carrefour, sinon elle ne s'y raccorde pas — et un
## carrefour manqué, c'est une rue qui ne mène nulle part, le premier des
## interdits du cahier.
##
## Les deux fréquences sont tirées une fois pour toute la rue, pas à chaque
## pas : c'est ce qui donne à chaque rue SON dessin, et à deux rues voisines
## des dessins différents.
static func _deport(t: float, g: Dictionary) -> float:
	var enveloppe := sin(PI * clampf(t, 0.0, 1.0))
	var a := sin(TAU * float(g["f1"]) * t + float(g["p1"]))
	var b := sin(TAU * float(g["f2"]) * t + float(g["p2"]))
	return enveloppe * (0.64 * a + 0.36 * b)

## Tire le dessin d'une rue : deux fréquences et deux phases.
static func _dessin(alea: RandomNumberGenerator) -> Dictionary:
	return {
		"f1": alea.randf_range(0.45, 1.15),
		"p1": alea.randf() * TAU,
		"f2": alea.randf_range(1.6, 2.8),
		"p2": alea.randf() * TAU,
	}

# ------------------------------------------------------------------ serpenter

## TRACE UNE RUE QUI SERPENTE de `a` à `b`, et rend l'indice de la route (ou
## −1 si elle n'a pas pu être posée).
##
## `ampleur` : de combien de cases la rue a le droit de s'écarter de la droite
## qui joint les deux bouts. Deux à trois pour une desserte, quatre à six pour
## une route de campagne, un seul pour une rue de faubourg qui doit rester
## lisible. Zéro rend une droite — c'est-à-dire le comportement d'avant, et
## c'est ce qu'on veut au centre.
##
## `pas_mini` : la longueur minimale d'une ligne droite entre deux virages.
##
## ⚠ LA RUE NE SORT PAS DE LA CARTE ET NE VA PAS À L'EAU. Un déport qui pousse
## la rue dans la mer produirait une route qui ne se rastérise pas — le
## rastériseur ne pose de chaussée que sur la terre — donc un trou muet au
## milieu du tracé. On rabat le déport plutôt que de le subir.
static func serpenter(v: Ville2, alea: RandomNumberGenerator, a: Vector2i, b: Vector2i,
		genre := Ville2.R_RUE, nom := "", ampleur := 3.0, pas_mini := PAS_MINI) -> int:
	var pts := points(v, alea, a, b, ampleur, pas_mini)
	if pts.size() < 2: return -1
	return v.ajouter_route(genre, pts, nom)

## La polyligne seule, sans la poser : de quoi la retoucher, la mesurer, ou la
## donner à autre chose qu'une route (un chemin de terre, un rail).
static func points(v: Ville2, alea: RandomNumberGenerator, a: Vector2i, b: Vector2i,
		ampleur := 3.0, pas_mini := PAS_MINI) -> Array:
	var d := b - a
	# L'AXE PRINCIPAL : celui sur lequel la rue avance. L'autre porte le
	# déport. Une rue qui avance de dix cases en X et de deux en Y est une rue
	# est-ouest qui louvoie, pas une rue en diagonale.
	var horizontal := absi(d.x) >= absi(d.y)
	var longueur := absi(d.x) if horizontal else absi(d.y)
	if longueur < 2: return [a, b]
	var sens := signi(d.x) if horizontal else signi(d.y)
	var depart := a.x if horizontal else a.y
	var lat0 := a.y if horizontal else a.x
	var lat1 := b.y if horizontal else b.x

	var g := _dessin(alea)
	var pts: Array = [a]
	var lat_pose := lat0
	var depuis := 0

	for k in range(1, longueur):
		var t := float(k) / float(longueur)
		# La droite qui joint les deux bouts, plus la courbe.
		var vise := int(round(lerpf(float(lat0), float(lat1), t) + _deport(t, g) * ampleur))
		if vise == lat_pose: continue
		if k - depuis < pas_mini: continue
		# ⚠ ON NE DÉCROCHE QUE D'UNE CASE À LA FOIS, OU DE DEUX. Au-delà, le
		# décroché est plus long que la ligne droite qui le précède : ce n'est
		# plus un virage, c'est un coude à angle droit au milieu de la rue, et
		# `angles.gd` ne peut pas l'arrondir (il lui faut deux cases libres).
		var saut: int = clampi(vise - lat_pose, -2, 2)
		var suivant := lat_pose + saut
		var ou := depart + k * sens
		var essai: Vector2i = Vector2i(ou, suivant) if horizontal else Vector2i(suivant, ou)
		# La rue reste sur la carte et sur la terre ferme.
		if not v.dedans(essai) or not v.terre(essai): continue
		var coude: Vector2i = Vector2i(ou, lat_pose) if horizontal else Vector2i(lat_pose, ou)
		if coude != pts[pts.size() - 1]: pts.append(coude)
		pts.append(essai)
		lat_pose = suivant
		depuis = k
	# LE RACCORD FINAL. La rue doit arriver SUR `b`, pas à côté : on revient
	# d'abord au déport de `b`, puis on file jusqu'au bout. Sans ce coude, le
	# dernier segment serait une diagonale et `ajouter_route` refuserait la
	# route entière — en silence pour le générateur, qui croit l'avoir posée.
	var fin_lat := b.y if horizontal else b.x
	if lat_pose != fin_lat:
		var ou_fin := b.x if horizontal else b.y
		var coude_fin: Vector2i = Vector2i(ou_fin, lat_pose) if horizontal \
			else Vector2i(lat_pose, ou_fin)
		if coude_fin != pts[pts.size() - 1]: pts.append(coude_fin)
	if b != pts[pts.size() - 1]: pts.append(b)
	return pts

# ------------------------------------------------------------------ la boucle

## UNE BOUCLE ORGANIQUE autour d'une zone : quatre côtés qui serpentent et se
## referment. C'est le tracé d'une desserte de lotissement ou d'une route de
## corniche — celui qu'on ne veut surtout pas au centre.
##
## Les quatre coins restent sur la zone : c'est là que les rues transversales
## viendront se brancher, et un coin qui bouge est un branchement raté.
static func boucler(v: Ville2, alea: RandomNumberGenerator, zone: Rect2i,
		genre := Ville2.R_RUE, nom := "", ampleur := 2.5) -> int:
	var coins := [
		zone.position,
		Vector2i(zone.end.x - 1, zone.position.y),
		Vector2i(zone.end.x - 1, zone.end.y - 1),
		Vector2i(zone.position.x, zone.end.y - 1),
	]
	var poses := 0
	for k in 4:
		if serpenter(v, alea, coins[k], coins[(k + 1) % 4], genre, nom, ampleur) >= 0:
			poses += 1
	return poses

# ------------------------------------------------------------------ brancher

## LES IMPASSES ET LES BRANCHES. Le cahier les veut « partout où c'est utile,
## mais jamais sans raison » : une impasse dessert des parcelles, sinon c'est
## un bout de bitume dans l'herbe.
##
## On part d'une rue déjà posée (`v.routes[indice]`), on prend une case sur
## `tous_les` le long de son tracé, et on pousse perpendiculairement de
## `longueur` cases — en s'arrêtant net si on sort, si on touche l'eau, ou si
## on retombe sur une autre chaussée (une impasse qui débouche n'est pas une
## impasse, c'est une rue, et elle fera doublon).
static func brancher(v: Ville2, alea: RandomNumberGenerator, indice: int,
		genre := Ville2.R_RUE, nom := "", tous_les := 6, longueur := 4,
		cote := 0) -> int:
	if indice < 0 or indice >= v.routes.size(): return 0
	var cases: Array = Ville2.cases_de_route(v.routes[indice])
	var poses := 0
	var k := tous_les
	while k < cases.size() - tous_les:
		var c: Vector2i = cases[k]
		# La perpendiculaire se déduit du SENS LOCAL de la rue, pas d'un axe
		# décidé d'avance : sur une rue qui serpente, les deux ne coïncident
		# pas, et une branche posée selon l'axe global sort en biais de sa
		# propre rue.
		var avant: Vector2i = cases[k - 1]
		var apres: Vector2i = cases[mini(k + 1, cases.size() - 1)]
		var sens := apres - avant
		var perp := Vector2i(-signi(sens.y), signi(sens.x))
		if perp == Vector2i.ZERO:
			k += tous_les
			continue
		var s := 1 if cote > 0 else (-1 if cote < 0 else (1 if alea.randf() < 0.5 else -1))
		perp *= s
		var bout := c
		for pas in range(1, longueur + 1):
			var n := c + perp * pas
			if not v.dedans(n) or not v.terre(n): break
			if v.carte != null and (v.carte.route(n) or v.carte.case_prise(n)): break
			bout = n
		if bout != c and (bout - c).length() >= 2.0:
			if v.ajouter_route(genre, [c, bout], nom) >= 0: poses += 1
		k += tous_les + (alea.randi() % 3)
	return poses

# ------------------------------------------------------------------ le radioconcentrique

## ⚠⚠⚠ UN ANNEAU ET UNE RADIALE, DANS UN KIT QUI NE PAVE QUE DEUX AXES.
##
## C'est le morceau de bravoure de l'Archipel des Aurones : l'Île Centrale est
## RADIOCONCENTRIQUE — deux anneaux primaires et huit radiales autour de la
## Gare Centrale — et `Ville2.ajouter_route` REFUSE LA DIAGONALE. Un cercle et
## une oblique doivent donc être rendus en escalier, et un escalier raté se
## reconnaît de très loin.
##
## LES TROIS RÈGLES DU HAUT DE CE FICHIER VALENT ENCORE, avec une nuance :
##
## 1. « les longues lignes droites dominent » devient, sur un cercle, LES
##    MARCHES SONT LONGUES ET PEU NOMBREUSES. Un anneau échantillonné case par
##    case donne un escalier de pixels ; échantillonné en vingt-quatre marches,
##    il donne un polygone arrondi qui se LIT comme un anneau. La bonne mesure :
##    une marche tous les huit à quinze cases. En dessous, ça grésille ;
##    au-dessus, l'anneau devient un octogone.
## 2. le déport à basse fréquence devient LE RAYON QUI RESPIRE : on fait varier
##    le rayon de quelques pour cent d'une marche à l'autre. Sans ça l'anneau
##    est un polygone régulier, et un polygone régulier se voit — c'est la
##    même faute que la patate, à l'envers.
## 3. « deux points au même déport fusionnent » devient `simplifier()`, qui
##    recolle tout segment colinéaire avec le précédent. Sans elle,
##    `angles.gd` trouve un coude tous les trois mètres et l'anneau devient un
##    serpentin de courbes larges.
##
## ⚠ ET L'ORDRE DES DEUX DEMI-MARCHES N'EST PAS INDIFFÉRENT. Pour aller d'un
## point à l'autre il faut un coude, et il y a deux coudes possibles. On prend
## TOUJOURS L'AXE DOMINANT EN PREMIER : sur un cercle, près de l'est le
## mouvement est surtout vertical, près du sud surtout horizontal, et prendre
## le dominant d'abord fait que la marche épouse la courbe au lieu de la couper.
## Pris à l'envers, l'anneau part systématiquement en dehors du cercle dans un
## quadrant et en dedans dans l'autre : il se met à ressembler à un carré tourné.

## Le coude entre deux points, axe dominant d'abord. Rend le point intermédiaire
## (égal à `de` s'il n'en faut pas).
static func coin(de: Vector2i, vers: Vector2i) -> Vector2i:
	var d := vers - de
	if d.x == 0 or d.y == 0: return de
	return Vector2i(vers.x, de.y) if absi(d.x) >= absi(d.y) else Vector2i(de.x, vers.y)

## Recolle les segments colinéaires et supprime les points en double. À passer
## sur TOUTE polyligne fabriquée ici avant de la donner à `ajouter_route`.
static func simplifier(pts: Array) -> Array:
	var propre: Array = []
	for p in pts:
		var c := Vector2i(p)
		if not propre.is_empty() and c == propre[propre.size() - 1]: continue
		propre.append(c)
	if propre.size() < 3: return propre
	var sortie: Array = [propre[0]]
	for k in range(1, propre.size() - 1):
		var a: Vector2i = sortie[sortie.size() - 1]
		var b: Vector2i = propre[k]
		var c2: Vector2i = propre[k + 1]
		# Trois points alignés sur le même axe : celui du milieu ne sert à rien.
		var aligne := (a.x == b.x and b.x == c2.x) or (a.y == b.y and b.y == c2.y)
		if aligne: continue
		sortie.append(b)
	sortie.append(propre[propre.size() - 1])
	return sortie

## L'ANNEAU : un cercle (ou une ellipse) rendu en escalier, refermé sur
## lui-même. `marches` est le nombre d'échantillons du tour — c'est LE réglage,
## voir la règle 1. `respiration` fait varier le rayon (0,04 = quatre pour cent,
## de quoi casser le polygone sans déformer le cercle).
static func anneau(centre: Vector2i, rayon: Vector2, marches := 24,
		alea: RandomNumberGenerator = null, respiration := 0.04) -> Array:
	if marches < 4: marches = 4
	# Les rayons sont tirés UNE FOIS, pas à chaque point : sinon le dernier
	# point ne retombe pas sur le premier et l'anneau ne se referme pas.
	var facteurs: Array = []
	for k in marches:
		var f := 1.0
		if alea != null and respiration > 0.0:
			f += alea.randf_range(-respiration, respiration)
		facteurs.append(f)
	var brut: Array = []
	for k2 in marches + 1:
		var i := k2 % marches
		var a := TAU * float(k2) / float(marches)
		var f2: float = facteurs[i]
		brut.append(Vector2i(centre.x + roundi(cos(a) * rayon.x * f2),
			centre.y + roundi(sin(a) * rayon.y * f2)))
	return _escalier_par(brut)

## LA RADIALE : de `r0` à `r1` le long d'une direction, en escalier. Aux quatre
## points cardinaux c'est une droite ; entre les deux, une suite de marches.
## `marches` est le nombre d'échantillons sur la longueur.
static func radiale(centre: Vector2i, angle: float, r0: float, r1: float,
		rayon: Vector2, marches := 10, alea: RandomNumberGenerator = null,
		respiration := 0.03) -> Array:
	var brut: Array = []
	for k in marches + 1:
		var t := float(k) / float(marches)
		var r := lerpf(r0, r1, t)
		var f := 1.0
		# On ne fait respirer NI le départ NI l'arrivée : une radiale doit
		# tomber exactement sur son anneau et exactement sur la place centrale.
		if alea != null and k > 0 and k < marches:
			f += alea.randf_range(-respiration, respiration)
		brut.append(Vector2i(centre.x + roundi(cos(angle) * rayon.x * r * f),
			centre.y + roundi(sin(angle) * rayon.y * r * f)))
	return _escalier_par(brut)

## L'ESCALIER GÉNÉRIQUE entre deux points, sans `Ville2` — de quoi tracer sur un
## PLAN, avant qu'aucune ville n'existe. `serpenter()` et `points()`, eux,
## interrogent le terrain et ne servent qu'une fois la carte bâtie.
static func escalier(a: Vector2i, b: Vector2i, marches := 6,
		alea: RandomNumberGenerator = null, ampleur := 0.0) -> Array:
	if marches < 1: marches = 1
	var brut: Array = []
	var d := b - a
	# La perpendiculaire porte l'ampleur : une liaison qui ne serpente pas du
	# tout se lit comme un trait de règle, et le client l'a déjà refusé.
	var n := Vector2(-float(d.y), float(d.x)).normalized()
	for k in marches + 1:
		var t := float(k) / float(marches)
		var p := Vector2(a) + Vector2(d) * t
		if alea != null and ampleur > 0.0 and k > 0 and k < marches:
			p += n * sin(PI * t) * alea.randf_range(-ampleur, ampleur)
		brut.append(Vector2i(roundi(p.x), roundi(p.y)))
	return _escalier_par(brut)

## Transforme une suite de points QUELCONQUES (donc en diagonale) en une
## polyligne strictement axiale, en insérant un coude entre chaque paire.
static func _escalier_par(brut: Array) -> Array:
	var pts: Array = []
	for k in brut.size():
		var p: Vector2i = brut[k]
		if pts.is_empty():
			pts.append(p)
			continue
		var prec: Vector2i = pts[pts.size() - 1]
		if p == prec: continue
		var c := coin(prec, p)
		if c != prec: pts.append(c)
		if p != c: pts.append(p)
	return simplifier(pts)
