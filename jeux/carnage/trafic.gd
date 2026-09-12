class_name TraficCarnage
extends RefCounted
## LA CIRCULATION ET LES TROTTOIRS : comment une voiture de la ville roule, et
## comment un passant marche. L'hôte seul s'en sert (`VilleVivante`), et ce
## module ne connaît que le plan — pas la scène, pas le réseau.
##
## Avant, une voiture civile allait tout droit jusqu'à ce qu'un mur ou un
## tirage au sort lui fasse prendre la perpendiculaire D'UN COUP : le cap
## sautait de quatre-vingt-dix degrés en une image, la position se recalait
## d'un bond sur la file, et rien ne l'empêchait de naître dans l'eau ni de
## foncer dedans — l'eau n'était qu'un « mur » de plus contre lequel elle se
## cognait. Un passant, lui, tirait une direction au hasard toutes les trois
## secondes et grattait les façades.
##
## Ici la rue est un GRAPHE : les carrefours sont les nœuds (tous les cinq
## cents pixels), les rues entre deux carrefours des arêtes — praticables ou
## non, selon qu'il y a du bitume, de l'eau, ou un pâté qui a avalé la rue.
## Une voiture roule d'un nœud au suivant sur sa file de droite, DÉCIDE au
## nœud d'avant ce qu'elle fera au prochain (tout droit, à droite, à gauche —
## demi-tour seulement en cul-de-sac), et un virage est un ARC : le cap ne
## saute jamais, il tourne à une vitesse angulaire bornée par le rayon de
## braquage, et la voiture ralentit avant de tourner. Un passant suit la ligne
## du trottoir de la même façon, tourne au coin, traverse au passage piéton,
## et s'arrête parfois devant une vitrine.
##
## Les boulevards, avenues et places (les « voies libres » du plan) restent
## suivis par leur tangente, comme avant — mais avec le même volant borné.

const FILE := 32.0                   ## px : la file de droite, depuis l'axe de la rue
const TROTTOIR := 90.0               ## px : la ligne de marche d'un passant, depuis l'axe
const ENTRE_CARREFOURS := float(PlanVille.PERIODE) * PlanVille.PAS   ## 500 px
const RAYON_DROITE := 44.0           ## px : un virage à droite est serré
const RAYON_GAUCHE := 104.0          ## px : à gauche, on traverse le carrefour
const RAYON_FILE := 150.0            ## px : tenir sa file, c'est un volant doux
const VISEE := 70.0                  ## px : ce qu'on regarde devant soi pour se placer
## La file de droite sur un boulevard, en tuiles depuis l'axe. ⚠ Plus près de
## l'axe que celle du plan (0,6) : une avenue en DIAGONALE est bordée de
## tuiles carrées, et sur un pont ces tuiles sont de l'eau — leurs coins
## mordent la chaussée jusqu'à quatre-vingts pixels de l'axe. À 0,6, une
## voiture sur deux s'y coinçait la roue et « se noyait ».
const FILE_BOULEVARD := 0.36
const AXES := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
## Les poids d'un choix au carrefour : la plupart continuent, sinon on
## tourne — un peu plus souvent à droite, qui ne coupe personne.
const POIDS_DROIT := 0.62
const POIDS_DROITE := 0.22
const POIDS_GAUCHE := 0.16

## Ce qu'un tournant vaut : 0 tout droit, 1 à droite, -1 à gauche, 2 demi-tour.
enum { TOUT_DROIT = 0, A_DROITE = 1, A_GAUCHE = -1, DEMI_TOUR = 2 }

var plan: PlanVille
var _rng: RandomNumberGenerator
var _routes: Dictionary = {}         ## Vector3i(i, j, axe) -> bool : la rue est-elle roulable
var _trottoirs: Dictionary = {}      ## Vector4i(i, j, axe, côté) -> bool : le trottoir est-il praticable

func _init(plan_de_ville: PlanVille, rng: RandomNumberGenerator) -> void:
	plan = plan_de_ville
	_rng = rng

