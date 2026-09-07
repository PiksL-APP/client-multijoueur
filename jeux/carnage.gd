extends Partie
## CARNAGE — une ville ouverte vue de dessus, deux minutes de trop-plein.
##
## L'ancien Carnage était un jeu de voiture : on écrasait, on ne descendait
## jamais. Celui-ci se joue comme un GTA 2 : on sort de la berline, on court,
## on tire, on pique la voiture d'un autre, on ramasse cinq étoiles et on va
## se faire repeindre au garage. Trois gangs tiennent leurs rues et se
## souviennent de qui les a saignés. Deux esplanades marquées au sol allument
## le tir ami : partout ailleurs, on joue la ville ensemble.
##
## Répartition du travail, inchangée dans son principe : chaque client simule
## SON personnage — la commande répond à l'image, pas au réseau — et l'HÔTE
## simule tout ce qui est partagé, dans `jeux/carnage/vivant.gd`. Laisser le
## tireur déclarer ses victimes serait plus nerveux et complètement indéfendable :
## deux joueurs revendiqueraient le même passant à cent millisecondes près.
##
## Le plan de la ville ne circule pas : il se déduit du CODE de la manche
## (`jeux/carnage/plan.gd`). Même code, même ville, chez tout le monde, y
## compris pour qui rejoint en retard.

const DUREE := 240.0

# ------------------------------------------------------- conduite
# Des valeurs d'arcade, pas de simulation. On veut qu'une voiture reparte vite
# après un choc, sinon le jeu punit la maladresse trop longtemps.
const ACCELERATION := 940.0
const FREIN := 1550.0
const VITESSE_MAX := 760.0
const VITESSE_ARRIERE := -270.0
const FROTTEMENT := 1.6
const BRAQUAGE := 3.6
const PRISE_PLEINE := 165.0        ## vitesse à partir de laquelle on braque à fond
const RAYON_VOITURE := 26.0
const PV_VOITURE := 100.0

# ------------------------------------------------------- à pied
const VITESSE_A_PIED := 215.0
const RAYON_A_PIED := 16.0
const PORTEE_ENTREE := 110.0       ## distance à laquelle on peut ouvrir une portière
const DELAI_PORTIERE := 0.45       ## on ne ressort pas dans la même seconde

const VIE_MAX := 100.0
const REGEN := 6.0                 ## points de vie par seconde, après une accalmie
const ACCALMIE := 6.0              ## secondes sans coup avant que ça reparte
const HORS_SERVICE := 4.0

## À pied, on encaisse deux fois plus : c'est ce qui fait qu'on remonte en
## voiture au lieu de traverser la ville à découvert.
const FRAGILITE_A_PIED := 2.0

const CADENCE_JOUEUR := 1.0 / 12.0
const CADENCE_INSTANTANE := 1.0 / 8.0

# Caméra presque à la verticale : en ville, une inclinaison basse met un
# immeuble entre l'œil et la voiture toutes les trois secondes. À pied on se
# rapproche, sinon le personnage fait quatre pixels.
const INCLINAISON := 70.0
const DISTANCE_AUTO := 58.0
const DISTANCE_PIED := 36.0

const RETOUR := 260.0              ## rappel vers le centre au-delà de la friche

## Ce qu'on DESSINE est plus étroit que ce que l'hôte diffuse : l'écran couvre
## treize cents pixels de large, et chaque voiture garée vaut cinq appels de
## dessin, chaque passant sept. À seize cents pixels, on en dessinait trois
## cents pour en voir quarante — et un navigateur en mode compatibilité tombe
## à dix images par seconde.
const PORTEE_RENDU := 1050.0
## Et on ne bâtit pas plus de quelques maillages par image : soixante voitures
## instanciées d'un coup à l'entrée d'un quartier font une saccade d'une
## demi-seconde qu'on prend pour un plantage.
const BATISSES_PAR_IMAGE := 6

## Les armes. Le pistolet ne s'épuise jamais : sans lui, un joueur à pied et à
## court de munitions n'a plus qu'à attendre la fin de la manche.
const ARMES := {
	"pistolet": {
		"nom": "Pistolet", "munitions": -1, "cadence": 0.32, "portee": 720.0,
		"vitesse": 1250.0, "souffle": 0.0, "degat": 16.0, "couleur": Palette.ENCRE_DOUCE,
	},
	"mitraillette": {
		"nom": "Mitraillette", "munitions": 60, "cadence": 0.10, "portee": 950.0,
		"vitesse": 1500.0, "souffle": 0.0, "degat": 14.0, "couleur": Palette.AVERTISSEMENT,
	},
	"roquette": {
		"nom": "Roquettes", "munitions": 6, "cadence": 0.85, "portee": 1200.0,
		"vitesse": 900.0, "souffle": 170.0, "degat": 90.0, "couleur": Palette.SERIEUX,
	},
	"eperon": {
		"nom": "Éperon", "munitions": 0, "cadence": 0.0, "portee": 0.0,
		"vitesse": 0.0, "souffle": 0.0, "degat": 0.0, "couleur": Palette.SERIE,
	},
}
const DUREE_EPERON := 16.0

## Identifiant de la voiture de départ. Elle n'appartient à personne dans la
## liste de l'hôte tant qu'on ne l'a pas quittée : le premier `sortir` la lui
## fait découvrir. Le nombre est haut pour ne jamais croiser un identifiant
## engendré pendant la manche.
const ID_VOITURE_DEPART := 10000

var carte: PlanVille
var ville: VilleVivante

# ------------------------------------------------------- le joueur local
var _position := Vector2.ZERO
var _angle := 0.0
var _vitesse := 0.0
var _pied := false
var _vehicule := 0
var _genre_vehicule: int = VilleVivante.CIVILE
var _modele_vehicule := -1        ## -1 : la Volvo de départ ; sinon un indice du kit
var _pv_vehicule := PV_VOITURE
var _vie := VIE_MAX
var _sonne := 0.0
var _hors_service := 0.0
var _depuis_coup := 99.0
var _depuis_portiere := 0.0
var _arme := "pistolet"
var _munitions := -1
var _eperon := 0.0
var _recharge := 0.0
var _dernier_agresseur := ""
var _hors_ville := 0.0
var _garage_en_cours := -1
var _cabine_en_cours := -1
var _contrat: Dictionary = {}
var _depuis_sirene := 0.0
var _hud_contrat: Label
var _radar: Control
var _hud_banniere: Label
var _banniere_reste := 0.0
var _territoire_vu := -99
var _quartier_vu := -99

var _autres: Dictionary = {}       ## cle -> état distant + nœuds 3D
var _projectiles: Array = []
var _cabines_posees: Array = []
var _eclats: Array = []
var _taches: Array = []

var _corps_auto: Node3D
var _corps_pied: Node3D
var _camera: Camera3D
var _secousse := 0.0
var _rng := RandomNumberGenerator.new()

var _place := 0
var _depuis_envoi := 0.0
var _depuis_instantane := 0.0
var _sortie_de_banc := false
var _pulsation := false

func duree_manche() -> float:
	return DUREE

func aide() -> String:
	return "Z/S : avancer et freiner · Q/D : tourner · ESPACE : tirer · E : monter ou descendre · caisse = arme · garage bleu = étoiles effacées · cabine jaune = contrat · cercle rouge = tir ami"

# ------------------------------------------------------- mise en place

