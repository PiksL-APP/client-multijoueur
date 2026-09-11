class_name VilleVivante
extends RefCounted
## Tout ce qui vit dans CARNAGE et que l'HÔTE simule : les passants, les sept
## gangs (trois par district), la circulation, la police, les caisses d'armes,
## la jauge de recherche et le respect.
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
enum { CIVILE, PATROUILLE, VOITURE_GANG, EPAVE, POMPIER, AMBULANCE }   ## `genre` d'un véhicule

const GENS_MAX := 90            ## de jour ; la nuit, la ville se vide à moitié
const AUTOS_MOBILES_MAX := 44   ## celles qui roulent ; les garées ne comptent pas
const GENS_NUIT := 40
const AUTOS_NUIT := 14
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

## LES CORPS QUI VOUS CHERCHENT, du plus banal au plus lourd (guide §5). Ce
## n'est pas la même chose d'avoir la police au train ou l'armée : sans ces
## quatre lignes, monter d'une étoile ne changeait que le NOMBRE de voitures,
## et cinq étoiles ressemblaient à trois avec plus de bruit.
##
## ⚠ Ce sont des PATROUILLES, toutes : le corps ne change ni le genre du
## véhicule, ni la conduite, ni le radar. Un fourgon du SWAT poursuit comme
## une voiture de police parce que c'est la même fonction qui le conduit —
## et c'est la seule raison pour laquelle cette phase tient en un fichier.
enum { CORPS_POLICE, CORPS_SWAT, CORPS_AGENT, CORPS_ARMEE }
const CORPS := [
	{"nom": "police", "pv": PV_FLIC, "cadence": 1.15, "degat": 9.0, "portee": 640.0,
		"vitesse": 108.0, "modele": FormesCarnage.MODELE_POLICE, "discret": false},
	{"nom": "SWAT", "pv": 7, "cadence": 0.78, "degat": 13.0, "portee": 700.0,
		"vitesse": 118.0, "modele": 6, "discret": false},
	{"nom": "agent spécial", "pv": 9, "cadence": 0.58, "degat": 16.0, "portee": 780.0,
		"vitesse": 128.0, "modele": 1, "discret": true},
	{"nom": "armée", "pv": 12, "cadence": 0.64, "degat": 20.0, "portee": 860.0,
		"vitesse": 112.0, "modele": 8, "discret": false},
]
## À quelle étoile chaque corps entre en scène.
const NIVEAU_SWAT := 3
const NIVEAU_AGENTS := 5
const NIVEAU_ARMEE := 6
## Ce qu'un fourgon du SWAT débarque en arrivant, et à quelle distance.
const DEBARQUEMENT := 4
const PORTEE_DEBARQUEMENT := 300.0
## LE CHAR. Il ne tire pas des balles : un obus toutes les deux secondes et
## demie, qui souffle tout dans un rayon. C'est la seule chose du jeu contre
## laquelle la tôle ne protège pas.
const PV_CHAR := 320.0
const CADENCE_OBUS := 2.5
const PORTEE_OBUS := 700.0
const DEGAT_OBUS := 46.0
const SOUFFLE_OBUS := 120.0
## ⚠ LA DISPERSION DOIT DÉPASSER LE SOUFFLE. À 110 px de dispersion pour 120
## de souffle, l'obus touchait DEUX CENTS FOIS SUR DEUX CENTS au banc : le
## char ne ratait jamais, quarante-six points toutes les deux secondes et
## demie, et la seule réponse était de quitter l'écran. À 240, un tir sur deux
## porte — on peut tenir la rue si on bouge.
const DISPERSION_OBUS := 240.0
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
## SIX PALIERS, SIX RÉPONSES (guide §5). Le sixième a été ajouté avec la
## phase 8 : à cinq, l'hélicoptère était le dernier mot, et une jauge dont le
## dernier cran arrive à la moitié de ce qu'on peut faire en une manche cesse
## de menacer. Le sixième est LOIN — neuf cents points, soit une manche à
## saccager sans jamais passer au garage.
const PALIERS := [40.0, 115.0, 230.0, 400.0, 620.0, 900.0]
const REFROIDISSEMENT := 9.0      ## points par seconde, après une accalmie
const ACCALMIE := 4.5             ## secondes sans crime avant que ça redescende

## LE RESPECT, DE ZÉRO À CENT, EN CINQ PALIERS.
##
## On commence à CINQUANTE avec les sept gangs : le joueur n'est ni attendu ni
## chassé, il est INCONNU. C'est ce qui donne deux directions à la jauge —
## avant, elle partait de zéro et ne pouvait que descendre en pratique, faute
## d'une raison de monter avant le premier contrat.
##
## Les cinq paliers viennent du guide (§3.3) et chacun a une CONSÉQUENCE
## visible, sinon ce serait un chiffre de plus dans un coin de l'écran :
##   moins de 20 : on lui tire dessus à vue
##   20 à 40     : mauvaise tête, aucun contrat proposé
##   40 à 60     : on l'ignore, contrats de base
##   60 à 80     : on le laisse passer, contrats moyens
##   plus de 80  : on se bat À CÔTÉ de lui, contrats difficiles
const RESPECT_DEPART := 50.0
const SEUIL_VUE := 20.0
const SEUIL_HOSTILE := 40.0
const SEUIL_AMICAL := 60.0
const SEUIL_ALLIE := 80.0

## ⚠ ON NE TIRE À VUE QU'AU TROISIÈME MORT. Le chiffre a déjà été remonté une
## fois : abattre un seul passant en couleurs retournait le quartier entier
## contre le joueur, et la jauge ne servait plus qu'à annoncer une
## catastrophe. Depuis 50, onze points par mort, cela donne 39 (mauvaise tête :
## le gang ne confie plus rien), 28, puis 17 — et là seulement on vous tire
## dessus. La sanction s'annonce donc DEUX FOIS avant de tomber.
##
## Un mort coûte les contrats du gang immédiatement, et c'est voulu : à moins
## de dix points la mort, il fallait quatre cadavres pour se faire chasser, et
## descendre un gars en couleurs ne se payait plus du tout.
const RESPECT_PERDU := 11.0
const RESPECT_GAGNE := 5.0

## Les cinq humeurs, et ce que le tableau de bord en dit. Un gang « vous
## couvre » : c'est la seule ligne qui promet de l'aide, elle doit se
## distinguer d'un « vous salue » qui ne promet rien.
enum { H_VUE, H_HOSTILE, H_NEUTRE, H_AMICAL, H_ALLIE }
const NOMS_HUMEUR := ["vous chasse", "vous cherche", "vous ignore", "vous salue", "vous couvre"]

## Ce que rapporte chaque chose, en DOLLARS : c'est de l'argent qu'on ramasse,
## pas des points — il s'achète une planque, un coffre, un garage.
const POINTS := {
	"pieton": 20, "gang": 60, "flic": 120, "auto": 90, "joueur": 500,
}
## Les contrats. Un gang décroche son téléphone et paie pour un service rendu
## chez le voisin. C'est ce qui donne une DIRECTION à une manche : sans eux, la
## ville est un bac à sable où l'on tourne en rond jusqu'au chrono.
const DUREE_CONTRAT := {"nettoyage": 55.0, "livraison": 45.0, "chasse": 32.0}
const PRIME_CONTRAT := {"nettoyage": 620, "livraison": 700, "chasse": 800}
const RESPECT_CONTRAT := 13.0

## Les trois téléphones du guide (§4.1) : vert, jaune, rouge. La difficulté
## appartient à la CABINE, pas au joueur — c'est `FormesCarnage.CABINES` qui
## la tire du pâté, une fois pour toutes, et l'enseigne l'annonce de loin.
##
## ⚠ C'était l'humeur du gang qui choisissait le palier : le même téléphone
## donnait « facile » puis « difficile » selon la jauge, donc rien à chercher
## dans la ville — on décrochait où on passait et le jeu décidait. Le guide
## demande l'inverse : le joueur REPÈRE un téléphone rouge et revient quand il
## a de quoi. Le respect ne fixe plus la difficulté, il ouvre la serrure —
## `CABINES[niveau]["respect"]` est le minimum qu'il faut avoir avec le gang
## du quartier pour que ce téléphone-là décroche.
##   nom, multiplicateur de prime, travail en plus, respect gagné
const PALIERS_CONTRAT := [
	{"nom": "facile", "prime": 1.0, "plus": 0, "respect": RESPECT_CONTRAT * 0.8},
	{"nom": "moyenne", "prime": 1.6, "plus": 1, "respect": RESPECT_CONTRAT},
	{"nom": "difficile", "prime": 2.4, "plus": 2, "respect": RESPECT_CONTRAT * 1.3},
]

const COMBO_FENETRE := 3.0
const COMBO_MAX := 4              ## facteur maximum = COMBO_MAX + 1

var plan: PlanVille
var gens: Array = []              ## {id,p,d,genre,gang,pv,etat,minuterie,recharge}
var autos: Array = []             ## {id,p,a,d,vitesse,genre,gang,pv,pilote,cible,minuterie}
var caisses: Array = []           ## {id,p,arme}
var barrages: Array = []          ## {id,p}
var helicos: Array = []           ## {id,p,cible,recharge} — un par joueur à cinq étoiles
var chaleur: Dictionary = {}      ## cle -> points de recherche
var plaques: Dictionary = {}      ## cle -> secondes de plaques maquillées
var respect: Dictionary = {}      ## cle -> une jauge 0..100 par gang (7)

# ------------------------------------------------------------ le feu
#
## LE FEU est ce qui donne des conséquences à une explosion : une voiture qui
## saute allume un brasier, le brasier allume les voitures d'à côté, noircit
## puis emporte les cubes du mur qu'il lèche, blesse qui reste dedans — et
## appelle les pompiers. Il vit chez l'HÔTE comme le reste de la ville, et
## voyage dans l'instantané : deux joueurs voient le même incendie.
var feux: Array = []              ## {id, p, force 0..1, t, propage, ronge}
const FEUX_MAX := 26              ## au-delà, la ville entière brûlerait
const DUREE_FEU := 26.0           ## un foyer s'épuise tout seul
const RAYON_FEU := 62.0           ## px : ce qu'un foyer chauffe
const DEGAT_FEU := 26.0           ## points de vie par seconde au cœur
const PROPAGATION := 3.2          ## secondes entre deux tentatives de propagation
const RONGE := 1.6                ## secondes entre deux cubes emportés par un foyer
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
	# LES PLAQUES MAQUILLÉES (atelier) : la police n'a plus la bonne
	# description. Ce n'est PAS le garage de peinture — la jauge ne redescend
	# pas, elle CESSE DE MONTER. C'est ce qui en fait un achat de poursuite :
	# on ne va pas au garage quand on a trois voitures aux fesses, on essaie
	# de tenir quarante-cinq secondes.
	if float(plaques.get(cle, 0.0)) > 0.0:
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
		var neuve: Array = []
		for _i in PlanVille.GANGS.size():
			neuve.append(RESPECT_DEPART)
		respect[cle] = neuve
	return respect[cle]

func respect_pour(cle: String, gang: int) -> float:
	return float(respect_de(cle)[posmod(gang, PlanVille.GANGS.size())])

## L'humeur d'un gang envers un joueur : le seul endroit du jeu où l'on
## traduit un nombre en intention. Tout le reste (l'IA, les cabines, le
## tableau de bord, les alliés) passe par ici — deux tables de seuils
## divergentes, c'est un gang qui tire à vue sur un joueur que l'écran
## annonce comme ami.
func humeur(cle: String, gang: int) -> int:
	var valeur := respect_pour(cle, gang)
	if valeur < SEUIL_VUE:
		return H_VUE
	if valeur < SEUIL_HOSTILE:
		return H_HOSTILE
	if valeur < SEUIL_AMICAL:
		return H_NEUTRE
	if valeur < SEUIL_ALLIE:
		return H_AMICAL
	return H_ALLIE

