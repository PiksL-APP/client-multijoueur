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
## Caméra : clic droit tenu = orbite, molette = zoom, clic milieu ou
## Maj + clic = déplacer, flèches / ZQSD = déplacer, Début = tout voir.

const CASE := Ville2.CASE
const DEMI := Ville2.DEMI
const PALIER := Ville2.PALIER

enum { OUTIL_SELECTION, OUTIL_ROUTE, OUTIL_LOT, OUTIL_OBJET, OUTIL_TERRAIN, OUTIL_EAU }
const NOMS_OUTILS := ["Sélection", "Route", "Bâtiment", "Objet", "Terrain", "Eau"]
const GENRES_ROUTE := [Ville2.R_RUE, Ville2.R_AVENUE, Ville2.R_VOIE_RAPIDE]

## Les objets proposés, dans l'ordre de la palette.
const OBJETS := ["lampadaire", "lampadaire_parc", "feu", "stop", "plaque", "arbre", "arbre_oak",
	"arbre_rond", "palmier", "buisson", "banc", "poubelle", "benne", "borne", "cone", "monument",
	"voitures/sedan", "voitures/taxi", "voitures/van", "voitures/police"]

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

var _pile: Array[String] = []
var _refaire: Array[String] = []
var _etat: Label
var _titre: Label
var _palette: ItemList
var _photo_sortie := ""

# ------------------------------------------------------------------ mise en place

func _ready() -> void:
	if get_parent() == get_tree().root:
		demarrer()

func demarrer() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--carte="): _chemin = a.trim_prefix("--carte=")
		if a.begins_with("--cliche="): _photo_sortie = a.trim_prefix("--cliche=")
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

	_ville = Ville2.charger(_chemin)
	if _ville.taille == Vector2i(40, 40) and _ville.lots.is_empty() and _ville.routes.is_empty():
		_ville = GenerateurCentre.generer(1)
	_morceaux = MorceauxV2.new()
	_morceaux.regler(_ville, 99)
	monde().add_child(_morceaux)
	_morceaux.tout()

	_apercu = Node3D.new()
	monde().add_child(_apercu)
	_cadre = MeshInstance3D.new()
	_cadre.visible = false
	monde().add_child(_cadre)
	_poser_grille()
	_pivot = Vector3(float(_ville.taille.x) * CASE * 0.5, 0, float(_ville.taille.y) * CASE * 0.5)
	_distance = float(maxi(_ville.taille.x, _ville.taille.y)) * CASE * 0.9
	_placer_camera()
	_interface()
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
	# La sélection : le lot posé, tourné puis effacé.
	_choisir_outil(OUTIL_SELECTION)
	_case = Vector2i(0, 20)
	_point = Vector3(1.0 * CASE, 0, 20.5 * CASE)
	_appliquer(true)
	print("[essai] sélection : %s — %s" % [str(_selection), _etat.text])
	_tourner_selection(1)
	_supprimer_selection()
	print("[essai] après suppression : %d lots — %s" % [_ville.lots.size(), _etat.text])
	_annuler()
	print("[essai] annulé : %d lots" % _ville.lots.size())
	_annuler()
	_annuler()
	_enregistrer()
	print("[essai] %s — %d ms" % [_etat.text, Time.get_ticks_msec() - t0])
	_choisir_outil(OUTIL_ROUTE)
	_case = Vector2i(10, 38)
	_point = Vector3(10.5 * CASE, 0, 38.5 * CASE)
	_montrer_apercu()
	if _photo_sortie != "":
		_photographier()

