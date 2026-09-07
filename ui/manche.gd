extends Control
## Le dessin du manche et du bouton. Séparé de la logique tactile : ici on ne
## fait que peindre ce que l'autoload a mesuré.

var manche_visible := false
var centre := Vector2.ZERO
var pouce := Vector2.ZERO
var bouton_tenu := false
var libelle := "TIR"
var bouton_action_tenu := false
var libelle_action := "ENTRER"

func _draw() -> void:
	var taille := get_viewport_rect().size
	var bouton := Vector2(taille.x - 40.0 - 70.0, taille.y - 40.0 - 70.0)

	var action := bouton - Vector2(0.0, 168.0)
	var police := Palette.police()

	draw_circle(bouton, 70.0, Color(Palette.SERIE, 0.30 if bouton_tenu else 0.16))
	draw_arc(bouton, 70.0, 0, TAU, 40, Color(Palette.SERIE, 0.85), 3.0, true)
	var largeur := police.get_string_size(libelle, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(police, bouton + Vector2(-largeur * 0.5, 7), libelle,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.ENCRE)

	# Le bouton d'action est plus petit et d'une autre teinte : deux ronds
	# identiques l'un au-dessus de l'autre, on appuie sur le mauvais.
	draw_circle(action, 56.0, Color(Palette.AVERTISSEMENT, 0.30 if bouton_action_tenu else 0.14))
	draw_arc(action, 56.0, 0, TAU, 36, Color(Palette.AVERTISSEMENT, 0.80), 3.0, true)
	var large_action := police.get_string_size(libelle_action, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	draw_string(police, action + Vector2(-large_action * 0.5, 6), libelle_action,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Palette.ENCRE)

	if manche_visible:
		draw_circle(centre, 92.0, Color(1, 1, 1, 0.07))
		draw_arc(centre, 92.0, 0, TAU, 48, Color(1, 1, 1, 0.22), 2.0, true)
		draw_circle(pouce, 42.0, Color(Palette.ENCRE, 0.35))
	else:
		# Une empreinte discrète en bas à gauche : elle dit qu'il y a quelque
		# chose à toucher, sans encombrer l'écran tant qu'on n'y touche pas.
		var repos := Vector2(40.0 + 92.0, taille.y - 40.0 - 92.0)
		draw_arc(repos, 92.0, 0, TAU, 48, Color(1, 1, 1, 0.10), 2.0, true)
		draw_circle(repos, 22.0, Color(1, 1, 1, 0.08))