func gang_hostile(cle: String, gang: int) -> bool:
	return humeur(cle, gang) == H_VUE

func gang_ami(cle: String, gang: int) -> bool:
	return humeur(cle, gang) >= H_AMICAL

func gang_allie(cle: String, gang: int) -> bool:
	return humeur(cle, gang) == H_ALLIE

## Bouger UNE jauge. `delta` positif fait monter le respect.
func _ajuster_respect(cle: String, gang: int, delta: float) -> void:
	var jauge := respect_de(cle)
	var i := posmod(gang, jauge.size())
	jauge[i] = clamp(float(jauge[i]) + delta, 0.0, 100.0)
	respect[cle] = jauge
	_diffuser_respect(cle)

## Un coup porté à un gang RETOMBE sur ses rivaux : c'est le triangle du
## guide (§3.2). Le point compte — voir `PlanVille.rivaux` : le Consortium
## n'a pas de secteur à lui, ce sont les deux locaux DE L'ENDROIT qui se
## réjouissent.
func _repercuter(cle: String, gang: int, ou: Vector2, perte: float, gain: float) -> void:
	var jauge := respect_de(cle)
	var vise := posmod(gang, jauge.size())
	jauge[vise] = clamp(float(jauge[vise]) - perte, 0.0, 100.0)
	if gain != 0.0:
		for autre in plan.rivaux(vise, ou):
			jauge[int(autre)] = clamp(float(jauge[int(autre)]) + gain, 0.0, 100.0)
	respect[cle] = jauge
	_diffuser_respect(cle)

## LES TROIS BARRES DU DISTRICT, prêtes à peindre : les deux gangs locaux puis
## le commun, avec ce qu'ils pensent du joueur. C'est ici et nulle part
## ailleurs — le tableau de bord et le banc d'image appellent la même
## fonction, sans quoi le banc photographierait des barres que le jeu ne
## montre pas.
func barres_de_respect(cle: String, ou: Vector2) -> Array:
	var barres: Array = []
	for g in plan.trio(ou):
		var indice := int(g)
		var etat := humeur(cle, indice)
		# DEUX couleurs par barre, et c'est voulu : le nom porte la couleur du
		# GANG (elle dit qui l'on regarde, elle est la même sur la carte, sur
		# les casquettes et sur les voitures), la barre et le mot portent celle
		# de l'HUMEUR. Une barre verte annonçant « vous chasse » parce que le
		# gang a le vert pour bannière, c'est un contresens qu'on lit avant de
		# lire le mot.
		barres.append({
			"nom": plan.nom_du_gang(indice),
			"part": respect_pour(cle, indice) / 100.0,
			"couleur": plan.couleur_du_gang(indice),
			"teinte": FormesCarnage.COULEURS_HUMEUR[etat],
			"humeur": String(NOMS_HUMEUR[etat]),
		})
	return barres

## La puce « qui tient la rue, et ce qu'il pense de vous ». Le rouge de
## l'alerte l'emporte sur la couleur du gang quand on tire à vue : la couleur
## d'un gang dit QUI, elle ne doit pas dire à sa place que tout va bien.
func puce_de_gang(cle: String, gang: int) -> Dictionary:
	var etat := humeur(cle, gang)
	var couleur: Color = plan.couleur_du_gang(gang)
	if etat == H_VUE:
		couleur = Palette.CRITIQUE
	return {"texte": "%s : %s" % [plan.nom_du_gang(gang), String(NOMS_HUMEUR[etat])],
		"couleur": couleur}

func _diffuser_respect(cle: String) -> void:
	var valeurs: Array = []
	for v in respect_de(cle):
		valeurs.append(int(v))
	emettre("resp", {"j": cle, "v": valeurs})

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
	_recycler(delta, joueurs)
	_animer_les_feux(delta, joueurs)
	_depecher_les_secours(delta, joueurs)
	_peupler(delta, temps, joueurs)
	_animer_les_gens(delta, joueurs)
	_animer_les_autos(delta, joueurs)
	_arbitrer(delta, joueurs)
	_depecher_la_police(delta, joueurs)
	_animer_les_helicos(delta, joueurs)
	_animer_les_trains(delta, joueurs)
	_avancer_contrats(delta, joueurs)
	_animer_les_pieges(delta, joueurs)
	_animer_les_bombes(delta)
	_semer_les_a_cotes(delta, joueurs)
	_avancer_les_frenzies(delta)
	for cle_p in plaques.keys():
		var reste := float(plaques[cle_p]) - delta
		plaques[cle_p] = max(0.0, reste)
		if reste <= 0.0 and reste > -delta:
			emettre("mod", {"j": String(cle_p), "m": "plaques", "e": "fini"})

## Au-delà de cette distance de TOUS les joueurs, un passant ou une voiture
## civile disparaît : le plafond se libère et la ville se repeuple devant soi.
## Sans ça, la population naissait autour du point de départ, y restait, et au
## bout de cent mètres on ne croisait plus personne.
const OUBLI := 2100.0
var _depuis_recyclage := 0.0

func _recycler(delta: float, joueurs: Dictionary) -> void:
	_depuis_recyclage += delta
	if _depuis_recyclage < 0.5 or joueurs.is_empty():
		return
	_depuis_recyclage = 0.0
	var gardes: Array = []
	for personne in gens:
		# Les membres attachés à un repaire y restent : le repaire se vide sinon.
		if personne.has("attache") or _pres_d_un_joueur(personne["p"], joueurs, OUBLI):
			gardes.append(personne)
	gens = gardes
	var restantes: Array = []
	for auto in autos:
		var civile := String(auto["pilote"]) == "" and not bool(auto.get("garee", false)) and int(auto["genre"]) in [CIVILE, VOITURE_GANG]
		if not civile or _pres_d_un_joueur(auto["p"], joueurs, OUBLI):
			restantes.append(auto)
		else:
			var noeud = auto.get("noeud")
			if noeud != null:
				(noeud as Node3D).queue_free()
	autos = restantes

func _pres_d_un_joueur(point: Vector2, joueurs: Dictionary, distance: float) -> bool:
	for cle in joueurs:
		if Vector2(joueurs[cle]["p"]).distance_to(point) <= distance:
			return true
	return false

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
	# La ville vit au rythme du jour : pleine de monde et de voitures à midi,
	# à moitié vide la nuit. L'heure est la même chez tous (celle du village).
	var nuit := MatieresCarnage.nuit()
	if _depuis_gens >= lerpf(0.32, 0.7, nuit) and gens.size() < plafond_gens():
		_depuis_gens = 0.0
		_naitre_passant(joueurs, false)
		_peupler_les_repaires(joueurs)

	_depuis_autos += delta
	if _depuis_autos >= lerpf(0.5, 1.8, nuit) and _mobiles() < plafond_autos():
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
		if presents >= PAR_REPAIRE or gens.size() >= plafond_gens():
			continue
		var p := plan.point_de_rue(_rng, r["p"], 30.0, PlanVille.RAYON_REPAIRE * 0.8)
		gens.append({
			"id": _id(), "p": p, "d": Vector2.RIGHT.rotated(_rng.randf() * TAU),
			"genre": GANG, "gang": int(r["gang"]), "pv": PV_GANG,
			"etat": 0, "minuterie": _rng.randf_range(0.5, 2.0), "recharge": 0.0, "a": 0.0,
			"attache": r["p"],
		})

## Les plafonds de population selon l'heure.
func plafond_autos() -> int:
	return int(round(lerpf(float(AUTOS_MOBILES_MAX), float(AUTOS_NUIT), MatieresCarnage.nuit())))

func plafond_gens() -> int:
	return int(round(lerpf(float(GENS_MAX), float(GENS_NUIT), MatieresCarnage.nuit())))

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

## Un identifiant neuf, pour un objet fabriqué côté client (un feu reçu).
func prochain_id() -> int:
	return _id()

func _autour_d_un_joueur(joueurs: Dictionary) -> Vector2:
	var cles := joueurs.keys()
	if cles.is_empty():
		return plan.coeur()   # ⚠ le cœur, pas le centre : il peut être en pleine eau
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
	# Sur le territoire d'un gang, un passant sur DEUX en porte les couleurs —
	# et près de leur repaire, presque tous. Un quartier tenu doit se sentir
	# tenu : c'est ce qui donne envie d'y entrer, ou de l'éviter.
	var genre := PIETON
	if gang >= 0:
		var part := 0.45
		var repaire := plan.repaire_le_plus_proche(p, gang)
		if not repaire.is_empty() and Vector2(repaire["p"]).distance_to(p) < PlanVille.RAYON_REPAIRE * 2.0:
			part = 0.8
		if _rng.randf() < part:
			genre = GANG
	gens.append({
		"id": _id(), "p": p, "d": Vector2.RIGHT.rotated(_rng.randf() * TAU),
		"genre": genre, "gang": gang, "pv": PV_GANG if genre == GANG else PV_PIETON,
		"etat": 0, "minuterie": _rng.randf_range(1.0, 3.5), "recharge": 0.0, "a": 0.0,
	})

func _naitre_auto(joueurs: Dictionary, genre: int, cible: String, corps: int = CORPS_POLICE,
		canon: bool = false) -> void:
	# Le plafond porte sur ce qui ROULE : les garées sont trois cents et ne
	# comptent pas, sinon plus rien ne circulerait jamais.
	if _mobiles() >= plafond_autos() and genre != PATROUILLE:
		return
	var autour := _autour_d_un_joueur(joueurs)
	if cible != "" and joueurs.has(cible):
		autour = joueurs[cible]["p"]
	var pose := plan.point_de_chaussee(_rng, autour, NAISSANCE_MIN, NAISSANCE_MAX)
	# Jamais SUR une autre voiture (garée ou non) : deux caisses emboîtées, ça
	# se voit tout de suite et ça ne se démêle jamais. Trois essais, sinon on
	# renonce pour cette fois.
	for essai in 3:
		if _degage_des_autos(pose["p"]):
			break
		pose = plan.point_de_chaussee(_rng, autour, NAISSANCE_MIN, NAISSANCE_MAX)
	if not _degage_des_autos(pose["p"]):
		return
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
		modele = int(CORPS[posmod(corps, CORPS.size())]["modele"])
	autos.append({
		"id": _id(), "p": pose["p"], "a": direction.angle(), "d": direction,
		"vitesse": 0.0, "genre": genre, "gang": gang,
		"pv": PV_CHAR if canon else PV_AUTO, "pilote": "", "cible": cible,
		"minuterie": 0.0, "recharge": 0.0,
		"modele": modele, "garee": false,
		"corps": posmod(corps, CORPS.size()) if genre == PATROUILLE else CORPS_POLICE,
		"canon": canon, "vide": false,
	})

## Vrai si aucune voiture (ni aucun joueur) ne se trouve à moins de deux
## longueurs de voiture du point.
func _degage_des_autos(point: Vector2) -> bool:
	for auto in autos:
		if Vector2(auto["p"]).distance_squared_to(point) < (RAYON_AUTO * 2.4) * (RAYON_AUTO * 2.4):
			return false
	return true

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
				_compter(cle, ou, 120, "argent", false)
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

## LES ALLIÉS QUI PRÊTENT MAIN-FORTE (guide §3.3, palier « très élevé »).
##
## Au-dessus de quatre-vingts, un homme de gang ne se contente plus de laisser
## passer : il tire sur ce qui vous tire dessus. C'est la seule récompense du
## respect qui se voie SANS regarder l'écran — un flic qui tombe sans qu'on ait
## appuyé sur rien.
##
## ⚠ Il vise des PNJ, pas des joueurs. Un allié qui canarde un autre joueur
## ferait du respect une arme à distance : on monterait sa jauge chez un gang
## et on lâcherait le quartier sur un adversaire qui n'a rien demandé, sans
## risque et sans y être. Les joueurs ne se blessent qu'en arène.
const PORTEE_MAIN_FORTE := 520.0    ## distance à laquelle un allié prend un ennemi en charge
const DELAI_MAIN_FORTE := 9.0       ## secondes entre deux annonces, par joueur
var _depuis_main_forte: Dictionary = {}   ## cle -> secondes avant de pouvoir réannoncer

