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
const BRAQUAGE := 2.9              ## rad/s au braquage plein ; 3,6 rendait la voiture nerveuse comme un kart
## La voiture a du POIDS : sa trajectoire suit son cap avec un retard qui
## grandit avec la vitesse — à fond, elle dérive dans les virages ; au pas,
## elle tourne sur place. C'est l'inertie qui manquait pour que la conduite
## se sente, sans rien enlever du contrôle.
const ADHERENCE_LENTE := 11.0
const ADHERENCE_RAPIDE := 3.4
## La collision de la voiture est une CAPSULE — deux cercles à l'avant et à
## l'arrière — et non un cercle de sa demi-longueur : celui-ci cognait un mur
## situé à dix pixels du flanc, et toute la conduite en rue étroite s'en
## sentait.
const RAYON_CAPSULE := 13.0
const DEMI_EMPATTEMENT := 15.0
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
## ⚠ 79°, pas 70 : avec les tours du centre, à 70° une tour au sud du joueur le
## cachait entièrement. À 76° et des tours de trente unités, la façade d'une
## tour en bas d'écran couvrait encore un quart de l'image. GTA 2 se joue de
## dessus ; on recule un peu pour garder la rue entière.
const INCLINAISON := 72.0
const DISTANCE_AUTO := 64.0
const DISTANCE_PIED := 40.0

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
## Les MORCEAUX de ville : bâtis quand leur bord passe à moins de
## PORTEE_MORCEAU du joueur, un par image au plus, libérés au-delà de
## LIBERATION. Neuf morceaux suffisent à couvrir l'écran et sa marge.
const PORTEE_MORCEAU := 1500.0
const LIBERATION := 3400.0
## La caméra recule avec la vitesse : à fond, on voit venir le carrefour.
const RECUL_VITESSE := 16.0

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

## Toutes les voitures ne se conduisent pas pareil : la sportive file, le
## camion pèse et encaisse, la police pousse. Sans ça, voler une voiture ne
## change que la peinture — et on ne vole plus rien.
## v : vitesse de pointe, a : accélération, t : solidité de la tôle.
const CARACTERES := {
	-1: {"v": 1.0, "a": 1.0, "t": 1.0},     # la Volvo
	0: {"v": 1.0, "a": 1.0, "t": 1.0},      # berline
	1: {"v": 1.2, "a": 1.18, "t": 0.75},    # berline sport
	2: {"v": 1.14, "a": 1.22, "t": 0.7},    # compacte sport
	3: {"v": 0.96, "a": 0.95, "t": 1.25},   # 4x4
	4: {"v": 1.05, "a": 1.0, "t": 1.15},    # 4x4 de luxe
	5: {"v": 1.0, "a": 1.05, "t": 0.9},     # taxi
	6: {"v": 0.9, "a": 0.85, "t": 1.3},     # fourgon
	7: {"v": 0.82, "a": 0.72, "t": 1.6},    # camion de livraison
	8: {"v": 0.78, "a": 0.68, "t": 1.8},    # camion
	9: {"v": 1.12, "a": 1.1, "t": 1.0},     # police
	10: {"v": 1.22, "a": 1.2, "t": 0.7},    # coupé
	11: {"v": 0.98, "a": 0.95, "t": 1.1},   # break
	12: {"v": 0.95, "a": 0.9, "t": 1.3},    # pick-up
	13: {"v": 0.72, "a": 0.6, "t": 2.2},    # bus
	14: {"v": 0.95, "a": 0.8, "t": 1.4},    # limousine
	15: {"v": 1.0, "a": 0.95, "t": 1.3},    # ambulance
	16: {"v": 1.24, "a": 1.45, "t": 0.35},  # moto : file et tourne, mais rien autour de soi
	17: {"v": 1.34, "a": 1.55, "t": 0.3},   # moto de course
	18: {"v": 0.86, "a": 0.74, "t": 2.0},   # camion de pompiers
}

## Le butin qui n'est pas une arme : une trousse rend cinquante points de vie,
## un billet vaut cent vingt dollars — comptés par l'hôte, comme tout le reste.
const COULEURS_BUTIN := {"vie": Palette.BON, "argent": Palette.AVERTISSEMENT}
const SOIN_TROUSSE := 50.0
const KLAXON_DELAI := 0.9

## Identifiant de la voiture de départ. Elle n'appartient à personne dans la
## liste de l'hôte tant qu'on ne l'a pas quittée : le premier `sortir` la lui
## fait découvrir. Le nombre est haut pour ne jamais croiser un identifiant
## engendré pendant la manche.
const ID_VOITURE_DEPART := 10000

var carte: PlanVille
var ville: VilleVivante
var _ambiance: Array = []            ## [WorldEnvironment, soleil, lune], réglés à l'heure du village
var _morceaux: Dictionary = {}       ## Vector2i -> MorceauVille, les morceaux bâtis ou en chantier
var _chantier: MorceauVille = null   ## le morceau en cours de construction, une étape par image
var _cachees: Dictionary = {}        ## id dormante -> vrai : déjà effacée de sa nappe

# ------------------------------------------------------- le joueur local
var _position := Vector2.ZERO
var _angle := 0.0
var _vitesse := 0.0
var _glisse := Vector2.RIGHT          ## la direction réelle du mouvement (l'inertie)
# ------------------------------------------------------- l'argent et la planque
#
# Les points sont des DOLLARS. Ce qu'on a sur soi (`_argent`) se perd quand on
# tombe : la police ramasse. Ce qu'on a déposé à la planque (`_banque`) est à
# l'abri, et c'est lui qui donne une raison de rentrer chez soi vivant plutôt
# que de foncer jusqu'à la mort. Le score du classement reste la FORTUNE
# totale (sur soi + en banque) : le tableau ne change pas de sens.
var _argent := 0
var _banque := 0
var _planque := -1                 ## l'identifiant de la planque possédée, ou -1
var _ameliorations: Dictionary = {"coffre": false, "arsenal": false, "garage": false}
var _garage_perso := -1            ## le modèle de véhicule rangé à la planque, ou -1
var _planque_en_cours := -1        ## la planque dans laquelle on se tient
var _hopital_en_cours := -1
var _affaire := ""                 ## ce que F ferait ici, pour la ligne du HUD
var _mot_affaire := ""             ## le dernier message d'affaire, affiché deux secondes
var _mot_affaire_reste := 0.0

## Le tarif de l'hôpital : on ressort debout, la note est salée.
const SOIN := 400
## Ce que la police ramasse quand on tombe : TOUT ce qu'on a sur soi quand on
## a une planque où l'on aurait pu le mettre à l'abri — la moitié seulement
## tant qu'on n'en a pas, sinon le premier achat est hors de portée et la
## mécanique ne démarre jamais.
const SAISIE := 1.0
const SAISIE_SANS_PLANQUE := 0.5

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
var _depuis_klaxon := 0.0
var _depuis_battement := 0.0
var _cible_contrat: Dictionary = {}
var _contrat_duree := 0.0            ## durée initiale du contrat en main, pour le sablier du HUD
var _radar: Control
var _plan_image: Image                ## la carte entière, un pixel par tuile, peinte par lots
var _plan_texture: ImageTexture
var _plan_pate := 0                   ## prochain pâté à peindre
var _plan_secteur := 0                ## prochain secteur dont peindre les lieux
var _plan_vue: Control                ## l'incrustation, TAB tenu
var _hud_banniere: Label
var _banniere_reste := 0.0
var _territoire_vu := -99
var _quartier_vu := -99

var _traces: MultiMesh                ## les traces de pneus, en anneau
var _trace_suivante := 0
var _depuis_trace := 0.0
const TRACES_MAX := 320
var _autres: Dictionary = {}       ## cle -> état distant + nœuds 3D
var _projectiles: Array = []
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
	return "Z/S : avancer et freiner · Q/D : tourner · ESPACE : tirer · E : monter ou descendre · F : affaires (planque, hôpital) · H : klaxon · TAB : carte · caisse = arme, trousse ou billet · garage bleu = étoiles effacées · cabine jaune = contrat · maison violette = planque à acheter · croix blanche = hôpital"

# ------------------------------------------------------- mise en place

