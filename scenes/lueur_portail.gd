extends Node2D
## Le portail au fond d'une pièce : un rectangle qui palpite.
##
## Dessiné plutôt que dessiné-en-image : il doit s'accorder à la palette de la
## maison et pulser, ce qu'un sprite fixe du pack ne ferait pas.

var taille := Vector2(80, 56)
var _t := 0.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var battement := 0.5 + 0.5 * sin(_t * 2.4)
	var rect := Rect2(-taille * 0.5, taille)
	draw_rect(rect, Color(Palette.SERIE, 0.18 + 0.12 * battement), true)
	draw_rect(rect, Color(Palette.SERIE, 0.55 + 0.35 * battement), false, 2.0)
	for i in 3:
		var r := taille.x * (0.2 + 0.14 * i) * (0.9 + 0.1 * battement)
		draw_arc(Vector2.ZERO, r, _t * (0.6 + i * 0.4), _t * (0.6 + i * 0.4) + TAU * 0.7,
			24, Color(Palette.SERIE, 0.5 - i * 0.12), 2.0)