func preparer() -> void:
	_rng.randomize()
	carte = PlanVille.new(code)
	ville = VilleVivante.new(carte, _rng)

	_planter_decor()

	# Le départ ne se tire pas au hasard : il se déduit de la place à la table,
	# donc du même calcul chez tout le monde. Deux clients qui tireraient
	# séparément mettraient deux joueurs au même carrefour une fois sur trois.
	var graine := RandomNumberGenerator.new()
	graine.seed = hash(code) + 977
	var place := 0
	for membre in donnees.get("equipe", []):
		if String(membre.get("cle", "")) == Session.cle:
			break
		place += 1
	_place = place
	var pose := carte.depart(place, graine)
	_position = pose["p"]
	_angle = float(pose["a"])
	_vehicule = ID_VOITURE_DEPART + place
	_pied = false

	_corps_auto = FormesCarnage.voiture(_ma_couleur(), Session.pseudo)
	monde().add_child(_corps_auto)
	_corps_pied = FormesCarnage.pieton(_ma_couleur(), false, Session.pseudo, true)
	_corps_pied.visible = false
	monde().add_child(_corps_pied)

	# Le contrat a sa propre ligne, au-dessus de celle du socle : glissé dans
	# l'état du joueur, il se perdait au milieu de sept autres mentions alors
	# qu'il décide de la minute qui vient.
	# La bannière : le nom du quartier et de qui le tient, quand on y entre.
	# Le sol change de teinte, mais une teinte ne se nomme pas toute seule.
	_hud_banniere = UI.titre("", 24)
	_hud_banniere.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hud_banniere.offset_top = 52
	_hud_banniere.offset_bottom = 88
	_hud_banniere.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interface().add_child(_hud_banniere)

	_hud_contrat = UI.titre("", 20)
	_hud_contrat.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hud_contrat.offset_left = 20
	_hud_contrat.offset_right = -20
	_hud_contrat.offset_top = -106
	_hud_contrat.offset_bottom = -76
	interface().add_child(_hud_contrat)

	# Le plan, en haut à droite : sous le bandeau du socle, et à l'opposé des
	# boutons tactiles, qui vivent en bas à droite.
	_radar = Control.new()
	_radar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_radar.offset_left = -200.0
	_radar.offset_right = -6.0
	_radar.offset_top = 56.0
	_radar.offset_bottom = 268.0
	_radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radar.set_script(load("res://ui/radar.gd"))
	_radar.carte = carte
	interface().add_child(_radar)

	_camera = Decor.camera(INCLINAISON, DISTANCE_AUTO, 54.0)
	monde().add_child(_camera)
	_camera.make_current()
	Tactile.mode = Tactile.CONDUITE

## La carrosserie qu'on conduit : la Volvo au départ, puis ce qu'on a volé. On
## reconstruit le nœud plutôt que d'en garder dix cachés — une voiture volée
## par manche, ça se compte sur les doigts.
func _rebatir_ma_voiture() -> void:
	if _corps_auto != null:
		_corps_auto.queue_free()
	_corps_auto = _batir_voiture_de(_modele_vehicule, _ma_couleur(), Session.pseudo)
	monde().add_child(_corps_auto)

func _batir_voiture_de(modele: int, couleur: Color, pseudo: String) -> Node3D:
	if modele < 0:
		return FormesCarnage.voiture(couleur, pseudo)
	# Une voiture volée garde sa peinture ; c'est le halo qui dit à qui elle
	# est. Une voiture de gang volée, elle, garde les couleurs du gang.
	return FormesCarnage.voiture_kit(modele, Color.WHITE, couleur, pseudo, true)

## La couleur vient de la place à la TABLE, pas de la place dans la présence :
## celle-ci n'arrive qu'après le premier échange, et la voiture serait bleue
## pendant deux secondes chez tout le monde.
func _ma_couleur() -> Color:
	return Palette.couleur_joueur(_place)

func _planter_decor() -> void:
	poser_ambiance(true, 0.92)

	# Une nappe de fond, très sombre, sous la ville : elle rattrape ce que la
	# caméra voit au-delà de la ceinture, là où il n'y a plus de tuiles.
	var fond := Decor.sol(carte.etendue() + Vector2(carte.banlieue(), carte.banlieue()) * 2.0,
		140.0, Color("#101010"), 3000.0)
	fond.position = Decor.vers3d(carte.centre(), -0.15)
	monde().add_child(fond)

	for chemin in carte.nappes:
		var nom := String(chemin).get_file().get_basename()
		# Le sol ne porte pas d'ombre : il n'a rien à projeter, et le calculer
		# pour huit cents dalles coûte une passe d'ombre pour rien.
		var sans_ombre := nom in ["road-straight", "road-intersection", "pavement", "grass",
			"road-corner", "road-split"]
		var nappe: Dictionary = carte.nappes[chemin]
		monde().add_child(FormesCarnage.nappe(String(chemin), nappe["t"], nappe["c"],
			not sans_ombre, PlanVille.TEINTE_VILLE))

	for r in carte.repaires:
		var tag := FormesCarnage.tag_de_gang(carte.couleur_du_gang(int(r["gang"])),
			carte.nom_du_gang(int(r["gang"])))
		tag.position = Decor.vers3d(r["p"])
		monde().add_child(tag)

	for centre_garage: Vector2 in carte.garages():
		var dalle := FormesCarnage.dalle_garage()
		dalle.position = Decor.vers3d(centre_garage)
		monde().add_child(dalle)

	var rang := 0
	for centre_cabine: Vector2 in carte.cabines():
		var poste := FormesCarnage.cabine(rang)
		poste.position = Decor.vers3d(centre_cabine)
		monde().add_child(poste)
		_cabines_posees.append(poste)
		rang += 1

	var numero := 0
	for centre_arene: Vector2 in carte.arenes():
		var cercle := FormesCarnage.cercle_arene(numero)
		cercle.position = Decor.vers3d(centre_arene)
		monde().add_child(cercle)
		numero += 1

# ------------------------------------------------------- simulation locale

func simuler_local(delta: float) -> void:
	if Commandes.pilote_automatique:
		_piloter_pour_le_banc()

	_depuis_portiere = max(0.0, _depuis_portiere - delta)
	# ⚠ Le délai se teste AVANT de lire la touche : `action_declenchee` consomme
	# le front. Interrogée pendant le délai, elle avalait l'appui de celui qui
	# venait de descendre et il restait planté à côté de sa portière.
	if _depuis_portiere <= 0.0 and _hors_service <= 0.0 and Commandes.action_declenchee():
		_basculer_portiere()

	if _pied:
		_marcher(delta)
	else:
		_conduire(delta)
	_tirer(delta)
	_surveiller_les_lieux(delta)

	if _eperon > 0.0:
		_eperon -= delta

	for cle in _autres:
		var a: Dictionary = _autres[cle]
		a["p"] = (a["p"] as Vector2).lerp(a["cible"], clamp(delta * 14.0, 0, 1))
		a["a"] = lerp_angle(float(a["a"]), float(a["angle_cible"]), clamp(delta * 14.0, 0, 1))

	_depuis_envoi += delta
	if _depuis_envoi >= CADENCE_JOUEUR:
		_depuis_envoi = 0.0
		canal.envoyer("j", {
			"x": int(_position.x), "y": int(_position.y),
			"a": snapped(_angle, 0.01), "s": int(_vitesse), "h": int(_vie),
			"e": 2 if _hors_service > 0.0 else (0 if _pied else 1),
			"w": _vehicule, "vg": _genre_vehicule, "vm": _modele_vehicule,
			"ep": 1 if _eperon > 0.0 else 0,
		})

	if not est_hote():
		# Les objets de l'hôte ne se déplacent pas d'un bond toutes les huit
		# images : on glisse vers la dernière position connue.
		for objet in ville.gens:
			objet["p"] = (objet["p"] as Vector2).lerp(objet.get("cible", objet["p"]), clamp(delta * 11.0, 0, 1))
		for auto in ville.autos:
			auto["p"] = (auto["p"] as Vector2).lerp(auto.get("cible_p", auto["p"]), clamp(delta * 11.0, 0, 1))

	_avancer_projectiles(delta)
	_ramasser_caisses()

## Pilote automatique du banc d'essai. Il ne joue pas bien, il joue TOUT :
## sans une sortie de véhicule programmée, la moitié du jeu — la marche, le
## vol de voiture, le tir à pied — ne serait jamais exercée avant livraison.
func _piloter_pour_le_banc() -> void:
	# ⚠ L'action se PULSE. Maintenue, elle ne produit qu'un seul front : le
	# pilote descendait de voiture et ne remontait jamais, et la moitié du jeu
	# passait le banc sans être exercée.
	_pulsation = not _pulsation
	Commandes.action_simulee = false
	if not _sortie_de_banc and not _pied and temps > duree_reelle() * 0.4:
		_sortie_de_banc = true
		Commandes.action_simulee = true
		Commandes.direction_simulee = Vector2.ZERO
		return

	if _pied:
		var auto := ville.vehicule_proche(_position, 1400.0)
		if auto.is_empty():
			Commandes.direction_simulee = Vector2.RIGHT.rotated(temps)
			Commandes.tir_simule = true
			return
		var vers: Vector2 = Vector2(auto["p"]) - _position
		if vers.length() <= PORTEE_ENTREE:
			Commandes.action_simulee = _pulsation
			Commandes.direction_simulee = Vector2.ZERO
		else:
			Commandes.direction_simulee = vers.normalized()
		Commandes.tir_simule = true
		return

	Commandes.direction_simulee = _viser(_but_du_banc())
	Commandes.tir_simule = true