func preparer() -> void:
	var chrono := Time.get_ticks_msec()
	# Carnage n'a plus de chrono : on reste en ville tant qu'on veut, on rentre
	# déposer son argent, et on sort par le hub. Le banc garde une fin
	# (`duree_forcee`), sinon il ne rendrait jamais la main.
	sans_limite = Partie.duree_forcee <= 0.0
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
	# `--banc-position=colonne,ligne` (en tuiles) : partir ailleurs qu'au
	# centre. La ville fait six cent quatre-vingts tuiles ; sans ça, le banc ne
	# photographierait jamais le port ni la banlieue.
	if Commandes.pilote_automatique:
		for argument in OS.get_cmdline_args():
			if String(argument).begins_with("--banc-position="):
				var xy := String(argument).substr(16).split(",")
				if xy.size() == 2:
					_position = carte.point_de_rue(_rng,
						Vector2(float(xy[0]), float(xy[1])) * PlanVille.PAS, 0.0, 160.0)
				elif String(argument).ends_with("etoile"):
					# `--banc-position=etoile` : partir près de la grande place, dont
					# la position dépend du code de la manche.
					_position = carte.point_de_rue(_rng, carte.place_etoile(), 320.0, 480.0)
	_vehicule = ID_VOITURE_DEPART + place
	_pied = false

	_corps_auto = FormesCarnage.voiture(_ma_couleur(), Session.pseudo)
	_corps_auto.add_child(FormesCarnage.echappement(-2.4))
	FormesCarnage.projecteurs(_corps_auto, 2.2)
	monde().add_child(_corps_auto)

	# Le post-traitement (vignette, grain) : premier enfant de la couche, donc
	# SOUS l'interface — le HUD ne doit pas prendre le grain.
	var post := ColorRect.new()
	post.name = "Post"
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post.material = MatieresCarnage.post()
	interface().add_child(post)
	interface().move_child(post, 0)

	# Les traces de pneus : une nappe d'instances qu'on réutilise en anneau.
	# Un rectangle par roue et par pas de temps, qui pâlit avec l'âge.
	_traces = MultiMesh.new()
	_traces.transform_format = MultiMesh.TRANSFORM_3D
	_traces.use_colors = true
	var dalle := QuadMesh.new()
	dalle.size = Vector2(1.0, 1.0)
	dalle.orientation = PlaneMesh.FACE_Y
	_traces.mesh = dalle
	_traces.instance_count = TRACES_MAX
	for i in TRACES_MAX:
		_traces.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(0.001, 0.001, 0.001)), Vector3(0, -50, 0)))
		_traces.set_instance_color(i, Color(0, 0, 0, 0))
	var noeud_t := MultiMeshInstance3D.new()
	noeud_t.multimesh = _traces
	noeud_t.material_override = MatieresCarnage.trace()
	noeud_t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	monde().add_child(noeud_t)
	_corps_pied = FormesCarnage.pieton(_ma_couleur(), false, Session.pseudo, true,
		FormesCarnage.PEAU_JOUEUR)
	_corps_pied.visible = false
	monde().add_child(_corps_pied)

	# La bannière : le nom du quartier et de qui le tient, quand on y entre.
	# Le sol change de teinte, mais une teinte ne se nomme pas toute seule.
	# Elle se pose sous les étoiles du HUD, qui occupent le haut du milieu.
	_hud_banniere = UI.titre("", 16)
	_hud_banniere.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hud_banniere.offset_top = 64
	_hud_banniere.offset_bottom = 90
	_hud_banniere.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interface().add_child(_hud_banniere)

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

	# La carte de la ville (TAB) : une image d'un pixel par tuile, peinte par
	# lots pendant la manche, incrustée au milieu de l'écran tant qu'on tient la
	# touche. C'est la carte de GTA 2 : l'île, la rivière, la voie ferrée, les
	# quartiers, et où l'on est.
	_plan_image = Image.create(PlanVille.COLONNES, PlanVille.LIGNES, false, Image.FORMAT_RGB8)
	_plan_image.fill(PlanVille.CARTE_EAU)
	_plan_texture = ImageTexture.create_from_image(_plan_image)
	_plan_vue = Control.new()
	_plan_vue.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plan_vue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plan_vue.visible = false
	_plan_vue.draw.connect(_dessiner_le_plan)
	interface().add_child(_plan_vue)

	# Les quatre morceaux les plus proches du départ, tout de suite ; les autres
	# suivent à un par image pendant le décompte. Bâtir les neuf d'un coup
	# bloquait le fil principal une seconde et demie dans le navigateur.
	_diffuser_la_ville(4)

	# Le temps de mise en place, toujours : dans le navigateur, une préparation
	# qui bloque le fil principal plusieurs secondes fait tomber le socket.
	print("[carnage] ville prête en %d ms — %d morceaux, %d fiches en cache" % [
		Time.get_ticks_msec() - chrono, _morceaux.size(), carte.fiches_en_cache()])

	# `--banc-feu=N` : allumer N foyers autour du départ. Un incendie ne se
	# commande pas au pilote automatique, et c'est ce qu'il faut photographier.
	for argument in OS.get_cmdline_args():
		if String(argument).begins_with("--banc-feu="):
			_feux_de_banc = int(String(argument).substr(11))

	# `--banc-etoiles=N` : partir déjà recherché. Attendre qu'un pilote au hasard
	# gagne cinq étoiles pour voir l'hélicoptère, c'est attendre une manche sur
	# quatre — la police et l'hélicoptère se vérifient en trente secondes avec ça.
	if Commandes.pilote_automatique:
		for argument in OS.get_cmdline_args():
			if String(argument).begins_with("--banc-etoiles="):
				var niveau := int(String(argument).substr(15))
				if niveau > 0:
					ville.chaleur[Session.cle] = float(VilleVivante.PALIERS[min(niveau, 5) - 1]) + 40.0
					ville._depuis_crime[Session.cle] = 0.0

## La carrosserie qu'on conduit : la Volvo au départ, puis ce qu'on a volé. On
## reconstruit le nœud plutôt que d'en garder dix cachés — une voiture volée
## par manche, ça se compte sur les doigts.
func _rebatir_ma_voiture() -> void:
	if _corps_auto != null:
		_corps_auto.queue_free()
	_corps_auto = _batir_voiture_de(_modele_vehicule, _ma_couleur(), Session.pseudo)
	FormesCarnage.projecteurs(_corps_auto, 2.2)
	_corps_auto.add_child(FormesCarnage.echappement(-2.4 if _modele_vehicule < 0 else -2.2))
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

## L'heure bleue, et rien d'autre : la ville elle-même arrive par morceaux,
## autour du joueur, dans `_diffuser_la_ville`. Les lieux (repaires, garages,
## cabines, arènes) vivent dans le morceau qui porte leur pâté.
func _planter_decor() -> void:
	# `--nuit=0.8` (ou `?nuit=0.8` dans l'adresse) : photographier la nuit sans
	# attendre que le village y passe.
	for argument in OS.get_cmdline_args():
		if String(argument).begins_with("--nuit="):
			MatieresCarnage.nuit_forcee = clamp(float(String(argument).substr(7)), 0.0, 1.0)
	_ambiance = MatieresCarnage.ambiance()
	for noeud in _ambiance:
		monde().add_child(noeud)
	# La voie ferrée est une droite de la ville : le shader du sol la trace en
	# espace monde, il lui faut ses paramètres.
	MatieresCarnage.sol().set_shader_parameter("rail", carte.rail())
	# Les voies libres : le shader du sol trace leurs chaussées en espace monde.
	MatieresCarnage.sol().set_shader_parameter("lignes", carte.lignes_libres())
	MatieresCarnage.sol().set_shader_parameter("origines", carte.origines_libres())
	MatieresCarnage.sol().set_shader_parameter("anneaux", carte.anneaux_libres())
	MatieresCarnage.sol().set_shader_parameter("etoiles", carte.etoiles_libres())

## Les morceaux dont le bord passe à portée du joueur sont bâtis, du plus proche
## au plus loin, une ÉTAPE de chantier par image ; ceux qui sont partis loin
## sont libérés. `entiers` > 0 : autant de morceaux bâtis d'un coup, pour le
## départ. Un morceau complet coûte quelques dizaines de millisecondes : en
## bâtir un d'un bloc en pleine course ferait une saccade au passage de chaque
## rue.
func _diffuser_la_ville(entiers: int = 0) -> void:
	# Un pâté sali par une casse se remaille : UN par image, tous morceaux
	# confondus, pour qu'une roquette ne coûte jamais plus qu'un maillage.
	if _chantier == null:
		for cle in _morceaux:
			if (_morceaux[cle] as MorceauVille).rafraichir():
				break
	if _chantier != null and entiers == 0:
		if _chantier.avancer():
			_chantier = null
		return
	var cote := PlanVille.MORCEAU * PlanVille.PAS
	var m0 := Vector2i(int(floor((_position.x - PORTEE_MORCEAU) / cote)), int(floor((_position.y - PORTEE_MORCEAU) / cote)))
	var m1 := Vector2i(int(floor((_position.x + PORTEE_MORCEAU) / cote)), int(floor((_position.y + PORTEE_MORCEAU) / cote)))
	var manquants: Array = []
	for my in range(m0.y, m1.y + 1):
		for mx in range(m0.x, m1.x + 1):
			var cle := Vector2i(mx, my)
			if _morceaux.has(cle):
				continue
			var rect := Rect2(Vector2(mx, my) * cote, Vector2(cote, cote))
			var plus_proche := Vector2(clamp(_position.x, rect.position.x, rect.end.x),
				clamp(_position.y, rect.position.y, rect.end.y))
			if plus_proche.distance_to(_position) <= PORTEE_MORCEAU:
				manquants.append([plus_proche.distance_squared_to(_position), cle])
	manquants.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	for i in min(max(entiers, 1), manquants.size()):
		var cle: Vector2i = manquants[i][1]
		var morceau := MorceauVille.new()
		monde().add_child(morceau)
		_morceaux[cle] = morceau
		if entiers > 0:
			morceau.batir(carte, cle, ville.reveillees, ville.detruits)
		else:
			morceau.commencer(carte, cle, ville.reveillees, ville.detruits)
			_chantier = morceau
	# On ne libère qu'un morceau par image aussi : libérer neuf nœuds de mille
	# instances d'un coup se sent autant que les bâtir.
	for cle in _morceaux.keys():
		var rect := Rect2(Vector2(cle) * cote, Vector2(cote, cote))
		var plus_proche := Vector2(clamp(_position.x, rect.position.x, rect.end.x),
			clamp(_position.y, rect.position.y, rect.end.y))
		if plus_proche.distance_to(_position) > LIBERATION:
			if _morceaux[cle] == _chantier:
				_chantier = null
			(_morceaux[cle] as Node3D).queue_free()
			_morceaux.erase(cle)
			break

