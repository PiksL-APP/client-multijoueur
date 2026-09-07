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

const GENS_MAX := 90
const AUTOS_MOBILES_MAX := 26   ## celles qui roulent ; les garées ne comptent pas
const PAR_REPAIRE := 5          ## gars qui traînent à un repaire
const CAISSES_MAX := 8
const PORTEE_VUE := 1600.0        ## au-delà, on ne diffuse plus : personne ne regarde

## Une population qui naît trop loin ne menace jamais personne ; trop près,
## elle apparaît sous le capot. Entre les deux, on la voit arriver.
const NAISSANCE_MIN := 460.0
const NAISSANCE_MAX := 980.0

const RAYON_PIETON := 22.0
const RAYON_AUTO := 26.0
## Distance de CHOC entre deux voitures. Pas deux rayons : une voiture fait
## seize pixels de demi-largeur, et les voies sont à cinquante pixels l'une de
## l'autre. À cinquante-deux, deux voitures qui se croisent en sens inverse se
## percutaient sans se toucher, et on cabossait la sienne en longeant les
## voitures garées.
const CHOC_AUTO := 38.0

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

## La circulation roule à DROITE, à trente-deux pixels de l'axe. Au centre de la
## chaussée, deux voitures qui se croisent se traversaient ; et sans file, rien
## ne dit dans quel sens va une rue.
const FILE := 32.0
const VITESSE_TRAFIC := 250.0
const DISTANCE_FREIN := 130.0     ## on s'arrête derrière ce qu'on a devant
const KLAXON_APRES := 0.7         ## secondes à l'arrêt avant de klaxonner

## L'hélicoptère, à cinq étoiles : il ne se sème pas, il se repeint.
const VITESSE_HELICO := 430.0
const DEGAT_HELICO := 13.0
const CADENCE_HELICO := 0.75
const PORTEE_HELICO := 420.0

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
var helicos: Array = []           ## {id,p,cible,recharge} — un par joueur à cinq étoiles
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

## Un coup de feu, un klaxon : les passants à portée décampent. C'est la moitié
## de ce qui rend une rue vivante — l'autre moitié, c'est qu'ils y reviennent.
func paniquer(autour: Vector2, rayon: float, duree: float) -> void:
	for personne in gens:
		if int(personne["genre"]) != PIETON:
			continue
		var ecart: Vector2 = Vector2(personne["p"]) - autour
		if ecart.length() > rayon:
			continue
		personne["etat"] = 1
		personne["fuite"] = duree * _rng.randf_range(0.7, 1.3)
		personne["d"] = ecart.normalized() if ecart != Vector2.ZERO else Vector2.RIGHT.rotated(_rng.randf() * TAU)

# ------------------------------------------------------------ le tour d'horloge

## `joueurs` : cle -> {p, a, v, pied, vie, arene, seuil, vehicule}
func simuler(delta: float, temps: float, joueurs: Dictionary) -> void:
	_refroidir(delta, joueurs)
	_peupler(delta, temps, joueurs)
	_animer_les_gens(delta, joueurs)
	_animer_les_autos(delta, joueurs)
	_arbitrer(delta, joueurs)
	_depecher_la_police(delta, joueurs)
	_animer_les_helicos(delta, joueurs)
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
		for i in 28:
			_naitre_passant(joueurs, true)
		for i in 12:
			_naitre_auto(joueurs, CIVILE, "")
		for i in 6:
			_poser_caisse(joueurs)

	_depuis_gens += delta
	if _depuis_gens >= 0.32 and gens.size() < GENS_MAX:
		_depuis_gens = 0.0
		_naitre_passant(joueurs, false)
		_peupler_les_repaires(joueurs)

	_depuis_autos += delta
	if _depuis_autos >= 1.4 and _mobiles() < AUTOS_MOBILES_MAX:
		_depuis_autos = 0.0
		_naitre_auto(joueurs, CIVILE, "")

	# Le butin ne traîne pas : quatorze secondes, puis il disparaît. Sinon la
	# ville se couvre de caisses et plus aucune n'a de valeur.
	var gardees: Array = []
	for c in caisses:
		if c.has("duree"):
			c["duree"] = float(c["duree"]) - delta
			if float(c["duree"]) <= 0.0:
				continue
		gardees.append(c)
	caisses = gardees

	_depuis_caisse += delta
	if _depuis_caisse >= 7.0 and _caisses_posees() < CAISSES_MAX:
		_depuis_caisse = 0.0
		_poser_caisse(joueurs)

