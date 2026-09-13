class_name GenerateurPlage
extends RefCounted
## LE DEUXIÈME QUARTIER TÉMOIN : LE FRONT DE MER (cahier § 3 et § 11).
##
## Ce témoin-là existe pour éprouver ce que le centre ne touchait pas : LE
## TERRAIN. Il n'y a pas de plateau ici — le sable descend, entre dans l'eau
## et continue en pente jusqu'au large (cahier § 4 : « plages en pente douce,
## le sable entre dans l'eau »), et le port lui oppose l'autre côte du cahier :
## un quai vertical, de l'eau profonde au pied.
##
## L'ordre reste celui du cahier (§ 10) : terrain → côtes → axes → quartiers →
## rues → lots → détails.
##
## DU NORD AU SUD : l'arrière-plage (pâtés ordinaires), l'avenue du bord de
## mer, la promenade pavée, la plage, la mer. À L'EST : le port, ses hangars,
## ses conteneurs et ses cargos. AU MILIEU DE LA PLAGE : la jetée, son bar et
## sa grande roue.

## Les courbes larges et le rond-point (cahier § 5) : brique commune, appelée
## par `preload` — un `class_name` neuf n'existe pas dans l'export web.
const ANGLES := preload("res://commun/ville2/angles.gd")

## Les règles communes à tous les quartiers : rien sur la chaussée, et pas
## une pelouse nue. Appelées en dernier (voir `commun/ville2/proprete.gd`).
const PROPRETE := preload("res://commun/ville2/proprete.gd")
const ATLAS := preload("res://commun/ville2/atlas.gd")
const TEINTES := preload("res://commun/ville2/teintes.gd")

## Les panneaux publicitaires (cahier § 7) : toits, pignons aveugles, bords
## d'axe. Brique commune — l'affichage est une règle de ville, pas de quartier.
const AFFICHES := preload("res://commun/ville2/affiches.gd")

const CASE := Ville2.CASE
const DEMI := Ville2.DEMI

## Les bandes, en cases, du nord vers le sud.
const J_AVENUE := 17                   ## l'avenue du bord de mer
const J_PROMENADE := 18                ## la promenade pavée, une case
const J_SABLE := 19                    ## le haut de plage
const J_RIVAGE := 24                   ## la ligne d'eau
## ⚠ LA PLAGE EST PLATE, SAUF SON BOUT. Elle descendait de bout en bout, une
## demi-unité par case : une pente douce, invisible sur une capture — mais
## TOUT CE QU'ON Y POSE FLOTTE OU S'ENTERRE. Un objet est posé au point qu'on
## lui donne, et le maillage du sol, lui, est interpolé entre les quatre coins
## de la case : sur un sol qui penche, les deux ne se rejoignent qu'au centre
## exact. « Fais en sorte que sur la plage ce soit juste le bout qui soit en
## dénivelé, sinon les objets flottent » (client, 12/09) — et il a raison, le
## haut de plage d'une vraie plage est plat, c'est l'estran qui plonge.
##
## Le sable reste donc à zéro depuis `J_SABLE`, et seules les `CASES_ESTRAN`
## dernières cases avant l'eau descendent — là où l'on ne pose rien.
const CASES_ESTRAN := 2
const PENTE_ESTRAN := -0.75            ## par case : deux cases pour 1,5 unité
const PENTE_FOND := -0.95              ## le fond de la mer, par case
const FOND_MAX := -11.0

## Le port, à l'est : son quai est vertical, et l'eau y est profonde.
const X_PORT := 28
const J_QUAI := 26                     ## le bord du quai, plus au sud que la plage
const FOND_PORT := -7.0

## La jetée, au milieu de la plage.
const X_JETEE := 11
const J_JETEE_BOUT := 33
const TABLIER := 3.4                   ## la hauteur du tablier au-dessus de la mer

## Ce qui traîne sur le sable, et les cailloux du rivage : le kit nature en a
## de quoi ne jamais répéter deux fois la même chose.
const SUR_LE_SABLE := ["nature/grass_leafs", "nature/plant_flatShort", "nature/log",
	"nature/campfire_stones", "nature/campfire_logs", "nature/path_wood",
	"nature/platform_beach", "nature/pot_small"]
## ⚠ 0 = à l'échelle du kit (une pièce de sol) ; SINON UNE HAUTEUR EN MÈTRES,
## une unité valant un mètre. Une touffe d'oyat fait 50 cm, pas 1,20 (« faut
## faire attention que chaque objet ne soit pas énorme », client, 12/09).
const H_SUR_LE_SABLE := [0.50, 0.40, 0.50, 0.30, 0.45, 0.0, 0.0, 0.50]
const CAILLOUX := ["nature/rock_smallA", "nature/rock_smallD", "nature/rock_smallFlatB",
	"nature/stone_smallB", "nature/stone_smallFlatC", "nature/rock_largeA",
	"nature/rock_largeC", "nature/stone_largeE"]