## Un lot de pâtés de la carte par image, puis les lieux secteur par secteur.
## Cent vingt pâtés, c'est trois mille pixels et autant de tests d'eau : une
## milliseconde native, quatre dans le navigateur. La carte est complète en
## deux secondes de jeu sans qu'on l'ait sentie.
const PATES_PAR_IMAGE := 120

func _peindre_le_plan() -> void:
	var total := PlanVille.pates_x() * PlanVille.pates_y()
	var secteurs := (PlanVille.COLONNES / PlanVille.SECTEUR) * (PlanVille.LIGNES / PlanVille.SECTEUR)
	if _plan_pate < total:
		for i in PATES_PAR_IMAGE:
			if _plan_pate >= total:
				break
			carte.peindre_pate(_plan_image, _plan_pate)
			_plan_pate += 1
		if _plan_pate >= total or _plan_pate % (PATES_PAR_IMAGE * 10) == 0:
			_plan_texture.update(_plan_image)
	elif _plan_secteur < secteurs:
		for i in 3:
			if _plan_secteur >= secteurs:
				break
			var par_ligne := PlanVille.COLONNES / PlanVille.SECTEUR
			carte.peindre_secteur(_plan_image, Vector2i(posmod(_plan_secteur, par_ligne), _plan_secteur / par_ligne))
			_plan_secteur += 1
		if _plan_secteur >= secteurs:
			_plan_texture.update(_plan_image)
	_plan_vue.visible = Commandes.carte()
	if _plan_vue.visible:
		_plan_vue.queue_redraw()

