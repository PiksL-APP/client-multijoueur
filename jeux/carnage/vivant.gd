class_name VilleVivante
extends RefCounted
## Tout ce qui vit dans CARNAGE et que l'HÔTE simule : les passants, les trois
## gangs, la circulation, la police, les caisses d'armes, la jauge de recherche
## et le respect.
##
## Pourquoi un seul module pour tout ça : ces populations se regardent en
## permanence. Un flic poursuit un joueur MAIS s'arrête devant une voiture ;
## un membre de gang tire sur un joueur mal vu ET fuit une berline lancée ; un
## piéton se sauve de tout le monde. Découpés en quatre fichiers, ces objets
## passeraient leur temps à se demander mutuellement leurs listes.
##
## Rien ici n'est décidé par un client : le tireur ne déclare pas ses victimes.
## Deux joueurs revendiqueraient le même passant à cent millisecondes près, et
## rien n'empêcherait un client modifié d'annoncer trente victimes par seconde.
## L'hôte tranche, diffuse, et les autres regardent.
##
## Ce module ne connaît ni la scène, ni le réseau : il produit une liste
## d'événements que `jeux/carnage.gd` diffuse et applique. C'est ce qui permet
## de le faire tourner au banc sans afficher une seule image.

# ------------------------------------------------------------ les genres

enum { PIETON, GANG, FLIC }                        ## `genre` d'un passant
enum { CIVILE, PATROUILLE, VOITURE_GANG, EPAVE }   ## `genre` d'un véhicule

const GENS_MAX := 46
const AUTOS_MAX := 18
const CAISSES_MAX := 8
const PORTEE_VUE := 1500.0        ## au-delà, on ne diffuse plus : personne ne regarde

## Une population qui naît trop loin ne menace jamais personne ; trop près,
## elle apparaît sous le capot. Entre les deux, on la voit arriver.
const NAISSANCE_MIN := 460.0
const NAISSANCE_MAX := 980.0

const RAYON_PIETON := 22.0
const RAYON_AUTO := 26.0

const VITESSE_MARCHE := 62.0
const VITESSE_FUITE := 132.0
const VITESSE_GANG := 96.0
const VITESSE_FLIC := 108.0

const PV_PIETON := 1
const PV_GANG := 3
const PV_FLIC := 4
const PV_AUTO := 100.0

## En dessous, on pousse le passant sans l'écraser : c'est le piéton qui gagne
## l'échange, et la voiture qui s'abîme.
const SEUIL_ECRASEMENT := 190.0
const SEUIL_EPERON := 80.0

const PORTEE_TIR_PNJ := 640.0
const CADENCE_TIR_PNJ := 1.15
const DEGAT_BALLE_PNJ := 9.0

## La jauge de recherche. Les crimes chauffent, le calme refroidit.
const CHALEUR := {
	"pieton": 12.0, "gang": 6.0, "flic": 52.0, "auto": 15.0,
	"coup_de_feu": 2.5, "joueur": 0.0,
}
const PALIERS := [40.0, 115.0, 230.0, 400.0, 620.0]   ## une étoile par palier franchi
const REFROIDISSEMENT := 9.0      ## points par seconde, après une accalmie
const ACCALMIE := 4.5             ## secondes sans crime avant que ça redescende

## Le respect. Nettoyer un gang fâche ce gang et arrange les deux autres.
const RESPECT_PERDU := 22.0
const RESPECT_GAGNE := 12.0
## ⚠ Le seuil vaut TROIS morts, pas un. À -30 pour 34 points perdus, abattre
## un seul passant en couleurs retournait le quartier entier contre le joueur,
## et la jauge de respect ne servait plus qu'à annoncer une catastrophe.
const RESPECT_HOSTILE := -60.0    ## en dessous, le gang tire à vue
const RESPECT_AMI := 50.0         ## au-dessus, il laisse passer

const POINTS := {
	"pieton": 10, "gang": 30, "flic": 60, "auto": 45, "joueur": 250,
}
## Les contrats. Un gang décroche son téléphone et paie pour un service rendu
## chez le voisin. C'est ce qui donne une DIRECTION à une manche : sans eux, la
## ville est un bac à sable où l'on tourne en rond jusqu'au chrono.
const DUREE_CONTRAT := {"nettoyage": 55.0, "livraison": 45.0, "chasse": 32.0}
const PRIME_CONTRAT := {"nettoyage": 260, "livraison": 300, "chasse": 340}
const RESPECT_CONTRAT := 26.0

const COMBO_FENETRE := 3.0
const COMBO_MAX := 4              ## facteur maximum = COMBO_MAX + 1

var plan: PlanVille
var gens: Array = []              ## {id,p,d,genre,gang,pv,etat,minuterie,recharge}
var autos: Array = []             ## {id,p,a,d,vitesse,genre,gang,pv,pilote,cible,minuterie}
var caisses: Array = []           ## {id,p,arme}
var barrages: Array = []          ## {id,p}
var chaleur: Dictionary = {}      ## cle -> points de recherche
var respect: Dictionary = {}      ## cle -> [respect gang 0, 1, 2]
var contrats: Dictionary = {}     ## cle -> {genre,employeur,rival,objectif,fait,reste,texte}
var sortants: Array = []          ## événements à diffuser : {"e": nom, "c": charge}

var _rng: RandomNumberGenerator
var _prochain_id := 1
var _depuis_crime: Dictionary = {}
var _combos: Dictionary = {}
var _depuis_gens := 0.0
var _depuis_autos := 0.0
var _depuis_caisse := 0.0
var _amorce := false

func _init(plan_de_ville: PlanVille, rng: RandomNumberGenerator) -> void:
	plan = plan_de_ville
	_rng = rng

func _id() -> int:
	var valeur := _prochain_id
	_prochain_id += 1
	return valeur

func emettre(nom: String, charge: Dictionary) -> void:
	sortants.append({"e": nom, "c": charge})

# ------------------------------------------------------------ recherche