const PRENOMS := ["du Phare", "des Mouettes", "de la Plage", "des Dunes", "du Large",
	"des Régates", "de l'Ancre", "du Ponton", "des Filets", "de la Criée"]

## Les familles du bord de mer : des immeubles clairs côté avenue, des
## pavillons derrière, des hangars au port.
const HOTELS := ["batiments/building-l", "batiments/building-i", "batiments/building-j",
	"batiments/building-f", "batiments/building-g", "batiments/building-m"]
const PETITS := ["pavillons/building-type-b", "pavillons/building-type-d",
	"pavillons/building-type-f", "pavillons/building-type-n", "pavillons/building-type-t",
	"pavillons/building-type-u", "pavillons/building-type-g"]
const COMMERCES := ["batiments/building-c", "batiments/building-e", "batiments/building-a",
	"batiments/building-b", "batiments/building-h"]
const HANGARS := ["industriel/building-c", "industriel/building-l", "industriel/building-q",
	"industriel/building-r", "industriel/building-s", "industriel/building-p",
	"industriel/building-h", "industriel/building-i"]

static func generer(graine := 2, taille := Vector2i(40, 40), curseurs := {}) -> Ville2:
	var v := Ville2.new(taille)
	v.nom = String(curseurs.get("nom", "temoin-plage"))
	v.graine = graine
	var alea := RandomNumberGenerator.new()
	alea.seed = graine
	Lotisseur.oublier_les_sacs()

	_terrain(v, alea)
	_quartiers(v)
	var xs := _rues(v, taille)
	v.rasteriser()
	# ⚠ LES VIRAGES S'ARRONDISSENT AVANT LES MAISONS. Une courbe large mange
	# quatre cases ; si les lots sont déjà posés il n'en reste aucune de libre —
	# sur huit épingles de la colline, deux seulement s'arrondissaient. Arrondi
	# d'abord, le carré est marqué PRIS et le lotisseur le contourne tout seul.
	ANGLES.arrondir(v, alea, 0.7)
	v.rasteriser()
	_lots(v, alea, xs, taille)
	v.rasteriser()
	_promenade(v, alea, taille)
	_la_plage(v, alea, taille)
	_la_jetee(v, alea)
	_le_port(v, alea, taille)
	v.rasteriser()
	# ⚠ LES REPÈRES DU CLIENT. Ce sont ses propres modèles, faits pour ce
	# jeu : un quartier qui n'en porte aucun se lit comme du Kenney tout nu.
	_poser_repere(v, "piksl/firestation", Vector2i(22, 10), 0, "caserne", "Caserne du Port")
	_poser_repere(v, "piksl/supermarket", Vector2i(6, 9), 0, "supermarche", "Supérette du Front de mer")
	v.rasteriser()
	AFFICHES.semer(v, alea, 120.0, [], 3)
	# ⚠ AUCUNE TOITURE VERTE (client, 13/09). Voir `atlas.gd` : la bande
	# verte de l'atlas est repeinte par bâtiment, murs inchangés.
	TEINTES.couvrir(v, alea, "", ATLAS.PAVILLONNAIRE)
	TEINTES.peindre(v, alea, "", TEINTES.PAVILLONS, 0.35)
	PROPRETE.finir(v, alea)
	return v

# ------------------------------------------------------------------ 1. le terrain

## ⚠ LE RIVAGE N'EST PAS UNE LIGNE DROITE. Une plage dont la ligne d'eau suit
## exactement une rangée de cases se lit comme un bord de piscine. On la fait
## onduler de deux cases avec deux sinus déphasés — assez pour qu'elle
## respire, pas assez pour qu'une case de sable se retrouve isolée au large.
static func _rivage(i: int) -> float:
	return float(J_RIVAGE) + sin(float(i) * 0.31) * 1.4 + sin(float(i) * 0.11 + 1.7) * 0.9

