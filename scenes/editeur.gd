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
## LES CINQ DÉCISIONS QUI COMPTENT
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
## 4. LE GESTE A UNE FORME : libre, ligne, rectangle, rectangle plein, godet,
##    pipette. Une avenue de trente cases peinte case par case, c'est trente
##    occasions de rater la ligne droite — et la ville est faite de lignes
##    droites. La forme est choisie une fois, elle vaut pour le dessin ET pour
##    le relief.
## 5. LE TRAVAIL EN COURS EST GARDÉ (`user://brouillon_<id>.json`, donc dans
##    le navigateur en ligne). Un onglet fermé par erreur ne coûte plus le
##    quartier. La VÉRITÉ reste le catalogue : « Recharger » jette le
##    brouillon et repart du fichier.

const CASE := CarteVille.CASE
const PALIER := CarteVille.PALIER

## Les quatre côtés, pour le godet. En dur plutôt qu'empruntés à `CarteVille` :
## un remplissage n'a pas à dépendre du modèle de carte du jeu.
const COTES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## La palette, dans l'ordre où on s'en sert : le sol, puis ce qui pousse, puis
## ce qui se bâtit — et c'est CET ordre que suivent les touches 1‑9 puis
## Maj+1‑9. La couleur sert à l'aperçu du geste ET à la mini-carte.
const PINCEAUX := [
	["#", "Rue", Color("#7d828c")],
	["=", "Pont", Color("#9aa0a8")],
	["O", "Rond-point", Color("#5f6874")],
	[".", "Eau", Color("#2b5f7a")],
	["~", "Mouillage", Color("#1f4d63")],
	[",", "Pelouse", Color("#7f9464")],
	[";", "Sable", Color("#d9c9a2")],
	["o", "Esplanade", Color("#b9b6ac")],
	["P", "Parking", Color("#a8a49c")],
	["^", "Arbres", Color("#4f7a3a")],
	["'", "Buissons", Color("#6d8a4a")],
	["X", "Dépôt", Color("#c0784a")],
	["%", "Chantier", Color("#d9a441")],
	["T", "Tour", Color("#3f6f8f")],
	["B", "Bureau", Color("#8fa3b5")],
	["C", "Commerce", Color("#c8553a")],
	["M", "Maison", Color("#e8d8b8")],
	["V", "Vieille", Color("#d29a5e")],
	["H", "Hangar", Color("#7d8a8f")],
]
## Les familles s'écrivent aussi en minuscule : deux bâtiments de même famille
## côte à côte fusionnent en un seul s'ils portent la même lettre.
const FAMILLES := "TBCMVH"
## Ce qui roule : rue, pont, rond-point. La mini-carte les fonce pour que le
## plan de rues se détache des façades.
const CHAUSSEE := "#=O"
const TEINTE_VOIE := Color("#3f444d")
## La rampe du relief : du vert du niveau de la mer au rouge des hauteurs. Dix
## crans, parce que la grille en autorise dix — même si la ville n'en use que six.
const RAMPE := [
	Color("#40704f"), Color("#5e8656"), Color("#8c9658"), Color("#b09656"),
	Color("#c48454"), Color("#d67860"), Color("#dd6f74"), Color("#e0708c"),
	Color("#e07aa6"), Color("#e089bf"),
]
## Ce qui n'est PAS de la terre : l'eau nue et le mouillage du port. Une case
## d'eau ne prend pas de palier, et la visée ne s'y pose pas.
const EAUX := ".~"

enum { OUTIL_DESSIN, OUTIL_RELIEF }
enum { FORME_LIBRE, FORME_LIGNE, FORME_CADRE, FORME_PLEIN, FORME_GODET, FORME_PIPETTE }

## La forme du geste, son libellé et sa touche. L'ordre est celui des boutons.
const FORMES := [
	[FORME_LIBRE, "Libre", "B"],
	[FORME_LIGNE, "Ligne", "L"],
	[FORME_CADRE, "Cadre", "K"],
	[FORME_PLEIN, "Plein", "J"],
	[FORME_GODET, "Godet", "G"],
	[FORME_PIPETTE, "Pipette", "I"],
]

var _id := "pikstown"
var _fiche: Dictionary = {}
var _quartier: Node3D
var _decor: Node3D                      ## les autres quartiers, pour le contexte
var _apercu: Node3D                     ## les dalles du geste en cours
var _marques: Node3D                    ## les blocs rouges des fautes
var _ville: VilleMorcelee               ## le décor, bâti par morceaux
var _maillage: MeshInstance3D           ## le quadrillage posé au sol
var _nappe: MeshInstance3D              ## le plan du palier courant, en relief
var _curseur: MeshInstance3D
var _camera: Camera3D

var _outil := OUTIL_DESSIN
var _forme := FORME_LIBRE
var _pinceau := "#"
var _minuscule := false
var _palier := 0
var _voir_grille := true
var _relief_relatif := false
var _carte_relief := false
var _dessus := false

var _pivot := Vector3.ZERO
var _distance := 500.0
var _azimut := 0.75
var _inclinaison := 0.55
var _azimut_avant := 0.75
var _inclinaison_avant := 0.55

## ⚠ TROIS CACHES, ET CE NE SONT PAS DES OPTIMISATIONS PRÉMATURÉES. Sur les
## six petits quartiers d'avant, `_large()`, `_haut()` et le calcul du palier
## le plus haut coûtaient quelques centaines d'itérations : on pouvait les
## appeler à chaque mouvement de souris. Sur Pikstown ils en coûtent 48 375
## CHACUN, et la visée les appelle à chaque pixel parcouru — l'éditeur passait
## sous la seconde par image avant d'avoir posé une case.
var _large_cache := 0
var _haut_cache := 0
var _plus_haut := 0

var _case := Vector2i.ZERO
var _depart := Vector2i.ZERO
var _vise := false
var _peint := false
var _peint_carte := false
var _gauche := true
var _orbite := false
var _pile: Array = []
var _refaire: Array = []
var _touchees: Dictionary = {}
var _fautives: Dictionary = {}

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
	# `--essai-dessus` prépare l'écran le plus dur à vérifier de mémoire : le
	# relief au palier 3, un rectangle en aperçu, la vue de dessus et le
	# quadrillage — tout ce qui ne se voit QUE sur une photo. Il n'écrit rien.
	if "--essai-dessus" in OS.get_cmdline_args():
		_outil = OUTIL_RELIEF
		_relief_relatif = true
		_carte_relief = true
		_redessiner_carte()
		_palier = 3
		_forme = FORME_PLEIN
		_gauche = true
		_depart = Vector2i(4, 4)
		_case = Vector2i(mini(11, _large() - 1), mini(9, _haut() - 1))
		_apercu_forme()
		_rafraichir_boutons()
		_vue_dessus()
	# ⚠ L'ALLER-RETOUR. `--essai-export=<fichier>` ressort le dessin SANS y avoir
	# touché : ce qui sort doit être exactement ce qui est entré. Un export qui
	# perd une ligne, décale une colonne ou casse une chaîne, on ne s'en aperçoit
	# qu'en le recollant dans le projet — c'est-à-dire une fois le dessin perdu.
	for a in OS.get_cmdline_args():
		if a.begins_with("--essai-export="):
			var chemin := a.substr(15)
			var f2 := FileAccess.open(chemin, FileAccess.WRITE)
			if f2 != null:
				f2.store_string(_texte_source())
				f2.close()
				print("export écrit : ", chemin)
			get_tree().quit()
			return
	if "--essai-editeur" in OS.get_cmdline_args():
		_essai()
	for a in OS.get_cmdline_args():
		if a.begins_with("--photo-editeur="):
			_photo = a.substr(16)
			get_tree().process_frame.connect(_photographier)