func etoiles(cle: String) -> int:
	var points: float = float(chaleur.get(cle, 0.0))
	var niveau := 0
	for palier: float in PALIERS:
		if points >= palier:
			niveau += 1
	return niveau

func crime(cle: String, genre_de_crime: String) -> void:
	if cle == "":
		return
	var avant := etoiles(cle)
	chaleur[cle] = float(chaleur.get(cle, 0.0)) + float(CHALEUR.get(genre_de_crime, 0.0))
	_depuis_crime[cle] = 0.0
	if etoiles(cle) != avant:
		emettre("etoiles", {"j": cle, "r": etoiles(cle)})

## Le garage de peinture : la seule remise à zéro du jeu. Sans échappatoire,
## cinq étoiles sont une condamnation et le joueur repose la manette.
func repeindre(cle: String) -> void:
	# ⚠ La livraison se solde AVANT le garde : sans étoile au compteur, la
	# fonction sortait tout de suite et le contrat ne s'achevait jamais pour
	# qui arrivait au garage la conscience tranquille.
	_avancer_livraison(cle)
	if float(chaleur.get(cle, 0.0)) <= 0.0:
		return
	chaleur[cle] = 0.0
	_depuis_crime[cle] = 99.0
	emettre("etoiles", {"j": cle, "r": 0})
	emettre("peint", {"j": cle})

func respect_de(cle: String) -> Array:
	if not respect.has(cle):
		respect[cle] = [0.0, 0.0, 0.0]
	return respect[cle]

func gang_hostile(cle: String, gang: int) -> bool:
	return float(respect_de(cle)[posmod(gang, 3)]) <= RESPECT_HOSTILE

func gang_ami(cle: String, gang: int) -> bool:
	return float(respect_de(cle)[posmod(gang, 3)]) >= RESPECT_AMI

func _ajuster_respect(cle: String, gang: int, perte: float, gain: float) -> void:
	var jauge := respect_de(cle)
	for i in 3:
		if i == posmod(gang, 3):
			jauge[i] = clamp(float(jauge[i]) - perte, -100.0, 100.0)
		else:
			jauge[i] = clamp(float(jauge[i]) + gain, -100.0, 100.0)
	respect[cle] = jauge
	emettre("resp", {"j": cle, "v": [int(jauge[0]), int(jauge[1]), int(jauge[2])]})

# ------------------------------------------------------------ le tour d'horloge

## `joueurs` : cle -> {p, a, v, pied, vie, arene, seuil, vehicule}
func simuler(delta: float, temps: float, joueurs: Dictionary) -> void:
	_refroidir(delta, joueurs)
	_peupler(delta, temps, joueurs)
	_animer_les_gens(delta, joueurs)
	_animer_les_autos(delta, joueurs)
	_arbitrer(delta, joueurs)
	_depecher_la_police(delta, joueurs)
	_avancer_contrats(delta, joueurs)

func _refroidir(delta: float, joueurs: Dictionary) -> void:
	for cle in joueurs:
		_depuis_crime[cle] = float(_depuis_crime.get(cle, 99.0)) + delta
		if float(_depuis_crime[cle]) < ACCALMIE:
			continue
		var avant := etoiles(String(cle))
		chaleur[cle] = max(0.0, float(chaleur.get(cle, 0.0)) - REFROIDISSEMENT * delta)
		if etoiles(String(cle)) != avant:
			emettre("etoiles", {"j": cle, "r": etoiles(String(cle))})

# ------------------------------------------------------------ peuplement

func _peupler(delta: float, _temps: float, joueurs: Dictionary) -> void:
	if joueurs.is_empty():
		return
	if not _amorce:
		_amorce = true
		for i in 16:
			_naitre_passant(joueurs, true)
		for i in 8:
			_naitre_auto(joueurs, CIVILE, "")
		for i in 4:
			_poser_caisse(joueurs)

	_depuis_gens += delta
	if _depuis_gens >= 0.55 and gens.size() < GENS_MAX:
		_depuis_gens = 0.0
		_naitre_passant(joueurs, false)

	_depuis_autos += delta
	if _depuis_autos >= 2.2 and _nombre_de(CIVILE) + _nombre_de(VOITURE_GANG) < 11:
		_depuis_autos = 0.0
		_naitre_auto(joueurs, CIVILE, "")

	_depuis_caisse += delta
	if _depuis_caisse >= 7.0 and caisses.size() < CAISSES_MAX:
		_depuis_caisse = 0.0
		_poser_caisse(joueurs)

func _nombre_de(genre_cherche: int) -> int:
	var total := 0
	for a in autos:
		if int(a["genre"]) == genre_cherche:
			total += 1
	return total

func _autour_d_un_joueur(joueurs: Dictionary) -> Vector2:
	var cles := joueurs.keys()
	if cles.is_empty():
		return plan.centre()
	return joueurs[cles[_rng.randi_range(0, cles.size() - 1)]]["p"]

func _naitre_passant(joueurs: Dictionary, large: bool) -> void:
	var autour := _autour_d_un_joueur(joueurs)
	var p := plan.point_de_rue(_rng, autour,
		0.0 if large else NAISSANCE_MIN, NAISSANCE_MAX if not large else 1400.0)
	# Le territoire décide de qui traîne là : sur les terres d'un gang, un
	# passant sur trois en porte les couleurs. C'est ce qui fait qu'une bande
	# de ville a une identité sans qu'on ait à la nommer.
	var gang := plan.territoire(p)
	var genre := PIETON
	if _rng.randf() < 0.34:
		genre = GANG
	gens.append({
		"id": _id(), "p": p, "d": Vector2.RIGHT.rotated(_rng.randf() * TAU),
		"genre": genre, "gang": gang, "pv": PV_GANG if genre == GANG else PV_PIETON,
		"etat": 0, "minuterie": _rng.randf_range(1.0, 3.5), "recharge": 0.0, "a": 0.0,
	})