## Ce que vise le pilote du banc. Tant qu'il n'a pas de contrat, il va
## décrocher : sans ce détour, une cabine sur vingt-six par vingt tuiles n'est
## jamais croisée par hasard, et toute la chaîne des contrats — proposition,
## avancement, prime, respect — passe la livraison sans avoir tourné une fois.
func _but_du_banc() -> Vector2:
	if _contrat.is_empty():
		var cabines := carte.cabines()
		var proche := Vector2.INF
		var ecart := INF
		for c: Vector2 in cabines:
			var d: float = _position.distance_squared_to(c)
			if d < ecart:
				ecart = d
				proche = c
		if proche != Vector2.INF:
			return proche
	var cible := Vector2.INF
	var distance := INF
	for personne in ville.gens:
		var d2: float = _position.distance_squared_to(personne["p"])
		if d2 < distance:
			distance = d2
			cible = personne["p"]
	return cible if cible != Vector2.INF else carte.centre()

func _viser(cible: Vector2) -> Vector2:
	var ecart := wrapf((cible - _position).angle() - _angle, -PI, PI)
	return Vector2(clamp(ecart * 2.0, -1.0, 1.0), 1.0)

# ------------------------------------------------------- portières

## Monter, descendre. C'est le geste qui sépare un jeu de voiture d'un GTA :
## tant qu'on ne peut pas sortir, la ville n'est qu'un circuit.
func _basculer_portiere() -> void:
	_depuis_portiere = DELAI_PORTIERE
	if _pied:
		var auto := ville.vehicule_proche(_position, PORTEE_ENTREE)
		if auto.is_empty():
			return
		var id := int(auto["id"])
		if est_hote():
			ville.accorder_vehicule(Session.cle, id, _position)
			_vider_les_evenements()
		else:
			# L'hôte tranche : deux joueurs arrivés à cent millisecondes
			# d'intervalle ne repartent pas avec la même berline.
			canal.envoyer("monte", {"id": id, "x": int(_position.x), "y": int(_position.y)})
		return

	# On descend : la voiture retourne au monde, là où on l'a laissée.
	if Commandes.pilote_automatique:
		print("[banc] descend du véhicule %d" % _vehicule)
	var descente := _position + Vector2.UP.rotated(_angle) * 46.0
	descente = carte.degager(descente, RAYON_A_PIED)[0]
	var id_rendu := _vehicule
	var pv := _pv_vehicule
	_pied = true
	_vitesse = 0.0
	_vehicule = 0
	Tactile.mode = Tactile.MARCHE
	Sons.arreter_moteur()
	var angle_rendu := _angle
	var modele_rendu := _modele_vehicule
	var genre_rendu := _genre_vehicule
	canal.envoyer("sort", {"id": id_rendu, "x": int(_position.x), "y": int(_position.y),
		"a": snapped(angle_rendu, 0.01), "pv": int(pv), "g": genre_rendu, "m": modele_rendu})
	if est_hote():
		ville.rendre_vehicule(Session.cle, id_rendu, _position, angle_rendu, pv, modele_rendu, genre_rendu)
		_vider_les_evenements()
	_position = descente
	_modele_vehicule = -1

func _prendre_le_volant(id: int, genre: int, position: Vector2, angle: float, pv: float,
		modele: int = -1) -> void:
	_modele_vehicule = modele
	_rebatir_ma_voiture()
	# Le banc raconte ce qu'il fait : sans cette ligne, un pilote qui ne
	# remonterait jamais en voiture rendrait exactement le même journal qu'un
	# pilote qui joue toute la manche au volant.
	if Commandes.pilote_automatique:
		print("[banc] prend le volant du véhicule %d" % id)
	_pied = false
	_vehicule = id
	_genre_vehicule = genre
	_pv_vehicule = pv
	_position = position
	_angle = angle
	_vitesse = 0.0
	_depuis_portiere = DELAI_PORTIERE
	Tactile.mode = Tactile.CONDUITE
	Sons.demarrer_moteur()
	Sons.jouer("porte", 1.0, -10.0)

# ------------------------------------------------------- déplacement

func _marcher(delta: float) -> void:
	if _hors_service > 0.0:
		_hors_service -= delta
		if _hors_service <= 0.0:
			_relever()
		return
	_regenerer(delta)
	if _sonne > 0.0:
		_sonne -= delta
		return

	var commande := Commandes.direction()
	if commande.length() > 0.1:
		# À pied, la direction du regard suit la marche : on tire là où on va,
		# ce qui évite un second axe de visée sur un jeu qui se joue à quatre
		# touches.
		_angle = commande.angle()
		_vitesse = VITESSE_A_PIED
		var suivant := _position + commande.normalized() * VITESSE_A_PIED * delta
		_position = carte.degager(suivant, RAYON_A_PIED)[0]
	else:
		_vitesse = 0.0
	_surveiller_la_friche(delta)

func _conduire(delta: float) -> void:
	if _hors_service > 0.0:
		_hors_service -= delta
		_vitesse = move_toward(_vitesse, 0.0, FREIN * delta)
		_position += Vector2.RIGHT.rotated(_angle) * _vitesse * delta
		if _hors_service <= 0.0:
			_relever()
		return

	_regenerer(delta)

	if _sonne > 0.0:
		_sonne -= delta
		_angle += delta * 4.0
		_vitesse = move_toward(_vitesse, 0.0, FREIN * delta * 0.5)
	else:
		var commande := Commandes.conduite()
		if commande.y > 0.1:
			_vitesse = min(_vitesse + ACCELERATION * delta, VITESSE_MAX)
		elif commande.y < -0.1:
			_vitesse = max(_vitesse - FREIN * delta, VITESSE_ARRIERE)
		else:
			_vitesse = move_toward(_vitesse, 0.0, FROTTEMENT * abs(_vitesse) * delta + 40.0 * delta)

		# Le braquage atteint son plein dès 165 px/s — avant, la voiture ne
		# tournait qu'à pleine vitesse, ce qui la rendait inconduisible dans
		# des rues de cent quarante pixels. Il se resserre ensuite un peu à
		# haute vitesse, ce qui donne le poids sans enlever le contrôle.
		var prise: float = clamp(abs(_vitesse) / PRISE_PLEINE, 0.0, 1.0) * signf(_vitesse)
		var tenue: float = lerp(1.0, 0.74, clamp(abs(_vitesse) / VITESSE_MAX, 0.0, 1.0))
		_angle += commande.x * BRAQUAGE * delta * prise * tenue

	_position += Vector2.RIGHT.rotated(_angle) * _vitesse * delta
	_heurter_les_murs()
	_surveiller_la_friche(delta)
	Sons.regime(clamp(abs(_vitesse) / VITESSE_MAX, 0.0, 1.0))

## Un mur ne stoppe pas : il fait GLISSER. On ne perd que la part de vitesse
## qu'on a mise dedans, et la voiture se réaligne sur la façade quand on la
## frôle. Avant, le moindre angle de trottoir coupait les deux tiers de la
## vitesse et clouait la voiture — dans une ville, c'est toutes les trois
## secondes.
func _heurter_les_murs() -> void:
	var resultat := carte.degager(_position, RAYON_VOITURE)
	if not bool(resultat[1]):
		return
	var correction: Vector2 = (resultat[0] as Vector2) - _position
	_position = resultat[0]
	var normale := correction.normalized()
	if normale == Vector2.ZERO:
		return
	var direction := Vector2.RIGHT.rotated(_angle)
	var frontal: float = abs(direction.dot(normale))

	if frontal > 0.62 and abs(_vitesse) > 330.0:
		Sons.jouer("choc", 0.8, -10.0)
		_secousse = max(_secousse, 0.28)
		# La tôle s'abîme : une voiture qu'on maltraite finit par exploser,
		# et c'est ce qui donne un sens au garage.
		_pv_vehicule = max(0.0, _pv_vehicule - abs(_vitesse) * 0.012)
		if _pv_vehicule <= 0.0:
			_vehicule_detruit()
	_vitesse *= lerp(0.95, 0.28, frontal)

	var tangente := Vector2(-normale.y, normale.x)
	if tangente.dot(direction) < 0.0:
		tangente = -tangente
	_angle = lerp_angle(_angle, tangente.angle(), (1.0 - frontal) * 0.4)