static func _terrain(v: Ville2, _alea: RandomNumberGenerator) -> void:
	for j in v.taille.y:
		for i in v.taille.x:
			var c := Vector2i(i, j)
			# Au NORD de l'avenue, c'est la ville ordinaire sur toute la
			# largeur : le port ne commence qu'au bord de mer.
			if j <= J_AVENUE:
				v.poser_terre(c, 0.0)
				v.poser_matiere(c, Ville2.M_DALLE)
				continue
			if i >= X_PORT:
				# LE PORT : le terre-plein est plat jusqu'au quai, puis l'eau
				# tombe d'un coup — un quai vertical, pas une plage.
				if j < J_QUAI:
					v.poser_terre(c, 0.0)
					v.poser_matiere(c, Ville2.M_DALLE)
				else:
					v.poser_eau(c)
					v.altitude[v.indice(c)] = maxf(FOND_MAX, FOND_PORT - float(j - J_QUAI) * 0.5)
				continue
			var bord := _rivage(i)
			if float(j) < bord:
				var y := 0.0
				if j >= J_SABLE:
					# LE HAUT DE PLAGE EST PLAT ; seul l'estran plonge, sur les
					# deux dernières cases avant l'eau. `bord` ondule, donc
					# l'estran ondule avec lui : on compte les cases DEPUIS LA
					# LIGNE D'EAU, pas depuis une rangée fixe.
					var reste := bord - float(j)
					if reste < float(CASES_ESTRAN):
						y = (float(CASES_ESTRAN) - reste) * PENTE_ESTRAN
				v.poser_terre(c, y)
				if j >= J_SABLE:
					v.poser_matiere(c, Ville2.M_SABLE)
				elif j == J_PROMENADE:
					v.poser_matiere(c, Ville2.M_DALLE)
				else:
					v.poser_matiere(c, Ville2.M_DALLE)
			else:
				v.poser_eau(c)
				# La profondeur se compte depuis la ligne d'eau, pas depuis une
				# rangée fixe : sous une plage qui ondule, le fond ondule aussi.
				var d := float(j) - bord
				v.altitude[v.indice(c)] = maxf(FOND_MAX, -0.4 + d * PENTE_FOND)

static func _quartiers(v: Ville2) -> void:
	v.quartiers.append({"nom": "Le Front de mer", "genre": Ville2.Q_PLAGE, "gang": -1})
	v.quartiers.append({"nom": "Le Port", "genre": Ville2.Q_PORT, "gang": -1})
	v.peindre_quartier(Rect2i(Vector2i.ZERO, v.taille), 0)
	v.peindre_quartier(Rect2i(X_PORT, 0, v.taille.x - X_PORT, v.taille.y), 1)

# ------------------------------------------------------------------ 2. les rues

static func _rues(v: Ville2, taille: Vector2i) -> Array[int]:
	var n := 0
	# L'AVENUE DU BORD DE MER, d'un bout à l'autre : c'est l'axe du quartier.
	v.ajouter_route(Ville2.R_AVENUE, [Vector2i(0, J_AVENUE), Vector2i(taille.x - 1, J_AVENUE)],
		"Boulevard du Front de mer")
	# Les rues est-ouest de l'arrière-plage.
	for jr in [2, 7, 12]:
		v.ajouter_route(Ville2.R_RUE, [Vector2i(0, jr), Vector2i(taille.x - 1, jr)],
			"Rue " + PRENOMS[n % PRENOMS.size()])
		n += 1
	# Les rues nord-sud : elles s'arrêtent sur l'avenue, la plage n'est pas
	# carrossable. Celles du port continuent jusqu'au quai.
	var xs: Array[int] = []
	var x := 2
	while x < taille.x - 1:
		xs.append(x)
		var fin := J_AVENUE
		var genre := Ville2.R_RUE
		if x >= X_PORT:
			fin = J_QUAI - 1
			genre = Ville2.R_AVENUE if x == X_PORT + 3 else Ville2.R_RUE
		v.ajouter_route(genre, [Vector2i(x, 0), Vector2i(x, fin)],
			"Rue " + PRENOMS[n % PRENOMS.size()])
		n += 1
		x += 5
	# La desserte du port, le long du quai.
	v.ajouter_route(Ville2.R_AVENUE, [Vector2i(X_PORT - 3, J_QUAI - 2), Vector2i(taille.x - 2, J_QUAI - 2)],
		"Quai des Cargos")
	v.ajouter_route(Ville2.R_RUE, [Vector2i(X_PORT - 3, J_AVENUE), Vector2i(X_PORT - 3, J_QUAI - 2)],
		"Rue du Port")
	return xs

# ------------------------------------------------------------------ 3. les lots

