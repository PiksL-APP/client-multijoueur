extends Ecran
## L'ÉDITEUR DE LA VILLE V2 — cahier § 10.
##
## Ouvert par `--ecran=editeur2` (ou `?ecran=editeur2` dans le navigateur),
## ou seul par F6 sur `scenes/editeur_v2.tscn`. Il charge `cartes/<nom>.json`,
## bâtit la ville avec le même rendu que le jeu, et laisse :
##   - TRACER UNE ROUTE par points cliqués sur la grille (R) : chaque clic pose
##     un sommet, un tracé en biais devient un coude, Entrée ou clic droit
##     termine ; le genre (rue / avenue / voie rapide) se change avec G ;
##   - POSER UN BÂTIMENT (B) du kit sur la grille des demi-cases, tourner
##     avec Q / E, refusé sur une rue, un autre lot ou l'eau ;
##   - POSER UN OBJET (O) — lampadaire, arbre, banc, voiture… — aimanté au
##     sol, tourné avec Q / E, refusé sur une rue (sauf les voitures) ;
##   - SCULPTER LE TERRAIN (T) : clic gauche monte d'un palier, droit descend,
##     rayon avec + / − ; PEINDRE L'EAU (W) : gauche = eau, droit = terre ;
##   - SÉLECTIONNER (S) : clic sur un lot, un objet ou une rue, Suppr efface,
##     Q / E tourne un lot ou un objet ;
##   - Ctrl+Z / Ctrl+Y, Ctrl+S enregistre (dans `res://cartes/` au bureau,
##     dans `user://cartes/` au navigateur), P photographie.
##
## LA PALETTE montre TOUS les modèles du dossier `modeles/`, variantes
## comprises — filtrés par famille et par recherche — et le modèle choisi
## tourne dans un aperçu 3D à côté. « Pose libre » lève les refus (rue, eau,
## lot) pour retoucher à la main ; Page haut / Page bas décalent l'objet en
## hauteur, ce qui permet de poser sur une jetée ou un toit.
##
## Caméra : clic droit tenu = orbite, molette = zoom, clic milieu ou
## Maj + clic = déplacer, flèches / ZQSD = déplacer, Début = tout voir.

const CASE := Ville2.CASE
const DEMI := Ville2.DEMI
const PALIER := Ville2.PALIER

enum { OUTIL_SELECTION, OUTIL_ROUTE, OUTIL_LOT, OUTIL_OBJET, OUTIL_TERRAIN, OUTIL_EAU }
const NOMS_OUTILS := ["Sélection", "Route", "Bâtiment", "Objet", "Terrain", "Eau"]
## ⚠ DES CHIFFRES, PAS DES LETTRES. Les lettres servent à SE DÉPLACER
## (ZQSD, comme dans le jeu et comme dans Godot) : tant que « S » choisissait
## l'outil Sélection, avancer la caméra changeait d'outil.
const RACCOURCIS_OUTILS := ["1", "2", "3", "4", "5", "6"]
const GENRES_ROUTE := [Ville2.R_RUE, Ville2.R_AVENUE, Ville2.R_VOIE_RAPIDE]

## LES RACCOURCIS DE LA PALETTE : les props que les générateurs posent, avec
## leur hauteur réglée. Ils ouvrent la liste, avant le catalogue complet.
##
## ⚠ PLUS DE LISTE TENUE À LA MAIN. Elle en comptait trente, figés ; le jour où
## `KitVille2.PROPS` en a gagné trente-cinq de plus (le kit nature), l'éditeur
## n'en montrait toujours que trente. Elle se DÉDUIT maintenant du kit.
static func raccourcis() -> Array:
	var l: Array = KitVille2.PROPS.keys()
	l.sort()
	l.append("pelouse")
	for v in KitVille2.VOITURES:
		l.append(v)
	for v in ["voitures/police", "voitures/ambulance", "voitures/firetruck",
			"voitures/garbage-truck", "voitures/truck"]:
		if not l.has(v): l.append(v)
	return l
const FAMILLE_TOUT := "— tout —"
const FAMILLE_RACCOURCIS := "★ raccourcis"

const TEINTE_GRILLE := Color(1, 1, 1, 0.18)
const TEINTE_OK := Color("#2fe0d0")
const TEINTE_NON := Color("#ff2f86")
const TEINTE_ROUTE := Color("#ff9040")
const TEINTE_SELECTION := Color("#ffe14d")

var _chemin := PlanV2.CHEMIN_PAR_DEFAUT
var _ville: Ville2
var _morceaux: MorceauxV2
var _camera: Camera3D
var _grille: MeshInstance3D
var _apercu: Node3D                    ## le fantôme du geste en cours
var _cadre: MeshInstance3D              ## le cadre de la sélection

var _outil := OUTIL_SELECTION
var _genre_route := 0
var _lot_choisi := 0
var _objet_choisi := 0
var _quarts := 0
var _rayon_terrain := 2
var _trace: Array = []                  ## les sommets de la route en cours
var _selection := {}                    ## {"genre": "lot"|"objet"|"route", "k": int}

var _pivot := Vector3.ZERO
var _distance := 420.0
var _azimut := 0.6
var _inclinaison := 0.9
var _orbite := false
var _glisse := false
var _souris := Vector2.ZERO
var _case := Vector2i(-1, -1)
var _point := Vector3.ZERO              ## le point visé, au sol
var _presse := false
var _tire := false                      ## on déplace la sélection à la souris
var _tire_depart := Vector3.ZERO        ## le point du sol sous le curseur au clic
var _tire_ref := Vector2.ZERO           ## la position de l'objet (ou du lot) au clic
var _tire_bouge := false                ## le seuil de 3 unités a été franchi

var _pile: Array[String] = []
var _refaire: Array[String] = []
var _etat: Label
var _titre: Label
var _palette: ItemList
var _cartes: OptionButton
var _familles: OptionButton
var _recherche: LineEdit
var _libre: CheckBox
var _apercu3d: SubViewport
var _apercu_noeud: MeshInstance3D
var _apercu_nom: Label
var _compteur: Label
var _aide: Label
var _info: RichTextLabel
var _champ_rayon: SpinBox
var _champ_decalage: SpinBox
var _boutons_outils: Array[Button] = []
var _liste: Array[String] = []          ## ce que la palette montre en ce moment
var _decalage := 0.0                    ## la hauteur ajoutée à l'objet posé
var _tourne_apercu := 0.0
var _photo_sortie := ""
var _manque := ""                       ## la carte demandée et introuvable

# ------------------------------------------------------------------ mise en place

func _ready() -> void:
	if get_parent() == get_tree().root:
		demarrer()

func demarrer() -> void:
	# ⚠ `donnees` D'ABORD, LA LIGNE DE COMMANDE ENSUITE. Dans le navigateur la
	# ligne de commande est vide : c'est `scenes/racine.gd` qui lit l'URL et
	# nous passe ses paramètres ici. Au bureau, les deux disent la même chose.
	for a in OS.get_cmdline_args():
		if a.begins_with("--carte="): _chemin = a.trim_prefix("--carte=")
		if a.begins_with("--cliche="): _photo_sortie = a.trim_prefix("--cliche=")
	if donnees.has("carte"): _chemin = String(donnees["carte"])
	if donnees.has("cliche"): _photo_sortie = String(donnees["cliche"])
	var amb: Array = MatieresCarnage.ambiance()
	for n in amb:
		monde().add_child(n)
	MatieresCarnage.nuit_forcee = 0.0
	MatieresCarnage.regler_heure(amb[0], amb[1], amb[2], 0.0)
	MatieresCarnage.regler_nuit(0.0)
	var env: Environment = (amb[0] as WorldEnvironment).environment
	env.fog_density *= 0.04
	var soleil := amb[1] as DirectionalLight3D
	soleil.directional_shadow_max_distance = 2600.0
	soleil.light_color = Color("#fff3dc")
	soleil.light_energy = 1.75
	env.ambient_light_color = Color("#cfd6e4")
	env.ambient_light_energy = 0.55

	var mer := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(600.0 * CASE, 600.0 * CASE)
	mer.mesh = plan
	mer.material_override = MatieresCarnage.eau()
	mer.position = Vector3(0, -2.85, 0)
	monde().add_child(mer)

	_camera = Camera3D.new()
	_camera.fov = 50.0
	_camera.far = 9000.0
	monde().add_child(_camera)
	_camera.make_current()

	# `--temoin=plage` (ou `?temoin=plage`) engendre un témoin neuf plutôt que
	# de lire un fichier : c'est la façon la plus courte de REGARDER ce que le
	# générateur vient de produire, sans rien enregistrer.
	var temoin := String(donnees.get("temoin", ""))
	for a2 in OS.get_cmdline_args():
		if a2.begins_with("--temoin="): temoin = a2.trim_prefix("--temoin=")
	if temoin == "plage":
		_ville = GenerateurPlage.generer(2)
		_chemin = "res://cartes/temoin-plage.json"
	elif temoin == "colline":
		_ville = GenerateurColline.generer(3)
		_chemin = "res://cartes/temoin-colline.json"
	elif temoin == "centre":
		_ville = GenerateurCentre.generer(1)
	else:
		_ville = Ville2.charger(_chemin)
		# ⚠ LE REPLI DOIT SE VOIR. Une carte absente du paquet rendait une
		# ville vide, on repliait sur le générateur du centre… et l'écran
		# montrait le centre en silence : impossible de distinguer « la carte
		# demandée n'existe pas » de « elle est arrivée ».
		if _ville.lots.is_empty() and _ville.routes.is_empty():
			_manque = _chemin
			_ville = GenerateurCentre.generer(1)
	_morceaux = MorceauxV2.new()
	# ⚠ PAS `tout()` ICI. Bâtir seize cents cases d'un bloc fige l'onglet
	# plusieurs secondes dans le navigateur, et l'utilisateur croit que la page
	# a planté. `suivre()` remplit la file, `_process` la vide une passe par
	# image : la ville paraît morceau par morceau, et la page répond tout du
	# long.
	_morceaux.par_image = 2
	_morceaux.regler(_ville, 99)
	monde().add_child(_morceaux)
	_morceaux.suivre(Vector3(float(_ville.taille.x) * CASE * 0.5, 0, float(_ville.taille.y) * CASE * 0.5))
	if "--essai" in OS.get_cmdline_args() or _photo_sortie != "":
		_morceaux.tout()

	_apercu = Node3D.new()
	monde().add_child(_apercu)
	_cadre = MeshInstance3D.new()
	_cadre.visible = false
	monde().add_child(_cadre)
	_poser_grille()
	_tout_voir()
	_interface()
	if _manque != "":
		_dire("⚠ « %s » introuvable dans le paquet — c'est le centre qui s'affiche." % _manque)
		return
	_dire("Ville « %s » — %d lots, %d objets, %d routes. R route · B bâtiment · O objet · T terrain · W eau · S sélection · Ctrl+S enregistre" % [
		_ville.nom, _ville.lots.size(), _ville.objets.size(), _ville.routes.size()])
	if "--essai" in OS.get_cmdline_args():
		get_tree().create_timer(1.0).timeout.connect(_essai)
	elif _photo_sortie != "":
		get_tree().create_timer(2.0).timeout.connect(_photographier)

