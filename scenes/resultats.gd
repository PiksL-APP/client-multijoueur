extends Ecran
## Tableau de fin de manche. Le dépôt en base a déjà eu lieu côté hôte : cet
## écran ne fait que montrer, sinon quatre clients déposeraient quatre fois.

func demarrer() -> void:
	UI.fond(interface())
	var titre := String(donnees.get("titre", "Manche terminée"))
	var lignes: Array = donnees.get("classement", [])
	var jeu := String(donnees.get("jeu", "carnage"))
	var note := String(donnees.get("note", ""))

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	interface().add_child(centre)

	var panneau := UI.panneau()
	centre.add_child(panneau)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 12)
	colonne.custom_minimum_size = Vector2(520, 0)
	panneau.add_child(colonne)

	var gagnant := Palette.couleur_joueur(int(lignes[0].get("place", 0))) if not lignes.is_empty() else Palette.SERIE
	colonne.add_child(UI.entete(titre, note, gagnant))

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
		var numero := UI.titre("%d" % rang, 24 if rang == 1 else 16)
		numero.custom_minimum_size = Vector2(40, 0)
		numero.add_theme_color_override("font_color", couleur if rang == 1 else Palette.ENCRE_FAIBLE)
		numero.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		boite.add_child(numero)
		var nom := UI.texte(String(ligne.get("pseudo", "?")), 22, couleur)
		nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boite.add_child(nom)
		var points := UI.titre(str(int(ligne.get("score", 0))), 16)
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
		colonne.add_child(UI.texte("Aucun score.", 15, Palette.ENCRE_FAIBLE))

	var espace := Control.new()
	espace.custom_minimum_size = Vector2(0, 8)
	colonne.add_child(espace)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	colonne.add_child(actions)

	var rejouer := UI.bouton("Rejouer", true)
	rejouer.pressed.connect(func(): demande_ecran.emit("salon", {"jeu": jeu, "titre": titre}))
	actions.add_child(rejouer)

	var hub := UI.bouton("Retour au hub")
	hub.pressed.connect(func(): demande_ecran.emit("menu", {}))
	actions.add_child(hub)
