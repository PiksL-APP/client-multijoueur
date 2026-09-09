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

## Le vrai lettrage du jeu, détouré sur fond transparent (lettres blanches,
## liseré noir compris) : la police pixel de la maison ne sait pas le dessiner,
## et une approximation à côté de la jaquette se serait vue tout de suite.
const VITRINE := "PIKSTOWN"         ## le code de ville montré au menu — et son nom
const CREPUSCULE := 0.50            ## 0 plein jour, 1 nuit noire — 0,5 est le couchant
## Côté du carré de morceaux bâtis. Cinq sur cinq, soit mille unités : à trois,
## la ville s'arrêtait net avant l'horizon et on voyait la couture entre le sol
## et le ciel. Bâtir les vingt-cinq coûte moins d'un dixième de seconde — ce
## sont des morceaux statiques, sans voitures ni passants à animer.
const MORCEAUX_LARGE := 5
const HAUTEUR := 54.0               ## altitude de la caméra, en unités monde
const RECUL := 168.0
const TOUR := 150.0                 ## secondes pour un tour complet

## Les entrées, dans l'ordre. `ecran` vide = traitement particulier.
const ENTREES := [
	{"cle": "commencer", "libelle": "Commencer", "aide": "Choisir son pseudo et son personnage"},
	{"cle": "options", "libelle": "Options", "aide": "Affichage, son et commandes"},
	{"cle": "quitter", "libelle": "Quitter", "aide": "Retour au bureau"},
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
var _a_batir: Array = []            ## [distance², clé de morceau], du plus proche au plus loin
var _total_a_batir := 0
var _tuile0 := Vector2i.ZERO        ## coin du carré bâti, en tuiles
var _voile: VoileChargement
var _fondu := 0.0                   ## 0 pendant le chargement, 1 quand le menu est là
var _t := 0.0
var _choix := 0
var _boutons: Array[Button] = []
var _marques: Array[ColorRect] = []
var _aide: Label
var _etat: HBoxContainer

func demarrer() -> void:
	_preparer_la_ville()
	_poser_l_interface()
	# L'interface attend derrière l'écran de chargement : montée tout de suite
	# mais invisible, elle est prête à l'instant où la ville l'est.
	interface().visible = false
	_voile = VoileChargement.poser(self)
	# L'effet maquette, plus appuyé qu'en jeu : bande nette resserrée sur les
	# entrées, flou épais en haut (le ciel) et en bas (le premier plan). C'est
	# lui qui fait passer la ville pour une maquette sous vitrine.
	_maquette = Maquette.poser(self, 0.62, 14.0)
	if _maquette != null:
		_maquette.regler("nettete", 0.09)
		_maquette.regler("fondu", 0.30)
		_maquette.regler("saturation", 1.24)
	Sons.musique(Sons.THEME)
	Reseau.etat_change.connect(func(_e): _rafraichir())
	_rafraichir()

# ── Le fond ────────────────────────────────────────────────────────────────

## Ce qui ne coûte rien : le plan, le ciel, la caméra. Les vingt-cinq morceaux,
## eux, sont mis en FILE et bâtis un par image — vingt-cinq morceaux d'un bloc,
## c'est une seconde de fenêtre gelée avant le premier dessin, et un joueur ne
## sait pas si ça charge ou si ça a planté.
func _preparer_la_ville() -> void:
	_carte = PlanVille.new(VITRINE)
	_ambiance = MatieresCarnage.ambiance()
	for noeud in _ambiance:
		monde().add_child(noeud)
	# Le crépuscule du menu ne dépend pas de l'heure qu'il est : c'est une
	# lumière choisie, celle où le néon commence à porter et où le béton
	# passe à l'orange. On la règle sans toucher `nuit_forcee`, qui appartient
	# au jeu.
	MatieresCarnage.regler_heure(_ambiance[0], _ambiance[1], _ambiance[2], heure())
	# Et une brume plus épaisse qu'en jeu : c'est elle qui noie le dernier
	# rang d'immeubles dans l'horizon, pour qu'aucune arête ne trahisse le
	# bord du monde. En jeu on veut voir loin ; ici on veut voir beau.
	var air: Environment = (_ambiance[0] as WorldEnvironment).environment
	air.fog_density = 0.0026
	# Un peu de brume dans le ciel, pas plus : à 1, elle repeignait toute la
	# voûte de sa couleur et le couchant disparaissait sous un lavis uni.
	air.fog_sky_affect = 0.45

	# La voûte elle-même s'adoucit : sol et horizon presque de la même teinte,
	# et la courbe étalée, pour qu'aucune bande ne se dessine.
	var ciel := ((_ambiance[0] as WorldEnvironment).environment.sky.sky_material) as ProceduralSkyMaterial
	# LE TRAIT À L'HORIZON venait de la voûte elle-même : sa moitié basse a sa
	# propre couleur (un gris violacé) et la rencontre avec le ciel orange se
	# lisait comme une ligne tracée à la règle. On lui donne EXACTEMENT la
	# couleur de l'horizon, puis on la laisse descendre vers le sombre : plus
	# aucune arête, et le couchant garde sa chaleur.
	# La courbe reste celle du jeu : à 0,16 l'orange de l'horizon montait
	# jusqu'en haut du cadre et le ciel perdait son bleu de nuit.
	ciel.sky_curve = 0.10
	ciel.ground_horizon_color = ciel.sky_horizon_color
	ciel.ground_bottom_color = ciel.sky_horizon_color.darkened(0.72)
	ciel.ground_curve = 0.55
	var sol := MatieresCarnage.sol()
	sol.set_shader_parameter("rail", _carte.rail())
	sol.set_shader_parameter("lignes", _carte.lignes_libres())
	sol.set_shader_parameter("origines", _carte.origines_libres())
	sol.set_shader_parameter("anneaux", _carte.anneaux_libres())
	sol.set_shader_parameter("etoiles", _carte.etoiles_libres())

	# On se place au cœur de la ville : c'est là que les tours sont hautes.
	# Le carré est CENTRÉ sur ce cœur, il n'en part pas : bâti vers le sud-est,
	# la caméra visait un morceau et demi plus loin et tombait sur la banlieue
	# ou sur l'eau selon le code de la ville.
	var centre_tuiles := Vector2i(PlanVille.COLONNES / 2, PlanVille.LIGNES / 2)
	var m0 := Vector2i(centre_tuiles.x / PlanVille.MORCEAU, centre_tuiles.y / PlanVille.MORCEAU) \
		- Vector2i.ONE * (MORCEAUX_LARGE / 2)
	# Du plus proche du centre au plus lointain : ce qu'on voit d'abord se
	# remplit d'abord, et le fond arrive pendant qu'on regarde déjà le titre.
	var milieu := Vector2(MORCEAUX_LARGE - 1, MORCEAUX_LARGE - 1) * 0.5
	for j in MORCEAUX_LARGE:
		for i in MORCEAUX_LARGE:
			_a_batir.append([Vector2(i, j).distance_squared_to(milieu), m0 + Vector2i(i, j)])
	_a_batir.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	_total_a_batir = _a_batir.size()

	_tuile0 = m0 * PlanVille.MORCEAU
	var cote := PlanVille.MORCEAU * PlanVille.PAS
	_centre = Vector2(m0) * cote + Vector2.ONE * cote * MORCEAUX_LARGE * 0.5

	_camera = Camera3D.new()
	_camera.fov = 44.0
	_camera.near = 0.5
	# La ville fait mille unités de côté : à neuf cents, le plan lointain
	# était coupé net au milieu des toits.
	_camera.far = 1800.0
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

## Une image de chantier : UN morceau bâti, la barre du voile avancée.
## Renvoie vrai quand il ne reste rien à faire.
func _avancer_le_chantier() -> bool:
	if _a_batir.is_empty():
		return true
	var cle: Vector2i = _a_batir.pop_front()[1]
	var morceau := MorceauVille.new()
	monde().add_child(morceau)
	morceau.batir(_carte, cle, {}, {})
	_chantiers.append(morceau)
	if _voile != null and is_instance_valid(_voile):
		_voile.avancer(1.0 - float(_a_batir.size()) / float(maxi(1, _total_a_batir)))
	return _a_batir.is_empty()

# ── La ville vit ───────────────────────────────────────────────────────────
#
# Les morceaux bâtis sont un décor mort : leurs voitures dorment dans une
# nappe, leurs habitants n'existent pas. On y met donc NOTRE circulation, plus
# simple que celle du jeu et taillée pour être vue de très haut : des voitures
# qui suivent les axes de la trame et des passants qui longent les trottoirs.
# Personne ne s'arrête, personne ne se croise — à cette distance ça ne se voit
# pas, et une vraie simulation coûterait le prix du jeu pour un fond de menu.

const VOITURES := 34
const PASSANTS := 16
const RAYON_VIE := 190.0            ## on ne peuple que ce que la caméra survole

var _circulation: Array = []        ## {n: Node3D, p: Vector2, d: Vector2, v: float, marche: bool}

## L'axe de rue le plus proche d'une coordonnée, en unités monde. La trame fait
## cinq tuiles : deux de chaussée, trois de pâté. Le milieu de la chaussée
## tombe donc sur (5k + 1) tuiles.
func _axe_de_rue(k: int) -> float:
	return float((_tuile0.x / PlanVille.PERIODE + k) * PlanVille.PERIODE + 1) * PlanVille.TUILE

func _axe_de_rue_z(k: int) -> float:
	return float((_tuile0.y / PlanVille.PERIODE + k) * PlanVille.PERIODE + 1) * PlanVille.TUILE

func _peupler_la_ville() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(VITRINE)
	var vise := Decor.vers3d(_centre, 0.0)
	# Combien d'axes de rue tiennent dans le rayon peuplé, de part et d'autre.
	var portee := int(RAYON_VIE / (PlanVille.PERIODE * PlanVille.TUILE))
	var gabarits: Array = FormesCarnage.KENNEY_VOITURES.keys()

	for i in VOITURES:
		var vertical := i % 2 == 0
		var k := rng.randi_range(-portee, portee)
		var sens := 1.0 if rng.randf() < 0.5 else -1.0
		# Une voie de chaque côté de l'axe, et on roule à droite.
		var voie := 2.6 * sens
		var depart := rng.randf_range(-RAYON_VIE, RAYON_VIE)
		var p: Vector2
		var d: Vector2
		if vertical:
			p = Vector2(_axe_de_rue(k) - vise.x + voie, depart)
			d = Vector2(0, sens)
		else:
			p = Vector2(depart, _axe_de_rue_z(k) - vise.z - voie)
			d = Vector2(sens, 0)

		var indice: int = gabarits[rng.randi() % gabarits.size()]
		var auto := MeshInstance3D.new()
		auto.mesh = FormesCarnage.maillage_voiture(indice)
		auto.material_override = FormesCarnage.matiere_kenney(FormesCarnage.modele_kenney_de(indice))
		monde().add_child(auto)
		_circulation.append({"n": auto, "p": p, "d": d, "v": rng.randf_range(9.0, 17.0),
			"marche": false, "centre": Vector2(vise.x, vise.z)})

	for i in PASSANTS:
		var vertical := i % 2 == 0
		var k := rng.randi_range(-portee, portee)
		var sens := 1.0 if rng.randf() < 0.5 else -1.0
		# Le trottoir : au bord de la chaussée, contre les façades.
		var bord := 7.5 * (1.0 if rng.randf() < 0.5 else -1.0)
		var depart := rng.randf_range(-RAYON_VIE, RAYON_VIE)
		var p: Vector2
		var d: Vector2
		if vertical:
			p = Vector2(_axe_de_rue(k) - vise.x + bord, depart)
			d = Vector2(0, sens)
		else:
			p = Vector2(depart, _axe_de_rue_z(k) - vise.z + bord)
			d = Vector2(sens, 0)
		var peau: String = FormesCarnage.PEAUX_CIVILES[rng.randi() % FormesCarnage.PEAUX_CIVILES.size()]
		# Un support qui porte le cap : la silhouette a déjà sa propre rotation
		# pour regarder vers +X, on ne la lui reprend pas.
		var support := Node3D.new()
		support.add_child(FormesCarnage.silhouette_kenney(peau))
		monde().add_child(support)
		_circulation.append({"n": support, "p": p, "d": d, "v": rng.randf_range(1.4, 2.2),
			"marche": true, "centre": Vector2(vise.x, vise.z)})

	for fiche in _circulation:
		_animer_kenney_si_besoin(fiche)

func _animer_kenney_si_besoin(fiche: Dictionary) -> void:
	if not bool(fiche["marche"]):
		return
	var support: Node3D = fiche["n"]
	if support.get_child_count() > 0:
		FormesCarnage.animer_kenney(support.get_child(0) as Node3D, true)

## Chacun avance tout droit et REVIENT de l'autre côté quand il sort du rayon
## peuplé : un bouclage, pas un demi-tour. Vu d'aussi haut, la boucle ne se
## remarque pas ; un demi-tour, si.
func _animer_la_circulation(delta: float) -> void:
	for fiche in _circulation:
		var noeud: Node3D = fiche["n"]
		if not is_instance_valid(noeud):
			continue
		var p: Vector2 = fiche["p"] + fiche["d"] * float(fiche["v"]) * delta
		if absf(p.x) > RAYON_VIE:
			p.x = -signf(p.x) * RAYON_VIE
		if absf(p.y) > RAYON_VIE:
			p.y = -signf(p.y) * RAYON_VIE
		fiche["p"] = p
		var c: Vector2 = fiche["centre"]
		noeud.position = Vector3(c.x + p.x, 0.0, c.y + p.y)
		# Le maillage regarde +X : un cap vers +Z est un quart de tour négatif.
		noeud.rotation.y = atan2(-float(fiche["d"].y), float(fiche["d"].x))

# ── L'interface ────────────────────────────────────────────────────────────

func _poser_l_interface() -> void:
	var couche := interface()

	# Un voile sombre au bas de l'écran, comme sur la maquette : il porte le
	# pied de page et détache les entrées des toits qui défilent dessous.
	var degrade := GradientTexture2D.new()
	degrade.fill_from = Vector2(0, 0)
	degrade.fill_to = Vector2(0, 1)
	var couleurs := Gradient.new()
	couleurs.offsets = PackedFloat32Array([0.0, 0.32, 0.62, 1.0])
	couleurs.colors = PackedColorArray([Color(Charte.NUIT, 0.55), Color(Charte.NUIT, 0.10),
		Color(Charte.NUIT, 0.38), Color(Charte.NUIT, 0.88)])
	degrade.gradient = couleurs
	var fond := TextureRect.new()
	fond.texture = degrade
	fond.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fond.stretch_mode = TextureRect.STRETCH_SCALE
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	couche.add_child(fond)

	# Le même en-tête que pendant le chargement : c'est le seul élément que la
	# maquette garde d'un écran à l'autre.
	Charte.entete_pikstown(couche)

	# La boîte : au bord gauche, à mi-hauteur, un peu remontée.
	var boite := VBoxContainer.new()
	boite.add_theme_constant_override("separation", 14)
	boite.position = Vector2(Charte.serre(24, 5.0, 90), 0)
	boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	couche.add_child(boite)
	boite.add_child(_boite_du_jeu())
	var legende := Charte.capitales("Cliquer pour retourner",
		Charte.serre(9, 0.9, 13), Color(1, 1, 1, 0.38), 0.24, 0)
	legende.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boite.add_child(legende)
	# À mi-hauteur, remontée de quarante-deux pour cent de sa propre taille,
	# comme le `translateY(-42%)` de la maquette.
	boite.resized.connect(func() -> void:
		boite.position.y = couche.get_viewport().get_visible_rect().size.y * 0.5 - boite.size.y * 0.42)

	# Les entrées, CENTRÉES dans l'écran.
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	couche.add_child(centre)

	var colonne := VBoxContainer.new()
	colonne.alignment = BoxContainer.ALIGNMENT_CENTER
	colonne.add_theme_constant_override("separation", Charte.serre(6, 0.8, 14))
	centre.add_child(colonne)

	for i in ENTREES.size():
		var b := _entree(String(ENTREES[i]["libelle"]), i)
		colonne.add_child(b)
		_boutons.append(b)

	var espace := Control.new()
	espace.custom_minimum_size = Vector2(0, Charte.serre(14, 1.6, 26))
	colonne.add_child(espace)

	# L'aide sous les entrées : en bas de casse, pas en capitales, et décalée
	# de la largeur du losange pour s'aligner sur les libellés.
	_aide = Charte.texte("", Charte.serre(13, 1.25, 19), Color(1, 1, 1, 0.62))
	_aide.add_theme_constant_override("font_spacing_glyph", 2)
	_aide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(_aide)

	var marge: int = Charte.serre(18, 2.6, 42)
	var bas := HBoxContainer.new()
	bas.add_theme_constant_override("separation", Charte.serre(16, 2.4, 44))
	bas.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bas.offset_left = marge
	bas.offset_right = -marge
	bas.offset_top = -marge - 20
	bas.offset_bottom = -marge
	couche.add_child(bas)
	var taille: int = Charte.serre(10, 0.95, 14)
	_etat = Charte.etat_reseau()
	bas.add_child(_etat)
	bas.add_child(Charte.capitales("Version " + Config.version, taille, Color(1, 1, 1, 0.42), 0.22))
	bas.add_child(Charte.capitales("Haut / Bas pour choisir · Entrée pour valider",
		taille, Color(1, 1, 1, 0.42), 0.22))

## La pochette du jeu, dans sa boîte, posée à gauche du menu.
##
## Une vraie boîte en 3D plutôt qu'une image inclinée en 2D : la tranche
## attrape la lumière, l'épaisseur se voit au coin, et la boîte se balance
## doucement — c'est ce mouvement qui fait qu'on la lit comme un objet posé
## là et non comme un cartouche d'interface. Elle vit dans sa propre petite
## fenêtre 3D, au fond transparent, pour ne pas se mêler à la ville.
const POCHETTE := "res://images/pochette.jpg"
const POCHETTE_DOS := "res://images/pochette-dos.jpg"
## Un boîtier de jeu. Le rapport 1 : 1,45 est celui auquel les DEUX jaquettes
## sont calées (l'affiche est plus élancée, le dos plus trapu) : les caler à
## la même forme, avec une bande sombre là où il en manque, vaut mieux que de
## les étirer chacune à la sienne — un dos déformé de douze pour cent se voit.
const BOITE := Vector3(1.34, 1.94, 0.26)
## Les dimensions de la maquette : dix-sept pour cent de la largeur de la
## fenêtre, dans un rapport de 0,7 sur 1 comme un vrai boîtier.
const RAPPORT_BOITE := 0.7

func _boite_du_jeu() -> SubViewportContainer:
	var cadre := SubViewportContainer.new()
	cadre.stretch = true
	var large: float = Charte.serre(150, 17.0, 300)
	cadre.custom_minimum_size = Vector2(large, large / RAPPORT_BOITE)
	# La boîte se retourne au survol : il lui faut donc les événements de
	# souris, que le reste de l'habillage laisse passer.
	cadre.mouse_filter = Control.MOUSE_FILTER_STOP
	cadre.mouse_entered.connect(func(): _retournee = true)
	cadre.mouse_exited.connect(func(): _retournee = false)
	# `--pochette-dos` : forcer le demi-tour, pour photographier le dos au banc
	# — une ligne de commande ne survole rien.
	if "--pochette-dos" in OS.get_cmdline_args():
		_retournee = true
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

	# UNE seule source, blanche et douce, et rien d'autre : elle ne sert qu'à
	# détacher la tranche du boîtier. La lueur rose du couchant qu'on y avait
	# mise glissait un reflet coloré sur la jaquette — or une jaquette se
	# regarde, elle ne brille pas.
	var douce := DirectionalLight3D.new()
	douce.rotation_degrees = Vector3(-22, -30, 0)
	douce.light_color = Color("#ffffff")
	douce.light_energy = 1.0
	douce.shadow_enabled = false
	fenetre.add_child(douce)

	_boite = Node3D.new()
	fenetre.add_child(_boite)

	# Le corps du boîtier : plastique sombre, un peu brillant sur la tranche.
	var corps := MeshInstance3D.new()
	var volume := BoxMesh.new()
	volume.size = BOITE
	corps.mesh = volume
	# Noir mat : les tranches d'un boîtier de jeu sont noires, et un plastique
	# brillant renverrait la ville sur les côtés de l'affiche.
	var plastique := StandardMaterial3D.new()
	plastique.albedo_color = Color.BLACK
	plastique.roughness = 1.0
	plastique.metallic = 0.0
	plastique.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	corps.material_override = plastique
	_boite.add_child(corps)

	# La jaquette : un quad plaqué juste devant la face avant. La boîte n'en
	# porte pas la texture directement — un BoxMesh replie les six faces sur
	# le même carré d'UV, et l'affiche se retrouverait aussi sur la tranche.
	var jaquette := MeshInstance3D.new()
	var carte := QuadMesh.new()
	carte.size = Vector2(BOITE.x * 0.96, BOITE.y * 0.97)
	jaquette.mesh = carte
	jaquette.position = Vector3(0, 0, BOITE.z * 0.5 + 0.002)
	# Non éclairée : l'affiche s'affiche telle qu'elle est, sans reflet ni
	# ombre portée qui en changerait les couleurs.
	var papier := StandardMaterial3D.new()
	papier.albedo_texture = load(POCHETTE)
	papier.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	papier.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	jaquette.material_override = papier
	_boite.add_child(jaquette)

	# Le dos, sur l'autre face : les vues du jeu, le texte de jaquette et le
	# code-barres. Un quad retourné d'un demi-tour — sans quoi on le verrait
	# en miroir.
	var dos := MeshInstance3D.new()
	dos.mesh = carte
	dos.position = Vector3(0, 0, -BOITE.z * 0.5 - 0.002)
	dos.rotation_degrees = Vector3(0, 180, 0)
	var verso := StandardMaterial3D.new()
	verso.albedo_texture = load(POCHETTE_DOS)
	verso.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	verso.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	dos.material_override = verso
	_boite.add_child(dos)

	var camera := Camera3D.new()
	camera.fov = 36.0
	fenetre.add_child(camera)
	# Assez près pour que le boîtier remplisse presque la hauteur du panneau :
	# la caméra garde la hauteur (`KEEP_HEIGHT`), donc la boîte grandit avec
	# le panneau et jamais avec sa largeur.
	# Pas de `look_at` : la caméra n'est pas encore DANS l'arbre à cet
	# instant (la fenêtre est rendue puis ajoutée par l'appelant), et
	# `look_at` s'en plaint. Posée sur l'axe, elle vise déjà le centre.
	camera.position = Vector3(0, 0, 3.8)
	return cadre

var _boite: Node3D
var _retournee := false
var _demi_tour := 0.0

## La charte de Pikstown, celle de la jaquette et de l'écran de chargement :
## rose néon, cyan, orange pour ce qui est élu, violet pour les dégradés.
const ROSE := Charte.ROSE
const ORANGE := Charte.ORANGE
const VERT := Charte.VERT

## Une entrée de menu : pas un bouton d'arcade encadré, mais un grand libellé
## nu qui s'allume au survol. Le cadre du reste du jeu écraserait la ville
## derrière ; ici c'est elle le sujet.
func _entree(libelle: String, indice: int) -> Button:
	var b := Button.new()
	b.text = libelle.to_upper()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", Charte.TITRE)
	b.add_theme_font_size_override("font_size", Charte.serre(26, 3.0, 52))
	# Cerné de noir, comme le titre : le fond bouge, et une entrée qui passe
	# sur un toit clair doit rester lisible sans qu'on ait à assombrir la
	# ville.
	b.add_theme_color_override("font_outline_color", Color("#120a18"))
	b.add_theme_constant_override("outline_size", 10)
	# Assez large pour la plus longue entrée, et haut d'une ligne et demie.
	b.custom_minimum_size = Vector2(0, Charte.serre(26, 3.0, 52) * 1.35)
	b.mouse_entered.connect(func() -> void: _viser(indice))
	# Le curseur était un « ◆ » posé dans le libellé : la police de titre est
	# une police pixel qui n'a pas ce caractère, et le moteur affichait le
	# rectangle du caractère manquant. On le dessine plutôt qu'on ne l'écrit.
	var marque := ColorRect.new()
	marque.color = ORANGE
	marque.size = Vector2(14, 14)
	marque.pivot_offset = Vector2(7, 7)
	marque.rotation = PI * 0.25
	marque.position = Vector2(0, 0)
	# Le losange se recale sur la hauteur du bouton dès qu'elle est connue.
	b.resized.connect(func() -> void:
		marque.position = Vector2(0, (b.size.y - 14.0) * 0.5))
	marque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(marque)
	_marques.append(marque)
	b.pressed.connect(func() -> void:
		_viser(indice)
		_valider())
	# Le survol de la boîte ne doit pas sonner : elle n'est pas un choix.

	return b

## `vers` dit dans quel sens on s'est déplacé : le son monte ou descend avec
## le curseur. Un seul « clic » pour les deux, et la liste perd son relief.
## Un libellé en capitales espacées, cerné de noir : la signature typographique
## de la maquette, et la seule qui tienne sur une ville qui défile.
func _capitales(texte: String, taille: int, couleur: Color) -> Label:
	return Charte.capitales(texte, taille, couleur)

func _viser(indice: int, vers: int = 0) -> void:
	var vise := posmod(indice, ENTREES.size())
	if vise == _choix:
		return
	_choix = vise
	Sons.interface("bas" if vers > 0 else ("haut" if vers < 0 else "droite"), -10.0)
	_rafraichir()

func _rafraichir() -> void:
	Charte.rafraichir_etat(_etat)
	for i in _boutons.size():
		var b := _boutons[i]
		var elu := i == _choix
		# Le losange en tête d'entrée sert de curseur : sur un fond qui bouge,
		# une simple couleur de texte ne se repère pas assez vite.
		b.text = "   " + String(ENTREES[i]["libelle"]).to_upper()
		b.add_theme_constant_override("outline_size", 10 if elu else 8)
		_marques[i].visible = elu
		var teinte: Color = ORANGE if elu else Color(1, 1, 1, 0.62)
		for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(etat, teinte)
	_aide.text = String(ENTREES[_choix]["aide"])

func _valider() -> void:
	Sons.interface("valider", -5.0)
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
	# Tant que la ville se bâtit, le menu n'existe pas encore : une image de
	# chantier, et rien d'autre. La caméra tourne quand même — le fond bouge
	# derrière le voile, et c'est ce qui se découvre au fondu.
	# `--chargement` : garder l'écran de chargement à l'image, pour le
	# photographier au banc — il ne dure qu'une poignée d'images en vrai.
	if "--chargement" in OS.get_cmdline_args():
		_t += delta
		_placer_la_camera(_t)
		if _voile != null and is_instance_valid(_voile):
			_voile.avancer(fmod(_t * 0.12, 1.0))
		return
	if not _a_batir.is_empty():
		_t += delta
		_placer_la_camera(_t)
		if _avancer_le_chantier():
			_peupler_la_ville()
		return
	if _fondu < 1.0:
		_fondu = minf(1.0, _fondu + delta * 1.4)
		interface().visible = true
		if _voile != null and is_instance_valid(_voile):
			_voile.effacer()
			_voile = null

	_t += delta
	_placer_la_camera(_t)
	_animer_la_circulation(delta)
	# Le boîtier se balance sur trois quarts, sans jamais se retourner : on
	# doit pouvoir lire l'affiche à tout instant.
	if _boite != null and is_instance_valid(_boite):
		# Au survol, le boîtier fait un demi-tour et montre son dos. La
		# rotation est amortie plutôt que commutée : une boîte qui se retourne
		# d'un coup se lit comme un changement d'image, pas comme un objet
		# qu'on retourne dans la main.
		_demi_tour = move_toward(_demi_tour, 1.0 if _retournee else 0.0, delta * 2.4)
		var adouci := smoothstep(0.0, 1.0, _demi_tour)
		_boite.rotation.y = deg_to_rad(-22.0 + adouci * 202.0) + sin(_t * 0.42) * 0.16 * (1.0 - adouci)
		_boite.rotation.x = deg_to_rad(4.0) + sin(_t * 0.31 + 1.2) * 0.05
	# La ligne de netteté vise le bas de l'écran, là où la ville est proche :
	# le lointain reste dans le flou, et c'est lui qui fait la maquette.
	if _maquette != null:
		_maquette.viser(0.62)

func _input(evenement: InputEvent) -> void:
	var touche := evenement as InputEventKey
	if touche == null or not touche.pressed or touche.echo:
		return
	match touche.keycode:
		KEY_UP: _viser(_choix - 1, -1)
		KEY_DOWN: _viser(_choix + 1, 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: _valider()
		KEY_ESCAPE:
			Sons.interface("retour", -8.0)
			_viser(ENTREES.size() - 1)
