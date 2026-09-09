extends Ecran
## Les options : le son, l'image, les touches. Trois onglets, un seul écran.
##
## Tout se règle EN DIRECT : bouger le curseur du volume fait aussitôt sonner
## un bip au nouveau niveau, couper les ombres les fait disparaître de la ville
## qui tourne derrière. Un réglage qu'on ne peut pas entendre ni voir avant de
## valider ne se règle pas, il se devine.
##
## `donnees.retour` dit où revenir : « menu » d'ordinaire, mais on pourra
## rentrer ici depuis une partie sans se retrouver éjecté au menu.

var _retour := "menu"
var _onglets: TabContainer
var _en_attente := ""              ## action dont on attend la nouvelle touche
var _cases: Dictionary = {}        ## action -> Button

func demarrer() -> void:
	_retour = String(donnees.get("retour", "menu"))
	Sons.musique(Sons.THEME)
	_fond()

	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	for bord in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		marge.add_theme_constant_override(bord, 48)
	interface().add_child(marge)

	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 18)
	colonne.custom_minimum_size = Vector2(720, 0)
	colonne.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	marge.add_child(colonne)

	colonne.add_child(Charte.entete("Options", "Le son, l'image, les touches. Tout est gardé sur cette machine."))

	_onglets = TabContainer.new()
	_onglets.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_onglets.custom_minimum_size = Vector2(720, 400)
	colonne.add_child(_onglets)
	_onglets.add_theme_font_override("font", Charte.CAPITALES)
	_onglets.add_theme_font_size_override("font_size", 18)
	_onglets.add_theme_constant_override("font_spacing_glyph", 3)
	_onglets.add_child(_page_son())
	_onglets.add_child(_page_image())
	_onglets.add_child(_page_touches())
	_onglets.tab_changed.connect(func(_i: int) -> void: Sons.interface("droite", -10.0))
	# `--onglet=2` : ouvrir directement les touches, pour les photographier au
	# banc — on ne peut pas cliquer sur un onglet depuis une ligne de commande.
	for argument in OS.get_cmdline_args():
		if String(argument).begins_with("--onglet="):
			_onglets.current_tab = clampi(int(String(argument).substr(9)), 0, 2)

	var bas := HBoxContainer.new()
	bas.add_theme_constant_override("separation", 12)
	colonne.add_child(bas)
	var retour := Charte.bouton("Retour", true)
	retour.pressed.connect(_sortir)
	bas.add_child(retour)
	var defauts := Charte.bouton("Tout remettre à zéro")
	defauts.pressed.connect(_remettre_a_zero)
	bas.add_child(defauts)

# ── Son ────────────────────────────────────────────────────────────────────

func _page_son() -> Control:
	var boite := _page("Son")
	var page: VBoxContainer = _pages["Son"]
	page.add_child(_curseur("Volume général", Reglages.volume_general, 0.0, 1.0, func(v: float) -> void:
		Reglages.volume_general = v
		Reglages.appliquer_le_son()
		Reglages.ecrire()
		_gouter()))
	page.add_child(_curseur("Musique et ambiance", Reglages.volume_musique, 0.0, 1.0, func(v: float) -> void:
		Reglages.volume_musique = v
		Reglages.appliquer_le_son()
		Reglages.ecrire()))
	page.add_child(_curseur("Bruitages", Reglages.volume_effets, 0.0, 1.0, func(v: float) -> void:
		Reglages.volume_effets = v
		Reglages.appliquer_le_son()
		Reglages.ecrire()
		_gouter()))
	page.add_child(Charte.texte("Le volume se règle en direct : un bip sonne au niveau choisi dès qu'on lâche le curseur.", 16, Color(1, 1, 1, 0.5), true))
	return boite

var _dernier_gout := 0.0

## Un bip au niveau qu'on vient de choisir. Espacé : un curseur qu'on traîne
## déclenche une image sur deux, et cent bips par seconde font un bourdon.
func _gouter() -> void:
	var maintenant := Time.get_ticks_msec() / 1000.0
	if maintenant - _dernier_gout < 0.18:
		return
	_dernier_gout = maintenant
	Sons.interface("droite", -6.0)

# ── Image ──────────────────────────────────────────────────────────────────

