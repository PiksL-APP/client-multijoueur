extends Button
## Le bouton « SON » de l'en-tête : quatre barres d'égaliseur qui dansent tant
## que le son est actif, et se couchent quand il ne l'est pas.
##
## Il est à part parce qu'un `Button` fabriqué par la charte ne peut pas
## s'animer tout seul : il lui faut un script. Les barres sont dessinées, pas
## écrites — aucune police n'a ce glyphe-là.

const BARRES := [4.0, 11.0, 7.0, 14.0]

var _egaliseur: Control
var _t := 0.0

func _ready() -> void:
	_egaliseur = Control.new()
	_egaliseur.custom_minimum_size = Vector2(21, 14)
	_egaliseur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_egaliseur.draw.connect(_dessiner)
	add_child(_egaliseur)
	pressed.connect(_basculer)
	_rafraichir()

func _basculer() -> void:
	Sons.basculer()
	Sons.interface("valider", -10.0)
	_rafraichir()

func _rafraichir() -> void:
	text = "Son" if Sons.actif else "Son coupé"
	tooltip_text = "Couper le son" if Sons.actif else "Activer le son"

func _process(delta: float) -> void:
	_t += delta
	if _egaliseur != null:
		# Les barres se calent à gauche du libellé, dans la marge du bouton.
		_egaliseur.position = Vector2(14, (size.y - 14.0) * 0.5)
		_egaliseur.queue_redraw()

func _dessiner() -> void:
	for i in BARRES.size():
		var h: float = BARRES[i]
		if Sons.actif:
			h = 3.0 + (BARRES[i] - 3.0) * (0.5 + 0.5 * sin(_t * 6.0 + i * 1.3))
		else:
			h = 3.0
		var x := i * 6.0
		_egaliseur.draw_rect(Rect2(x, 14.0 - h, 3.0, h),
			Charte.CYAN if Sons.actif else Color(1, 1, 1, 0.3))