## Les voitures qui dorment le long des rues n'existent pas ici : le plan les
## décrit, le morceau les peint. L'hôte n'en prend une en charge que quand
## elle se RÉVEILLE — volée, percutée, tirée. Une ville de cent mille voitures
## garées ne peut pas vivre dans une liste qu'on parcourt à chaque image.
var reveillees: Dictionary = {}    ## id dormante -> vrai, chez l'hôte comme chez le client

func reveiller(id: int) -> Dictionary:
	var deja := auto_par_id(id)
	if not deja.is_empty():
		return deja
	var fiche := plan.dormante(id)
	if fiche.is_empty():
		return {}
	var gang := int(fiche["gang"])
	var auto := {
		"id": id, "p": fiche["p"], "a": float(fiche["a"]),
		"d": Vector2.RIGHT.rotated(float(fiche["a"])), "vitesse": 0.0,
		"genre": VOITURE_GANG if gang >= 0 else CIVILE, "gang": gang, "pv": PV_AUTO,
		"pilote": "", "cible": "", "minuterie": 0.0, "recharge": 0.0,
		"modele": int(fiche["modele"]), "garee": true,
	}
	autos.append(auto)
	reveillees[id] = true
	return auto

## Les voitures dormantes encore endormies autour d'un point.
func dormantes_endormies(autour: Vector2, rayon: float) -> Array:
	var liste: Array = []
	for d in plan.dormantes_autour(autour, rayon):
		if not reveillees.has(int(d["id"])):
			liste.append(d)
	return liste

func _modele_pour(quartier: int) -> int:
	var liste: Array = FormesCarnage.VOITURES_PAR_QUARTIER.get(quartier, [0])
	return int(liste[_rng.randi_range(0, liste.size() - 1)])

## Les gars d'un repaire. Ils traînent autour de leur tag et y reviennent :
## c'est le seul endroit de la ville où l'on est sûr de trouver un gang au
## complet — donc où l'on va quand un contrat demande de nettoyer.
func _peupler_les_repaires(joueurs: Dictionary) -> void:
	var vus: Dictionary = {}
	for cle in joueurs:
		for r in plan.lieux_autour(joueurs[cle]["p"], PORTEE_VUE)["repaires"]:
			vus[int(r["id"])] = r
	for id in vus:
		var r: Dictionary = vus[id]
		var presents := 0
		for personne in gens:
			if personne.has("attache") and Vector2(personne["attache"]) == Vector2(r["p"]):
				presents += 1
		if presents >= PAR_REPAIRE or gens.size() >= GENS_MAX:
			continue
		var p := plan.point_de_rue(_rng, r["p"], 30.0, PlanVille.RAYON_REPAIRE * 0.8)
		gens.append({
			"id": _id(), "p": p, "d": Vector2.RIGHT.rotated(_rng.randf() * TAU),
			"genre": GANG, "gang": int(r["gang"]), "pv": PV_GANG,
			"etat": 0, "minuterie": _rng.randf_range(0.5, 2.0), "recharge": 0.0, "a": 0.0,
			"attache": r["p"],
		})

func _mobiles() -> int:
	var total := 0
	for a in autos:
		if not bool(a.get("garee", false)) and int(a["genre"]) != EPAVE and String(a["pilote"]) == "":
			total += 1
	return total

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
	var quartier := plan.quartier(p)
	# La zone industrielle est vide le soir ; le centre et les parcs sont
	# pleins. Sans cette différence, tous les quartiers ont la même foule et le
	# décor ne raconte plus rien.
	if quartier in [PlanVille.INDUSTRIE, PlanVille.PORT] and _rng.randf() < 0.55:
		return
	if quartier == PlanVille.EAU:
		return
	var genre := PIETON
	if gang >= 0 and _rng.randf() < 0.22:
		genre = GANG
	gens.append({
		"id": _id(), "p": p, "d": Vector2.RIGHT.rotated(_rng.randf() * TAU),
		"genre": genre, "gang": gang, "pv": PV_GANG if genre == GANG else PV_PIETON,
		"etat": 0, "minuterie": _rng.randf_range(1.0, 3.5), "recharge": 0.0, "a": 0.0,
	})