func _dessiner_le_plan() -> void:
	var taille := _plan_vue.size
	var hauteur: float = taille.y * 0.68
	var largeur: float = hauteur * float(PlanVille.COLONNES) / float(PlanVille.LIGNES)
	# Un peu au-dessus du milieu : la légende passe sous la carte sans mordre
	# sur la ligne d'état du bas.
	var cadre := Rect2((taille - Vector2(largeur, hauteur)) * 0.5 - Vector2(0.0, taille.y * 0.05), Vector2(largeur, hauteur))
	_plan_vue.draw_rect(cadre.grow(6.0), Color(Palette.FOND, 0.9), true)
	_plan_vue.draw_texture_rect(_plan_texture, cadre, false)
	_plan_vue.draw_rect(cadre.grow(6.0), Palette.FILET, false, 1.0)
	var echelle := Vector2(largeur, hauteur) / carte.etendue()
	for cle in _autres:
		var a: Dictionary = _autres[cle]
		_plan_vue.draw_circle(cadre.position + Vector2(a["p"]) * echelle, 5.0,
			Palette.couleur_joueur(int(joueurs.get(cle, {}).get("place", 1))))
	var moi := cadre.position + _position * echelle
	var avant := Vector2.RIGHT.rotated(_angle)
	var cote := Vector2(-avant.y, avant.x)
	_plan_vue.draw_colored_polygon(PackedVector2Array([moi + avant * 10.0, moi - avant * 6.0 + cote * 6.0,
		moi - avant * 6.0 - cote * 6.0]), _ma_couleur())
	_plan_vue.draw_arc(moi, 14.0, 0, TAU, 24, _ma_couleur(), 2.0)
	# La légende, dans la police de la charte (la police de secours ne se
	# dessinait plus une fois le post-traitement posé dans la même couche).
	var police: Font = UI.TEXTE_POLICE
	var x := cadre.position.x
	var y := cadre.end.y + 24.0
	for entree in [["garage", Palette.SERIE], ["cabine", Palette.AVERTISSEMENT], ["arène", Palette.CRITIQUE],
			["planque", Color("#b070d0")], ["hôpital", Color("#f0f4f8")],
			["repaire", Palette.ENCRE], ["parc", Color("#50a050")], ["eau", Color("#3a6a9c")], ["voie ferrée", Color("#404040")],
			["boulevard", Color("#8a8a90")]]:
		_plan_vue.draw_rect(Rect2(Vector2(x - 4.0, y - 9.0), Vector2(8, 8)), entree[1], true)
		_plan_vue.draw_string(police, Vector2(x + 9.0, y), String(entree[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.ENCRE_DOUCE)
		x += 12.0 + police.get_string_size(String(entree[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 16.0

## Un IMPACT sur une façade. ⚠ Plus rien ne part du décor depuis la v12 : le
## morceau rend seulement la couleur et le point touchés, et on en tire les
## éclats, la poussière et le choc. Le mur, lui, tient.
func _casser_dans_le_decor(id: int, locale: int) -> void:
	var tuile := MorceauVille.tuile_d_immeuble(id)
	var cle_morceau := Vector2i(tuile.x / PlanVille.MORCEAU, tuile.y / PlanVille.MORCEAU)
	if not _morceaux.has(cle_morceau):
		return
	var morceau: MorceauVille = _morceaux[cle_morceau]
	var parti := morceau.casser(id, locale)
	if parti.is_empty():
		return
	if (parti["p"] as Vector3).distance_to(Decor.vers3d(_position)) > 120.0:
		return
	var couleur: Color = parti["c"]
	for i in 5:
		var debris := FormesCarnage.cubes([[Vector3.ZERO, float(parti["taille"]) * _rng.randf_range(0.2, 0.45), Color(couleur.r, couleur.g, couleur.b, 1.0)]])
		debris.position = parti["p"]
		monde().add_child(debris)
		var v := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.5, 1.6), _rng.randf_range(-1, 1)) * _rng.randf_range(5, 11)
		_eclats.append({"noeud": debris, "v": v, "t": 1.4, "t0": 1.4,
			"tourne": Vector3(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6), _rng.randf_range(-6, 6))})
	var poussiere := FormesCarnage.poussiere(couleur)
	poussiere.position = parti["p"]
	monde().add_child(poussiere)
	_eclats.append({"noeud": poussiere, "v": Vector3.ZERO, "t": 1.2, "t0": 1.2, "lumiere": true})
	Sons.jouer("choc", _rng.randf_range(0.6, 0.9), -14.0)

## Une voiture dormante s'est réveillée : on l'efface de la nappe du morceau
## qui la porte. Le nœud ordinaire de `_placer_les_autos` prend le relais.
func _effacer_la_dormante(id: int) -> void:
	if _cachees.has(id):
		return
	_cachees[id] = true
	for cle in _morceaux:
		(_morceaux[cle] as MorceauVille).cacher_voiture(id)

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
		_klaxonner(delta)
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
var _depuis_rapport := 0.0

func _piloter_pour_le_banc() -> void:
	# Toutes les cinq secondes, le pilote dit à quelle cadence il tourne et ce
	# qu'il voit : dans le navigateur, c'est la seule mesure de performance
	# qu'on ait — et c'est celle qui compte.
	_depuis_rapport += get_process_delta_time()
	if _depuis_rapport >= 5.0:
		_depuis_rapport = 0.0
		var cubes := 0
		for cle in _morceaux:
			cubes += (_morceaux[cle] as MorceauVille).cubes_poses()
		print("[banc] $%d sur soi, $%d au coffre, planque %d" % [_argent, _banque, _planque])
		var secours := 0
		for a in ville.autos:
			if int(a["genre"]) in [VilleVivante.POMPIER, VilleVivante.AMBULANCE]:
				secours += 1
		print("[banc] t=%ds fps=%d gens=%d autos=%d feux=%d secours=%d morceaux=%d cubes=%d quads=%d maillage_max=%.1fms fiches=%d noeuds=%d %s" % [int(temps),
			Engine.get_frames_per_second(), ville.gens.size(), ville.autos.size(), ville.feux.size(), secours,
			_morceaux.size(), cubes, MorceauVille.quads_total, MorceauVille.maillage_max_ms,
			carte.fiches_en_cache(), get_tree().get_node_count(), "hôte" if est_hote() else "client"])
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
	Commandes.klaxon_simule = fmod(temps, 9.0) < 0.3
	# Le pilote traite ses affaires : devant une planque ou un hôpital, il
	# appuie sur F. Sans ça, l'achat, le dépôt et le soin ne seraient jamais
	# exercés avant livraison.
	Commandes.affaire_simulee = _affaire != "" and _pulsation
	# La carte pendant trois secondes : c'est ainsi qu'on la photographie.
	Commandes.carte_simulee = temps > 8.0 and temps < 11.0

## Ce que vise le pilote du banc. Tant qu'il n'a pas de contrat, il va
## décrocher : sans ce détour, une cabine sur vingt-six par vingt tuiles n'est
## jamais croisée par hasard, et toute la chaîne des contrats — proposition,
## avancement, prime, respect — passe la livraison sans avoir tourné une fois.
func _but_du_banc() -> Vector2:
	if _contrat.is_empty():
		var proche := Vector2.INF
		var ecart := INF
		for c in carte.lieux_autour(_position, PlanVille.SECTEUR * PlanVille.PAS * 1.5)["cabines"]:
			var d: float = _position.distance_squared_to(c["p"])
			if d < ecart:
				ecart = d
				proche = c["p"]
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
	if PlanVille.est_dormante(id):
		ville.reveillees[id] = true
		_effacer_la_dormante(id)
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
		# À pied non plus, on ne traverse pas une voiture garée : on la contourne.
		for p: Vector2 in _voitures_autour(60.0):
			var vers := _position - p
			var minimum := RAYON_A_PIED + 22.0
			if vers.length() < minimum and vers.length() > 0.01:
				_position = p + vers.normalized() * minimum
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
		var fiche: Dictionary = CARACTERES.get(_modele_vehicule, CARACTERES[-1])
		if commande.y > 0.1:
			_vitesse = min(_vitesse + ACCELERATION * float(fiche["a"]) * delta, VITESSE_MAX * float(fiche["v"]))
		elif commande.y < -0.1:
			_vitesse = max(_vitesse - FREIN * delta, VITESSE_ARRIERE)
		else:
			_vitesse = move_toward(_vitesse, 0.0, FROTTEMENT * abs(_vitesse) * delta + 40.0 * delta)

		# Le braquage atteint son plein dès 165 px/s — avant, la voiture ne
		# tournait qu'à pleine vitesse, ce qui la rendait inconduisible dans
		# des rues de cent quarante pixels. Il se resserre ensuite un peu à
		# haute vitesse, ce qui donne le poids sans enlever le contrôle.
		var prise: float = clamp(abs(_vitesse) / PRISE_PLEINE, 0.0, 1.0) * signf(_vitesse)
		var tenue: float = lerp(1.0, 0.62, clamp(abs(_vitesse) / VITESSE_MAX, 0.0, 1.0))
		# Une moto tourne court et ne dérive presque pas : c'est tout son
		# intérêt dans des rues de deux tuiles.
		var vif := 1.45 if FormesCarnage.est_moto(_modele_vehicule) else 1.0
		_angle += commande.x * BRAQUAGE * vif * delta * prise * tenue

	var cap := Vector2.RIGHT.rotated(_angle)
	if abs(_vitesse) < 40.0:
		_glisse = cap
	else:
		var adherence: float = lerp(ADHERENCE_LENTE, ADHERENCE_RAPIDE, clamp(abs(_vitesse) / VITESSE_MAX, 0.0, 1.0))
		if FormesCarnage.est_moto(_modele_vehicule):
			adherence *= 1.8
		_glisse = _glisse.slerp(cap, clamp(delta * adherence, 0.0, 1.0)).normalized()
	_position += _glisse * _vitesse * delta
	_marquer_le_bitume(delta)
	_heurter_les_murs()
	_heurter_les_voitures()
	_surveiller_la_friche(delta)
	Sons.regime(clamp(abs(_vitesse) / VITESSE_MAX, 0.0, 1.0))

## Le klaxon fait fuir les passants — c'est son seul effet, et c'est déjà
## beaucoup : c'est le moyen de traverser une foule sans l'écraser, ou de la
## rabattre vers un coéquipier.
## Les traces de pneus : quand on freine fort ou qu'on braque à pleine vitesse,
## chaque roue arrière laisse un rectangle sombre sur le bitume. Elles vieillissent
## toutes d'un cran à chaque nouvelle : au bout de l'anneau, la plus vieille
## s'efface.
func _marquer_le_bitume(delta: float) -> void:
	_depuis_trace -= delta
	if _traces == null or _depuis_trace > 0.0 or abs(_vitesse) < 200.0:
		return
	var commande := Commandes.conduite()
	var derape: bool = (commande.y < -0.1 and _vitesse > 260.0) or (abs(commande.x) > 0.6 and abs(_vitesse) > 420.0) or _sonne > 0.0
	if not derape or not carte.sur_une_rue(_position, 20.0):
		return
	_depuis_trace = 0.04
	var direction := Vector2.RIGHT.rotated(_angle)
	var cote := Vector2(-direction.y, direction.x)
	for signe in [-1.0, 1.0]:
		var roue: Vector2 = _position - direction * 16.0 + cote * signe * 12.0
		var ou := Decor.vers3d(roue, 0.02)
		var base := Basis(Vector3.UP, -_angle).scaled(Vector3(abs(_vitesse) * 0.045 * Decor.ECHELLE + 0.3, 1.0, 0.55))
		_traces.set_instance_transform(_trace_suivante, Transform3D(base, ou))
		_traces.set_instance_color(_trace_suivante, Color(0, 0, 0, 0.85))
		_trace_suivante = (_trace_suivante + 1) % TRACES_MAX
	# Les autres pâlissent : une trace a une demi-vie d'une centaine de coups.
	if _trace_suivante % 8 == 0:
		for i in TRACES_MAX:
			var c := _traces.get_instance_color(i)
			if c.a > 0.0:
				_traces.set_instance_color(i, Color(0, 0, 0, maxf(0.0, c.a - 0.02)))

func _klaxonner(delta: float) -> void:
	_depuis_klaxon -= delta
	if _hors_service > 0.0 or not Commandes.klaxon() or _depuis_klaxon > 0.0:
		return
	_depuis_klaxon = KLAXON_DELAI
	Sons.jouer("klaxon", _rng.randf_range(0.96, 1.04), -9.0)
	canal.envoyer("klx", {"x": int(_position.x), "y": int(_position.y)})
	if est_hote():
		ville.paniquer(_position, 280.0, 1.8)

## Un mur ne stoppe pas : il fait GLISSER. On ne perd que la part de vitesse
## qu'on a mise dedans, et la voiture se réaligne sur la façade quand on la
## frôle. Avant, le moindre angle de trottoir coupait les deux tiers de la
## vitesse et clouait la voiture — dans une ville, c'est toutes les trois
## secondes.
func _heurter_les_murs() -> void:
	var direction0 := Vector2.RIGHT.rotated(_angle)
	var correction := Vector2.ZERO
	var touche := false
	var moto := FormesCarnage.est_moto(_modele_vehicule)
	var rayon_c := RAYON_CAPSULE * (0.6 if moto else 1.0)
	var empattement := DEMI_EMPATTEMENT * (0.7 if moto else 1.0)
	for signe in [1.0, -1.0]:
		var bout: Vector2 = _position + direction0 * empattement * signe
		var resultat := carte.degager(bout, rayon_c)
		if bool(resultat[1]):
			var c: Vector2 = (resultat[0] as Vector2) - bout
			_position += c
			correction += c
			touche = true
	if not touche:
		return
	var normale := correction.normalized()
	if normale == Vector2.ZERO:
		return
	var direction := Vector2.RIGHT.rotated(_angle)
	var frontal: float = abs(direction.dot(normale))

	if frontal > 0.62 and abs(_vitesse) > 330.0:
		Sons.jouer("choc", 0.8, -10.0)
		_secousse = max(_secousse, 0.28)
		# Une façade prise de face à cette vitesse perd des cubes : l'hôte
		# tranche lesquels, comme pour les balles.
		var impact := _position + direction * RAYON_VOITURE
		var gerbe := FormesCarnage.etincelles()
		gerbe.position = Decor.vers3d(impact, 1.0)
		monde().add_child(gerbe)
		_eclats.append({"noeud": gerbe, "v": Vector3.ZERO, "t": 0.8, "t0": 0.8, "lumiere": true})
		if est_hote():
			ville.choquer(impact, direction, abs(_vitesse))
			_vider_les_evenements()
		else:
			canal.envoyer("choc", {"x": int(impact.x), "y": int(impact.y), "a": snapped(direction.angle(), 0.01), "v": int(abs(_vitesse))})
		# La tôle s'abîme : une voiture qu'on maltraite finit par exploser,
		# et c'est ce qui donne un sens au garage.
		_pv_vehicule = max(0.0, _pv_vehicule - abs(_vitesse) * 0.012 / _solidite())
		if _pv_vehicule <= 0.0:
			_vehicule_detruit()
	_vitesse *= lerp(0.95, 0.28, frontal)

	var tangente := Vector2(-normale.y, normale.x)
	if tangente.dot(direction) < 0.0:
		tangente = -tangente
	_angle = lerp_angle(_angle, tangente.angle(), (1.0 - frontal) * 0.22)
	_glisse = Vector2.RIGHT.rotated(_angle)

## Une voiture garée n'est pas un mur, mais on ne la traverse pas non plus :
## on est repoussé hors de sa silhouette et on perd la part de vitesse qu'on a
## mise dedans. Les dégâts et la poussée de l'autre, c'est l'hôte qui les dit —
## ici on ne fait que rendre le choc IMMÉDIAT sous les doigts.
func _voitures_autour(rayon: float) -> Array:
	var obstacles: Array = []
	for auto in ville.autos:
		if String(auto.get("pilote", "")) != "" or int(auto["genre"]) == VilleVivante.EPAVE:
			continue
		if (auto["p"] as Vector2).distance_to(_position) < rayon:
			obstacles.append(auto["p"])
	for d in ville.dormantes_endormies(_position, rayon):
		obstacles.append(d["p"])
	return obstacles

func _heurter_les_voitures() -> void:
	var direction := Vector2.RIGHT.rotated(_angle)
	for p: Vector2 in _voitures_autour(90.0):
		var vers := _position - p
		var ecart := vers.length()
		var minimum := VilleVivante.CHOC_AUTO
		if ecart >= minimum or ecart < 0.01:
			continue
		var normale := vers / ecart
		_position = p + normale * minimum
		var frontal: float = abs(direction.dot(normale))
		if frontal > 0.5 and abs(_vitesse) > 260.0:
			Sons.jouer("choc", 0.9, -12.0)
			_secousse = max(_secousse, 0.2)
		_vitesse *= lerp(0.96, 0.45, frontal)

func _solidite() -> float:
	return float(CARACTERES.get(_modele_vehicule, CARACTERES[-1])["t"])

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
func _surveiller_les_lieux(delta: float) -> void:
	_mot_affaire_reste = max(0.0, _mot_affaire_reste - delta)
	_surveiller_les_affaires(delta)
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

# ------------------------------------------------------- l'argent

## Ce qu'on peut TRAITER là où l'on est : acheter la planque, y déposer son
## argent, l'améliorer, se faire recoudre. Une seule touche (F), et la ligne du
## HUD dit toujours ce qu'elle ferait — un menu, à cette échelle, se lirait
## moins vite qu'on ne se fait tirer dessus.
func _surveiller_les_affaires(_delta: float) -> void:
	_affaire = ""
	var planque := carte.planque_de(_position)
	var hopital := carte.hopital_de(_position)
	if planque >= 0:
		var fiche := carte.planque_par_id(_position, planque)
		var prix := int(fiche.get("prix", 0))
		if _planque < 0:
			_affaire = "F : acheter cette planque — $%d" % prix
			if Commandes.affaire_declenchee():
				_acheter_la_planque(planque, prix)
		elif planque == _planque:
			var suivante := _amelioration_suivante()
			if _argent > 0:
				_affaire = "F : déposer $%d" % _argent
			elif suivante != "":
				_affaire = "F : %s — $%d" % [_libelle_amelioration(suivante), int(PlanVille.PRIX_AMELIORATION[suivante])]
			else:
				_affaire = "chez vous — $%d à l'abri" % _banque
			if Commandes.affaire_declenchee():
				_traiter_chez_soi(suivante)
		else:
			_affaire = "planque d'un autre"
		if planque != _planque_en_cours:
			_planque_en_cours = planque
			if planque == _planque:
				_ranger_le_vehicule()
	elif hopital >= 0:
		if _vie < VIE_MAX:
			_affaire = "F : se faire recoudre — $%d" % SOIN
			if Commandes.affaire_declenchee():
				_se_faire_soigner()
		else:
			_affaire = "hôpital"
	else:
		_planque_en_cours = -1
	_hopital_en_cours = hopital

func _acheter_la_planque(id: int, prix: int) -> void:
	if _argent < prix:
		_dire_affaire("il vous manque $%d" % (prix - _argent))
		return
	_argent -= prix
	_planque = id
	_dire_affaire("planque achetée — rentrez y mettre votre argent")
	Sons.jouer("portail", 1.0, -6.0)
	canal.envoyer("planque", {"j": Session.cle, "i": id})

func _traiter_chez_soi(suivante: String) -> void:
	if _argent > 0:
		var depose := _argent
		_banque += depose
		_argent = 0
		_dire_affaire("$%d à l'abri" % depose)
		Sons.jouer("depart", 1.4, -8.0)
		return
	if suivante == "":
		_dire_affaire("rien à améliorer ici")
		return
	var prix := int(PlanVille.PRIX_AMELIORATION[suivante])
	if _banque < prix:
		_dire_affaire("il manque $%d au coffre" % (prix - _banque))
		return
	_banque -= prix
	_ameliorations[suivante] = true
	_dire_affaire("%s installé" % _libelle_amelioration(suivante))
	Sons.jouer("portail", 1.2, -6.0)

## L'ordre des travaux : le coffre d'abord (il double ce qu'on garde), puis
## l'arsenal (on ne perd plus son arme), puis le garage (on garde sa voiture).
func _amelioration_suivante() -> String:
	for cle in ["coffre", "arsenal", "garage"]:
		if not bool(_ameliorations[cle]):
			return cle
	return ""

func _libelle_amelioration(cle: String) -> String:
	match cle:
		"coffre": return "coffre"
		"arsenal": return "arsenal"
		"garage": return "garage"
	return cle

func _se_faire_soigner() -> void:
	if _argent < SOIN:
		_dire_affaire("il vous manque $%d" % (SOIN - _argent))
		return
	_argent -= SOIN
	_vie = VIE_MAX
	_dire_affaire("recousu")
	Sons.jouer("depart", 1.2, -8.0)

## Le véhicule qu'on ramène chez soi est rangé au garage : après la mort, on
## repart avec — c'est ce qui donne envie de garder la même voiture.
func _ranger_le_vehicule() -> void:
	if not bool(_ameliorations["garage"]) or _pied or _modele_vehicule < 0:
		return
	if _garage_perso != _modele_vehicule:
		_garage_perso = _modele_vehicule
		_dire_affaire("véhicule rangé au garage")

func _dire_affaire(texte: String) -> void:
	_mot_affaire = texte
	_mot_affaire_reste = 2.6

## Un gain d'argent : ce qui compte au classement reste la fortune, mais
## l'argent frais est SUR SOI — donc perdable.
func _encaisser_argent(montant: int) -> void:
	_argent = max(0, _argent + montant)

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
		ville.paniquer(_position, 320.0, 2.2)
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
		var dans_un_mur := carte.dans_un_batiment(tir["p"])
		var mort: bool = float(tir["restant"]) <= 0.0 or dans_un_mur
		if est_hote() and dans_un_mur:
			# La balle écaille le mur, la roquette le creuse : l'hôte décide
			# quels cubes partent, et le dit à tous.
			ville.impacter(tir["p"], String(tir["arme"]))
			_vider_les_evenements()
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
	# Une voiture dormante touchée se réveille cabossée : à partir de là, elle
	# est diffusée comme les autres et finira en épave si on insiste.
	for d in ville.dormantes_endormies(point, VilleVivante.RAYON_AUTO + 12.0):
		var reveillee := ville.reveiller(int(d["id"]))
		if reveillee.is_empty():
			continue
		reveillee["pv"] = float(reveillee["pv"]) - float(fiche["degat"])
		if float(reveillee["pv"]) <= 0.0:
			ville.detruire_auto(reveillee, par)
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
			var arme := ville.retirer_caisse(int(caisse["id"]), Session.cle)
			if arme != "":
				_accorder(Session.cle, arme)
			_vider_les_evenements()
		return

func _accorder(cle: String, arme: String) -> void:
	canal.envoyer("arme", {"j": cle, "arme": arme})
	if cle == Session.cle:
		_equiper(arme)

func _equiper(arme: String) -> void:
	if arme == "eperon":
		_eperon = DUREE_EPERON
	elif arme == "vie":
		_vie = min(VIE_MAX, _vie + SOIN_TROUSSE)
	elif arme == "argent":
		pass    # compté par l'hôte, arrive par « k »
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
		# L'instantané se cadre sur TOUS les joueurs, morts compris : `etats`
		# exclut ceux qui sont à terre (pour qu'on ne les touche pas), et quand
		# tout le monde était à terre en même temps, l'instantané partait vide
		# et la ville disparaissait chez les clients le temps de se relever.
		var regards := etats.duplicate()
		if not regards.has(Session.cle):
			regards[Session.cle] = {"p": _position}
		for cle in _autres:
			if not regards.has(cle):
				regards[cle] = {"p": _autres[cle]["p"]}
		canal.envoyer("n", ville.instantane(regards))

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
## ⚠ Les événements d'une même image partent en UN seul message (`lot`). Le
## serveur temps réel limite le nombre de messages par seconde sur un canal ;
## à trois étoiles, chaque coup de feu de flic (`tn`), chaque dégât, chaque
## point faisaient un message, et l'hôte dépassait la limite : le serveur
## fermait le socket (code 1000), l'écran passait « hors ligne » et la ville
## se figeait chez les autres. Vu dans le navigateur, jamais au banc natif.
func _vider_les_evenements() -> void:
	if ville.sortants.is_empty():
		return
	var lot: Array = ville.sortants.duplicate()
	ville.sortants.clear()
	if lot.size() == 1:
		canal.envoyer(String(lot[0]["e"]), lot[0]["c"])
	else:
		var paquet: Array = []
		for evenement in lot:
			paquet.append([String(evenement["e"]), evenement["c"]])
		canal.envoyer("lot", {"l": paquet})
	for evenement in lot:
		_appliquer(String(evenement["e"]), evenement["c"])

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
				ville.paniquer(Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))), 320.0, 2.2)
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
				var arme := ville.retirer_caisse(int(charge.get("id", -1)), String(charge.get("cle", "")))
				if arme != "":
					_accorder(String(charge.get("cle", "")), arme)
				_vider_les_evenements()
		"choc":
			if est_hote():
				ville.choquer(Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))),
					Vector2.RIGHT.rotated(float(charge.get("a", 0.0))), float(charge.get("v", 0)))
				_vider_les_evenements()
		"lot":
			for entree in charge.get("l", []):
				if typeof(entree) == TYPE_ARRAY and (entree as Array).size() == 2 and typeof(entree[1]) == TYPE_DICTIONARY:
					_appliquer(String(entree[0]), entree[1])
		_:
			_appliquer(evenement, charge)

