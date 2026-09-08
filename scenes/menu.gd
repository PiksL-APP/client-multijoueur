class_name MenuPrincipal
extends Ecran
## Le menu d'entrée : Commencer, Options, Quitter, posés sur la ville.
##
## Le fond n'est pas une image ni un décor bâti pour l'occasion : c'est la
## VILLE DU JEU, le même générateur que Carnage, vue de haut et tournant
## lentement au crépuscule. C'est ce qui donne au menu son air de maquette
## sous vitrine — et ça garantit qu'il ne ment jamais sur ce qu'on va trouver
## derrière : quand la ville change, le menu change avec elle.
##
## Un code de manche fixe (`VITRINE`) : le menu montre toujours le même
## quartier, celui qui présente bien. Tirer au sort donnerait un jour un port
## désert, un jour un échangeur.

## Le titre, en trois lignes empilées comme sur l'affiche. Une seule ligne
## « PIKS THEFT AUTO » tiendrait en petit ou déborderait ; empilé, il occupe
## le tiers gauche de l'écran et laisse la ville respirer à droite.
const TITRE := ["PIKS", "THEFT", "AUTO"]

const VITRINE := "SUNPORT"          ## le code de ville montré au menu — et son nom
const CREPUSCULE := 0.50            ## 0 plein jour, 1 nuit noire — 0,5 est le couchant
const MORCEAUX_LARGE := 3           ## côté du carré bâti, pour tenir jusqu'à l'horizon
const HAUTEUR := 54.0               ## altitude de la caméra, en unités monde
const RECUL := 168.0
const TOUR := 150.0                 ## secondes pour un tour complet

## Les entrées, dans l'ordre. `ecran` vide = traitement particulier.
const ENTREES := [
	{"cle": "commencer", "libelle": "Commencer", "aide": "Choisir son pseudo et son personnage"},
	{"cle": "options", "libelle": "Options", "aide": "Son, image, touches du clavier"},
	{"cle": "quitter", "libelle": "Quitter", "aide": "Retour sur piks-l.com"},
]

const ADRESSE_SORTIE := "https://www.piks-l.com"

## L'heure du décor de menu. `--nuit=0.8` (ou `?nuit=0.8` dans l'adresse) la
## force, comme dans le jeu : c'est ainsi qu'on règle le couchant en photo
## sans recompiler.
static func heure() -> float:
	for argument in OS.get_cmdline_args():
		if String(argument).begins_with("--nuit="):
			return clampf(float(String(argument).substr(7)), 0.0, 1.0)
	return CREPUSCULE

var _carte: PlanVille
var _camera: Camera3D
var _maquette: Maquette
var _ambiance: Array = []
var _chantiers: Array[MorceauVille] = []
var _t := 0.0
var _choix := 0
var _boutons: Array[Button] = []
var _aide: Label
var _etat: HBoxContainer

func demarrer() -> void:
	_batir_la_ville()
	_poser_l_interface()
	_maquette = Maquette.poser(self, 0.66, 7.0)
	Reseau.etat_change.connect(func(_e): _rafraichir())
	_rafraichir()

# ── Le fond ────────────────────────────────────────────────────────────────

## La ville, bâtie d'un bloc au démarrage. Un carré de deux morceaux sur deux
## suffit : la caméra est haute, tourne sur un petit rayon, et le brouillard
## mange le bord avant qu'on l'atteigne. Bâtir plus coûterait une seconde
## d'attente pour des toits qu'on ne voit jamais.
func _batir_la_ville() -> void:
	_carte = PlanVille.new(VITRINE)
	_ambiance = MatieresCarnage.ambiance()
	for noeud in _ambiance:
		monde().add_child(noeud)
	# Le crépuscule du menu ne dépend pas de l'heure qu'il est : c'est une
	# lumière choisie, celle où le néon commence à porter et où le béton
	# passe à l'orange. On la règle sans toucher `nuit_forcee`, qui appartient
	# au jeu.
	MatieresCarnage.regler_heure(_ambiance[0], _ambiance[1], _ambiance[2], heure())
	var sol := MatieresCarnage.sol()
	sol.set_shader_parameter("rail", _carte.rail())
	sol.set_shader_parameter("lignes", _carte.lignes_libres())
	sol.set_shader_parameter("origines", _carte.origines_libres())
	sol.set_shader_parameter("anneaux", _carte.anneaux_libres())
	sol.set_shader_parameter("etoiles", _carte.etoiles_libres())

	# On se place au cœur de la ville : c'est là que les tours sont hautes.
	var centre_tuiles := Vector2i(PlanVille.COLONNES / 2, PlanVille.LIGNES / 2)
	var m0 := Vector2i(centre_tuiles.x / PlanVille.MORCEAU, centre_tuiles.y / PlanVille.MORCEAU)
	for j in MORCEAUX_LARGE:
		for i in MORCEAUX_LARGE:
			var morceau := MorceauVille.new()
			monde().add_child(morceau)
			morceau.batir(_carte, m0 + Vector2i(i, j), {}, {})
			_chantiers.append(morceau)

	var cote := PlanVille.MORCEAU * PlanVille.PAS
	_centre = Vector2(m0) * cote + Vector2.ONE * cote * MORCEAUX_LARGE * 0.5

	_camera = Camera3D.new()
	_camera.fov = 44.0
	_camera.near = 0.5
	_camera.far = 900.0
	monde().add_child(_camera)
	_camera.make_current()
	_placer_la_camera(0.0)

