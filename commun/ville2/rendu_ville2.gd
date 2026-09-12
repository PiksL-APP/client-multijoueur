class_name RenduVille2
extends RefCounted
## LE RENDU DE LA VILLE V2 : un `Ville2` entre, un `Node3D` sort.
##
## Une seule règle : TOUT VIENT DU KIT, À SON ÉCHELLE. Une tuile de route est
## posée telle quelle, une unité Kenney = une case (20 unités 3D). Un bâtiment
## est posé tel quel à la même échelle, au centre de son lot. Rien n'est
## étiré. Les props (lampadaires, arbres…) viennent de kits à d'autres
## échelles : ils sont mis à la hauteur que le jeu leur donne déjà.
##
## Le sol : chaque case de terre reçoit une dalle `tile-low` du kit (le
## trottoir du kit, au ras des tuiles de route) ou, sur une rue, la tuile de
## route que `CarteVille.tuile()` désigne — la table de pavage mesurée au banc.
## Les tuiles AJOURÉES (voir `CarteVille.AJOUREES`) reçoivent une dalle dessous.

const CASE := Ville2.CASE
const PALIER := Ville2.PALIER
const ROUTES := "res://modeles/kenney/routes/"
## Le relief d'une tuile du kit (0,02 unité Kenney) : la dalle passe dessous.
const EPAISSEUR_TUILE := 0.02 * CASE
## La dalle des pâtés, un rien plus sombre que le trottoir blanc du kit : sans
## ça, une ville entière sort d'un seul blanc et rien ne se détache.
const TEINTE_DALLE := Color("#d9d6cf")
const TEINTE_RAIL := Color("#8c8f96")
const TEINTE_TRAVERSE := Color("#5b4a3a")

static var _matieres: Dictionary = {}
static var inventaire := false
static var poses: Dictionary = {}          ## chemin -> nombre de poses (banc)

## Les passes, pour bâtir un morceau en plusieurs images (voir `MorceauxV2`).
enum { P_SOLS = 1, P_LOTS = 2, P_OBJETS = 4, P_RAIL = 8 }
const P_TOUT := 15
const PASSES := [P_SOLS, P_LOTS, P_OBJETS | P_RAIL]

## Bâtit la ville entière, ou la seule `zone` (en cases) si elle est donnée.
## `racine` non nulle : on CONTINUE un morceau commencé, passe par passe.
static func batir(ville: Ville2, zone: Rect2i = Rect2i(), passes: int = P_TOUT,
		racine: Node3D = null) -> Node3D:
	if ville.carte == null:
		ville.rasteriser()
	if racine == null:
		racine = Node3D.new()
		racine.name = "VilleV2"
	if zone.size == Vector2i.ZERO:
		zone = Rect2i(Vector2i.ZERO, ville.taille)
	if passes & P_SOLS:
		_poser_sols(racine, ville, zone)
		_poser_ouvrages(racine, ville, zone)
	if passes & P_LOTS: _poser_lots(racine, ville, zone)
	if passes & P_OBJETS: _poser_objets(racine, ville, zone)
	if passes & P_RAIL: _poser_rail(racine, ville, zone)
	return racine

# ------------------------------------------------------------------ le sol

static func _poser_sols(racine: Node3D, ville: Ville2, zone: Rect2i) -> void:
	var carte := ville.carte
	for j in range(zone.position.y, zone.end.y):
		for i in range(zone.position.x, zone.end.x):
			var c := Vector2i(i, j)
			if not carte.terre(c): continue
			var y := float(carte.palier(c)) * PALIER
			var centre := Vector3((float(i) + 0.5) * CASE, y, (float(j) + 0.5) * CASE)
			if carte.case_prise(c):
				# La grosse pièce dessine elle-même ; ses cases ajourées
				# gardent une dalle pour ne pas voir la mer.
				if not carte.case_couverte(c):
					_tuile(racine, "tile-low", centre - Vector3(0, EPAISSEUR_TUILE, 0), 0)
				continue
			if carte.route(c):
				var f: Array = carte.tuile(c)
				var nom := String(f[0])
				if CarteVille.AJOUREES.has(nom):
					_tuile(racine, "tile-low", centre - Vector3(0, EPAISSEUR_TUILE, 0), 0)
				_tuile(racine, nom, centre, int(f[1]))
				# Les voies rapides sont bordées de glissières.
				if ville.genre_de_route(c) == Ville2.R_VOIE_RAPIDE and CarteVille.BARRIERES.has(nom):
					_tuile(racine, String(CarteVille.BARRIERES[nom]), centre, int(f[1]))
			else:
				_tuile(racine, _dalle_de(ville, c), centre, 0, TEINTE_DALLE)