func _appliquer(evenement: String, charge: Dictionary) -> void:
	match evenement:
		"pris":
			var qui := String(charge.get("j", ""))
			# Une dormante prise par N'IMPORTE QUI sort de sa nappe : l'instantané
			# ne liste pas les voitures conduites, on ne l'apprendrait jamais
			# autrement — et on verrait un joueur rouler dans la copie d'une
			# voiture restée garée.
			var id_pris := int(charge.get("id", 0))
			if PlanVille.est_dormante(id_pris):
				ville.reveillees[id_pris] = true
				_effacer_la_dormante(id_pris)
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
			if tueur == Session.cle:
				_encaisser_argent(int(charge.get("p", 0)))
			_effet_gain(Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))),
				int(charge.get("p", 0)), int(charge.get("f", 1)), tueur,
				String(charge.get("q", "")))
		"saisie":
			# Un joueur s'est fait ramasser : sa fortune baisse d'autant.
			if est_hote():
				ajouter_score(String(charge.get("j", "")), -int(charge.get("m", 0)))
		"feu":
			# L'hôte a allumé un foyer : chez le client, il ne s'agit que de le
			# dessiner — la vie du feu (propagation, dégâts) reste chez l'hôte.
			if not est_hote():
				ville.feux.append({"id": ville.prochain_id(), "f": float(charge.get("f", 100)) / 100.0,
					"p": Vector2(float(charge.get("x", 0)), float(charge.get("y", 0))),
					"force": float(charge.get("f", 100)) / 100.0, "t": 0.0,
					"propage": 99.0, "ronge": 99.0})
			Sons.jouer("choc", 0.55, -8.0)
		"eteint":
			if not est_hote():
				var ou_eteint := Vector2(float(charge.get("x", 0)), float(charge.get("y", 0)))
				var gardes: Array = []
				for f in ville.feux:
					if Vector2(f["p"]).distance_to(ou_eteint) > 40.0:
						gardes.append(f)
				ville.feux = gardes
		"secours":
			# Le Medicar est arrivé : on se relève tout de suite, à moitié
			# soigné. C'est ce qui rend l'ambulance utile plutôt que jolie.
			if String(charge.get("j", "")) == Session.cle and _hors_service > 0.0:
				_hors_service = min(_hors_service, 0.6)
				_vie = max(_vie, VIE_MAX * 0.5)
				_dire_affaire("le Medicar vous relève")
		"boum":
			var ou_boum := Vector2(float(charge.get("x", 0)), float(charge.get("y", 0)))
			_effet_explosion(ou_boum)
			if est_hote():
				ville.exploser(ou_boum)
				ville.allumer(ou_boum, 1.0)
				_vider_les_evenements()
		"casse":
			# Des cubes d'immeuble s'en vont : chez tout le monde, dans le décor
			# et dans la mémoire de la manche (un morceau rebâti plus tard doit
			# montrer la même ruine).
			var touches: Dictionary = {}
			for entree in charge.get("v", []):
				if typeof(entree) != TYPE_ARRAY or (entree as Array).size() != 2:
					continue
				var id := int(entree[0])
				touches[id] = true
				_casser_dans_le_decor(id, int(entree[1]))
			if Commandes.pilote_automatique:
				print("[banc] casse : %d cube(s) dans %d immeuble(s)" % [(charge.get("v", []) as Array).size(), touches.size()])
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
				_cible_contrat = {}
				Sons.jouer("fin", 1.15, -5.0)
			elif etat == "perdu":
				_contrat = {}
				_cible_contrat = {}
				Sons.jouer("choc", 0.55, -12.0)
			else:
				_contrat = {"t": String(charge.get("t", "")), "n": int(charge.get("n", 0)),
					"a": int(charge.get("a", 0)), "r": float(charge.get("r", 0))}
				_contrat_duree = max(_contrat_duree if int(charge.get("a", 0)) > 0 else 0.0, float(charge.get("r", 0)))
				_cible_contrat = {"k": String(charge.get("k", "")), "g": int(charge.get("g", -1))}
				if etat == "pris":
					Sons.jouer("portail", 1.3, -9.0)
		"klx":
			var ou := Vector2(float(charge.get("x", 0)), float(charge.get("y", 0)))
			var loin: float = ou.distance_to(_position)
			if loin < 1300.0:
				Sons.jouer("klaxon", _rng.randf_range(0.9, 1.1), -12.0 - loin * 0.012)
			if est_hote():
				ville.paniquer(ou, 260.0, 1.6)
		"helico":
			if Commandes.pilote_automatique:
				print("[banc] hélicoptère lancé sur %s" % String(charge.get("j", "")))
			if String(charge.get("j", "")) == Session.cle:
				_annoncer("HÉLICOPTÈRE — filez au garage", Palette.CRITIQUE, 4.0)
				Sons.jouer("sirene", 0.7, -6.0)
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
		var pieton := FormesCarnage.pieton(couleur, false, pseudo, true,
			FormesCarnage.PEAU_JOUEUR)
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
	# Arrivé en retard, on n'a pas vu le « pris » : la voiture qu'il conduit
	# sort quand même de sa nappe.
	var w := int(charge.get("w", 0))
	if PlanVille.est_dormante(w) and not ville.reveillees.has(w):
		ville.reveillees[w] = true
		_effacer_la_dormante(w)
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
		_pv_vehicule = max(0.0, _pv_vehicule - degats * 0.6 / _solidite())
	_secousse = max(_secousse, 0.5)
	if _vie <= 0.0:
		_tomber()
	elif cause != "balle":
		_sonne = 0.35
		Sons.jouer("choc", 1.0, -6.0)