## LE BANC. Il peint par le code exactement ce que la souris peindrait — et il
## se sert des FORMES, sinon elles ne seraient vérifiées nulle part.
func _essai() -> void:
	_empiler()
	_depart = Vector2i(2, 16)                    # une avenue en travers, à la ligne
	_case = Vector2i(13, 16)
	_forme = FORME_LIGNE
	_appliquer_forme(true)
	_choisir("T")
	_forme = FORME_PLEIN                         # un bloc de tours au bord de l'eau
	_depart = Vector2i(6, 17)
	_case = Vector2i(8, 18)
	_appliquer_forme(true)
	_outil = OUTIL_RELIEF                        # une terrasse au godet
	_palier = 3
	_forme = FORME_CADRE
	_depart = Vector2i(2, 1)
	_case = Vector2i(5, 1)
	_appliquer_forme(true)
	_forme = FORME_LIBRE
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
	if not Quartiers.CATALOGUE.has(id):
		return
	_id = id
	# Une COPIE PROFONDE : on ne veut surtout pas modifier le catalogue en
	# mémoire, sinon « recharger » ne recharge rien.
	_fiche = (Quartiers.CATALOGUE[id] as Dictionary).duplicate(true)
	_pile.clear(); _refaire.clear()
	var repris := _reprendre_brouillon()
	_rebatir()
	_recadrer()
	_synchroniser_liste()
	if repris:
		_dire("Brouillon repris — il était gardé dans ce navigateur. « Recharger » revient au catalogue.")
	else:
		_dire("")

## ⚠ ON NE REBÂTIT PLUS LA VILLE, ON LA SUIT. Pikstown coûte quatre secondes et
## cinquante-quatre mille nœuds : rebâtir tout au relâchement de chaque coup de
## pinceau, c'était quatre secondes par case peinte. Le décor passe donc par
## `VilleMorcelee`, qui bâtit les morceaux autour du pivot de la caméra ; et
## `_finir_geste` ne refait que les morceaux touchés.
func _rebatir() -> void:
	_remesurer()
	if _quartier != null: _quartier.queue_free()
	_quartier = Node3D.new()
	_quartier.name = "Repere_" + _id
	var org: Vector2 = _fiche.get("origine", Vector2.ZERO)
	_quartier.transform = Transform3D(
		Basis(Vector3.UP, deg_to_rad(float(_fiche.get("angle", 0.0)))),
		Vector3(org.x * CASE, 0, org.y * CASE))
	monde().add_child(_quartier)
	if _ville != null: _ville.queue_free()
	_ville = VilleMorcelee.new()
	monde().add_child(_ville)
	# ⚠ TROIS MORCEAUX PAR IMAGE, pas un. Dans le jeu, un à-coup de 124 ms se
	# paye en pilotage ; dans l'éditeur on ne pilote rien, et attendre vingt
	# secondes que le quartier paraisse coûte bien plus cher que trois images
	# sautées.
	_ville.par_image = 3
	_ville.regler(_fiche, _id, _rayon_utile())
	_ville.suivre(_pivot)

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
	_poser_maillage()
	_poser_nappe()
	_montrer_fautes()
	_redessiner_carte()
	_etat()


## LE RAYON SUIT LE ZOOM. Un rayon fixe ne peut pas convenir aux deux bouts :
## à trois morceaux, la vue d'ensemble de Pikstown ne montre qu'un huitième de
## l'île ; à dix, un simple coup d'œil sur un pâté en bâtit cent soixante-neuf
## et l'éditeur met vingt secondes à s'ouvrir. On demande donc exactement de
## quoi remplir ce qu'on regarde.
func _rayon_utile() -> int:
	var cases := _distance / CASE
	return clampi(int(cases / float(VilleMorcelee.COTE)) + 1, 2, 6)

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

# ------------------------------------------------------- les repères au sol

## LE QUADRILLAGE. Sans lui on vise une case en la devinant entre deux toits :
## le curseur dit où l'on est, il ne dit pas où sont les autres cases. Les
## lignes de cinq sont plus franches — on compte par cinq, pas par un — et le
## contour du quartier est de la couleur du panneau, pour qu'on voie d'un coup
## d'œil ce qui appartient au quartier COURANT et ce qui est le décor voisin.
func _poser_maillage() -> void:
	var l := _large()
	var h := _haut()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var y := 0.35
	for i in range(0, l + 1):
		var c := _teinte_ligne(i, l)
		im.surface_set_color(c)
		im.surface_add_vertex(Vector3(float(i) * CASE, y, 0.0))
		im.surface_set_color(c)
		im.surface_add_vertex(Vector3(float(i) * CASE, y, float(h) * CASE))
	for j in range(0, h + 1):
		var c2 := _teinte_ligne(j, h)
		im.surface_set_color(c2)
		im.surface_add_vertex(Vector3(0.0, y, float(j) * CASE))
		im.surface_set_color(c2)
		im.surface_add_vertex(Vector3(float(l) * CASE, y, float(j) * CASE))
	im.surface_end()
	_maillage = MeshInstance3D.new()
	_maillage.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_maillage.material_override = m
	_maillage.visible = _voir_grille
	_quartier.add_child(_maillage)

func _teinte_ligne(k: int, fin: int) -> Color:
	if k == 0 or k == fin:
		return Color(0.22, 0.53, 0.90, 0.85)
	if k % 5 == 0:
		return Color(1, 1, 1, 0.30)
	return Color(1, 1, 1, 0.11)

## LE PALIER COURANT, en relief : un voile posé à la hauteur où l'on peint. Un
## chiffre dans un panneau ne dit pas si l'on est au-dessus ou en dessous du
## toit qu'on regarde ; ce plan-là le dit.
func _poser_nappe() -> void:
	_nappe = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(float(_large()) * CASE, float(_haut()) * CASE)
	_nappe.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.35, 0.68, 1.0, 0.12)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_nappe.material_override = m
	_nappe.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)
	_nappe.visible = false
	_quartier.add_child(_nappe)

func _regler_nappe() -> void:
	if _nappe == null: return
	_nappe.visible = _outil == OUTIL_RELIEF
	_nappe.position = Vector3(float(_large()) * 0.5 * CASE,
		float(_palier) * PALIER + 0.6, float(_haut()) * 0.5 * CASE)

# ---------------------------------------------------------------- la grille

func _lignes(cle: String) -> Array:
	return _fiche[cle]

func _large() -> int:
	return _large_cache

func _haut() -> int:
	return _haut_cache

## À rappeler après TOUT changement de taille de grille ou de relief : agrandir
## un bord, charger, annuler, reprendre un brouillon.
func _remesurer() -> void:
	_large_cache = 0
	for ligne in _lignes("plan"):
		_large_cache = maxi(_large_cache, String(ligne).length())
	_haut_cache = _lignes("plan").size()
	_plus_haut = 0
	for l in _lignes("relief"):
		var ligne := String(l)
		for k in ligne.length():
			var c := ligne[k]
			if c > "0" and c <= "9":
				_plus_haut = maxi(_plus_haut, int(c))

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
	return not EAUX.contains(_lire("plan", i, j))

func _dans_grille(i: int, j: int) -> bool:
	return i >= 0 and j >= 0 and i < _large() and j < _haut()

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
	for niveau in range(_plus_haut, -1, -1):
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
			_dessus = false
			_poser_camera()
			return
		_viser()
		_montrer_curseur()
		if _peint:
			if _forme == FORME_LIBRE:
				_appliquer(_gauche)
			else:
				_apercu_forme()
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
				_commencer(b.button_index == MOUSE_BUTTON_LEFT, b.alt_pressed)
			else:
				_relacher()
			return
	if evenement is InputEventKey and (evenement as InputEventKey).pressed:
		_touche(evenement as InputEventKey)

