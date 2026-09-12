class_name MorceauxV2
extends Node3D
## LA VILLE V2, BÂTIE PAR MORCEAUX AUTOUR DE CELUI QUI REGARDE.
##
## Même principe que `VilleMorcelee` pour Pikstown : on ne bâtit que les
## morceaux (16 x 16 cases) autour du joueur, une passe par image (le sol,
## puis les bâtiments, puis les objets), les plus proches d'abord ; on rend
## les autres à la mémoire quand il s'éloigne. La carte, elle, est entière
## (`Ville2.carte`), donc une rue sait qu'elle continue chez le voisin.

const COTE := 16

var ville: Ville2
var rayon := 3
var par_image := 1

var _chantier := Vector2i(999999, 999999)
var _chantier_noeud: Node3D = null
var _chantier_passe := 0
var _morceaux: Dictionary = {}
var _file: Array[Vector2i] = []
var _centre := Vector2i(999999, 999999)

func regler(v: Ville2, r: int = 3) -> void:
	ville = v
	rayon = r
	if ville.carte == null:
		ville.rasteriser()
	for n in _morceaux.values():
		n.queue_free()
	_morceaux.clear()
	_file.clear()
	_chantier_noeud = null
	_chantier_passe = 0
	_centre = Vector2i(999999, 999999)
	set_process(true)

func morceaux_batis() -> int:
	return _morceaux.size()

func suivre(point: Vector3) -> void:
	var local := global_transform.affine_inverse() * point
	var c := Vector2i(floori(local.x / Ville2.CASE / float(COTE)),
		floori(local.z / Ville2.CASE / float(COTE)))
	if c == _centre: return
	_centre = c
	_revoir()

func _revoir() -> void:
	var derniers := rayon + 1
	for cle in _morceaux.keys():
		var d: Vector2i = cle
		if maxi(absi(d.x - _centre.x), absi(d.y - _centre.y)) > derniers:
			if _chantier_noeud != null and cle == _chantier:
				_chantier_noeud = null
			(_morceaux[cle] as Node3D).queue_free()
			_morceaux.erase(cle)
	_file.clear()
	var colonnes := int(ceil(float(ville.taille.x) / float(COTE)))
	var lignes := int(ceil(float(ville.taille.y) / float(COTE)))
	for dy in range(-rayon, rayon + 1):
		for dx in range(-rayon, rayon + 1):
			var c := _centre + Vector2i(dx, dy)
			if c.x < 0 or c.y < 0 or c.x >= colonnes or c.y >= lignes: continue
			if _morceaux.has(c): continue
			_file.append(c)
	var ici := _centre
	_file.sort_custom(func(a: Vector2i, b: Vector2i):
		return (a - ici).length_squared() < (b - ici).length_squared())

func _process(_delta: float) -> void:
	var faits := 0
	while faits < par_image:
		if _chantier_noeud == null:
			if _file.is_empty(): return
			var c: Vector2i = _file.pop_front()
			if _morceaux.has(c): continue
			_chantier = c
			_chantier_passe = 0
			_chantier_noeud = Node3D.new()
			_chantier_noeud.name = "v2_%d_%d" % [c.x, c.y]
			add_child(_chantier_noeud)
			_morceaux[c] = _chantier_noeud
		var zone := Rect2i(_chantier.x * COTE, _chantier.y * COTE, COTE, COTE)
		RenduVille2.batir(ville, zone, RenduVille2.PASSES[_chantier_passe], _chantier_noeud)
		_chantier_passe += 1
		faits += 1
		if _chantier_passe >= RenduVille2.PASSES.size():
			_chantier_noeud = null

## APRÈS UNE RETOUCHE (éditeur) : rebâtir les morceaux qui portent ces cases.
func refaire(cases: Array) -> void:
	ville.rasteriser()
	var a_refaire: Dictionary = {}
	for v in cases:
		var c: Vector2i = v
		var m := Vector2i(floori(float(c.x) / float(COTE)), floori(float(c.y) / float(COTE)))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				a_refaire[m + Vector2i(dx, dy)] = true
	for cle in a_refaire.keys():
		if not _morceaux.has(cle): continue
		if _chantier_noeud != null and cle == _chantier:
			_chantier_noeud = null
		(_morceaux[cle] as Node3D).queue_free()
		_morceaux.erase(cle)
		var zone := Rect2i((cle as Vector2i).x * COTE, (cle as Vector2i).y * COTE, COTE, COTE)
		var n := RenduVille2.batir(ville, zone)
		n.name = "v2_%d_%d" % [(cle as Vector2i).x, (cle as Vector2i).y]
		add_child(n)
		_morceaux[cle] = n

## Tout bâtir d'un coup, pour le banc et l'éditeur.
func tout() -> void:
	var colonnes := int(ceil(float(ville.taille.x) / float(COTE)))
	var lignes := int(ceil(float(ville.taille.y) / float(COTE)))
	for y in lignes:
		for x in colonnes:
			var c := Vector2i(x, y)
			if _morceaux.has(c): continue
			var n := RenduVille2.batir(ville, Rect2i(x * COTE, y * COTE, COTE, COTE))
			n.name = "v2_%d_%d" % [x, y]
			add_child(n)
			_morceaux[c] = n