func _naitre_auto(joueurs: Dictionary, genre: int, cible: String) -> void:
	if autos.size() >= AUTOS_MAX:
		return
	var autour := _autour_d_un_joueur(joueurs)
	if cible != "" and joueurs.has(cible):
		autour = joueurs[cible]["p"]
	var pose := plan.point_de_chaussee(_rng, autour, NAISSANCE_MIN, NAISSANCE_MAX)
	var direction: Vector2 = pose["d"]
	# Une berline sur quatre porte les couleurs du quartier : c'est ce qui fait
	# qu'on hésite avant de tirer dans le tas sur le territoire d'un gang avec
	# lequel on est en bons termes.
	if genre == CIVILE and _rng.randf() < 0.25:
		genre = VOITURE_GANG
	autos.append({
		"id": _id(), "p": pose["p"], "a": direction.angle(), "d": direction,
		"vitesse": 0.0, "genre": genre, "gang": plan.territoire(pose["p"]),
		"pv": PV_AUTO, "pilote": "", "cible": cible, "minuterie": 0.0, "recharge": 0.0,
	})

func _poser_caisse(joueurs: Dictionary) -> void:
	var noms := ["mitraillette", "roquette", "eperon"]
	var arme := String(noms[_rng.randi_range(0, noms.size() - 1)])
	var p := plan.point_de_rue(_rng, _autour_d_un_joueur(joueurs), 260.0, 1200.0)
	caisses.append({"id": _id(), "p": p, "arme": arme})

func retirer_caisse(id: int) -> String:
	for c in caisses:
		if int(c["id"]) == id:
			var arme := String(c["arme"])
			caisses.erase(c)
			return arme
	return ""

# ------------------------------------------------------------ les passants

func _menace_la_plus_proche(depuis: Vector2, joueurs: Dictionary, rayon: float) -> Dictionary:
	var meilleure := {}
	var distance := rayon * rayon
	for cle in joueurs:
		var j: Dictionary = joueurs[cle]
		if float(j.get("vie", 100.0)) <= 0.0:
			continue
		var d: float = depuis.distance_squared_to(j["p"])
		if d < distance:
			distance = d
			meilleure = {"cle": String(cle), "p": j["p"], "pied": bool(j.get("pied", true))}
	return meilleure

func _animer_les_gens(delta: float, joueurs: Dictionary) -> void:
	for personne in gens:
		personne["recharge"] = max(0.0, float(personne["recharge"]) - delta)
		personne["minuterie"] = float(personne["minuterie"]) - delta

		var genre := int(personne["genre"])
		var vitesse := VITESSE_MARCHE
		var direction: Vector2 = personne["d"]
		var proche := _menace_la_plus_proche(personne["p"], joueurs, 520.0)

		if genre == FLIC:
			vitesse = VITESSE_FLIC
			var proie := _proie_de_la_police(personne["p"], joueurs)
			if not proie.is_empty():
				direction = (Vector2(proie["p"]) - personne["p"]).normalized()
				_tirer_sur(personne, proie, delta)
			elif float(personne["minuterie"]) <= 0.0:
				personne["minuterie"] = _rng.randf_range(1.4, 3.0)
				direction = Vector2.RIGHT.rotated(_rng.randf() * TAU)
		elif genre == GANG and not proche.is_empty() and gang_hostile(String(proche["cle"]), int(personne["gang"])):
			# Fâché : il charge et il tire. Un gang qu'on a saigné ne se
			# contente pas de bouder — sinon la jauge de respect ne se sent
			# jamais.
			vitesse = VITESSE_GANG
			direction = (Vector2(proche["p"]) - personne["p"]).normalized()
			_tirer_sur(personne, proche, delta)
		elif not proche.is_empty() and not bool(proche["pied"]) \
				and Vector2(proche["p"]).distance_to(personne["p"]) < 300.0:
			# Une voiture qui fond sur vous : on court, et on court DROIT
			# devant elle. Fuir perpendiculairement serait plus malin et
			# beaucoup moins drôle.
			vitesse = VITESSE_FUITE
			direction = (personne["p"] - Vector2(proche["p"])).normalized()
			personne["etat"] = 1
		else:
			personne["etat"] = 0
			if float(personne["minuterie"]) <= 0.0:
				personne["minuterie"] = _rng.randf_range(1.2, 4.0)
				direction = Vector2.RIGHT.rotated(_rng.randf() * TAU)

		var suivant: Vector2 = personne["p"] + direction * vitesse * delta
		var degage := plan.degager(suivant, RAYON_PIETON)
		if bool(degage[1]):
			# Un mur : on rebrousse plutôt que de gratter la façade. Un piéton
			# collé à un immeuble pendant deux minutes se voit tout de suite.
			direction = -direction
			suivant = degage[0]
		personne["p"] = suivant
		personne["d"] = direction
		personne["a"] = direction.angle()

func _proie_de_la_police(depuis: Vector2, joueurs: Dictionary) -> Dictionary:
	var meilleure := {}
	var distance := 900.0 * 900.0
	for cle in joueurs:
		if etoiles(String(cle)) <= 0:
			continue
		var j: Dictionary = joueurs[cle]
		if float(j.get("vie", 100.0)) <= 0.0:
			continue
		var d: float = depuis.distance_squared_to(j["p"])
		if d < distance:
			distance = d
			meilleure = {"cle": String(cle), "p": j["p"], "pied": bool(j.get("pied", true))}
	return meilleure