func _naitre_auto(joueurs: Dictionary, genre: int, cible: String) -> void:
	# Le plafond porte sur ce qui ROULE : les garées sont trois cents et ne
	# comptent pas, sinon plus rien ne circulerait jamais.
	if _mobiles() >= AUTOS_MOBILES_MAX and genre != PATROUILLE:
		return
	var autour := _autour_d_un_joueur(joueurs)
	if cible != "" and joueurs.has(cible):
		autour = joueurs[cible]["p"]
	var pose := plan.point_de_chaussee(_rng, autour, NAISSANCE_MIN, NAISSANCE_MAX)
	var direction: Vector2 = pose["d"]
	# Une berline sur quatre porte les couleurs du quartier : c'est ce qui fait
	# qu'on hésite avant de tirer dans le tas sur le territoire d'un gang avec
	# lequel on est en bons termes.
	var gang := plan.territoire(pose["p"])
	var modele := _modele_pour(plan.quartier(pose["p"]))
	if genre == CIVILE and gang >= 0 and _rng.randf() < 0.18:
		genre = VOITURE_GANG
		modele = 1 if _rng.randf() < 0.5 else 4
	if genre == PATROUILLE:
		modele = FormesCarnage.MODELE_POLICE
	autos.append({
		"id": _id(), "p": pose["p"], "a": direction.angle(), "d": direction,
		"vitesse": 0.0, "genre": genre, "gang": gang,
		"pv": PV_AUTO, "pilote": "", "cible": cible, "minuterie": 0.0, "recharge": 0.0,
		"modele": modele, "garee": false,
	})

func _poser_caisse(joueurs: Dictionary) -> void:
	var noms := ["mitraillette", "roquette", "eperon"]
	var arme := String(noms[_rng.randi_range(0, noms.size() - 1)])
	var p := plan.point_de_rue(_rng, _autour_d_un_joueur(joueurs), 260.0, 1200.0)
	caisses.append({"id": _id(), "p": p, "arme": arme})

func _caisses_posees() -> int:
	var total := 0
	for c in caisses:
		if not c.has("duree"):
			total += 1
	return total

func retirer_caisse(id: int, cle: String = "") -> String:
	for c in caisses:
		if int(c["id"]) == id:
			var arme := String(c["arme"])
			var ou: Vector2 = c["p"]
			caisses.erase(c)
			if arme == "argent" and cle != "":
				_compter(cle, ou, 40, "argent", false)
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
		elif float(personne.get("fuite", 0.0)) > 0.0:
			# En panique : on court dans la direction qu'on a prise, et on ne
			# réfléchit plus — c'est `paniquer` qui l'a choisie.
			personne["fuite"] = float(personne["fuite"]) - delta
			vitesse = VITESSE_FUITE
			personne["etat"] = 1
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
				# Un passant préfère le trottoir : s'il s'apprête à descendre
				# sur la chaussée, il se ravise deux fois sur trois. Sans ce
				# réflexe, la moitié de la foule marche au milieu des avenues.
				if plan.sur_la_chaussee(Vector2(personne["p"]) + direction * 90.0) \
						and not plan.sur_la_chaussee(personne["p"]) and _rng.randf() < 0.66:
					direction = -direction
				# Un gars de repaire ne s'éloigne pas de son tag : parti trop
				# loin, il rentre. Sans ça, les repaires se vident en une minute.
				if personne.has("attache") and Vector2(personne["p"]).distance_to(personne["attache"]) > PlanVille.RAYON_REPAIRE * 0.8:
					direction = (Vector2(personne["attache"]) - Vector2(personne["p"])).normalized()

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

		if bool(auto.get("garee", false)):
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
			_conduire_civile(auto, delta, joueurs)
		restantes.append(auto)
	autos = restantes