static func _lots(v: Ville2, alea: RandomNumberGenerator, xs: Array[int], taille: Vector2i) -> void:
	# Les pâtés de l'arrière-plage, entre les rues.
	var ys := [2, 7, 12, J_AVENUE]
	for a in range(xs.size() - 1):
		for b in range(ys.size() - 1):
			var r := Rect2i(xs[a] + 1, int(ys[b]) + 1, xs[a + 1] - xs[a] - 1, int(ys[b + 1]) - int(ys[b]) - 1)
			if r.size.x < 2 or r.size.y < 2: continue
			var choix: Array = HOTELS if int(ys[b + 1]) == J_AVENUE else PETITS
			var genre := "hotel" if int(ys[b + 1]) == J_AVENUE else "immeuble"
			var occupe := Lotisseur.border(v, r, alea, choix + COMMERCES, 0.92, genre)
			_cour(v, r, alea, occupe)
	# LES HANGARS DU PORT, alignés le long de la desserte, face au quai.
	Lotisseur.aligner(v, alea, HANGARS, "s", Vector2i((X_PORT - 2) * 2, (J_QUAI - 3) * 2),
		(taille.x - X_PORT + 1) * 2, "hangar", 0.85, 1)

## La cour d'un pâté de bord de mer : une pelouse, des palmiers, une voiture.
static func _cour(v: Ville2, r: Rect2i, alea: RandomNumberGenerator, _occupe: Dictionary) -> void:
	var cx := (float(r.position.x) + float(r.size.x) * 0.5) * CASE
	var cz := (float(r.position.y) + float(r.size.y) * 0.5) * CASE
	if (r.position.x + r.position.y) % 2 == 0:
		v.objets.append({"m": "pelouse", "x": cx, "z": cz, "r": 0.0, "h": 0.0, "w": 26.0, "d": 26.0})
		v.ajouter_objet("palmier", cx - 6.0, cz - 5.0, alea.randf() * TAU)
		v.ajouter_objet("palmier", cx + 7.0, cz + 4.0, alea.randf() * TAU)
		v.ajouter_objet("banc", cx, cz + 7.0, 0.0)
	else:
		v.ajouter_objet("benne", cx - 8.0, cz - 6.0, 0.0)
		for k in 2:
			v.ajouter_objet(KitVille2.VOITURES[alea.randi() % KitVille2.VOITURES.size()],
				cx - 4.0 + float(k) * 8.0, cz + 5.0, PI * 0.5)
		v.ajouter_objet("arbre_rond", cx + 8.0, cz - 5.0, alea.randf() * TAU)

# ------------------------------------------------------------------ 4. la promenade

## LA PROMENADE : la case pavée entre l'avenue et le sable. Palmiers en
## alignement, bancs tournés vers la mer, lampadaires, poubelles — et la
## rambarde qui la sépare de la plage, en bornes du kit.
static func _promenade(v: Ville2, alea: RandomNumberGenerator, taille: Vector2i) -> void:
	var z := (float(J_PROMENADE) + 0.5) * CASE
	for i in range(1, mini(taille.x - 1, X_PORT)):
		var x := (float(i) + 0.5) * CASE
		match posmod(i, 4):
			0: v.ajouter_objet("palmier", x, z - 5.0, alea.randf() * TAU)
			1: v.ajouter_objet("banc", x, z + 2.0, PI)        # dossier au nord, face à la mer
			2: v.ajouter_objet("lampadaire", x, z - 5.5, 0.0)
			3:
				v.ajouter_objet("banc", x, z + 2.0, PI)
				v.ajouter_objet("poubelle", x + 5.0, z - 5.0, 0.0)
		# La rambarde, au ras du sable.
		v.ajouter_objet("borne", x - 5.0, z + 8.5, 0.0)
		v.ajouter_objet("borne", x + 5.0, z + 8.5, 0.0)

# ------------------------------------------------------------------ 5. la plage

