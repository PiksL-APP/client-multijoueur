extends Ecran
## Écran d'entrée : on choisit un pseudo, on regarde l'état de la connexion,
## on entre dans le hub. Derrière le panneau, un portail tourne — le même objet
## que dans le hub, pour que l'écran annonce ce qu'on va y trouver.

var _champ: LineEdit
var _bouton: Button
var _portraits: Dictionary = {}    # nom -> Button
var _etat: HBoxContainer
var _avertissement: Label
var _anneaux: Array[Node3D] = []
var _t := 0.0

func demarrer() -> void:
	_decor()
	UI.fond(interface())
	# Le fond 3D doit rester visible : le panneau se pose dessus, pas devant.
	interface().get_child(0).color = Color(Palette.FOND, 0.0)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	interface().add_child(centre)

	var panneau := UI.panneau()
	centre.add_child(panneau)

	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 14)
	colonne.custom_minimum_size = Vector2(440, 0)
	panneau.add_child(colonne)

	colonne.add_child(UI.titre("Piks-l Multijoueur"))
	colonne.add_child(UI.texte(
		"Un hub, des portails. Chaque portail lance un jeu de 2 à 4 joueurs. "
		+ "Déplacement : Z Q S D ou les flèches. Entrer dans un portail : E.",
		15, Palette.ENCRE_DOUCE, true))

	var separation := HSeparator.new()
	colonne.add_child(separation)

	_champ = UI.champ("Votre pseudo", Session.pseudo)
	_champ.text_submitted.connect(func(_t): _entrer())
	_champ.text_changed.connect(func(_t): _rafraichir())
	colonne.add_child(_champ)

	# Le héros qu'on incarne dans le village : chevalier, voleur ou mage.
	# Les autres nous voient sous ce trait, il fait partie de l'identité.
	colonne.add_child(UI.texte("Votre héros", 15, Palette.ENCRE_FAIBLE))
	var rangee := HBoxContainer.new()
	rangee.add_theme_constant_override("separation", 12)
	colonne.add_child(rangee)
	var noms := {"knight": "Chevalier", "rogue": "Voleur", "wizzard": "Mage"}
	for nom in Pixels.HEROS:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(128, 128)
		b.icon = Pixels.portrait(nom)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.tooltip_text = String(noms[nom])
		b.pressed.connect(func() -> void:
			Session.definir_heros(nom)
			_rafraichir())
		rangee.add_child(b)
		_portraits[nom] = b

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

func _rafraichir_portraits() -> void:
	var choisi := Session.heros_affiche()
	for nom in _portraits:
		var b: Button = _portraits[nom]
		var elu: bool = nom == choisi
		var style := StyleBoxFlat.new()
		style.bg_color = Palette.SURFACE.lightened(0.06) if elu else Palette.SURFACE
		style.border_color = Palette.SERIE if elu else Palette.FILET
		style.set_border_width_all(2 if elu else 1)
		style.set_corner_radius_all(8)
		style.set_content_margin_all(8)
		for etat in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(etat, style)
		b.modulate = Color.WHITE if elu else Color(1, 1, 1, 0.6)

func _decor() -> void:
	poser_ambiance(false)
	var cam := Decor.camera(28.0, 46.0, 46.0)
	cam.position = Vector3(4.0, 14.0, 44.0)
	cam.rotation_degrees = Vector3(-16, 12, 0)
	monde().add_child(cam)
	cam.make_current()

	var socle := Decor.sol(Vector2(3000, 3000), 100.0)
	socle.position = Vector3(0, -6, 0)
	monde().add_child(socle)

	# Trois anneaux concentriques posés à plat puis redressés : c'est la
	# signature visuelle du portail, reprise telle quelle dans le hub.
	var couleurs := [Palette.SERIE, Palette.SERIE.lightened(0.2), Palette.CRITIQUE]
	for i in 3:
		var support := Node3D.new()
		support.position = Vector3(21.0, 2.0 + i * 0.6, -10.0)
		var a := Decor.anneau(7.5 + i * 2.4, 0.28, couleurs[i], 1.15 - i * 0.25)
		support.add_child(a)
		monde().add_child(support)
		_anneaux.append(support)

	var noyau := Decor.sphere(3.0, Palette.SERIE)
	noyau.material_override = Decor.matiere_lumineuse(Palette.SERIE, 0.7, 0.8)
	noyau.position = Vector3(21.0, 2.6, -10.0)
	monde().add_child(noyau)

func _process(delta: float) -> void:
	_t += delta
	for i in _anneaux.size():
		var n := _anneaux[i]
		n.rotation.y = _t * (0.35 + i * 0.22)
		n.rotation.x = deg_to_rad(78.0) + sin(_t * 0.5 + i) * 0.12

func _rafraichir() -> void:
	_rafraichir_portraits()
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