## Une voiture civile suit sa file et tourne aux carrefours. Elle ne cherche
## pas d'itinéraire : dans une grille, un tirage au sort à chaque croisement
## produit un trafic qui a l'air d'aller quelque part.
func _conduire_civile(auto: Dictionary, delta: float, joueurs: Dictionary = {}) -> void:
	var direction: Vector2 = auto["d"]

	# Freiner derrière ce qu'on a devant : joueur, voiture, passant. Une
	# circulation qui traverse tout ce qu'elle croise n'est pas une circulation,
	# c'est un défilement. Et une voiture arrêtée trop longtemps klaxonne — le
	# klaxon est ce qui fait entendre qu'une rue est pleine.
	var voulue := VITESSE_TRAFIC
	if _obstacle_devant(auto, joueurs):
		voulue = 0.0
		auto["patience"] = float(auto.get("patience", 0.0)) + delta
		if float(auto["patience"]) > KLAXON_APRES:
			auto["patience"] = -_rng.randf_range(1.6, 3.2)
			emettre("klx", {"x": int(auto["p"].x), "y": int(auto["p"].y)})
	else:
		auto["patience"] = min(float(auto.get("patience", 0.0)), 0.0) + delta * 0.5
	auto["vitesse"] = move_toward(float(auto["vitesse"]), voulue, (320.0 if voulue > 0.0 else 900.0) * delta)

	# Tenir sa file : on glisse vers la droite de l'axe. `carrefour_proche` donne
	# l'axe de la rue ; la normale à droite du sens de marche donne le côté.
	var axe := plan.carrefour_proche(auto["p"])
	var droite := Vector2(-direction.y, direction.x)
	var ecart_lateral: float
	if abs(direction.x) > 0.5:
		ecart_lateral = (axe.y + droite.y * FILE) - float(auto["p"].y)
		auto["p"] = Vector2(auto["p"].x, float(auto["p"].y) + clamp(ecart_lateral, -60.0 * delta, 60.0 * delta))
	else:
		ecart_lateral = (axe.x + droite.x * FILE) - float(auto["p"].x)
		auto["p"] = Vector2(float(auto["p"].x) + clamp(ecart_lateral, -60.0 * delta, 60.0 * delta), auto["p"].y)

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
		# trafic finit aligné sur deux avenues. On ne tourne qu'au carrefour,
		# et on repart sur la file de droite de la nouvelle rue.
		var carrefour := plan.carrefour_proche(auto["p"])
		if Vector2(auto["p"]).distance_to(carrefour) < 60.0:
			direction = Vector2(-direction.y, direction.x) if _rng.randf() < 0.5 \
				else Vector2(direction.y, -direction.x)
			auto["d"] = direction
			suivant = carrefour + Vector2(-direction.y, direction.x) * FILE

	var degage := plan.degager(suivant, RAYON_AUTO)
	auto["p"] = degage[0]
	auto["a"] = direction.angle()

## Y a-t-il quelque chose dans les cent trente pixels devant ? Le test est un
## cône étroit, pas un cercle : une voiture garée sur la file d'à côté ne doit
## pas bloquer la rue.
func _obstacle_devant(auto: Dictionary, joueurs: Dictionary) -> bool:
	var ici: Vector2 = auto["p"]
	var direction: Vector2 = auto["d"]
	for cle in joueurs:
		if _dans_le_cone(ici, direction, joueurs[cle]["p"], 34.0):
			return true
	for autre in autos:
		if autre == auto or String(autre["pilote"]) != "":
			continue
		if _dans_le_cone(ici, direction, autre["p"], 26.0):
			return true
	for personne in gens:
		if _dans_le_cone(ici, direction, personne["p"], 22.0):
			return true
	# Une voiture dormante en travers (mal garée, poussée) : on freine aussi.
	for d in dormantes_endormies(ici + direction * DISTANCE_FREIN * 0.5, DISTANCE_FREIN * 0.6):
		if _dans_le_cone(ici, direction, d["p"], 26.0):
			return true
	return false