func _regenerer(delta: float) -> void:
	_depuis_coup += delta
	if _depuis_coup > ACCALMIE:
		_vie = min(VIE_MAX, _vie + REGEN * delta)

## Il n'y a pas de mur : au-delà de la friche on est ramené, doucement d'abord.
## Un mur invisible qui arrête net donne l'impression d'un défaut ; une
## inertie qui ramène se comprend sans explication.
func _surveiller_la_friche(delta: float) -> void:
	var limite := Rect2(-carte.banlieue(), -carte.banlieue(),
		carte.etendue().x + carte.banlieue() * 2.0, carte.etendue().y + carte.banlieue() * 2.0)
	if limite.has_point(_position):
		_hors_ville = max(0.0, _hors_ville - delta * 2.0)
		return
	_hors_ville += delta
	var vers_centre := (carte.centre() - _position).normalized()
	_position += vers_centre * RETOUR * delta * min(_hors_ville, 3.0)

## Les lieux qui font quelque chose quand on s'y arrête : le garage de
## peinture. Il ne se déclenche qu'en voiture — repeindre un piéton n'a
## jamais effacé un casier.
func _surveiller_les_lieux(_delta: float) -> void:
	# Une cabine se décroche à pied comme au volant : obliger à descendre au
	# milieu d'une avenue pour prendre un contrat, c'est se faire faucher.
	var cabine := carte.cabine_de(_position)
	if cabine != _cabine_en_cours:
		_cabine_en_cours = cabine
		if cabine >= 0 and _contrat.is_empty():
			canal.envoyer("cabine", {"i": cabine, "x": int(_position.x), "y": int(_position.y)})
			if est_hote():
				ville.proposer_contrat(Session.cle, cabine, _position)
				_vider_les_evenements()

	if _pied:
		_garage_en_cours = -1
		return
	var garage := carte.garage_de(_position)
	if garage == _garage_en_cours:
		return
	_garage_en_cours = garage
	if garage < 0:
		return
	_pv_vehicule = PV_VOITURE
	Sons.jouer("portail", 1.0, -8.0)
	canal.envoyer("garage", {"i": garage})
	if est_hote():
		ville.repeindre(Session.cle)
		_vider_les_evenements()

# ------------------------------------------------------- armes

func _tirer(delta: float) -> void:
	_recharge = max(0.0, _recharge - delta)
	if _hors_service > 0.0 or _arme == "" or _arme == "eperon" or _munitions == 0 or _recharge > 0.0:
		return
	if not Commandes.tir():
		return
	var fiche: Dictionary = ARMES[_arme]
	_recharge = float(fiche["cadence"])
	if _munitions > 0:
		_munitions -= 1
	var depart := _position + Vector2.RIGHT.rotated(_angle) * (40.0 if not _pied else 24.0)
	canal.envoyer("tir", {"x": int(depart.x), "y": int(depart.y),
		"a": snapped(_angle, 0.01), "arme": _arme})
	_creer_projectile(depart, _angle, _arme, Session.cle)
	Sons.jouer("clic" if _arme != "roquette" else "choc",
		1.6 if _arme != "roquette" else 0.7, -12.0)
	# Tirer en ville, ça s'entend. La police n'a pas besoin de voir le corps.
	if est_hote():
		ville.crime(Session.cle, "coup_de_feu")
		_vider_les_evenements()
	if _munitions == 0:
		_reprendre_le_pistolet()

func _reprendre_le_pistolet() -> void:
	_arme = "pistolet"
	_munitions = -1

func _creer_projectile(depart: Vector2, angle: float, arme: String, par: String) -> void:
	var fiche: Dictionary = ARMES.get(arme, ARMES["pistolet"])
	var couleur: Color = fiche["couleur"]
	var noeud := Decor.sphere(0.5 if arme != "roquette" else 0.9, couleur, false)
	noeud.material_override = Decor.matiere_lumineuse(couleur, 1.25)
	noeud.position = Decor.vers3d(depart, 1.4)
	monde().add_child(noeud)
	_projectiles.append({
		"p": depart, "v": Vector2.RIGHT.rotated(angle) * float(fiche["vitesse"]),
		"restant": float(fiche["portee"]), "par": par, "arme": arme, "noeud": noeud,
	})

func _avancer_projectiles(delta: float) -> void:
	var restants: Array = []
	for tir in _projectiles:
		var pas: Vector2 = (tir["v"] as Vector2) * delta
		tir["p"] = (tir["p"] as Vector2) + pas
		tir["restant"] = float(tir["restant"]) - pas.length()
		var mort: bool = float(tir["restant"]) <= 0.0 or carte.dans_un_batiment(tir["p"])
		if est_hote() and not mort:
			mort = _resoudre_impact(tir)
		if mort:
			if String(tir["arme"]) == "roquette":
				_effet_explosion(tir["p"])
			(tir["noeud"] as Node3D).queue_free()
			continue
		(tir["noeud"] as Node3D).position = Decor.vers3d(tir["p"], 1.4)
		restants.append(tir)
	_projectiles = restants

## Seul l'hôte tranche : lui seul voit toute la ville à la même date.
func _resoudre_impact(tir: Dictionary) -> bool:
	var point: Vector2 = tir["p"]
	var par := String(tir["par"])
	var fiche: Dictionary = ARMES.get(String(tir["arme"]), ARMES["pistolet"])
	var souffle := float(fiche["souffle"])

	for personne in ville.gens:
		if (personne["p"] as Vector2).distance_to(point) <= VilleVivante.RAYON_PIETON + 12.0:
			ville.abattre_par_id(int(personne["id"]), par, souffle)
			_vider_les_evenements()
			return true

	for auto in ville.autos:
		if int(auto["genre"]) == VilleVivante.EPAVE or String(auto["pilote"]) != "":
			continue
		if (auto["p"] as Vector2).distance_to(point) > VilleVivante.RAYON_AUTO + 12.0:
			continue
		auto["pv"] = float(auto["pv"]) - float(fiche["degat"])
		if float(auto["pv"]) <= 0.0:
			ville.detruire_auto(auto, par)
		_vider_les_evenements()
		return true

	# Le tir ami n'existe QUE dans une arène, et seulement si le coup PART
	# d'une arène et arrive dans la même. Sans cette condition, un tireur
	# posté dehors nettoierait l'esplanade sans jamais y entrer.
	var arene := carte.arene_de(point)
	if arene >= 0:
		var etats := _etats_des_joueurs()
		for cle in etats:
			if String(cle) == par:
				continue
			var etat: Dictionary = etats[cle]
			if int(etat.get("arene", -1)) != arene:
				continue
			if Vector2(etat["p"]).distance_to(point) > RAYON_VOITURE + 12.0:
				continue
			ville.emettre("deg", {"j": cle, "d": int(fiche["degat"]),
				"k": "joueur", "par": par})
			_vider_les_evenements()
			return true
	return false

func _ramasser_caisses() -> void:
	for caisse in ville.caisses:
		if (caisse["p"] as Vector2).distance_to(_position) > 52.0:
			continue
		canal.envoyer("ramasse", {"id": int(caisse["id"])})
		if est_hote():
			var arme := ville.retirer_caisse(int(caisse["id"]))
			if arme != "":
				_accorder(Session.cle, arme)
		return

func _accorder(cle: String, arme: String) -> void:
	canal.envoyer("arme", {"j": cle, "arme": arme})
	if cle == Session.cle:
		_equiper(arme)

func _equiper(arme: String) -> void:
	if arme == "eperon":
		_eperon = DUREE_EPERON
	else:
		_arme = arme
		_munitions = int(ARMES[arme]["munitions"])
	Sons.jouer("depart", 1.0, -8.0)

