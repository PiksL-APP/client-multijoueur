extends Ecran
## « Commencer » : on se donne un nom, on se choisit une tête, on entre.
##
## Le personnage choisi occupe la moitié droite de l'écran, en grand, tourné
## de trois quarts et animé — pas une vignette de cent pixels. C'est lui qu'on
## va incarner pendant toute une soirée : il mérite qu'on le voie. La bande de
## portraits en bas sert à parcourir le casting, le grand modèle sert à
## décider.
##
## Le fond reprend la ville du menu, mais figée et floue : on est encore dans
## le même lieu, on n'a pas changé de logiciel.

const RANGEE := 6                   ## portraits par ligne dans la bande

var _champ: LineEdit
var _bouton: Button
var _avertissement: Label
var _nom_choisi: Label
var _lot: Label
var _etat: HBoxContainer

var _scene: SubViewport
var _modele: Node3D
var _support: Node3D
var _vignettes: Array[Button] = []
var _cle := ""
var _t := 0.0
var _courts: Array[Button] = []

func demarrer() -> void:
	_cle = Session.personnage_affiche()
	_fond()

	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	for bord in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		marge.add_theme_constant_override(bord, 40)
	interface().add_child(marge)

	var rangee := HBoxContainer.new()
	rangee.add_theme_constant_override("separation", 32)
	marge.add_child(rangee)

	# ── Colonne de gauche : l'identité ──────────────────────────────────
	var gauche := VBoxContainer.new()
	# La colonne doit tenir dans la hauteur de l'écran : si elle déborde, la
	# rangée grandit avec elle et emporte la fenêtre 3D hors du cadre — le
	# personnage se retrouve coupé aux genoux sans qu'on ait touché la caméra.
	gauche.add_theme_constant_override("separation", 9)
	gauche.custom_minimum_size = Vector2(460, 0)
	gauche.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(gauche)

	gauche.add_child(Charte.entete("Commencer", "Un nom, une tête de carton, et on descend."))

	gauche.add_child(Charte.capitales("Votre pseudo", 15, Color(1, 1, 1, 0.6)))
	_champ = Charte.champ("Puxian", Session.pseudo)
	_champ.text_submitted.connect(func(_x): _entrer())
	# Chaque frappe s'entend, comme sur une borne : c'est ce qui fait qu'un
	# champ de texte a du corps.
	_champ.text_changed.connect(func(_x) -> void:
		Sons.interface("frappe", -16.0)
		_rafraichir())
	gauche.add_child(_champ)

	gauche.add_child(Charte.capitales("Votre personnage", 15, Color(1, 1, 1, 0.6)))
	_nom_choisi = Charte.titre("", 26, Charte.ORANGE)
	gauche.add_child(_nom_choisi)
	_lot = Charte.capitales("", 13, Color(1, 1, 1, 0.5))
	gauche.add_child(_lot)
	gauche.add_child(_bande())

	_bouton = Charte.bouton("Entrer à Pikstown", true)
	_bouton.pressed.connect(_entrer)
	gauche.add_child(_bouton)

	# Les deux autres jeux, le temps que les bâtiments de la ville en ouvrent
	# les portes. Sans cette rangée, ils ne seraient plus joignables du tout
	# depuis que le village n'est plus sur le chemin.
	gauche.add_child(Charte.capitales("Ou une partie courte :", 14, Color(1, 1, 1, 0.5)))
	var courts := HBoxContainer.new()
	courts.add_theme_constant_override("separation", 10)
	gauche.add_child(courts)
	# `enigme-chambres` et non `enigme` : depuis la refonte, `enigme` mène à la
	# ferme, qui est un écran et non une partie — elle ne se termine jamais et
	# ne dépose aucun score. Les chambres, elles, se jouent.
	for jeu in [["enigme-chambres", "Énigme"], ["bousculade", "Bousculade"]]:
		var b := Charte.bouton(String(jeu[1]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _partir(String(jeu[0]), String(jeu[1])))
		courts.add_child(b)
		_courts.append(b)

	var retour := Charte.bouton("Retour au menu")
	retour.pressed.connect(func() -> void:
		Sons.interface("retour", -8.0)
		demande_ecran.emit("menu", {}))
	gauche.add_child(retour)

	_avertissement = Charte.texte("", 15, Charte.ORANGE, true)
	gauche.add_child(_avertissement)

	var bas := HBoxContainer.new()
	bas.add_theme_constant_override("separation", 12)
	gauche.add_child(bas)
	_etat = Charte.etat_reseau()
	bas.add_child(_etat)
	bas.add_child(Charte.capitales("Version " + Config.version, 13, Color(1, 1, 1, 0.42)))

	# ── Colonne de droite : le personnage en grand ──────────────────────
	rangee.add_child(_vitrine())

	# Le thème continue : `musique` compare au nom en cours et ne redémarre
	# rien, donc passer du menu à la création ne coupe pas le morceau.
	Sons.musique(Sons.THEME)
	Reseau.etat_change.connect(func(_e): _rafraichir())
	_champ.grab_focus()
	_rafraichir()

## La bande de portraits. Un bouton par personnage, tous à la même peau que
## le grand modèle — c'est la texture qui fait le portrait, on n'a donc rien
## à dessiner : on montre directement l'image de peau, recadrée sur le
## visage. Douze rendus 3D côte à côte coûteraient douze mondes.
func _bande() -> GridContainer:
	var grille := GridContainer.new()
	grille.columns = RANGEE
	grille.add_theme_constant_override("h_separation", 8)
	grille.add_theme_constant_override("v_separation", 8)
	for fiche in Personnages.LISTE:
		var cle := String(fiche["cle"])
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(66, 66)
		b.tooltip_text = String(fiche["nom"])
		b.pressed.connect(func(): _choisir(cle))
		var portrait := TextureRect.new()
		portrait.texture = Personnages.portrait(cle)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
		portrait.offset_left = 6
		portrait.offset_top = 6
		portrait.offset_right = -6
		portrait.offset_bottom = -6
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(portrait)
		b.set_meta("cle", cle)
		grille.add_child(b)
		_vignettes.append(b)
	return grille

## Le grand modèle, dans son propre monde : fond transparent, une lumière
## chaude de face et une froide de dos, caméra à hauteur de poitrine.
func _vitrine() -> SubViewportContainer:
	var cadre := SubViewportContainer.new()
	cadre.stretch = true
	cadre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cadre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene = SubViewport.new()
	_scene.transparent_bg = true
	_scene.own_world_3d = true
	_scene.msaa_3d = Viewport.MSAA_4X
	cadre.add_child(_scene)

	var environnement := Environment.new()
	environnement.background_mode = Environment.BG_COLOR
	environnement.background_color = Color(0, 0, 0, 0)
	environnement.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environnement.ambient_light_color = Color("#6d5f8a")
	environnement.ambient_light_energy = 0.9
	var monde_env := WorldEnvironment.new()
	monde_env.environment = environnement
	_scene.add_child(monde_env)

	var chaude := DirectionalLight3D.new()
	chaude.rotation_degrees = Vector3(-28, -38, 0)
	chaude.light_color = Color("#ffcf9a")
	chaude.light_energy = 1.5
	_scene.add_child(chaude)
	var froide := DirectionalLight3D.new()
	froide.rotation_degrees = Vector3(-14, 148, 0)
	froide.light_color = Color("#ff4f9a")
	froide.light_energy = 0.9
	froide.shadow_enabled = false
	_scene.add_child(froide)

	_support = Node3D.new()
	_scene.add_child(_support)
	_modele = Personnages.creer(_cle)
	_support.add_child(_modele)

	var camera := Camera3D.new()
	camera.fov = 34.0
	_scene.add_child(camera)
	# Cadrage pied-à-tête d'un bonhomme d'un mètre quatre-vingts, avec un peu
	# d'air au-dessus : la caméra vise la poitrine, pas les yeux, sinon les
	# pieds sortent du cadre dès qu'on l'anime.
	# L'inclinaison est posée à la main plutôt que par `look_at` : la caméra
	# n'est pas encore dans l'arbre ici, et `look_at` refuse de travailler.
	camera.position = Vector3(0, 1.05, 3.6)
	camera.rotation = Vector3(-atan2(1.05 - 0.92, 3.6), 0, 0)
	return cadre

func _fond() -> void:
	# La même ville qu'au menu, prise de très haut et immobile : un fond, pas
	# une scène. Bâtir un seul morceau suffit — le reste est hors champ.
	var carte := PlanVille.new(MenuPrincipal.VITRINE)
	var ambiance := MatieresCarnage.ambiance()
	for noeud in ambiance:
		monde().add_child(noeud)
	MatieresCarnage.regler_heure(ambiance[0], ambiance[1], ambiance[2], MenuPrincipal.heure())
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
	var centre := Decor.vers3d(Vector2(m0) * cote + Vector2.ONE * cote * 0.5, 0.0)
	var camera := Camera3D.new()
	camera.fov = 40.0
	camera.far = 900.0
	monde().add_child(camera)
	camera.position = centre + Vector3(70.0, 110.0, 70.0)
	camera.look_at(centre + Vector3(0, 10.0, 0))
	camera.make_current()

	# L'écran de création n'est pas une carte postale : le fond doit reculer.
	# Un flou franc et un voile sombre, et l'œil va au panneau.
	var maquette := Maquette.poser(self, 0.5, 9.0)
	maquette.regler("nettete", 0.02)
	maquette.regler("fondu", 0.14)
	var voile := ColorRect.new()
	voile.color = Color(0.03, 0.02, 0.07, 0.62)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interface().add_child(voile)

func _choisir(cle: String) -> void:
	if cle == _cle:
		return
	_cle = cle
	Session.definir_personnage(cle)
	Personnages.habiller(_modele, cle)
	Sons.interface("droite", -10.0)
	_rafraichir()

func _rafraichir() -> void:
	Charte.rafraichir_etat(_etat)
	var fiche := Personnages.fiche(_cle)
	_nom_choisi.text = String(fiche["nom"]).to_upper()
	_lot.text = "lot " + String(fiche["lot"])
	for b in _vignettes:
		var elu: bool = String(b.get_meta("cle")) == _cle
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.10) if elu else Color(0, 0, 0, 0.45)
		style.border_color = Charte.ORANGE if elu else Color(1, 1, 1, 0.14)
		style.set_border_width_all(2 if elu else 1)
		for etat in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(etat, style)
		b.modulate = Color.WHITE if elu else Color(1, 1, 1, 0.66)

	var pseudo := Session.nettoyer_pseudo(_champ.text)
	var pret := pseudo.length() >= 2 and Reseau.etat == Reseau.EN_LIGNE
	_bouton.disabled = not pret
	for b in _courts:
		b.disabled = not pret
	if not Config.est_configure():
		_avertissement.text = "Clés Supabase absentes : le multijoueur ne peut pas démarrer."
	elif pseudo.length() < 2:
		_avertissement.text = "Deux caractères au minimum."
	elif Reseau.etat != Reseau.EN_LIGNE:
		_avertissement.text = "Connexion au serveur temps réel…"
	else:
		_avertissement.text = ""

func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(_support):
		# Un va-et-vient plutôt qu'un tour complet : on garde toujours le
		# visage dans le champ, et c'est le visage qui distingue les douze.
		_support.rotation.y = sin(_t * 0.5) * 0.62

func _entrer() -> void:
	_partir("carnage", "Piks Theft Auto")

## On ne passe plus par le village : « Commencer » descend directement dans
## la ville, par le salon qui apparie les joueurs. C'est le sens du jeu
## maintenant — la ville EST le hub, ses bâtiments ouvriront les autres jeux.
func _partir(jeu: String, titre: String) -> void:
	var pseudo := Session.nettoyer_pseudo(_champ.text)
	if pseudo.length() < 2 or Reseau.etat != Reseau.EN_LIGNE:
		return
	Session.definir_pseudo(pseudo)
	Session.definir_personnage(_cle)
	Sons.interface("valider", -4.0)
	demande_ecran.emit("salon", {"jeu": jeu, "titre": titre.to_upper()})

func _input(evenement: InputEvent) -> void:
	var touche := evenement as InputEventKey
	if touche != null and touche.pressed and not touche.echo and touche.keycode == KEY_ESCAPE:
		Sons.interface("retour", -8.0)
		demande_ecran.emit("menu", {})