func _tirer_sur(tireur: Dictionary, proie: Dictionary, _delta: float) -> void:
	if float(tireur["recharge"]) > 0.0:
		return
	var vers: Vector2 = Vector2(proie["p"]) - Vector2(tireur["p"])
	if vers.length() > PORTEE_TIR_PNJ:
		return
	tireur["recharge"] = CADENCE_TIR_PNJ * _rng.randf_range(0.8, 1.4)
	var angle := vers.angle()
	emettre("tn", {"x": int(tireur["p"].x), "y": int(tireur["p"].y), "a": snapped(angle, 0.01)})
	# La balle d'un PNJ ne vole pas : elle touche ou elle rate, tiré au sort
	# selon la distance. Faire voler quatre-vingts projectiles de plus, c'est
	# quatre-vingts objets à diffuser pour un résultat que personne ne suit
	# à l'œil dans une rue de nuit.
	# Sept balles sur dix qui portent, avec quatre tireurs, c'est une mort
	# toutes les trois secondes à pied : on ne sortait plus de voiture.
	var chance: float = clamp(1.0 - vers.length() / PORTEE_TIR_PNJ, 0.10, 0.46)
	if _rng.randf() < chance:
		emettre("deg", {"j": proie["cle"], "d": int(DEGAT_BALLE_PNJ), "k": "balle"})

# ------------------------------------------------------------ la circulation

func _animer_les_autos(delta: float, joueurs: Dictionary) -> void:
	var restantes: Array = []
	for auto in autos:
		if String(auto["pilote"]) != "":
			# Conduite par un joueur : c'est SON client qui la simule et la
			# diffuse. L'hôte n'y touche plus, sinon la voiture se bat contre
			# les touches de celui qui est dedans.
			restantes.append(auto)
			continue

		if int(auto["genre"]) == EPAVE:
			auto["minuterie"] = float(auto["minuterie"]) - delta
			if float(auto["minuterie"]) > 0.0:
				restantes.append(auto)
			else:
				var carcasse = auto.get("noeud")
				if carcasse != null:
					(carcasse as Node3D).queue_free()
			continue

		if int(auto["genre"]) == PATROUILLE:
			_conduire_patrouille(auto, delta, joueurs)
		else:
			_conduire_civile(auto, delta)
		restantes.append(auto)
	autos = restantes

## Une voiture civile suit sa file et tourne aux carrefours. Elle ne cherche
## pas d'itinéraire : dans une grille, un tirage au sort à chaque croisement
## produit un trafic qui a l'air d'aller quelque part.
func _conduire_civile(auto: Dictionary, delta: float) -> void:
	var direction: Vector2 = auto["d"]
	auto["vitesse"] = move_toward(float(auto["vitesse"]), 250.0, 320.0 * delta)
	var suivant: Vector2 = auto["p"] + direction * float(auto["vitesse"]) * delta

	# Devant un mur, on tourne au prochain carrefour plutôt que de s'y écraser.
	if plan.dans_un_batiment(suivant + direction * 60.0, RAYON_AUTO):
		direction = Vector2(-direction.y, direction.x) if _rng.randf() < 0.5 \
			else Vector2(direction.y, -direction.x)
		auto["d"] = direction
		auto["vitesse"] = float(auto["vitesse"]) * 0.4
		suivant = plan.carrefour_proche(auto["p"])
	elif _rng.randf() < delta * 0.55:
		# De temps à autre, on prend la perpendiculaire : sans ça, tout le
		# trafic finit aligné sur deux avenues.
		var carrefour := plan.carrefour_proche(auto["p"])
		if Vector2(auto["p"]).distance_to(carrefour) < 46.0:
			direction = Vector2(-direction.y, direction.x) if _rng.randf() < 0.5 \
				else Vector2(direction.y, -direction.x)
			auto["d"] = direction
			suivant = carrefour

	var degage := plan.degager(suivant, RAYON_AUTO)
	auto["p"] = degage[0]
	auto["a"] = direction.angle()

## Une patrouille ne suit pas les files : elle coupe. C'est ce qui fait qu'on
## ne la sème pas en tournant deux fois à droite.
func _conduire_patrouille(auto: Dictionary, delta: float, joueurs: Dictionary) -> void:
	var cible := String(auto["cible"])
	if not joueurs.has(cible) or etoiles(cible) <= 0:
		# Plus recherché : la patrouille reprend une conduite ordinaire et
		# finira par se faire oublier.
		auto["genre"] = CIVILE
		return
	var vers: Vector2 = Vector2(joueurs[cible]["p"]) - Vector2(auto["p"])
	var direction := vers.normalized()
	var allure: float = 300.0 + 42.0 * float(etoiles(cible))
	auto["vitesse"] = move_toward(float(auto["vitesse"]), allure, 420.0 * delta)
	var suivant: Vector2 = auto["p"] + direction * float(auto["vitesse"]) * delta
	var degage := plan.degager(suivant, RAYON_AUTO)
	if bool(degage[1]):
		# Contre un mur, elle longe : une voiture de police coincée dans un
		# angle pendant toute la manche, c'est une menace en moins et un
		# défaut visible.
		var tangente := Vector2(-direction.y, direction.x)
		suivant = plan.degager(Vector2(auto["p"]) + tangente * float(auto["vitesse"]) * delta, RAYON_AUTO)[0]
		auto["vitesse"] = float(auto["vitesse"]) * 0.8
	else:
		suivant = degage[0]
	auto["p"] = suivant
	auto["d"] = direction
	auto["a"] = direction.angle()

# ------------------------------------------------------------ la police

func _depecher_la_police(delta: float, joueurs: Dictionary) -> void:
	for cle in joueurs:
		var niveau := etoiles(String(cle))
		if niveau <= 0:
			continue
		var j: Dictionary = joueurs[cle]
		if float(j.get("vie", 100.0)) <= 0.0:
			continue

		var patrouilles := 0
		for auto in autos:
			if int(auto["genre"]) == PATROUILLE and String(auto["cible"]) == cle:
				patrouilles += 1
		if patrouilles < niveau and _rng.randf() < delta * 1.2:
			_naitre_auto(joueurs, PATROUILLE, String(cle))

		# À deux étoiles, la police descend de voiture.
		if niveau >= 2 and gens.size() < GENS_MAX and _rng.randf() < delta * 0.6 * float(niveau - 1):
			var p := plan.point_de_rue(_rng, j["p"], 420.0, 760.0)
			gens.append({
				"id": _id(), "p": p, "d": Vector2.RIGHT, "genre": FLIC, "gang": -1,
				"pv": PV_FLIC, "etat": 0, "minuterie": 0.0, "recharge": 0.0, "a": 0.0,
			})

		# À quatre étoiles, on ferme les rues.
		if niveau >= 4 and barrages.size() < 5 and _rng.randf() < delta * 0.5:
			var carrefour := plan.carrefour_proche(Vector2(j["p"]) + Vector2(j.get("d", Vector2.RIGHT)) * 700.0)
			var libre := true
			for b in barrages:
				if Vector2(b["p"]).distance_to(carrefour) < 200.0:
					libre = false
			if libre:
				barrages.append({"id": _id(), "p": carrefour})