var _centre := Vector2.ZERO

## La caméra tourne autour du centre, très lentement, en plongée. Rien d'autre
## ne bouge : une ville figée qui tourne se lit comme une maquette posée sur
## un plateau, ce qui est exactement l'effet cherché.
func _placer_la_camera(temps: float) -> void:
	var angle := TAU * temps / TOUR
	var vise := Decor.vers3d(_centre, 0.0)
	_camera.position = vise + Vector3(sin(angle) * RECUL, HAUTEUR, cos(angle) * RECUL)
	# On vise AU-DESSUS du sol : la ligne d'horizon monte alors dans le cadre
	# et le ciel du couchant entre dans l'image. Viser le sol, comme au début,
	# donnait une vue à la verticale où la ville n'avait plus de ciel.
	_camera.look_at(vise + Vector3(0, 34.0, 0))

# ── L'interface ────────────────────────────────────────────────────────────

func _poser_l_interface() -> void:
	var couche := interface()

	# Un dégradé sombre le long du bord gauche : sans lui, un libellé clair
	# passe sur un toit clair et devient illisible une fois sur trois pendant
	# que la caméra tourne.
	var degrade := GradientTexture2D.new()
	degrade.fill = GradientTexture2D.FILL_LINEAR
	degrade.fill_from = Vector2(0, 0)
	# Le voile court jusqu'aux deux tiers de l'écran : depuis que la boîte
	# occupe la gauche, le menu s'est décalé vers le milieu, et un dégradé
	# qui s'arrêtait au quart laissait « OPTIONS » sur un toit blanc.
	degrade.fill_to = Vector2(0.72, 0)
	var couleurs := Gradient.new()
	couleurs.set_offset(0, 0.0)
	couleurs.set_color(0, Color(0.02, 0.01, 0.06, 0.92))
	couleurs.set_offset(1, 1.0)
	couleurs.set_color(1, Color(0.02, 0.01, 0.06, 0.0))
	degrade.gradient = couleurs
	var fond := TextureRect.new()
	fond.texture = degrade
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	couche.add_child(fond)

	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	marge.add_theme_constant_override("margin_left", 72)
	marge.add_theme_constant_override("margin_top", 56)
	marge.add_theme_constant_override("margin_bottom", 40)
	couche.add_child(marge)

	var rangee := HBoxContainer.new()
	rangee.alignment = BoxContainer.ALIGNMENT_BEGIN
	rangee.add_theme_constant_override("separation", 40)
	rangee.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	marge.add_child(rangee)
	rangee.add_child(_boite_du_jeu())

	var colonne := VBoxContainer.new()
	colonne.alignment = BoxContainer.ALIGNMENT_CENTER
	colonne.add_theme_constant_override("separation", 4)
	colonne.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(colonne)

	var surtitre := UI.texte("Piks-l · multijoueur", 15, ROSE)
	colonne.add_child(surtitre)
	# Le titre est cerné de noir : sur une ville qui tourne, un lettrage blanc
	# nu se perd dès qu'un toit clair passe dessous. C'est le contour qui le
	# tient, exactement comme sur l'affiche.
	var pile := VBoxContainer.new()
	pile.add_theme_constant_override("separation", -6)
	colonne.add_child(pile)
	for mot in TITRE:
		var ligne := UI.titre(String(mot), 56)
		ligne.add_theme_color_override("font_color", Color("#fffaf2"))
		ligne.add_theme_color_override("font_outline_color", Color("#120a18"))
		ligne.add_theme_constant_override("outline_size", 14)
		pile.add_child(ligne)
	var sous := UI.texte("Sunport City. La ville est le jeu — chaque bâtiment ouvre une partie.",
		17, Palette.ENCRE_DOUCE)
	sous.add_theme_color_override("font_outline_color", Color("#120a18"))
	sous.add_theme_constant_override("outline_size", 6)
	colonne.add_child(sous)

	var espace := Control.new()
	espace.custom_minimum_size = Vector2(0, 34)
	colonne.add_child(espace)

	for i in ENTREES.size():
		var b := _entree(String(ENTREES[i]["libelle"]), i)
		colonne.add_child(b)
		_boutons.append(b)

	var espace2 := Control.new()
	espace2.custom_minimum_size = Vector2(0, 22)
	colonne.add_child(espace2)
	_aide = UI.texte("", 15, Palette.ENCRE_DOUCE)
	_aide.add_theme_color_override("font_outline_color", Color("#120a18"))
	_aide.add_theme_constant_override("outline_size", 6)
	_aide.custom_minimum_size = Vector2(470, 0)
	colonne.add_child(_aide)

	var bas := HBoxContainer.new()
	bas.add_theme_constant_override("separation", 14)
	bas.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bas.offset_left = 72
	bas.offset_top = -46
	bas.offset_bottom = -18
	couche.add_child(bas)
	_etat = UI.etat_reseau()
	bas.add_child(_etat)
	bas.add_child(UI.texte("version " + Config.version, 13, Palette.ENCRE_FAIBLE))
	bas.add_child(UI.texte("↑ ↓ pour choisir · Entrée pour valider", 13, Palette.ENCRE_FAIBLE))