func _tomber() -> void:
	_vie = 0.0
	_hors_service = HORS_SERVICE
	# La police ramasse ce qu'on avait sur soi — et l'arme, sauf si on a un
	# arsenal à la planque. C'est ce qui fait qu'on rentre déposer son argent
	# au lieu de rouler jusqu'à la mort.
	if _argent > 0:
		var saisi := int(round(float(_argent) * (SAISIE if _planque >= 0 else SAISIE_SANS_PLANQUE)))
		_argent -= saisi
		if est_hote():
			ajouter_score(Session.cle, -saisi)
		else:
			canal.envoyer("saisie", {"j": Session.cle, "m": saisi})
		_dire_affaire("la police vous prend $%d" % saisi)
	if not bool(_ameliorations["arsenal"]):
		_reprendre_le_pistolet()
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
	# On rouvre les yeux à l'HÔPITAL le plus proche — et devant chez soi si on a
	# une planque : c'est ce qui donne un point d'ancrage dans une ville de
	# soixante-huit mille pixels. À défaut, trois à sept rues plus loin.
	var reveil := {}
	if _planque >= 0:
		reveil = carte.planque_par_id(_position, _planque)
	if reveil.is_empty():
		reveil = carte.hopital_le_plus_proche(_position)
	if not reveil.is_empty():
		_position = carte.degager(Vector2(reveil["p"]) + Vector2(0.0, PlanVille.PAS * 0.9), RAYON_A_PIED)[0]
	else:
		_position = carte.point_de_rue(_rng, _position, 300.0, 700.0)
	# Le véhicule rangé au garage nous attend devant la porte.
	if _garage_perso >= 0 and _planque >= 0 and not reveil.is_empty():
		_dire_affaire("votre véhicule vous attend")
	Sons.jouer("depart", 0.8, -8.0)

# ------------------------------------------------------- effets

func _effet_gain(position: Vector2, points: int, facteur: int, cle: String, quoi: String) -> void:
	var couleur := Palette.couleur_joueur(int(joueurs.get(cle, {}).get("place", 0)))
	if quoi == "argent" or quoi == "contrat":
		Sons.jouer("depart", 1.4, -10.0)
	else:
		Sons.jouer("ecrasement", _rng.randf_range(0.85, 1.2), -8.0)
	if quoi == "pieton":
		Sons.jouer("cri", _rng.randf_range(0.8, 1.25), -11.0)

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
	# La bouffée de feu, et un éclair orange sur les façades autour : au
	# crépuscule, une explosion doit ÉCLAIRER, pas seulement projeter des éclats.
	var bouffee := FormesCarnage.explosion()
	bouffee.position = Decor.vers3d(position, 1.0)
	monde().add_child(bouffee)
	bouffee.finished.connect(bouffee.queue_free)
	var eclair := OmniLight3D.new()
	eclair.light_color = Color(1.0, 0.6, 0.25)
	eclair.light_energy = 4.0
	eclair.omni_range = 30.0
	eclair.shadow_enabled = false
	eclair.position = Decor.vers3d(position, 3.0)
	monde().add_child(eclair)
	_eclats.append({"noeud": eclair, "v": Vector3.ZERO, "t": 0.5, "t0": 0.5, "lumiere": true})
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
		if e.has("tourne"):
			# Un débris tourne sur lui-même en vol, et s'arrête au sol.
			var w: Vector3 = e["tourne"]
			noeud.rotation += w * delta
			if noeud.position.y <= 0.13:
				e["tourne"] = w * 0.6
		if not e.has("texte") and not e.has("lumiere"):
			v.y -= 26.0 * delta          # les éclats retombent
			e["v"] = v
			if noeud.position.y < 0.12:
				noeud.position.y = 0.12
				e["v"] = Vector3(v.x * 0.4, -v.y * 0.35, v.z * 0.4)
		var reste: float = clamp(float(e["t"]) / float(e["t0"]), 0.0, 1.0)
		if noeud is Label3D:
			(noeud as Label3D).modulate.a = reste
		elif noeud is OmniLight3D:
			(noeud as OmniLight3D).light_energy = 4.0 * reste
		elif noeud is CPUParticles3D:
			pass
		else:
			noeud.scale = Vector3.ONE * max(0.05, reste)
		restants.append(e)
	_eclats = restants

