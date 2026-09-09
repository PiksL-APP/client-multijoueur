class_name EditeurCarte
extends Ecran
## L'ÉDITEUR DE CARTE 3D.
##
## ⚠ CE QU'IL MANIPULE : le DESSIN ASCII de `jeux/carnage/quartiers.gd`, un
## caractère par case — pas un format à lui. Le premier jet avait son propre
## fichier JSON : il y avait alors deux vérités, celle qu'on dessinait à la
## souris et celle que le jeu bâtissait, et rien ne garantissait qu'elles
## disent la même chose. Ici on peint des caractères dans la grille, on rebâtit
## le quartier avec `Quartiers.batir_fiche` — LA MÊME fonction que le banc de
## photo et que le jeu — et on ressort le bloc GDScript à recoller dans le
## catalogue. L'éditeur et le fichier sont le même objet vu de deux côtés.
##
## LES TROIS DÉCISIONS QUI COMPTENT
##
## 1. On rebâtit à la FIN du geste, pas à chaque case. Bâtir un quartier prend
##    une fraction de seconde ; le faire à chaque case peinte rendait le tracé
##    d'une avenue impossible. Pendant le geste, les cases modifiées sont
##    montrées par des dalles de couleur — instantanées — et le vrai décor
##    arrive au relâchement.
## 2. Les FAUTES sont celles du banc (`Quartiers.fautes`), affichées en rouge
##    sur la case coupable et listées dans le panneau. Un éditeur qui laisse
##    dessiner une rampe au pied d'un carrefour ne sert à rien.
## 3. La grille s'AGRANDIT par les bords. Un quartier qu'on ne peut pas
##    étendre, c'est un quartier qu'on recommence.

const CASE := CarteVille.CASE
const PALIER := CarteVille.PALIER

## La palette, dans l'ordre où on s'en sert : le sol, puis ce qui pousse, puis
## ce qui se bâtit. La couleur ne sert qu'à l'aperçu pendant le geste.
const PINCEAUX := [
	["#", "Rue", Color("#7d828c")],
	[".", "Eau", Color("#2b5f7a")],
	[",", "Pelouse", Color("#7f9464")],
	[";", "Sable", Color("#d9c9a2")],
	["o", "Esplanade", Color("#b9b6ac")],
	["P", "Parking", Color("#a8a49c")],
	["^", "Arbres", Color("#4f7a3a")],
	["'", "Buissons", Color("#6d8a4a")],
	["X", "Dépôt", Color("#c0784a")],
	["%", "Chantier", Color("#d9a441")],
	["O", "Rond-point", Color("#5f6874")],
	["T", "Tour", Color("#3f6f8f")],
	["B", "Bureau", Color("#8fa3b5")],
	["C", "Commerce", Color("#c8553a")],
	["M", "Maison", Color("#e8d8b8")],
	["V", "Vieille ville", Color("#d29a5e")],
	["H", "Hangar", Color("#7d8a8f")],
]
## Les familles s'écrivent aussi en minuscule : deux bâtiments de même famille
## côte à côte fusionnent en un seul s'ils portent la même lettre.
const FAMILLES := "TBCMVH"

enum { OUTIL_DESSIN, OUTIL_RELIEF }

var _id := "centre"
var _fiche: Dictionary = {}
var _quartier: Node3D
var _decor: Node3D                      ## les autres quartiers, pour le contexte
var _apercu: Node3D                     ## les dalles du geste en cours
var _marques: Node3D                    ## les croix rouges des fautes
var _curseur: MeshInstance3D
var _camera: Camera3D

var _outil := OUTIL_DESSIN
var _pinceau := "#"
var _minuscule := false
var _palier := 0

var _pivot := Vector3.ZERO
var _distance := 500.0
var _azimut := 0.75
var _inclinaison := 0.55

var _case := Vector2i.ZERO
var _vise := false
var _peint := false
var _orbite := false
var _pile: Array = []
var _refaire: Array = []
var _touchees: Dictionary = {}

# ---------------------------------------------------------------- montage

func _ready() -> void:
	# Ouvert tout seul (F6 sur `scenes/editeur.tscn`), l'éditeur se démarre
	# lui-même : la racine, qui appelle `demarrer()` d'habitude, n'est pas là.
	if get_parent() == get_tree().root:
		demarrer()