func _interface() -> void:
	var couche := interface()
	var panneau := PanelContainer.new()
	panneau.position = Vector2(12, 12)
	panneau.custom_minimum_size = Vector2(260, 0)
	var boite := VBoxContainer.new()
	panneau.add_child(boite)
	_titre = Label.new()
	_titre.text = "ÉDITEUR — ville v2"
	boite.add_child(_titre)
	var outils := HBoxContainer.new()
	boite.add_child(outils)
	for k in NOMS_OUTILS.size():
		var b := Button.new()
		b.text = NOMS_OUTILS[k]
		b.pressed.connect(func() -> void: _choisir_outil(k))
		outils.add_child(b)
	_palette = ItemList.new()
	_palette.custom_minimum_size = Vector2(240, 320)
	_palette.item_selected.connect(_palette_choisie)
	boite.add_child(_palette)
	var actions := HBoxContainer.new()
	boite.add_child(actions)
	for paire in [["Enregistrer", _enregistrer], ["Annuler", _annuler], ["Refaire", _refaire_geste], ["Photo", _photographier]]:
		var b := Button.new()
		b.text = String(paire[0])
		b.pressed.connect(paire[1])
		actions.add_child(b)
	couche.add_child(panneau)
	_etat = Label.new()
	_etat.position = Vector2(12, 0)
	_etat.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_etat.offset_top = -30
	_etat.offset_left = 12
	_etat.autowrap_mode = TextServer.AUTOWRAP_WORD
	couche.add_child(_etat)
	_remplir_palette()

func _remplir_palette() -> void:
	_palette.clear()
	match _outil:
		OUTIL_LOT:
			for m in KitVille2.BATIMENTS.keys():
				_palette.add_item(String(m))
			for m in KitVille2.PIKSL.keys():
				_palette.add_item(String(m))
			_palette.select(mini(_lot_choisi, _palette.item_count - 1))
		OUTIL_OBJET:
			for m in OBJETS:
				_palette.add_item(String(m))
			_palette.select(mini(_objet_choisi, _palette.item_count - 1))
		OUTIL_ROUTE:
			for g in GENRES_ROUTE:
				_palette.add_item(String(g))
			_palette.select(_genre_route)
		_:
			pass
	_palette.visible = _palette.item_count > 0

func _palette_choisie(k: int) -> void:
	match _outil:
		OUTIL_LOT: _lot_choisi = k
		OUTIL_OBJET: _objet_choisi = k
		OUTIL_ROUTE: _genre_route = k
	_montrer_apercu()

func _choisir_outil(k: int) -> void:
	_finir_route(false)
	_outil = k
	_selection = {}
	_cadre.visible = false
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

func _placer_camera() -> void:
	var d := Vector3(sin(_azimut) * cos(_inclinaison), sin(_inclinaison), cos(_azimut) * cos(_inclinaison)) * _distance
	_camera.look_at_from_position(_pivot + d, _pivot, Vector3.UP)

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

func _input(ev: InputEvent) -> void:
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
					_distance = maxf(60.0, _distance * 0.88)
					_placer_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				if b.pressed:
					_distance = minf(6000.0, _distance * 1.14)
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
					if _sur_l_interface(b.position): return
					_viser()
					_presse = true
					_appliquer(true)
				else:
					_presse = false
	elif ev is InputEventKey and (ev as InputEventKey).pressed:
		_touche(ev as InputEventKey)

func _sur_l_interface(p: Vector2) -> bool:
	for n in interface().get_children():
		if n is Control and (n as Control).get_global_rect().has_point(p):
			return true
	return false

