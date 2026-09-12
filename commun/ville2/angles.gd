class_name AnglesVille2
extends RefCounted
## LES ROUTES QUI NE SONT PAS À ANGLE DROIT (cahier § 5 : « ronds-points,
## échangeurs à bretelles (courbe large du kit) »).
##
## Le kit routes ne se réduit pas à la grille : il a une COURBE LARGE (2 × 2
## cases, un quart de tour en douceur), un ROND-POINT (3 × 3) et des bretelles.
## `CarteVille` sait déjà les poser et les orienter — `quarts_courbe` cherche
## le quart de tour qui raccorde les deux bouts, `modele_courbe` choisit entre
## les trois variantes — mais aucun générateur v2 ne l'appelait : toutes nos
## routes tournaient à l'équerre.
##
## Cette brique repasse sur une ville finie et ARRONDIT CE QUI PEUT L'ÊTRE :
## chaque coude de rue devient une courbe large quand le carré de deux cases
## est libre et de niveau. Les demi-tours des lacets de la colline en sont les
## premiers bénéficiaires — un virage en épingle à l'équerre, ça ne se conduit
## pas.
##
## ⚠ À APPELER APRÈS `rasteriser()`, ET RASTÉRISER DE NOUVEAU APRÈS. Les pièces
## se posent sur la carte pour que la suivante voie la place prise, et elles
## sont ajoutées à `ville.ouvrages` pour que la prochaine rastérisation les
## repose à l'identique.

const CASE := Ville2.CASE

## Les quatre masques d'un coude : nord+est, est+sud, sud+ouest, ouest+nord.
const COUDES := [3, 6, 12, 9]

## Arrondit les coudes de rue en courbes larges. Rend le nombre de courbes
## posées. `densite` laisse quelques angles droits : une ville dont tous les
## virages sont des courbes larges devient un circuit.
static func arrondir(v: Ville2, alea: RandomNumberGenerator, densite := 1.0) -> int:
	var carte := v.carte
	if carte == null: return 0
	var poses := 0
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			if not carte.route(c) or carte.case_prise(c): continue
			if not COUDES.has(carte.masque(c)): continue
			if alea.randf() > densite: continue
			# Les quatre carrés de deux cases qui contiennent ce coude.
			for d in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
				var coin: Vector2i = c + d
				if not _carre_libre(v, coin): continue
				var q := CarteVille.quarts_courbe(carte, coin)
				if q < 0: continue
				var modele := _modele(v, coin, q)
				if not carte.poser_piece(modele, coin, Vector2i(2, 2), q): continue
				v.ouvrages.append({"t": modele, "i": coin.x, "j": coin.y, "q": q,
					"w": 2, "h": 2})
				poses += 1
				break
	return poses

## Pose un rond-point de trois cases sur trois, centré sur `centre`. Rend faux
## si la place n'y est pas — un rond-point qui mange un immeuble, c'est pire
## qu'un carrefour ordinaire.
static func rond_point(v: Ville2, centre: Vector2i) -> bool:
	var carte := v.carte
	if carte == null: return false
	var coin := centre - Vector2i(1, 1)
	if not _carre_libre(v, coin, 3): return false
	var niveau := carte.palier(centre)
	for b in 3:
		for a in 3:
			if carte.palier(coin + Vector2i(a, b)) != niveau: return false
	if not carte.poser_piece("road-roundabout", coin, Vector2i(3, 3), 0): return false
	v.ouvrages.append({"t": "road-roundabout", "i": coin.x, "j": coin.y, "q": 0,
		"w": 3, "h": 3})
	return true

## LAQUELLE DES TROIS COURBES ? `CarteVille.modele_courbe` tranche pour la
## ville ; ici on tranche pour le PAYSAGE (demande du client, 12/09) :
##
## * `road-curve-intersection` dès que son bras droit a une rue à rejoindre —
##   c'est la pièce la plus riche du kit, autant s'en servir ;
## * `road-curve` (la bande de chaussée nue, coins ouverts) DÈS QU'ON EST SUR
##   L'HERBE : un virage de campagne n'a pas de trottoir ;
## * `road-curve-pavement` (le carré rempli de trottoir) en ville seulement.
static func _modele(v: Ville2, coin: Vector2i, quarts: int) -> String:
	var carte := v.carte
	var b: Array = CarteVille.COURBE_BOUTS[posmod(quarts, 4)]
	# Le bras droit PROLONGE L'ENTRÉE TOUT DROIT : la rue qu'il rejoint est deux
	# cases plus loin dans le sens de l'entrée.
	var traverse: Vector2i = coin + b[0] - b[1] * 2
	if carte.route(traverse) and not carte.case_prise(traverse):
		return "road-curve-intersection"
	return "road-curve" if a_la_campagne(v, coin, 2) else "road-curve-pavement"

## ⚠ C'EST LE SOL QUI DÉCIDE, PAS LE VOISINAGE BÂTI. Première version : « aucun
## bâtiment autour » — sur une terrasse de la colline, les maisons bordent la
## route, donc plus rien n'était jamais « à la campagne » et tous les virages
## gardaient leur trottoir. Ce qu'on veut savoir est plus simple : AUTOUR DE
## CETTE TUILE, EST-CE DE L'HERBE OU DU BÉTON ? On compte les cases de sol
## naturel contre les cases de dalle ; la majorité l'emporte.
static func a_la_campagne(v: Ville2, coin: Vector2i, cote := 1) -> bool:
	var nature := 0
	var dalle := 0
	for b in range(-1, cote + 1):
		for a in range(-1, cote + 1):
			var c: Vector2i = coin + Vector2i(a, b)
			if not v.dedans(c) or not v.terre(c): continue
			if v.carte != null and v.carte.route(c): continue
			if v.lot_sur(c) >= 0:
				dalle += 1
			elif v.matiere_de(c) == Ville2.M_DALLE:
				dalle += 1
			else:
				nature += 1
	return nature > dalle

## Un carré de `cote` cases, à terre, sans pièce déjà posée, sans bâtiment et
## sans eau. Le bâtiment est le point important : `poser_piece` ne connaît que
## les pièces, il ne sait pas qu'un lot occupe la case.
static func _carre_libre(v: Ville2, coin: Vector2i, cote := 2) -> bool:
	for b in cote:
		for a in cote:
			var c: Vector2i = coin + Vector2i(a, b)
			if not v.dedans(c) or not v.terre(c): return false
			if v.carte.case_prise(c): return false
			if v.lot_sur(c) >= 0: return false
	return true