func _dans_le_cone(ici: Vector2, direction: Vector2, point: Vector2, largeur: float) -> bool:
	var vers: Vector2 = point - ici
	var devant: float = vers.dot(direction)
	if devant < 10.0 or devant > DISTANCE_FREIN:
		return false
	return abs(vers.dot(Vector2(-direction.y, direction.x))) < largeur

## Une patrouille ne suit pas les files : elle coupe. C'est ce qui fait qu'on
## ne la sème pas en tournant deux fois à droite.
func _conduire_patrouille(auto: Dictionary, delta: float, joueurs: Dictionary) -> void:
	# Chez un client devenu hôte en cours de manche, « cible » porte encore la
	# position visée par le lissage (un Vector2) : la patrouille redevient
	# civile plutôt que de planter la simulation.
	var cible := String(auto["cible"]) if typeof(auto["cible"]) == TYPE_STRING else ""
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
			if int(auto["genre"]) == PATROUILLE and typeof(auto["cible"]) == TYPE_STRING and String(auto["cible"]) == cle:
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

## À cinq étoiles, l'hélicoptère. Il survole le joueur avec un temps de retard,
## tire par rafales, et ne lâche que quand la jauge redescend. C'est la seule
## menace du jeu qu'on ne sème pas en conduisant : elle oblige à aller au
## garage, ce qui est exactement ce que cinq étoiles doivent obliger à faire.
func _animer_les_helicos(delta: float, joueurs: Dictionary) -> void:
	for cle in joueurs:
		if etoiles(String(cle)) < 5:
			continue
		var deja := false
		for h in helicos:
			if String(h["cible"]) == String(cle):
				deja = true
		if not deja:
			var depuis: Vector2 = Vector2(joueurs[cle]["p"]) + Vector2.RIGHT.rotated(_rng.randf() * TAU) * 1400.0
			helicos.append({"id": _id(), "p": depuis, "cible": String(cle), "recharge": 2.0})
			emettre("helico", {"j": cle})

	var restants: Array = []
	for h in helicos:
		var cle := String(h["cible"])
		if not joueurs.has(cle) and etoiles(cle) >= 5:
			# Le joueur est à terre : l'hélicoptère fait du surplace et attend
			# qu'il se relève. Repartir puis revenir, c'était trois annonces
			# « hélicoptère » en trente secondes.
			restants.append(h)
			continue
		if etoiles(cle) < 5:
			# Plus recherché à ce point : il rentre à la base. On le laisse
			# filer plutôt que de le faire disparaître d'un coup.
			h["p"] = Vector2(h["p"]) + Vector2.RIGHT.rotated(float(h.get("cap", 0.0))) * VITESSE_HELICO * delta
			h["retrait"] = float(h.get("retrait", 0.0)) + delta
			if float(h["retrait"]) < 3.0:
				restants.append(h)
			continue
		var vers: Vector2 = Vector2(joueurs[cle]["p"]) - Vector2(h["p"])
		h["cap"] = vers.angle()
		if vers.length() > 90.0:
			h["p"] = Vector2(h["p"]) + vers.normalized() * min(VITESSE_HELICO * delta, vers.length())
		h["recharge"] = float(h["recharge"]) - delta
		if float(h["recharge"]) <= 0.0 and vers.length() < PORTEE_HELICO:
			h["recharge"] = CADENCE_HELICO
			emettre("tn", {"x": int(h["p"].x), "y": int(h["p"].y), "a": snapped(vers.angle(), 0.01), "h": 1})
			if _rng.randf() < 0.55:
				emettre("deg", {"j": cle, "d": int(DEGAT_HELICO), "k": "balle"})
		restants.append(h)
	helicos = restants

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
	# Une voiture dormante qu'un joueur percute se réveille : à partir de là,
	# c'est une voiture comme les autres, poussée, cabossée, diffusée.
	for cle in joueurs:
		var j: Dictionary = joueurs[cle]
		if bool(j.get("pied", true)) or abs(float(j.get("v", 0.0))) < 40.0:
			continue
		for d in dormantes_endormies(j["p"], CHOC_AUTO):
			reveiller(int(d["id"]))
	for auto in autos:
		if int(auto["genre"]) == EPAVE or String(auto["pilote"]) != "":
			continue
		for cle in joueurs:
			var j: Dictionary = joueurs[cle]
			if bool(j.get("pied", true)) or float(j.get("vie", 100.0)) <= 0.0:
				continue
			var ecart: float = Vector2(auto["p"]).distance_to(j["p"])
			if ecart > CHOC_AUTO:
				continue
			var choc: float = abs(float(j.get("v", 0.0)))
			auto["pv"] = float(auto["pv"]) - choc * 0.06
			emettre("deg", {"j": cle, "d": int(choc * 0.02), "k": "tole"})
			# On se repousse : deux carrosseries qui s'interpénètrent finissent
			# par se catapulter, et ça, ça se voit.
			auto["p"] = Vector2(auto["p"]) + (Vector2(auto["p"]) - Vector2(j["p"])).normalized() \
				* (10.0 if bool(auto.get("garee", false)) else 26.0)
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
	# Ce qu'il laisse par terre. Un gang armé lâche son arme une fois sur
	# trois ; un passant, un billet une fois sur six, une trousse une fois sur
	# quinze. C'est ce qui donne une raison de descendre de voiture.
	var tirage := _rng.randf()
	if genre == GANG and tirage < 0.34:
		_lacher(personne["p"], "mitraillette" if tirage < 0.26 else "roquette")
	elif genre == FLIC and tirage < 0.5:
		_lacher(personne["p"], "vie" if tirage < 0.25 else "mitraillette")
	elif genre == PIETON:
		if tirage < 0.16:
			_lacher(personne["p"], "argent")
		elif tirage < 0.23:
			_lacher(personne["p"], "vie")
	# Les voisins ont vu : ils courent.
	paniquer(Vector2(personne["p"]), 260.0, 2.4)