func seuil_ecrasement() -> float:
	return VilleVivante.SEUIL_EPERON if _eperon > 0.0 else VilleVivante.SEUIL_ECRASEMENT

# ------------------------------------------------------- simulation hôte

func simuler_hote(delta: float) -> void:
	ville.reprendre_la_main()
	var etats := _etats_des_joueurs()
	ville.simuler(delta, temps, etats)
	_vider_les_evenements()

	_depuis_instantane += delta
	if _depuis_instantane >= CADENCE_INSTANTANE:
		_depuis_instantane = 0.0
		canal.envoyer("n", ville.instantane(etats))

## Ce que l'hôte sait de chacun. Il ne le déduit jamais : chaque client annonce
## sa position, et l'hôte s'en contente. Le contraire — un hôte qui replacerait
## les autres — ferait cahoter la voiture de tout le monde sauf la sienne.
func _etats_des_joueurs() -> Dictionary:
	var etats: Dictionary = {}
	if _hors_service <= 0.0:
		etats[Session.cle] = {
			"p": _position, "a": _angle, "v": _vitesse, "vie": _vie,
			"pied": _pied, "seuil": seuil_ecrasement(),
			"arene": carte.arene_de(_position), "d": Vector2.RIGHT.rotated(_angle),
		}
	for cle in _autres:
		var a: Dictionary = _autres[cle]
		if int(a.get("etat", 1)) == 2 or float(a.get("vie", VIE_MAX)) <= 0.0:
			continue
		etats[cle] = {
			"p": a["p"], "a": float(a["a"]), "v": float(a.get("v", 0.0)),
			"vie": float(a.get("vie", VIE_MAX)), "pied": bool(a.get("pied", false)),
			"seuil": VilleVivante.SEUIL_EPERON if bool(a.get("eperon", false)) \
				else VilleVivante.SEUIL_ECRASEMENT,
			"arene": carte.arene_de(a["p"]),
			"d": Vector2.RIGHT.rotated(float(a["a"])),
		}
	return etats

## Les décisions de l'hôte partent sur le réseau ET s'appliquent chez lui :
## `broadcast.self` est à faux, il ne recevra pas ses propres messages.
func _vider_les_evenements() -> void:
	if ville.sortants.is_empty():
		return
	var lot: Array = ville.sortants.duplicate()
	ville.sortants.clear()
	for evenement in lot:
		var nom := String(evenement["e"])
		var charge: Dictionary = evenement["c"]
		canal.envoyer(nom, charge)
		_appliquer(nom, charge)

# ------------------------------------------------------- réception

func recevoir(evenement: String, charge: Dictionary) -> void:
	match evenement:
		"j":
			_recevoir_joueur(charge)
		"n":
			if not est_hote():
				ville.appliquer_instantane(charge)
		"tir":
			if String(charge.get("cle", "")) == Session.cle:
				return
			if est_hote():
				ville.crime(String(charge.get("cle", "")), "coup_de_feu")
				_vider_les_evenements()
			_creer_projectile(
				Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))),
				float(charge.get("a", 0.0)), String(charge.get("arme", "pistolet")),
				String(charge.get("cle", "")))
		"monte":
			if est_hote():
				ville.accorder_vehicule(String(charge.get("cle", "")), int(charge.get("id", 0)),
					Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))))
				_vider_les_evenements()
		"sort":
			if est_hote():
				ville.rendre_vehicule(String(charge.get("cle", "")), int(charge.get("id", 0)),
					Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))),
					float(charge.get("a", 0.0)), float(charge.get("pv", PV_VOITURE)),
					int(charge.get("m", -1)), int(charge.get("g", VilleVivante.CIVILE)))
				_vider_les_evenements()
		"cabine":
			if est_hote():
				ville.proposer_contrat(String(charge.get("cle", "")), int(charge.get("i", 0)),
					Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))))
				_vider_les_evenements()
		"garage":
			if est_hote():
				ville.repeindre(String(charge.get("cle", "")))
				_vider_les_evenements()
		"ramasse":
			if est_hote():
				var arme := ville.retirer_caisse(int(charge.get("id", -1)))
				if arme != "":
					_accorder(String(charge.get("cle", "")), arme)
		_:
			_appliquer(evenement, charge)

func _appliquer(evenement: String, charge: Dictionary) -> void:
	match evenement:
		"pris":
			var qui := String(charge.get("j", ""))
			if qui == Session.cle:
				_prendre_le_volant(int(charge.get("id", 0)), int(charge.get("g", 0)),
					Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))),
					float(charge.get("a", 0.0)), float(charge.get("pv", PV_VOITURE)),
					int(charge.get("m", 0)))
		"arme":
			var beneficiaire := String(charge.get("j", ""))
			if beneficiaire == Session.cle:
				_equiper(String(charge.get("arme", "")))
			elif _autres.has(beneficiaire):
				_autres[beneficiaire]["eperon"] = String(charge.get("arme", "")) == "eperon"
		"deg":
			if String(charge.get("j", "")) == Session.cle:
				_encaisser(float(charge.get("d", 0)), String(charge.get("k", "")),
					String(charge.get("par", "")))
		"k":
			var tueur := String(charge.get("j", ""))
			if est_hote():
				ajouter_score(tueur, int(charge.get("p", 0)))
			_effet_gain(Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))),
				int(charge.get("p", 0)), int(charge.get("f", 1)), tueur,
				String(charge.get("q", "")))
		"boum":
			_effet_explosion(Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))))
		"etoiles":
			ville.chaleur[String(charge.get("j", ""))] = ville.chaleur_pour(int(charge.get("r", 0)))
			if Commandes.pilote_automatique and String(charge.get("j", "")) == Session.cle:
				print("[banc] recherche : %d étoile(s)" % int(charge.get("r", 0)))
		"resp":
			var valeurs = charge.get("v", [])
			if typeof(valeurs) == TYPE_ARRAY and (valeurs as Array).size() >= 3:
				ville.respect[String(charge.get("j", ""))] = [
					float(valeurs[0]), float(valeurs[1]), float(valeurs[2])]
		"ctr":
			if String(charge.get("j", "")) != Session.cle:
				return
			var etat := String(charge.get("e", ""))
			if Commandes.pilote_automatique:
				print("[banc] contrat %s : %s" % [etat, String(charge.get("t", ""))])
			if etat == "gagne":
				_contrat = {}
				Sons.jouer("fin", 1.15, -5.0)
			elif etat == "perdu":
				_contrat = {}
				Sons.jouer("choc", 0.55, -12.0)
			else:
				_contrat = {"t": String(charge.get("t", "")), "n": int(charge.get("n", 0)),
					"a": int(charge.get("a", 0)), "r": float(charge.get("r", 0))}
				if etat == "pris":
					Sons.jouer("portail", 1.3, -9.0)
		"peint":
			if String(charge.get("j", "")) == Session.cle:
				Sons.jouer("fin", 1.2, -10.0)
		"tn":
			# Le coup de feu d'un PNJ : on le VOIT partir, mais il ne vole
			# pas. Quatre-vingts projectiles de plus à diffuser pour un
			# résultat que personne ne suit à l'œil, ça ne valait pas le prix.
			_effet_depart_de_coup(Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))),
				float(charge.get("a", 0.0)))
		"mort":
			# Une élimination ne compte que si elle a eu lieu dans une arène :
			# ailleurs, les joueurs ne peuvent pas se blesser, et une mort est
			# le fait de la ville — personne ne la porte à son tableau.
			if not est_hote():
				return
			var par := String(charge.get("par", ""))
			var victime := String(charge.get("j", ""))
			var ou := Vector2(float(charge.get("x", 0)), float(charge.get("y", 0)))
			if par == "" or par == victime or carte.arene_de(ou) < 0:
				return
			ville.compter_frag(par, ou)
			_vider_les_evenements()