func demarrer() -> void:
	var amb: Array = MatieresCarnage.ambiance()
	for n in amb:
		monde().add_child(n)
	MatieresCarnage.regler_heure(amb[0], amb[1], amb[2], 0.10)
	MatieresCarnage.regler_nuit(0.10)
	# La brume du jeu est réglée pour une caméra à trente unités du sol ; à vol
	# d'oiseau elle efface la carte.
	var env: Environment = (amb[0] as WorldEnvironment).environment
	env.fog_density *= 0.12
	(amb[1] as DirectionalLight3D).directional_shadow_max_distance = 2600.0

	var mer := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(600.0 * CASE, 600.0 * CASE)
	mer.mesh = plan
	var eau := StandardMaterial3D.new()
	eau.albedo_color = Color("#2b5f7a")
	eau.roughness = 0.15
	eau.metallic = 0.25
	mer.material_override = eau
	mer.position = Vector3(0, -2.4, 0)
	monde().add_child(mer)

	_camera = Camera3D.new()
	_camera.fov = 50.0
	_camera.far = 9000.0
	monde().add_child(_camera)
	_camera.make_current()

	_interface()
	for a in OS.get_cmdline_args():
		if a.begins_with("--quartier="): _id = a.substr(11)
	_charger(_id)
	set_process(true)
	set_process_input(true)
	# Le banc : `--photo-editeur=<fichier>` prend une image et sort. C'est le
	# seul moyen de vérifier l'éditeur depuis une session sans écran.
	if "--essai-editeur" in OS.get_cmdline_args():
		_essai()
	for a in OS.get_cmdline_args():
		if a.begins_with("--photo-editeur="):
			_photo = a.substr(16)
			get_tree().process_frame.connect(_photographier)

func _essai() -> void:
	_empiler()
	for i in range(2, 14):                       # une avenue en travers
		_case = Vector2i(i, 16); _vise = true; _appliquer(true)
	_choisir("T")
	for i in range(6, 9):                        # deux tours au bord de l'eau
		for j in range(17, 19):
			_case = Vector2i(i, j); _vise = true; _appliquer(true)
	_outil = OUTIL_RELIEF
	_palier = 3
	for i in range(2, 6):
		_case = Vector2i(i, 1); _vise = true; _appliquer(true)
	_finir_geste()
	print("--- essai : grille %d x %d" % [_large(), _haut()])
	for l in _lignes("plan"):
		print("    ", l)
	print(_texte_fiche().substr(0, 300))
	var liste: Array = Quartiers.fautes(_fiche)
	print("--- fautes après essai : ", liste.size())
	for f in liste:
		print("    ", f)

var _photo := ""
var _images := 0

func _photographier() -> void:
	_images += 1
	if _images < 16: return
	DirAccess.make_dir_recursive_absolute(_photo.get_base_dir())
	get_viewport().get_texture().get_image().save_png(_photo)
	print("photo ", _photo)
	get_tree().quit()

# ---------------------------------------------------------------- le quartier

func _charger(id: String) -> void:
	_id = id
	# Une COPIE PROFONDE : on ne veut surtout pas modifier le catalogue en
	# mémoire, sinon « recharger » ne recharge rien.
	_fiche = (Quartiers.CATALOGUE[id] as Dictionary).duplicate(true)
	_pile.clear(); _refaire.clear()
	_rebatir()
	_recadrer()

func _rebatir() -> void:
	if _quartier != null: _quartier.queue_free()
	_quartier = Quartiers.batir_fiche(_fiche, _id)
	monde().add_child(_quartier)
	if _decor != null: _decor.queue_free()
	# Les autres quartiers restent visibles : on dessine une ville, pas une
	# île isolée, et leurs angles disent où poser les ponts.
	_decor = Node3D.new()
	monde().add_child(_decor)
	for autre in Quartiers.CATALOGUE.keys():
		if String(autre) == _id: continue
		_decor.add_child(Quartiers.batir(String(autre)))
	_curseur = MeshInstance3D.new()
	_curseur.mesh = _cadre()
	var mc := StandardMaterial3D.new()
	mc.albedo_color = Color("#ffd23f")
	mc.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_curseur.material_override = mc
	_quartier.add_child(_curseur)
	_apercu = Node3D.new()
	_quartier.add_child(_apercu)
	_marques = Node3D.new()
	_quartier.add_child(_marques)
	_montrer_fautes()
	_etat()

