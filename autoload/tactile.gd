extends Node
## Commandes au doigt.
##
## Le jeu se partage par un lien : une bonne moitié des gens l'ouvriront sur un
## téléphone. Sans manette à l'écran, ils voient le hub, ne peuvent pas
## bouger, et referment l'onglet.
##
## Un manche à gauche, PEU de boutons à droite, et rien du tout sur un poste
## sans écran tactile — un pavé virtuel affiché à quelqu'un qui a un clavier
## passe pour un défaut.
##
## TROIS BOUTONS À L'ÉCRAN, pas sept. On en avait mis un par touche du
## clavier (tir, entrer, affaire, carte, manger, radio, pause) : un pavé de
## sept ronds, c'est un clavier dessiné, et on appuie sur le mauvais. Il reste :
## - TIR et ENTRER/SORTIR, qu'on martèle ;
## - AFFAIRE, qui N'APPARAÎT QUE quand `F` ferait quelque chose ici (acheter,
##   déposer, entrer chez soi…) — un bouton qui surgit dit « il y a quelque
##   chose à faire », mieux qu'une ligne de texte ;
## - le MENU (≡), qui déplie en éventail ce qu'on fait de temps en temps :
##   CARTE, SAC (→ MANGER, BOIRE), RADIO au volant, PAUSE. Deux appuis pour
##   manger, mais un seul rond au repos.
##
## LE PAVÉ NE VIT QU'EN VILLE (`en_jeu`, posé par la racine à chaque écran) :
## sur le chargement et dans le salon il n'a rien à commander, et il s'efface
## sous la carte et sous les menus (`Commandes.saisie`) — là, le doigt tape
## les lignes, pas le manche.
##
## SUR UN TÉLÉPHONE, TOUT EST PLUS GROS : la scène est prévue pour 1280×720
## et s'y étire (`canvas_items` / `expand`) ; sur un écran de six pouces un
## texte de 12 px fait un millimètre. On abaisse la taille logique à 960×540
## (`content_scale_size`) : tout l'en-jeu grandit d'un tiers sans qu'aucun
## écran ne change, et la mise en page tient encore (le pavé est placé pour
## les deux tailles). Une tablette garde 1280×720 : elle a la place.

signal action()

enum { MARCHE, CONDUITE }

const RAYON_BASE := 92.0
const RAYON_POUCE := 42.0
const MARGE := 40.0

## Les centres et rayons des boutons, calculés d'après la taille de l'écran :
## le dessin (`ui/manche.gd`) et la lecture des doigts partagent la même
## table, sinon on appuie à côté de ce qu'on voit.
const RAYON_TIR := 70.0
const RAYON_ACTION := 56.0
const RAYON_AFFAIRE := 44.0
const RAYON_MENU := 34.0
const RAYON_VOLET := 34.0         ## un bouton de l'éventail
const PORTEE_VOLET := 110.0       ## la distance du menu à ses boutons
const TAILLE_TELEPHONE := Vector2i(960, 540)
const VOLET_DELAI := 5.0          ## secondes sans appui : l'éventail se replie

var mode: int = MARCHE
var direction := Vector2.ZERO
var bouton_tenu := false
var bouton_action_tenu := false
var bouton_affaire_tenu := false
var bouton_carte_tenu := false
var bouton_manger_tenu := false
var bouton_radio_tenu := false
var bouton_klaxon_tenu := false   ## le klaxon au volant, le DÉTONATEUR à pied
var detonateur_possible := false  ## posé par l'écran de jeu : des bombes sont armées quelque part
var envie := ""                   ## « manger » ou « boire » : ce que le SAC a choisi
var _radio_avant := false
var carte_ouverte := false        ## posé par l'écran de jeu : le pavé s'efface, la carte a ses boutons
var affaire_possible := false     ## posé par l'écran de jeu : `F` ferait quelque chose ici
var en_jeu := false               ## posé par la racine : le pavé ne se montre qu'en ville
var telephone := false            ## petit écran : la scène passe à 960×540
var volet := ""                   ## l'éventail ouvert : "", "menu" ou "sac"

var _couche: CanvasLayer
var _zone = null   ## Control portant ui/manche.gd (non typé : ses champs sont ajoutés par le script)
var _disponible := false
var _doigt_manche := -1
var _doigts := {}                 ## nom du bouton → index du doigt qui le tient
var _centre := Vector2.ZERO
var _pouce := Vector2.ZERO
var _volet_reste := 0.0
var _volet_de_banc := ""          ## `--banc-volet=menu|sac` : l'éventail ouvert pour la photo
var _fiche_de_banc := false       ## `--banc-fiche` : la pause puis la fiche des commandes, pour la photo
var _banc_temps := 0.0