## Quelle dalle sous une case sans rue : le trottoir du kit en ville, la
## pelouse ailleurs (un parc, un jardin).
static func _dalle_de(ville: Ville2, c: Vector2i) -> String:
	var lot := ville.lot_sur(c)
	if lot >= 0:
		return "tile-low"
	match ville.genre_du_quartier(c):
		Ville2.Q_PARC: return "tile-low"     # TODO pelouse du Nature Kit
		_: return "tile-low"

static func _poser_ouvrages(racine: Node3D, ville: Ville2, zone: Rect2i) -> void:
	var carte := ville.carte
	for o in ville.ouvrages:
		var coin := Vector2i(int(o["i"]), int(o["j"]))
		if not zone.has_point(coin): continue
		var t := Vector2i(int(o["w"]), int(o.get("h", o["w"])))
		var y := float(carte.palier(coin)) * PALIER
		var centre := Vector3((float(coin.x) + float(t.x) * 0.5) * CASE, y,
			(float(coin.y) + float(t.y) * 0.5) * CASE)
		_tuile(racine, String(o["t"]), centre, int(o["q"]))

# ------------------------------------------------------------------ les lots

static func _poser_lots(racine: Node3D, ville: Ville2, zone: Rect2i) -> void:
	for l in ville.lots:
		var cases := Ville2.cases_du_lot(l)
		if cases.is_empty() or not zone.has_point(cases[0]): continue
		var chemin := KitVille2.chemin(String(l["m"]))
		if not ResourceLoader.exists(chemin):
			push_warning("modèle absent : " + chemin)
			continue
		var n := MeshInstance3D.new()
		n.mesh = FormesCarnage.maillage_kenney(chemin, 0.0, Vector3.AXIS_X, 0.0)
		n.material_override = _matiere(chemin, Color.WHITE)
		# Posé SUR la dalle : une tuile du kit a une épaisseur, et un modèle posé
		# au palier avait le pied enterré de 0,4 unité.
		var ou := ville.centre_du_lot(l) + Vector3(0, EPAISSEUR_TUILE, 0)
		n.transform = Transform3D(Basis(Vector3.UP, PI * 0.5 * float(int(l["q"]))).scaled(Vector3.ONE * KitVille2.echelle(String(l["m"]))), ou)
		n.set_meta("modele", String(l["m"]))
		_noter(chemin)
		racine.add_child(n)

# ------------------------------------------------------------------ les objets

static func _poser_objets(racine: Node3D, ville: Ville2, zone: Rect2i) -> void:
	for o in ville.objets:
		var x := float(o["x"])
		var z := float(o["z"])
		var c := Vector2i(floori(x / CASE), floori(z / CASE))
		if not zone.has_point(c): continue
		var y := float(ville.carte.palier(c)) * PALIER + EPAISSEUR_TUILE
		poser_objet(racine, String(o["m"]), Vector3(x, y, z), float(o.get("r", 0.0)),
			float(o.get("h", 0.0)), String(o.get("c", "")), o)

## Pose un objet : `modele` est un nom du catalogue (`KitVille2.PROPS`), une
## voiture (`voitures/...`), ou un chemin `res://` posé à l'échelle du kit.
static func poser_objet(parent: Node3D, modele: String, ou: Vector3, tourne := 0.0,
		hauteur := 0.0, teinte := "", fiche_objet := {}) -> void:
	if modele == "pelouse":
		_pelouse(parent, ou, float(fiche_objet.get("w", CASE)), float(fiche_objet.get("d", CASE)))
		return
	var chemin := ""
	var h := hauteur
	var couleur := Color.WHITE
	var fiche: Dictionary = KitVille2.PROPS.get(modele, {})
	if not fiche.is_empty():
		chemin = KitVille2.chemin(String(fiche["m"]))
		if h <= 0.0: h = float(fiche.get("h", 0.0))
		if fiche.has("c"): couleur = Color(String(fiche["c"]))
	else:
		chemin = KitVille2.chemin(modele)
	if teinte != "": couleur = Color(teinte)
	if not ResourceLoader.exists(chemin):
		push_warning("objet absent : " + chemin)
		return
	var n := MeshInstance3D.new()
	if modele.begins_with("voitures/"):
		# ⚠ Le Car Kit regarde +Z quand les props regardent −Z (mesuré,
		# `FormesCarnage.maillage_voiture`) : un quart de tour dans l'autre sens.
		n.mesh = FormesCarnage.maillage_kenney(chemin, KitVille2.LONGUEUR_VOITURE, Vector3.AXIS_Z, PI * 0.5)
		n.transform = Transform3D(Basis(Vector3.UP, tourne), ou)
	elif h > 0.0:
		n.mesh = FormesCarnage.maillage_kenney(chemin, h, Vector3.AXIS_Y, 0.0)
		n.transform = Transform3D(Basis(Vector3.UP, tourne), ou)
	else:
		# À l'échelle du kit (auvents, conteneurs…).
		n.mesh = FormesCarnage.maillage_kenney(chemin, 0.0, Vector3.AXIS_X, 0.0)
		n.transform = Transform3D(Basis(Vector3.UP, tourne).scaled(Vector3.ONE * CASE), ou)
	n.material_override = _matiere(chemin, couleur)
	n.set_meta("modele", modele)
	_noter(chemin)
	parent.add_child(n)