func _cadre() -> ArrayMesh:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var h := CASE * 0.5
	var coins := [Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)]
	for k in 4:
		im.surface_add_vertex(coins[k] + Vector3(0, 0.8, 0))
		im.surface_add_vertex(coins[(k + 1) % 4] + Vector3(0, 0.8, 0))
		im.surface_add_vertex(coins[k] + Vector3(0, 0.8, 0))
		im.surface_add_vertex(coins[k] + Vector3(0, PALIER * 0.9, 0))
	im.surface_end()
	var m := ArrayMesh.new()
	for s in im.get_surface_count():
		m.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, im.surface_get_arrays(s))
	return m

# ---------------------------------------------------------------- la grille

func _lignes(cle: String) -> Array:
	return _fiche[cle]

func _large() -> int:
	var l := 0
	for ligne in _lignes("plan"):
		l = maxi(l, String(ligne).length())
	return l

func _haut() -> int:
	return _lignes("plan").size()

func _lire(cle: String, i: int, j: int) -> String:
	var lignes: Array = _lignes(cle)
	if j < 0 or j >= lignes.size(): return "." if cle == "plan" else "0"
	var ligne: String = lignes[j]
	if i < 0 or i >= ligne.length(): return "." if cle == "plan" else "0"
	return ligne[i]

## ⚠ Une chaîne GDScript ne se modifie pas par indice : on la recompose. Et on
## complète les lignes trop courtes, sinon peindre à droite d'une ligne courte
## ne fait rien du tout, en silence.
func _ecrire(cle: String, i: int, j: int, c: String) -> void:
	var lignes: Array = _lignes(cle)
	if j < 0 or j >= lignes.size() or i < 0: return
	var ligne: String = lignes[j]
	var bouche := "." if cle == "plan" else "0"
	while ligne.length() <= i:
		ligne += bouche
	lignes[j] = ligne.substr(0, i) + c + ligne.substr(i + 1)

func _palier_de(i: int, j: int) -> int:
	var c := _lire("relief", i, j)
	return int(c) if c >= "0" and c <= "9" else 0

func _terre(i: int, j: int) -> bool:
	return _lire("plan", i, j) != "."

# ---------------------------------------------------------------- visée

## Où pointe la souris, DANS LE REPÈRE DU QUARTIER : il a son propre angle, et
## viser en coordonnées du monde donnait des cases décalées dès que l'angle
## n'était pas nul.
func _viser() -> void:
	if _camera == null or _quartier == null: return
	var souris := get_viewport().get_mouse_position()
	var inverse := _quartier.global_transform.affine_inverse()
	var origine := inverse * _camera.project_ray_origin(souris)
	var direction := (inverse.basis * _camera.project_ray_normal(souris)).normalized()
	if absf(direction.y) < 0.0001:
		_vise = false
		return
	var plus_haut := 0
	for j in _haut():
		for i in _large():
			plus_haut = maxi(plus_haut, _palier_de(i, j))
	for niveau in range(plus_haut, -1, -1):
		var t := (float(niveau) * PALIER - origine.y) / direction.y
		if t <= 0.0: continue
		var p := origine + direction * t
		var c := Vector2i(floori(p.x / CASE), floori(p.z / CASE))
		if _terre(c.x, c.y) and _palier_de(c.x, c.y) == niveau:
			_case = c; _vise = true; return
	var t0 := (float(_palier) * PALIER - origine.y) / direction.y
	if t0 <= 0.0:
		_vise = false
		return
	var p0 := origine + direction * t0
	_case = Vector2i(floori(p0.x / CASE), floori(p0.z / CASE))
	_vise = true

# ---------------------------------------------------------------- le geste