func _touche(k: InputEventKey) -> void:
	if k.ctrl_pressed:
		match k.keycode:
			KEY_Z: _annuler()
			KEY_Y: _refaire_geste()
			KEY_S: _enregistrer()
		return
	match k.keycode:
		KEY_S: _choisir_outil(OUTIL_SELECTION)
		KEY_R: _choisir_outil(OUTIL_ROUTE)
		KEY_B: _choisir_outil(OUTIL_LOT)
		KEY_O: _choisir_outil(OUTIL_OBJET)
		KEY_T: _choisir_outil(OUTIL_TERRAIN)
		KEY_W: _choisir_outil(OUTIL_EAU)
		KEY_G:
			_genre_route = (_genre_route + 1) % GENRES_ROUTE.size()
			if _outil == OUTIL_ROUTE: _palette.select(_genre_route)
			_dire("Genre de route : " + GENRES_ROUTE[_genre_route])
		KEY_Q, KEY_A:
			_quarts = posmod(_quarts + 1, 4)
			_tourner_selection(1)
			_montrer_apercu()
		KEY_E:
			_quarts = posmod(_quarts - 1, 4)
			_tourner_selection(-1)
			_montrer_apercu()
		KEY_PLUS, KEY_KP_ADD, KEY_EQUAL:
			_rayon_terrain = mini(8, _rayon_terrain + 1)
			_dire("Rayon du pinceau : %d" % _rayon_terrain)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_rayon_terrain = maxi(1, _rayon_terrain - 1)
			_dire("Rayon du pinceau : %d" % _rayon_terrain)
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
			_pivot = Vector3(float(_ville.taille.x) * CASE * 0.5, 0, float(_ville.taille.y) * CASE * 0.5)
			_distance = float(maxi(_ville.taille.x, _ville.taille.y)) * CASE * 0.9
			_placer_camera()
		KEY_LEFT: _deplacer(Vector3(-1, 0, 0))
		KEY_RIGHT: _deplacer(Vector3(1, 0, 0))
		KEY_UP: _deplacer(Vector3(0, 0, -1))
		KEY_DOWN: _deplacer(Vector3(0, 0, 1))

func _deplacer(d: Vector3) -> void:
	_pivot += d * _distance * 0.08
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

func _modele_lot() -> String:
	var noms: Array = KitVille2.BATIMENTS.keys() + KitVille2.PIKSL.keys()
	return String(noms[clampi(_lot_choisi, 0, noms.size() - 1)])

## Le coin du lot fantôme, en demi-cases, centré sous la souris.
func _coin_lot(m: String) -> Vector2i:
	var e := KitVille2.emprise_tournee(m, _quarts)
	var hx := roundi(_point.x / DEMI - float(e.x) * 0.5)
	var hy := roundi(_point.z / DEMI - float(e.y) * 0.5)
	return Vector2i(hx, hy)

func _lot_possible(m: String, coin: Vector2i) -> bool:
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
	return OBJETS[clampi(_objet_choisi, 0, OBJETS.size() - 1)]

func _objet_possible(m: String, c: Vector2i) -> bool:
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
	_ville.ajouter_objet(m, snappedf(_point.x, 1.0), snappedf(_point.z, 1.0), PI * 0.5 * float(_quarts))
	_rebatir([_case])
	_dire("Posé : %s." % m)

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

func _selectionner() -> void:
	_selection = {}
	# Un objet à moins de 6 unités ?
	var meilleur := -1
	var dist := 36.0
	for k in _ville.objets.size():
		var o: Dictionary = _ville.objets[k]
		var d := Vector2(float(o["x"]), float(o["z"])).distance_squared_to(Vector2(_point.x, _point.z))
		if d < dist:
			dist = d
			meilleur = k
	if meilleur >= 0:
		_selection = {"genre": "objet", "k": meilleur}
		_dire("Objet : %s — Suppr efface, Q/E tourne." % String(_ville.objets[meilleur]["m"]))
	else:
		var l := _ville.lot_sur(_case)
		if l >= 0:
			_selection = {"genre": "lot", "k": l}
			_dire("Bâtiment : %s — Suppr efface, Q/E tourne." % String(_ville.lots[l]["m"]))
		elif _ville.carte.route(_case):
			for k in _ville.routes.size():
				if _case in Ville2.cases_de_route(_ville.routes[k]):
					_selection = {"genre": "route", "k": k}
					var r: Dictionary = _ville.routes[k]
					_dire("Route : %s « %s » (%d points) — Suppr efface." % [r["genre"], r["nom"], (r["points"] as Array).size()])
					break
	_montrer_cadre()

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
	_morceaux.tout()
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