# ------------------------------------------------------------ la grille

static func droite_de(direction: Vector2) -> Vector2:
	return Vector2(-direction.y, direction.x)

## L'axe de la grille le plus proche d'un cap quelconque.
static func axe_proche(direction: Vector2) -> Vector2:
	if abs(direction.x) >= abs(direction.y):
		return Vector2(signf(direction.x) if direction.x != 0.0 else 1.0, 0.0)
	return Vector2(0.0, signf(direction.y))

static func indice_axe(axe: Vector2) -> int:
	for k in AXES.size():
		if Vector2(AXES[k]).dot(axe) > 0.9:
			return k
	return 0

## Les coordonnées de grille d'un carrefour (son centre en pixels).
static func indices_du_noeud(centre: Vector2) -> Vector2i:
	return Vector2i(int(round((centre.x / PlanVille.PAS - 1.0) / float(PlanVille.PERIODE))),
		int(round((centre.y / PlanVille.PAS - 1.0) / float(PlanVille.PERIODE))))

## La rue qui part d'un carrefour dans une direction est-elle roulable sur
## toute sa longueur ? On sonde la file de droite en cinq points : un pâté
## qui a avalé la rue, un bras d'eau sans pont, le bord de la carte ou le
## parvis d'une place l'interdisent. Mis en cache : la ville a des milliers
## de rues, et une voiture demande ça à chaque carrefour.
func roulable(noeud: Vector2, axe: Vector2) -> bool:
	var ij := indices_du_noeud(noeud)
	var cle := Vector3i(ij.x, ij.y, indice_axe(axe))
	if _routes.has(cle):
		return _routes[cle]
	var n := droite_de(axe)
	var ok := true
	for t in [70.0, 160.0, 250.0, 340.0, 430.0]:
		var p: Vector2 = noeud + axe * t + n * FILE
		if plan.dans_un_batiment(p, VilleVivante.RAYON_AUTO - 4.0):
			ok = false
			break
		var libre := plan.voie_libre_en(p)
		if not libre.is_empty() and String(libre["genre"]) == "esplanade":
			ok = false
			break
	_routes[cle] = ok
	return ok

## Le trottoir qui part d'un carrefour, d'un côté de la rue : praticable ?
func praticable(noeud: Vector2, axe: Vector2, cote: int) -> bool:
	var ij := indices_du_noeud(noeud)
	var cle := Vector4i(ij.x, ij.y, indice_axe(axe), cote)
	if _trottoirs.has(cle):
		return _trottoirs[cle]
	var n := droite_de(axe) * float(cote)
	var ok := true
	for t in [60.0, 150.0, 250.0, 350.0, 440.0]:
		var p: Vector2 = noeud + axe * t + n * TROTTOIR
		if plan.dans_un_batiment(p, VilleVivante.RAYON_PIETON - 6.0):
			ok = false
			break
	_trottoirs[cle] = ok
	return ok

## Que fera-t-on au carrefour `noeud`, en y arrivant par `route` ? Un tirage
## pondéré parmi les sorties roulables ; s'il n'y en a aucune, c'est un
## cul-de-sac et l'on fait demi-tour.
func choisir_le_tournant(noeud: Vector2, route: Vector2) -> int:
	var choix: Array = []
	var poids: Array = []
	if roulable(noeud, route):
		choix.append(TOUT_DROIT); poids.append(POIDS_DROIT)
	if roulable(noeud, droite_de(route)):
		choix.append(A_DROITE); poids.append(POIDS_DROITE)
	if roulable(noeud, -droite_de(route)):
		choix.append(A_GAUCHE); poids.append(POIDS_GAUCHE)
	if choix.is_empty():
		return DEMI_TOUR
	var total := 0.0
	for w in poids:
		total += float(w)
	var tirage := _rng.randf() * total
	for k in choix.size():
		tirage -= float(poids[k])
		if tirage <= 0.0:
			return int(choix[k])
	return int(choix[choix.size() - 1])