func _input(evenement: InputEvent) -> void:
	if evenement is InputEventMouseMotion:
		if _orbite:
			var m := evenement as InputEventMouseMotion
			_azimut -= m.relative.x * 0.006
			_inclinaison = clampf(_inclinaison + m.relative.y * 0.005, 0.14, 1.45)
			_poser_camera()
			return
		_viser()
		_montrer_curseur()
		if _peint:
			_appliquer(true)
		return
	if evenement is InputEventMouseButton:
		var b := evenement as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(50.0, _distance * 0.9); _poser_camera(); return
		if b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(6000.0, _distance * 1.1); _poser_camera(); return
		if b.button_index == MOUSE_BUTTON_MIDDLE:
			_orbite = b.pressed; return
		if get_viewport().gui_get_hovered_control() != null:
			return
		if b.button_index == MOUSE_BUTTON_LEFT or b.button_index == MOUSE_BUTTON_RIGHT:
			if b.pressed:
				_empiler()
				_peint = true
				_gauche = b.button_index == MOUSE_BUTTON_LEFT
				_viser()
				_appliquer(_gauche)
			else:
				_peint = false
				_finir_geste()
			return
	if evenement is InputEventKey and (evenement as InputEventKey).pressed:
		_touche(evenement as InputEventKey)

var _gauche := true

func _touche(k: InputEventKey) -> void:
	if k.ctrl_pressed and k.keycode == KEY_Z: _annuler(); return
	if k.ctrl_pressed and k.keycode == KEY_Y: _refaire_geste(); return
	match k.keycode:
		KEY_TAB:
			_outil = OUTIL_RELIEF if _outil == OUTIL_DESSIN else OUTIL_DESSIN
			if _bouton_relief != null:
				_bouton_relief.button_pressed = _outil == OUTIL_RELIEF
			for b in _boutons:
				if _outil == OUTIL_RELIEF: b.button_pressed = false
			_etat()
		KEY_R:
			_minuscule = not _minuscule
			_etat()
		KEY_PAGEUP, KEY_KP_ADD:
			_palier = mini(_palier + 1, 9); _etat()
		KEY_PAGEDOWN, KEY_KP_SUBTRACT:
			_palier = maxi(_palier - 1, 0); _etat()
		KEY_F:
			_recadrer()
		KEY_E:
			_exporter()

## Ce que le pinceau écrit vraiment : une famille passe en minuscule quand on
## le demande, pour poser deux bâtiments voisins sans qu'ils fusionnent.
func _caractere() -> String:
	if _minuscule and FAMILLES.contains(_pinceau):
		return _pinceau.to_lower()
	return _pinceau

func _appliquer(gauche: bool) -> void:
	if not _vise: return
	var i := _case.x
	var j := _case.y
	if i < 0 or j < 0 or i >= _large() or j >= _haut(): return
	if _outil == OUTIL_RELIEF:
		var n := _palier if gauche else 0
		if not gauche:
			n = maxi(0, _palier_de(i, j) - 1)
		if _palier_de(i, j) == n: return
		_ecrire("relief", i, j, str(n))
	else:
		var c := _caractere() if gauche else "."
		if _lire("plan", i, j) == c: return
		_ecrire("plan", i, j, c)
		# Une case qu'on sort de l'eau doit prendre le palier courant, sinon
		# elle arrive à zéro au milieu d'une terrasse.
		if c != "." and gauche:
			_ecrire("relief", i, j, str(_palier))
	_touchees[_case] = true
	_dalle(_case)
	_etat()

## L'aperçu : une dalle plate de la couleur du pinceau, posée tout de suite.
## Rebâtir le quartier à chaque case rendait le tracé d'une avenue impossible ;
## la dalle coûte un quad et dit exactement ce qu'on vient d'écrire.
func _dalle(c: Vector2i) -> void:
	var n := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(CASE * 0.92, CASE * 0.92)
	n.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = _couleur(_lire("plan", c.x, c.y))
	m.albedo_color.a = 0.85
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	n.material_override = m
	n.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
		Vector3((float(c.x) + 0.5) * CASE, float(_palier_de(c.x, c.y)) * PALIER + 1.2,
			(float(c.y) + 0.5) * CASE))
	_apercu.add_child(n)

func _couleur(c: String) -> Color:
	for p in PINCEAUX:
		if String(p[0]) == c or String(p[0]).to_lower() == c:
			return p[2]
	return Color("#ff00ff")

func _finir_geste() -> void:
	if _touchees.is_empty(): return
	_touchees.clear()
	_rebatir()