## LA PLAGE : parasols et serviettes en semis, un poste de secours, des
## rochers au bout, des bouées sur l'eau. Rien n'est aligné — une plage
## rangée en grille est la chose qui trahit le plus un décor engendré.
static func _la_plage(v: Ville2, alea: RandomNumberGenerator, taille: Vector2i) -> void:
	# ⚠ UNE PLAGE SE JUGE À SA FOULE. Trois tirages par case sur une plage de
	# quatre cases de profondeur, c'est un parasol tous les cinquante mètres :
	# vue d'en haut, la plage est vide. On monte à six — le sable reste
	# majoritaire, mais il est FRÉQUENTÉ, ce qui est le sujet.
	for i in range(1, mini(taille.x - 1, X_PORT)):
		var bord := _rivage(i)
		for k in 6:
			var x := (float(i) + alea.randf()) * CASE
			# ⚠ RIEN SUR L'ESTRAN : c'est la seule bande qui penche encore, et
			# c'est là que les parasols flottaient. On s'arrête au pied de la
			# pente, une marge de sécurité en plus.
			var j := float(J_SABLE) + alea.randf() \
				* (bord - float(J_SABLE) - float(CASES_ESTRAN) - 0.3)
			if j <= float(J_SABLE) + 0.2: continue
			var z := j * CASE
			var t := alea.randf()
			if t < 0.26:
				# ⚠ À LA TAILLE D'UN PARASOL, soit deux mètres cinquante de haut
				# et non la taille du catalogue : le kit le dessine pour son
				# petit bonhomme, et posé tel quel il se perd dans le sable.
				v.ajouter_objet("parasol" if k % 2 == 0 else "parasol_b", x, z,
					alea.randf() * TAU, alea.randf_range(2.4, 3.0))
				# ⚠ ET SES SERVIETTES DESSOUS (demande du client, 13/09 : « tu
				# dois faire des serviettes de plage au sol un peu partout sous
				# les parasols »). Un parasol seul sur le sable a l'air planté
				# là par erreur ; ce qui dit « on est à la plage », ce sont les
				# rectangles de couleur autour de son pied. Le kit n'a pas de
				# serviette — on en fait une surface colorée, comme les
				# pelouses et les tracés de stade.
				for _s in alea.randi_range(1, 3):
					var a := alea.randf() * TAU
					var d := alea.randf_range(2.5, 7.0)
					v.objets.append({"m": "pelouse", "x": x + cos(a) * d,
						"z": z + sin(a) * d, "r": 0.0, "h": 0.0,
						"w": alea.randf_range(1.5, 2.1), "d": alea.randf_range(3.4, 4.4),
						"c": SERVIETTES[alea.randi() % SERVIETTES.size()]})
			elif t < 0.36:
				v.ajouter_objet(CAILLOUX[alea.randi() % CAILLOUX.size()], x, z,
					alea.randf() * TAU, alea.randf_range(0.40, 1.00))
			elif t < 0.44:
				v.ajouter_objet("banc", x, z, alea.randf() * TAU)
			elif t < 0.50:
				# LE SABLE N'EST PAS QUE DU SABLE (kit nature) : touffes d'oyat,
				# caillebotis, troncs, feux de camp. Les pièces de SOL se posent
				# à l'échelle du kit (elles pavent la case) ; le reste prend une
				# hauteur voulue.
				var n := alea.randi() % SUR_LE_SABLE.size()
				v.ajouter_objet(SUR_LE_SABLE[n], x, z, alea.randf() * TAU,
					float(H_SUR_LE_SABLE[n]))
	# ⚠ UNE SEULE TENTE, ET PAS UNE RANGÉE DE CABINES. La tente du kit nature
	# fait 17 unités de large et 11 de haut posée telle quelle : à l'échelle,
	# c'est un chapiteau. Une rangée de chapiteaux barrait la plage (« enlève
	# les tentes ou mets-en une seule devant un feu de camp, elles sont
	# beaucoup trop grosses », client, 12/09). Il en reste UNE, ramenée à
	# quatre unités de haut, avec son feu de camp et ses deux troncs — un
	# bivouac, pas un camping.
	var camp_x := float(mini(taille.x - 8, X_PORT - 9)) * CASE * 0.42
	var camp_z := float(J_SABLE + 1) * CASE + 6.0
	v.ajouter_objet("nature/tent_smallClosed", camp_x, camp_z, PI * 0.75, 2.20)
	v.ajouter_objet("nature/campfire_stones", camp_x + 9.0, camp_z + 7.0, 0.0, 0.45)
	v.ajouter_objet("nature/log", camp_x + 2.0, camp_z + 12.0, 0.4, 0.50)
	v.ajouter_objet("nature/log", camp_x + 16.0, camp_z + 4.0, 1.9, 0.50)
	# Les barques tirées au sec, en haut de plage.
	# ⚠ UNE HAUTEUR VOULUE, JAMAIS L'ÉCHELLE DU KIT POUR UN BATEAU. Le pack
	# nautique est dessiné en unités de jeu, pas en cases : `boat-row-small`
	# posé « tel quel » sortait à cent unités de long — deux barques géantes en
	# travers de la plage. Mise à l'échelle par la hauteur, la coque retrouve
	# sa taille.
	for k in 5:
		var bx := alea.randf_range(4.0, float(mini(taille.x - 4, X_PORT - 5))) * CASE
		v.ajouter_objet("nature/canoe", bx,
			float(J_SABLE + 2) * CASE + alea.randf() * CASE,
			alea.randf_range(-0.5, 0.5) + PI * 0.5, 0.75)
	_le_poste_de_secours(v, alea)
	# LA POINTE ROCHEUSE du bout de plage, côté port : de vraies falaises du kit
	# (mesurées : `cliff_rock` fait une case de large et une case de haut), pas
	# seulement des cailloux grossis.
	for k in 14:
		var x := float(X_PORT - 2) * CASE + alea.randf_range(-10.0, 34.0)
		var z := float(J_SABLE + 1) * CASE + alea.randf_range(0.0, 5.0 * CASE)
		v.ajouter_objet(CAILLOUX[alea.randi() % CAILLOUX.size()], x, z,
			alea.randf() * TAU, alea.randf_range(1.20, 2.60))
	for k in 4:
		var x := float(X_PORT - 3) * CASE + float(k) * CASE * 0.8
		var z := float(J_SABLE + 3 + (k % 2)) * CASE
		v.ajouter_objet("nature/cliff_large_rock" if k % 2 == 0 else "nature/cliff_half_rock",
			x, z, float(alea.randi() % 4) * PI * 0.5, alea.randf_range(5.0, 9.0))
	# Les bouées du chenal, alignées sur la sortie de la jetée.
	for k in 5:
		v.ajouter_objet("bateau:bouee" if k % 2 == 0 else "bateau:bouee_drapeau",
			float(X_JETEE + 3) * CASE, float(J_RIVAGE + 2 + k * 3) * CASE, 0.0)