func _ready() -> void:
	# `--tactile` force l'affichage sur un poste sans écran tactile : sans ça,
	# le pavé virtuel ne serait jamais exercé par le banc d'essai, et on ne
	# saurait qu'il est cassé qu'en ouvrant le jeu sur un téléphone.
	_disponible = DisplayServer.is_touchscreen_available() or "--tactile" in OS.get_cmdline_args()
	if not _disponible:
		return
	telephone = _est_un_telephone() or "--telephone" in OS.get_cmdline_args()
	for argument in OS.get_cmdline_args():
		if String(argument).begins_with("--banc-volet="):
			_volet_de_banc = String(argument).substr(13)
	_fiche_de_banc = "--banc-fiche" in OS.get_cmdline_args()
	if telephone:
		get_window().content_scale_size = TAILLE_TELEPHONE
	_couche = CanvasLayer.new()
	_couche.layer = 50
	add_child(_couche)
	_zone = Control.new()
	_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zone.set_script(preload("res://ui/manche.gd"))
	_couche.add_child(_zone)

func actif() -> bool:
	return _disponible

## Un téléphone, pas une tablette : moins de 600 points CSS dans le sens
## court (le seuil habituel des feuilles de style), ou moins de sept pouces
## de diagonale quand le système sait la mesurer. Dans le navigateur, seule
## la fenêtre est fiable — la densité rapportée y est celle du bureau.
func _est_un_telephone() -> bool:
	if OS.has_feature("web"):
		var court = JavaScriptBridge.eval("Math.min(window.screen.width, window.screen.height)", true)
		return court != null and float(court) < 600.0
	var taille := Vector2(DisplayServer.screen_get_size())
	var dpi := float(DisplayServer.screen_get_dpi())
	if dpi <= 0.0:
		return false
	return taille.length() / dpi < 7.0

## Le pavé a-t-il quelque chose à faire ? Pas hors de la ville, pas sous la
## carte, pas pendant qu'un menu ou le tchat prennent les touches.
func efface() -> bool:
	return not en_jeu or carte_ouverte or Commandes.saisie

func libelle_bouton() -> String:
	return "TIR"

## Le second bouton. Il dit ce qu'il FERA, pas où l'on est : « SORTIR » quand
## on est au volant, « ENTRER » quand on est à pied. Un bouton qui nomme
## l'état oblige à réfléchir avant chaque appui.
func libelle_action() -> String:
	return "SORTIR" if mode == CONDUITE else "ENTRER"

## Où sont les boutons pour un écran de cette taille : {nom: [centre, rayon]}.
## TIR en bas à droite sous le pouce ; ENTRER en haut à gauche de TIR (le
## pouce se déplace en arc, il ne monte pas droit) ; AFFAIRE et le MENU plus
## loin vers la gauche, plus petits — on les cherche, on ne les martèle pas.
## Rien ne monte au-dessus de H − 244 : sur un téléphone (540 de haut) le
## radar descend jusqu'à 268, et un ENTRER posé au-dessus de TIR passait
## dessous. L'éventail, lui, s'ouvre vers le HAUT et la GAUCHE du menu, où il
## n'y a que la ville.
func boutons(taille: Vector2) -> Dictionary:
	var tir := Vector2(taille.x - MARGE - RAYON_TIR, taille.y - MARGE - RAYON_TIR)
	var menu := tir + Vector2(-250.0, -20.0)
	var b := {
		"tir": [tir, RAYON_TIR],
		"action": [tir + Vector2(-140.0, -50.0), RAYON_ACTION],
		"affaire": [tir + Vector2(-250.0, -120.0), RAYON_AFFAIRE],
		"menu": [menu, RAYON_MENU],
	}
	# L'éventail : un bouton tous les 40° autour du haut-gauche du menu (225°),
	# à égale distance, dans l'ordre où on les lit. Quarante degrés à cette
	# portée, c'est 75 px d'un centre à l'autre — deux ronds de 34 ne se
	# touchent pas. Ouvert, il est SEUL avec le menu : les autres boutons se
	# retirent, l'éventail ne peut rien recouvrir.
	var noms := _boutons_du_volet()
	for i in noms.size():
		var angle := deg_to_rad(225.0 + 40.0 * (float(i) - float(noms.size() - 1) * 0.5))
		b[noms[i]] = [menu + Vector2(cos(angle), sin(angle)) * PORTEE_VOLET, RAYON_VOLET]
	return b