# ------------------------------------------------------------ l'arbitrage

## Le seul endroit du jeu où l'on décide qui meurt. L'hôte y voit tout le monde
## à la même date, ce qu'aucun client ne peut faire.
func _arbitrer(_delta: float, joueurs: Dictionary) -> void:
	_arbitrer_les_passants(joueurs)
	_arbitrer_les_autos(joueurs)
	_arbitrer_les_joueurs(joueurs)
	_arbitrer_les_barrages(joueurs)

func _arbitrer_les_passants(joueurs: Dictionary) -> void:
	var fauches: Array = []
	for personne in gens:
		for cle in joueurs:
			var j: Dictionary = joueurs[cle]
			if float(j.get("vie", 100.0)) <= 0.0 or bool(j.get("pied", true)):
				continue
			if Vector2(personne["p"]).distance_to(j["p"]) > RAYON_PIETON + RAYON_AUTO:
				continue
			if abs(float(j.get("v", 0.0))) >= float(j.get("seuil", SEUIL_ECRASEMENT)):
				fauches.append([personne, String(cle)])
			else:
				# Trop lent : le passant s'écarte, la voiture se raye.
				emettre("deg", {"j": cle, "d": 6, "k": "choc"})
				personne["p"] = Vector2(personne["p"]) \
					+ (Vector2(personne["p"]) - Vector2(j["p"])).normalized() * 60.0
			break
	for couple in fauches:
		_abattre(couple[0], String(couple[1]), true)

func _arbitrer_les_autos(joueurs: Dictionary) -> void:
	for auto in autos:
		if int(auto["genre"]) == EPAVE or String(auto["pilote"]) != "":
			continue
		for cle in joueurs:
			var j: Dictionary = joueurs[cle]
			if bool(j.get("pied", true)) or float(j.get("vie", 100.0)) <= 0.0:
				continue
			var ecart: float = Vector2(auto["p"]).distance_to(j["p"])
			if ecart > RAYON_AUTO * 2.0:
				continue
			var choc: float = abs(float(j.get("v", 0.0)))
			auto["pv"] = float(auto["pv"]) - choc * 0.06
			emettre("deg", {"j": cle, "d": int(choc * 0.02), "k": "tole"})
			# On se repousse : deux carrosseries qui s'interpénètrent finissent
			# par se catapulter, et ça, ça se voit.
			auto["p"] = Vector2(auto["p"]) + (Vector2(auto["p"]) - Vector2(j["p"])).normalized() * 26.0
			if float(auto["pv"]) <= 0.0:
				detruire_auto(auto, String(cle))
			break

## Le tir ami n'existe QUE dans une arène, et seulement si les deux y sont.
## Ailleurs, la ville se joue à plusieurs contre elle : un joueur qui peut
## tuer un coéquipier n'importe où transforme la coopération en méfiance.
func _arbitrer_les_joueurs(joueurs: Dictionary) -> void:
	var cles := joueurs.keys()
	for i in cles.size():
		for k in range(i + 1, cles.size()):
			var a: Dictionary = joueurs[cles[i]]
			var b: Dictionary = joueurs[cles[k]]
			if int(a.get("arene", -1)) < 0 or int(a.get("arene", -1)) != int(b.get("arene", -2)):
				continue
			if Vector2(a["p"]).distance_to(b["p"]) > RAYON_AUTO * 2.0:
				continue
			var va: float = abs(float(a.get("v", 0.0)))
			var vb: float = abs(float(b.get("v", 0.0)))
			# Celui qui va le plus vite embrase l'autre. À vitesse égale, les
			# deux prennent : un face-à-face ne doit pas être gratuit.
			if va > vb + 60.0:
				emettre("deg", {"j": cles[k], "d": int(va * 0.06), "k": "joueur", "par": cles[i]})
			elif vb > va + 60.0:
				emettre("deg", {"j": cles[i], "d": int(vb * 0.06), "k": "joueur", "par": cles[k]})
			else:
				emettre("deg", {"j": cles[i], "d": 12, "k": "joueur", "par": cles[k]})
				emettre("deg", {"j": cles[k], "d": 12, "k": "joueur", "par": cles[i]})

func _arbitrer_les_barrages(joueurs: Dictionary) -> void:
	for b in barrages:
		for cle in joueurs:
			var j: Dictionary = joueurs[cle]
			if bool(j.get("pied", true)):
				continue
			if Vector2(b["p"]).distance_to(j["p"]) < 90.0:
				emettre("deg", {"j": cle, "d": 24, "k": "barrage"})

# ------------------------------------------------------------ la mort

func abattre_par_id(id: int, cle: String, souffle: float) -> bool:
	var touche := {}
	for personne in gens:
		if int(personne["id"]) == id:
			touche = personne
			break
	if touche.is_empty():
		return false
	var groupe: Array = [touche]
	if souffle > 0.0:
		groupe = []
		for personne in gens:
			if Vector2(personne["p"]).distance_to(touche["p"]) <= souffle:
				groupe.append(personne)
	for personne in groupe:
		personne["pv"] = int(personne["pv"]) - (3 if souffle > 0.0 else 1)
		if int(personne["pv"]) <= 0:
			_abattre(personne, cle, false)
	return true