## LES COULEURS DE SERVIETTE. Franches et variées : c'est leur bariolage qui
## fait la plage fréquentée, une plage de serviettes assorties serait un hôtel.
const SERVIETTES := ["#e8514a", "#f2a43c", "#3f8fd6", "#49b36a", "#d45ea8", "#f2e04a"]

## ⚠ LE POSTE DE SECOURS EST UNE CABANE SUR PILOTIS, PAS UN PAVILLON. Avant, on
## posait un `building-type-k` — une maison de lotissement de vingt mètres — et
## le client ne la voyait pas pour ce qu'elle était : « tu dois mettre un centre
## de sauvetage pour maître nageur » (13/09). Ce qui fait reconnaître un poste
## de secours, ce n'est pas le bâtiment : c'est la SILHOUETTE — une cabine
## carrée perchée sur une plateforme, une rampe, un mât, et le rouge.
static func _le_poste_de_secours(v: Ville2, alea: RandomNumberGenerator) -> void:
	var x := float(X_JETEE - 4) * CASE
	var z := float(J_SABLE + 2) * CASE
	var haut := 5.0
	# La plateforme sur pilotis, à cinq mètres au-dessus du sable.
	v.objets.append({"m": "plateforme", "x": x, "z": z, "r": 0.0, "h": 0.0,
		"w": 14.0, "d": 12.0, "y": haut})
	# La cabine dessus, rouge et blanche.
	v.objets.append({"m": "ville/building-garage", "x": x, "z": z, "r": 0.0,
		"h": 4.2, "dy": haut + 0.8, "c": "#e05a4a", "toit": "#f0f2ee"})
	# Le mât et son drapeau, les bouées, la rampe d'accès.
	v.objets.append({"m": "lampadaire", "x": x + 6.0, "z": z - 5.0, "r": 0.0,
		"h": 11.0, "dy": haut + 0.8})
	for k in 3:
		v.ajouter_objet("bateaux/buoy", x - 7.5, z - 4.0 + float(k) * 4.0, PI * 0.5, 1.4)
	for k in 5:
		v.ajouter_objet("nature/path_wood", x - 10.0 - float(k) * 3.2,
			z + 6.0 + float(k) * 1.1, 0.0, 0.3)
	# Le quad et la remorque de secours, au pied.
	v.ajouter_objet("voitures/suv", x + 12.0, z + 5.0, PI * 0.5)
	v.ajouter_lieu("secours", x, z, {"nom": "Poste de Secours"})

# ------------------------------------------------------------------ 6. la jetée