## Le début d'un geste. La PIPETTE et le GODET n'ont pas de durée : ils
## agissent au clic et il n'y a rien à faire au relâchement — d'où leur sortie
## avant que `_peint` ne soit levé.
func _commencer(gauche: bool, alt: bool) -> void:
	_viser()
	if not _vise: return
	_gauche = gauche
	_depart = _case
	if alt or _forme == FORME_PIPETTE:
		_prelever()
		return
	if _forme == FORME_GODET:
		_empiler()
		_remplir(_case, gauche)
		_finir_geste()
		return
	_empiler()
	_peint = true
	if _forme == FORME_LIBRE:
		_appliquer(gauche)
	else:
		_apercu_forme()

func _relacher() -> void:
	if not _peint:
		return
	_peint = false
	if _forme != FORME_LIBRE:
		_appliquer_forme(_gauche)
	_finir_geste()

func _touche(k: InputEventKey) -> void:
	if k.ctrl_pressed and k.keycode == KEY_Z: _annuler(); return
	if k.ctrl_pressed and k.keycode == KEY_Y: _refaire_geste(); return
	# Les chiffres choisissent le pinceau : les neuf premiers, puis les neuf
	# suivants avec Maj. Dix-neuf pinceaux ne tiennent pas sur dix touches, et
	# lâcher la souris pour aller cliquer dans la colonne casse le geste.
	# ⚠ `physical_keycode` et non `keycode` : sur un clavier AZERTY, la rangée
	# des chiffres se lit « & é " ' » sans Maj, et `keycode` rendrait donc
	# KEY_AMPERSAND là où l'on attend KEY_1. La position de la touche, elle, ne
	# dépend pas de la disposition.
	if k.physical_keycode >= KEY_1 and k.physical_keycode <= KEY_9:
		var rang := k.physical_keycode - KEY_1 + (9 if k.shift_pressed else 0)
		if rang < PINCEAUX.size(): _choisir(String(PINCEAUX[rang][0]))
		return
	match k.keycode:
		KEY_TAB:
			_outil = OUTIL_RELIEF if _outil == OUTIL_DESSIN else OUTIL_DESSIN
			_rafraichir_boutons()
			_etat()
		KEY_B: _choisir_forme(FORME_LIBRE)
		KEY_L: _choisir_forme(FORME_LIGNE)
		KEY_K: _choisir_forme(FORME_CADRE)
		KEY_J: _choisir_forme(FORME_PLEIN)
		KEY_G: _choisir_forme(FORME_GODET)
		KEY_I: _choisir_forme(FORME_PIPETTE)
		KEY_X: _basculer_grille()
		KEY_V: _vue_dessus()
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
	_poser(_case.x, _case.y, gauche)
	_etat()

## UNE case écrite. Tout passe par ici — la souris, les formes, le godet, la
## mini-carte et le banc — pour qu'il n'y ait qu'un seul endroit qui sache ce
## que « peindre » veut dire.
func _poser(i: int, j: int, gauche: bool) -> void:
	if not _dans_grille(i, j): return
	if _outil == OUTIL_RELIEF:
		# ⚠ ABSOLU OU RELATIF. En absolu, le pinceau POSE le palier courant —
		# c'est ce qu'il faut pour aplanir une terrasse. En relatif il monte ou
		# descend d'un cran ce qui est déjà là : c'est ce qu'il faut pour
		# creuser un vallon ou relever une rue, et sans lui il fallait relever
		# le palier de chaque case à la pipette avant de la peindre.
		var n := 0
		if _relief_relatif:
			n = clampi(_palier_de(i, j) + (1 if gauche else -1), 0, 9)
		else:
			n = _palier if gauche else maxi(0, _palier_de(i, j) - 1)
		if _palier_de(i, j) == n: return
		_ecrire("relief", i, j, str(n))
	else:
		var c := _caractere() if gauche else "."
		if _lire("plan", i, j) == c: return
		_ecrire("plan", i, j, c)
		# Une case qu'on sort de l'eau doit prendre le palier courant, sinon
		# elle arrive à zéro au milieu d'une terrasse.
		if gauche and not EAUX.contains(c):
			_ecrire("relief", i, j, str(_palier))
	_touchees[Vector2i(i, j)] = true
	_dalle(Vector2i(i, j), _teinte_pose(gauche))

## La couleur de l'aperçu. En relief elle éclaircit avec le palier : sinon
## trois terrasses de hauteurs différentes se ressemblent toutes.
func _teinte_pose(gauche: bool) -> Color:
	if _outil == OUTIL_RELIEF:
		var n := _palier if gauche else 0
		return Color(0.42, 0.55, 0.68).lightened(float(n) * 0.07)
	return _couleur(_caractere() if gauche else ".")

## L'aperçu : une dalle plate de la couleur du pinceau, posée tout de suite.
## Rebâtir le quartier à chaque case rendait le tracé d'une avenue impossible ;
## la dalle coûte un quad et dit exactement ce qu'on vient d'écrire.
func _dalle(c: Vector2i, teinte: Color) -> void:
	var n := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(CASE * 0.92, CASE * 0.92)
	n.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = teinte
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
	var cases: Array = _touchees.keys()
	_touchees.clear()
	_remesurer()
	if _ville != null:
		_ville.refaire(cases)
	for e in _apercu.get_children():
		_apercu.remove_child(e)
		e.queue_free()
	_montrer_fautes()
	_redessiner_carte()
	_etat()
	_sauver_brouillon()

func _montrer_curseur() -> void:
	if _curseur == null: return
	_curseur.visible = _vise
	if not _vise: return
	_curseur.position = Vector3((float(_case.x) + 0.5) * CASE,
		float(_palier_de(_case.x, _case.y)) * PALIER + 0.4, (float(_case.y) + 0.5) * CASE)
	_etat()

# ------------------------------------------------------- les formes du geste

func _choisir_forme(f: int) -> void:
	_forme = f
	_rafraichir_boutons()
	_etat()

## Les cases que couvre le geste en cours. La pipette et le godet n'ont pas de
## traînée : ils ne passent jamais par ici.
func _cases_forme() -> Array:
	var a := _depart
	var b := _case
	if _forme == FORME_LIGNE:
		return _tracer_ligne(a, b)
	if _forme == FORME_CADRE or _forme == FORME_PLEIN:
		var x0 := mini(a.x, b.x)
		var x1 := maxi(a.x, b.x)
		var y0 := mini(a.y, b.y)
		var y1 := maxi(a.y, b.y)
		var pts: Array = []
		for j in range(y0, y1 + 1):
			for i in range(x0, x1 + 1):
				if _forme == FORME_PLEIN or i == x0 or i == x1 or j == y0 or j == y1:
					pts.append(Vector2i(i, j))
		return pts
	return [b]

## Bresenham. Une ligne tirée à la souris qui « saute » des cases laisse des
## trous dans l'avenue — et un trou dans une rue, le jeu le voit comme une
## impasse.
static func _tracer_ligne(a: Vector2i, b: Vector2i) -> Array:
	var pts: Array = []
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var c := a
	while true:
		pts.append(c)
		if c == b or pts.size() > 4000: break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			c.x += sx
		if e2 <= dx:
			err += dx
			c.y += sy
	return pts

## L'aperçu d'une forme se REFAIT à chaque mouvement — on efface d'abord. Et
## on retire les dalles tout de suite au lieu de les mettre en file : un
## `queue_free` ne prend effet qu'en fin d'image, et pendant cette image-là on
## verrait les deux rectangles à la fois.
func _apercu_forme() -> void:
	if _apercu == null: return
	for e in _apercu.get_children():
		_apercu.remove_child(e)
		e.queue_free()
	var teinte := _teinte_pose(_gauche)
	for c in _cases_forme():
		if _dans_grille(c.x, c.y):
			_dalle(c, teinte)
	_etat()

func _appliquer_forme(gauche: bool) -> void:
	for c in _cases_forme():
		_poser(c.x, c.y, gauche)
	_etat()