# ------------------------------------------------------- rendu

var _batisses := 0

func rafraichir_scene(delta: float) -> void:
	_batisses = 0
	_diffuser_la_ville()
	_peindre_le_plan()
	# L'heure du village, à chaque image : le jour tombe pendant la manche.
	if _ambiance.size() == 3:
		MatieresCarnage.regler_heure(_ambiance[0], _ambiance[1], _ambiance[2], MatieresCarnage.nuit())
	# Les vrais phares ne s'allument que la nuit, et les bords de l'écran
	# rougissent le temps d'une secousse.
	if _corps_auto != null:
		FormesCarnage.regler_projecteurs(_corps_auto, MatieresCarnage.nuit())
	MatieresCarnage.post().set_shader_parameter("secousse", clampf(_secousse, 0.0, 1.0))
	_placer_le_joueur(delta)
	_placer_les_autres()
	_placer_la_foule()
	_placer_les_autos()
	_placer_les_objets()
	_placer_les_helicos(delta)
	_animer_effets(delta)
	_placer_camera(delta)
	_animer_les_feux(delta)
	_animer_les_cabines()
	_faire_hurler_la_police(delta)
	_rafraichir_contrat(delta)
	_rafraichir_radar()
	_rafraichir_banniere(delta)

## Le nom du quartier quand on en change. Trois secondes, puis plus rien : une
## bannière permanente serait un panneau de plus dans un écran déjà chargé.
func _annoncer(texte: String, couleur: Color, duree: float) -> void:
	if _hud_banniere == null:
		return
	_hud_banniere.text = texte
	_hud_banniere.add_theme_color_override("font_color", couleur)
	_banniere_reste = duree

func _rafraichir_banniere(delta: float) -> void:
	if _hud_banniere == null:
		return
	var territoire := carte.territoire(_position)
	var quartier := carte.quartier(_position)
	if territoire != _territoire_vu or quartier != _quartier_vu:
		_territoire_vu = territoire
		_quartier_vu = quartier
		# Une annonce plus pressante (l'hélicoptère) ne se fait pas couvrir par
		# le nom d'un quartier.
		if _banniere_reste < 1.0:
			var texte := carte.nom_du_quartier(_position).capitalize()
			var couleur := Palette.ENCRE_DOUCE
			if territoire >= 0:
				texte += " — chez %s" % carte.nom_du_gang(territoire)
				couleur = carte.couleur_du_gang(territoire)
			_annoncer(texte, couleur, 3.2)
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
	_radar.cible = _cible_contrat
	_radar.queue_redraw()

## Le halo d'une cabine clignote tant qu'on n'a pas de contrat en main. Une
## cabine qui appelle alors qu'on est déjà pris ferait faire un détour pour rien.
## Les brasiers : un nœud par foyer, apparu et retiré au fil de ce que dit
## l'hôte. Les dégâts du feu, eux, sont locaux — chacun s'inflige la brûlure
## qu'il traverse, comme pour les balles : attendre l'aller-retour de l'hôte
## rendrait le feu inoffensif à haute vitesse.
var _brasiers: Dictionary = {}        ## id du feu -> Node3D
var _feux_de_banc := 0                ## `--banc-feu=N` : foyers à rallumer autour du pilote
var _depuis_feu_banc := 0.0
var _depuis_brulure := 0.0

func _animer_les_feux(delta: float) -> void:
	# `--banc-feu=N` : N foyers autour de soi, RENOUVELÉS toutes les huit
	# secondes — un incendie s'éteint (ou les pompiers l'éteignent) avant la
	# photo suivante, et on ne photographierait jamais la ville qui brûle.
	if _feux_de_banc > 0 and est_hote() and temps > 3.0:
		_depuis_feu_banc -= delta
		if _depuis_feu_banc <= 0.0:
			_depuis_feu_banc = 5.0
			for i in _feux_de_banc:
				var loin := _position + Vector2.RIGHT.rotated(TAU * float(i) / float(_feux_de_banc) + temps) * _rng.randf_range(40.0, 120.0)
				ville.allumer(carte.degager(loin, 20.0)[0], 1.0)

	var vus: Dictionary = {}
	for f in ville.feux:
		var id := int(f["id"])
		vus[id] = true
		var ou: Vector2 = f["p"]
		if ou.distance_to(_position) > 2200.0:
			continue
		var noeud: Node3D = _brasiers.get(id)
		if noeud == null:
			noeud = FormesCarnage.brasier()
			noeud.position = Decor.vers3d(ou, 0.6)
			monde().add_child(noeud)
			_brasiers[id] = noeud
		FormesCarnage.regler_brasier(noeud, float(f["force"]), temps + float(id))
	for id in _brasiers.keys():
		if not vus.has(id):
			(_brasiers[id] as Node3D).queue_free()
			_brasiers.erase(id)

	# Rester dans les flammes coûte cher : on brûle une fois par demi-seconde.
	_depuis_brulure -= delta
	if _depuis_brulure > 0.0 or _hors_service > 0.0:
		return
	for f in ville.feux:
		var d: float = Vector2(f["p"]).distance_to(_position)
		var portee: float = VilleVivante.RAYON_FEU * (0.55 + 0.45 * float(f["force"]))
		if d < portee:
			_depuis_brulure = 0.5
			_encaisser(VilleVivante.DEGAT_FEU * 0.5 * float(f["force"]), "feu", "")
			_secousse = max(_secousse, 0.18)
			break

## La cabine annonce sa couleur : ce que le gang du quartier pense de vous.
const CABINE_HOSTILE := Color("#d0402c")
const CABINE_NEUTRE := Color("#e0b23a")
const CABINE_AMIE := Color("#4cc25a")

func _animer_les_cabines() -> void:
	var libre := _contrat.is_empty()
	for cle in _morceaux:
		for entree in (_morceaux[cle] as MorceauVille).cabines:
			var poste: Node3D = entree["n"]
			var halo := poste.get_node_or_null("Halo") as Node3D
			if halo:
				halo.visible = libre and fmod(temps, 1.0) > 0.42
			var mot := poste.get_node_or_null("Mot") as Node3D
			if mot:
				mot.visible = libre
			var enseigne := poste.get_node_or_null("Enseigne") as MeshInstance3D
			if enseigne == null:
				continue
			var gang := int(entree.get("gang", -1))
			var couleur := CABINE_NEUTRE
			if gang >= 0:
				if ville.gang_hostile(Session.cle, gang):
					couleur = CABINE_HOSTILE
				elif ville.gang_ami(Session.cle, gang):
					couleur = CABINE_AMIE
			if entree.get("teinte") != couleur:
				entree["teinte"] = couleur
				enseigne.material_override = Decor.matiere_lumineuse(couleur, 1.4)

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

## Le sablier du contrat descend chez chacun entre deux nouvelles de l'hôte ;
## l'affichage lui-même est dans la fiche (`fiche_joueur`).
func _rafraichir_contrat(delta: float) -> void:
	if _contrat.is_empty():
		return
	_contrat["r"] = max(0.0, float(_contrat["r"]) - delta)

func _alerte_contrat() -> Dictionary:
	if _contrat.is_empty():
		return {}
	var avance := ""
	if int(_contrat["n"]) > 1:
		avance = "  %d/%d" % [int(_contrat["a"]), int(_contrat["n"])]
	var restant := float(_contrat["r"])
	return {
		"texte": "CONTRAT  %s%s   %ds" % [String(_contrat["t"]).to_upper(), avance, int(ceil(restant))],
		"couleur": Palette.CRITIQUE if restant <= 8.0 else Palette.AVERTISSEMENT,
		"part": restant / _contrat_duree if _contrat_duree > 0.0 else -1.0,
	}

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
		# La fumée : un filet à l'accélération, un panache noir quand la tôle
		# est à bout. C'est ce qui dit qu'il est temps de changer de voiture.
		var fumee := _corps_auto.get_node_or_null("Fumee") as CPUParticles3D
		if fumee:
			var abime := _pv_vehicule < PV_VOITURE * 0.35
			fumee.emitting = abime or (Commandes.conduite().y > 0.1 and _hors_service <= 0.0)
			fumee.amount = 40 if abime else 22
			if fumee.color_ramp:
				(fumee.color_ramp as Gradient).set_color(0, Color(0.15, 0.15, 0.15, 0.7) if abime else Color(0.8, 0.8, 0.82, 0.45))
		_regler_jauge(_corps_auto, _pv_vehicule / PV_VOITURE)

	if _corps_pied.visible:
		_corps_pied.position = Decor.vers3d(_position, 0.0)
		_corps_pied.rotation.y = -_angle
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
			pieton.rotation.y = -float(a["a"])
			_demarche(pieton, "walk" if abs(float(a.get("v", 0.0))) > 1.0 else "idle")
			_regler_jauge(pieton, float(a["vie"]) / VIE_MAX)