## Retire un objet de sa liste par IDENTIFIANT, et libère son maillage. Deux
## dictionnaires au même contenu se ressemblent trop pour qu'`erase` soit sûr,
## et un maillage oublié laisse un fantôme immobile que plus rien ne référence.
static func retirer(liste: Array, id: int) -> bool:
	for i in liste.size():
		if int(liste[i]["id"]) != id:
			continue
		var noeud = liste[i].get("noeud")
		if noeud != null:
			(noeud as Node3D).queue_free()
		liste.remove_at(i)
		return true
	return false

func _abattre(personne: Dictionary, cle: String, ecrase: bool) -> void:
	if not retirer(gens, int(personne["id"])):
		return
	var genre := int(personne["genre"])
	var quoi := "pieton"
	if genre == GANG:
		quoi = "gang"
	elif genre == FLIC:
		quoi = "flic"
	crime(cle, quoi)
	if genre == GANG:
		_ajuster_respect(cle, int(personne["gang"]), RESPECT_PERDU, RESPECT_GAGNE)
		_avancer_nettoyage(cle, int(personne["gang"]))
	_compter(cle, Vector2(personne["p"]), int(POINTS[quoi]), quoi, ecrase)

func detruire_auto(auto: Dictionary, cle: String) -> void:
	if int(auto["genre"]) == VOITURE_GANG:
		# Brûler la voiture d'un gang, ça se retient aussi longtemps qu'un
		# mort : sans ça, on ferait le vide dans un quartier au lance-roquettes
		# sans jamais fâcher personne.
		_ajuster_respect(cle, int(auto.get("gang", 0)), RESPECT_PERDU * 0.6, RESPECT_GAGNE * 0.5)
	auto["genre"] = EPAVE
	auto["minuterie"] = 7.0
	auto["vitesse"] = 0.0
	crime(cle, "auto")
	_compter(cle, Vector2(auto["p"]), int(POINTS["auto"]), "auto", false)
	emettre("boum", {"x": int(auto["p"].x), "y": int(auto["p"].y)})

## Les enchaînements. C'est le seul endroit où le jeu récompense le rythme
## plutôt que la précision — sans lui, la meilleure façon de marquer serait de
## rouler au pas en tirant, ce qui n'est amusant pour personne.
func _compter(cle: String, ou: Vector2, base: int, quoi: String, avec_combo: bool) -> void:
	if cle == "":
		return
	var facteur := 1
	if avec_combo:
		var combo: Dictionary = _combos.get(cle, {"dernier": -99.0, "facteur": 0})
		var maintenant := float(Time.get_ticks_msec()) / 1000.0
		if maintenant - float(combo["dernier"]) <= COMBO_FENETRE:
			combo["facteur"] = min(int(combo["facteur"]) + 1, COMBO_MAX)
		else:
			combo["facteur"] = 0
		combo["dernier"] = maintenant
		_combos[cle] = combo
		facteur = int(combo["facteur"]) + 1
	emettre("k", {
		"j": cle, "x": int(ou.x), "y": int(ou.y),
		"p": base * facteur, "f": facteur, "q": quoi,
	})

## Élimination d'un joueur par un autre, en arène. Passe par le même chemin
## que le reste pour que le tableau et les effets soient identiques.
func compter_frag(cle: String, ou: Vector2) -> void:
	_compter(cle, ou, int(POINTS["joueur"]), "joueur", false)

# ------------------------------------------------------------ les contrats

## Décrocher à une cabine. Le gang qui appelle est celui dont c'est le
## territoire : une cabine chez Le Lierre ne fait jamais travailler pour Les
## Braises, sinon le respect n'a plus de sens géographique.
func proposer_contrat(cle: String, cabine: int, position: Vector2) -> void:
	if cle == "" or contrats.has(cle):
		return
	var employeur := posmod(cabine, 3)
	var rival := posmod(employeur + 1 + _rng.randi_range(0, 1), 3)
	var tirage := _rng.randf()
	var genre := "nettoyage"
	var objectif := 3 + _rng.randi_range(0, 2)
	var texte := ""
	if tirage < 0.36:
		texte = "%s veut la peau de %d gars %s" % [
			plan.nom_du_gang(employeur), objectif, plan.du_gang(rival)]
	elif tirage < 0.70:
		genre = "livraison"
		objectif = 1
		texte = "%s veut cette voiture repeinte, et vite" % plan.nom_du_gang(employeur)
	else:
		genre = "chasse"
		objectif = 2
		texte = "%s paie si vous tenez %d étoiles jusqu'au bout" % [
			plan.nom_du_gang(employeur), objectif]

	contrats[cle] = {
		"genre": genre, "employeur": employeur, "rival": rival,
		"objectif": objectif, "fait": 0.0, "reste": float(DUREE_CONTRAT[genre]),
		"texte": texte, "p": position,
	}
	_diffuser_contrat(cle, "pris")

func _diffuser_contrat(cle: String, etat: String) -> void:
	var c: Dictionary = contrats.get(cle, {})
	emettre("ctr", {
		"j": cle, "e": etat,
		"t": String(c.get("texte", "")), "n": int(c.get("objectif", 0)),
		"a": int(c.get("fait", 0.0)), "r": int(ceil(float(c.get("reste", 0.0)))),
	})

func _avancer_contrats(delta: float, joueurs: Dictionary) -> void:
	for cle in contrats.keys():
		var c: Dictionary = contrats[cle]
		c["reste"] = float(c["reste"]) - delta
		if joueurs.has(cle):
			c["p"] = joueurs[cle]["p"]

		if String(c["genre"]) == "chasse":
			# Tenir ses étoiles, c'est un compte à rebours qu'on remonte : la
			# jauge de recherche redescend toute seule, il faut donc continuer
			# à faire des bêtises pour rester payé.
			if etoiles(String(cle)) >= int(c["objectif"]):
				c["fait"] = float(c["fait"]) + delta
			if float(c["fait"]) >= float(DUREE_CONTRAT["chasse"]) * 0.6:
				_solder_contrat(String(cle), true)
				continue

		if float(c["reste"]) <= 0.0:
			_solder_contrat(String(cle), false)