## LE GODET. Il remplit la tache contiguë de même valeur — le plan en dessin,
## le relief en relief. Le plafond de six mille cases n'est pas de la prudence
## théorique : une grille de cent sur cent remplie d'un coup, dans le
## navigateur, c'est une image perdue à chaque clic.
func _remplir(depart: Vector2i, gauche: bool) -> void:
	var cle := "relief" if _outil == OUTIL_RELIEF else "plan"
	var source := _lire(cle, depart.x, depart.y)
	var cible := "0"
	if _outil == OUTIL_RELIEF:
		cible = str(_palier) if gauche else "0"
	else:
		cible = _caractere() if gauche else "."
	if source == cible: return
	var vues := {}
	var file: Array = [depart]
	var n := 0
	while not file.is_empty() and n < 6000:
		var c: Vector2i = file.pop_back()
		if vues.has(c): continue
		if not _dans_grille(c.x, c.y): continue
		if _lire(cle, c.x, c.y) != source: continue
		vues[c] = true
		n += 1
		_poser(c.x, c.y, gauche)
		for d in COTES:
			file.append(c + d)
	_etat()

## LA PIPETTE. Elle reprend ce qui est SOUS le curseur — en dessin le
## caractère, en relief le palier. C'est le geste qu'on fait vingt fois par
## séance : retrouver la teinte exacte du pâté d'à côté sans la chercher des
## yeux dans la colonne.
func _prelever() -> void:
	if not _vise or not _dans_grille(_case.x, _case.y): return
	if _outil == OUTIL_RELIEF:
		_palier = _palier_de(_case.x, _case.y)
		_dire("Palier %d prélevé." % _palier)
		_etat()
		return
	var c := _lire("plan", _case.x, _case.y)
	for p in PINCEAUX:
		if String(p[0]) == c or String(p[0]).to_lower() == c:
			_minuscule = c != String(p[0])
			_choisir(String(p[0]))
			_dire("Pinceau « %s » prélevé." % _caractere())
			return

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
	_sauver_brouillon()

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
	if _ville != null: _ville.suivre(_pivot)

func _poser_camera() -> void:
	var oeil := _pivot + Vector3(sin(_azimut) * cos(_inclinaison), sin(_inclinaison),
		cos(_azimut) * cos(_inclinaison)) * _distance
	_camera.look_at_from_position(oeil, _pivot, Vector3.UP)

func _recadrer() -> void:
	var org: Vector2 = _fiche.get("origine", Vector2.ZERO)
	var angle := deg_to_rad(float(_fiche.get("angle", 0.0)))
	var centre_local := Vector3(float(_large()) * 0.5 * CASE, 0, float(_haut()) * 0.5 * CASE)
	if _pivot != Vector3.ZERO and _distance <= 80.0 * CASE:
		# Recadrer depuis un point de travail garde ce point : on veut revenir
		# au pâté qu'on dessinait, pas au milieu de l'île.
		centre_local = _quartier.global_transform.affine_inverse() * _pivot \
			if _quartier != null else centre_local
	_pivot = Vector3(org.x * CASE, 0, org.y * CASE) + Basis(Vector3.UP, angle) * centre_local
	# ⚠ ON NE CADRE PAS UNE VILLE DE DEUX KILOMÈTRES COMME UN QUARTIER DE TRENTE
	# CASES. Cadrée en entier, Pikstown demande cent soixante-neuf morceaux au
	# chargement : vingt secondes d'écran presque vide. On cadre donc au plus un
	# voisinage de cinquante-six cases, et « F » depuis un point de la ville
	# recentre là où l'on travaille. La vue d'ensemble, c'est la mini-carte —
	# elle est faite pour ça, et elle est instantanée.
	var etendue := maxf(float(_large()), float(_haut())) * CASE * 1.25
	_distance = clampf(minf(etendue, 56.0 * CASE), 200.0, 4000.0)
	_poser_camera()
	if _ville != null:
		_ville.rayon = _rayon_utile()
		_ville.suivre(_pivot)

## LA VUE DE DESSUS, calée sur l'ANGLE DU QUARTIER — pas sur le nord du monde.
## Un quartier tourné de dix-sept degrés vu à plat depuis le nord se dessine en
## escalier ; vu depuis son propre angle, la grille redevient une grille et on
## peint une avenue droite sans compenser à l'œil.
func _vue_dessus() -> void:
	_dessus = not _dessus
	if _dessus:
		_azimut_avant = _azimut
		_inclinaison_avant = _inclinaison
		_azimut = deg_to_rad(float(_fiche.get("angle", 0.0)))
		_inclinaison = 1.45
	else:
		_azimut = _azimut_avant
		_inclinaison = _inclinaison_avant
	_recadrer()
	_rafraichir_boutons()

func _basculer_grille() -> void:
	_voir_grille = not _voir_grille
	if _maillage != null: _maillage.visible = _voir_grille
	_rafraichir_boutons()

# ---------------------------------------------------------------- les fautes

## Les fautes du banc, posées SUR la case coupable. Un message dans un panneau
## se lit ; un bloc rouge sur le carrefour fautif se comprend.
func _montrer_fautes() -> void:
	for e in _marques.get_children(): e.queue_free()
	var liste: Array = Quartiers.fautes(_fiche)
	_fautives.clear()
	var texte := ""
	var dites := 0
	for f in liste:
		# QUATRE fautes affichées, pas quinze : une colonne pleine de rouge
		# repousse le pinceau hors de l'écran, et on les corrige de toute
		# façon une par une. Le compte, lui, est toujours dit.
		if dites < 4:
			texte += "• %s\n" % f["texte"] if int(f["i"]) < 0 \
				else "• (%d,%d) %s\n" % [f["i"], f["j"], f["texte"]]
			dites += 1
		elif dites == 4:
			texte += "• … et %d autre(s).\n" % (liste.size() - 4)
			dites += 1
		if int(f["i"]) < 0: continue
		_fautives[Vector2i(int(f["i"]), int(f["j"]))] = true
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
	_sauver_brouillon()

func _tourner(pas: float) -> void:
	_fiche["angle"] = snappedf(float(_fiche.get("angle", 0.0)) + pas, 0.5)
	_rebatir()
	_sauver_brouillon()

func _deplacer(pas: Vector2) -> void:
	_fiche["origine"] = (_fiche.get("origine", Vector2.ZERO) as Vector2) + pas
	_rebatir()
	_sauver_brouillon()

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
	_sauver_brouillon()
	_dire("Quartier neuf. Dessine-le, puis « Exporter » et colle le bloc dans Quartiers.CATALOGUE.")

# ------------------------------------------------------------- le brouillon

## LE TRAVAIL EN COURS, gardé à côté du catalogue — jamais à sa place. En
## ligne, `user://` est l'IndexedDB du navigateur : fermer l'onglet ne coûte
## plus rien. Mais un brouillon N'EST PAS une source de vérité : il n'y a que
## le plan et le relief dedans, et « Recharger » le jette.
func _chemin_brouillon(id: String) -> String:
	return "user://brouillon_%s.json" % id

func _sauver_brouillon() -> void:
	var org: Vector2 = _fiche.get("origine", Vector2.ZERO)
	var d := {
		"nom": String(_fiche.get("nom", _id)),
		"angle": float(_fiche.get("angle", 0.0)),
		"origine": [org.x, org.y],
		"graine": int(_fiche.get("graine", 1)),
		"plan": _lignes("plan"),
		"relief": _lignes("relief"),
	}
	var f := FileAccess.open(_chemin_brouillon(_id), FileAccess.WRITE)
	if f == null: return
	f.store_string(JSON.stringify(d))
	f.close()