func _animer_les_gens(delta: float, joueurs: Dictionary) -> void:
	for cle_j in _depuis_main_forte:
		_depuis_main_forte[cle_j] = max(0.0, float(_depuis_main_forte[cle_j]) - delta)
	for personne in gens:
		personne["recharge"] = max(0.0, float(personne["recharge"]) - delta)
		personne["minuterie"] = float(personne["minuterie"]) - delta

		var genre := int(personne["genre"])
		var vitesse := VITESSE_MARCHE
		var direction: Vector2 = personne["d"]
		var proche := _menace_la_plus_proche(personne["p"], joueurs, 520.0)
		# Cherché UNE fois : `_a_epauler` parcourt toute la foule, et l'appeler
		# dans la condition PUIS dans le corps doublait la facture à chaque
		# image pour chaque homme de gang allié.
		var epaule := {}
		if genre == GANG and not proche.is_empty() and gang_allie(String(proche["cle"]), int(personne["gang"])):
			epaule = _a_epauler(personne, proche)

		if genre == FLIC:
			vitesse = float(CORPS[posmod(int(personne.get("corps", CORPS_POLICE)), CORPS.size())]["vitesse"])
			var proie := _proie_de_la_police(personne["p"], joueurs)
			if not proie.is_empty():
				direction = (Vector2(proie["p"]) - personne["p"]).normalized()
				_tirer_sur(personne, proie, delta)
			elif float(personne["minuterie"]) <= 0.0:
				personne["minuterie"] = _rng.randf_range(1.4, 3.0)
				direction = Vector2.RIGHT.rotated(_rng.randf() * TAU)
		elif genre == GANG and not epaule.is_empty():
			# Allié : il court vers CE QUI VOUS ATTAQUE et lui tire dessus.
			vitesse = VITESSE_GANG
			direction = (Vector2(epaule["p"]) - personne["p"]).normalized()
			_tirer_sur_pnj(personne, epaule, String(proche["cle"]), int(personne["gang"]))
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
	# Un homme du SWAT n'a pas la même arme qu'un îlotier, et un agent spécial
	# encore moins. Cadence, portée et dégâts viennent de son CORPS ; hors
	# police (les gangs), on retombe sur les valeurs d'origine.
	var corps: Dictionary = {}
	if int(tireur.get("genre", PIETON)) == FLIC:
		corps = CORPS[posmod(int(tireur.get("corps", CORPS_POLICE)), CORPS.size())]
	var portee := float(corps.get("portee", PORTEE_TIR_PNJ))
	var vers: Vector2 = Vector2(proie["p"]) - Vector2(tireur["p"])
	if vers.length() > portee:
		return
	tireur["recharge"] = float(corps.get("cadence", CADENCE_TIR_PNJ)) * _rng.randf_range(0.8, 1.4)
	var angle := vers.angle()
	emettre("tn", {"x": int(tireur["p"].x), "y": int(tireur["p"].y), "a": snapped(angle, 0.01)})
	# La balle d'un PNJ ne vole pas : elle touche ou elle rate, tiré au sort
	# selon la distance. Faire voler quatre-vingts projectiles de plus, c'est
	# quatre-vingts objets à diffuser pour un résultat que personne ne suit
	# à l'œil dans une rue de nuit.
	# Sept balles sur dix qui portent, avec quatre tireurs, c'est une mort
	# toutes les trois secondes à pied : on ne sortait plus de voiture.
	var chance: float = clamp(1.0 - vers.length() / portee, 0.10, 0.46)
	if _rng.randf() < chance:
		emettre("deg", {"j": proie["cle"], "d": int(corps.get("degat", DEGAT_BALLE_PNJ)), "k": "balle"})

## Qui un allié prend en charge : le flic qui vous poursuit, ou l'homme d'un
## gang qui vous tire dessus. Rien d'autre — un allié qui abattrait les
## passants pour vous faire plaisir viderait la rue en dix secondes et vous
## collerait la police sur le dos sans que vous ayez rien fait.
##
## ⚠ On cherche autour de L'ALLIÉ, pas autour du joueur : c'est lui qui doit
## avoir l'ennemi à portée de tir, sinon il part en courant traverser deux
## avenues pour un flic qu'il ne rejoindra jamais.
func _a_epauler(garde: Dictionary, joueur: Dictionary) -> Dictionary:
	var cle := String(joueur["cle"])
	var traque := etoiles(cle) > 0
	var meilleure := {}
	var distance := PORTEE_MAIN_FORTE * PORTEE_MAIN_FORTE
	for autre in gens:
		if int(autre["id"]) == int(garde["id"]):
			continue
		var genre_autre := int(autre["genre"])
		var vise := false
		if genre_autre == FLIC:
			vise = traque
		elif genre_autre == GANG:
			vise = int(autre["gang"]) != int(garde["gang"]) and gang_hostile(cle, int(autre["gang"]))
		if not vise:
			continue
		var d: float = Vector2(garde["p"]).distance_squared_to(autre["p"])
		if d < distance:
			distance = d
			meilleure = autre
	return meilleure

## Le tir d'un PNJ sur un PNJ. Il emprunte la même balle qui ne vole pas que
## `_tirer_sur` : elle touche ou elle rate, tirée au sort selon la distance.
## Le joueur épaulé ne marque RIEN — il n'a pas tiré. Ce qu'il gagne, c'est un
## ennemi de moins, et c'est déjà beaucoup.
func _tirer_sur_pnj(tireur: Dictionary, cible: Dictionary, pour: String, gang: int) -> void:
	if float(tireur["recharge"]) > 0.0:
		return
	var vers: Vector2 = Vector2(cible["p"]) - Vector2(tireur["p"])
	if vers.length() > PORTEE_TIR_PNJ:
		return
	tireur["recharge"] = CADENCE_TIR_PNJ * _rng.randf_range(0.8, 1.4)
	emettre("tn", {"x": int(tireur["p"].x), "y": int(tireur["p"].y), "a": snapped(vers.angle(), 0.01)})
	if float(_depuis_main_forte.get(pour, 0.0)) <= 0.0:
		_depuis_main_forte[pour] = DELAI_MAIN_FORTE
		emettre("aide", {"j": pour, "g": gang})
	var chance: float = clamp(1.0 - vers.length() / PORTEE_TIR_PNJ, 0.10, 0.46)
	if _rng.randf() >= chance:
		return
	cible["pv"] = int(cible["pv"]) - 1
	if int(cible["pv"]) > 0:
		return
	# Mort sans propriétaire : personne ne l'inscrit à son tableau, personne
	# n'écope de l'étoile. `_abattre` ferait les deux au nom du joueur épaulé.
	if retirer(gens, int(cible["id"])):
		paniquer(Vector2(cible["p"]), 260.0, 2.4)

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
		elif int(auto["genre"]) in [POMPIER, AMBULANCE]:
			_conduire_service(auto, delta, joueurs)
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

	# Sur une voie libre — avenue en diagonale, boulevard circulaire, place en
	# étoile — la file n'est plus un axe de la grille mais la tangente de la
	# voie. On la suit si l'on arrive à peu près dans son sens (ou qu'on la
	# suivait déjà) ; sinon on la traverse tout droit, comme un carrefour.
	var libre := plan.voie_libre_en(auto["p"])
	var sur_esplanade := not libre.is_empty() and String(libre["genre"]) == "esplanade"
	if sur_esplanade:
		libre = {}          # le parvis se traverse tout droit, comme une rue de la grille
	var suivait := bool(auto.get("libre", false))
	var suit_libre := false
	if not libre.is_empty():
		var t: Vector2 = libre["d"]
		var genre := String(libre["genre"])
		var alignee := direction.dot(t)
		if genre == "place" or abs(alignee) > 0.5 or suivait:
			suit_libre = true
			var meme_sens := genre == "place" or alignee >= 0.0
			if not meme_sens:
				t = -t
			var s: float = float(libre["s"]) * (1.0 if meme_sens else -1.0)
			# La place est serrée : on tourne vite et on ralentit.
			var raideur := 9.0 if genre == "place" else 3.5
			direction = direction.lerp(t, clampf(delta * raideur, 0.0, 1.0)).normalized()
			if genre == "place":
				auto["vitesse"] = minf(float(auto["vitesse"]), VITESSE_TRAFIC * 0.65)
				# Sortir de la place : quand on passe devant une avenue, une fois
				# sur deux environ, on la prend.
				var radial: Vector2 = (Vector2(auto["p"]) / PlanVille.PAS - Vector2(libre["c"])).normalized()
				for e in plan.sorties_de_la_place(int(libre["e"])):
					if Vector2(e).dot(radial) > 0.94 and _rng.randf() < delta * 1.4:
						direction = e
			auto["d"] = direction
			var droite_t := Vector2(-t.y, t.x)
			var ecart_libre := (PlanVille.FILE_BOULEVARD - s) * PlanVille.PAS
			auto["p"] = Vector2(auto["p"]) + droite_t * clampf(ecart_libre, -80.0 * delta, 80.0 * delta)
			auto["libre"] = true
			# Quitter un boulevard : au croisement d'une rue de la grille, une
			# fois de temps en temps, on tourne dedans.
			if genre != "place" and _rng.randf() < delta * 0.35:
				var colonne := int(floor(float(auto["p"].x) / PlanVille.PAS))
				var ligne := int(floor(float(auto["p"].y) / PlanVille.PAS))
				if PlanVille.est_voie(ligne) and abs(direction.x) > 0.3:
					direction = Vector2(signf(direction.x), 0.0)
					auto["d"] = direction
					auto["libre"] = false
				elif PlanVille.est_voie(colonne) and abs(direction.y) > 0.3:
					direction = Vector2(0.0, signf(direction.y))
					auto["d"] = direction
					auto["libre"] = false
	if not suit_libre and suivait:
		# On sort d'une voie libre : on se recale sur l'axe de la grille le plus
		# proche de notre cap, la file suit.
		auto["libre"] = false
		direction = Vector2(signf(direction.x), 0.0) if abs(direction.x) >= abs(direction.y) else Vector2(0.0, signf(direction.y))
		auto["d"] = direction

	if not suit_libre:
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
	# Le parvis de la place est un mur aussi : sans ça, les voitures y entraient
	# par les axes de la grille, s'y bloquaient les unes derrière les autres, et
	# la place était un parking. Celles qui y sont déjà le traversent pour sortir.
	var devant := plan.voie_libre_en(suivant + direction * 60.0)
	var parvis_devant := not sur_esplanade and not devant.is_empty() and String(devant["genre"]) == "esplanade"
	if parvis_devant or plan.dans_un_batiment(suivant + direction * 60.0, RAYON_AUTO):
		direction = Vector2(-direction.y, direction.x) if _rng.randf() < 0.5 \
			else Vector2(direction.y, -direction.x)
		if suit_libre:
			# Au bout d'une avenue en diagonale, on reprend la grille : une
			# perpendiculaire à un cap oblique n'est pas une rue.
			direction = Vector2(signf(direction.x), 0.0) if abs(direction.x) >= abs(direction.y) else Vector2(0.0, signf(direction.y))
			auto["libre"] = false
		auto["d"] = direction
		auto["vitesse"] = float(auto["vitesse"]) * 0.4
		suivant = plan.carrefour_proche(auto["p"]) if not suit_libre else Vector2(auto["p"])
	elif not suit_libre and _rng.randf() < delta * 0.55:
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

	# LE FOURGON DU SWAT (guide §5) : arrivé à portée, il s'arrête et VIDE
	# quatre hommes sur le trottoir. C'est ce qui rend trois étoiles autre
	# chose que « deux étoiles avec une voiture de plus » — on ne sème pas
	# quatre types à pied en tournant à droite.
	if int(auto.get("corps", CORPS_POLICE)) == CORPS_SWAT and not bool(auto.get("vide", false)) \
			and vers.length() < PORTEE_DEBARQUEMENT:
		auto["vide"] = true
		auto["vitesse"] = 0.0
		for i in DEBARQUEMENT:
			var autour: Vector2 = Vector2(auto["p"]) + Vector2.RIGHT.rotated(TAU * float(i) / float(DEBARQUEMENT)) * 40.0
			_poser_uniforme(plan.degager(autour, RAYON_PIETON)[0], CORPS_SWAT)
		emettre("swat", {"x": int(auto["p"].x), "y": int(auto["p"].y), "j": cible})
		return

	# LE CHAR ne poursuit pas, il CANONNE. Il roule moins vite que tout le
	# monde et tire un obus dès qu'il vous tient dans sa portée : le fuir est
	# facile, rester dans la rue ne l'est pas.
	if bool(auto.get("canon", false)):
		auto["recharge"] = max(0.0, float(auto.get("recharge", 0.0)) - delta)
		if vers.length() < PORTEE_OBUS and float(auto["recharge"]) <= 0.0:
			auto["recharge"] = CADENCE_OBUS
			_tirer_un_obus(auto, joueurs, cible)

	var allure: float = 300.0 + 42.0 * float(etoiles(cible))
	if bool(auto.get("canon", false)):
		allure = 190.0
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