func _lacher(ou: Vector2, quoi: String) -> void:
	caisses.append({"id": _id(), "p": Vector2(ou) + Vector2.RIGHT.rotated(_rng.randf() * TAU) * 18.0,
		"arme": quoi, "duree": 14.0})

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
		"k": String(c.get("genre", "")), "g": int(c.get("rival", -1)),
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

# ------------------------------------------------------------ la casse

## Ce que la manche a cassé : id d'immeuble -> clés locales de voxels partis.
## Partagé avec l'écran (les morceaux le lisent en se bâtissant) et rempli chez
## tout le monde par l'événement `casse`. Ici aussi, l'hôte décide : deux
## clients qui casseraient chacun de leur côté verraient deux ruines différentes.
var detruits: Dictionary = {}
var _coups_voxel: Dictionary = {}   ## clé globale -> balles reçues
const COUPS_PAR_VOXEL := 3
const RAYON_ROQUETTE := 2.6         ## unités 3D
const RAYON_EXPLOSION := 2.4
const RAYON_CHOC := 1.3

## Une balle ou une roquette dans un mur. Le pistolet écaille (trois balles par
## cube), la roquette creuse une sphère.
func impacter(point: Vector2, arme: String, hauteur: float = 1.4) -> void:
	var trouve := plan.immeuble_a(point)
	if trouve.is_empty():
		return
	var id := int(trouve["id"])
	var b: Dictionary = trouve["b"]
	var p3 := Decor.vers3d(point, hauteur)
	if arme == "roquette":
		_casser(id, VoxelsCarnage.voxels_autour_de(b, p3, RAYON_ROQUETTE))
		return
	var locale := VoxelsCarnage.voxel_proche_de(b, p3)
	if _deja_casse(id, locale):
		return
	var cle := id * 8192 + locale
	_coups_voxel[cle] = int(_coups_voxel.get(cle, 0)) + 1
	if int(_coups_voxel[cle]) >= COUPS_PAR_VOXEL:
		_casser(id, [locale])