## La pochette du jeu, dans sa boîte, posée à gauche du menu.
##
## Une vraie boîte en 3D plutôt qu'une image inclinée en 2D : la tranche
## attrape la lumière, l'épaisseur se voit au coin, et la boîte se balance
## doucement — c'est ce mouvement qui fait qu'on la lit comme un objet posé
## là et non comme un cartouche d'interface. Elle vit dans sa propre petite
## fenêtre 3D, au fond transparent, pour ne pas se mêler à la ville.
const POCHETTE := "res://images/pochette.jpg"
const BOITE := Vector3(1.30, 1.96, 0.26)   ## un boîtier de jeu, en unités

func _boite_du_jeu() -> SubViewportContainer:
	var cadre := SubViewportContainer.new()
	cadre.stretch = true
	cadre.custom_minimum_size = Vector2(300, 430)
	cadre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fenetre := SubViewport.new()
	fenetre.transparent_bg = true
	fenetre.own_world_3d = true
	fenetre.msaa_3d = Viewport.MSAA_4X
	cadre.add_child(fenetre)

	var environnement := Environment.new()
	environnement.background_mode = Environment.BG_COLOR
	environnement.background_color = Color(0, 0, 0, 0)
	environnement.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environnement.ambient_light_color = Color("#4a3550")
	environnement.ambient_light_energy = 1.1
	var monde_env := WorldEnvironment.new()
	monde_env.environment = environnement
	fenetre.add_child(monde_env)

	# Deux sources, celles du couchant : chaude de face à droite, rose de
	# l'autre bord — la même lumière que sur la ville derrière.
	var chaude := DirectionalLight3D.new()
	chaude.rotation_degrees = Vector3(-26, -34, 0)
	chaude.light_color = Color("#ffcf9a")
	chaude.light_energy = 1.6
	chaude.shadow_enabled = false
	fenetre.add_child(chaude)
	var rose := DirectionalLight3D.new()
	rose.rotation_degrees = Vector3(-8, 128, 0)
	rose.light_color = ROSE
	rose.light_energy = 1.1
	rose.shadow_enabled = false
	fenetre.add_child(rose)

	_boite = Node3D.new()
	fenetre.add_child(_boite)

	# Le corps du boîtier : plastique sombre, un peu brillant sur la tranche.
	var corps := MeshInstance3D.new()
	var volume := BoxMesh.new()
	volume.size = BOITE
	corps.mesh = volume
	corps.material_override = Decor.matiere(Color("#14101c"), 0.42)
	_boite.add_child(corps)

	# La jaquette : un quad plaqué juste devant la face avant. La boîte n'en
	# porte pas la texture directement — un BoxMesh replie les six faces sur
	# le même carré d'UV, et l'affiche se retrouverait aussi sur la tranche.
	var jaquette := MeshInstance3D.new()
	var carte := QuadMesh.new()
	carte.size = Vector2(BOITE.x * 0.96, BOITE.y * 0.97)
	jaquette.mesh = carte
	jaquette.position = Vector3(0, 0, BOITE.z * 0.5 + 0.002)
	var papier := StandardMaterial3D.new()
	papier.albedo_texture = load(POCHETTE)
	papier.roughness = 0.55
	papier.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	jaquette.material_override = papier
	_boite.add_child(jaquette)

	var camera := Camera3D.new()
	camera.fov = 36.0
	fenetre.add_child(camera)
	camera.position = Vector3(0, 0, 4.6)
	camera.look_at(Vector3.ZERO)
	return cadre