## L'obus. Il ne vole pas non plus (comme les balles des PNJ) : il tombe où le
## char visait, et souffle tout ce qui est autour — voitures comprises. C'est
## la seule attaque du jeu qui ne fait aucune différence entre celui qui est à
## pied et celui qui est en tôle.
func _tirer_un_obus(auto: Dictionary, joueurs: Dictionary, cible: String) -> void:
	var ou: Vector2 = Vector2(joueurs[cible]["p"])
	# ⚠ On vise LÀ OÙ IL ÉTAIT, avec de la dispersion : un obus qui tombe pile
	# sur le joueur à chaque coup, c'est une mort par seconde et demie et plus
	# aucune raison de conduire.
	ou += Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(0.0, DISPERSION_OBUS)
	emettre("obus", {"x": int(ou.x), "y": int(ou.y),
		"dx": int(auto["p"].x), "dy": int(auto["p"].y)})
	for autre in joueurs:
		var j: Dictionary = joueurs[autre]
		if float(j.get("vie", 100.0)) <= 0.0:
			continue
		var loin: float = Vector2(j["p"]).distance_to(ou)
		if loin > SOUFFLE_OBUS:
			continue
		emettre("deg", {"j": String(autre), "d": int(DEGAT_OBUS * (1.0 - loin / SOUFFLE_OBUS * 0.5)),
			"k": "obus", "par": ""})
	for victime in autos:
		if int(victime["id"]) == int(auto["id"]) or int(victime["genre"]) == EPAVE:
			continue
		if String(victime["pilote"]) != "" or Vector2(victime["p"]).distance_to(ou) > SOUFFLE_OBUS:
			continue
		victime["pv"] = float(victime["pv"]) - DEGAT_OBUS * 1.6
		if float(victime["pv"]) <= 0.0:
			detruire_auto(victime, "")
	allumer(ou, 0.7)

# ------------------------------------------------------------ la police

## Qui répond, à ce niveau-là. Le tirage garde une part de police ordinaire
## même à six étoiles : une rue où il n'y a QUE des chars n'a plus l'air d'une
## ville en panique, elle a l'air d'un niveau de jeu.
func corps_pour(niveau: int) -> int:
	if niveau >= NIVEAU_ARMEE and _rng.randf() < 0.55:
		return CORPS_ARMEE
	if niveau >= NIVEAU_AGENTS and _rng.randf() < 0.55:
		return CORPS_AGENT
	if niveau >= NIVEAU_SWAT and _rng.randf() < 0.6:
		return CORPS_SWAT
	return CORPS_POLICE

func _poser_uniforme(ou: Vector2, corps: int) -> Dictionary:
	var fiche: Dictionary = CORPS[posmod(corps, CORPS.size())]
	var homme := {
		"id": _id(), "p": ou, "d": Vector2.RIGHT, "genre": FLIC, "gang": -1,
		"pv": int(fiche["pv"]), "etat": 0, "minuterie": 0.0, "recharge": 0.0, "a": 0.0,
		"corps": posmod(corps, CORPS.size()),
	}
	gens.append(homme)
	return homme

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
			_naitre_auto(joueurs, PATROUILLE, String(cle), corps_pour(niveau))

		# À deux étoiles, la police descend de voiture.
		if niveau >= 2 and gens.size() < plafond_gens() and _rng.randf() < delta * 0.6 * float(niveau - 1):
			_poser_uniforme(plan.point_de_rue(_rng, j["p"], 420.0, 760.0), corps_pour(niveau))

		# À quatre étoiles, on ferme les rues.
		# LE CHAR, au dernier cran. Un seul par joueur : deux, et la rue est un
		# champ de tir où l'on ne fait plus trois mètres.
		if niveau >= NIVEAU_ARMEE:
			var chars := 0
			for auto in autos:
				if bool(auto.get("canon", false)) and String(auto.get("cible", "")) == cle:
					chars += 1
			if chars == 0 and _rng.randf() < delta * 0.7:
				_naitre_auto(joueurs, PATROUILLE, String(cle), CORPS_ARMEE, true)

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
		_repercuter(cle, int(personne["gang"]), Vector2(personne["p"]), RESPECT_PERDU, RESPECT_GAGNE)
		_avancer_nettoyage(cle, int(personne["gang"]))
	_compter(cle, Vector2(personne["p"]), int(POINTS[quoi]), quoi, ecrase)
	_avancer_frenzy(cle, Vector2(personne["p"]))
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
		_repercuter(cle, int(auto.get("gang", 0)), Vector2(auto["p"]), RESPECT_PERDU * 0.6, RESPECT_GAGNE * 0.5)
	auto["genre"] = EPAVE
	auto["minuterie"] = 7.0
	auto["vitesse"] = 0.0
	crime(cle, "auto")
	_compter(cle, Vector2(auto["p"]), int(POINTS["auto"]), "auto", false)
	emettre("boum", {"x": int(auto["p"].x), "y": int(auto["p"].y)})
	# Une carcasse brûle : c'est de là que part tout le reste (la propagation,
	# les pompiers, la fumée qu'on voit de trois rues).
	allumer(Vector2(auto["p"]), 1.0)

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

# ------------------------------------------------------------ le feu

## Allumer un foyer. `force` 1 = un réservoir qui vient de partir, 0,5 = une
## flaque d'essence. Les foyers trop proches se fondent (leur force monte) :
## sinon une roquette dans un embouteillage en posait dix au même endroit.
func allumer(point: Vector2, force: float = 1.0) -> void:
	for f in feux:
		if Vector2(f["p"]).distance_to(point) < 34.0:
			f["force"] = minf(1.0, float(f["force"]) + force * 0.5)
			f["t"] = 0.0
			return
	if feux.size() >= FEUX_MAX:
		return
	feux.append({"id": _id(), "p": point, "force": clampf(force, 0.2, 1.0), "t": 0.0,
		"propage": _rng.randf_range(0.5, PROPAGATION), "ronge": RONGE})
	emettre("feu", {"x": int(point.x), "y": int(point.y), "f": int(force * 100.0)})

## Éteindre ce qui brûle autour d'un point (la lance d'un camion de pompiers).
func arroser(point: Vector2, rayon: float, delta: float) -> void:
	for f in feux:
		if Vector2(f["p"]).distance_to(point) <= rayon:
			f["force"] = float(f["force"]) - delta * 0.85

func feu_le_plus_proche(point: Vector2) -> Dictionary:
	var meilleur: Dictionary = {}
	var distance := INF
	for f in feux:
		var d: float = Vector2(f["p"]).distance_to(point)
		if d < distance:
			distance = d
			meilleur = f
	return meilleur

## La vie d'un incendie : il monte, il brûle ce qu'il touche, il essaie de
## sauter sur une voiture voisine, il ronge le mur d'à côté, puis il meurt.
func _animer_les_feux(delta: float, joueurs: Dictionary) -> void:
	if feux.is_empty():
		return
	var restants: Array = []
	for f in feux:
		f["t"] = float(f["t"]) + delta
		# La courbe : plein feu pendant les deux tiers, puis il baisse.
		var age := float(f["t"]) / DUREE_FEU
		if age > 0.62:
			f["force"] = float(f["force"]) - delta / (DUREE_FEU * 0.5)
		if float(f["force"]) <= 0.05 or age > 1.4:
			emettre("eteint", {"x": int(f["p"].x), "y": int(f["p"].y)})
			continue
		restants.append(f)
		var p: Vector2 = f["p"]
		var force := float(f["force"])
		var rayon := RAYON_FEU * (0.55 + 0.45 * force)

		# Ce qui est dedans souffre : passants, joueurs, voitures.
		for personne in gens:
			if Vector2(personne["p"]).distance_to(p) < rayon:
				personne["pv"] = int(personne["pv"]) - int(DEGAT_FEU * force * delta)
				if int(personne["pv"]) <= 0:
					_abattre(personne, "", true)
					break
		paniquer(p, rayon + 90.0, 1.2)

		# Sauter sur une voiture voisine : elle explose et allume son propre
		# foyer. C'est ce qui fait qu'un carambolage part en chaîne.
		f["propage"] = float(f["propage"]) - delta
		if float(f["propage"]) <= 0.0:
			f["propage"] = PROPAGATION * _rng.randf_range(0.7, 1.5)
			for auto in autos:
				if int(auto["genre"]) == EPAVE or String(auto["pilote"]) != "":
					continue
				if Vector2(auto["p"]).distance_to(p) < rayon * 1.15 and _rng.randf() < 0.55 * force:
					detruire_auto(auto, "")
					allumer(Vector2(auto["p"]), 0.9)
					break

		# Ronger le mur : un cube part, la façade se noircit là où ça brûle.
		f["ronge"] = float(f["ronge"]) - delta
		if float(f["ronge"]) <= 0.0:
			f["ronge"] = RONGE * _rng.randf_range(0.8, 1.4)
			var trouve := plan.immeuble_a(p, 26.0)
			if not trouve.is_empty():
				var hauteur := 1.0 + float(f["t"]) * 0.12   # le feu monte le long du mur
				var cibles := VoxelsCarnage.voxels_autour_de(trouve["b"], Decor.vers3d(p, hauteur), 1.6)
				if not cibles.is_empty():
					_casser(int(trouve["id"]), [cibles[_rng.randi_range(0, cibles.size() - 1)]])
	feux = restants

# ------------------------------------------------------------ les secours

## Les services d'urgence : un camion de pompiers pour les incendies, un
## Medicar pour les blessés. Ils ne sont pas décoratifs — le camion ÉTEINT
## (sinon un quartier entier finirait par brûler), le Medicar relève un joueur
## à terre bien plus vite que l'attente. Un seul de chaque à la fois : deux
## camions au même feu, c'est un embouteillage, pas une caserne.
const PORTEE_LANCE := 150.0       ## px : la lance porte de loin, on la voit arroser
const PORTEE_SOIN := 90.0
const ATTENTE_SECOURS := 5.0      ## le temps qu'ils mettent à être prévenus
var _depuis_pompier := 0.0
var _depuis_medicar := 0.0

func _depecher_les_secours(delta: float, joueurs: Dictionary) -> void:
	_depuis_pompier += delta
	_depuis_medicar += delta
	var pompiers := 0
	var medicars := 0
	for auto in autos:
		if int(auto["genre"]) == POMPIER:
			pompiers += 1
		elif int(auto["genre"]) == AMBULANCE:
			medicars += 1

	# Un camion par tranche de trois foyers, deux au plus : au-delà c'est un
	# convoi qui se gêne lui-même dans les rues.
	var camions_voulus: int = clampi(int(ceil(float(feux.size()) / 3.0)), 0, 2)
	if pompiers < camions_voulus and _depuis_pompier >= ATTENTE_SECOURS:
		_depuis_pompier = 0.0
		_naitre_secours(joueurs, POMPIER, 18)

	if medicars == 0 and _depuis_medicar >= ATTENTE_SECOURS and _un_blesse(joueurs):
		_depuis_medicar = 0.0
		_naitre_secours(joueurs, AMBULANCE, 15)