## La route après un tournant.
static func route_apres(route: Vector2, tournant: int) -> Vector2:
	match tournant:
		A_DROITE: return droite_de(route)
		A_GAUCHE: return -droite_de(route)
		DEMI_TOUR: return -route
	return route

## Tourne un cap vers un cap voulu, d'au plus `omega × delta` radians : c'est
## le volant borné, celui qui fait qu'un virage est un arc et pas un saut.
static func braquer(cap: Vector2, voulu: Vector2, omega: float, delta: float) -> Vector2:
	if voulu == Vector2.ZERO:
		return cap
	var ecart := cap.angle_to(voulu)
	return cap.rotated(clampf(ecart, -omega * delta, omega * delta)).normalized()

# ------------------------------------------------------------ les voitures

## Pose une voiture sur la grille : sa route est l'axe le plus proche de son
## cap, son prochain carrefour est devant elle, et son tournant y est décidé.
func placer_sur_la_grille(auto: Dictionary, route: Vector2 = Vector2.ZERO) -> void:
	var d: Vector2 = auto.get("d", Vector2.RIGHT)
	if route == Vector2.ZERO:
		route = axe_proche(d)
	var carrefour := plan.carrefour_proche(auto["p"])
	var noeud := carrefour
	if (carrefour - Vector2(auto["p"])).dot(route) < 30.0:
		noeud = carrefour + route * ENTRE_CARREFOURS
	auto["route"] = route
	auto["prochain"] = noeud
	auto["tournant"] = choisir_le_tournant(noeud, route)
	auto["vire"] = false
	auto["libre"] = false
	auto["bloque"] = 0.0

## Un point de naissance pour une voiture qui roule : sur une rue roulable,
## dans sa file, dans le bon sens — jamais dans l'eau, jamais dans un pâté,
## jamais sur le parvis. Vide si l'on n'a rien trouvé en huit essais.
func naissance_auto(autour: Vector2, rayon_min: float, rayon_max: float) -> Dictionary:
	for essai in 8:
		var p: Vector2 = autour + Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(rayon_min, rayon_max)
		var noeud := plan.carrefour_proche(p)
		var k0 := _rng.randi_range(0, 3)
		for k in 4:
			var axe: Vector2 = AXES[(k0 + k) % 4]
			if not roulable(noeud, axe):
				continue
			var ou: Vector2 = noeud + axe * _rng.randf_range(120.0, 380.0) + droite_de(axe) * FILE
			if plan.dans_un_batiment(ou, VilleVivante.RAYON_AUTO + 6.0):
				continue
			return {"p": ou, "d": axe, "route": axe, "prochain": noeud + axe * ENTRE_CARREFOURS}
	return {}

## La rue où l'on est (celle qui porte le point, dans cet axe) est-elle
## roulable ? Sert à décider de quitter un boulevard pour une rue de la grille.
func _rue_courante_roulable(p: Vector2, axe: Vector2) -> bool:
	var noeud := plan.carrefour_proche(p)
	if (noeud - p).dot(axe) < 30.0:
		return roulable(noeud, axe)
	return roulable(noeud - axe * ENTRE_CARREFOURS, axe)