## Les boutons de l'éventail ouvert, dans l'ordre de l'arc.
func _boutons_du_volet() -> Array:
	match volet:
		"menu":
			var noms := ["carte", "sac"]
			if mode == CONDUITE:
				noms.append("radio")
				noms.append("klaxon")
			elif detonateur_possible:
				noms.append("detonateur")
			noms.append("son")
			noms.append("pause")
			return noms
		"sac":
			return ["manger", "boire"]
	return []

## La radio au doigt se DÉCLENCHE (un appui, une station), elle ne se tient
## pas : la roue demande une direction en plus, et le pouce gauche conduit.
func radio_declenchee() -> bool:
	var front := bouton_radio_tenu and not _radio_avant
	_radio_avant = bouton_radio_tenu
	return front

func _input(evenement: InputEvent) -> void:
	if not _disponible:
		return
	var taille := get_viewport().get_visible_rect().size

	# LE PAVÉ EFFACÉ, il se tait : chaque doigt est à la carte (glisser,
	# pincer, viser) ou au menu (les lignes) — jamais au manche. On LÂCHE
	# tout en entrant : le doigt qui a ouvert la carte est encore sur le
	# bouton, et son relâchement n'arrivera jamais ici ; un bouton resté tenu
	# n'aurait plus de front, et la carte ne se rouvrirait plus.
	if efface():
		_lacher_tout()
		return

	if evenement is InputEventScreenTouch:
		var t := evenement as InputEventScreenTouch
		if t.pressed:
			_presser(t.index, t.position, taille)
		else:
			_relacher(t.index)
		_rafraichir()
	elif evenement is InputEventScreenDrag:
		var d := evenement as InputEventScreenDrag
		if d.index == _doigt_manche:
			_pouce = d.position
			var ecart := _pouce - _centre
			# On plafonne à la base plutôt que de normaliser : un petit
			# mouvement doit donner une petite poussée, sinon la voiture part
			# à fond au moindre frôlement.
			direction = ecart / RAYON_BASE
			if direction.length() > 1.0:
				direction = direction.normalized()
			if direction.length() < 0.18:
				direction = Vector2.ZERO
			_rafraichir()

## Un doigt se pose. La zone de prise dépasse un peu le dessin : un pouce
## n'est pas une pointe de stylet.
func _presser(index: int, ou: Vector2, taille: Vector2) -> void:
	var b := boutons(taille)
	var sur := _bouton_sous(ou, b)
	# L'ÉVENTAIL OUVERT EST MODAL : on choisit, on referme, ou on appuie à
	# côté et il se replie — le manche ne reprend qu'après. Sinon le pouce
	# gauche ferait avancer la voiture pendant qu'on cherche BOIRE.
	if volet != "":
		if sur == "menu" or not (sur in _boutons_du_volet()):
			_fermer_le_volet()
			return
		_volet_reste = VOLET_DELAI
		match sur:
			"sac":
				volet = "sac"
			"carte":
				_doigts["carte"] = index
				bouton_carte_tenu = true
				_fermer_le_volet()
			"radio":
				_doigts["radio"] = index
				bouton_radio_tenu = true
				_fermer_le_volet()
			"klaxon", "detonateur":
				# Le klaxon se TIENT (il se module) : l'éventail reste ouvert
				# tant que le doigt est dessus, il se replie au relâcher.
				_doigts["klaxon"] = index
				bouton_klaxon_tenu = true
				if sur == "detonateur":
					_fermer_le_volet()
			"son":
				Sons.basculer()
				_fermer_le_volet()
			"pause":
				# ÉCHAP, ni plus ni moins : la même précédence que la touche —
				# fermer ce qui est ouvert, sinon ouvrir la pause.
				Commandes.appuyer(KEY_ESCAPE)
				_fermer_le_volet()
			"manger", "boire":
				envie = sur
				_doigts["manger"] = index
				bouton_manger_tenu = true
				_fermer_le_volet()
		return
	match sur:
		"menu":
			volet = "menu"
			_volet_reste = VOLET_DELAI
			# Le manche lâche : on ne conduit pas en choisissant.
			_doigt_manche = -1
			direction = Vector2.ZERO
		"affaire":
			if affaire_possible:
				_doigts["affaire"] = index
				bouton_affaire_tenu = true
		"action":
			_doigts["action"] = index
			bouton_action_tenu = true
		"tir":
			_doigts["tir"] = index
			bouton_tenu = true
			action.emit()
		_:
			if ou.x < taille.x * 0.55 and _doigt_manche < 0:
				_doigt_manche = index
				_centre = ou
				_pouce = ou