## LE BANC DE L'ÉDITEUR (`--ecran=editeur2 --essai --cliche=/tmp/e.png`) :
## chaque outil est joué comme si la souris cliquait, et on compte.
func _essai() -> void:
	var t0 := Time.get_ticks_msec()
	var lots0 := _ville.lots.size()
	var objets0 := _ville.objets.size()
	var routes0 := _ville.routes.size()
	# Une route en L dans la bande vide du sud, de (3,38) à (30,39).
	_choisir_outil(OUTIL_ROUTE)
	_genre_route = 1
	for c in [Vector2i(3, 38), Vector2i(30, 39)]:
		_case = c
		_point = Vector3((float(c.x) + 0.5) * CASE, 0, (float(c.y) + 0.5) * CASE)
		_appliquer(true)
	_finir_route(true)
	print("[essai] route : %d -> %d routes, %s" % [routes0, _ville.routes.size(), _etat.text])
	# Un bâtiment sur la bande vide de l'ouest, puis un refusé sur la rue.
	_choisir_outil(OUTIL_LOT)
	_lot_choisi = 0
	_quarts = 1
	_case = Vector2i(0, 20)
	_point = Vector3(1.0 * CASE, 0, 20.5 * CASE)
	_appliquer(true)
	var lots1 := _ville.lots.size()
	_case = Vector2i(2, 20)
	_point = Vector3(2.5 * CASE, 0, 20.5 * CASE)
	_appliquer(true)
	print("[essai] lots : %d -> %d (posé) -> %d (refusé sur rue) — %s" % [lots0, lots1, _ville.lots.size(), _etat.text])
	# Un objet, puis un refusé sur la rue.
	_choisir_outil(OUTIL_OBJET)
	_objet_choisi = 5
	_case = Vector2i(1, 24)
	_point = Vector3(1.5 * CASE, 0, 24.5 * CASE)
	_appliquer(true)
	var objets1 := _ville.objets.size()
	_case = Vector2i(2, 24)
	_point = Vector3(2.5 * CASE, 0, 24.5 * CASE)
	_appliquer(true)
	print("[essai] objets : %d -> %d (posé) -> %d (refusé) — %s" % [objets0, objets1, _ville.objets.size(), _etat.text])
	# Le terrain : une bosse au coin sud-est, deux paliers.
	_choisir_outil(OUTIL_TERRAIN)
	_case = Vector2i(37, 36)
	_appliquer(true)
	_appliquer(true)
	print("[essai] terrain : palier %d en (37,36), %d en (39,39) — %s" % [_ville.palier(Vector2i(37, 36)), _ville.palier(Vector2i(39, 39)), _etat.text])
	# LA SÉLECTION SE VÉRIFIE SUR UN OBJET QUI EXISTE, pas sur une case choisie
	# d'avance : le banc visait (0,20) et ne trouvait rien, et c'est ce trou
	# qui a laissé passer « la sélection ne marche pas » jusqu'au client.
	_choisir_outil(OUTIL_SELECTION)
	var cible: Dictionary = _ville.objets[_ville.objets.size() / 2]
	var ox := float(cible["x"])
	var oz := float(cible["z"])
	_point = Vector3(ox + 1.0, 0, oz + 1.0)
	_case = Vector2i(floori(_point.x / CASE), floori(_point.z / CASE))
	_selectionner()
	print("[essai] sélection objet : %s — %s" % [str(_selection), _etat.text])
	# Le glissé : on attrape, on tire de deux cases, on relâche.
	_armer_le_glisse()
	_point += Vector3(2.0 * CASE, 0, 0)
	_glisser()
	_poser_le_glisse()
	print("[essai] glissé : x %.1f -> %.1f (%s)" % [ox, float(cible["x"]), _etat.text])
	_annuler()
	print("[essai] glissé annulé : x %.1f" % float((_ville.objets[_ville.objets.size() / 2] as Dictionary)["x"]))
	# Puis un bâtiment : sélection, rotation, effacement.
	# On cherche un bâtiment dont le centre n'est pas encombré : un banc ou une
	# voiture garée pile au milieu volerait le clic, et le banc dirait « raté »
	# là où l'éditeur a bien fait son travail.
	var essais := 0
	for k in range(_ville.lots.size() / 2, _ville.lots.size()):
		var centre := _ville.centre_du_lot(_ville.lots[k])
		_point = centre
		_case = Vector2i(floori(centre.x / CASE), floori(centre.z / CASE))
		_selectionner()
		essais += 1
		if not _selection.is_empty() and String(_selection["genre"]) == "lot": break
	print("[essai] sélection lot : %s en %d essai(s) — %s" % [str(_selection), essais, _etat.text])
	_tourner_selection(1)
	_supprimer_selection()
	print("[essai] après suppression : %d lots — %s" % [_ville.lots.size(), _etat.text])
	_annuler()
	print("[essai] annulé : %d lots" % _ville.lots.size())
	_annuler()
	_annuler()
	# ⚠ UN VRAI CLIC, POUSSÉ DANS LA FENÊTRE. Tous les essais ci-dessus
	# appellent les gestes en direct : ils ont dit « la sélection marche »
	# pendant que le client, lui, ne pouvait RIEN sélectionner — un test plein
	# écran avalait chaque clic avant la ville. Celui-ci traverse tout le
	# chemin, `_unhandled_input` compris, et c'est le seul qui prouve quelque
	# chose sur ce qu'on livre.
	_tout_voir()
	_choisir_outil(OUTIL_SELECTION)
	_case = Vector2i(-9, -9)
	var ecran := get_viewport().get_visible_rect().size
	for presse in [true, false]:
		var clic := InputEventMouseButton.new()
		clic.button_index = MOUSE_BUTTON_LEFT
		clic.pressed = presse
		clic.position = ecran * 0.5
		get_viewport().push_input(clic)
	if _case == Vector2i(-9, -9):
		push_error("[essai] LE CLIC N'ARRIVE PAS JUSQU'À LA VILLE")
	print("[essai] clic réel au centre : case %s, sélection %s" % [str(_case), str(_selection)])
	# ⚠ LE BANC N'ÉCRIT PAS SUR LA CARTE QU'IL A OUVERTE. Il l'a couverte de
	# ses gestes d'essai : enregistrée en place, elle partait au dépôt.
	_chemin = "user://essai_editeur.json"
	_enregistrer()
	print("[essai] %s — %d ms" % [_etat.text, Time.get_ticks_msec() - t0])
	# La palette : on montre le catalogue complet et un modèle choisi, pour que
	# la capture du banc dise si l'aperçu 3D marche.
	_choisir_outil(OUTIL_OBJET)
	for k in _familles.item_count:
		if _familles.get_item_text(k).begins_with("kenney/batiments"):
			_familles.select(k)
			break
	_remplir_palette()
	_objet_choisi = 14
	_palette.select(mini(14, _palette.item_count - 1))
	_maj_apercu()
	print("[essai] palette : %d modèles, aperçu « %s »" % [_palette.item_count, _apercu_nom.text])
	_choisir_outil(OUTIL_OBJET)
	_case = Vector2i(10, 38)
	_point = Vector3(10.5 * CASE, 0, 38.5 * CASE)
	_montrer_apercu()
	if _photo_sortie != "":
		_photographier()

# ------------------------------------------------------------------ l'interface