func _reprendre_brouillon() -> bool:
	var chemin := _chemin_brouillon(_id)
	if not FileAccess.file_exists(chemin): return false
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null: return false
	var brut := f.get_as_text()
	f.close()
	var d = JSON.parse_string(brut)
	if typeof(d) != TYPE_DICTIONARY: return false
	if not d.has("plan") or not d.has("relief"): return false
	var plan: Array = []
	for l in d["plan"]: plan.append(String(l))
	var relief: Array = []
	for l in d["relief"]: relief.append(String(l))
	if plan.is_empty() or relief.size() != plan.size(): return false
	_fiche["plan"] = plan
	_fiche["relief"] = relief
	_fiche["angle"] = float(d.get("angle", _fiche.get("angle", 0.0)))
	var o: Array = d.get("origine", [])
	if o.size() == 2: _fiche["origine"] = Vector2(float(o[0]), float(o[1]))
	if d.has("graine"): _fiche["graine"] = int(d["graine"])
	return true

func _recharger() -> void:
	var chemin := _chemin_brouillon(_id)
	if FileAccess.file_exists(chemin):
		DirAccess.remove_absolute(chemin)
	_charger(_id)
	_dire("Rechargé depuis le catalogue — le brouillon est jeté.")

# ---------------------------------------------------------------- l'export

## LE BLOC À RECOLLER dans `Quartiers.CATALOGUE`. C'est la sortie de
## l'éditeur : pas un fichier à part, le texte exact du catalogue. On le met au
## presse-papier ET dans une fenêtre — dans le navigateur, l'écriture du
## presse-papier passe, sa lecture non, et il faut pouvoir sélectionner à la
## main.
## ⚠ CE QUE L'ÉDITEUR REND DÉPEND DE L'ENDROIT OÙ LE DESSIN VIT. Tant qu'un
## quartier tenait en trente lignes, il vivait dans `Quartiers.CATALOGUE` et on
## recollait un bloc de dictionnaire. Pikstown fait 300 lignes de 320
## caractères : le dessin a son propre fichier (`PlanPikstown`), et un bloc de
## catalogue ne se recolle plus nulle part. On ressort donc LE FICHIER ENTIER,
## prêt à écraser `jeux/carnage/pikstown.gd`.
##
## La fiche (nom, origine, angle, graine, teintes, hauteurs) reste dans le
## catalogue et ne bouge presque jamais : elle a son propre bouton.
func _texte_source() -> String:
	var classe := String(_fiche.get("source", ""))
	var t := "class_name %s\n" % classe
	t += "extends RefCounted\n"
	t += "## LE DESSIN DE %s — %d x %d cases.\n" % [_fiche.get("nom", _id), _large(), _haut()]
	t += "##\n"
	t += "## Un caractère par case, le vocabulaire de `Quartiers`. Ressorti par\n"
	t += "## l'éditeur (`?ecran=editeur`) : ce fichier EST ce qu'on a dessiné.\n"
	t += "\n"
	t += "const LARGE := %d\n" % _large()
	t += "const HAUT := %d\n\n" % _haut()
	for cle in [["plan", "PLAN"], ["relief", "RELIEF"]]:
		t += "const %s: Array[String] = [\n" % cle[1]
		for ligne in _lignes(String(cle[0])):
			t += "\t\"%s\",\n" % String(ligne)
		t += "]\n\n"
	return t

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

## `E` sort LE DESSIN ; le bouton « Fiche » sort les quelques lignes de
## catalogue. C'est le dessin qu'on modifie cent fois par séance.
func _exporter() -> void:
	if String(_fiche.get("source", "")) != "":
		_sortir(_texte_source(), "pikstown.gd", "à écraser dans jeux/carnage/")
	else:
		_sortir(_texte_fiche(), "quartier_%s.txt" % _id, "à recoller dans Quartiers.CATALOGUE")

func _exporter_fiche() -> void:
	_sortir(_texte_fiche(), "fiche_%s.txt" % _id, "à recoller dans Quartiers.CATALOGUE")

func _sortir(t: String, nom: String, ou: String) -> void:
	DisplayServer.clipboard_set(t)
	var f := FileAccess.open("user://" + nom, FileAccess.WRITE)
	if f != null:
		f.store_string(t); f.close()
	_dire("%s copié (%d caractères) — %s" % [nom, t.length(), ou])
	_montrer_texte(t)

var _boite: Window
var _zone: TextEdit

func _montrer_texte(t: String) -> void:
	if _boite == null:
		_boite = Window.new()
		_boite.size = Vector2i(860, 560)
		_boite.title = "Déjà dans le presse-papier — sélectionnable ici au besoin"
		_boite.close_requested.connect(func(): _boite.hide())
		_zone = TextEdit.new()
		_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
		_boite.add_child(_zone)
		interface().add_child(_boite)
	_zone.text = t
	_boite.popup_centered()

# ---------------------------------------------------------------- interface

var _etiquette: Label
var _aide: Label
var _message: Label
var _fautes_texte: Label
var _boutons: Array[Button] = []
var _boutons_forme: Array[Button] = []
var _choix_quartier: OptionButton
var _bouton_relief: Button
var _bouton_dessin: Button
var _bouton_grille: Button
var _bouton_dessus: Button
var _bouton_relatif: Button
var _bouton_carte_relief: Button
var _carte2d: Control
var _carte_pas := 1.0
var _carte_org := Vector2.ZERO
var _carte_image: ImageTexture

