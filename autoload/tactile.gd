extends Node
## Commandes au doigt.
##
## Le jeu se partage par un lien : une bonne moitié des gens l'ouvriront sur un
## téléphone. Sans manette à l'écran, ils voient le hub, ne peuvent pas
## bouger, et referment l'onglet.
##
## Un manche à gauche, un bouton à droite, et rien du tout sur un poste sans
## écran tactile — un pavé virtuel affiché à quelqu'un qui a un clavier passe
## pour un défaut.

signal action()

enum { MARCHE, CONDUITE }

const RAYON_BASE := 92.0
const RAYON_POUCE := 42.0
const MARGE := 40.0

var mode: int = MARCHE
var direction := Vector2.ZERO
var bouton_tenu := false

var _couche: CanvasLayer
var _zone = null   ## Control portant ui/manche.gd (non typé : ses champs sont ajoutés par le script)
var _disponible := false
var _doigt_manche := -1
var _doigt_bouton := -1
var _centre := Vector2.ZERO
var _pouce := Vector2.ZERO

func _ready() -> void:
	# `--tactile` force l'affichage sur un poste sans écran tactile : sans ça,
	# le pavé virtuel ne serait jamais exercé par le banc d'essai, et on ne
	# saurait qu'il est cassé qu'en ouvrant le jeu sur un téléphone.
	_disponible = DisplayServer.is_touchscreen_available() or "--tactile" in OS.get_cmdline_args()
	if not _disponible:
		return
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

func libelle_bouton() -> String:
	return "TIR" if mode == CONDUITE else "ENTRER"

func _input(evenement: InputEvent) -> void:
	if not _disponible:
		return
	var taille := get_viewport().get_visible_rect().size
	var bouton_centre := Vector2(taille.x - MARGE - 70.0, taille.y - MARGE - 70.0)

	if evenement is InputEventScreenTouch:
		var t := evenement as InputEventScreenTouch
		if t.pressed:
			if t.position.distance_to(bouton_centre) <= 88.0:
				_doigt_bouton = t.index
				bouton_tenu = true
				action.emit()
			elif t.position.x < taille.x * 0.55 and _doigt_manche < 0:
				_doigt_manche = t.index
				_centre = t.position
				_pouce = t.position
		else:
			if t.index == _doigt_bouton:
				_doigt_bouton = -1
				bouton_tenu = false
			if t.index == _doigt_manche:
				_doigt_manche = -1
				direction = Vector2.ZERO
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

func _rafraichir() -> void:
	if _zone:
		_zone.manche_visible = _doigt_manche >= 0
		_zone.centre = _centre
		_zone.pouce = _centre + (_pouce - _centre).limit_length(RAYON_BASE)
		_zone.bouton_tenu = bouton_tenu
		_zone.libelle = libelle_bouton()
		_zone.queue_redraw()

## Ce que les commandes lisent : à la marche, la direction telle quelle ;
## au volant, x braque et y accélère (le doigt vers le haut = avancer).
func direction_de_marche() -> Vector2:
	return direction

func direction_de_conduite() -> Vector2:
	return Vector2(direction.x, -direction.y)