## L'INTERFACE EST CELLE D'UN LOGICIEL, pas d'un menu de jeu (demande du
## client, 12/09) : une BARRE D'OUTILS en haut, un DOCK à gauche (les outils
## et leurs réglages), un DOCK à droite (le catalogue et l'aperçu), une BARRE
## D'ÉTAT en bas, et la vue 3D au milieu. C'est la disposition de Godot, et
## ce n'est pas un hasard : elle laisse la vue au centre, toujours visible,
## pendant que les panneaux bordent l'écran.
##
## ⚠ CHAQUE PANNEAU ARRÊTE LA SOURIS (`MOUSE_FILTER_STOP`) et le centre la
## LAISSE PASSER (`IGNORE`). C'est ce qui fait que la molette fait défiler la
## liste des modèles quand on est dessus, et zoome la carte quand on est sur
## la vue — et non les deux à la fois.

const LARGE_GAUCHE := 190
const LARGE_DROITE := 272
const C_BARRE := Color("#1b1f27")
const C_DOCK := Color("#23283286")
const C_TRAIT := Color("#3a4150")
const C_ACCENT := Color("#2fe0d0")

## ⚠ PAS LA POLICE DU PROJET. Celle-ci est une police à pixels : dessinée pour
## les gros titres d'une borne d'arcade, elle est illisible en corps 13 et
## impose des lignes hautes. Un logiciel se lit en petit et en dense — on
## reprend donc les DEUX POLICES DU MENU (`ui/charte.gd`), la condensée demi-
## grasse pour le courant et la grasse en capitales pour les entêtes.
const POLICE := preload("res://polices/BarlowCondensed-SemiBold.ttf")
const POLICE_GRASSE := preload("res://polices/BarlowCondensed-Bold.ttf")
const CORPS := 16
const CORPS_ENTETE := 13

func _interface() -> void:
	var couche := interface()
	var racine := VBoxContainer.new()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.add_theme_constant_override("separation", 0)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Le thème descend sur TOUT l'arbre : une seule ligne habille les boutons,
	# les listes, les champs et les info-bulles.
	racine.theme = _theme_logiciel()
	couche.add_child(racine)

	# ---- la barre d'outils du haut : le fichier et la carte
	var haut := _panneau(C_BARRE)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	haut.add_child(hb)
	_titre = Label.new()
	_titre.text = "  PIKS  ·  ÉDITEUR DE VILLE  "
	_titre.add_theme_color_override("font_color", C_ACCENT)
	_titre.add_theme_font_override("font", POLICE_GRASSE)
	_titre.add_theme_font_size_override("font_size", CORPS)
	_titre.add_theme_constant_override("font_spacing_glyph", 2)
	hb.add_child(_titre)
	hb.add_child(_separateur())
	var etiquette_carte := Label.new()
	etiquette_carte.text = "Carte"
	hb.add_child(etiquette_carte)
	_cartes = OptionButton.new()
	_cartes.custom_minimum_size.x = 190
	for nom in _cartes_du_dossier():
		_cartes.add_item(nom)
	for k in _cartes.item_count:
		if _cartes.get_item_text(k) == _chemin.get_file().get_basename():
			_cartes.select(k)
	_cartes.focus_mode = Control.FOCUS_NONE
	_cartes.item_selected.connect(_changer_de_carte)
	hb.add_child(_cartes)
	hb.add_child(_separateur())
	for paire in [["Enregistrer", _enregistrer], ["Annuler", _annuler],
			["Refaire", _refaire_geste], ["Photo", _photographier], ["Tout voir", _tout_voir]]:
		var b := Button.new()
		b.text = String(paire[0])
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(paire[1])
		hb.add_child(b)
	var pousse := Control.new()
	pousse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pousse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(pousse)
	_compteur = Label.new()
	hb.add_child(_compteur)
	racine.add_child(haut)

	# ---- le milieu : dock gauche, vue, dock droit
	var milieu := HBoxContainer.new()
	milieu.size_flags_vertical = Control.SIZE_EXPAND_FILL
	milieu.add_theme_constant_override("separation", 0)
	milieu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(milieu)

	# ---- dock gauche : les outils, puis leurs réglages
	var gauche := _panneau(C_DOCK)
	gauche.custom_minimum_size.x = LARGE_GAUCHE
	var gb := VBoxContainer.new()
	gb.add_theme_constant_override("separation", 4)
	gauche.add_child(gb)
	gb.add_child(_entete("Outils"))
	var groupe := ButtonGroup.new()
	_boutons_outils.clear()
	for k in NOMS_OUTILS.size():
		var b := Button.new()
		b.text = "%s   %s" % [RACCOURCIS_OUTILS[k], NOMS_OUTILS[k]]
		b.toggle_mode = true
		b.button_group = groupe
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = k == _outil
		b.pressed.connect(func() -> void: _choisir_outil(k))
		gb.add_child(b)
		_boutons_outils.append(b)
	gb.add_child(_entete("Réglages"))
	_libre = CheckBox.new()
	_libre.text = "Pose libre"
	_libre.tooltip_text = "Ignore les refus : rue, eau, lot déjà posé."
	_libre.focus_mode = Control.FOCUS_NONE
	gb.add_child(_libre)
	gb.add_child(_ligne_reglage("Pinceau", _regle_rayon(), "cases"))
	gb.add_child(_ligne_reglage("Hauteur", _regle_decalage(), "unités"))
	gb.add_child(_entete("Sélection"))
	_info = RichTextLabel.new()
	_info.fit_content = true
	_info.custom_minimum_size.y = 70
	_info.bbcode_enabled = false
	_info.text = "rien"
	gb.add_child(_info)
	milieu.add_child(gauche)

	# ---- le centre : la vue 3D, que la souris traverse
	var vue := Control.new()
	vue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	milieu.add_child(vue)

	# ---- dock droit : le catalogue et l'aperçu
	var droite := _panneau(C_DOCK)
	droite.custom_minimum_size.x = LARGE_DROITE
	var db := VBoxContainer.new()
	db.add_theme_constant_override("separation", 4)
	droite.add_child(db)
	db.add_child(_entete("Modèles"))
	_familles = OptionButton.new()
	_familles.add_item(FAMILLE_RACCOURCIS)
	_familles.add_item(FAMILLE_TOUT)
	var vues: Dictionary = {}
	for m in KitVille2.catalogue():
		vues[KitVille2.famille(m)] = true
	var noms_familles: Array = vues.keys()
	noms_familles.sort()
	for f in noms_familles:
		_familles.add_item(String(f))
	# ⚠ AUCUN FOCUS SUR LES LISTES. Une liste qui a le clavier avale les
	# flèches : on croyait déplacer la caméra, on faisait défiler le catalogue.
	_familles.focus_mode = Control.FOCUS_NONE
	_familles.item_selected.connect(func(_k: int) -> void: _remplir_palette())
	db.add_child(_familles)
	_recherche = LineEdit.new()
	_recherche.placeholder_text = "chercher…"
	_recherche.clear_button_enabled = true
	_recherche.text_changed.connect(func(_t: String) -> void: _remplir_palette())
	db.add_child(_recherche)
	_palette = ItemList.new()
	_palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_palette.custom_minimum_size.y = 200
	_palette.focus_mode = Control.FOCUS_NONE
	_palette.item_selected.connect(_palette_choisie)
	db.add_child(_palette)
	db.add_child(_entete("Aperçu"))
	var cadre := SubViewportContainer.new()
	cadre.custom_minimum_size = Vector2(LARGE_DROITE - 16, 170)
	cadre.stretch = true
	cadre.mouse_filter = Control.MOUSE_FILTER_STOP
	_apercu3d = SubViewport.new()
	_apercu3d.own_world_3d = true
	_apercu3d.transparent_bg = false
	_apercu3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cadre.add_child(_apercu3d)
	db.add_child(cadre)
	_apercu_nom = Label.new()
	_apercu_nom.autowrap_mode = TextServer.AUTOWRAP_WORD
	_apercu_nom.custom_minimum_size.y = 34
	db.add_child(_apercu_nom)
	milieu.add_child(droite)

	# ---- la barre d'état
	var bas := _panneau(C_BARRE)
	var bb := HBoxContainer.new()
	bas.add_child(bb)
	_etat = Label.new()
	_etat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_etat.clip_text = true
	_etat.add_theme_color_override("font_color", Color("#d7dde8"))
	bb.add_child(_etat)
	_aide = Label.new()
	_aide.text = "  ZQSD ou flèches : déplacer · clic droit : tourner · molette : zoom · A/E : pivoter · Suppr : effacer"
	_aide.add_theme_color_override("font_color", Color("#8d95a6"))
	bb.add_child(_aide)
	racine.add_child(bas)

	_monter_apercu()
	_remplir_palette()
	_maj_compteur()