func _placer_la_foule() -> void:
	for personne in ville.gens:
		var noeud = personne.get("noeud")
		if noeud == null:
			if (personne["p"] as Vector2).distance_to(_position) > PORTEE_RENDU or _batisses >= BATISSES_PAR_IMAGE:
				continue
			_batisses += 1
			noeud = FormesCarnage.pieton(_couleur_de(personne),
				int(personne["genre"]) == VilleVivante.GANG, "", false, _peau_de(personne))
			monde().add_child(noeud)
			personne["noeud"] = noeud
		var corps: Node3D = noeud
		corps.visible = (personne["p"] as Vector2).distance_to(_position) <= PORTEE_RENDU
		if not corps.visible:
			continue
		corps.position = Decor.vers3d(personne["p"])
		# Le personnage en cubes regarde +X, comme les voitures.
		corps.rotation.y = -float(personne.get("a", 0.0))
		_demarche(corps, "walk")
		_regler_jauge(corps, float(int(personne["pv"])) / float(_pv_max_de(personne)))

## La tête d'un habitant : les hommes de main ont les leurs, les flics la
## leur, les passants huit visages tirés de leur identifiant. Tirer sur
## l'identifiant et non au hasard, c'est ce qui fait qu'un piéton ne change pas
## de tête entre deux images.
func _peau_de(personne: Dictionary) -> String:
	var graine := int(personne.get("id", 0))
	match int(personne["genre"]):
		VilleVivante.GANG:
			return FormesCarnage.PEAUX_GANG[posmod(graine, FormesCarnage.PEAUX_GANG.size())]
		VilleVivante.FLIC:
			return FormesCarnage.PEAU_FLIC
	return FormesCarnage.peau_civile(graine)

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
		if PlanVille.est_dormante(int(auto["id"])):
			_effacer_la_dormante(int(auto["id"]))
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
		# Une voiture à l'arrêt a ses phares éteints : allumés, on la prend
		# pour une voiture qui arrive.
		var phares := corps.get_node_or_null("Phares") as Node3D
		if phares:
			phares.visible = not bool(auto.get("garee", false))
		_regler_jauge(corps, float(auto["pv"]) / PV_VOITURE)

func _placer_les_objets() -> void:
	for caisse in ville.caisses:
		var noeud = caisse.get("noeud")
		if noeud == null:
			var arme := String(caisse["arme"])
			noeud = FormesCarnage.caisse(arme, COULEURS_BUTIN[arme] if COULEURS_BUTIN.has(arme)
				else ARMES.get(arme, ARMES["pistolet"])["couleur"])
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

## La démarche d'un habitant : ses cuisses et ses bras pivotent quand il
## marche. Quatre os par image et par personnage, rien de plus — et un
## décalage tiré de son adresse, sinon toute la rue marche au même pas.
func _demarche(porteur: Node3D, nom: String) -> void:
	var silhouette := porteur.get_node_or_null("Silhouette") as Node3D
	if silhouette:
		FormesCarnage.animer_kenney(silhouette, nom == "walk",
			temps + float(porteur.get_instance_id() % 97))

## L'hélicoptère : il glisse vers sa dernière position connue, son rotor tourne,
## et on entend ses pales quand il est proche — c'est ce qui dit qu'il est là
## avant qu'on lève les yeux, ce que la caméra ne permet pas.
func _placer_les_helicos(delta: float) -> void:
	var proche_de_moi := false
	for h in ville.helicos:
		var noeud = h.get("noeud")
		if noeud == null:
			noeud = FormesCarnage.helico()
			monde().add_child(noeud)
			h["noeud"] = noeud
		if not est_hote():
			h["p"] = (h["p"] as Vector2).lerp(h.get("cible", h["p"]) if h.get("cible", "") is Vector2 else h["p"], clamp(delta * 8.0, 0, 1))
		var corps: Node3D = noeud
		corps.position = Decor.vers3d(h["p"])
		var cellule := corps.get_node_or_null("Cellule") as Node3D
		if cellule:
			cellule.rotation.y = -float(h.get("cap", 0.0))
			var rotor := cellule.get_node_or_null("Rotor") as Node3D
			if rotor:
				rotor.rotation.y += delta * 28.0
			var feu := cellule.get_node_or_null("Feu") as Node3D
			if feu:
				feu.visible = fmod(temps, 0.5) > 0.25
		if (h["p"] as Vector2).distance_to(_position) < 900.0:
			proche_de_moi = true
	if proche_de_moi:
		_depuis_battement -= delta
		if _depuis_battement <= 0.0:
			_depuis_battement = 0.36
			Sons.jouer("battement", 1.0, -14.0)

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
	var distance: float = DISTANCE_PIED if _pied else DISTANCE_AUTO + RECUL_VITESSE * clamp(abs(_vitesse) / VITESSE_MAX, 0.0, 1.0)
	# Un peu d'avance dans le sens de la marche : on regarde où l'on va.
	var avance := Vector2.RIGHT.rotated(_angle) * _vitesse * 0.22 if not _pied else Vector2.ZERO
	var vise := Decor.viser(_camera, _position + avance, INCLINAISON, distance)
	if _secousse > 0.0:
		_secousse = max(0.0, _secousse - delta * 2.0)
		vise += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * _secousse * 2.5
	_camera.position = _camera.position.lerp(vise, clamp(delta * 7.0, 0, 1))

# ------------------------------------------------------- état affiché

## La fiche du HUD : les étoiles d'abord — c'est ce qui décide de la minute qui
## vient — puis les jauges, l'arme, et l'humeur du quartier en puces. La ligne
## de texte d'autrefois mettait sept mentions bout à bout ; on ne lisait rien
## en conduisant.
## La fortune : ce qui compte au classement. L'argent sur soi et celui de la
## planque, plus la valeur de la planque elle-même.
func fortune() -> int:
	var valeur := 0
	if _planque >= 0:
		var pl := carte.planque_par_id(_position, _planque)
		valeur = int(pl.get("prix", 0)) if not pl.is_empty() else 0
		for cle in _ameliorations:
			if bool(_ameliorations[cle]):
				valeur += int(PlanVille.PRIX_AMELIORATION[cle])
	return _argent + _banque + valeur

func fiche_joueur() -> Dictionary:
	var fiche := {"etoiles": ville.etoiles(Session.cle)}
	var jauges: Array = []
	jauges.append({"nom": "VIE", "part": _vie / 100.0, "couleur": Palette.BON, "valeur": "%d" % int(_vie)})
	if not _pied:
		jauges.append({"nom": "TÔLE", "part": _pv_vehicule / PV_VOITURE,
			"couleur": Palette.SERIE, "valeur": "%d" % int(_pv_vehicule)})
	fiche["jauges"] = jauges
	fiche["arme"] = {"nom": String(ARMES[_arme]["nom"]), "munitions": "" if _munitions < 0 else "%d" % _munitions}
	fiche["argent"] = {"sur_soi": _argent, "banque": _banque, "planque": _planque >= 0}

	var puces: Array = []
	if _mot_affaire_reste > 0.0:
		puces.append({"texte": _mot_affaire, "couleur": Palette.AVERTISSEMENT})
	elif _affaire != "":
		puces.append({"texte": _affaire, "couleur": Palette.SERIE})
	if _hors_service > 0.0:
		puces.append({"texte": "à terre — %d s" % int(ceil(_hors_service)), "couleur": Palette.CRITIQUE})
	if _eperon > 0.0:
		puces.append({"texte": "éperon %ds" % int(ceil(_eperon)), "couleur": Palette.SERIEUX})
	var territoire := carte.territoire(_position)
	if territoire >= 0:
		var humeur := "neutre"
		var couleur := carte.couleur_du_gang(territoire)
		if ville.gang_hostile(Session.cle, territoire):
			humeur = "vous chasse"
			couleur = Palette.CRITIQUE
		elif ville.gang_ami(Session.cle, territoire):
			humeur = "vous laisse"
		puces.append({"texte": "%s : %s" % [carte.nom_du_gang(territoire), humeur], "couleur": couleur})
	else:
		puces.append({"texte": "terrain neutre", "couleur": Palette.ENCRE_FAIBLE})
	if carte.arene_de(_position) >= 0:
		puces.append({"texte": "ARÈNE — tir ami", "couleur": Palette.CRITIQUE})
	if carte.garage_de(_position) >= 0:
		puces.append({"texte": "garage", "couleur": Palette.SERIE})
	if _pied:
		var auto := ville.vehicule_proche(_position, PORTEE_ENTREE)
		puces.append({"texte": "E : monter" if not auto.is_empty() else "à pied", "couleur": Palette.AVERTISSEMENT if not auto.is_empty() else Palette.ENCRE_DOUCE})
	if _hors_ville > 0.2:
		puces.append({"texte": "VOUS QUITTEZ LA VILLE", "couleur": Palette.CRITIQUE})
	fiche["puces"] = puces
	fiche["accent"] = _ma_couleur()
	var alerte := _alerte_contrat()
	if not alerte.is_empty():
		fiche["alerte"] = alerte
	return fiche

func aide_touches() -> Array:
	return [["Z S", "avancer, freiner"], ["Q D", "tourner"], ["ESPACE", "tirer"],
		["E", "monter, descendre"], ["H", "klaxon"], ["TAB", "carte"]]