## Une voiture civile roule : file, carrefours, virages en arc, boulevards.
## `obstacle` dit s'il y a quelque chose devant (c'est la ville qui le sait,
## elle a tout le monde sous la main) ; on rend la vitesse voulue à zéro dans
## ce cas et la ville gère le klaxon.
func conduire(auto: Dictionary, delta: float, obstacle: bool) -> void:
	var modele := int(auto.get("modele", 0))
	var allure: float = VilleVivante.VITESSE_TRAFIC * VehiculesCarnage.valeur(modele, "vt")
	var d: Vector2 = auto.get("d", Vector2.RIGHT)
	if d == Vector2.ZERO:
		d = Vector2.RIGHT
	if not auto.has("route"):
		placer_sur_la_grille(auto)
	var p: Vector2 = auto["p"]
	var voulu := Vector2.ZERO          # le cap qu'on aimerait avoir
	var plafond := allure              # la vitesse qu'on aimerait
	var rayon := RAYON_FILE            # le rayon de braquage du moment

	# ── Les voies libres : boulevards, avenues, places. On les suit par leur
	# tangente si l'on y est déjà, ou si l'on y arrive à peu près dans leur
	# sens — une fois sur deux : sans ce tirage, tout ce qui coupait une avenue
	# en diagonale s'y engouffrait, et la grille se vidait.
	var libre := plan.voie_libre_en(p)
	var genre := String(libre.get("genre", ""))
	if genre == "esplanade":
		libre = {}
		genre = ""
	var suivait := bool(auto.get("libre", false))
	var suit := false
	if not libre.is_empty():
		var t: Vector2 = libre["d"]
		var alignee := d.dot(t)
		if suivait:
			suit = true
		elif genre == "place" or abs(alignee) > 0.5:
			if not auto.has("hesite"):
				auto["hesite"] = _rng.randf() < 0.5
			suit = bool(auto["hesite"])
		if suit:
			var meme_sens := genre == "place" or alignee >= 0.0
			if not meme_sens:
				t = -t
			var s: float = float(libre["s"]) * (1.0 if meme_sens else -1.0)
			var n := droite_de(t)
			var ecart_px := (FILE_BOULEVARD - s) * PlanVille.PAS
			voulu = (t * VISEE + n * clampf(ecart_px, -VISEE, VISEE)).normalized()
			rayon = RAYON_DROITE * 1.4 if genre == "place" else RAYON_GAUCHE
			if genre == "place":
				plafond = minf(plafond, allure * 0.6)
				# Sortir de la place : quand on passe devant une avenue, une
				# fois sur deux environ, on la prend.
				var radial: Vector2 = (p / PlanVille.PAS - Vector2(libre["c"])).normalized()
				for e in plan.sorties_de_la_place(int(libre["e"])):
					if Vector2(e).dot(radial) > 0.94 and _rng.randf() < delta * 1.4:
						voulu = e
			auto["libre"] = true
			# Quitter un boulevard : au croisement d'une rue de la grille, de
			# temps en temps, on tourne dedans — et le volant fait le reste.
			if genre != "place" and _rng.randf() < delta * 0.35:
				var colonne := int(floor(p.x / PlanVille.PAS))
				var ligne := int(floor(p.y / PlanVille.PAS))
				var sortie := Vector2.ZERO
				if PlanVille.est_voie(ligne) and abs(d.x) > 0.3:
					sortie = Vector2(signf(d.x), 0.0)
				elif PlanVille.est_voie(colonne) and abs(d.y) > 0.3:
					sortie = Vector2(0.0, signf(d.y))
				if sortie != Vector2.ZERO and _rue_courante_roulable(p, sortie):
					auto["sortie"] = sortie
					suit = false
	else:
		auto.erase("hesite")

	if not suit:
		if suivait:
			# On sort d'une voie libre : on se recale sur la grille, sans à-coup
			# — sur la rue qu'on a choisie s'il y en a une, sinon sur l'axe le
			# plus proche du cap.
			placer_sur_la_grille(auto, auto.get("sortie", Vector2.ZERO))
			auto.erase("sortie")
			auto["vire"] = true
			auto["dernier"] = A_GAUCHE
		var route: Vector2 = auto["route"]
		var noeud: Vector2 = auto["prochain"]
		var tournant := int(auto.get("tournant", TOUT_DROIT))
		var reste := (noeud - p).dot(route)
		# ⚠ Un carrefour qu'on a dépassé de beaucoup (poussé par un choc,
		# repris après un blocage) : on se replace, sinon on vise un point
		# derrière soi pour toujours.
		if reste < -ENTRE_CARREFOURS * 0.6:
			placer_sur_la_grille(auto, route)
			noeud = auto["prochain"]
			tournant = int(auto["tournant"])
			reste = (noeud - p).dot(route)
		# Un mur (ou l'eau) à quatre-vingt-dix pixels DEVANT, sur une rue qu'on
		# croyait roulable : c'est une rue coupée en son milieu — un bras
		# d'eau sans pont, un chantier. On fait demi-tour AVANT, en arc, plutôt
		# que de s'y cogner et de pivoter sur place.
		if not bool(auto.get("vire", false)) and plan.dans_un_batiment(p + route * 90.0, VilleVivante.RAYON_AUTO):
			route = -route
			noeud = plan.carrefour_proche(p)
			if (noeud - p).dot(route) < 30.0:
				noeud += route * ENTRE_CARREFOURS
			auto["route"] = route
			auto["prochain"] = noeud
			auto["tournant"] = choisir_le_tournant(noeud, route)
			auto["vire"] = true
			auto["dernier"] = DEMI_TOUR
			tournant = int(auto["tournant"])
			reste = (noeud - p).dot(route)
		if not bool(auto.get("vire", false)):
			var seuil := 0.0
			match tournant:
				A_DROITE: seuil = FILE + RAYON_DROITE
				A_GAUCHE: seuil = RAYON_GAUCHE - FILE
				DEMI_TOUR: seuil = 30.0
			if reste <= seuil:
				if tournant == TOUT_DROIT:
					noeud += route * ENTRE_CARREFOURS
				else:
					route = route_apres(route, tournant)
					noeud += route * ENTRE_CARREFOURS
					auto["vire"] = true
					auto["dernier"] = tournant
				auto["route"] = route
				auto["prochain"] = noeud
				auto["tournant"] = choisir_le_tournant(noeud, route)
				tournant = int(auto["tournant"])
				reste = (noeud - p).dot(route)
		# On ralentit avant de tourner, plus pour un virage serré.
		if tournant != TOUT_DROIT and reste < 170.0:
			plafond = minf(plafond, allure * (0.5 if tournant != A_GAUCHE else 0.62))
		if bool(auto.get("vire", false)):
			plafond = minf(plafond, allure * 0.62)
			match int(auto.get("dernier", A_GAUCHE)):
				A_DROITE: rayon = RAYON_DROITE
				DEMI_TOUR: rayon = RAYON_DROITE * 1.2
				_: rayon = RAYON_GAUCHE
		# Tenir sa file : on vise un point devant soi, sur la file de droite
		# de la rue qu'on suit. Loin de la file, on y va franchement ; dessus,
		# le point est droit devant et le volant ne bouge pas.
		var n := droite_de(route)
		var ecart := (noeud + n * FILE - p).dot(n)
		voulu = (route * VISEE + n * clampf(ecart, -VISEE, VISEE)).normalized()
		if bool(auto.get("vire", false)) and abs(d.angle_to(route)) < 0.12 and abs(ecart) < 10.0:
			auto["vire"] = false
			rayon = RAYON_FILE

	# ── La vitesse : la sienne, bornée par le virage, nulle derrière un
	# obstacle. Un camion part et s'arrête moins vite qu'une compacte.
	var vitesse := float(auto.get("vitesse", 0.0))
	var cible := 0.0 if obstacle else plafond
	var accel: float = 300.0 * VehiculesCarnage.valeur(modele, "a")
	var frein: float = 900.0 * VehiculesCarnage.valeur(modele, "f")
	vitesse = move_toward(vitesse, cible, (accel if cible > vitesse else frein) * delta)

	# ── Le volant : borné par la vitesse et le rayon, jamais instantané. À
	# l'arrêt on ne tourne pas les roues d'un bloc non plus.
	var omega := clampf(maxf(vitesse, 60.0) / rayon, 0.9, 5.5)
	d = braquer(d, voulu, omega, delta)

	# ── On avance ; les murs (et l'eau, qui en est un) restent une sécurité,
	# plus une méthode : une voiture qui les touche encore est une voiture
	# qui a été poussée là, et elle repart.
	var suivant: Vector2 = p + d * vitesse * delta
	var degage := plan.degager(suivant, VilleVivante.RAYON_AUTO)
	if bool(degage[1]):
		# On ne compte le blocage que si l'on POUSSAIT : une voiture arrêtée
		# derrière une autre, la roue contre une borne, n'est pas coincée.
		if vitesse > 20.0:
			auto["bloque"] = float(auto.get("bloque", 0.0)) + delta
		vitesse *= 0.5
		if float(auto["bloque"]) > 1.2:
			if OS.has_environment("TRAFIC_DEBUG"):
				var c := int(floor(p.x / PlanVille.PAS)); var l := int(floor(p.y / PlanVille.PAS))
				print("[trafic] coincee %s route=%s prochain=%s libre=%s tile=(%d,%d) eau=%s vl=%s vire=%s tournant=%d" % [str(p), str(auto.get("route")), str(auto.get("prochain")), str(auto.get("libre")), c, l, str(plan.eau(c, l)), str(plan.voie_libre_en(p).get("genre", "")), str(auto.get("vire")), int(auto.get("tournant", 0))])
			# Coincée pour de bon : demi-tour — en arc, roues braquées, comme
			# on manœuvre dans une impasse ; le volant borné tourne même à
			# l'arrêt, lentement, et la voiture repart dans l'autre sens.
			var route_r: Vector2 = -Vector2(auto.get("route", axe_proche(d)))
			var noeud_r := plan.carrefour_proche(p)
			if (noeud_r - p).dot(route_r) < 30.0:
				noeud_r += route_r * ENTRE_CARREFOURS
			auto["route"] = route_r
			auto["prochain"] = noeud_r
			auto["tournant"] = choisir_le_tournant(noeud_r, route_r)
			auto["vire"] = true
			auto["dernier"] = DEMI_TOUR
			auto["libre"] = false
			auto["bloque"] = -2.0
	elif float(auto.get("bloque", 0.0)) > 0.0:
		auto["bloque"] = 0.0
	else:
		auto["bloque"] = minf(0.0, float(auto.get("bloque", 0.0)) + delta)
	auto["p"] = degage[0]
	auto["d"] = d
	auto["vitesse"] = vitesse
	auto["a"] = d.angle()