func _page_image() -> Control:
	var boite := _page("Graphisme")
	var page: VBoxContainer = _pages["Graphisme"]
	page.add_child(_bascule("Effets d'image", Reglages.effets,
		"Le flou de bascule du menu, et le halo des néons dans Piks Theft Auto.",
		func(v: bool) -> void:
			Reglages.effets = v
			Reglages.ecrire()
			_refaire_le_fond()))
	page.add_child(_bascule("Ombres portées", Reglages.ombres,
		"Dans le menu comme en ville. Le premier réglage à couper si ça saccade.",
		func(v: bool) -> void:
			Reglages.ombres = v
			Reglages.ecrire()
			_refaire_le_fond()))
	page.add_child(_bascule("Plein écran", Reglages.plein_ecran, "",
		func(v: bool) -> void:
			Reglages.plein_ecran = v
			Reglages.appliquer_l_image()
			Reglages.ecrire()))
	# Les bornes du curseur passent AVANT la lambda : écrites après, la
	# parenthèse fermante se rattachait à `add_child` et le moteur voyait
	# `add_child(page, 0.5, 1.0)`.
	page.add_child(_curseur("Finesse du rendu", Reglages.finesse, 0.5, 1.0, func(v: float) -> void:
		Reglages.finesse = clampf(v, 0.5, 1.0)
		Reglages.appliquer_l_image()
		Reglages.ecrire()))
	page.add_child(Charte.texte("Baisser la finesse rend le jeu en plus petit puis agrandit l'image : deux fois moins de pixels à calculer, une netteté à peine entamée sur des voxels.", 16, Color(1, 1, 1, 0.5), true))
	return boite

# ── Touches ────────────────────────────────────────────────────────────────

func _page_touches() -> Control:
	var boite := _page("Touches")
	var page: VBoxContainer = _pages["Touches"]
	page.add_child(Charte.texte("Cliquez sur une touche puis appuyez sur la nouvelle. Elles valent pour Piks Theft Auto comme pour les parties courtes. Les flèches du clavier restent toujours actives pour se déplacer.", 16, Color(1, 1, 1, 0.5), true))
	# Dix actions ne tiennent pas dans la hauteur d'un onglet : la liste défile.
	var defilement := ScrollContainer.new()
	defilement.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(defilement)
	var grille := GridContainer.new()
	grille.columns = 2
	grille.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grille.add_theme_constant_override("h_separation", 18)
	grille.add_theme_constant_override("v_separation", 4)
	defilement.add_child(grille)
	for action in Reglages.LIBELLES:
		var etiquette := Charte.texte(String(Reglages.LIBELLES[action]), 18, Color(1, 1, 1, 0.78))
		etiquette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grille.add_child(etiquette)
		var b := Charte.bouton("")
		b.custom_minimum_size = Vector2(170, 34)
		b.pressed.connect(func(): _attendre(String(action)))
		grille.add_child(b)
		_cases[String(action)] = b
	var remise := Charte.bouton("Touches par défaut")
	remise.pressed.connect(func():
		Sons.interface("special", -8.0)
		Reglages.remettre_les_touches()
		_en_attente = ""
		_rafraichir_les_touches())
	page.add_child(remise)
	_rafraichir_les_touches()
	return boite

func _attendre(action: String) -> void:
	Sons.interface("frappe", -8.0)
	_en_attente = action
	_rafraichir_les_touches()

func _rafraichir_les_touches() -> void:
	for action in _cases:
		var b: Button = _cases[action]
		if action == _en_attente:
			b.text = "…"
			b.modulate = Charte.ORANGE
		else:
			b.text = Reglages.nom_de_touche(String(action))
			b.modulate = Color.WHITE

# ── Fabrique ───────────────────────────────────────────────────────────────

## Une page d'onglet. Le contenu vit dans une marge : posé nu dans le
## TabContainer, le premier libellé vient coller au filet de l'onglet et la
## page a l'air décadrée.
func _page(titre: String) -> MarginContainer:
	var boite := MarginContainer.new()
	boite.name = titre
	for bord in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		boite.add_theme_constant_override(bord, 22)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	boite.add_child(page)
	_pages[titre] = page
	return boite

## titre d'onglet -> la colonne où empiler les réglages
var _pages: Dictionary = {}

## Un curseur avec son libellé et sa valeur en clair. La valeur affichée n'est
## pas décorative : sans elle, « le son est-il à 40 ou à 60 ? » n'a pas de
## réponse, et on repasse trois fois sur le même réglage.
func _curseur(libelle: String, valeur: float, mini: float, maxi: float,
		action: Callable) -> VBoxContainer:
	var boite := VBoxContainer.new()
	boite.add_theme_constant_override("separation", 4)
	var ligne := HBoxContainer.new()
	var nom := Charte.texte(libelle, 19, Color.WHITE)
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ligne.add_child(nom)
	var chiffre := Charte.capitales("%d %%" % roundi(valeur * 100.0), 16, Charte.ORANGE, 0.08)
	ligne.add_child(chiffre)
	boite.add_child(ligne)
	var glissiere := HSlider.new()
	glissiere.min_value = mini
	glissiere.max_value = maxi
	glissiere.step = 0.05
	glissiere.value = valeur
	glissiere.custom_minimum_size = Vector2(0, 24)
	glissiere.value_changed.connect(func(v: float) -> void:
		chiffre.text = "%d %%" % roundi(v * 100.0)
		action.call(v))
	boite.add_child(glissiere)
	return boite