## Une voiture qui explose : tout ce qui est à portée, dans tous les immeubles
## qui bordent le point.
func exploser(point: Vector2) -> void:
	var vus: Dictionary = {}
	for angle in 8:
		var sonde := point + Vector2.RIGHT.rotated(TAU * float(angle) / 8.0) * RAYON_EXPLOSION * 10.0
		var trouve := plan.immeuble_a(sonde, 4.0)
		if trouve.is_empty() or vus.has(int(trouve["id"])):
			continue
		vus[int(trouve["id"])] = true
		_casser(int(trouve["id"]), VoxelsCarnage.voxels_autour_de(trouve["b"], Decor.vers3d(point, 1.2), RAYON_EXPLOSION))

## Un pare-chocs dans une façade, à pleine vitesse : un ou deux cubes du
## rez-de-chaussée sautent.
func choquer(point: Vector2, direction: Vector2, vitesse: float) -> void:
	if vitesse < 380.0:
		return
	var trouve := plan.immeuble_a(point + direction * 18.0, 10.0)
	if trouve.is_empty():
		return
	var rayon := RAYON_CHOC * (1.6 if vitesse > 600.0 else 1.0)
	var liste: Array = []
	for locale in VoxelsCarnage.voxels_autour_de(trouve["b"], Decor.vers3d(point + direction * 18.0, 1.0), rayon):
		if posmod(int(locale), 32) == 0:      # le rez-de-chaussée seulement
			liste.append(locale)
	_casser(int(trouve["id"]), liste)

func _deja_casse(id: int, locale: int) -> bool:
	return detruits.has(id) and (detruits[id] as Array).has(locale)

func _casser(id: int, locales: Array) -> void:
	var neufs: Array = []
	for locale in locales:
		if not _deja_casse(id, int(locale)):
			neufs.append(int(locale))
			if not detruits.has(id):
				detruits[id] = []
			detruits[id].append(int(locale))
	if neufs.is_empty():
		return
	var charge: Array = []
	for locale in neufs:
		charge.append([id, locale])
	emettre("casse", {"v": charge})

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
	if auto.is_empty() and PlanVille.est_dormante(id):
		auto = reveiller(id)
	if auto.is_empty() or String(auto["pilote"]) != "" or int(auto["genre"]) == EPAVE:
		return
	if Vector2(auto["p"]).distance_to(position) > 120.0:
		return
	auto["pilote"] = cle
	auto["garee"] = false
	if int(auto["genre"]) == PATROUILLE:
		# Voler une voiture de police, ça se paie.
		crime(cle, "pieton")
	elif int(auto["genre"]) == VOITURE_GANG:
		# Voler la voiture d'un gang aussi — moins qu'un mort, plus qu'un rien.
		_ajuster_respect(cle, int(auto.get("gang", 0)), RESPECT_PERDU * 0.4, 0.0)
	emettre("pris", {"j": cle, "id": id, "g": int(auto["genre"]), "m": int(auto.get("modele", 0)),
		"x": int(auto["p"].x), "y": int(auto["p"].y), "a": snapped(float(auto["a"]), 0.01),
		"pv": int(auto["pv"])})

