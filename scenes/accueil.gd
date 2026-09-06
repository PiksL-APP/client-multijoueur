extends Ecran
## Écran d'entrée : on choisit un pseudo, on regarde l'état de la connexion,
## on entre dans le hub. Rien d'autre — le reste se découvre en jouant.

var _champ: LineEdit
var _bouton: Button
var _etat: HBoxContainer
var _avertissement: Label

func demarrer() -> void:
	UI.fond(self)
	_dessiner_decor()

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var panneau := UI.panneau()
	centre.add_child(panneau)

	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 14)
	colonne.custom_minimum_size = Vector2(420, 0)
	panneau.add_child(colonne)

	colonne.add_child(UI.titre("Piks-l Multijoueur"))
	colonne.add_child(UI.texte(
		"Un hub, des portails. Chaque portail lance un jeu de 2 à 4 joueurs. "
		+ "Déplacement : Z Q S D ou les flèches. Entrer dans un portail : E.",
		15, Palette.ENCRE_DOUCE, true))

	var separation := HSeparator.new()
	separation.add_theme_constant_override("separation", 10)
	colonne.add_child(separation)

	_champ = UI.champ("Votre pseudo", Session.pseudo)
	_champ.text_submitted.connect(func(_t): _entrer())
	_champ.text_changed.connect(func(_t): _rafraichir())
	colonne.add_child(_champ)

	_bouton = UI.bouton("Entrer dans le hub", true)
	_bouton.pressed.connect(_entrer)
	colonne.add_child(_bouton)

	_avertissement = UI.texte("", 13, Palette.AVERTISSEMENT, true)
	colonne.add_child(_avertissement)

	var bas := HBoxContainer.new()
	bas.add_theme_constant_override("separation", 12)
	colonne.add_child(bas)
	_etat = UI.etat_reseau()
	bas.add_child(_etat)
	bas.add_child(UI.texte("version " + Config.version, 13, Palette.ENCRE_FAIBLE))

	Reseau.etat_change.connect(func(_e): _rafraichir())
	_champ.grab_focus()
	_rafraichir()

func _dessiner_decor() -> void:
	# Un fond qui bouge à peine : le portail du hub, en veilleuse.
	var anneau := Node2D.new()
	anneau.position = Vector2(1060, 560)
	anneau.set_script(preload("res://scenes/anneau.gd"))
	add_child(anneau)

func _rafraichir() -> void:
	UI.rafraichir_etat_reseau(_etat)
	var pseudo := Session.nettoyer_pseudo(_champ.text)
	var pret := pseudo.length() >= 2 and Reseau.etat == Reseau.EN_LIGNE
	_bouton.disabled = not pret
	if not Config.est_configure():
		_avertissement.text = "Clés Supabase absentes : le multijoueur ne peut pas démarrer."
	elif pseudo.length() < 2:
		_avertissement.text = "Deux caractères au minimum."
	elif Reseau.etat != Reseau.EN_LIGNE:
		_avertissement.text = "Connexion au serveur temps réel…"
	else:
		_avertissement.text = ""

func _entrer() -> void:
	var pseudo := Session.nettoyer_pseudo(_champ.text)
	if pseudo.length() < 2 or Reseau.etat != Reseau.EN_LIGNE:
		return
	Session.definir_pseudo(pseudo)
	demande_ecran.emit("hub", {})