## Un bouton de la colonne. Deux choses à savoir : il ne doit JAMAIS réclamer
## plus de largeur que la colonne — sinon c'est lui qui décide de la taille du
## panneau — et les marges de la charte (dix-huit pixels de chaque côté) sont
## faites pour des boutons d'accueil, pas pour dix-neuf pinceaux sur deux
## colonnes. On les resserre ici, et seulement ici.
func _petit(b: Button) -> Button:
	b.clip_text = true
	b.custom_minimum_size = Vector2(0, 0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# La police pixel de la maison n'est nette qu'à 11 ou 22 ; à 22 les
	# libellés de la colonne sortaient rognés à trois lettres.
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_constant_override("h_separation", 5)
	_teinter(b, false)
	return b

## L'ÉTAT D'UN BOUTON SE PEINT, il ne se déclare pas. La première version
## fabriquait le pinceau courant en « bouton principal » et changeait ensuite
## `button_pressed` — sur un bouton qui n'est pas en mode bascule, cela ne
## repeint rien : le surlignage restait collé sur « Rue » quoi qu'on clique.
func _teinter(b: Button, actif: bool) -> void:
	var teinte := Palette.SERIE if actif else Palette.SURFACE
	var encre := Palette.FOND if actif else Palette.ENCRE
	for etat in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		if etat == "hover":
			s.bg_color = teinte.lightened(0.14)
		elif etat == "pressed":
			s.bg_color = teinte.darkened(0.18)
		else:
			s.bg_color = teinte
		s.border_color = teinte.lightened(0.35) if actif else UI.CADRE
		s.set_border_width_all(UI.BORDURE)
		s.set_corner_radius_all(0)
		s.content_margin_left = 7
		s.content_margin_right = 7
		s.content_margin_top = 5
		s.content_margin_bottom = 5
		b.add_theme_stylebox_override(etat, s)
	b.add_theme_color_override("font_color", encre)
	b.add_theme_color_override("font_hover_color", encre)
	b.add_theme_color_override("font_pressed_color", encre)

## ⚠ LA VRAIE IMAGE DU PINCEAU, PHOTOGRAPHIÉE. `outils/vignettes.gd` bâtit une
## parcelle avec CE pinceau — par `Quartiers.batir_fiche`, la fonction du jeu —
## et la photographie. Un carré de couleur dit « du orange » ; la vignette dit
## « des conteneurs empilés et une cuve », et c'est ce qu'on cherche quand on
## hésite entre « Dépôt » et « Chantier ». C'est le geste des repaires, où
## aucune affirmation sur un modèle n'est admise sans photo.
##
## La pastille de couleur reste le SECOURS : si les vignettes n'ont pas été
## engendrées, la colonne garde ses repères de couleur au lieu de se vider.
static func _vignette(c: String) -> Texture2D:
	var chemin := "res://images/pinceaux/p%d.png" % c.unicode_at(0)
	if ResourceLoader.exists(chemin):
		return load(chemin) as Texture2D
	return null

## La pastille de couleur d'un pinceau. Un caractère et un mot ne disent pas de
## quelle couleur sera la case ; la mini-carte, elle, ne parle QUE couleur —
## sans pastille dans la colonne, les deux ne se répondent pas.
static func _pastille(c: Color) -> ImageTexture:
	var cote := 14
	var img := Image.create(cote, cote, false, Image.FORMAT_RGBA8)
	img.fill(c)
	var bord := Color(0, 0, 0, 0.65)
	for k in cote:
		img.set_pixel(k, 0, bord)
		img.set_pixel(k, cote - 1, bord)
		img.set_pixel(0, k, bord)
		img.set_pixel(cote - 1, k, bord)
	return ImageTexture.create_from_image(img)

func _rang_texte(boite: VBoxContainer, titre: String) -> HBoxContainer:
	boite.add_child(UI.texte(titre, 12, Palette.ENCRE_FAIBLE))
	var rang := HBoxContainer.new()
	rang.add_theme_constant_override("separation", 4)
	boite.add_child(rang)
	return rang

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
	# ⚠ AUCUNE largeur minimale ici. La première version en demandait 306 dans
	# un panneau de 328 dont les marges mangent déjà 52 : la colonne débordait
	# et le moteur rognait les libellés par la droite.
	defilement.custom_minimum_size = Vector2(0, 0)
	defilement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonne.add_child(defilement)
	var boite := VBoxContainer.new()
	boite.add_theme_constant_override("separation", 5)
	boite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defilement.add_child(boite)

	boite.add_child(UI.titre("EDITEUR", 16))
	_choix_quartier = OptionButton.new()
	_choix_quartier.clip_text = true
	for id in Quartiers.CATALOGUE.keys():
		_choix_quartier.add_item(String(Quartiers.CATALOGUE[id]["nom"]))
	_choix_quartier.item_selected.connect(func(k):
		_charger(String(Quartiers.CATALOGUE.keys()[k])))
	boite.add_child(_choix_quartier)

	_message = UI.texte("", 12, Palette.AVERTISSEMENT, true)
	_message.visible = false
	boite.add_child(_message)

	boite.add_child(UI.texte("VÉRIFICATION", 12, Palette.ENCRE_FAIBLE))
	_fautes_texte = UI.texte("", 12, Palette.ENCRE_DOUCE, true)
	boite.add_child(_fautes_texte)

	# LA MINI-CARTE. C'est le plan tel qu'il est ÉCRIT, pas tel qu'il est bâti :
	# vingt cases d'un pâté se lisent d'un coup, là où la vue 3D demande de
	# tourner autour. Et elle se peint — c'est le seul moyen de toucher une case
	# cachée sous un toit sans déplacer la caméra.
	var titre_plan := HBoxContainer.new()
	titre_plan.add_theme_constant_override("separation", 6)
	boite.add_child(titre_plan)
	var lbl := UI.texte("PLAN   (clic milieu : y aller)", 12, Palette.ENCRE_FAIBLE)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titre_plan.add_child(lbl)
	_bouton_carte_relief = UI.bouton("Relief")
	_petit(_bouton_carte_relief)
	_bouton_carte_relief.size_flags_horizontal = Control.SIZE_SHRINK_END
	_bouton_carte_relief.custom_minimum_size = Vector2(56, 0)
	_bouton_carte_relief.tooltip_text = "Montrer les paliers au lieu du dessin"
	_bouton_carte_relief.pressed.connect(func():
		_carte_relief = not _carte_relief
		_rafraichir_boutons()
		_redessiner_carte())
	titre_plan.add_child(_bouton_carte_relief)
	_carte2d = Control.new()
	_carte2d.custom_minimum_size = Vector2(0, 190)
	_carte2d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_carte2d.mouse_filter = Control.MOUSE_FILTER_STOP
	_carte2d.draw.connect(_dessiner_carte)
	_carte2d.gui_input.connect(_carte_souris)
	boite.add_child(_carte2d)

	# ⚠ L'ORDRE DE LA COLONNE EST UN ORDRE D'USAGE, PAS UN ORDRE DE MENU. On
	# change de pinceau cent fois par séance et d'angle de quartier une fois par
	# mois : la palette a donc la place du dessus, juste sous le plan, et
	# l'angle descend en bas. Dans la version précédente le pinceau était
	# dernier — il fallait faire défiler la colonne à chaque changement de
	# couleur, sur l'écran d'un éditeur de carte.
	var rang := _rang_texte(boite, "OUTIL   (Tab)")
	_bouton_dessin = UI.bouton("Dessin")
	_petit(_bouton_dessin)
	_bouton_dessin.pressed.connect(func():
		_outil = OUTIL_DESSIN
		_rafraichir_boutons()
		_etat())
	rang.add_child(_bouton_dessin)
	_bouton_relief = UI.bouton("Relief")
	_petit(_bouton_relief)
	_bouton_relief.pressed.connect(func():
		_outil = OUTIL_RELIEF
		_rafraichir_boutons()
		_etat())
	rang.add_child(_bouton_relief)
	var moins := UI.bouton("−")
	_petit(moins)
	moins.custom_minimum_size = Vector2(30, 0)
	moins.size_flags_horizontal = Control.SIZE_SHRINK_END
	moins.pressed.connect(func(): _palier = maxi(0, _palier - 1); _etat())
	rang.add_child(moins)
	var plus := UI.bouton("+")
	_petit(plus)
	plus.custom_minimum_size = Vector2(30, 0)
	plus.size_flags_horizontal = Control.SIZE_SHRINK_END
	plus.pressed.connect(func(): _palier = mini(9, _palier + 1); _etat())
	rang.add_child(plus)
	_bouton_relatif = UI.bouton("± Relatif")
	_petit(_bouton_relatif)
	_bouton_relatif.tooltip_text = "Monter / descendre d'un cran au lieu de poser le palier courant"
	_bouton_relatif.pressed.connect(func():
		_relief_relatif = not _relief_relatif
		_outil = OUTIL_RELIEF
		_rafraichir_boutons()
		_etat())
	boite.add_child(_bouton_relatif)

	# LA FORME DU GESTE. Elle vaut pour le dessin ET pour le relief : une
	# terrasse rectangulaire au godet et une avenue à la ligne, c'est le même
	# outil vu de deux côtés.
	boite.add_child(UI.texte("FORME DU GESTE", 12, Palette.ENCRE_FAIBLE))
	var colF := GridContainer.new()
	colF.columns = 3
	colF.add_theme_constant_override("h_separation", 4)
	colF.add_theme_constant_override("v_separation", 4)
	colF.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boite.add_child(colF)
	for f6 in FORMES:
		var bf := UI.bouton("%s  %s" % [String(f6[2]), String(f6[1])])
		_petit(bf)
		bf.tooltip_text = "Touche %s" % String(f6[2])
		bf.pressed.connect(_choisir_forme.bind(int(f6[0])))
		_boutons_forme.append(bf)
		colF.add_child(bf)

	boite.add_child(UI.texte("PINCEAU   (1-9, Maj+1-9 · R : MAJ/min)", 12, Palette.ENCRE_FAIBLE))
	# ⚠ DEUX COLONNES, L'IMAGE À GAUCHE DU NOM. Essayé en trois colonnes avec
	# l'image au-dessus : à quatre-vingt-huit pixels de large, le libellé
	# tombait à « Ru », « Po », « Ro » — on avait gagné une photo et perdu les
	# noms. À deux colonnes l'image fait quarante pixels, le nom tient en
	# entier, et on lit les deux d'un coup.
	var grille := GridContainer.new()
	grille.columns = 2
	grille.add_theme_constant_override("h_separation", 4)
	grille.add_theme_constant_override("v_separation", 4)
	grille.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boite.add_child(grille)
	for k in PINCEAUX.size():
		var p: Array = PINCEAUX[k]
		var vig := _vignette(String(p[0]))
		var b3 := UI.bouton(String(p[1]) if vig != null else "%s  %s" % [p[0], p[1]])
		_petit(b3)
		# ⚠ PAS DE `expand_icon`. Il étire l'image sur toute la place libre du
		# bouton et ne laisse plus rien au texte — c'est ce qui rognait les
		# libellés à deux lettres. La vignette est déjà écrite à sa taille
		# d'affichage par `outils/vignettes.gd` : on la pose telle quelle.
		b3.icon = vig if vig != null else _pastille(p[2])
		b3.tooltip_text = "%s — touche %s%d" % [p[0], "Maj+" if k >= 9 else "", (k % 9) + 1]
		b3.pressed.connect(_choisir.bind(String(p[0])))
		_boutons.append(b3)
		grille.add_child(b3)

	var barre := HBoxContainer.new()
	barre.add_theme_constant_override("separation", 4)
	boite.add_child(barre)
	for f in [["Exporter", _exporter], ["Fiche", _exporter_fiche],
			["Recharger", _recharger], ["Nouveau", _nouveau]]:
		var b := UI.bouton(String(f[0]))
		_petit(b)
		b.pressed.connect(f[1])
		barre.add_child(b)
	var barre2 := HBoxContainer.new()
	barre2.add_theme_constant_override("separation", 4)
	boite.add_child(barre2)
	for f5 in [["Annuler", _annuler], ["Refaire", _refaire_geste], ["Recadrer", _recadrer]]:
		var b7 := UI.bouton(String(f5[0]))
		_petit(b7)
		b7.pressed.connect(f5[1])
		barre2.add_child(b7)

	var rangV := _rang_texte(boite, "VUE")
	_bouton_grille = UI.bouton("X  Quadrillage")
	_petit(_bouton_grille)
	_bouton_grille.pressed.connect(_basculer_grille)
	rangV.add_child(_bouton_grille)
	_bouton_dessus = UI.bouton("V  De dessus")
	_petit(_bouton_dessus)
	_bouton_dessus.pressed.connect(_vue_dessus)
	rangV.add_child(_bouton_dessus)

	# L'ANGLE et la POSITION du quartier. C'est là que se joue le « moins
	# carré » : deux quartiers voisins qui n'ont pas le même angle cassent le
	# damier mieux que n'importe quelle rue courbe. Sans ces boutons, l'angle
	# n'était modifiable qu'en éditant le fichier à la main.
	var rangA := _rang_texte(boite, "ANGLE ET POSITION")
	for f3 in [["−5°", -5.0], ["+5°", 5.0], ["−1°", -1.0], ["+1°", 1.0]]:
		var b5 := UI.bouton(String(f3[0]))
		_petit(b5)
		b5.pressed.connect(_tourner.bind(float(f3[1])))
		rangA.add_child(b5)
	var rangB := HBoxContainer.new()
	rangB.add_theme_constant_override("separation", 4)
	boite.add_child(rangB)
	for f4 in [["O", Vector2(-1, 0)], ["N", Vector2(0, -1)], ["S", Vector2(0, 1)], ["E", Vector2(1, 0)]]:
		var b6 := UI.bouton(String(f4[0]))
		_petit(b6)
		b6.pressed.connect(_deplacer.bind(f4[1]))
		rangB.add_child(b6)

	var croix := _rang_texte(boite, "AGRANDIR LA GRILLE")
	for f2 in [["+O", "ouest"], ["+N", "nord"], ["+S", "sud"], ["+E", "est"]]:
		var b2 := UI.bouton(String(f2[0]))
		_petit(b2)
		b2.pressed.connect(_agrandir.bind(String(f2[1])))
		croix.add_child(b2)

	# LA BARRE DU BAS : l'état sur une ligne lisible, l'aide dessous en petit.
	# Les deux à la même taille, c'était trente-cinq raccourcis qui criaient
	# aussi fort que la case sous le curseur.
	var bas := UI.panneau(Palette.AVERTISSEMENT)
	bas.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bas.offset_left = 352
	bas.offset_right = -8
	bas.offset_top = -104
	bas.offset_bottom = -8
	couche.add_child(bas)
	var pile := VBoxContainer.new()
	pile.add_theme_constant_override("separation", 6)
	bas.add_child(pile)
	_etiquette = UI.texte("", 22, Palette.ENCRE, true)
	pile.add_child(_etiquette)
	_aide = UI.texte("", 12, Palette.ENCRE_FAIBLE, true)
	pile.add_child(_aide)
	_rafraichir_boutons()

func _synchroniser_liste() -> void:
	if _choix_quartier == null: return
	var rang := Quartiers.CATALOGUE.keys().find(_id)
	if rang >= 0: _choix_quartier.selected = rang

func _dire(message: String) -> void:
	if _message != null:
		_message.text = message
		_message.visible = message != ""

func _choisir(c: String) -> void:
	_pinceau = c
	_outil = OUTIL_DESSIN
	if _forme == FORME_PIPETTE: _forme = FORME_LIBRE
	_rafraichir_boutons()
	_etat()

## Le surlignage de TOUS les boutons d'état, au même endroit. Éparpillé, il
## finit toujours par en oublier un — c'est exactement ce qui laissait « Rue »
## en bleu après un clic sur « Tour ».
func _rafraichir_boutons() -> void:
	for k in _boutons.size():
		_teinter(_boutons[k], _outil == OUTIL_DESSIN and String(PINCEAUX[k][0]) == _pinceau)
	for k in _boutons_forme.size():
		_teinter(_boutons_forme[k], int(FORMES[k][0]) == _forme)
	if _bouton_dessin != null: _teinter(_bouton_dessin, _outil == OUTIL_DESSIN)
	if _bouton_relief != null: _teinter(_bouton_relief, _outil == OUTIL_RELIEF)
	if _bouton_grille != null: _teinter(_bouton_grille, _voir_grille)
	if _bouton_dessus != null: _teinter(_bouton_dessus, _dessus)
	if _bouton_relatif != null: _teinter(_bouton_relatif, _relief_relatif)
	if _bouton_carte_relief != null: _teinter(_bouton_carte_relief, _carte_relief)

const AIDE := "clic milieu sur le plan : s'y rendre · ZQSD déplacer · molette zoom · clic milieu tourner · clic gauche peindre · clic droit effacer · Alt+clic pipette · Tab dessin/relief · Pg↑ Pg↓ palier · Ctrl+Z / Ctrl+Y annuler · F recadrer · E exporter"

func _etat() -> void:
	if _etiquette == null: return
	var quoi := ("RELIEF ±1" if _relief_relatif else "RELIEF palier %d" % _palier) \
		if _outil == OUTIL_RELIEF else "DESSIN « %s »" % _caractere()
	var nom_forme := "Libre"
	for f in FORMES:
		if int(f[0]) == _forme: nom_forme = String(f[1])
	# ⚠ COURT. Écrite en toutes lettres, cette ligne passait à deux lignes dans
	# le cartouche et poussait l'aide hors du cadre : ce qu'on lit vingt fois
	# par minute doit tenir sur UNE ligne.
	_etiquette.text = "%s · %s · case (%d, %d) palier %d · %d×%d · angle %s° · origine (%s, %s)" % [
		quoi, nom_forme, _case.x, _case.y, _palier_de(_case.x, _case.y), _large(), _haut(),
		_nombre(float(_fiche.get("angle", 0.0))),
		_nombre((_fiche.get("origine", Vector2.ZERO) as Vector2).x),
		_nombre((_fiche.get("origine", Vector2.ZERO) as Vector2).y)]
	if _aide != null: _aide.text = AIDE
	_regler_nappe()
	if _carte2d != null: _carte2d.queue_redraw()

# ------------------------------------------------------------- la mini-carte

## LE PLAN, à plat, tel qu'il est écrit. Les couleurs sont celles des pinceaux
## — la colonne et la carte disent donc la même chose — et le palier ÉCLAIRCIT
## la case : sans ça, une terrasse à trois crans et le trottoir d'à côté sont
## du même gris et le relief ne se voit que dans la vue 3D.
## ⚠ UNE TEXTURE, PAS QUARANTE-HUIT MILLE RECTANGLES. La première version
## dessinait la carte case par case à chaque `queue_redraw` — donc à chaque
## pixel parcouru par la souris. Sur les six petits quartiers, six cents
## rectangles passaient inaperçus ; sur Pikstown, 48 375 rectangles par
## mouvement de souris figeaient l'éditeur. On peint donc une IMAGE d'un pixel
## par case, une seule fois par modification du plan, et le `draw` ne fait plus
## que l'étirer et poser le curseur et les fautes par-dessus.
func _redessiner_carte() -> void:
	var l := _large()
	var h := _haut()
	if l <= 0 or h <= 0: return
	var img := Image.create(l, h, false, Image.FORMAT_RGBA8)
	img.fill(Color("#16323f"))
	for j in h:
		var ligne := String(_lignes("plan")[j])
		for i in mini(l, ligne.length()):
			var c := ligne[i]
			if c == ".": continue
			# La chaussée est peinte plus sombre que son pinceau : au gris du
			# pinceau, les rues et les bureaux se confondaient et la carte
			# devenait un aplat laiteux où le plan de rues ne se voyait plus.
			var teinte := Color.BLACK
			if _carte_relief:
				# LA CARTE DU RELIEF. Sur une ville plate elle n'aurait rien
				# dit ; avec cinq paliers, c'est la seule vue où l'on voit d'un
				# coup où sont les hauteurs — et la chaussée reste plus sombre,
				# pour garder le plan de rues comme repère.
				teinte = RAMPE[clampi(_palier_de(i, j), 0, RAMPE.size() - 1)]
				if CHAUSSEE.contains(c): teinte = teinte.darkened(0.42)
			else:
				teinte = (TEINTE_VOIE if CHAUSSEE.contains(c) else _couleur(c)) \
					.lightened(float(_palier_de(i, j)) * 0.07)
				# La minuscule d'une famille est un AUTRE bâtiment : sans ça,
				# `TTtt` et `TTTT` se ressemblent sur la carte.
				if FAMILLES.contains(c.to_upper()) and c == c.to_lower():
					teinte = teinte.darkened(0.22)
			img.set_pixel(i, j, teinte)
	_carte_image = ImageTexture.create_from_image(img)
	if _carte2d != null: _carte2d.queue_redraw()

func _dessiner_carte() -> void:
	var l := _large()
	var h := _haut()
	if l <= 0 or h <= 0 or _carte_image == null: return
	var s: Vector2 = _carte2d.size
	var pas := minf(s.x / float(l), s.y / float(h))
	var org := Vector2((s.x - pas * float(l)) * 0.5, (s.y - pas * float(h)) * 0.5)
	_carte_pas = pas
	_carte_org = org
	var emprise := Rect2(org, Vector2(pas * float(l), pas * float(h)))
	_carte2d.draw_texture_rect(_carte_image, emprise, false)
	if l <= 64:
		for i in range(0, l + 1, 5):
			var x := org.x + float(i) * pas
			_carte2d.draw_line(Vector2(x, org.y), Vector2(x, org.y + pas * float(h)), Color(1, 1, 1, 0.10))
		for j in range(0, h + 1, 5):
			var y := org.y + float(j) * pas
			_carte2d.draw_line(Vector2(org.x, y), Vector2(org.x + pas * float(l), y), Color(1, 1, 1, 0.10))
	for f in _fautives.keys():
		var c2: Vector2i = f
		_carte2d.draw_rect(Rect2(org + Vector2(float(c2.x), float(c2.y)) * pas,
			Vector2(maxf(pas, 2.0), maxf(pas, 2.0))), Palette.CRITIQUE, false, maxf(1.0, pas * 0.3))
	_carte2d.draw_rect(emprise, Color(1, 1, 1, 0.25), false, 1.0)
	if _dans_grille(_case.x, _case.y):
		_carte2d.draw_rect(Rect2(org + Vector2(float(_case.x), float(_case.y)) * pas,
			Vector2(maxf(pas, 3.0), maxf(pas, 3.0))), Color("#ffd23f"), false, maxf(1.0, pas * 0.5))
	# LA VUE : sur une carte de 225 cases, savoir OÙ l'on regarde dans la ville
	# est plus utile que n'importe quel autre repère de la mini-carte.
	if _camera != null:
		var vue := _quartier.global_transform.affine_inverse() * _pivot if _quartier != null else _pivot
		var p := org + Vector2(vue.x / CASE, vue.z / CASE) * pas
		_carte2d.draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), Color("#3987e5"), false, 2.0)