func rendre_vehicule(cle: String, id: int, position: Vector2, angle: float, pv: float,
		modele: int = -1, genre_rendu: int = CIVILE) -> void:
	var auto := auto_par_id(id)
	if auto.is_empty():
		# L'hôte a changé en cours de route et ne connaît plus cette voiture —
		# ou c'est la voiture de départ, qu'il découvre : on la réinscrit
		# plutôt que de la faire disparaître sous le joueur.
		autos.append({
			"id": id, "p": position, "a": angle, "d": Vector2.RIGHT.rotated(angle),
			"vitesse": 0.0, "genre": EPAVE if pv <= 0.0 else genre_rendu,
			"gang": plan.territoire(position),
			"pv": pv, "pilote": "", "cible": "", "minuterie": 7.0 if pv <= 0.0 else 0.0,
			"recharge": 0.0, "modele": modele, "garee": true,
		})
		if PlanVille.est_dormante(id):
			reveillees[id] = true
		return
	if String(auto["pilote"]) != cle:
		return
	auto["pilote"] = ""
	auto["p"] = position
	auto["a"] = angle
	auto["d"] = Vector2.RIGHT.rotated(angle)
	auto["pv"] = pv
	auto["vitesse"] = 0.0
	# Abandonnée, elle reste là où on l'a laissée : une voiture qu'on quitte et
	# qui repart toute seule dans la circulation, c'est une voiture qu'on ne
	# retrouve jamais.
	auto["garee"] = true
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
	# Les dormantes : elles ne sont dans aucune liste, mais on les vole quand
	# même — c'est même la plupart de ce qu'on vole.
	for dormante in dormantes_endormies(position, rayon):
		var d2: float = Vector2(dormante["p"]).distance_squared_to(position)
		if d2 < distance:
			distance = d2
			meilleur = {"id": int(dormante["id"]), "p": dormante["p"], "a": float(dormante["a"]),
				"genre": VOITURE_GANG if int(dormante["gang"]) >= 0 else CIVILE,
				"gang": int(dormante["gang"]), "pv": PV_AUTO, "pilote": "", "modele": int(dormante["modele"]),
				"garee": true, "dormante": true}
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
			int(float(auto["a"]) * 100.0), int(auto["genre"]), int(auto["pv"]),
			int(auto.get("modele", 0)), 1 if bool(auto.get("garee", false)) else 0])

	var vues_caisses: Array = []
	for c in caisses:
		vues_caisses.append([int(c["id"]), int(c["p"].x), int(c["p"].y), String(c["arme"])])

	var vus_barrages: Array = []
	for b in barrages:
		vus_barrages.append([int(b["id"]), int(b["p"].x), int(b["p"].y)])

	var vus_helicos: Array = []
	for h in helicos:
		vus_helicos.append([int(h["id"]), int(h["p"].x), int(h["p"].y), int(float(h.get("cap", 0.0)) * 100.0)])

	var etats: Dictionary = {}
	for cle in joueurs:
		etats[cle] = [etoiles(String(cle)),
			int(respect_de(String(cle))[0]), int(respect_de(String(cle))[1]),
			int(respect_de(String(cle))[2])]

	return {"g": vus_gens, "a": vus_autos, "c": vues_caisses, "b": vus_barrages, "h": vus_helicos, "e": etats}

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
		if not auto.has("modele"):
			auto["modele"] = 0
		if not auto.has("garee"):
			auto["garee"] = false
		if PlanVille.est_dormante(int(auto["id"])):
			reveillees[int(auto["id"])] = true
		else:
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
	for entree in charge.get("a", []):
		if typeof(entree) == TYPE_ARRAY and (entree as Array).size() > 0 and PlanVille.est_dormante(int(entree[0])):
			reveillees[int(entree[0])] = true
	autos = _fusionner(autos, charge.get("a", []), func(entree: Array) -> Dictionary:
		return {"id": int(entree[0]), "p": Vector2(float(entree[1]), float(entree[2])),
			"cible_p": Vector2(float(entree[1]), float(entree[2])),
			"a": float(entree[3]) / 100.0, "genre": int(entree[4]), "pv": float(entree[5]),
			"modele": int(entree[6]) if entree.size() > 6 else 0,
			"garee": (int(entree[7]) == 1) if entree.size() > 7 else false,
			"gang": plan.territoire(Vector2(float(entree[1]), float(entree[2]))),
			"d": Vector2.RIGHT, "vitesse": 0.0, "pilote": "", "cible": "", "minuterie": 0.0})
	caisses = _fusionner(caisses, charge.get("c", []), func(entree: Array) -> Dictionary:
		return {"id": int(entree[0]), "p": Vector2(float(entree[1]), float(entree[2])),
			"arme": String(entree[3])})
	barrages = _fusionner(barrages, charge.get("b", []), func(entree: Array) -> Dictionary:
		return {"id": int(entree[0]), "p": Vector2(float(entree[1]), float(entree[2]))})
	helicos = _fusionner(helicos, charge.get("h", []), func(entree: Array) -> Dictionary:
		return {"id": int(entree[0]), "p": Vector2(float(entree[1]), float(entree[2])),
			"cible": "", "recharge": 0.0, "cap": float(entree[3]) / 100.0 if entree.size() > 3 else 0.0})

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
			for champ in ["genre", "gang", "pv", "a", "arme", "garee", "cap"]:
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