func _bascule(libelle: String, valeur: bool, aide: String, action: Callable) -> VBoxContainer:
	var boite := VBoxContainer.new()
	boite.add_theme_constant_override("separation", 2)
	var bouton := CheckButton.new()
	bouton.text = libelle
	bouton.button_pressed = valeur
	bouton.add_theme_font_override("font", Charte.COURANTE)
	bouton.add_theme_font_size_override("font_size", 19)
	bouton.toggled.connect(func(v: bool) -> void:
		Sons.interface("valider" if v else "retour", -10.0)
		action.call(v))
	boite.add_child(bouton)
	if aide != "":
		boite.add_child(Charte.texte(aide, 16, Color(1, 1, 1, 0.5), true))
	return boite

# ── Le fond ────────────────────────────────────────────────────────────────

var _ambiance: Array = []
var _maquette: Maquette
var _t := 0.0
var _camera: Camera3D
var _centre := Vector3.ZERO

## La même ville qu'au menu, au même crépuscule : les options ne sont pas un
## ailleurs. Un seul morceau bâti — la caméra ne bouge presque pas.
func _fond() -> void:
	var carte := PlanVille.new(MenuPrincipal.VITRINE)
	_ambiance = MatieresCarnage.ambiance()
	for noeud in _ambiance:
		monde().add_child(noeud)
	MatieresCarnage.regler_heure(_ambiance[0], _ambiance[1], _ambiance[2], MenuPrincipal.heure())
	var sol := MatieresCarnage.sol()
	sol.set_shader_parameter("rail", carte.rail())
	sol.set_shader_parameter("lignes", carte.lignes_libres())
	sol.set_shader_parameter("origines", carte.origines_libres())
	sol.set_shader_parameter("anneaux", carte.anneaux_libres())
	sol.set_shader_parameter("etoiles", carte.etoiles_libres())

	var m0 := Vector2i(PlanVille.COLONNES / 2 / PlanVille.MORCEAU, PlanVille.LIGNES / 2 / PlanVille.MORCEAU)
	var morceau := MorceauVille.new()
	monde().add_child(morceau)
	morceau.batir(carte, m0, {}, {})

	var cote := PlanVille.MORCEAU * PlanVille.PAS
	_centre = Decor.vers3d(Vector2(m0) * cote + Vector2.ONE * cote * 0.5, 0.0)
	_camera = Camera3D.new()
	_camera.fov = 42.0
	_camera.far = 900.0
	monde().add_child(_camera)
	_camera.make_current()
	_placer(0.0)

	_maquette = Maquette.poser(self, 0.5, 8.0)
	_maquette.regler("nettete", 0.03)
	_maquette.regler("fondu", 0.16)
	var voile := ColorRect.new()
	voile.color = Color(0.03, 0.02, 0.07, 0.7)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interface().add_child(voile)

func _placer(temps: float) -> void:
	var angle := 0.7 + temps * 0.012
	_camera.position = _centre + Vector3(sin(angle) * 96.0, 104.0, cos(angle) * 96.0)
	_camera.look_at(_centre + Vector3(0, 10.0, 0))

## Couper les ombres ou l'effet maquette doit se voir TOUT DE SUITE, sinon on
## ne sait pas ce qu'on vient de régler. On rebâtit donc le fond sur place.
func _refaire_le_fond() -> void:
	if _maquette != null and is_instance_valid(_maquette):
		_maquette.queue_free()
		_maquette = null
	for enfant in monde().get_children():
		enfant.queue_free()
	for enfant in interface().get_children():
		if enfant is ColorRect:
			enfant.queue_free()
	_ambiance.clear()
	_fond()
	# Le voile et la maquette viennent d'être ajoutés en fin de couche : ils
	# passeraient devant le panneau. On les remet dessous.
	for enfant in interface().get_children():
		if enfant is ColorRect:
			interface().move_child(enfant, 0)

func _process(delta: float) -> void:
	_t += delta
	if _camera != null and is_instance_valid(_camera):
		_placer(_t)

## Tout remettre à zéro : les volumes, l'image, les touches. On reconstruit
## l'écran plutôt que de remettre chaque contrôle à sa valeur — c'est le même
## résultat en trois lignes, et rien ne peut rester en arrière.
func _remettre_a_zero() -> void:
	Reglages.remettre_tout()
	Sons.interface("special", -8.0)
	demande_ecran.emit("options", {"retour": _retour})

func _sortir() -> void:
	Sons.interface("retour", -8.0)
	demande_ecran.emit(_retour, {})

func _input(evenement: InputEvent) -> void:
	var touche := evenement as InputEventKey
	if touche == null or not touche.pressed or touche.echo:
		return
	# Une touche en attente capte TOUT, échappement compris : c'est le seul
	# moyen d'attribuer Échap à une action, et d'éviter qu'un réglage en cours
	# ferme l'écran par surprise.
	if _en_attente != "":
		var code := touche.physical_keycode if touche.physical_keycode != 0 else touche.keycode
		Reglages.definir_touche(_en_attente, code)
		_en_attente = ""
		_rafraichir_les_touches()
		Sons.interface("special", -8.0)
		get_viewport().set_input_as_handled()
		return
	if touche.keycode == KEY_ESCAPE:
		_sortir()