func _un_blesse(joueurs: Dictionary) -> bool:
	for cle in joueurs:
		if float(joueurs[cle].get("vie", 100.0)) <= 0.0:
			return true
	return false

func _naitre_secours(joueurs: Dictionary, genre: int, modele: int) -> void:
	var autour := _autour_d_un_joueur(joueurs)
	var pose := plan.point_de_chaussee(_rng, autour, NAISSANCE_MIN, NAISSANCE_MAX)
	if not _degage_des_autos(pose["p"]):
		return
	var direction: Vector2 = pose["d"]
	autos.append({
		"id": _id(), "p": pose["p"], "a": direction.angle(), "d": direction,
		"vitesse": 0.0, "genre": genre, "gang": -1,
		"pv": PV_AUTO * 2, "pilote": "", "cible": "", "minuterie": 0.0, "recharge": 0.0,
		"modele": modele, "garee": false, "service": 0.0,
	})

## Un véhicule de service roule vers ce qu'il doit traiter et agit sur place.
## Il conduit comme une patrouille (tout droit, en longeant les murs) : un
## camion qui respecte les sens interdits n'arrive jamais.
func _conduire_service(auto: Dictionary, delta: float, joueurs: Dictionary) -> void:
	var cible := Vector2.ZERO
	var trouve := false
	if int(auto["genre"]) == POMPIER:
		var f := feu_le_plus_proche(auto["p"])
		if not f.is_empty():
			cible = f["p"]
			trouve = true
			if Vector2(auto["p"]).distance_to(cible) <= PORTEE_LANCE:
				arroser(cible, PORTEE_LANCE, delta)
				auto["service"] = float(auto.get("service", 0.0)) + delta
	else:
		var meilleure := INF
		for cle in joueurs:
			if float(joueurs[cle].get("vie", 100.0)) > 0.0:
				continue
			var d: float = Vector2(joueurs[cle]["p"]).distance_to(auto["p"])
			if d < meilleure:
				meilleure = d
				cible = joueurs[cle]["p"]
				trouve = true
				if d <= PORTEE_SOIN:
					emettre("secours", {"j": String(cle)})
	if not trouve:
		# Plus rien à faire : le véhicule reprend la circulation ordinaire et
		# se fera oublier par le recyclage.
		auto["genre"] = CIVILE
		return
	var vers: Vector2 = cible - Vector2(auto["p"])
	# À l'arrêt devant le feu : on ne lui roule pas dedans.
	var freine: bool = vers.length() < (PORTEE_LANCE * 0.55 if int(auto["genre"]) == POMPIER else PORTEE_SOIN * 0.6)
	var direction := vers.normalized()
	auto["vitesse"] = move_toward(float(auto["vitesse"]), 0.0 if freine else 340.0, 460.0 * delta)
	var suivant: Vector2 = Vector2(auto["p"]) + direction * float(auto["vitesse"]) * delta
	var degage := plan.degager(suivant, RAYON_AUTO)
	if bool(degage[1]):
		var tangente := Vector2(-direction.y, direction.x)
		suivant = plan.degager(Vector2(auto["p"]) + tangente * float(auto["vitesse"]) * delta, RAYON_AUTO)[0]
		auto["vitesse"] = float(auto["vitesse"]) * 0.8
	else:
		suivant = degage[0]
	auto["p"] = suivant
	if not freine:
		auto["d"] = direction
		auto["a"] = direction.angle()

# ------------------------------------------------------------ les à-côtés
#
## LES À-CÔTÉS (guide §4.3) : ce qu'on trouve dans la rue sans que personne
## l'ait demandé. Ils vivent chez l'HÔTE, comme les caisses — un ramassage est
## un objet du monde, pas une décision de client.
##
## ⚠ Pourquoi ils comptent : sans eux, une manche de Carnage est un bac à
## sable où l'on tourne en rond entre deux contrats. Un colis qui brille à
## trois rues donne une RAISON de tourner à droite.
enum { R_COLIS, R_FRENZY }
const COLIS_EN_VILLE := 8         ## ce que la ville garde de colis posés
const COLIS_OBJECTIF := 10        ## la collection complète, et sa prime
const PRIME_COLIS := 220
const PRIME_COLLECTION := 3000
const FRENZY_EN_VILLE := 2
const DUREE_FRENZY := 30.0
const OBJECTIF_FRENZY := 8
const PRIME_FRENZY := 1800
## L'arme imposée fait le défi : à la roquette on cherche la foule, à la
## mitraillette on cherche le trottoir. C'est ce qui distingue deux Frenzy.
const ARMES_FRENZY := ["mitraillette", "roquette", "mitraillette"]
var ramassages: Array = []        ## {id, p, genre, arme}
var colis: Dictionary = {}        ## cle -> colis trouvés
var frenzies: Dictionary = {}     ## cle -> {reste, fait, objectif, arme}
var _depuis_ramassage := 0.0

func _semer_les_a_cotes(delta: float, joueurs: Dictionary) -> void:
	if joueurs.is_empty():
		return
	_depuis_ramassage += delta
	if _depuis_ramassage < 1.5:
		return
	_depuis_ramassage = 0.0
	var colis_poses := 0
	var frenzy_poses := 0
	for r in ramassages:
		if int(r["genre"]) == R_COLIS:
			colis_poses += 1
		else:
			frenzy_poses += 1
	# ⚠ Loin, mais pas trop : posé à cent pixels, le colis se ramasse sans
	# avoir été cherché ; posé à deux mille, on ne le voit jamais.
	if colis_poses < COLIS_EN_VILLE:
		ramassages.append({"id": _id(), "genre": R_COLIS, "arme": "",
			"p": plan.point_de_rue(_rng, _autour_d_un_joueur(joueurs), 420.0, 1500.0)})
	if frenzy_poses < FRENZY_EN_VILLE:
		ramassages.append({"id": _id(), "genre": R_FRENZY,
			"arme": String(ARMES_FRENZY[_rng.randi_range(0, ARMES_FRENZY.size() - 1)]),
			"p": plan.point_de_rue(_rng, _autour_d_un_joueur(joueurs), 600.0, 1700.0)})

## Ramasser. C'est l'hôte qui tranche — deux joueurs sur le même colis à cent
## millisecondes près, et le premier arrivé est celui que l'hôte a vu.
func ramasser_a_cote(id: int, cle: String, ou: Vector2) -> void:
	for r in ramassages:
		if int(r["id"]) != id:
			continue
		var genre := int(r["genre"])
		retirer(ramassages, id)
		if genre == R_COLIS:
			colis[cle] = int(colis.get(cle, 0)) + 1
			var combien := int(colis[cle])
			_compter(cle, ou, PRIME_COLIS, "colis", false)
			emettre("colis", {"j": cle, "n": combien, "sur": COLIS_OBJECTIF})
			if combien == COLIS_OBJECTIF:
				_compter(cle, ou, PRIME_COLLECTION, "collection", false)
				emettre("colis", {"j": cle, "n": combien, "sur": COLIS_OBJECTIF, "fini": true})
		else:
			lancer_frenzy(cle, String(r["arme"]))
		return

## KILL FRENZY. Une arme, un compte, un chrono. Le joueur reçoit l'arme :
## sans elle, le défi consiste à courir chercher une caisse, et le chrono est
## déjà fini quand il commence.
func lancer_frenzy(cle: String, arme: String) -> void:
	frenzies[cle] = {"reste": DUREE_FRENZY, "fait": 0, "objectif": OBJECTIF_FRENZY, "arme": arme}
	emettre("frenzy", {"j": cle, "e": "debut", "a": arme, "n": OBJECTIF_FRENZY,
		"f": 0, "r": int(DUREE_FRENZY)})

func _avancer_les_frenzies(delta: float) -> void:
	for cle in frenzies.keys():
		var f: Dictionary = frenzies[cle]
		f["reste"] = float(f["reste"]) - delta
		if float(f["reste"]) > 0.0:
			continue
		frenzies.erase(cle)
		emettre("frenzy", {"j": String(cle), "e": "perdu", "a": String(f["arme"]),
			"n": int(f["objectif"]), "f": int(f["fait"]), "r": 0})

## Une victime de plus pendant un Frenzy. Appelé depuis `_abattre` : c'est le
## même compte que le score, on ne recompte rien à côté.
func _avancer_frenzy(cle: String, ou: Vector2) -> void:
	if not frenzies.has(cle):
		return
	var f: Dictionary = frenzies[cle]
	f["fait"] = int(f["fait"]) + 1
	if int(f["fait"]) < int(f["objectif"]):
		emettre("frenzy", {"j": cle, "e": "avance", "a": String(f["arme"]),
			"n": int(f["objectif"]), "f": int(f["fait"]), "r": int(ceil(float(f["reste"])))})
		return
	frenzies.erase(cle)
	_compter(cle, ou, PRIME_FRENZY, "frenzy", false)
	emettre("frenzy", {"j": cle, "e": "gagne", "a": String(f["arme"]),
		"n": int(f["objectif"]), "f": int(f["fait"]), "r": 0})

## Le client monte dans le taxi : il quitte le trottoir. C'est l'hôte qui le
## retire — un client effacé par le seul chauffeur resterait là pour les trois
## autres joueurs, qui le verraient marcher pendant toute la course.
func embarquer_client(id: int) -> bool:
	for personne in gens:
		if int(personne["id"]) == id and int(personne["genre"]) == PIETON:
			return retirer(gens, id)
	return false

## Payer un service rendu qui n'est pas une victime : une course de taxi, une
## cascade. Passe par le même chemin que tout le reste — le tableau, l'effet
## de gain et l'argent sur soi sont ceux du jeu, pas des copies.
func payer(cle: String, ou: Vector2, montant: int, quoi: String) -> void:
	_compter(cle, ou, max(0, montant), quoi, false)

# ------------------------------------------------------------ les pièges
#
## MINES ET TACHES D'HUILE — ce que l'atelier vend et qu'on sème derrière soi.
##
## Ils vivent chez l'HÔTE, comme les caisses et les barrages : c'est lui qui
## décide qu'une voiture a roulé dessus. Un client qui annoncerait ses propres
## victimes ferait sauter la ville entière depuis son navigateur.
##
## ⚠ Une mine s'AMORCE. Sans le délai, elle explosait sous la voiture qui
## venait de la lâcher — on payait sept cents dollars pour se tuer soi-même,
## une fois, et on n'en rachetait plus jamais.
enum { MINE, HUILE }
const PIEGES_MAX := 18            ## au-delà, la ville est un champ de mines
const AMORCE_MINE := 1.4          ## secondes avant qu'elle morde
const DUREE_MINE := 45.0
const DUREE_HUILE := 26.0
const DEGAT_MINE := 70.0          ## une voiture n'y survit pas deux fois
var pieges: Array = []            ## {id, p, genre, par, reste, amorce}

## LA BOMBE (guide §7.2) : elle ne se déclenche pas à distance, elle attend
## qu'on soit SORTI. C'est le piège à voleur de GTA 2 — on laisse sa voiture
## ouverte au milieu de la rue, quelqu'un monte, et la rue change de forme.
##
## ⚠ Elle est armée par l'HÔTE et attachée à l'identifiant du VÉHICULE, pas au
## joueur : sinon un joueur qui se déconnecte emporterait la bombe avec lui et
## la voiture piégée resterait piégée pour l'éternité.
var bombes: Dictionary = {}       ## id de véhicule -> {reste, par}
const BOMBE_DELAI := 6.0