# ------------------------------------------------------------ les passants

const VITESSE_ANGULAIRE_MARCHE := 5.0     ## rad/s : on se retourne en un tiers de seconde
const CHANCE_PAUSE := 0.05                ## par seconde : s'arrêter devant une vitrine
const POIDS_TRAVERSEE := 0.14             ## au coin : changer de trottoir
const POIDS_COIN := 0.30                  ## au coin : tourner
## Le bord d'un boulevard, en tuiles depuis l'axe : là où marche un passant.
## ⚠ Pas au ras du trottoir (1,2 tuile) : sur un pont en diagonale, les coins
## des tuiles d'eau mordent la chaussée jusqu'à quatre-vingts pixels de l'axe.
const BORD_BOULEVARD := 0.8

## Pose un passant sur le trottoir le plus proche de lui, s'il est près d'une
## rue ; sinon il reste en errance (un parc, une cour, une esplanade).
func placer_sur_le_trottoir(personne: Dictionary) -> bool:
	var p: Vector2 = personne["p"]
	if not plan.sur_une_rue(p, 40.0):
		personne.erase("route")
		return false
	var d: Vector2 = personne.get("d", Vector2.RIGHT)
	var carrefour := plan.carrefour_proche(p)
	# La rue la plus proche : celle dont l'axe est le plus près du passant.
	var route := axe_proche(d)
	var dx: float = abs(p.x - carrefour.x)
	var dy: float = abs(p.y - carrefour.y)
	# Près de l'axe vertical (x proche) : on marche le long de la rue
	# verticale ; près de l'axe horizontal : le long de l'horizontale.
	if dx < dy and abs(route.x) > 0.5:
		route = Vector2(0.0, signf(d.y) if d.y != 0.0 else 1.0)
	elif dy < dx and abs(route.y) > 0.5:
		route = Vector2(signf(d.x) if d.x != 0.0 else 1.0, 0.0)
	var n := droite_de(route)
	var cote := 1 if (p - carrefour).dot(n) >= 0.0 else -1
	var noeud := carrefour
	if (carrefour - p).dot(route) < TROTTOIR:
		noeud = carrefour + route * ENTRE_CARREFOURS
	if not praticable(noeud - route * ENTRE_CARREFOURS, route, cote):
		personne.erase("route")
		return false
	personne["route"] = route
	personne["cote"] = cote
	personne["prochain"] = noeud
	personne.erase("but")
	return true