func _montrer_curseur() -> void:
	if _curseur == null: return
	_curseur.visible = _vise
	if not _vise: return
	_curseur.position = Vector3((float(_case.x) + 0.5) * CASE,
		float(_palier_de(_case.x, _case.y)) * PALIER + 0.4, (float(_case.y) + 0.5) * CASE)
	_etat()

# ---------------------------------------------------------------- annuler

func _empiler() -> void:
	_pile.append({"plan": _lignes("plan").duplicate(), "relief": _lignes("relief").duplicate()})
	if _pile.size() > 60: _pile.pop_front()
	_refaire.clear()

func _annuler() -> void:
	if _pile.is_empty(): return
	_refaire.append({"plan": _lignes("plan").duplicate(), "relief": _lignes("relief").duplicate()})
	_restaurer(_pile.pop_back())

func _refaire_geste() -> void:
	if _refaire.is_empty(): return
	_pile.append({"plan": _lignes("plan").duplicate(), "relief": _lignes("relief").duplicate()})
	_restaurer(_refaire.pop_back())

func _restaurer(etat: Dictionary) -> void:
	_fiche["plan"] = etat["plan"]
	_fiche["relief"] = etat["relief"]
	_rebatir()

# ---------------------------------------------------------------- caméra

func _process(delta: float) -> void:
	var d := Vector3.ZERO
	if Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): d.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): d.z += 1.0
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): d.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): d.x += 1.0
	if d == Vector3.ZERO: return
	# On se déplace dans le repère de la CAMÉRA : après une orbite, « avant »
	# doit rester ce qu'on voit en haut de l'écran.
	var avant := Vector3(sin(_azimut), 0, cos(_azimut))
	var droite := Vector3(cos(_azimut), 0, -sin(_azimut))
	_pivot += (avant * d.z + droite * d.x) * delta * _distance * 1.1
	_poser_camera()

func _poser_camera() -> void:
	var oeil := _pivot + Vector3(sin(_azimut) * cos(_inclinaison), sin(_inclinaison),
		cos(_azimut) * cos(_inclinaison)) * _distance
	_camera.look_at_from_position(oeil, _pivot, Vector3.UP)

func _recadrer() -> void:
	var org: Vector2 = _fiche.get("origine", Vector2.ZERO)
	var angle := deg_to_rad(float(_fiche.get("angle", 0.0)))
	var centre_local := Vector3(float(_large()) * 0.5 * CASE, 0, float(_haut()) * 0.5 * CASE)
	_pivot = Vector3(org.x * CASE, 0, org.y * CASE) + Basis(Vector3.UP, angle) * centre_local
	_distance = clampf(maxf(float(_large()), float(_haut())) * CASE * 1.25, 200.0, 4000.0)
	_poser_camera()

# ---------------------------------------------------------------- les fautes

## Les fautes du banc, posées SUR la case coupable. Un message dans un panneau
## se lit ; une croix rouge sur le carrefour fautif se comprend.
func _montrer_fautes() -> void:
	for e in _marques.get_children(): e.queue_free()
	var liste: Array = Quartiers.fautes(_fiche)
	var texte := ""
	for f in liste:
		texte += "• %s\n" % f["texte"] if int(f["i"]) < 0 \
			else "• (%d,%d) %s\n" % [f["i"], f["j"], f["texte"]]
		if int(f["i"]) < 0: continue
		var n := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(CASE * 0.5, CASE * 1.4, CASE * 0.5)
		n.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.85, 0.15, 0.15, 0.55)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		n.material_override = m
		n.position = Vector3((float(f["i"]) + 0.5) * CASE,
			float(_palier_de(int(f["i"]), int(f["j"]))) * PALIER + CASE * 0.7,
			(float(f["j"]) + 0.5) * CASE)
		_marques.add_child(n)
	if _fautes_texte != null:
		_fautes_texte.text = "PLAN PROPRE." if liste.is_empty() else texte
		_fautes_texte.add_theme_color_override("font_color",
			Palette.BON if liste.is_empty() else Palette.CRITIQUE)

# ---------------------------------------------------------------- agrandir