## Un panneau de dock : un fond plein, une bordure, et la souris qui S'ARRÊTE.
func _panneau(couleur: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var f := StyleBoxFlat.new()
	f.bg_color = couleur
	f.border_color = C_TRAIT
	f.set_border_width_all(1)
	f.content_margin_left = 8
	f.content_margin_right = 8
	f.content_margin_top = 6
	f.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", f)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p

## L'entête d'une section du dock : petites capitales espacées, comme les
## titres de l'inspecteur de Godot. L'espacement se donne en pixels ici — le
## moteur ne connaît que ça.
func _entete(texte: String) -> Label:
	var l := Label.new()
	l.text = texte.to_upper()
	l.add_theme_color_override("font_color", C_ACCENT)
	l.add_theme_font_override("font", POLICE_GRASSE)
	l.add_theme_font_size_override("font_size", CORPS_ENTETE)
	l.add_theme_constant_override("font_spacing_glyph", 2)
	l.custom_minimum_size.y = 22
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return l

## Le thème du logiciel : la police du menu, en corps de logiciel, et des
## boutons plats qui s'éclairent au survol plutôt que de se dessiner un cadre.
func _theme_logiciel() -> Theme:
	var t := Theme.new()
	t.default_font = POLICE
	t.default_font_size = CORPS
	var plat := func(fond: Color, bord: Color) -> StyleBoxFlat:
		var f := StyleBoxFlat.new()
		f.bg_color = fond
		f.border_color = bord
		f.set_border_width_all(1)
		f.corner_radius_top_left = 3
		f.corner_radius_top_right = 3
		f.corner_radius_bottom_left = 3
		f.corner_radius_bottom_right = 3
		f.content_margin_left = 8
		f.content_margin_right = 8
		f.content_margin_top = 4
		f.content_margin_bottom = 4
		return f
	# ⚠ PAS LA CASE À COCHER : un fond et un cadre lui donnent l'air d'un
	# bouton, et on ne sait plus si elle est cochée ou enfoncée.
	for classe in ["Button", "OptionButton"]:
		t.set_stylebox("normal", classe, plat.call(Color("#2b313c"), C_TRAIT))
		t.set_stylebox("hover", classe, plat.call(Color("#38404e"), Color("#4d5666")))
		t.set_stylebox("pressed", classe, plat.call(Color("#14484a"), C_ACCENT))
		t.set_stylebox("focus", classe, plat.call(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
		t.set_color("font_color", classe, Color("#d7dde8"))
		t.set_color("font_hover_color", classe, Color.WHITE)
		t.set_color("font_pressed_color", classe, C_ACCENT)
	t.set_color("font_color", "CheckBox", Color("#d7dde8"))
	t.set_color("font_hover_color", "CheckBox", Color.WHITE)
	t.set_stylebox("normal", "LineEdit", plat.call(Color("#181c23"), C_TRAIT))
	t.set_stylebox("panel", "ItemList", plat.call(Color("#181c23"), C_TRAIT))
	t.set_color("font_selected_color", "ItemList", Color("#06232a"))
	t.set_stylebox("selected", "ItemList", plat.call(C_ACCENT, C_ACCENT))
	t.set_stylebox("selected_focus", "ItemList", plat.call(C_ACCENT, C_ACCENT))
	t.set_stylebox("normal", "RichTextLabel", plat.call(Color("#181c23"), C_TRAIT))
	return t

func _separateur() -> VSeparator:
	return VSeparator.new()

## Une ligne « étiquette — réglage — unité », comme l'inspecteur de Godot.
func _ligne_reglage(nom: String, champ: Control, unite: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = nom
	l.custom_minimum_size.x = 62
	h.add_child(l)
	champ.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(champ)
	var u := Label.new()
	u.text = unite
	u.add_theme_color_override("font_color", Color("#8d95a6"))
	h.add_child(u)
	return h

func _regle_rayon() -> SpinBox:
	_champ_rayon = SpinBox.new()
	_champ_rayon.min_value = 1
	_champ_rayon.max_value = 8
	_champ_rayon.value = _rayon_terrain
	_champ_rayon.value_changed.connect(func(v: float) -> void:
		_rayon_terrain = int(v)
		_montrer_apercu())
	return _champ_rayon

func _regle_decalage() -> SpinBox:
	_champ_decalage = SpinBox.new()
	_champ_decalage.min_value = -40
	_champ_decalage.max_value = 200
	_champ_decalage.step = 0.5
	_champ_decalage.value = _decalage
	_champ_decalage.value_changed.connect(func(v: float) -> void: _decalage = v)
	return _champ_decalage

## Le compte de la barre du haut : ce que porte la ville en ce moment.
func _maj_compteur() -> void:
	if _compteur == null or _ville == null: return
	_compteur.text = "%d lots · %d objets · %d routes · %d × %d cases   " % [
		_ville.lots.size(), _ville.objets.size(), _ville.routes.size(),
		_ville.taille.x, _ville.taille.y]

## Ce que dit le dock de gauche sur ce qui est sélectionné.
func _maj_info() -> void:
	if _info == null: return
	if _selection.is_empty():
		_info.text = "rien"
		return
	var k := int(_selection["k"])
	match String(_selection["genre"]):
		"objet":
			var o: Dictionary = _ville.objets[k]
			_info.text = "objet\n%s\nx %.0f  z %.0f" % [_nom_lisible(String(o["m"])),
				float(o["x"]), float(o["z"])]
		"lot":
			var l: Dictionary = _ville.lots[k]
			_info.text = "bâtiment\n%s\n%d × %d demi-cases, %d quart(s)" % [
				_nom_lisible(String(l["m"])), int(l["w"]), int(l["h"]), int(l["q"])]
		"route":
			var r: Dictionary = _ville.routes[k]
			_info.text = "route\n%s\n%s, %d points" % [String(r["nom"]), String(r["genre"]),
				(r["points"] as Array).size()]

# ------------------------------------------------------------------ l'aperçu 3D

## LA PETITE FENÊTRE 3D. Un `SubViewport` avec SON PROPRE monde : sans
## `own_world_3d`, l'aperçu montrerait la ville entière, et la ville
## recevrait la lumière de l'aperçu.
func _monter_apercu() -> void:
	var lumiere := DirectionalLight3D.new()
	lumiere.rotation_degrees = Vector3(-45.0, -40.0, 0)
	lumiere.light_energy = 1.5
	lumiere.light_color = Color("#fff3dc")
	_apercu3d.add_child(lumiere)
	var monde_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#1f2733")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9fb0c4")
	env.ambient_light_energy = 0.8
	monde_env.environment = env
	_apercu3d.add_child(monde_env)
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	_apercu3d.add_child(pivot)
	_apercu_noeud = MeshInstance3D.new()
	pivot.add_child(_apercu_noeud)
	var cam := Camera3D.new()
	cam.name = "Camera"
	_apercu3d.add_child(cam)
	cam.make_current()

## Montre le modèle choisi, cadré sur sa boîte : un lampadaire et un
## gratte-ciel doivent remplir la fenêtre autant l'un que l'autre.
func _maj_apercu() -> void:
	if _apercu_noeud == null: return
	var m := _modele_lot() if _outil == OUTIL_LOT else _modele_objet()
	if _outil == OUTIL_ROUTE: m = ""
	if m == "":
		_apercu_noeud.mesh = null
		_apercu_nom.text = ""
		return
	var chemin := _chemin_de(m)
	if chemin == "" or not ResourceLoader.exists(chemin):
		_apercu_noeud.mesh = null
		_apercu_nom.text = m + " (pas un modèle)"
		return
	var maillage := FormesCarnage.maillage_kenney(chemin, 0.0, Vector3.AXIS_X, 0.0)
	_apercu_noeud.mesh = maillage
	_apercu_noeud.material_override = FormesCarnage.matiere_kenney(chemin)
	var boite := maillage.get_aabb()
	var rayon := maxf(0.001, boite.size.length() * 0.5)
	# Le modèle est recentré en X et Z et posé sur y = 0 : on vise son milieu.
	_apercu_noeud.position = Vector3(0, -boite.size.y * 0.5, 0)
	var cam := _apercu3d.get_node("Camera") as Camera3D
	cam.near = rayon * 0.01
	cam.far = rayon * 20.0
	cam.position = Vector3(0, rayon * 0.55, rayon * 2.4)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	# ⚠ UN RACCOURCI N'A PAS D'EMPRISE, IL A UNE HAUTEUR. « lampadaire » n'est
	# pas un modèle mais une fiche du catalogue : mesuré comme un bâtiment, il
	# sortait à « 1,0 × 1,0 × 1,0 case », ce qui ne veut rien dire.
	var fiche: Dictionary = KitVille2.PROPS.get(m, {})
	if not fiche.is_empty():
		_apercu_nom.text = "%s — %s, %.1f unité(s) de haut" % [m,
			KitVille2.nom_court(chemin), float(fiche.get("h", 0.0))]
		return
	var t := KitVille2.mesurer(m)
	_apercu_nom.text = "%s — %.1f × %.1f × %.1f cases (%.0f × %.0f × %.0f unités)" % [
		_nom_lisible(m), t.x, t.y, t.z, t.x * CASE, t.y * CASE, t.z * CASE]

func _process(delta: float) -> void:
	if _apercu3d == null: return
	var pivot := _apercu3d.get_node_or_null("Pivot") as Node3D
	if pivot != null and _apercu_noeud != null and _apercu_noeud.mesh != null:
		_tourne_apercu += delta * 0.6
		pivot.rotation.y = _tourne_apercu

## Les cartes livrées dans `res://cartes/`. ⚠ `DirAccess` ne voit pas les
## mêmes noms dans un paquet exporté qu'au bureau : au navigateur on lit la
## liste écrite dans `cartes/index.json`, qui est engendrée avec les cartes.
func _cartes_du_dossier() -> Array:
	var noms: Array = []
	var index := FileAccess.get_file_as_string("res://cartes/index.json")
	if index != "":
		var brut = JSON.parse_string(index)
		if typeof(brut) == TYPE_ARRAY:
			for n in brut: noms.append(String(n))
	if noms.is_empty():
		var d := DirAccess.open("res://cartes")
		if d != null:
			for f in d.get_files():
				if f.ends_with(".json") and f != "index.json":
					noms.append(f.get_basename())
	noms.sort()
	return noms

func _changer_de_carte(k: int) -> void:
	var nom := _cartes.get_item_text(k)
	_chemin = "res://cartes/%s.json" % nom
	var v := Ville2.charger(_chemin)
	if v.lots.is_empty() and v.routes.is_empty():
		_dire("Carte « %s » illisible." % nom)
		return
	_pile.clear()
	_refaire.clear()
	_recharger(v.vers_json())
	_tout_voir()
	_maj_compteur()
	_dire("Ville « %s » — %d lots, %d objets, %d routes." % [_ville.nom, _ville.lots.size(),
		_ville.objets.size(), _ville.routes.size()])

func _remplir_palette() -> void:
	_palette.clear()
	_liste.clear()
	if _outil == OUTIL_ROUTE:
		for g in GENRES_ROUTE:
			_liste.append(String(g))
			_palette.add_item(String(g))
		_palette.select(clampi(_genre_route, 0, _palette.item_count - 1))
		_palette.visible = true
		_maj_apercu()
		return
	# ⚠ LA PALETTE RESTE VISIBLE MÊME HORS POSE. Le client veut VOIR le
	# catalogue et son aperçu ; la cacher dès qu'on prend l'outil Sélection
	# revenait à lui retirer la moitié de l'écran.
	var f := _familles.get_item_text(_familles.selected).get_slice(" (", 0)
	var cherche := _recherche.text.strip_edges().to_lower()
	var source: Array = []
	if f == FAMILLE_RACCOURCIS:
		source = raccourcis()
	else:
		source = KitVille2.catalogue().duplicate()
		if f != FAMILLE_TOUT:
			var gardes: Array = []
			for m in source:
				if KitVille2.famille(String(m)) == f: gardes.append(m)
			source = gardes
	for m in source:
		var nom := _nom_lisible(String(m))
		if cherche != "" and not nom.to_lower().contains(cherche): continue
		_liste.append(String(m))
		_palette.add_item(nom)
	_palette.visible = true
	var choisi: int = _lot_choisi if _outil == OUTIL_LOT else _objet_choisi
	if _palette.item_count > 0:
		_palette.select(clampi(choisi, 0, _palette.item_count - 1))
	_familles.set_item_text(_familles.selected,
		"%s (%d)" % [f.get_slice(" (", 0), _palette.item_count])
	_maj_apercu()

## Le nom montré dans la liste : le nom de fichier pour un modèle, le mot du
## catalogue pour un raccourci.
func _nom_lisible(m: String) -> String:
	if m.begins_with("res://"): return KitVille2.nom_court(m)
	return m

## Le chemin `res://…` d'une entrée de la palette (un raccourci passe par son
## catalogue de props).
func _chemin_de(m: String) -> String:
	if m.begins_with("res://"): return m
	var fiche: Dictionary = KitVille2.PROPS.get(m, {})
	if not fiche.is_empty(): return KitVille2.chemin(String(fiche["m"]))
	if m == "pelouse": return ""
	return KitVille2.chemin(m)

func _palette_choisie(k: int) -> void:
	match _outil:
		OUTIL_LOT: _lot_choisi = k
		OUTIL_OBJET: _objet_choisi = k
		OUTIL_ROUTE: _genre_route = k
	_maj_apercu()
	_montrer_apercu()

func _choisir_outil(k: int) -> void:
	_finir_route(false)
	_outil = k
	if k < _boutons_outils.size() and not _boutons_outils[k].button_pressed:
		_boutons_outils[k].button_pressed = true
	_selection = {}
	_cadre.visible = false
	_maj_info()
	_remplir_palette()
	_montrer_apercu()
	_dire("Outil : " + NOMS_OUTILS[k])

func _dire(texte: String) -> void:
	if _etat != null:
		_etat.text = texte

# ------------------------------------------------------------------ la grille

func _poser_grille() -> void:
	if _grille != null:
		_grille.queue_free()
	_grille = MeshInstance3D.new()
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = TEINTE_GRILLE
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	var lx := float(_ville.taille.x) * CASE
	var lz := float(_ville.taille.y) * CASE
	for i in _ville.taille.x + 1:
		im.surface_add_vertex(Vector3(float(i) * CASE, 0.6, 0))
		im.surface_add_vertex(Vector3(float(i) * CASE, 0.6, lz))
	for j in _ville.taille.y + 1:
		im.surface_add_vertex(Vector3(0, 0.6, float(j) * CASE))
		im.surface_add_vertex(Vector3(lx, 0.6, float(j) * CASE))
	im.surface_end()
	_grille.mesh = im
	monde().add_child(_grille)

# ------------------------------------------------------------------ la caméra

## LE RECUL QUI TIENT LA CARTE ENTIÈRE. Avec un champ de 50°, il faut à peu
## près un côté et quart de distance pour cadrer un carré de ce côté.
func _recul_maxi() -> float:
	return float(maxi(_ville.taille.x, _ville.taille.y)) * CASE * 1.15

func _recul_mini() -> float:
	return CASE * 1.5

func _placer_camera() -> void:
	_distance = clampf(_distance, _recul_mini(), _recul_maxi())
	# ⚠ LE PIVOT RESTE AU-DESSUS DE LA CARTE. On peut regarder un peu au-delà
	# du bord — c'est utile pour poser contre la lisière — mais pas partir à
	# l'infini et perdre la ville de vue.
	var marge := CASE * 6.0
	_pivot.x = clampf(_pivot.x, -marge, float(_ville.taille.x) * CASE + marge)
	_pivot.z = clampf(_pivot.z, -marge, float(_ville.taille.y) * CASE + marge)
	_pivot.y = 0.0
	var d := Vector3(sin(_azimut) * cos(_inclinaison), sin(_inclinaison), cos(_azimut) * cos(_inclinaison)) * _distance
	_camera.look_at_from_position(_pivot + d, _pivot, Vector3.UP)
	# ⚠ LES DOCKS MANGENT L'ÉCRAN. La caméra rend la vue ENTIÈRE, docks
	# compris : cadrée sur le milieu de la fenêtre, la ville se retrouve à
	# moitié sous le panneau de droite. On décale donc la caméra de la moitié
	# de la différence des deux docks, en unités du monde à cette distance.
	var ecran := get_viewport().get_visible_rect().size
	if ecran.y > 1.0:
		var par_pixel := 2.0 * _distance * tan(deg_to_rad(_camera.fov) * 0.5) / ecran.y
		_camera.global_position += _camera.global_transform.basis.x \
			* (float(LARGE_DROITE) - float(LARGE_GAUCHE)) * 0.5 * par_pixel

## Cadrer toute la carte — le bouton de la barre et la touche Début.
func _tout_voir() -> void:
	_pivot = Vector3(float(_ville.taille.x) * CASE * 0.5, 0, float(_ville.taille.y) * CASE * 0.5)
	_distance = _recul_maxi()
	_placer_camera()

func _viser() -> void:
	var origine := _camera.project_ray_origin(_souris)
	var dir := _camera.project_ray_normal(_souris)
	var p = _sur_plan(origine, dir, 0.0)
	if p == null:
		_case = Vector2i(-1, -1)
		return
	var c := Vector2i(floori((p as Vector3).x / CASE), floori((p as Vector3).z / CASE))
	# Deuxième passe à l'altitude de la case visée : sur un plateau, la
	# première suffit ; sur une colline, on corrige.
	if _ville.dedans(c):
		var y := _ville.sol(c)
		if y != 0.0:
			var p2 = _sur_plan(origine, dir, y)
			if p2 != null:
				p = p2
				c = Vector2i(floori((p as Vector3).x / CASE), floori((p as Vector3).z / CASE))
	_point = p as Vector3
	_case = c

func _sur_plan(origine: Vector3, dir: Vector3, y: float):
	if absf(dir.y) < 1.0e-5: return null
	var t := (y - origine.y) / dir.y
	if t < 0.0: return null
	return origine + dir * t

# ------------------------------------------------------------------ l'entrée

## ⚠ `_unhandled_input`, PAS `_input`. `_input` passe AVANT l'interface : la
## molette au-dessus de la liste des modèles zoomait la carte au lieu de faire
## défiler la liste, et taper « route » dans la recherche déclenchait les
## outils R, O, U, T, E. En `_unhandled_input`, un panneau qui arrête la souris
## et un champ qui a le clavier ont servi les premiers ; on ne reçoit que ce
## qui tombe sur la vue.
func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var m := ev as InputEventMouseMotion
		_souris = m.position
		if _orbite:
			_azimut -= m.relative.x * 0.006
			_inclinaison = clampf(_inclinaison + m.relative.y * 0.006, 0.15, 1.5)
			_placer_camera()
		elif _glisse:
			var droite := _camera.global_transform.basis.x
			var avant := Vector3(-_camera.global_transform.basis.z.x, 0, -_camera.global_transform.basis.z.z).normalized()
			_pivot -= (droite * m.relative.x - avant * m.relative.y) * _distance * 0.0016
			_placer_camera()
		elif _tire:
			_viser()
			_glisser()
		else:
			_viser()
			_montrer_apercu()
			if _presse and (_outil == OUTIL_TERRAIN or _outil == OUTIL_EAU):
				pass
	elif ev is InputEventMouseButton:
		var b := ev as InputEventMouseButton
		_souris = b.position
		match b.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if b.pressed:
					_distance = maxf(_recul_mini(), _distance * 0.88)
					_placer_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				if b.pressed:
					# ⚠ LE DÉZOOM A UNE BUTÉE. Sans elle, une roulette un peu
					# vive envoyait la caméra à six mille unités : la ville
					# devenait un point, et il fallait « Tout voir » pour la
					# retrouver. On ne recule pas plus loin que ce qu'il faut
					# pour tenir la carte entière à l'écran.
					_distance = minf(_recul_maxi(), _distance * 1.14)
					_placer_camera()
			MOUSE_BUTTON_RIGHT:
				if b.pressed and _outil == OUTIL_ROUTE and not _trace.is_empty():
					_finir_route(true)
				elif b.pressed and (_outil == OUTIL_TERRAIN or _outil == OUTIL_EAU):
					_viser()
					_appliquer(false)
				else:
					_orbite = b.pressed
			MOUSE_BUTTON_MIDDLE:
				_glisse = b.pressed
			MOUSE_BUTTON_LEFT:
				if b.shift_pressed:
					_glisse = b.pressed
				elif b.pressed:
					# ⚠ NE PLUS TESTER « EST-CE QUE JE SUIS SUR L'INTERFACE ».
					# Depuis la refonte en logiciel, le premier enfant de la
					# couche est un conteneur PLEIN ÉCRAN : le test répondait
					# « oui » partout et AUCUN CLIC n'arrivait jamais à la
					# ville — ni sélection, ni pose. Le filtre de souris fait
					# déjà le travail : les panneaux ARRÊTENT l'événement
					# (`MOUSE_FILTER_STOP`), le centre le LAISSE PASSER, et
					# `_unhandled_input` ne reçoit que ce qui tombe sur la vue.
					# Un clic dans la vue rend le clavier à la vue : sans ça,
					# un champ resté actif avalait les flèches et le ZQSD.
					get_viewport().gui_release_focus()
					_viser()
					_presse = true
					_appliquer(true)
					_armer_le_glisse()
				else:
					_presse = false
					_poser_le_glisse()
	elif ev is InputEventKey and (ev as InputEventKey).pressed:
		_touche(ev as InputEventKey)

func _touche(k: InputEventKey) -> void:
	if k.ctrl_pressed:
		match k.keycode:
			KEY_Z: _annuler()
			KEY_Y: _refaire_geste()
			KEY_S: _enregistrer()
		return
	match k.keycode:
		KEY_1, KEY_KP_1: _choisir_outil(OUTIL_SELECTION)
		KEY_2, KEY_KP_2: _choisir_outil(OUTIL_ROUTE)
		KEY_3, KEY_KP_3: _choisir_outil(OUTIL_LOT)
		KEY_4, KEY_KP_4: _choisir_outil(OUTIL_OBJET)
		KEY_5, KEY_KP_5: _choisir_outil(OUTIL_TERRAIN)
		KEY_6, KEY_KP_6: _choisir_outil(OUTIL_EAU)
		KEY_G:
			_genre_route = (_genre_route + 1) % GENRES_ROUTE.size()
			if _outil == OUTIL_ROUTE: _palette.select(_genre_route)
			_dire("Genre de route : " + GENRES_ROUTE[_genre_route])
		KEY_A:
			_quarts = posmod(_quarts + 1, 4)
			_tourner_selection(1)
			_montrer_apercu()
		KEY_E:
			_quarts = posmod(_quarts - 1, 4)
			_tourner_selection(-1)
			_montrer_apercu()
		KEY_PAGEUP:
			_decalage += 1.0
			if _champ_decalage != null: _champ_decalage.value = _decalage
		KEY_PAGEDOWN:
			_decalage -= 1.0
			if _champ_decalage != null: _champ_decalage.value = _decalage
		KEY_PLUS, KEY_KP_ADD, KEY_EQUAL:
			_rayon_terrain = mini(8, _rayon_terrain + 1)
			if _champ_rayon != null: _champ_rayon.value = _rayon_terrain
		KEY_MINUS, KEY_KP_SUBTRACT:
			_rayon_terrain = maxi(1, _rayon_terrain - 1)
			if _champ_rayon != null: _champ_rayon.value = _rayon_terrain
		KEY_ENTER, KEY_KP_ENTER:
			_finir_route(true)
		KEY_ESCAPE:
			_finir_route(false)
			_selection = {}
			_cadre.visible = false
		KEY_DELETE, KEY_BACKSPACE:
			_supprimer_selection()
		KEY_P:
			_photographier()
		KEY_HOME:
			_tout_voir()
		# La caméra se conduit au ZQSD ET aux flèches. Le déplacement suit les
		# AXES DE L'ÉCRAN, pas ceux du monde : « avancer » va vers le haut de
		# l'écran quelle que soit l'orientation de la caméra.
		KEY_LEFT, KEY_Q: _deplacer(-1.0, 0.0)
		KEY_RIGHT, KEY_D: _deplacer(1.0, 0.0)
		KEY_UP, KEY_Z: _deplacer(0.0, 1.0)
		KEY_DOWN, KEY_S: _deplacer(0.0, -1.0)

func _deplacer(cote: float, avant: float) -> void:
	var b := _camera.global_transform.basis
	var droite := Vector3(b.x.x, 0, b.x.z).normalized()
	var devant := Vector3(-b.z.x, 0, -b.z.z).normalized()
	_pivot += (droite * cote + devant * avant) * _distance * 0.08
	_placer_camera()

# ------------------------------------------------------------------ les gestes

func _appliquer(gauche: bool) -> void:
	if not _ville.dedans(_case): return
	match _outil:
		OUTIL_ROUTE: _ajouter_sommet()
		OUTIL_LOT: _poser_lot()
		OUTIL_OBJET: _poser_objet()
		OUTIL_TERRAIN: _sculpter(gauche)
		OUTIL_EAU: _peindre_eau(gauche)
		OUTIL_SELECTION: _selectionner()

## LA ROUTE PAR POINTS. Un sommet par clic ; entre deux sommets qui ne sont
## ni sur la même ligne ni sur la même colonne, on passe par le coude
## (horizontal d'abord, puis vertical) — le kit ne sait pas paver en biais.
func _ajouter_sommet() -> void:
	if not _ville.terre(_case):
		_dire("Une route ne se trace pas sur l'eau.")
		return
	if _trace.is_empty():
		_trace.append(_case)
		_dire("Route : premier point posé. Clic pour les suivants, Entrée ou clic droit pour finir, Échap pour abandonner.")
		return
	var dernier: Vector2i = _trace[_trace.size() - 1]
	if dernier == _case: return
	if dernier.x != _case.x and dernier.y != _case.y:
		_trace.append(Vector2i(_case.x, dernier.y))
	_trace.append(_case)
	_montrer_apercu()

func _finir_route(garder: bool) -> void:
	if _trace.is_empty(): return
	if garder and _trace.size() >= 2:
		_empiler()
		var k := _ville.ajouter_route(GENRES_ROUTE[_genre_route], _trace, "Rue %d" % (_ville.routes.size() + 1))
		if k >= 0:
			var cases := Ville2.cases_de_route(_ville.routes[k])
			# Un lot sous la nouvelle rue est ôté : la rue a la priorité, on
			# le dit.
			var otes := _oter_lots_sur(cases)
			_rebatir(cases)
			_dire("Route tracée (%d cases%s)." % [cases.size(), ", %d lot(s) ôté(s)" % otes if otes > 0 else ""])
	_trace.clear()
	_montrer_apercu()

func _oter_lots_sur(cases: Array) -> int:
	var pris: Dictionary = {}
	for c in cases: pris[c] = true
	var restants: Array = []
	var otes := 0
	for l in _ville.lots:
		var dedans := false
		for c in Ville2.cases_du_lot(l):
			if pris.has(c): dedans = true
		if dedans: otes += 1
		else: restants.append(l)
	_ville.lots = restants
	return otes

## ⚠ UN LOT EST TOUJOURS UN CHEMIN. Un raccourci de la palette (« lampadaire »)
## n'a de sens que pour un OBJET, qui sait sa hauteur voulue ; posé comme lot,
## il partait en `res://modeles/kenney/lampadaire.glb` — un fichier qui
## n'existe pas. On le ramène donc à son modèle.
func _modele_lot() -> String:
	if _liste.is_empty(): return ""
	var m := _liste[clampi(_lot_choisi, 0, _liste.size() - 1)]
	return m if m.begins_with("res://") else _chemin_de(m)

## Le coin du lot fantôme, en demi-cases, centré sous la souris.
func _coin_lot(m: String) -> Vector2i:
	var e := KitVille2.emprise_tournee(m, _quarts)
	var hx := roundi(_point.x / DEMI - float(e.x) * 0.5)
	var hy := roundi(_point.z / DEMI - float(e.y) * 0.5)
	return Vector2i(hx, hy)

func _lot_possible(m: String, coin: Vector2i) -> bool:
	if m == "": return false
	if _libre != null and _libre.button_pressed: return true
	var e := KitVille2.emprise_tournee(m, _quarts)
	var essai := {"x": coin.x, "y": coin.y, "w": e.x, "h": e.y}
	for c in Ville2.cases_du_lot(essai):
		if not _ville.terre(c) or _ville.carte.route(c) or _ville.carte.case_prise(c):
			return false
	# Pas deux lots l'un dans l'autre : les rectangles en demi-cases.
	var r := Rect2i(coin, e)
	for l in _ville.lots:
		if r.intersects(Rect2i(int(l["x"]), int(l["y"]), int(l["w"]), int(l["h"]))):
			return false
	return true

func _poser_lot() -> void:
	var m := _modele_lot()
	var coin := _coin_lot(m)
	if not _lot_possible(m, coin):
		_dire("Impossible ici : une rue, l'eau ou un autre bâtiment.")
		return
	_empiler()
	var e := KitVille2.emprise_tournee(m, _quarts)
	var k := _ville.ajouter_lot(m, coin.x, coin.y, e.x, e.y, _quarts, "editeur")
	_rebatir(Ville2.cases_du_lot(_ville.lots[k]))
	_dire("Posé : %s (%d x %d demi-cases)." % [m, e.x, e.y])

func _modele_objet() -> String:
	if _liste.is_empty(): return ""
	return _liste[clampi(_objet_choisi, 0, _liste.size() - 1)]

func _objet_possible(m: String, c: Vector2i) -> bool:
	if m == "": return false
	if _libre != null and _libre.button_pressed: return true
	if not _ville.terre(c): return false
	if _ville.carte.route(c) and not m.begins_with("voitures/"): return false
	if _ville.lot_sur(c) >= 0: return false
	return true

func _poser_objet() -> void:
	var m := _modele_objet()
	if not _objet_possible(m, _case):
		_dire("Impossible ici : une rue, l'eau ou un bâtiment.")
		return
	_empiler()
	var o := {"m": m, "x": snappedf(_point.x, 0.5), "z": snappedf(_point.z, 0.5),
		"r": PI * 0.5 * float(_quarts), "h": 0.0}
	if absf(_decalage) > 0.01:
		o["y_abs"] = TerrainV2.hauteur_en(_ville, float(o["x"]), float(o["z"])) + _decalage
	_ville.objets.append(o)
	_rebatir([_case])
	_dire("Posé : %s%s." % [_nom_lisible(m), "" if absf(_decalage) < 0.01 else " (+%.1f)" % _decalage])

func _sculpter(monte: bool) -> void:
	_empiler()
	var touchees: Array = []
	for dj in range(-_rayon_terrain, _rayon_terrain + 1):
		for di in range(-_rayon_terrain, _rayon_terrain + 1):
			if di * di + dj * dj > _rayon_terrain * _rayon_terrain: continue
			var c := _case + Vector2i(di, dj)
			if not _ville.dedans(c) or not _ville.terre(c): continue
			var y := _ville.sol(c) + (PALIER if monte else -PALIER)
			_ville.poser_terre(c, clampf(y, 0.0, 12.0 * PALIER))
			touchees.append(c)
	_rebatir(touchees)
	_dire("Terrain : palier %d au centre." % _ville.palier(_case))

func _peindre_eau(eau: bool) -> void:
	_empiler()
	var touchees: Array = []
	for dj in range(-_rayon_terrain, _rayon_terrain + 1):
		for di in range(-_rayon_terrain, _rayon_terrain + 1):
			if di * di + dj * dj > _rayon_terrain * _rayon_terrain: continue
			var c := _case + Vector2i(di, dj)
			if not _ville.dedans(c): continue
			if eau: _ville.poser_eau(c)
			else: _ville.poser_terre(c, _ville.sol(c))
			touchees.append(c)
	if eau:
		_oter_lots_sur(touchees)
	_rebatir(touchees)

# ------------------------------------------------------------------ la sélection

## ⚠ LE RAYON DE PIOCHE SUIT LA TAILLE DU MODÈLE. Six unités fixes, c'était
## moins d'un tiers de conteneur : il fallait viser le nombril de l'objet pour
## l'attraper, et le client a conclu que la sélection ne marchait pas. On prend
## maintenant la demi-emprise réelle du modèle, plus deux unités de tolérance.
func _rayon_pioche(o: Dictionary) -> float:
	var large := float(o.get("w", 0.0))
	var profond := float(o.get("d", 0.0))
	if large <= 0.0 or profond <= 0.0:
		# `taille()` répond en CASES, la ville compte en unités.
		var t := KitVille2.taille(String(o["m"])) * CASE
		large = t.x
		profond = t.z
	return clampf(maxf(large, profond) * 0.5 + 2.0, 4.0, 60.0)

## ⚠ TROIS PASSES, DANS CET ORDRE. Le doigt sur un objet l'emporte ; sinon le
## bâtiment sous le curseur ; sinon seulement un objet voisin, à la tolérance.
## Sans cette hiérarchie, une voiture garée devant un immeuble prenait le clic
## qui visait l'immeuble.
func _objet_pique(large: bool) -> int:
	var meilleur := -1
	var meilleure := INF
	for k in _ville.objets.size():
		var o: Dictionary = _ville.objets[k]
		var r := _rayon_pioche(o)
		if not large: r = maxf(r - 2.0, 2.0) * 0.6
		var d := Vector2(float(o["x"]), float(o["z"])).distance_to(Vector2(_point.x, _point.z))
		if d <= r and d < meilleure:
			meilleure = d
			meilleur = k
	return meilleur

func _selectionner() -> void:
	_selection = {}
	var meilleur := _objet_pique(false)
	if meilleur < 0 and _ville.lot_sur(_case) < 0:
		meilleur = _objet_pique(true)
	if meilleur >= 0:
		_selection = {"genre": "objet", "k": meilleur}
		_dire("Objet : %s — glisser déplace, Suppr efface, A/E tourne." % _nom_lisible(String(_ville.objets[meilleur]["m"])))
	else:
		var l := _ville.lot_sur(_case)
		if l >= 0:
			_selection = {"genre": "lot", "k": l}
			_dire("Bâtiment : %s — glisser déplace, Suppr efface, A/E tourne." % _nom_lisible(String(_ville.lots[l]["m"])))
		elif _ville.carte.route(_case):
			for k in _ville.routes.size():
				if _case in Ville2.cases_de_route(_ville.routes[k]):
					_selection = {"genre": "route", "k": k}
					var r: Dictionary = _ville.routes[k]
					_dire("Route : %s « %s » (%d points) — Suppr efface." % [r["genre"], r["nom"], (r["points"] as Array).size()])
					break
	_montrer_cadre()

## LE DÉPLACEMENT À LA SOURIS. Un clic sélectionne ; si la souris bouge
## ensuite de plus de trois unités avant le relâchement, la sélection SUIT le
## curseur. Rien n'est rebâti pendant le glissé — seul le cadre suit, et la
## ville se refait une fois, au relâchement : sinon chaque pixel de souris
## reconstruisait un morceau de seize cases.
func _armer_le_glisse() -> void:
	_tire = false
	_tire_bouge = false
	if _outil != OUTIL_SELECTION or _selection.is_empty(): return
	match String(_selection["genre"]):
		"objet":
			var o: Dictionary = _ville.objets[int(_selection["k"])]
			_tire_ref = Vector2(float(o["x"]), float(o["z"]))
		"lot":
			var l: Dictionary = _ville.lots[int(_selection["k"])]
			_tire_ref = Vector2(float(l["x"]), float(l["y"]))
		_:
			return
	_tire_depart = _point
	_tire = true

func _glisser() -> void:
	if not _tire: return
	var d := Vector2(_point.x - _tire_depart.x, _point.z - _tire_depart.z)
	if not _tire_bouge and d.length() < 3.0: return
	# ⚠ ON EMPILE AU PREMIER MOUVEMENT, pas au clic : sinon chaque clic de
	# sélection laissait un « Annuler » qui ne défaisait rien. À cet instant
	# la sélection n'a pas encore bougé — c'est le bon état à garder.
	if not _tire_bouge: _empiler()
	_tire_bouge = true
	match String(_selection["genre"]):
		"objet":
			var o: Dictionary = _ville.objets[int(_selection["k"])]
			o["x"] = snappedf(_tire_ref.x + d.x, 0.5)
			o["z"] = snappedf(_tire_ref.y + d.y, 0.5)
			_dire("Déplacement : x %.1f  z %.1f" % [float(o["x"]), float(o["z"])])
		"lot":
			# Un bâtiment se pose sur la trame : il se déplace en DEMI-CASES.
			var l: Dictionary = _ville.lots[int(_selection["k"])]
			l["x"] = int(_tire_ref.x) + roundi(d.x / DEMI)
			l["y"] = int(_tire_ref.y) + roundi(d.y / DEMI)
			_dire("Déplacement : demi-case %d, %d" % [int(l["x"]), int(l["y"])])
	_montrer_cadre()

func _poser_le_glisse() -> void:
	if not _tire: return
	_tire = false
	if not _tire_bouge: return
	_tire_bouge = false
	var touchees: Array = []
	match String(_selection["genre"]):
		"objet":
			var o: Dictionary = _ville.objets[int(_selection["k"])]
			# L'objet reprend l'altitude de son nouveau sol, sauf s'il avait
			# été posé à une hauteur voulue (`y_abs`) — un panneau au mur.
			if o.has("y_abs"):
				o["y_abs"] = TerrainV2.hauteur_en(_ville, float(o["x"]), float(o["z"])) + _decalage
			touchees = [_case_de(_tire_ref.x, _tire_ref.y),
				_case_de(float(o["x"]), float(o["z"]))]
		"lot":
			var l: Dictionary = _ville.lots[int(_selection["k"])]
			touchees = Ville2.cases_du_lot(l)
			for c in Ville2.cases_du_lot({"x": int(_tire_ref.x), "y": int(_tire_ref.y),
					"w": int(l["w"]), "h": int(l["h"])}):
				touchees.append(c)
	_rebatir(touchees)
	_dire("Déplacé. (Ctrl+Z annule)")

func _case_de(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CASE), floori(z / CASE))

func _montrer_cadre() -> void:
	_cadre.visible = false
	if _selection.is_empty(): return
	var r := Rect2()
	var y := 0.0
	match String(_selection["genre"]):
		"objet":
			var o: Dictionary = _ville.objets[int(_selection["k"])]
			r = Rect2(float(o["x"]) - 4.0, float(o["z"]) - 4.0, 8.0, 8.0)
			y = _ville.sol(Vector2i(floori(float(o["x"]) / CASE), floori(float(o["z"]) / CASE)))
		"lot":
			var l: Dictionary = _ville.lots[int(_selection["k"])]
			r = Rect2(float(l["x"]) * DEMI, float(l["y"]) * DEMI, float(l["w"]) * DEMI, float(l["h"]) * DEMI)
			y = _ville.centre_du_lot(l).y
		"route":
			var cases := Ville2.cases_de_route(_ville.routes[int(_selection["k"])])
			var c0: Vector2i = cases[0]
			r = Rect2(float(c0.x) * CASE, float(c0.y) * CASE, CASE, CASE)
			for c in cases:
				r = r.merge(Rect2(float((c as Vector2i).x) * CASE, float((c as Vector2i).y) * CASE, CASE, CASE))
			y = _ville.sol(c0)
	_cadre.mesh = _rectangle(r, TEINTE_SELECTION)
	_cadre.position = Vector3(0, y + 0.9, 0)
	_cadre.visible = true
	_maj_info()

func _supprimer_selection() -> void:
	if _selection.is_empty(): return
	_empiler()
	var touchees: Array = []
	match String(_selection["genre"]):
		"objet":
			var o: Dictionary = _ville.objets[int(_selection["k"])]
			touchees.append(Vector2i(floori(float(o["x"]) / CASE), floori(float(o["z"]) / CASE)))
			_ville.objets.remove_at(int(_selection["k"]))
		"lot":
			touchees = Ville2.cases_du_lot(_ville.lots[int(_selection["k"])])
			_ville.lots.remove_at(int(_selection["k"]))
		"route":
			touchees = Ville2.cases_de_route(_ville.routes[int(_selection["k"])])
			_ville.routes.remove_at(int(_selection["k"]))
	_selection = {}
	_cadre.visible = false
	_rebatir(touchees)
	_dire("Effacé.")

func _tourner_selection(sens: int) -> void:
	if _selection.is_empty(): return
	_empiler()
	match String(_selection["genre"]):
		"objet":
			var o: Dictionary = _ville.objets[int(_selection["k"])]
			o["r"] = float(o.get("r", 0.0)) + PI * 0.5 * float(sens)
			_rebatir([Vector2i(floori(float(o["x"]) / CASE), floori(float(o["z"]) / CASE))])
		"lot":
			var l: Dictionary = _ville.lots[int(_selection["k"])]
			var avant := Ville2.cases_du_lot(l)
			var q := posmod(int(l["q"]) + sens, 4)
			var e := KitVille2.emprise_tournee(String(l["m"]), q)
			# On tourne autour du centre : le coin bouge pour garder le centre.
			var cx := float(l["x"]) + float(l["w"]) * 0.5
			var cy := float(l["y"]) + float(l["h"]) * 0.5
			l["q"] = q
			l["x"] = roundi(cx - float(e.x) * 0.5)
			l["y"] = roundi(cy - float(e.y) * 0.5)
			l["w"] = e.x
			l["h"] = e.y
			_rebatir(avant + Ville2.cases_du_lot(l))
	_montrer_cadre()

# ------------------------------------------------------------------ l'aperçu

func _montrer_apercu() -> void:
	for n in _apercu.get_children():
		n.queue_free()
	if not _ville.dedans(_case): return
	var y := _ville.sol(_case) + 0.8
	match _outil:
		OUTIL_ROUTE:
			var cases: Array = []
			if not _trace.is_empty():
				var essai := {"points": _trace.duplicate()}
				var dernier: Vector2i = _trace[_trace.size() - 1]
				if dernier.x != _case.x and dernier.y != _case.y:
					(essai["points"] as Array).append(Vector2i(_case.x, dernier.y))
				(essai["points"] as Array).append(_case)
				cases = Ville2.cases_de_route(essai)
			else:
				cases = [_case]
			for c in cases:
				_dalle(Rect2(float((c as Vector2i).x) * CASE, float((c as Vector2i).y) * CASE, CASE, CASE),
					TEINTE_ROUTE if _ville.terre(c) else TEINTE_NON, y)
		OUTIL_LOT:
			var m := _modele_lot()
			var coin := _coin_lot(m)
			var e := KitVille2.emprise_tournee(m, _quarts)
			_dalle(Rect2(float(coin.x) * DEMI, float(coin.y) * DEMI, float(e.x) * DEMI, float(e.y) * DEMI),
				TEINTE_OK if _lot_possible(m, coin) else TEINTE_NON, y)
		OUTIL_OBJET:
			_dalle(Rect2(_point.x - 3.0, _point.z - 3.0, 6.0, 6.0),
				TEINTE_OK if _objet_possible(_modele_objet(), _case) else TEINTE_NON, y)
		OUTIL_TERRAIN, OUTIL_EAU:
			for dj in range(-_rayon_terrain, _rayon_terrain + 1):
				for di in range(-_rayon_terrain, _rayon_terrain + 1):
					if di * di + dj * dj > _rayon_terrain * _rayon_terrain: continue
					var c := _case + Vector2i(di, dj)
					if _ville.dedans(c):
						_dalle(Rect2(float(c.x) * CASE, float(c.y) * CASE, CASE, CASE), TEINTE_OK, _ville.sol(c) + 0.8)
		_:
			_dalle(Rect2(float(_case.x) * CASE, float(_case.y) * CASE, CASE, CASE), TEINTE_GRILLE, y)

func _dalle(r: Rect2, teinte: Color, y: float) -> void:
	var n := MeshInstance3D.new()
	n.mesh = _rectangle(r, Color(teinte, 0.45))
	n.position = Vector3(0, y, 0)
	_apercu.add_child(n)

func _rectangle(r: Rect2, teinte: Color) -> Mesh:
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = teinte
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
	var a := Vector3(r.position.x, 0, r.position.y)
	var b := Vector3(r.end.x, 0, r.position.y)
	var c := Vector3(r.end.x, 0, r.end.y)
	var d := Vector3(r.position.x, 0, r.end.y)
	for v in [a, b, c, a, c, d]:
		im.surface_add_vertex(v)
	im.surface_end()
	return im

# ------------------------------------------------------------------ rebâtir, annuler, enregistrer

func _rebatir(cases: Array) -> void:
	_morceaux.refaire(cases)
	_montrer_apercu()
	_maj_compteur()

func _empiler() -> void:
	_pile.append(_ville.vers_json())
	if _pile.size() > 40: _pile.pop_front()
	_refaire.clear()

func _annuler() -> void:
	if _pile.is_empty():
		_dire("Rien à annuler.")
		return
	_refaire.append(_ville.vers_json())
	_recharger(_pile.pop_back())
	_dire("Annulé.")

func _refaire_geste() -> void:
	if _refaire.is_empty(): return
	_pile.append(_ville.vers_json())
	_recharger(_refaire.pop_back())
	_dire("Refait.")

func _recharger(json: String) -> void:
	_ville = Ville2.depuis_json(json)
	_selection = {}
	_cadre.visible = false
	_morceaux.regler(_ville, 99)
	_morceaux.suivre(Vector3(float(_ville.taille.x) * CASE * 0.5, 0, float(_ville.taille.y) * CASE * 0.5))
	_poser_grille()

func _chemin_d_enregistrement() -> String:
	if OS.has_feature("web") or OS.has_feature("template"):
		return "user://cartes/" + _chemin.get_file()
	return _chemin

func _enregistrer() -> void:
	var ou := _chemin_d_enregistrement()
	if _ville.enregistrer(ou):
		_dire("Enregistré : " + ou)
	else:
		_dire("Impossible d'écrire " + ou)

func _photographier() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var ou := _photo_sortie if _photo_sortie != "" else "user://editeur_v2.png"
	DirAccess.make_dir_recursive_absolute(ou.get_base_dir())
	get_viewport().get_texture().get_image().save_png(ou)
	print("photo ", ou)
	_dire("Photo : " + ou)
	if _photo_sortie != "":
		get_tree().quit()