func _recevoir_joueur(charge: Dictionary) -> void:
	var cle := String(charge.get("cle", ""))
	if cle == "" or cle == Session.cle:
		return
	var cible := Vector2(float(charge.get("x", 0)), float(charge.get("y", 0)))
	if not _autres.has(cle):
		var place := int(joueurs.get(cle, {}).get("place", 1))
		var pseudo := String(joueurs.get(cle, {}).get("pseudo", ""))
		var couleur := Palette.couleur_joueur(place)
		var auto := FormesCarnage.voiture(couleur, pseudo)
		auto.position = Decor.vers3d(cible)
		monde().add_child(auto)
		var pieton := FormesCarnage.pieton(couleur, false, pseudo, true)
		pieton.visible = false
		monde().add_child(pieton)
		_autres[cle] = {"p": cible, "a": 0.0, "v": 0.0, "vie": VIE_MAX, "cible": cible,
			"angle_cible": 0.0, "pied": false, "etat": 1, "eperon": false, "modele": -1,
			"genre": VilleVivante.CIVILE, "auto": auto, "pieton": pieton}
	var a: Dictionary = _autres[cle]
	a["cible"] = cible
	a["angle_cible"] = float(charge.get("a", 0.0))
	a["v"] = float(charge.get("s", 0))
	a["vie"] = float(charge.get("h", VIE_MAX))
	a["etat"] = int(charge.get("e", 1))
	a["pied"] = int(charge.get("e", 1)) == 0
	a["genre"] = int(charge.get("vg", VilleVivante.CIVILE))
	a["eperon"] = int(charge.get("ep", 0)) == 1
	var modele := int(charge.get("vm", -1))
	if modele != int(a.get("modele", -1)):
		# Il a changé de voiture : on rebâtit la sienne. Le nœud d'avant part.
		a["modele"] = modele
		(a["auto"] as Node3D).queue_free()
		var neuf := _batir_voiture_de(modele,
			Palette.couleur_joueur(int(joueurs.get(cle, {}).get("place", 1))),
			String(joueurs.get(cle, {}).get("pseudo", "")))
		neuf.position = Decor.vers3d(cible)
		monde().add_child(neuf)
		a["auto"] = neuf

# ------------------------------------------------------- dégâts

func _encaisser(degats: float, cause: String, par: String) -> void:
	if _hors_service > 0.0:
		return
	_depuis_coup = 0.0
	if par != "":
		_dernier_agresseur = par
	_vie -= max(1.0, degats) * (FRAGILITE_A_PIED if _pied else 1.0)
	if not _pied:
		_vitesse *= 0.35
		_pv_vehicule = max(0.0, _pv_vehicule - degats * 0.6)
	_secousse = max(_secousse, 0.5)
	if _vie <= 0.0:
		_tomber()
	elif cause != "balle":
		_sonne = 0.35
		Sons.jouer("choc", 1.0, -6.0)

func _tomber() -> void:
	_vie = 0.0
	_hors_service = HORS_SERVICE
	Sons.jouer("ecrasement", 0.5, -3.0)
	Sons.arreter_moteur()
	canal.envoyer("mort", {"j": Session.cle, "par": _dernier_agresseur,
		"x": int(_position.x), "y": int(_position.y)})
	if est_hote() and _dernier_agresseur != "" and carte.arene_de(_position) >= 0:
		ville.compter_frag(_dernier_agresseur, _position)
		_vider_les_evenements()
	_dernier_agresseur = ""

func _vehicule_detruit() -> void:
	_effet_explosion(_position)
	canal.envoyer("boum", {"x": int(_position.x), "y": int(_position.y)})
	# On la rend à l'hôte en morceaux. Sans ce message, il continuerait de la
	# croire conduite : elle ne serait plus simulée, plus diffusée, et
	# resterait invisible au milieu de la rue jusqu'à la fin de la manche.
	if _vehicule != 0:
		canal.envoyer("sort", {"id": _vehicule, "x": int(_position.x), "y": int(_position.y),
			"a": snapped(_angle, 0.01), "pv": 0, "g": _genre_vehicule, "m": _modele_vehicule})
		if est_hote():
			ville.rendre_vehicule(Session.cle, _vehicule, _position, _angle, 0.0, _modele_vehicule, _genre_vehicule)
			_vider_les_evenements()
	_encaisser(35.0, "boum", "")
	if _hors_service <= 0.0:
		# On est éjecté : la carcasse reste, le joueur repart à pied.
		_pied = true
		_vitesse = 0.0
		_vehicule = 0
		_modele_vehicule = -1
		_pv_vehicule = PV_VOITURE
		Tactile.mode = Tactile.MARCHE
		Sons.arreter_moteur()

## On se relève à pied, loin de là où on est tombé, et la police a un peu
## oublié. Réapparaître au volant serait plus confortable et retirerait tout
## poids à la mort.
func _relever() -> void:
	_vie = VIE_MAX
	_hors_service = 0.0
	_sonne = 0.0
	_vitesse = 0.0
	_pied = true
	_vehicule = 0
	_modele_vehicule = -1
	_pv_vehicule = PV_VOITURE
	_reprendre_le_pistolet()
	_eperon = 0.0
	Tactile.mode = Tactile.MARCHE
	_position = carte.point_de_rue(_rng, carte.centre(), 200.0,
		max(carte.etendue().x, carte.etendue().y) * 0.45)
	Sons.jouer("depart", 0.8, -8.0)

# ------------------------------------------------------- effets

func _effet_gain(position: Vector2, points: int, facteur: int, cle: String, quoi: String) -> void:
	var couleur := Palette.couleur_joueur(int(joueurs.get(cle, {}).get("place", 0)))
	Sons.jouer("ecrasement", _rng.randf_range(0.85, 1.2), -8.0)

	if quoi == "pieton" or quoi == "gang" or quoi == "flic":
		# Une flaque au sol, bien plus sombre que la foule : à la même teinte,
		# elle se lit comme une cible et on fonce dessus pour rien. Leur
		# nombre est borné — sans plafond, une manche pleine empile des
		# centaines de maillages.
		var flaque := Decor.cylindre(_rng.randf_range(1.1, 1.9), 0.08,
			Palette.CRITIQUE.darkened(0.72), false)
		flaque.position = Decor.vers3d(position, 0.05)
		flaque.rotation.y = _rng.randf() * TAU
		monde().add_child(flaque)
		_taches.append(flaque)
		if _taches.size() > 80:
			(_taches.pop_front() as Node3D).queue_free()

	for i in 10:
		var eclat := Decor.sphere(_rng.randf_range(0.18, 0.42), Palette.CRITIQUE, false)
		eclat.position = Decor.vers3d(position, 1.0)
		monde().add_child(eclat)
		var direction := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(1.4, 3.2), _rng.randf_range(-1, 1))
		_eclats.append({"noeud": eclat, "v": direction * _rng.randf_range(6, 14), "t": 1.0, "t0": 1.0})

	var mention := Decor.etiquette("+%d%s" % [points, ("  x%d" % facteur) if facteur > 1 else ""],
		couleur, 44)
	mention.position = Decor.vers3d(position, 3.0)
	monde().add_child(mention)
	_eclats.append({"noeud": mention, "v": Vector3(0, 7.0, 0), "t": 1.1, "t0": 1.1, "texte": true})

func _effet_explosion(position: Vector2) -> void:
	Sons.jouer("ecrasement", 0.6, -4.0)
	_secousse = max(_secousse, 0.4)
	for i in 18:
		var eclat := Decor.sphere(_rng.randf_range(0.3, 0.7), Palette.SERIEUX, false)
		eclat.material_override = Decor.matiere_lumineuse(Palette.SERIEUX, 1.2)
		eclat.position = Decor.vers3d(position, 1.2)
		monde().add_child(eclat)
		var direction := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.6, 2.4), _rng.randf_range(-1, 1))
		_eclats.append({"noeud": eclat, "v": direction * _rng.randf_range(14, 26), "t": 0.7, "t0": 0.7})

func _effet_depart_de_coup(position: Vector2, angle: float) -> void:
	# ⚠ Ne pas appeler cette variable `trait` : le mot est réservé par GDScript
	# et l'erreur qui en sort ne parle que d'un « nom de variable attendu ».
	var lueur := Decor.sphere(0.3, Palette.AVERTISSEMENT, false)
	lueur.material_override = Decor.matiere_lumineuse(Palette.AVERTISSEMENT, 1.4)
	lueur.position = Decor.vers3d(position + Vector2.RIGHT.rotated(angle) * 22.0, 1.4)
	monde().add_child(lueur)
	var vers := Vector2.RIGHT.rotated(angle)
	_eclats.append({"noeud": lueur, "v": Vector3(vers.x, 0.0, vers.y) * 34.0, "t": 0.22, "t0": 0.22})