## Agrandir par un bord. Vers le NORD ou l'OUEST, la grille pousse ET l'origine
## recule d'autant : sans ça le quartier se déplacerait dans le monde à chaque
## rangée ajoutée, et les ponts ne tomberaient plus en face.
func _agrandir(cote: String) -> void:
	_empiler()
	var l := _large()
	var lignes: Array = _lignes("plan")
	var reliefs: Array = _lignes("relief")
	match cote:
		"est":
			for j in lignes.size():
				lignes[j] = String(lignes[j]).rpad(l + 1, ".")
				reliefs[j] = String(reliefs[j]).rpad(l + 1, "0")
		"ouest":
			for j in lignes.size():
				lignes[j] = "." + String(lignes[j])
				reliefs[j] = "0" + String(reliefs[j])
			_fiche["origine"] = (_fiche["origine"] as Vector2) - Vector2(1, 0)
		"sud":
			lignes.append(".".repeat(l))
			reliefs.append("0".repeat(l))
		"nord":
			lignes.insert(0, ".".repeat(l))
			reliefs.insert(0, "0".repeat(l))
			_fiche["origine"] = (_fiche["origine"] as Vector2) - Vector2(0, 1)
	_rebatir()

func _tourner(pas: float) -> void:
	_fiche["angle"] = snappedf(float(_fiche.get("angle", 0.0)) + pas, 0.5)
	_rebatir()

func _deplacer(pas: Vector2) -> void:
	_fiche["origine"] = (_fiche.get("origine", Vector2.ZERO) as Vector2) + pas
	_rebatir()

## Un quartier NEUF : une grille vide posée à côté du courant, tournée
## autrement. On garde les teintes et les hauteurs du quartier d'où l'on part —
## il est plus rapide de les corriger que de les retaper.
func _nouveau() -> void:
	var modele: Dictionary = _fiche.duplicate(true)
	modele["nom"] = "Quartier neuf"
	modele["angle"] = snappedf(float(_fiche.get("angle", 0.0)) + 17.0, 0.5)
	modele["origine"] = (_fiche.get("origine", Vector2.ZERO) as Vector2) + Vector2(float(_large()) + 4.0, 6.0)
	modele["graine"] = randi() % 9000 + 1
	var plan: Array = []
	var relief: Array = []
	for j in 12:
		plan.append(",".repeat(16))
		relief.append("0".repeat(16))
	modele["plan"] = plan
	modele["relief"] = relief
	_id = "neuf"
	_fiche = modele
	_pile.clear(); _refaire.clear()
	_rebatir()
	_recadrer()
	_dire("Quartier neuf. Dessine-le, puis « Exporter » et colle le bloc dans Quartiers.CATALOGUE.")

func _dire(message: String) -> void:
	if _fautes_texte != null:
		_fautes_texte.text = message

# ---------------------------------------------------------------- l'export

## LE BLOC À RECOLLER dans `Quartiers.CATALOGUE`. C'est la sortie de
## l'éditeur : pas un fichier à part, le texte exact du catalogue. On le met au
## presse-papier ET dans une fenêtre — dans le navigateur, l'écriture du
## presse-papier passe, sa lecture non, et il faut pouvoir sélectionner à la
## main.
func _texte_fiche() -> String:
	var org: Vector2 = _fiche.get("origine", Vector2.ZERO)
	var t := "\t\"%s\": {\n" % _id
	t += "\t\t\"nom\": \"%s\", \"origine\": Vector2(%s, %s), \"angle\": %s, \"graine\": %d,\n" % [
		_fiche.get("nom", _id), _nombre(org.x), _nombre(org.y),
		_nombre(float(_fiche.get("angle", 0.0))), int(_fiche.get("graine", 1))]
	t += "\t\t\"herbe\": Color(\"%s\"), \"roche\": Color(\"%s\"),\n" % [
		"#" + (_fiche.get("herbe", Color.WHITE) as Color).to_html(false),
		"#" + (_fiche.get("roche", Color.WHITE) as Color).to_html(false)]
	var h: Dictionary = _fiche.get("hauteurs", {})
	var morceaux: Array[String] = []
	for cle in h.keys():
		morceaux.append("\"%s\": [%s, %s]" % [cle, _nombre(float(h[cle][0])), _nombre(float(h[cle][1]))])
	t += "\t\t\"hauteurs\": {%s},\n" % ", ".join(morceaux)
	for cle in ["plan", "relief"]:
		t += "\t\t\"%s\": [\n" % cle
		for ligne in _lignes(cle):
			t += "\t\t\t\"%s\",\n" % String(ligne)
		t += "\t\t],\n"
	return t + "\t},\n"