func armer_bombe(cle: String, id: int) -> void:
	bombes[id] = {"reste": BOMBE_DELAI, "par": cle}

func _animer_les_bombes(delta: float) -> void:
	for id in bombes.keys():
		var fiche: Dictionary = bombes[id]
		fiche["reste"] = float(fiche["reste"]) - delta
		if float(fiche["reste"]) > 0.0:
			continue
		bombes.erase(id)
		for auto in autos:
			if int(auto["id"]) != int(id) or int(auto["genre"]) == EPAVE:
				continue
			# Celui qui a posé la bombe marque la voiture : c'est son piège,
			# même s'il est à trois rues de là quand elle saute.
			detruire_auto(auto, String(fiche["par"]))
			break

func poser_piege(cle: String, ou: Vector2, genre: int) -> int:
	if pieges.size() >= PIEGES_MAX:
		# Le plus vieux s'efface : refuser la pose punirait celui qui a payé,
		# et il ne verrait même pas pourquoi.
		retirer(pieges, int(pieges[0]["id"]))
	var id := _id()
	pieges.append({"id": id, "p": ou, "genre": genre, "par": cle,
		"reste": DUREE_MINE if genre == MINE else DUREE_HUILE,
		"amorce": AMORCE_MINE if genre == MINE else 0.0})
	return id

func _animer_les_pieges(delta: float, joueurs: Dictionary) -> void:
	var restants: Array = []
	for piege in pieges:
		piege["reste"] = float(piege["reste"]) - delta
		piege["amorce"] = max(0.0, float(piege["amorce"]) - delta)
		if float(piege["reste"]) <= 0.0:
			retirer(pieges, int(piege["id"]))
			continue
		if float(piege["amorce"]) > 0.0:
			restants.append(piege)
			continue
		if int(piege["genre"]) == MINE:
			if _mordre(piege, joueurs):
				retirer(pieges, int(piege["id"]))
				continue
		else:
			_faire_glisser(piege, joueurs)
		restants.append(piege)
	pieges = restants

## Une mine ne saute qu'UNE fois : elle rend vrai, et l'appelant la retire.
func _mordre(piege: Dictionary, joueurs: Dictionary) -> bool:
	var ou: Vector2 = piege["p"]
	var par := String(piege["par"])
	for auto in autos:
		if String(auto["pilote"]) != "" or bool(auto.get("garee", false)) or int(auto["genre"]) == EPAVE:
			continue
		if Vector2(auto["p"]).distance_to(ou) > PlanVille.RAYON_MINE:
			continue
		# La mine porte le nom de celui qui l'a posée : c'est SA victime, il
		# la marque, et le gang de la voiture le lui reproche.
		detruire_auto(auto, par)
		emettre("boum", {"x": int(ou.x), "y": int(ou.y)})
		return true
	for cle in joueurs:
		var j: Dictionary = joueurs[cle]
		if bool(j.get("pied", true)) or float(j.get("vie", 100.0)) <= 0.0:
			continue
		if Vector2(j["p"]).distance_to(ou) > PlanVille.RAYON_MINE:
			continue
		emettre("deg", {"j": String(cle), "d": int(DEGAT_MINE), "k": "mine", "par": par})
		emettre("boum", {"x": int(ou.x), "y": int(ou.y)})
		return true
	return false

## L'huile ne fait pas de dégâts : elle fait PERDRE LE CAP. C'est ce qui la
## rend intéressante en poursuite — le poursuivant ne meurt pas, il part dans
## le décor et se retrouve trois rues en arrière.
##
## ⚠ Elle glisse aussi sous celui qui l'a posée. Une flaque inoffensive pour
## son propriétaire, c'est une arme sans risque : on en sème une devant chaque
## carrefour et on ne se retourne jamais.
func _faire_glisser(piege: Dictionary, joueurs: Dictionary) -> void:
	var ou: Vector2 = piege["p"]
	for auto in autos:
		if String(auto["pilote"]) != "" or bool(auto.get("garee", false)):
			continue
		if Vector2(auto["p"]).distance_to(ou) > PlanVille.RAYON_HUILE:
			continue
		var d: Vector2 = Vector2(auto["d"]).rotated(_rng.randf_range(-1.5, 1.5))
		auto["d"] = d
		auto["a"] = d.angle()
		auto["vitesse"] = float(auto["vitesse"]) * 0.45
	for cle in joueurs:
		var j: Dictionary = joueurs[cle]
		if bool(j.get("pied", true)) or float(j.get("vie", 100.0)) <= 0.0:
			continue
		if Vector2(j["p"]).distance_to(ou) > PlanVille.RAYON_HUILE:
			continue
		emettre("glisse", {"j": String(cle)})

# ------------------------------------------------------------ le train

## LE TRAIN (§1.3). La ville a toujours eu sa voie ferrée — une droite en biais
## d'un bord à l'autre, le seul trait qui ne suive pas la grille — mais rien
## n'y roulait : c'était une texture peinte par le nuanceur du sol. Deux rames
## y circulent maintenant, et elles font les deux choses que le guide demande.
##
##   — ON LE PREND. Il marque l'arrêt tous les `ECART_GARES` px. À quai,
##     `E` fait monter comme dans une voiture ; il traverse alors la ville en
##     ligne droite, plus vite qu'aucune carrosserie, sans un feu ni un
##     barrage, et la police ne monte pas dedans.
##   — ON SE FAIT ÉCRASER PAR LUI. Rien ne l'arrête : ni un piéton, ni une
##     berline en travers, ni le char de l'armée. C'est le seul danger du jeu
##     qui ne vise personne, ne se combat pas et ne se négocie pas — il passe,
##     à l'heure. Une poursuite qui coupe la voie au mauvais moment se termine
##     là, pour le poursuivi comme pour les six voitures derrière.
##
## Il vit chez l'hôte comme le reste de la ville et ne voyage que par son
## ABSCISSE le long de la voie : la trajectoire est une droite connue des
## quatre joueurs, il serait absurde d'en diffuser des coordonnées.
const TRAINS := 2                 ## deux rames, lancées à l'opposé l'une de l'autre
const VITESSE_TRAIN := 940.0      ## px/s — au-dessus de VITESSE_MAX d'une voiture
const FREINAGE_TRAIN := 380.0     ## px/s² : un train ne pile pas, il glisse
const ECART_GARES := 11000.0      ## px entre deux quais (~110 tuiles)
const ARRET_EN_GARE := 7.0        ## s portes ouvertes — le temps d'y courir
const WAGONS := 3                 ## motrice + deux voitures
const LONG_WAGON := 96.0          ## px
const ECART_WAGON := 12.0
const LARGEUR_TRAIN := 30.0       ## px de part et d'autre de l'axe : ce qu'il balaie
const QUAI := 150.0               ## px : d'où l'on peut monter, une fois à l'arrêt
const DEGAT_TRAIN := 400.0        ## on ne survit pas à un train, ce n'est pas un réglage
var trains: Array = []            ## {id, s, sens, v, arret}
var _voie: Dictionary = {}

## La voie ferrée sous forme PARAMÉTRÉE. `plan.rail()` la donne comme une
## équation `n·p = c` en unités 3D — parfait pour un nuanceur qui teste « suis-je
## sur le ballast ? », inutilisable pour un train, qui se repère par son
## abscisse le long de la voie et pas par sa distance à un axe.
##
## ⚠ Le passage en pixels de jeu ne s'oublie pas : `rail()` travaille en unités
## 3D (une tuile = 10), la simulation en pixels (une tuile = 100). Sans la
## division par `Decor.ECHELLE`, les deux rames roulaient dans le coin
## nord-ouest de la carte, sur une voie dix fois trop courte.
func voie() -> Dictionary:
	if not _voie.is_empty():
		return _voie
	var r := plan.rail()
	var n := Vector2(r.x, r.y)
	var origine := n * (r.z / Decor.ECHELLE)
	var d := Vector2(-n.y, n.x)
	# On coupe la droite aux bords de la carte : sans ça le terminus tombait
	# à des kilomètres hors de la ville et le train mettait deux minutes à
	# revenir d'un néant que personne ne voit.
	var bornes := Vector2(float(PlanVille.COLONNES) * PlanVille.PAS,
		float(PlanVille.LIGNES) * PlanVille.PAS)
	var t0 := -1.0e12
	var t1 := 1.0e12
	for axe in 2:
		var dd: float = d.x if axe == 0 else d.y
		if absf(dd) < 0.0001:
			continue
		var o: float = origine.x if axe == 0 else origine.y
		var borne: float = bornes.x if axe == 0 else bornes.y
		var a := (0.0 - o) / dd
		var b := (borne - o) / dd
		t0 = maxf(t0, minf(a, b))
		t1 = minf(t1, maxf(a, b))
	_voie = {"o": origine, "d": d, "n": n, "t0": t0 + 200.0, "t1": t1 - 200.0}
	return _voie

## Le point de la voie à cette abscisse. C'est la seule fonction dont le client
## a besoin pour poser une rame : l'hôte ne diffuse qu'un nombre.
func point_de_voie(s: float) -> Vector2:
	var v := voie()
	return Vector2(v["o"]) + Vector2(v["d"]) * s

func cap_de_voie() -> float:
	return Vector2(voie()["d"]).angle()

## Les quais, régulièrement espacés depuis le terminus sud. Ils ne sont pas
## posés à la main : la voie change avec le code de la manche, une liste écrite
## en dur planterait des gares dans la rivière une manche sur deux.
func gares() -> Array:
	var v := voie()
	var liste: Array = []
	var s: float = float(v["t0"]) + ECART_GARES * 0.5
	while s < float(v["t1"]):
		liste.append(s)
		s += ECART_GARES
	return liste

## La prochaine gare DEVANT soi, ou le terminus s'il n'y en a plus. La marge de
## dix pixels est ce qui empêche un train qui vient de repartir de considérer
## le quai qu'il quitte comme son prochain arrêt et de rester planté là.
func _prochaine_gare(s: float, sens: float) -> float:
	var v := voie()
	var mieux: float = float(v["t1"]) if sens > 0.0 else float(v["t0"])
	for g in gares():
		var g_f := float(g)
		if sens > 0.0 and g_f > s + 10.0:
			mieux = minf(mieux, g_f)
		elif sens < 0.0 and g_f < s - 10.0:
			mieux = maxf(mieux, g_f)
	return mieux

func _mettre_les_rames_en_ligne() -> void:
	var v := voie()
	var longueur: float = float(v["t1"]) - float(v["t0"])
	for k in TRAINS:
		# Réparties sur la ligne et lancées en sens contraires : deux rames qui
		# partent du même bout dans le même sens, c'est une seule rame.
		trains.append({"id": _id(), "sens": 1.0 if k % 2 == 0 else -1.0, "v": 0.0,
			"arret": 0.0, "freine": false, "s": float(v["t0"]) + longueur * (float(k) + 0.5) / float(TRAINS)})

static func longueur_de_rame() -> float:
	return float(WAGONS) * LONG_WAGON + float(WAGONS - 1) * ECART_WAGON