## Le bouton sous un point, ou "". Les boutons de l'éventail ne comptent
## qu'ouvert, AFFAIRE que s'il a quelque chose à faire ; le reste (ENTRER,
## TIR, le menu) toujours — mais ouvert, seul le menu répond.
func _bouton_sous(ou: Vector2, b: Dictionary) -> String:
	for nom in b:
		var centre: Vector2 = b[nom][0]
		var rayon: float = b[nom][1]
		if ou.distance_to(centre) <= rayon + 14.0:
			return String(nom)
	return ""

func _relacher(index: int) -> void:
	for nom in _doigts.keys():
		if int(_doigts[nom]) == index:
			_doigts.erase(nom)
			match String(nom):
				"tir": bouton_tenu = false
				"action": bouton_action_tenu = false
				"affaire": bouton_affaire_tenu = false
				"carte": bouton_carte_tenu = false
				"radio": bouton_radio_tenu = false
				"manger": bouton_manger_tenu = false
				"klaxon":
					bouton_klaxon_tenu = false
					if volet != "":
						_fermer_le_volet()
	if index == _doigt_manche:
		_doigt_manche = -1
		direction = Vector2.ZERO

func _fermer_le_volet() -> void:
	volet = ""
	_volet_reste = 0.0

func _rafraichir() -> void:
	if _zone:
		_zone.manche_visible = _doigt_manche >= 0
		_zone.centre = _centre
		_zone.pouce = _centre + (_pouce - _centre).limit_length(RAYON_BASE)
		_zone.bouton_tenu = bouton_tenu
		_zone.bouton_action_tenu = bouton_action_tenu
		_zone.bouton_affaire_tenu = bouton_affaire_tenu
		_zone.tenus = _doigts.keys()
		_zone.son_actif = Sons.actif
		_zone.volet = volet
		_zone.affaire_possible = affaire_possible
		_zone.efface = efface()
		_zone.libelle = libelle_bouton()
		_zone.libelle_action = libelle_action()
		_zone.queue_redraw()

## Ce qui change sans qu'un doigt bouge : l'écran de jeu ouvre la carte ou
## un menu, on monte en voiture, une affaire apparaît sous nos pieds, ou
## l'éventail a attendu trop longtemps. Le pavé se redessine avec.
func _process(delta: float) -> void:
	if _zone == null:
		return
	# Le banc n'a pas de doigt : trois touches virtuelles ouvrent la pause,
	# descendent d'une ligne et valident — la fiche des commandes s'affiche.
	if _fiche_de_banc and en_jeu:
		_banc_temps += delta
		if absf(_banc_temps - 6.0) < delta:
			Commandes.appuyer(KEY_ESCAPE)
		elif absf(_banc_temps - 7.0) < delta:
			Commandes.appuyer(KEY_DOWN)
		elif absf(_banc_temps - 8.0) < delta:
			Commandes.appuyer(KEY_ENTER)
	if volet != "":
		_volet_reste -= delta
		if _volet_reste <= 0.0:
			_fermer_le_volet()
	elif _volet_de_banc != "" and not efface():
		# Le banc n'a pas de doigt : l'éventail s'ouvre seul et reste ouvert.
		volet = _volet_de_banc
		_volet_reste = 1.0e9
	if _zone.efface != efface():
		if efface():
			_lacher_tout()
		_rafraichir()
	elif _zone.volet != volet or _zone.affaire_possible != affaire_possible \
			or _zone.libelle_action != libelle_action():
		_rafraichir()

## Tous les doigts relâchés d'un coup — quand le pavé s'efface.
func _lacher_tout() -> void:
	if _doigt_manche < 0 and _doigts.is_empty() and volet == "":
		return
	_doigt_manche = -1
	_doigts.clear()
	direction = Vector2.ZERO
	bouton_tenu = false
	bouton_action_tenu = false
	bouton_affaire_tenu = false
	bouton_carte_tenu = false
	bouton_manger_tenu = false
	bouton_radio_tenu = false
	bouton_klaxon_tenu = false
	_fermer_le_volet()
	_rafraichir()

## Ce que les commandes lisent : à la marche, la direction telle quelle ;
## au volant, x braque et y accélère (le doigt vers le haut = avancer).
func direction_de_marche() -> Vector2:
	return direction

func direction_de_conduite() -> Vector2:
	return Vector2(direction.x, -direction.y)
