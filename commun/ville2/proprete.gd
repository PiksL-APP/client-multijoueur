class_name PropreteVille2
extends RefCounted
## LES RÈGLES QUI VALENT POUR TOUS LES QUARTIERS.
##
## ⚠ POURQUOI CE FICHIER EXISTE. Chaque générateur pose ses objets à sa façon,
## et chacun refaisait — mal, et pas au même endroit — les mêmes vérifications :
## « est-ce que je suis sur la chaussée ? », « est-ce que cette pelouse est
## nue ? ». Résultat : des rochers plantés au milieu d'un quai, des pelouses
## rases à côté de pelouses fournies, et un client qui redit la même chose à
## chaque témoin (« on avait dit rien sur les routes et je vois toujours des
## trucs », 12/09).
##
## Une règle du cahier ne doit pas vivre dans cinq générateurs. Elle vit ici,
## elle s'applique À LA FIN, sur la ville finie, et elle vaudra pour la carte
## entière le jour où on la bâtira — c'est le but annoncé : « des témoins
## parfaits pour que tu puisses ensuite construire toute la carte en gardant
## les règles appliquées ».
##
## À appeler en dernier, APRÈS la dernière `rasteriser()`.

const CASE := Ville2.CASE

## Le drapeau qui exempte un objet de la règle « rien sur les routes ». Le
## mobilier de voirie — lampadaires, feux, panneaux, cônes, voitures garées —
## est POSÉ sur la chaussée exprès.
const SUR_ROUTE := "voirie"

## ⚠ CE QUI A LE DROIT D'ÊTRE SUR LA CHAUSSÉE, par son nom de catalogue. On
## teste le nom plutôt qu'un drapeau posé à la main : un drapeau oublié est un
## rocher sur le quai, et il n'y a aucun moyen de s'en apercevoir avant la
## capture.
const VOIRIE := ["lampadaire", "lampadaire_double", "lampadaire_parc", "feu", "stop",
	"plaque", "borne", "cone", "poubelle", "benne", "pub", "plateforme", "pelouse"]

## Rien ne reste sur la chaussée sauf le mobilier de voirie. Rend le nombre
## d'objets retirés.
static func rien_sur_les_routes(v: Ville2) -> int:
	if v.carte == null: return 0
	var gardes: Array = []
	var retires := 0
	for o in v.objets:
		var m := String(o.get("m", ""))
		if o.get(SUR_ROUTE, false) or _est_de_la_voirie(m) or m.begins_with("voitures/"):
			gardes.append(o)
			continue
		var c := Vector2i(floori(float(o["x"]) / CASE), floori(float(o["z"]) / CASE))
		# ⚠ ET AUSSI LES CASES PRISES PAR UNE PIÈCE. `route()` ne connaît que la
		# chaussée rastérisée ; une COURBE LARGE ou un rond-point est posé comme
		# une pièce et marque `case_prise` sans être « une route ». Deux
		# panneaux de clôture ont traversé le contrôle par cette porte-là, en
		# plein virage. Une case prise par une pièce est occupée, point.
		if v.dedans(c) and (v.carte.route(c) or v.carte.case_prise(c)):
			retires += 1
			continue
		gardes.append(o)
	v.objets = gardes
	return retires

static func _est_de_la_voirie(modele: String) -> bool:
	if VOIRIE.has(modele): return true
	# Les pièces posées par la carte elle-même (courbes, rampes) portent leur
	# nom de tuile : elles sont la chaussée, pas un objet dessus.
	return modele.begins_with("routes/") or modele.begins_with("res://modeles/kenney/routes/")

## ⚠ UNE PELOUSE VIDE N'EST PAS UNE PELOUSE, C'EST UN TAPIS VERT (demande du
## client, 12/09 : « j'aimerais aussi que les zones d'herbe soient remplies
## d'herbe »). Le kit nature a de quoi : `grass`, `grass_large`, `grass_leafs`,
## et des touffes plates. On en sème sur CHAQUE case d'herbe libre — plusieurs
## par case, jamais alignées — et le vert plat disparaît.
##
## C'est ce qui coûte le plus d'objets de tout le générateur, et c'est ce qui
## se voit le plus : une case d'herbe nue saute aux yeux à côté d'une case
## fournie, alors qu'une ville entièrement fournie se lit comme un décor.
const TOUFFES := ["nature/grass", "nature/grass_large", "nature/grass_leafs",
	"nature/plant_flatShort", "nature/plant_flatTall", "nature/plant_bushSmall"]