func _carte_souris(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var b := e as InputEventMouseButton
		# ⚠ SE DÉPLACER DEPUIS LA MINI-CARTE. Sur 320 × 300 cases, traverser la
		# ville au clavier prend une minute, et la mini-carte était le seul
		# endroit où l'on voyait où aller — sans pouvoir y aller. Clic milieu,
		# ou Ctrl+clic : la caméra se pose sur la case visée.
		if b.button_index == MOUSE_BUTTON_MIDDLE or (b.ctrl_pressed and b.pressed):
			if b.pressed:
				_carte_viser(b.position)
				if _vise: _aller_a(_case)
			return
		if b.button_index != MOUSE_BUTTON_LEFT and b.button_index != MOUSE_BUTTON_RIGHT: return
		if b.pressed:
			_gauche = b.button_index == MOUSE_BUTTON_LEFT
			if b.alt_pressed or _forme == FORME_PIPETTE:
				_carte_viser(b.position)
				_prelever()
				return
			_empiler()
			_peint_carte = true
			_carte_poser(b.position)
		else:
			_peint_carte = false
			_finir_geste()
	elif e is InputEventMouseMotion:
		_carte_viser((e as InputEventMouseMotion).position)
		if _peint_carte:
			_carte_poser((e as InputEventMouseMotion).position)
		else:
			_etat()

func _aller_a(c: Vector2i) -> void:
	if _quartier == null: return
	_pivot = _quartier.global_transform * Vector3((float(c.x) + 0.5) * CASE,
		float(_palier_de(c.x, c.y)) * PALIER, (float(c.y) + 0.5) * CASE)
	_dessus = false
	_poser_camera()
	if _ville != null:
		_ville.rayon = _rayon_utile()
		_ville.suivre(_pivot)
	_dire("Déplacé en (%d, %d)." % [c.x, c.y])
	_etat()

func _carte_viser(p: Vector2) -> void:
	if _carte_pas <= 0.0: return
	var c := Vector2i(floori((p.x - _carte_org.x) / _carte_pas), floori((p.y - _carte_org.y) / _carte_pas))
	_vise = _dans_grille(c.x, c.y)
	if _vise:
		_case = c
		_montrer_curseur()

## La carte peint TOUJOURS à main levée, quelle que soit la forme choisie : on
## y vient pour corriger une case précise, pas pour tirer une avenue — et un
## rectangle tracé sur cent quatre-vingt-dix pixels de haut se rate.
func _carte_poser(p: Vector2) -> void:
	_carte_viser(p)
	if not _vise: return
	_poser(_case.x, _case.y, _gauche)
	_etat()
