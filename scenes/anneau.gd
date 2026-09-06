extends Node2D
## Décor : un anneau qui tourne lentement, repris du vocabulaire des portails.

var _t := 0.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	for i in 3:
		var rayon := 120.0 + i * 34.0
		var alpha := 0.28 - i * 0.07
		draw_arc(Vector2.ZERO, rayon, _t * (0.4 + i * 0.25), _t * (0.4 + i * 0.25) + TAU * 0.62,
			48, Color(Palette.SERIE, alpha), 2.0, true)
	draw_circle(Vector2.ZERO, 46.0, Color(Palette.SERIE, 0.10))