## Un point de naissance pour un passant : sur un trottoir praticable. Vide
## si l'on n'a rien trouvé.
func naissance_passant(autour: Vector2, rayon_min: float, rayon_max: float) -> Dictionary:
	for essai in 8:
		var p: Vector2 = autour + Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(rayon_min, rayon_max)
		var noeud := plan.carrefour_proche(p)
		var k0 := _rng.randi_range(0, 3)
		var cote := 1 if _rng.randf() < 0.5 else -1
		for k in 4:
			var axe: Vector2 = AXES[(k0 + k) % 4]
			if not praticable(noeud, axe, cote):
				continue
			var ou: Vector2 = noeud + axe * _rng.randf_range(40.0, 460.0) + droite_de(axe) * float(cote) * TROTTOIR
			if plan.dans_un_batiment(ou, VilleVivante.RAYON_PIETON):
				continue
			# Dans un sens ou l'autre : un trottoir se remonte aussi.
			var sens := axe if _rng.randf() < 0.5 else -axe
			return {"p": ou, "d": sens, "route": sens, "cote": cote,
				"prochain": noeud + axe * ENTRE_CARREFOURS if sens == axe else noeud}
	return {}

## Un passant tranquille marche. Renvoie la vitesse à laquelle il va (zéro
## s'il fait une pause) ; son cap est dans `d`, lissé.
func marcher(personne: Dictionary, delta: float) -> float:
	var p: Vector2 = personne["p"]
	var d: Vector2 = personne.get("d", Vector2.RIGHT)
	if d == Vector2.ZERO:
		d = Vector2.RIGHT
	var allure: float = VilleVivante.VITESSE_MARCHE * float(personne.get("allure", 1.0))
	if not personne.has("allure"):
		personne["allure"] = _rng.randf_range(0.78, 1.18)
		allure = VilleVivante.VITESSE_MARCHE * float(personne["allure"])

	# La pause : devant une vitrine, au téléphone, à attendre quelqu'un.
	if float(personne.get("pause", 0.0)) > 0.0:
		personne["pause"] = float(personne["pause"]) - delta
		return 0.0
	if _rng.randf() < delta * CHANCE_PAUSE:
		personne["pause"] = _rng.randf_range(1.5, 5.0)
		return 0.0

	if not personne.has("route"):
		# L'errance : un parc, une cour, un boulevard. Sur un boulevard on
		# longe la chaussée, du côté où l'on est, comme sur un trottoir ;
		# ailleurs on va où l'on va, on change d'idée toutes les cinq ou huit
		# secondes, et l'on reprend le premier trottoir venu.
		var libre := plan.voie_libre_en(p)
		if not libre.is_empty() and String(libre["genre"]) != "place":
			var t: Vector2 = libre["d"]
			if d.dot(t) < 0.0:
				t = -t
			# Le côté se décide en entrant sur le boulevard et ne change plus :
			# relu à chaque image sur le signe de `s`, il basculait dès qu'on
			# frôlait l'axe et le passant zigzaguait au milieu de la chaussée.
			if not personne.has("bord"):
				personne["bord"] = 1.0 if float(libre["s"]) >= 0.0 else -1.0
			var cote := float(personne["bord"]) * (1.0 if d.dot(Vector2(libre["d"])) >= 0.0 else -1.0)
			var ecart_px: float = (cote * BORD_BOULEVARD - float(libre["s"]) * (1.0 if d.dot(Vector2(libre["d"])) >= 0.0 else -1.0)) * PlanVille.PAS
			var n := droite_de(t)
			var voulu_b := (t * VISEE + n * clampf(ecart_px, -VISEE, VISEE)).normalized()
			d = braquer(d, voulu_b, VITESSE_ANGULAIRE_MARCHE, delta)
			personne["d"] = d
			personne["errance"] = 0.0
			return allure
		personne.erase("bord")
		personne["errance"] = float(personne.get("errance", 0.0)) - delta
		if float(personne["errance"]) <= 0.0:
			personne["errance"] = _rng.randf_range(5.0, 8.0)
			if plan.sur_une_rue(p, 40.0) and placer_sur_le_trottoir(personne):
				personne.erase("voulu")
				return allure
			# On tourne d'un quart de tour au plus : pas de demi-tour sec.
			personne["voulu"] = d.rotated(_rng.randf_range(-PI * 0.5, PI * 0.5))
		if personne.has("voulu"):
			d = braquer(d, personne["voulu"], VITESSE_ANGULAIRE_MARCHE * 0.5, delta)
		personne["d"] = d
		return allure

	var route: Vector2 = personne["route"]
	var cote := int(personne.get("cote", 1))
	var noeud: Vector2 = personne["prochain"]
	var n := droite_de(route) * float(cote)
	var voulu: Vector2

	if personne.has("but"):
		# En train de traverser : on va au point visé sur l'autre trottoir.
		var but: Vector2 = personne["but"]
		if p.distance_to(but) < 10.0:
			personne.erase("but")
			personne["cote"] = -cote
			cote = -cote
			n = -n
			voulu = route
		else:
			voulu = (but - p).normalized()
	else:
		var reste := (noeud - p).dot(route)
		if reste < -ENTRE_CARREFOURS * 0.6:
			placer_sur_le_trottoir(personne)
			noeud = personne.get("prochain", noeud)
			reste = (noeud - p).dot(route)
		if reste <= TROTTOIR:
			# Au coin : on continue (le passage piéton traverse la rue de
			# côté), on tourne, ou l'on change de trottoir. Le prochain
			# carrefour est posé ICI, une fois : sinon on redéciderait à
			# chaque image tant qu'on est au coin.
			var tirage := _rng.randf()
			var fait := false
			if tirage < POIDS_TRAVERSEE and praticable(noeud, route, -cote):
				# Changer de trottoir : on traverse au passage piéton, puis on
				# reprend la même rue de l'autre côté.
				personne["but"] = p - n * (2.0 * TROTTOIR)
				personne["prochain"] = noeud + route * ENTRE_CARREFOURS
				fait = true
			elif tirage < POIDS_TRAVERSEE + POIDS_COIN:
				# Tourner au coin : la nouvelle rue est la perpendiculaire, et
				# l'on reste sur le trottoir du coin où l'on est.
				var r2 := droite_de(route) if _rng.randf() < 0.5 else -droite_de(route)
				var cote2 := 1 if (p - noeud).dot(droite_de(r2)) >= 0.0 else -1
				if praticable(noeud, r2, cote2):
					personne["route"] = r2
					personne["cote"] = cote2
					personne["prochain"] = noeud + r2 * ENTRE_CARREFOURS
					route = r2
					cote = cote2
					n = droite_de(route) * float(cote)
					noeud = personne["prochain"]
					fait = true
			if not fait:
				if praticable(noeud, route, cote):
					personne["prochain"] = noeud + route * ENTRE_CARREFOURS
					noeud = personne["prochain"]
				else:
					# Le trottoir s'arrête (eau, pâté fermé) : on rebrousse.
					personne["route"] = -route
					personne["prochain"] = noeud - route * ENTRE_CARREFOURS
					route = -route
					n = -n
					noeud = personne["prochain"]
		# Tenir la ligne du trottoir.
		var ecart := (noeud + n * TROTTOIR - p).dot(n)
		voulu = (route * VISEE + n * clampf(ecart, -VISEE, VISEE)).normalized()

	d = braquer(d, voulu, VITESSE_ANGULAIRE_MARCHE, delta)
	personne["d"] = d
	return allure