## Un contrat gagné paie en argent ET en respect : c'est la seule façon de
## remonter une jauge qu'on a fait plonger en écrasant tout un pâté de maisons.
func _solder_contrat(cle: String, gagne: bool) -> void:
	var c: Dictionary = contrats.get(cle, {})
	if c.is_empty():
		return
	var position: Vector2 = c.get("p", plan.centre())
	contrats.erase(cle)
	if gagne:
		_compter(cle, position, int(PRIME_CONTRAT[String(c["genre"])]), "contrat", false)
		# Une perte NÉGATIVE remonte la jauge de l'employeur sans toucher aux
		# deux autres : rendre service à un gang ne fâche pas ses voisins.
		_ajuster_respect(cle, int(c["employeur"]), -RESPECT_CONTRAT, 0.0)
	emettre("ctr", {"j": cle, "e": "gagne" if gagne else "perdu",
		"t": String(c.get("texte", "")), "n": 0, "a": 0, "r": 0})

func _avancer_nettoyage(cle: String, gang: int) -> void:
	var c: Dictionary = contrats.get(cle, {})
	if c.is_empty() or String(c["genre"]) != "nettoyage" or int(c["rival"]) != gang:
		return
	c["fait"] = float(c["fait"]) + 1.0
	if float(c["fait"]) >= float(c["objectif"]):
		_solder_contrat(cle, true)
	else:
		_diffuser_contrat(cle, "avance")

func _avancer_livraison(cle: String) -> void:
	var c: Dictionary = contrats.get(cle, {})
	if c.is_empty() or String(c["genre"]) != "livraison":
		return
	_solder_contrat(cle, true)

# ------------------------------------------------------------ les véhicules

func auto_par_id(id: int) -> Dictionary:
	for auto in autos:
		if int(auto["id"]) == id:
			return auto
	return {}

## Le vol de voiture est arbitré par l'hôte : sans ça, deux joueurs arrivés à
## cent millisecondes d'intervalle repartent chacun avec la même berline, et
## chacun voit l'autre rouler dans le vide.
func accorder_vehicule(cle: String, id: int, position: Vector2) -> void:
	var auto := auto_par_id(id)
	if auto.is_empty() or String(auto["pilote"]) != "" or int(auto["genre"]) == EPAVE:
		return
	if Vector2(auto["p"]).distance_to(position) > 120.0:
		return
	auto["pilote"] = cle
	if int(auto["genre"]) == PATROUILLE:
		# Voler une voiture de police, ça se paie.
		crime(cle, "pieton")
	emettre("pris", {"j": cle, "id": id, "g": int(auto["genre"]),
		"x": int(auto["p"].x), "y": int(auto["p"].y), "a": snapped(float(auto["a"]), 0.01),
		"pv": int(auto["pv"])})

func rendre_vehicule(cle: String, id: int, position: Vector2, angle: float, pv: float) -> void:
	var auto := auto_par_id(id)
	if auto.is_empty():
		# L'hôte a changé en cours de route et ne connaît plus cette voiture :
		# on la réinscrit plutôt que de la faire disparaître sous le joueur.
		autos.append({
			"id": id, "p": position, "a": angle, "d": Vector2.RIGHT.rotated(angle),
			"vitesse": 0.0, "genre": CIVILE, "gang": plan.territoire(position),
			"pv": pv, "pilote": "", "cible": "", "minuterie": 0.0, "recharge": 0.0,
		})
		return
	if String(auto["pilote"]) != cle:
		return
	auto["pilote"] = ""
	auto["p"] = position
	auto["a"] = angle
	auto["d"] = Vector2.RIGHT.rotated(angle)
	auto["pv"] = pv
	auto["vitesse"] = 0.0
	# Rendue en morceaux : elle finit sa vie en carcasse. La remettre en
	# circulation avec zéro point de tôle donnerait une voiture qui explose au
	# premier trottoir sans que personne comprenne pourquoi.
	if pv <= 0.0:
		auto["genre"] = EPAVE
		auto["minuterie"] = 7.0

## Le véhicule libre le plus proche : c'est ce que le client interroge quand on
## appuie sur ENTRER, et l'hôte revérifie avant d'accorder.
func vehicule_proche(position: Vector2, rayon: float) -> Dictionary:
	var meilleur := {}
	var distance := rayon * rayon
	for auto in autos:
		if String(auto["pilote"]) != "" or int(auto["genre"]) == EPAVE:
			continue
		var d: float = Vector2(auto["p"]).distance_squared_to(position)
		if d < distance:
			distance = d
			meilleur = auto
	return meilleur

# ------------------------------------------------------------ diffusion

## L'instantané. Il ne porte QUE ce qui est à portée de vue d'un joueur : une
## ville pleine diffusée en entier, c'est vingt-cinq kilo-octets par seconde
## pour des passants que personne ne regarde.
func instantane(joueurs: Dictionary) -> Dictionary:
	var vus_gens: Array = []
	for personne in gens:
		if not _regarde(personne["p"], joueurs):
			continue
		vus_gens.append([int(personne["id"]), int(personne["p"].x), int(personne["p"].y),
			int(personne["genre"]), int(personne["gang"]), int(personne["pv"]),
			int(float(personne["a"]) * 100.0)])

	var vus_autos: Array = []
	for auto in autos:
		if String(auto["pilote"]) != "" or not _regarde(auto["p"], joueurs):
			continue
		vus_autos.append([int(auto["id"]), int(auto["p"].x), int(auto["p"].y),
			int(float(auto["a"]) * 100.0), int(auto["genre"]), int(auto["pv"])])

	var vues_caisses: Array = []
	for c in caisses:
		vues_caisses.append([int(c["id"]), int(c["p"].x), int(c["p"].y), String(c["arme"])])

	var vus_barrages: Array = []
	for b in barrages:
		vus_barrages.append([int(b["id"]), int(b["p"].x), int(b["p"].y)])

	var etats: Dictionary = {}
	for cle in joueurs:
		etats[cle] = [etoiles(String(cle)),
			int(respect_de(String(cle))[0]), int(respect_de(String(cle))[1]),
			int(respect_de(String(cle))[2])]

	return {"g": vus_gens, "a": vus_autos, "c": vues_caisses, "b": vus_barrages, "e": etats}