static func _nombre(v: float) -> String:
	return ("%d" % int(v)) + (".0" if absf(v - float(int(v))) < 0.001 else "") \
		if absf(v - roundf(v)) < 0.001 else ("%.1f" % v)

func _exporter() -> void:
	var t := _texte_fiche()
	DisplayServer.clipboard_set(t)
	var f := FileAccess.open("user://quartier_%s.txt" % _id, FileAccess.WRITE)
	if f != null:
		f.store_string(t); f.close()
	_montrer_texte(t)

var _boite: Window
var _zone: TextEdit

func _montrer_texte(t: String) -> void:
	if _boite == null:
		_boite = Window.new()
		_boite.size = Vector2i(860, 560)
		_boite.title = "À recoller dans Quartiers.CATALOGUE (déjà copié)"
		_boite.close_requested.connect(func(): _boite.hide())
		_zone = TextEdit.new()
		_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
		_boite.add_child(_zone)
		interface().add_child(_boite)
	_zone.text = t
	_boite.popup_centered()

# ---------------------------------------------------------------- interface

var _etiquette: Label
var _fautes_texte: Label
var _boutons: Array[Button] = []
var _choix_quartier: OptionButton
var _bouton_relief: Button

## Un bouton de la colonne : il ne doit JAMAIS réclamer plus de largeur que la
## colonne, sinon c'est lui qui décide de la taille du panneau.
func _petit(b: Button) -> Button:
	b.clip_text = true
	b.custom_minimum_size = Vector2(0, 0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# La police pixel de la maison n'est nette qu'à 11 ou 22 ; à 22 les
	# libellés de la colonne sortaient rognés à trois lettres. Onze, c'est la
	# taille des mentions — ici c'est le seul moyen de les lire en entier.
	b.add_theme_font_size_override("font_size", 11)
	return b

func _interface() -> void:
	var couche := interface()
	var colonne := UI.panneau(Palette.SERIE)
	colonne.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	colonne.offset_left = 8
	colonne.offset_right = 336
	colonne.offset_top = 8
	colonne.offset_bottom = -8
	couche.add_child(colonne)
	var defilement := ScrollContainer.new()
	defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defilement.custom_minimum_size = Vector2(306, 0)
	defilement.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	colonne.add_child(defilement)
	var boite := VBoxContainer.new()
	boite.add_theme_constant_override("separation", 5)
	boite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defilement.add_child(boite)

	boite.add_child(UI.titre("EDITEUR", 16))
	_choix_quartier = OptionButton.new()
	for id in Quartiers.CATALOGUE.keys():
		_choix_quartier.add_item(String(Quartiers.CATALOGUE[id]["nom"]))
	_choix_quartier.item_selected.connect(func(k):
		_charger(String(Quartiers.CATALOGUE.keys()[k])))
	boite.add_child(_choix_quartier)

	boite.add_child(UI.texte("VÉRIFICATION", 12, Palette.ENCRE_FAIBLE))
	_fautes_texte = UI.texte("", 12, Palette.ENCRE_DOUCE, true)
	boite.add_child(_fautes_texte)

	var barre := HBoxContainer.new()
	boite.add_child(barre)
	for f in [["Exporter", _exporter], ["Recharger", func(): _charger(_id)], ["Nouveau", _nouveau]]:
		var b := UI.bouton(String(f[0]))
		_petit(b)
		b.pressed.connect(f[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		barre.add_child(b)

	# L'ANGLE et la POSITION du quartier. C'est là que se joue le « moins
	# carré » : deux quartiers voisins qui n'ont pas le même angle cassent le
	# damier mieux que n'importe quelle rue courbe. Sans ces boutons, l'angle
	# n'était modifiable qu'en éditant le fichier à la main.
	boite.add_child(UI.texte("ANGLE ET POSITION", 12, Palette.ENCRE_FAIBLE))
	var rangA := HBoxContainer.new()
	boite.add_child(rangA)
	for f3 in [["−5°", -5.0], ["+5°", 5.0], ["−1°", -1.0], ["+1°", 1.0]]:
		var b5 := UI.bouton(String(f3[0]))
		_petit(b5)
		b5.pressed.connect(_tourner.bind(float(f3[1])))
		b5.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rangA.add_child(b5)
	var rangB := HBoxContainer.new()
	boite.add_child(rangB)
	for f4 in [["O", Vector2(-1, 0)], ["N", Vector2(0, -1)], ["S", Vector2(0, 1)], ["E", Vector2(1, 0)]]:
		var b6 := UI.bouton(String(f4[0]))
		_petit(b6)
		b6.pressed.connect(_deplacer.bind(f4[1]))
		b6.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rangB.add_child(b6)

	boite.add_child(UI.texte("AGRANDIR LA GRILLE", 12, Palette.ENCRE_FAIBLE))
	var croix := HBoxContainer.new()
	boite.add_child(croix)
	for f2 in [["+O", "ouest"], ["+N", "nord"], ["+S", "sud"], ["+E", "est"]]:
		var b2 := UI.bouton(String(f2[0]))
		_petit(b2)
		b2.pressed.connect(_agrandir.bind(String(f2[1])))
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		croix.add_child(b2)

	boite.add_child(UI.texte("RELIEF   (Tab)", 12, Palette.ENCRE_FAIBLE))
	var rang := HBoxContainer.new()
	boite.add_child(rang)
	_bouton_relief = UI.bouton("Outil relief", false)
	_petit(_bouton_relief)
	_bouton_relief.pressed.connect(func():
		_outil = OUTIL_RELIEF
		for b4 in _boutons: b4.button_pressed = false
		_etat())
	_bouton_relief.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rang.add_child(_bouton_relief)
	var moins := UI.bouton("−")
	_petit(moins)
	moins.pressed.connect(func(): _palier = maxi(0, _palier - 1); _etat())
	rang.add_child(moins)
	var plus := UI.bouton("+")
	_petit(plus)
	plus.pressed.connect(func(): _palier = mini(9, _palier + 1); _etat())
	rang.add_child(plus)

	boite.add_child(UI.texte("PINCEAU   (R : MAJ/min)", 12, Palette.ENCRE_FAIBLE))
	var grille := GridContainer.new()
	grille.columns = 2
	boite.add_child(grille)
	for p in PINCEAUX:
		var b3 := UI.bouton("%s  %s" % [p[0], p[1]], String(p[0]) == _pinceau)
		_petit(b3)
		b3.pressed.connect(_choisir.bind(String(p[0])))
		b3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_boutons.append(b3)
		grille.add_child(b3)

	var bas := UI.panneau(Palette.AVERTISSEMENT)
	bas.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bas.offset_left = 352
	bas.offset_right = -8
	bas.offset_top = -104
	bas.offset_bottom = -8
	couche.add_child(bas)
	_etiquette = UI.texte("", 12, Palette.ENCRE_DOUCE, true)
	bas.add_child(_etiquette)

func _choisir(c: String) -> void:
	_pinceau = c
	_outil = OUTIL_DESSIN
	for k in _boutons.size():
		_boutons[k].button_pressed = String(PINCEAUX[k][0]) == c
	if _bouton_relief != null: _bouton_relief.button_pressed = false
	_etat()

func _etat() -> void:
	if _etiquette == null: return
	var quoi := "RELIEF — palier %d" % _palier if _outil == OUTIL_RELIEF \
		else "DESSIN — pinceau « %s »" % _caractere()
	_etiquette.text = "%s   ·   case (%d, %d)   palier %d   ·   grille %d × %d   ·   angle %s°   origine (%s, %s)\n%s\nZQSD : se déplacer · molette : zoom · clic milieu : tourner · clic : peindre · clic droit : effacer (eau) · Tab : dessin/relief · Pg↑/Pg↓ : palier · R : MAJ/min · F : recadrer · E : exporter · Ctrl+Z" % [
		quoi, _case.x, _case.y, _palier_de(_case.x, _case.y), _large(), _haut(),
		_nombre(float(_fiche.get("angle", 0.0))),
		_nombre((_fiche.get("origine", Vector2.ZERO) as Vector2).x),
		_nombre((_fiche.get("origine", Vector2.ZERO) as Vector2).y),
		"Le relâchement du clic rebâtit le quartier ; pendant le geste, les dalles de couleur montrent ce qui est écrit."]