func _animer_effets(delta: float) -> void:
	var restants: Array = []
	for e in _eclats:
		e["t"] = float(e["t"]) - delta
		var noeud: Node3D = e["noeud"]
		if float(e["t"]) <= 0.0:
			noeud.queue_free()
			continue
		var v: Vector3 = e["v"]
		noeud.position += v * delta
		if not e.has("texte"):
			v.y -= 26.0 * delta          # les éclats retombent
			e["v"] = v
			if noeud.position.y < 0.12:
				noeud.position.y = 0.12
				e["v"] = Vector3(v.x * 0.4, -v.y * 0.35, v.z * 0.4)
		var reste: float = clamp(float(e["t"]) / float(e["t0"]), 0.0, 1.0)
		if noeud is Label3D:
			(noeud as Label3D).modulate.a = reste
		else:
			noeud.scale = Vector3.ONE * max(0.05, reste)
		restants.append(e)
	_eclats = restants

# ------------------------------------------------------- rendu

var _batisses := 0

func rafraichir_scene(delta: float) -> void:
	_batisses = 0
	_placer_le_joueur(delta)
	_placer_les_autres()
	_placer_la_foule()
	_placer_les_autos()
	_placer_les_objets()
	_animer_effets(delta)
	_placer_camera(delta)
	_animer_les_cabines()
	_faire_hurler_la_police(delta)
	_rafraichir_contrat(delta)
	_rafraichir_radar()
	_rafraichir_banniere(delta)

## Le nom du quartier quand on en change. Trois secondes, puis plus rien : une
## bannière permanente serait un panneau de plus dans un écran déjà chargé.
func _rafraichir_banniere(delta: float) -> void:
	if _hud_banniere == null:
		return
	var territoire := carte.territoire(_position)
	var quartier := carte.quartier(_position)
	if territoire != _territoire_vu or quartier != _quartier_vu:
		_territoire_vu = territoire
		_quartier_vu = quartier
		var texte := carte.nom_du_quartier(_position).capitalize()
		var couleur := Palette.ENCRE_DOUCE
		if territoire >= 0:
			texte += " — chez %s" % carte.nom_du_gang(territoire)
			couleur = carte.couleur_du_gang(territoire)
		_hud_banniere.text = texte
		_hud_banniere.add_theme_color_override("font_color", couleur)
		_banniere_reste = 3.2
	_banniere_reste -= delta
	_hud_banniere.modulate.a = clamp(_banniere_reste / 0.8, 0.0, 1.0)

## Le plan ne se redessine qu'avec ce qu'il montre : positions des joueurs,
## patrouilles lancées, étoiles. Lui passer la ville entière image par image
## coûterait plus cher que la partie.
func _rafraichir_radar() -> void:
	if _radar == null:
		return
	_radar.moi = _position
	_radar.mon_angle = _angle
	_radar.ma_couleur = _ma_couleur()
	_radar.etoiles = ville.etoiles(Session.cle)
	var voisins: Array = []
	for cle in _autres:
		var a: Dictionary = _autres[cle]
		voisins.append({"p": a["p"],
			"couleur": Palette.couleur_joueur(int(joueurs.get(cle, {}).get("place", 1)))})
	_radar.autres = voisins
	var bleus: Array = []
	for auto in ville.autos:
		if int(auto["genre"]) == VilleVivante.PATROUILLE:
			bleus.append(auto["p"])
	_radar.patrouilles = bleus
	_radar.queue_redraw()

## Le halo d'une cabine clignote tant qu'on n'a pas de contrat en main. Une
## cabine qui appelle alors qu'on est déjà pris ferait faire un détour pour rien.
func _animer_les_cabines() -> void:
	var libre := _contrat.is_empty()
	for poste in _cabines_posees:
		var halo := (poste as Node3D).get_node_or_null("Halo") as Node3D
		if halo:
			halo.visible = libre and fmod(temps, 1.0) > 0.42
		var mot := (poste as Node3D).get_node_or_null("Mot") as Node3D
		if mot:
			mot.visible = libre

## Une poursuite s'entend avant de se voir : c'est la sirène qui dit qu'il faut
## tourner tout de suite, pas la voiture aperçue trois rues plus loin.
func _faire_hurler_la_police(delta: float) -> void:
	var niveau := ville.etoiles(Session.cle)
	if niveau <= 0:
		_depuis_sirene = 0.0
		return
	_depuis_sirene -= delta
	if _depuis_sirene > 0.0:
		return
	_depuis_sirene = max(0.7, 1.6 - 0.18 * float(niveau))
	Sons.jouer("sirene", 1.0 + 0.06 * float(niveau), -16.0)

func _rafraichir_contrat(delta: float) -> void:
	if _hud_contrat == null:
		return
	if _contrat.is_empty():
		_hud_contrat.text = ""
		return
	_contrat["r"] = max(0.0, float(_contrat["r"]) - delta)
	var avance := ""
	if int(_contrat["n"]) > 1:
		avance = "  %d/%d" % [int(_contrat["a"]), int(_contrat["n"])]
	_hud_contrat.text = "CONTRAT — %s%s   ·   %d s" % [
		String(_contrat["t"]), avance, int(ceil(float(_contrat["r"])))]
	_hud_contrat.add_theme_color_override("font_color",
		Palette.CRITIQUE if float(_contrat["r"]) <= 8.0 else Palette.AVERTISSEMENT)

func _placer_le_joueur(delta: float) -> void:
	_corps_auto.visible = not _pied and _hors_service <= 0.0
	_corps_pied.visible = _pied and (_hors_service <= 0.0 or fmod(_hors_service, 0.3) > 0.15)

	if _corps_auto.visible:
		_corps_auto.position = Decor.vers3d(_position, 0.0)
		_corps_auto.rotation.y = -_angle
		# Assiette : la voiture pique du nez au freinage et se cabre à
		# l'accélération. Trois degrés suffisent à faire sentir la masse.
		var assiette: float = clamp(_vitesse / VITESSE_MAX, -1.0, 1.0)
		_corps_auto.rotation.z = lerp(_corps_auto.rotation.z, deg_to_rad(-assiette * 3.0),
			clamp(delta * 6.0, 0, 1))
		if _sonne > 0.0:
			_corps_auto.rotation.z = sin(_sonne * 40.0) * 0.25
		var buffle := _corps_auto.get_node_or_null("Buffle") as MeshInstance3D
		if buffle:
			buffle.visible = _eperon > 0.0
		_regler_jauge(_corps_auto, _pv_vehicule / PV_VOITURE)

	if _corps_pied.visible:
		_corps_pied.position = Decor.vers3d(_position, 0.0)
		_corps_pied.rotation.y = -_angle + PI * 0.5
		_demarche(_corps_pied, "walk" if abs(_vitesse) > 1.0 else "idle")
		_regler_jauge(_corps_pied, _vie / VIE_MAX)

func _placer_les_autres() -> void:
	for cle in _autres:
		var a: Dictionary = _autres[cle]
		var au_volant: bool = not bool(a["pied"]) and int(a.get("etat", 1)) != 2
		var a_pied: bool = bool(a["pied"]) and int(a.get("etat", 1)) != 2
		var auto: Node3D = a["auto"]
		var pieton: Node3D = a["pieton"]
		auto.visible = au_volant
		pieton.visible = a_pied
		if au_volant:
			auto.position = Decor.vers3d(a["p"])
			auto.rotation.y = -float(a["a"])
			var gyro := auto.get_node_or_null("Gyrophare")
			if gyro:
				gyro.visible = int(a.get("genre", 0)) == VilleVivante.PATROUILLE
			var buffle := auto.get_node_or_null("Buffle") as MeshInstance3D
			if buffle:
				buffle.visible = bool(a.get("eperon", false))
			_regler_jauge(auto, float(a["vie"]) / VIE_MAX)
		if a_pied:
			pieton.position = Decor.vers3d(a["p"])
			pieton.rotation.y = -float(a["a"]) + PI * 0.5
			_demarche(pieton, "walk" if abs(float(a.get("v", 0.0))) > 1.0 else "idle")
			_regler_jauge(pieton, float(a["vie"]) / VIE_MAX)

