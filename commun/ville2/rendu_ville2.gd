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
				nom = _variante_avenue(ville, c, nom)
				if CarteVille.AJOUREES.has(nom):
					_tuile(racine, "tile-low", centre - Vector3(0, EPAISSEUR_TUILE, 0), 0)
				_tuile(racine, nom, centre, int(f[1]))
				# Les voies rapides sont bordées de glissières.
				if ville.genre_de_route(c) == Ville2.R_VOIE_RAPIDE and CarteVille.BARRIERES.has(nom):
					_tuile(racine, String(CarteVille.BARRIERES[nom]), centre, int(f[1]))
			else:
				_tuile(racine, _dalle_de(ville, c), centre, 0, TEINTE_DALLE)

## LES PASSAGES PIÉTONS (cahier § 5 : « feux tricolores aux carrefours
## d'avenues », § 8 : « piétons sur les passages »). Sur une avenue, un
## carrefour prend la variante à zébras du kit, et le tronçon droit qui y
## mène prend `road-crossing`. Les rues gardent le tirage de `CarteVille`.
static func _variante_avenue(ville: Ville2, c: Vector2i, nom: String) -> String:
	if ville.genre_de_route(c) != Ville2.R_AVENUE: return nom
	if nom.begins_with("road-crossroad"): return "road-crossroad-path"
	if nom.begins_with("road-intersection"): return "road-intersection-path"
	if nom == "road-straight":
		for d in CarteVille.COTES:
			var m := ville.carte.masque(c + d)
			if ville.carte.route(c + d) and m != 5 and m != 10 and m != 0:
				return "road-crossing"
	return nom

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
	if modele == "pub":
		_panneau(parent, ou + Vector3(0, float(fiche_objet.get("y", 0.0)), 0), tourne,
			float(fiche_objet.get("w", 14.0)), float(fiche_objet.get("hh", 8.0)),
			float(fiche_objet.get("pied", 3.0)), int(fiche_objet.get("image", 0)))
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

# ------------------------------------------------------------------ les panneaux pub

## LES 24 VISUELS DU CLIENT (cahier § 7) : sur les toits des immeubles moyens
## (cadre + poteaux courts) et sur les pignons aveugles. Plus jamais sur pieds
## au milieu d'un trottoir. Les affiches vivent dans `images/panneaux/pubNN.jpg`
## et se comptent : le client en dépose une de plus, elle est en ville.
const PUB_DOSSIER := "res://images/panneaux/"
static var _affiches: Array[String] = []
static var _pub_matieres: Dictionary = {}
static var _pub_cadre: StandardMaterial3D = null
static var _cube: BoxMesh = null

static func affiches() -> Array[String]:
	if not _affiches.is_empty(): return _affiches
	var trous := 0
	var n := 1
	while trous < 3 and n < 200:
		var chemin := PUB_DOSSIER + "pub%02d.jpg" % n
		if ResourceLoader.exists(chemin):
			_affiches.append(chemin)
			trous = 0
		else:
			trous += 1
		n += 1
	return _affiches

static func _matiere_pub(chemin: String) -> StandardMaterial3D:
	if _pub_matieres.has(chemin): return _pub_matieres[chemin]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(chemin)
	m.roughness = 0.62
	# Éclairé : faible de jour (noyé dans le soleil), lisible la nuit.
	m.emission_enabled = true
	m.emission_texture = m.albedo_texture
	m.emission = Color(1, 1, 1)
	m.emission_energy_multiplier = 0.18
	m.cull_mode = BaseMaterial3D.CULL_BACK
	_pub_matieres[chemin] = m
	return m

## Deux poteaux, un cadre, une affiche, l'affiche vers +Z tourné de `tour`.
## `ou` est le pied (le toit, ou le sol au pied du pignon avec `pied` = 0).
static func _panneau(parent: Node3D, ou: Vector3, tour: float, large: float, haut: float,
		pied: float, image: int) -> void:
	var liste := affiches()
	if liste.is_empty(): return
	if _cube == null:
		_cube = BoxMesh.new()
		_cube.size = Vector3.ONE
	if _pub_cadre == null:
		_pub_cadre = StandardMaterial3D.new()
		_pub_cadre.albedo_color = Color("#2f3338")
		_pub_cadre.roughness = 0.8
	var base := Basis(Vector3.UP, tour)
	# ⚠ `Basis.scaled()` MET À L'ÉCHELLE DANS LE MONDE, PAS DANS L'OBJET. Un
	# `Basis(UP, 90°).scaled(Vector3(14, 8, 3))` étire l'axe X DU MONDE de 14 :
	# sur un panneau tourné d'un quart, le caisson sortait perpendiculaire au
	# mur — quatorze unités de profondeur, trois de large, en travers de
	# l'affiche. On met donc l'échelle AVANT la rotation.
	var boite := func(dims: Vector3, centre: Vector3) -> Transform3D:
		return Transform3D(base * Basis.from_scale(dims), centre)
	var mi_h := pied + haut * 0.5
	# ⚠ UN PANNEAU MURAL EST UN CAISSON, PAS UNE PEINTURE. Les façades Kenney
	# ont du relief — descente d'eau au milieu, bandeaux, appuis de fenêtre. Une
	# affiche plaquée au mur se faisait TRAVERSER par la descente d'eau, qui la
	# barrait de haut en bas. Le cadre d'un panneau mural est donc un caisson
	# épais : il coiffe le relief, et l'affiche se pose sur sa face avant.
	var ep := 3.2 if pied <= 0.0 else 0.5
	if pied > 0.0:
		for s in [-1.0, 1.0]:
			var n := MeshInstance3D.new()
			n.mesh = _cube
			n.material_override = _pub_cadre
			n.transform = boite.call(Vector3(0.7, pied + haut * 0.5, 0.7),
				ou + base * Vector3(s * large * 0.36, (pied + haut * 0.5) * 0.5, 0.0))
			parent.add_child(n)
	# ⚠ L'AFFICHE DONNE SES PROPORTIONS, PAS LE PANNEAU. `large` et `haut` ne
	# sont qu'un ENCOMBREMENT MAXIMAL (ce que le mur ou le toit peut porter) :
	# on y inscrit l'image à son format, sinon un visuel qui n'est pas en 16:9
	# sort étiré, et le client dépose ce qu'il veut dans `images/panneaux/`.
	var chemin := String(liste[posmod(image, liste.size())])
	var matiere := _matiere_pub(chemin)
	var rapport := 9.0 / 16.0
	var tex: Texture2D = matiere.albedo_texture
	if tex != null and tex.get_width() > 0:
		rapport = float(tex.get_height()) / float(tex.get_width())
	if large * rapport > haut:
		large = haut / rapport
	else:
		haut = large * rapport
	mi_h = pied + haut * 0.5
	var cadre := MeshInstance3D.new()
	cadre.mesh = _cube
	cadre.material_override = _pub_cadre
	cadre.transform = boite.call(Vector3(large + 1.0, haut + 1.0, ep), ou + Vector3(0, mi_h, 0))
	parent.add_child(cadre)
	var toile := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(large, haut)
	toile.mesh = q
	toile.material_override = matiere
	toile.transform = Transform3D(base, ou + Vector3(0, mi_h, 0) + base * Vector3(0, 0, ep * 0.5 + 0.06))
	toile.set_meta("modele", "pub")
	parent.add_child(toile)

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
