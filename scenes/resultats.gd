extends Ecran
## Tableau de fin de manche. Le dépôt en base a déjà eu lieu côté hôte : cet
## écran ne fait que montrer, sinon quatre clients déposeraient quatre fois.

func demarrer() -> void:
	Sons.musique(Sons.THEME)
	var fond := ColorRect.new()
	fond.color = Charte.NUIT
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interface().add_child(fond)
	var titre := String(donnees.get("titre", "Manche terminée"))
	var lignes: Array = donnees.get("classement", [])
	var jeu := String(donnees.get("jeu", "carnage"))
	var note := String(donnees.get("note", ""))

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	interface().add_child(centre)

	var panneau := PanelContainer.new()
	var boite_r := StyleBoxFlat.new()
	boite_r.bg_color = Color(1, 1, 1, 0.03)
	boite_r.border_color = Color(1, 1, 1, 0.12)
	boite_r.set_border_width_all(1)
	boite_r.set_content_margin_all(24)
	panneau.add_theme_stylebox_override("panel", boite_r)
	centre.add_child(panneau)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 12)
	colonne.custom_minimum_size = Vector2(520, 0)
	panneau.add_child(colonne)

	var gagnant := Palette.couleur_joueur(int(lignes[0].get("place", 0))) if not lignes.is_empty() else Palette.SERIE
	colonne.add_child(Charte.entete(titre, note))

	# Le classement : un rang en gros chiffre pixel, le pseudo dans la couleur
	# du joueur, le score à droite, et sous chaque ligne une barre à la longueur
	# du score — le podium se lit d'un coup d'œil, sans comparer des nombres.
	var maximum := 1
	for ligne in lignes:
		maximum = max(maximum, int(ligne.get("score", 0)))
	var rang := 1
	for ligne in lignes:
		var couleur := Palette.couleur_joueur(int(ligne.get("place", rang - 1)))
		var bloc := VBoxContainer.new()
		bloc.add_theme_constant_override("separation", 4)
		var boite := HBoxContainer.new()
		boite.add_theme_constant_override("separation", 14)
		var numero := Charte.titre("%d" % rang, 30 if rang == 1 else 20, Charte.ORANGE if rang == 1 else Color.WHITE)
		numero.custom_minimum_size = Vector2(40, 0)
		numero.add_theme_color_override("font_color", couleur if rang == 1 else Palette.ENCRE_FAIBLE)
		numero.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		boite.add_child(numero)
		var nom := Charte.texte(String(ligne.get("pseudo", "?")), 22, couleur)
		nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boite.add_child(nom)
		var points := Charte.titre(str(int(ligne.get("score", 0))), 20)
		points.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		boite.add_child(points)
		bloc.add_child(boite)
		var fond_barre := ColorRect.new()
		fond_barre.color = Color(couleur, 0.18)
		fond_barre.custom_minimum_size = Vector2(0, 4)
		var barre := ColorRect.new()
		barre.color = couleur
		barre.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		barre.anchor_right = float(int(ligne.get("score", 0))) / float(maximum)
		fond_barre.add_child(barre)
		bloc.add_child(fond_barre)
		colonne.add_child(bloc)
		rang += 1
	if lignes.is_empty():
		colonne.add_child(Charte.texte("Aucun score.", 17, Color(1, 1, 1, 0.5)))

	var espace := Control.new()
	espace.custom_minimum_size = Vector2(0, 8)
	colonne.add_child(espace)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	colonne.add_child(actions)

	var rejouer := Charte.bouton("Rejouer", true)
	rejouer.pressed.connect(func(): demande_ecran.emit("salon", {"jeu": jeu, "titre": titre}))
	actions.add_child(rejouer)

	var hub := Charte.bouton("Retour au menu")
	hub.pressed.connect(func(): demande_ecran.emit("menu", {}))
	actions.add_child(hub)