# ------------------------------------------------------------------ le rail

## Le rail : deux files et des traverses, en boîtes — le kit n'a pas de voie
## ferrée. Posé au sol, entre les cases, au niveau du palier.
static func _poser_rail(racine: Node3D, ville: Ville2, zone: Rect2i) -> void:
	for r in ville.rail:
		var cases := Ville2.cases_de_route(r)
		for k in range(1, cases.size()):
			var a: Vector2i = cases[k - 1]
			var b: Vector2i = cases[k]
			if not zone.has_point(a): continue
			var y := float(ville.carte.palier(a)) * PALIER + 0.3
			var pa := Vector3((float(a.x) + 0.5) * CASE, y, (float(a.y) + 0.5) * CASE)
			var pb := Vector3((float(b.x) + 0.5) * CASE, y, (float(b.y) + 0.5) * CASE)
			var selon_x := a.y == b.y
			var milieu := (pa + pb) * 0.5
			var ecart := 3.2
			for s in [-1.0, 1.0]:
				var d := Vector3(0, 0, ecart * s) if selon_x else Vector3(ecart * s, 0, 0)
				_boite(racine, Vector3(CASE, 0.5, 0.6) if selon_x else Vector3(0.6, 0.5, CASE),
					milieu + d + Vector3(0, 0.25, 0), TEINTE_RAIL)
			for t in 5:
				var f := (float(t) + 0.5) / 5.0
				var p := pa.lerp(pb, f)
				_boite(racine, Vector3(1.2, 0.3, 9.0) if selon_x else Vector3(9.0, 0.3, 1.2),
					p + Vector3(0, 0.15, 0), TEINTE_TRAVERSE)

## Une pelouse : un plan vert, posé un rien au-dessus de la dalle.
const TEINTE_PELOUSE := Color("#5d9a3c")

static func _pelouse(parent: Node3D, ou: Vector3, largeur: float, profondeur: float) -> void:
	var n := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(largeur, profondeur)
	n.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = TEINTE_PELOUSE
	m.roughness = 1.0
	n.material_override = m
	n.position = ou + Vector3(0, 0.06, 0)
	n.set_meta("modele", "pelouse")
	parent.add_child(n)

static func _boite(racine: Node3D, dims: Vector3, ou: Vector3, teinte: Color) -> void:
	var n := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = dims
	n.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = teinte
	m.roughness = 0.9
	n.material_override = m
	n.position = ou
	racine.add_child(n)

# ------------------------------------------------------------------ outils

static func _tuile(parent: Node3D, nom: String, ou: Vector3, quarts: int, teinte := Color.WHITE) -> void:
	var chemin := ROUTES + nom + ".glb"
	if not ResourceLoader.exists(chemin):
		push_warning("tuile absente : " + chemin)
		return
	var n := MeshInstance3D.new()
	n.mesh = FormesCarnage.maillage_kenney(chemin, 0.0, Vector3.AXIS_X, 0.0)
	n.material_override = _matiere(chemin, teinte)
	n.transform = Transform3D(Basis(Vector3.UP, PI * 0.5 * float(quarts)).scaled(Vector3.ONE * CASE), ou)
	n.set_meta("tuile", nom)
	_noter(chemin)
	parent.add_child(n)

static func _matiere(chemin: String, teinte: Color) -> Material:
	var cle := chemin + teinte.to_html()
	if _matieres.has(cle): return _matieres[cle]
	var m := FormesCarnage.matiere_kenney(chemin).duplicate()
	if m is ShaderMaterial:
		(m as ShaderMaterial).set_shader_parameter("teinte", teinte)
	elif m is BaseMaterial3D:
		(m as BaseMaterial3D).albedo_color = teinte
	_matieres[cle] = m
	return m

static func _noter(chemin: String) -> void:
	if not inventaire: return
	poses[chemin] = int(poses.get(chemin, 0)) + 1