func _regarde(point: Vector2, joueurs: Dictionary) -> bool:
	for cle in joueurs:
		if Vector2(joueurs[cle]["p"]).distance_to(point) <= PORTEE_VUE:
			return true
	return false

## Si l'hôte précédent est parti, celui qui reprend hérite d'objets reçus par
## instantané : ils ont une position et un genre, pas de vitesse ni de points
## de vie. Sans cette remise en état, la ville resterait figée — un troupeau
## de statues et un trafic à l'arrêt.
func reprendre_la_main() -> void:
	for personne in gens:
		if not personne.has("minuterie"):
			personne["minuterie"] = 0.0
		if not personne.has("recharge"):
			personne["recharge"] = 0.0
		if not personne.has("d") or Vector2(personne["d"]) == Vector2.ZERO:
			personne["d"] = Vector2.RIGHT.rotated(_rng.randf() * TAU)
		_prochain_id = max(_prochain_id, int(personne["id"]) + 1)
	for auto in autos:
		if not auto.has("d") or Vector2(auto["d"]) == Vector2.ZERO:
			auto["d"] = Vector2.RIGHT.rotated(float(auto["a"]))
		if not auto.has("cible"):
			auto["cible"] = ""
		if not auto.has("pilote"):
			auto["pilote"] = ""
		if not auto.has("minuterie"):
			auto["minuterie"] = 0.0
		_prochain_id = max(_prochain_id, int(auto["id"]) + 1)
	for c in caisses:
		_prochain_id = max(_prochain_id, int(c["id"]) + 1)
	# ⚠ On ne déclare la ville amorcée que s'il y a VRAIMENT quelque chose à
	# reprendre : cette fonction est appelée à chaque image, et poser le
	# drapeau à vide empêcherait le premier peuplement de la manche.
	if not gens.is_empty() or not autos.is_empty():
		_amorce = true

## Côté client : on remplace listes et jauges par ce que l'hôte vient de dire.
## Ce qui n'est plus dans l'instantané a disparu — le garder à l'écran, c'est
## laisser des fantômes intouchables au milieu de la rue.
func appliquer_instantane(charge: Dictionary) -> void:
	gens = _fusionner(gens, charge.get("g", []), func(entree: Array) -> Dictionary:
		return {"id": int(entree[0]), "p": Vector2(float(entree[1]), float(entree[2])),
			"cible": Vector2(float(entree[1]), float(entree[2])),
			"genre": int(entree[3]), "gang": int(entree[4]), "pv": int(entree[5]),
			"a": float(entree[6]) / 100.0, "d": Vector2.RIGHT, "etat": 0,
			"minuterie": 0.0, "recharge": 0.0})
	autos = _fusionner(autos, charge.get("a", []), func(entree: Array) -> Dictionary:
		return {"id": int(entree[0]), "p": Vector2(float(entree[1]), float(entree[2])),
			"cible_p": Vector2(float(entree[1]), float(entree[2])),
			"a": float(entree[3]) / 100.0, "genre": int(entree[4]), "pv": float(entree[5]),
			"d": Vector2.RIGHT, "vitesse": 0.0, "pilote": "", "cible": "", "minuterie": 0.0})
	caisses = _fusionner(caisses, charge.get("c", []), func(entree: Array) -> Dictionary:
		return {"id": int(entree[0]), "p": Vector2(float(entree[1]), float(entree[2])),
			"arme": String(entree[3])})
	barrages = _fusionner(barrages, charge.get("b", []), func(entree: Array) -> Dictionary:
		return {"id": int(entree[0]), "p": Vector2(float(entree[1]), float(entree[2]))})

	var etats = charge.get("e", {})
	if typeof(etats) == TYPE_DICTIONARY:
		for cle in etats:
			var valeurs = etats[cle]
			if typeof(valeurs) == TYPE_ARRAY and (valeurs as Array).size() >= 4:
				chaleur[cle] = chaleur_pour(int(valeurs[0]))
				respect[cle] = [float(valeurs[1]), float(valeurs[2]), float(valeurs[3])]

## Le client ne reçoit que le NOMBRE d'étoiles, pas la chaleur : il lui suffit
## d'en avoir une valeur qui affiche le bon compte.
func chaleur_pour(niveau: int) -> float:
	if niveau <= 0:
		return 0.0
	return float(PALIERS[min(niveau, PALIERS.size()) - 1])

func _fusionner(existants: Array, recus, fabrique: Callable) -> Array:
	if typeof(recus) != TYPE_ARRAY:
		return existants
	var connus: Dictionary = {}
	for objet in existants:
		connus[int(objet["id"])] = objet
	var gardes: Array = []
	var vus: Dictionary = {}
	for entree in recus:
		if typeof(entree) != TYPE_ARRAY:
			continue
		var id := int((entree as Array)[0])
		vus[id] = true
		if connus.has(id):
			var objet: Dictionary = connus[id]
			var neuf: Dictionary = fabrique.call(entree)
			# On garde le nœud 3D et on ne déplace que la CIBLE : la position
			# affichée glisse vers elle image par image, sinon un instantané
			# à huit par seconde donne une ville qui saute.
			for champ in ["genre", "gang", "pv", "a", "arme"]:
				if neuf.has(champ):
					objet[champ] = neuf[champ]
			objet["cible"] = neuf["p"]
			gardes.append(objet)
		else:
			gardes.append(fabrique.call(entree))
	for objet in existants:
		if not vus.has(int(objet["id"])):
			var noeud = objet.get("noeud")
			if noeud != null:
				(noeud as Node3D).queue_free()
	return gardes
