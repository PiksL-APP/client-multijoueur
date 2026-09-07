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

	colonne.add_child(UI.titre(titre, 30))
	if note != "":
		colonne.add_child(UI.texte(note, 15, Palette.ENCRE_DOUCE))
	colonne.add_child(HSeparator.new())

	var rang := 1
	for ligne in lignes:
		var boite := HBoxContainer.new()
		boite.add_theme_constant_override("separation", 12)
		var couleur := Palette.couleur_joueur(int(ligne.get("place", rang - 1)))
		var nom := UI.texte("%d.  %s" % [rang, String(ligne.get("pseudo", "?"))], 19, couleur)
		nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boite.add_child(nom)
		boite.add_child(UI.texte(str(int(ligne.get("score", 0))) + " pts", 19, Palette.ENCRE))
		colonne.add_child(boite)
		rang += 1
	if lignes.is_empty():
		colonne.add_child(UI.texte("Aucun score.", 15, Palette.ENCRE_FAIBLE))

	colonne.add_child(HSeparator.new())
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	colonne.add_child(actions)

	var rejouer := UI.bouton("Rejouer", true)
	rejouer.pressed.connect(func(): demande_ecran.emit("salon", {"jeu": jeu, "titre": titre}))
	actions.add_child(rejouer)

	var hub := UI.bouton("Retour au hub")
	hub.pressed.connect(func(): demande_ecran.emit("hub", {}))
	actions.add_child(hub)