const H_TOUFFES = [0.45, 0.70, 0.50, 0.40, 0.60, 0.55]

static func remplir_l_herbe(v: Ville2, alea: RandomNumberGenerator,
		par_case := 3, densite := 1.0) -> int:
	var poses := 0
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			if not v.terre(c) or v.plate(c): continue
			if v.matiere_de(c) != Ville2.M_HERBE: continue
			if alea.randf() > densite: continue
			for _k in alea.randi_range(maxi(1, par_case - 1), par_case + 1):
				var n := alea.randi() % TOUFFES.size()
				v.ajouter_objet(TOUFFES[n], (float(i) + alea.randf()) * CASE,
					(float(j) + alea.randf()) * CASE, alea.randf() * TAU,
					float(H_TOUFFES[n]) * alea.randf_range(0.8, 1.25))
				poses += 1
	return poses

## ⚠ LA SALETÉ EST UN DÉCOR, PAS UN DÉFAUT (demande du client pour le quartier
## chaud, 13/09 : « pas assez de poubelle de saleté au sol »). Deux bennes par
## pâté ne salissent rien ; ce qui salit, c'est le PETIT déchet répété — un
## carton éventré au pied d'un mur, un sac plat dans le caniveau, un fût
## renversé au coin. On les sème donc au pied des bâtiments, sur le trottoir,
## là où l'œil passe.
##
## Le caniveau EST de la chaussée : ces objets portent donc le drapeau de
## voirie, sinon la passe « rien sur les routes » les balaie tous.
const DETRITUS := ["interieur/cardboardBoxOpen", "interieur/cardboardBoxClosed",
	"nourriture/bag-flat", "nourriture/bag", "nourriture/barrel", "poubelle"]
const H_DETRITUS = [0.55, 0.55, 0.25, 0.45, 0.95, 1.05]

## Sème des détritus le long des façades qui donnent sur la rue. `par_lot` :
## combien au pied de chaque bâtiment retenu.
static func salir(v: Ville2, alea: RandomNumberGenerator, genres: Array = [],
		densite := 0.55, par_lot := 3) -> int:
	if v.carte == null: return 0
	var poses := 0
	for l in v.lots:
		if not genres.is_empty() and not genres.has(String(l.get("genre", ""))): continue
		if alea.randf() > densite: continue
		var centre := v.centre_du_lot(l)
		var t := KitVille2.taille(String(l["m"]))
		var q := int(l["q"])
		var demi_x := (t.x if q % 2 == 0 else t.z) * CASE * 0.5
		var demi_z := (t.z if q % 2 == 0 else t.x) * CASE * 0.5
		for _k in alea.randi_range(1, par_lot):
			# Le long d'un des quatre murs, collé dessus, décalé au hasard.
			var mur := alea.randi() % 4
			var x := centre.x
			var z := centre.z
			if mur == 0: z -= demi_z + alea.randf_range(0.6, 2.4)
			elif mur == 1: z += demi_z + alea.randf_range(0.6, 2.4)
			elif mur == 2: x -= demi_x + alea.randf_range(0.6, 2.4)
			else: x += demi_x + alea.randf_range(0.6, 2.4)
			if mur < 2: x += alea.randf_range(-demi_x * 0.7, demi_x * 0.7)
			else: z += alea.randf_range(-demi_z * 0.7, demi_z * 0.7)
			var c := Vector2i(floori(x / CASE), floori(z / CASE))
			if not v.dedans(c) or not v.terre(c): continue
			if v.lot_sur(c) >= 0: continue
			var n := alea.randi() % DETRITUS.size()
			v.objets.append({"m": DETRITUS[n], "x": x, "z": z, "r": alea.randf() * TAU,
				"h": float(H_DETRITUS[n]) * alea.randf_range(0.8, 1.2), SUR_ROUTE: true})
			poses += 1
	return poses

## La passe complète, à appeler en dernier dans chaque générateur.
static func finir(v: Ville2, alea: RandomNumberGenerator, herbe := 3) -> void:
	rien_sur_les_routes(v)
	if herbe > 0: remplir_l_herbe(v, alea, herbe)