var _boite: Node3D

const ROSE := Color("#ff4f9a")
const ORANGE := Color("#ffa441")

## Une entrée de menu : pas un bouton d'arcade encadré, mais un grand libellé
## nu qui s'allume au survol. Le cadre du reste du jeu écraserait la ville
## derrière ; ici c'est elle le sujet.
func _entree(libelle: String, indice: int) -> Button:
	var b := Button.new()
	b.text = libelle.to_upper()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", UI.TITRE_POLICE)
	b.add_theme_font_size_override("font_size", UI.taille_titre(24))
	# Cerné de noir, comme le titre : le fond bouge, et une entrée qui passe
	# sur un toit clair doit rester lisible sans qu'on ait à assombrir la
	# ville.
	b.add_theme_color_override("font_outline_color", Color("#120a18"))
	b.add_theme_constant_override("outline_size", 10)
	b.custom_minimum_size = Vector2(470, 58)
	b.mouse_entered.connect(func() -> void: _viser(indice))
	b.pressed.connect(func() -> void:
		_viser(indice)
		_valider())
	return b

func _viser(indice: int) -> void:
	var vise := posmod(indice, ENTREES.size())
	if vise == _choix:
		return
	_choix = vise
	Sons.jouer("clic", 1.0, -12.0)
	_rafraichir()

func _rafraichir() -> void:
	UI.rafraichir_etat_reseau(_etat)
	for i in _boutons.size():
		var b := _boutons[i]
		var elu := i == _choix
		# Le losange en tête d'entrée sert de curseur : sur un fond qui bouge,
		# une simple couleur de texte ne se repère pas assez vite.
		b.text = ("◆  " if elu else "    ") + String(ENTREES[i]["libelle"]).to_upper()
		var teinte := ORANGE if elu else Color(1, 1, 1, 0.62)
		for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(etat, teinte)
	_aide.text = String(ENTREES[_choix]["aide"])

func _valider() -> void:
	Sons.jouer("depart", 1.0, -8.0)
	match String(ENTREES[_choix]["cle"]):
		"commencer": demande_ecran.emit("creation", {})
		"options": demande_ecran.emit("options", {"retour": "menu"})
		"quitter": _quitter()

## Quitter, c'est retourner sur le site. Dans un navigateur on remplace
## l'adresse de l'onglet — `OS.shell_open` y ouvrirait une fenêtre que le
## bloqueur de publicités arrête une fois sur deux. Hors navigateur, c'est
## bien le navigateur système qu'on veut, puis on ferme.
func _quitter() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.href = '%s';" % ADRESSE_SORTIE, true)
		return
	OS.shell_open(ADRESSE_SORTIE)
	get_tree().quit()

func _process(delta: float) -> void:
	_t += delta
	_placer_la_camera(_t)
	# Le boîtier se balance sur trois quarts, sans jamais se retourner : on
	# doit pouvoir lire l'affiche à tout instant.
	if _boite != null and is_instance_valid(_boite):
		_boite.rotation.y = deg_to_rad(-22.0) + sin(_t * 0.42) * 0.16
		_boite.rotation.x = deg_to_rad(4.0) + sin(_t * 0.31 + 1.2) * 0.05
	# La ligne de netteté vise le bas de l'écran, là où la ville est proche :
	# le lointain reste dans le flou, et c'est lui qui fait la maquette.
	if _maquette != null:
		_maquette.viser(0.66)

func _input(evenement: InputEvent) -> void:
	var touche := evenement as InputEventKey
	if touche == null or not touche.pressed or touche.echo:
		return
	match touche.keycode:
		KEY_UP: _viser(_choix - 1)
		KEY_DOWN: _viser(_choix + 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: _valider()
		KEY_ESCAPE: _viser(ENTREES.size() - 1)