func _animer_les_trains(delta: float, joueurs: Dictionary) -> void:
	if trains.is_empty():
		_mettre_les_rames_en_ligne()
	var v := voie()
	for t in trains:
		if float(t["arret"]) > 0.0:
			t["v"] = 0.0
			t["arret"] = float(t["arret"]) - delta
			if float(t["arret"]) <= 0.0:
				emettre("train", {"i": int(t["id"]), "e": "part"})
			continue
		var sens := float(t["sens"])
		var s := float(t["s"])
		var but := _prochaine_gare(s, sens)
		var reste: float = absf(but - s)
		var vitesse := float(t["v"])
		# La distance qu'il faut pour s'arrêter à cette vitesse-là. Sans elle,
		# le train pilait sur le premier pixel du quai : un arrêt instantané à
		# neuf cents pixels par seconde se voit à l'image près.
		var frein: float = vitesse * vitesse / (2.0 * FREINAGE_TRAIN)
		# ⚠ LE FREINAGE SE VERROUILLE. Recalculé à chaque image, il se
		# DÉBRANCHAIT tout seul : le train ralentissait, sa distance d'arrêt
		# fondait avec le carré de sa vitesse, la condition redevenait fausse à
		# soixante mètres du quai — et il RELANÇAIT. Le banc le voyait passer
		# devant sept quais d'affilée sans s'arrêter une fois, à chaque fois en
		# ralentissant juste assez pour donner l'illusion d'y penser.
		var freine := bool(t.get("freine", false)) or reste <= frein + 30.0
		t["freine"] = freine
		vitesse = move_toward(vitesse, 0.0 if freine else VITESSE_TRAIN,
			FREINAGE_TRAIN * delta)
		# Deux façons d'être arrivé : le pas suivant dépasserait le quai, ou
		# l'on n'avance plus assez pour que ça vaille encore le nom de rouler.
		# Sans la seconde, une rame arrêtée à quatorze pixels du quai y restait.
		if freine and (vitesse * delta >= reste - 2.0 or vitesse <= 40.0):
			s = but
			vitesse = 0.0
			t["freine"] = false
			t["arret"] = ARRET_EN_GARE
			emettre("train", {"i": int(t["id"]), "e": "quai",
				"x": int(point_de_voie(s).x), "y": int(point_de_voie(s).y)})
			# ⚠ LE DEMI-TOUR SE FAIT ICI, À L'ARRÊT, et nulle part ailleurs.
			# Testé à chaque image sur « suis-je au bout de la ligne ? », il
			# s'appliquait AUSSI à la première image du départ — la rame était
			# encore à un dixième de pixel du terminus, elle repartait, et se
			# retournait aussitôt. Elle passait sa vie à faire des demi-tours
			# sur place au bout du quai : cinquante-cinq en cinq minutes.
			if s <= float(v["t0"]) + 1.0 or s >= float(v["t1"]) - 1.0:
				t["sens"] = -sens
		else:
			s += sens * vitesse * delta
		t["s"] = s
		t["v"] = vitesse
		_faucher(t, joueurs)

## Ce que la rame balaie. On travaille dans le repère de la VOIE (abscisse le
## long, écart de côté) plutôt qu'en distances point à point : une rame fait
## trois cent trente pixels de long pour soixante de large, un simple rayon
## autour de sa tête laisserait passer le quart arrière.
##
## ⚠ Un train À L'ARRÊT ne fauche personne — sinon la portière ouverte tuait
## celui qui vient la prendre, et l'on ne pouvait tout simplement pas monter.
func _faucher(t: Dictionary, joueurs: Dictionary) -> void:
	if float(t["v"]) < 60.0:
		return
	var v := voie()
	var o: Vector2 = v["o"]
	var d: Vector2 = v["d"]
	var n: Vector2 = v["n"]
	var tete := float(t["s"])
	var queue := tete - float(t["sens"]) * longueur_de_rame()
	var bas: float = minf(tete, queue)
	var haut: float = maxf(tete, queue)
	var sous_la_rame := func(p: Vector2) -> bool:
		var relatif := p - o
		if absf(relatif.dot(n)) > LARGEUR_TRAIN:
			return false
		var le_long := relatif.dot(d)
		return le_long >= bas and le_long <= haut
	for personne in gens.duplicate():
		if sous_la_rame.call(Vector2(personne["p"])):
			# Personne ne marque ce point : le train n'appartient à aucun
			# joueur. Passer `""` évite d'attribuer un meurtre à l'hôte.
			_abattre(personne, "", true)
	for auto in autos.duplicate():
		if int(auto["genre"]) == EPAVE or String(auto["pilote"]) != "":
			continue
		if sous_la_rame.call(Vector2(auto["p"])):
			detruire_auto(auto, "")
	for cle in joueurs:
		var j: Dictionary = joueurs[cle]
		if float(j.get("vie", 100.0)) <= 0.0 or bool(j.get("train", false)):
			continue
		if sous_la_rame.call(Vector2(j["p"])):
			emettre("deg", {"j": String(cle), "d": int(DEGAT_TRAIN), "k": "train"})

## La rame à quai la plus proche d'un point, ou {} : c'est ce que le client
## interroge avant d'ouvrir la portière. Elle vit ici et pas chez lui pour que
## la règle de montée soit la même que celle du fauchage — un quai où l'on peut
## monter et se faire écraser en même temps serait une farce.
func rame_a_quai(point: Vector2) -> Dictionary:
	var v := voie()
	var o: Vector2 = v["o"]
	var d: Vector2 = v["d"]
	for t in trains:
		if float(t["arret"]) <= 0.0:
			continue
		var tete := float(t["s"])
		var queue := tete - float(t["sens"]) * longueur_de_rame()
		var le_long := (point - o).dot(d)
		if le_long < minf(tete, queue) - QUAI or le_long > maxf(tete, queue) + QUAI:
			continue
		if absf((point - o).dot(Vector2(v["n"]))) > QUAI:
			continue
		return t
	return {}

func train_par_id(id: int) -> Dictionary:
	for t in trains:
		if int(t["id"]) == id:
			return t
	return {}

# ------------------------------------------------------------ le compacteur

## LE COMPACTEUR (§1.3) : on y entre au volant, on en ressort à pied, plus
## riche et armé. C'est la seule façon du jeu de FAIRE DISPARAÎTRE une voiture
## — le garage la repeint, l'explosion en laisse une carcasse qui brûle, la
## casse n'en laisse rien.
##
## Pourquoi il paie ce qu'il paie : une berline vaut peu, un camion vaut le
## déplacement. Le tarif suit la LONGUEUR du gabarit (`VoxelsCarnage.GABARITS`)
## parce que c'est la seule mesure qui existe déjà pour les vingt-huit modèles,
## qu'elle est celle qu'on voit à l'écran, et qu'une table de prix écrite à la
## main ligne par ligne aurait vieilli au premier véhicule ajouté.
##
## ⚠ LA CASSE EST AU BORD DE LA VOIE FERRÉE, et sa place n'est PAS un nouveau
## genre de lieu dans `PlanVille`. Deux raisons : la bande du ballast est la
## seule de la ville que personne n'habite (c'est là qu'on entasse des
## carcasses), et le plan de la ville est retravaillé en parallèle — y ajouter
## un septième genre de lieu, c'est se donner rendez-vous dans un conflit.
## ⚠ CES DEUX CHIFFRES SONT CEUX DU BALLAST. La bande de la voie fait
## `LARGEUR_RAIL` = 2,2 tuiles, soit 110 px de chaque côté de l'axe. Écartée de
## 200 px avec une dalle de 190, la casse tombait ENTIÈREMENT hors du ballast :
## elle se posait sur le pâté d'à côté, par-dessus les immeubles. Écartée de 68
## avec une dalle de 110, elle va de 13 à 123 px de l'axe — dedans, sans
## recouvrir les rails, et le convoi (`LARGEUR_TRAIN`, 30 px) passe à côté sans
## toucher la voiture garée dessus.
const ECART_CASSE := 68.0         ## px : de combien la casse s'écarte de l'axe
const RAYON_CASSE := 55.0         ## px : la dalle sous laquelle on est broyé
## ⚠ LA CASSE NE DOIT PAS ÊTRE LE MEILLEUR REVENU DU JEU. À 240 + 34 par
## voxel, une citadine ramassée au coin de la rue valait 750 $ — plus qu'un
## contrat de gang (620), sans risque et sans une étoile. On volait, on roulait
## jusqu'au ballast, on recommençait : tout le reste du jeu devenait facultatif.
## À 120 + 18, la citadine fait 390 et la benne 570 : de quoi tenir, jamais de
## quoi s'enrichir. Ce qu'on vient chercher, c'est l'arme au sol.
const PRIME_CASSE := 120          ## le minimum, pour une épave de citadine
const PRIME_PAR_VOXEL := 18       ## par unité de longueur du gabarit

## Une casse au milieu de chaque intervalle entre deux quais : on la croise en
## suivant la voie, ce qui est exactement ce qu'on fait quand on cherche où se
## débarrasser d'une voiture.
## ⚠ MISE EN CACHE. `casse_de` est appelée à CHAQUE IMAGE par la ligne
## d'action du tableau de bord ; sans le cache, on rebâtissait la liste des
## quais et six dictionnaires soixante fois par seconde pour savoir si l'on est
## garé sur une dalle.
var _casses: Array = []

func casses() -> Array:
	if not _casses.is_empty():
		return _casses
	var liste: Array = []
	var quais := gares()
	var v := voie()
	for k in range(quais.size() - 1):
		var s := (float(quais[k]) + float(quais[k + 1])) * 0.5
		# Alternées d'un côté et de l'autre de la voie : toutes du même bord,
		# elles ne se distinguaient plus des quais en un coup d'œil sur la carte.
		var cote := 1.0 if k % 2 == 0 else -1.0
		liste.append({"i": k, "s": s, "cote": cote,
			"p": point_de_voie(s) + Vector2(v["n"]) * cote * ECART_CASSE})
	_casses = liste
	return _casses

func casse_de(point: Vector2) -> int:
	for c in casses():
		if Vector2(c["p"]).distance_to(point) <= RAYON_CASSE:
			return int(c["i"])
	return -1

func prix_de_la_casse(modele: int) -> int:
	var gabarit: Dictionary = VoxelsCarnage.GABARITS.get(modele, VoxelsCarnage.GABARITS[0])
	return PRIME_CASSE + int(gabarit["l"]) * PRIME_PAR_VOXEL

## Broyer. L'hôte tranche : il retire la voiture de la ville, annonce la somme,
## et pose une caisse d'arme sur le tapis de sortie — c'est le « power-up » du
## guide, servi par le ramassage qui existe déjà plutôt que par un troisième
## système d'inventaire.
##
## ⚠ Ce n'est PAS `detruire_auto`. Celle-là compte un crime, marque des points,
## allume un brasier et appelle les pompiers : brûler une voiture en pleine rue
## et la déposer à la casse ne sont pas le même geste, et le second ne doit
## rien coûter en étoiles — c'est même la seule chose qu'on puisse faire d'une
## voiture volée sans que la police s'en mêle.
func broyer(cle: String, id: int, ou: Vector2) -> void:
	var modele := 0
	for auto in autos:
		if int(auto["id"]) == id:
			modele = int(auto.get("modele", 0))
			break
	retirer(autos, id)
	# Une dormante broyée ne doit pas repousser : `reveillees` est ce qui
	# empêche le décor de la reposer au prochain passage du morceau.
	reveillees[id] = true
	var somme := prix_de_la_casse(modele)
	var butin: String = ["mitraillette", "roquette", "vie", "argent"][posmod(hash(Vector2i(id, 907)), 4)]
	_lacher(ou, butin)
	# ⚠ L'événement s'appelle « broye » et PAS « casse » : « casse » est déjà
	# l'impact d'une balle dans une façade, et deux sens sur le même nom, c'est
	# un jour perdu à chercher pourquoi tirer sur un mur rend de l'argent.
	emettre("broye", {"j": cle, "m": somme, "b": butin,
		"x": int(ou.x), "y": int(ou.y), "v": modele})

# ------------------------------------------------------------ les contrats