func _placer_la_foule() -> void:
	for personne in ville.gens:
		var noeud = personne.get("noeud")
		if noeud == null:
			if (personne["p"] as Vector2).distance_to(_position) > PORTEE_RENDU or _batisses >= BATISSES_PAR_IMAGE:
				continue
			_batisses += 1
			noeud = FormesCarnage.pieton(_couleur_de(personne), int(personne["genre"]) == VilleVivante.GANG)
			monde().add_child(noeud)
			personne["noeud"] = noeud
			# La foule marche du début à la fin : la démarche se lance une
			# fois, à la naissance. Appelée à chaque image, elle coûterait
			# quarante-six parcours d'arbre par trame pour ne rien changer.
			Decor.demarche(noeud, "walk")
		var corps: Node3D = noeud
		corps.visible = (personne["p"] as Vector2).distance_to(_position) <= PORTEE_RENDU
		if not corps.visible:
			continue
		corps.position = Decor.vers3d(personne["p"])
		corps.rotation.y = -float(personne.get("a", 0.0)) + PI * 0.5
		_regler_jauge(corps, float(int(personne["pv"])) / float(_pv_max_de(personne)))

func _couleur_de(personne: Dictionary) -> Color:
	match int(personne["genre"]):
		VilleVivante.GANG:
			return carte.couleur_du_gang(int(personne["gang"]))
		VilleVivante.FLIC:
			return Palette.SERIE
	return Palette.ENCRE_DOUCE

func _pv_max_de(personne: Dictionary) -> int:
	match int(personne["genre"]):
		VilleVivante.GANG:
			return VilleVivante.PV_GANG
		VilleVivante.FLIC:
			return VilleVivante.PV_FLIC
	return VilleVivante.PV_PIETON

func _placer_les_autos() -> void:
	for auto in ville.autos:
		if String(auto.get("pilote", "")) != "":
			var conduit = auto.get("noeud")
			if conduit != null:
				(conduit as Node3D).visible = false
			continue
		var noeud = auto.get("noeud")
		var genre := int(auto["genre"])
		# Ce qui est à plus d'un écran et demi n'est pas dessiné : l'hôte a
		# trois cents voitures dans sa liste, et un navigateur en mode
		# compatibilité n'en dessine pas trois cents.
		var proche: bool = (auto["p"] as Vector2).distance_to(_position) <= PORTEE_RENDU
		if noeud == null:
			if not proche or _batisses >= BATISSES_PAR_IMAGE:
				continue
			_batisses += 1
			if genre == VilleVivante.EPAVE:
				noeud = FormesCarnage.epave()
			else:
				var couleur := Color.WHITE
				if genre == VilleVivante.VOITURE_GANG:
					couleur = carte.couleur_du_gang(int(auto.get("gang", 0)))
				noeud = FormesCarnage.voiture_kit(int(auto.get("modele", 0)), couleur)
			monde().add_child(noeud)
			auto["noeud"] = noeud
		elif genre == VilleVivante.EPAVE and not auto.get("epave_vue", false):
			# Elle vient de brûler : la coque saine part, la carcasse la remplace.
			(noeud as Node3D).queue_free()
			noeud = FormesCarnage.epave()
			monde().add_child(noeud)
			auto["noeud"] = noeud
		auto["epave_vue"] = genre == VilleVivante.EPAVE
		var corps: Node3D = noeud
		corps.visible = proche
		corps.position = Decor.vers3d(auto["p"])
		corps.rotation.y = -float(auto["a"])
		_regler_jauge(corps, float(auto["pv"]) / PV_VOITURE)

func _placer_les_objets() -> void:
	for caisse in ville.caisses:
		var noeud = caisse.get("noeud")
		if noeud == null:
			var arme := String(caisse["arme"])
			noeud = FormesCarnage.caisse(arme, ARMES.get(arme, ARMES["pistolet"])["couleur"])
			monde().add_child(noeud)
			caisse["noeud"] = noeud
		(noeud as Node3D).position = Decor.vers3d(caisse["p"])
		var objet := (noeud as Node3D).get_node_or_null("Objet") as Node3D
		if objet:
			objet.rotation.y = temps * 1.3
			objet.position.y = 1.6 + sin(temps * 2.2 + float(int(caisse["id"]))) * 0.28

	for b in ville.barrages:
		var noeud = b.get("noeud")
		if noeud == null:
			noeud = FormesCarnage.barrage()
			monde().add_child(noeud)
			b["noeud"] = noeud
		(noeud as Node3D).position = Decor.vers3d(b["p"])
		var gyro := (noeud as Node3D).get_node_or_null("Gyro") as Node3D
		if gyro:
			gyro.visible = fmod(temps, 0.7) > 0.35

## Change la démarche d'un porteur en retenant celle qui tourne : sans cette
## mémoire, il faut parcourir l'arbre du personnage à chaque image pour
## retrouver son lecteur d'animation.
var _demarches: Dictionary = {}

func _demarche(porteur: Node3D, nom: String) -> void:
	if String(_demarches.get(porteur.get_instance_id(), "")) == nom:
		return
	_demarches[porteur.get_instance_id()] = nom
	Decor.demarche(porteur, nom)

## La jauge est fille de son porteur : sans compenser la rotation, elle
## tournerait avec lui et deviendrait illisible dès le premier virage.
func _regler_jauge(porteur: Node3D, part: float) -> void:
	var jauge := porteur.get_node_or_null("Vie") as Node3D
	if jauge == null:
		return
	jauge.rotation.y = -porteur.rotation.y
	jauge.visible = part < 0.999
	if jauge.visible:
		Decor.remplir(jauge, clamp(part, 0.0, 1.0))

func _placer_camera(delta: float) -> void:
	if _camera == null:
		return
	var distance: float = DISTANCE_PIED if _pied else DISTANCE_AUTO
	var vise := Decor.viser(_camera, _position, INCLINAISON, distance)
	if _secousse > 0.0:
		_secousse = max(0.0, _secousse - delta * 2.0)
		vise += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * _secousse * 2.5
	_camera.position = _camera.position.lerp(vise, clamp(delta * 7.0, 0, 1))

# ------------------------------------------------------- état affiché

## La ligne du bas : ce qui change souvent. Les étoiles d'abord — c'est ce qui
## décide de la minute qui vient.
func etat_joueur() -> String:
	if _hors_service > 0.0:
		return "À TERRE — vous vous relevez dans %d s" % int(ceil(_hors_service))
	var morceaux: Array = []

	var niveau := ville.etoiles(Session.cle)
	if niveau > 0:
		morceaux.append("RECHERCHÉ %s (%d)" % ["★".repeat(niveau), niveau])
	morceaux.append("Vie %d%%" % int(_vie))
	if not _pied:
		morceaux.append("Tôle %d%%" % int(_pv_vehicule))
	morceaux.append("%s%s" % [String(ARMES[_arme]["nom"]),
		"" if _munitions < 0 else " %d" % _munitions])
	if _eperon > 0.0:
		morceaux.append("Éperon %ds" % int(ceil(_eperon)))

	var territoire := carte.territoire(_position)
	var jauge := ville.respect_de(Session.cle)
	var humeur := "neutre"
	if ville.gang_hostile(Session.cle, territoire):
		humeur = "vous chasse"
	elif ville.gang_ami(Session.cle, territoire):
		humeur = "vous laisse"
	if territoire >= 0:
		morceaux.append("%s : %s (%d)" % [carte.nom_du_gang(territoire), humeur, int(jauge[territoire])])
	else:
		morceaux.append("centre — terrain neutre")

	if carte.arene_de(_position) >= 0:
		morceaux.append("ARÈNE — TIR AMI ACTIF")
	if carte.garage_de(_position) >= 0:
		morceaux.append("GARAGE — repeint")
	if _pied:
		var auto := ville.vehicule_proche(_position, PORTEE_ENTREE)
		morceaux.append("E : monter" if not auto.is_empty() else "à pied")
	if _hors_ville > 0.2:
		morceaux.append("VOUS QUITTEZ LA VILLE")
	return "   ·   ".join(morceaux)