## LA JETÉE : un tablier sur pilotis qui part du sable et file au large, un
## bar à mi-chemin, la grande roue au bout. C'est le repère du quartier — ce
## qu'on voit de partout, et ce vers quoi on marche.
static func _la_jetee(v: Ville2, alea: RandomNumberGenerator) -> void:
	var x := (float(X_JETEE) + 0.5) * CASE
	var j := float(J_SABLE + 1)
	while j < float(J_JETEE_BOUT):
		v.objets.append({"m": "plateforme", "x": x, "z": (j + 1.0) * CASE, "r": 0.0,
			"h": 0.0, "w": 14.0, "d": 2.0 * CASE, "y": TABLIER})
		j += 2.0
	# L'élargissement du bout, qui porte la roue.
	v.objets.append({"m": "plateforme", "x": x, "z": (float(J_JETEE_BOUT) + 1.0) * CASE, "r": 0.0,
		"h": 0.0, "w": 2.2 * CASE, "d": 2.4 * CASE, "y": TABLIER})
	# Les lampadaires de la jetée, en quinconce.
	var k := 0
	var z := float(J_SABLE + 2) * CASE
	while z < float(J_JETEE_BOUT) * CASE:
		v.objets.append({"m": "lampadaire", "x": x + (5.0 if k % 2 == 0 else -5.0),
			"z": z, "r": 0.0, "h": 0.0, "y_abs": TerrainV2.NIVEAU_MER + TABLIER + 0.35})
		k += 1
		z += 2.5 * CASE
	# LE BAR de la jetée, à mi-longueur : le tablier s'y élargit, et c'est un
	# vrai commerce du kit — un bloc gris posé là n'était qu'un bloc gris.
	var mi := float((J_SABLE + 1 + J_JETEE_BOUT)) * 0.5 * CASE
	v.objets.append({"m": "plateforme", "x": x, "z": mi, "r": 0.0,
		"h": 0.0, "w": 2.4 * CASE, "d": 2.0 * CASE, "y": TABLIER})
	v.objets.append({"m": "res://modeles/kenney/batiments/building-c.glb",
		"x": x, "z": mi, "r": PI, "h": 0.0, "y_abs": TerrainV2.NIVEAU_MER + TABLIER + 0.35})
	v.objets.append({"m": "parasol", "x": x - 16.0, "z": mi + 6.0, "r": 0.0, "h": 0.0,
		"y_abs": TerrainV2.NIVEAU_MER + TABLIER + 0.35})
	v.objets.append({"m": "parasol_b", "x": x + 16.0, "z": mi - 6.0, "r": 0.0, "h": 0.0,
		"y_abs": TerrainV2.NIVEAU_MER + TABLIER + 0.35})
	# LA GRANDE ROUE, au bout, face à la plage.
	v.objets.append({"m": "roue", "x": x, "z": (float(J_JETEE_BOUT) + 1.0) * CASE,
		"r": 0.0, "h": 0.0, "w": 34.0, "y_abs": TerrainV2.NIVEAU_MER + TABLIER + 0.35})
	# Les barques amarrées au pied de la jetée.
	for b in 4:
		v.ajouter_objet("bateau:barque" if b % 2 == 0 else "bateau:vedette_b",
			x - 16.0 - float(b) * 3.0, float(J_RIVAGE + 2 + b) * CASE, alea.randf_range(1.2, 1.9))

## La taille d'un conteneur du kit, mesurée, en unités : 7,5 large, 7,0 haut,
## 16,5 long.
const CONTENEUR := Vector3(7.46, 6.96, 16.46)
## Le jeu entre deux boîtes : ce que laisse un cavalier gerbeur pour passer.
const JEU_GRUE := 1.6

static func _les_conteneurs(v: Ville2, alea: RandomNumberGenerator, taille: Vector2i,
		zq: float) -> void:
	# Tournés d'un quart de tour : leur longueur suit l'axe des x, comme les
	# rangées du quai. Donc pas de `CONTENEUR.z` en x, `CONTENEUR.x` en z.
	var pas_x := CONTENEUR.z + JEU_GRUE
	var pas_z := CONTENEUR.x + JEU_GRUE
	var x0 := (float(X_PORT) + 0.2) * CASE
	var rangs := 5
	for r in rangs:
		var z := zq - 14.0 - float(r) * pas_z
		var x := x0
		while x < float(taille.x - 1) * CASE:
			# Une travée sur six reste vide : c'est l'allée du cavalier.
			if alea.randf() < 0.82:
				var pile := 1 + alea.randi() % 3
				for k in pile:
					var lettre: String = ["a", "b", "c"][alea.randi() % 3]
					v.objets.append({
						"m": "res://modeles/kenney/industriel/shipping-container-%s.glb" % lettre,
						"x": x, "z": z, "r": PI * 0.5, "h": 0.0,
						"dy": float(k) * CONTENEUR.y})
			x += pas_x
	# Quelques boîtes isolées, posées de travers près du hangar : un quai n'est
	# jamais parfait. Elles sont HORS de la grille, donc sans risque.
	for k in 4:
		v.ajouter_objet("res://modeles/kenney/industriel/shipping-container-b.glb",
			(float(X_PORT) + 0.5 + float(k) * 1.4) * CASE, zq - 14.0 - float(rangs) * pas_z - 24.0,
			alea.randf_range(-0.25, 0.25))