## Décrocher à une cabine. Le gang qui appelle est celui dont c'est le
## territoire : une cabine chez Le Lierre ne fait jamais travailler pour Les
## Braises, sinon le respect n'a plus de sens géographique.
func proposer_contrat(cle: String, cabine: int, position: Vector2) -> void:
	if cle == "" or contrats.has(cle):
		return
	# ⚠ L'employeur est le gang DU TERRITOIRE, pas le numéro de la cabine.
	# C'était `posmod(cabine, 3)` — l'indice d'un pâté modulo trois : une
	# cabine plantée chez Le Lierre faisait travailler pour Les Braises deux
	# fois sur trois, et son enseigne annonçait un employeur qui n'était pas
	# celui qui décrochait. Le calcul est chez `plan` : l'enseigne s'allume
	# avec le même résultat, elle ne peut donc plus inviter à décrocher chez
	# un gang qui refuse.
	var employeur := plan.employeur_de_cabine(cabine, position)
	# La couleur du téléphone dit ce qu'il faut avoir pour décrocher. Elle est
	# tirée du numéro de cabine, donc identique chez les quatre joueurs sans
	# rien faire passer par le réseau — c'est la même règle que les ateliers.
	var rang := FormesCarnage.niveau_de_cabine(cabine)
	var exige := float(FormesCarnage.CABINES[rang]["respect"])
	var avoir := respect_pour(cle, employeur)
	if avoir < exige:
		# Le refus NOMME le manque. Sans le chiffre, un joueur qui tombe sur un
		# téléphone rouge à quarante de respect croit le jeu cassé ; avec, il
		# sait quoi faire — et il repasse.
		emettre("ctr", {"j": cle, "e": "refuse", "n": 0, "a": 0, "r": 0, "g": employeur,
			"t": "Cabine %s : %s exige %d de respect (vous en avez %d)" % [
				String(FormesCarnage.CABINES[rang]["nom"]),
				plan.nom_du_gang(employeur), int(exige), int(avoir)]})
		return
	var niveau: Dictionary = PALIERS_CONTRAT[rang]
	# Le rival est tiré parmi les rivaux DE CE GANG ICI : envoyer nettoyer
	# chez un gang de l'autre bout de la ville, c'est un contrat qu'on ne peut
	# pas tenir dans le temps imparti.
	var candidats: Array = plan.rivaux(employeur, position)
	var rival := int(candidats[_rng.randi_range(0, candidats.size() - 1)])
	var tirage := _rng.randf()
	var genre := "nettoyage"
	var objectif := 3 + _rng.randi_range(0, 2) + int(niveau["plus"])
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
		objectif = 2 + int(niveau["plus"])
		texte = "%s paie si vous tenez %d étoiles jusqu'au bout" % [
			plan.nom_du_gang(employeur), objectif]
	texte += " (%s)" % String(niveau["nom"])

	contrats[cle] = {
		"genre": genre, "employeur": employeur, "rival": rival,
		"objectif": objectif, "fait": 0.0, "reste": float(DUREE_CONTRAT[genre]),
		"texte": texte, "p": position,
		"prime": int(round(float(PRIME_CONTRAT[genre]) * float(niveau["prime"]))),
		"respect": float(niveau["respect"]),
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
		_compter(cle, position, int(c.get("prime", PRIME_CONTRAT[String(c["genre"])])), "contrat", false)
		# Servir un gang le rapproche ET fâche celui qu'on a servi contre lui,
		# moitié moins fort (guide §3.2). Sans ce second mouvement, on pouvait
		# enchaîner les contrats des deux camps et finir ami avec tout le
		# monde — le triangle de rivalité ne tenait plus.
		var gagne_respect := float(c.get("respect", RESPECT_CONTRAT))
		_ajuster_respect(cle, int(c["employeur"]), gagne_respect)
		if int(c.get("rival", -1)) >= 0:
			_ajuster_respect(cle, int(c["rival"]), -gagne_respect * 0.5)
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
## Les cubes font une unité (`VoxelsCarnage.V`) : une balle en emporte un, la
## roquette une sphère d'une quarantaine.
const COUPS_PAR_VOXEL := 1
const RAYON_ROQUETTE := 2.2         ## unités 3D
const RAYON_EXPLOSION := 2.0
const RAYON_CHOC := 1.2
## La clé locale tient sur 16 bits (32 × 32 × 64 cellules).
const LOCALES_PAR_IMMEUBLE := 65536

## Une balle ou une roquette dans un mur. Le pistolet écaille (un cube par
## balle), la roquette creuse une sphère.
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
	var cle := id * LOCALES_PAR_IMMEUBLE + locale
	_coups_voxel[cle] = int(_coups_voxel.get(cle, 0)) + 1
	if int(_coups_voxel[cle]) >= COUPS_PAR_VOXEL:
		# ⚠ On remet le compteur à zéro : le mur ne s'ouvrant plus, sans ça il
		# restait au-dessus du seuil et chaque balle suivante repartait en
		# événement — une gerbe de poussière par balle, jusqu'au chargeur vide.
		_coups_voxel[cle] = 0
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
		if posmod(int(locale), 64) < 2:       # le rez-de-chaussée seulement
			liste.append(locale)
	_casser(int(trouve["id"]), liste)

## Un impact sur une façade. ⚠ Depuis la v12 il ne CASSE plus rien : les murs
## tiennent (voir `MorceauVille.casser`), et cet événement ne sert plus qu'à
## jouer le même impact chez tout le monde — la poussière et les éclats. On ne
## garde donc plus la liste des cubes partis (`detruits` reste vide) : elle ne
## servait qu'à rebâtir un morceau avec ses trous, et il n'y a plus de trous.
func _casser(id: int, locales: Array) -> void:
	if locales.is_empty():
		return
	# Un seul point d'impact suffit à l'effet : une roquette renvoyait
	# cinquante cubes, donc cinquante gerbes de poussière au même endroit.
	emettre("casse", {"v": [[id, int(locales[0])]]})

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
		# Et depuis qu'elle vient AVEC SA MITRAILLEUSE (§1.3), ce n'est plus
		# une berline de couleur : c'est une prise, et elle a un prix.
		#
		# ⚠ Le gain au rival était à ZÉRO. Tout le reste du jeu fait bouger DEUX
		# jauges — un mort, une voiture brûlée, un contrat rendu — parce que
		# c'est ce qui tient le triangle de rivalité (§3.1) : sans le second
		# mouvement, on peut fâcher tout le monde sans jamais devenir l'ami de
		# personne. Un quart de gain : partir au volant de leur voiture sous
		# leurs fenêtres se remarque, mais ça ne remplace pas un contrat.
		_repercuter(cle, int(auto.get("gang", 0)), Vector2(auto["p"]),
			RESPECT_PERDU * 0.4, RESPECT_GAGNE * 0.25)
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
		# Le CORPS voyage : c'est lui qui donne sa tenue à l'uniforme et la
		# hauteur de sa jauge de vie. Sans lui, les quatre hommes d'un fourgon
		# apparaissaient chez les autres joueurs en simples îlotiers.
		vus_gens.append([int(personne["id"]), int(personne["p"].x), int(personne["p"].y),
			int(personne["genre"]), int(personne["gang"]), int(personne["pv"]),
			int(float(personne["a"]) * 100.0), int(personne.get("corps", CORPS_POLICE))])

	var vus_autos: Array = []
	for auto in autos:
		if String(auto["pilote"]) != "" or not _regarde(auto["p"], joueurs):
			continue
		vus_autos.append([int(auto["id"]), int(auto["p"].x), int(auto["p"].y),
			int(float(auto["a"]) * 100.0), int(auto["genre"]), int(auto["pv"]),
			int(auto.get("modele", 0)), 1 if bool(auto.get("garee", false)) else 0,
			int(auto.get("corps", CORPS_POLICE)), 1 if bool(auto.get("canon", false)) else 0])

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
		var ligne: Array = [etoiles(String(cle))]
		for v in respect_de(String(cle)):
			ligne.append(int(v))
		etats[cle] = ligne

	var vus_feux: Array = []
	for f in feux:
		vus_feux.append([int(f["id"]), int(f["p"].x), int(f["p"].y), int(float(f["force"]) * 100.0)])

	var vus_a_cotes: Array = []
	for r in ramassages:
		vus_a_cotes.append([int(r["id"]), int(r["p"].x), int(r["p"].y), int(r["genre"])])

	var vus_pieges: Array = []
	for piege in pieges:
		vus_pieges.append([int(piege["id"]), int(piege["p"].x), int(piege["p"].y), int(piege["genre"])])

	# LE TRAIN ne voyage que par son abscisse : la voie est une droite que les
	# quatre joueurs savent tracer, en diffuser des coordonnées serait payer
	# deux fois pour la même information.
	var vus_trains: Array = []
	for t in trains:
		vus_trains.append([int(t["id"]), int(t["s"]), int(t["sens"]), int(t["v"]),
			int(float(t["arret"]) * 10.0)])

	return {"g": vus_gens, "a": vus_autos, "c": vues_caisses, "b": vus_barrages, "h": vus_helicos,
		"f": vus_feux, "e": etats, "pg": vus_pieges, "ac": vus_a_cotes, "tr": vus_trains}

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
			"corps": int(entree[7]) if entree.size() > 7 else CORPS_POLICE,
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
			"corps": int(entree[8]) if entree.size() > 8 else CORPS_POLICE,
			"canon": (int(entree[9]) == 1) if entree.size() > 9 else false,
			"gang": plan.territoire(Vector2(float(entree[1]), float(entree[2]))),
			"d": Vector2.RIGHT, "vitesse": 0.0, "pilote": "", "cible": "", "minuterie": 0.0})
	caisses = _fusionner(caisses, charge.get("c", []), func(entree: Array) -> Dictionary:
		return {"id": int(entree[0]), "p": Vector2(float(entree[1]), float(entree[2])),
			"arme": String(entree[3])})
	barrages = _fusionner(barrages, charge.get("b", []), func(entree: Array) -> Dictionary:
		return {"id": int(entree[0]), "p": Vector2(float(entree[1]), float(entree[2]))})
	ramassages = _fusionner(ramassages, charge.get("ac", []), func(entree: Array) -> Dictionary:
		return {"id": int(entree[0]), "p": Vector2(float(entree[1]), float(entree[2])),
			"genre": int(entree[3]), "arme": ""})
	pieges = _fusionner(pieges, charge.get("pg", []), func(entree: Array) -> Dictionary:
		return {"id": int(entree[0]), "p": Vector2(float(entree[1]), float(entree[2])),
			"genre": int(entree[3]), "par": "", "reste": 9.0, "amorce": 0.0})
	helicos = _fusionner(helicos, charge.get("h", []), func(entree: Array) -> Dictionary:
		return {"id": int(entree[0]), "p": Vector2(float(entree[1]), float(entree[2])),
			"cible": "", "recharge": 0.0, "cap": float(entree[3]) / 100.0 if entree.size() > 3 else 0.0})

	# LE TRAIN : on reçoit son abscisse, pas sa position. `age` compte les
	# secondes depuis l'instantané — le client extrapole avec, parce qu'une
	# rame sur des rails est le seul objet de la ville dont on sait où il sera
	# dans un dixième de seconde. Sans cette extrapolation, un train à neuf
	# cents pixels par seconde avançait par bonds de cent vingt pixels.
	trains = _fusionner(trains, charge.get("tr", []), func(entree: Array) -> Dictionary:
		return {"id": int(entree[0]), "s": float(entree[1]), "sens": float(entree[2]),
			"v": float(entree[3]), "arret": float(entree[4]) / 10.0, "age": 0.0,
			"p": point_de_voie(float(entree[1]))})

	feux = _fusionner(feux, charge.get("f", []), func(entree: Array) -> Dictionary:
		return {"id": int(entree[0]), "p": Vector2(float(entree[1]), float(entree[2])),
			"force": float(entree[3]) / 100.0, "t": 0.0, "propage": PROPAGATION, "ronge": RONGE})

	var etats = charge.get("e", {})
	if typeof(etats) == TYPE_DICTIONARY:
		for cle in etats:
			var valeurs = etats[cle]
			if typeof(valeurs) == TYPE_ARRAY and (valeurs as Array).size() >= 1 + PlanVille.GANGS.size():
				chaleur[cle] = chaleur_pour(int(valeurs[0]))
				var jauge: Array = []
				for i in PlanVille.GANGS.size():
					jauge.append(float(valeurs[1 + i]))
				respect[cle] = jauge

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
			for champ in ["genre", "gang", "pv", "a", "arme", "garee", "cap", "corps", "canon",
					"s", "sens", "v", "arret", "age"]:
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