# ------------------------------------------------------------------ 7. le port

## LE PORT DE COMMERCE : un terre-plein pavé, des piles de conteneurs, des
## cargos à quai et un remorqueur. Le quai est vertical : l'eau arrive au pied
## de la dalle, et la coque d'un cargo tient contre elle.
static func _le_port(v: Ville2, alea: RandomNumberGenerator, taille: Vector2i) -> void:
	var zq := float(J_QUAI) * CASE
	# ⚠⚠ ON EMPILE LES CONTENEURS, ON NE LES ENCASTRE PAS (demande du client,
	# 13/09 : « tu ne dois pas fusionner des conteneurs — empile-les si tu dois
	# le faire »).
	#
	# La faute était arithmétique. Un conteneur du kit mesure, à l'échelle de la
	# case, 7,5 × 16,5 × 7,0 mètres. Les rangées étaient espacées de TREIZE
	# mètres et l'orientation tirée au hasard entre 0 et un quart de tour : une
	# fois sur deux la profondeur de 16,5 m tombait dans un pas de 13 m, et la
	# rangée suivante entrait dans la précédente. Rien ne pouvait le rattraper —
	# ce sont des objets libres, personne ne vérifiait.
	#
	# Un parc à conteneurs réel est ORTHOGONAL et tout aligné : c'est la
	# manutention qui l'impose, et c'est aussi ce qui se lit d'en haut. On pose
	# donc toutes les boîtes dans le même sens, au pas de leur taille réelle
	# plus un jeu de grutage, et la variété vient de la HAUTEUR des piles.
	_les_conteneurs(v, alea, taille, zq)
	# Les cuves et le château d'eau du terre-plein.
	v.ajouter_objet("res://modeles/kenney/industriel/water-tower.glb",
		(float(X_PORT) + 0.6) * CASE, zq - 46.0, 0.0)
	for k in 2:
		v.ajouter_objet("res://modeles/kenney/industriel/detail-tank-large.glb",
			(float(X_PORT + 3 + k * 2) + 0.5) * CASE, zq - 44.0, 0.0)
	# Les bornes du bord de quai : on ne tombe pas à l'eau par distraction.
	var i2 := X_PORT
	while i2 < taille.x - 1:
		v.ajouter_objet("borne", (float(i2) + 0.5) * CASE, zq - 2.0, 0.0)
		i2 += 1
	# LES CARGOS À QUAI, le long du bord, plus un remorqueur au large.
	v.ajouter_objet("bateau:cargo", (float(X_PORT) + 2.0) * CASE, zq + 12.0, 0.0)
	v.ajouter_objet("bateau:cargo_b", (float(X_PORT) + 6.5) * CASE, zq + 28.0, 0.08)
	v.ajouter_objet("bateau:remorqueur", (float(X_PORT) - 1.0) * CASE, zq + 42.0, 2.6)
	v.ajouter_objet("bateau:paquebot", (float(taille.x) - 3.0) * CASE, zq + 34.0, 0.0)
	# Les bateaux de pêche, contre le quai du fond.
	for k in 3:
		v.ajouter_objet("bateau:peche", (float(taille.x - 2) - float(k) * 1.2) * CASE,
			zq + 6.0 + float(k) * 2.0, PI * 0.5)

## Cherche une place pour un repère du client, en spirale autour du point voulu
## et dans les quatre orientations. Même règle partout : un repère qui abandonne
## au premier refus n'apparaît jamais, et rien ne le dit.
static func _poser_repere(v: Ville2, modele: String, depart: Vector2i, quarts: int,
		genre: String, nom: String, portee := 9) -> bool:
	for tour in [quarts, (quarts + 2) % 4, (quarts + 1) % 4, (quarts + 3) % 4]:
		var e := KitVille2.emprise_tournee(modele, tour)
		for rayon in range(0, portee):
			for dj in range(-rayon, rayon + 1):
				for di in range(-rayon, rayon + 1):
					if maxi(absi(di), absi(dj)) != rayon: continue
					var c := depart + Vector2i(di, dj)
					if c.x < 1 or c.y < 1: continue
					if not Lotisseur.terrain_libre(v, c.x * 2, c.y * 2, e): continue
					v.ajouter_lot(modele, c.x * 2, c.y * 2, e.x, e.y, tour, genre)
					v.ajouter_lieu(genre, (float(c.x) + float(e.x) * 0.25) * CASE,
						(float(c.y) + float(e.y) * 0.25) * CASE, {"nom": nom})
					return true
	push_warning("repère « %s » : pas de place" % nom)
	return false
