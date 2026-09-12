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

## ⚠ `preload` ET PAS LE NOM DE CLASSE : un `class_name` créé après coup
## n'existe pas dans l'export web (il n'est inscrit que dans le cache de
## l'éditeur, que le workflow d'export ne régénère pas).
const ANGLES := preload("res://commun/ville2/angles.gd")

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
		_poser_terrain(racine, ville, zone)
		_poser_sols(racine, ville, zone)
		_poser_soutenements(racine, ville, zone)
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
			# Une case de terrain (herbe, sable, terre, roche) est portée par le
			# maillage continu, pas par une dalle du kit.
			if not carte.terre(c) or not ville.plate(c): continue
			var y := float(carte.palier(c)) * PALIER
			var centre := Vector3((float(i) + 0.5) * CASE, y, (float(j) + 0.5) * CASE)
			# ⚠ PLUS DE DALLE DE BOUCHAGE SOUS LES TUILES AJOURÉES. Le maillage
			# du terrain couvre désormais les cases plates : il passe sous la
			# tuile, bouche sa rainure et remplit ses coins ouverts, de la
			# couleur du sol. Une dalle de plus par case ne servirait qu'à
			# poser du béton dans l'herbe — et à doubler le nombre de tuiles.
			if carte.case_prise(c):
				continue
			if carte.route(c):
				var f: Array = carte.tuile(c)
				var nom := String(f[0])
				nom = _variante_avenue(ville, c, nom)
				nom = _variante_campagne(ville, c, nom)
				_tuile(racine, nom, centre, int(f[1]))
				# Les voies rapides sont bordées de glissières.
				if ville.genre_de_route(c) == Ville2.R_VOIE_RAPIDE and CarteVille.BARRIERES.has(nom):
					_tuile(racine, String(CarteVille.BARRIERES[nom]), centre, int(f[1]))
			else:
				_tuile(racine, _dalle_de(ville, c), centre, 0, TEINTE_DALLE)

## LES TUILES DE CAMPAGNE (demande du client, 12/09 : « road-bend plutôt que
## road-bend-sidewalk sur l'herbe »). Le kit a deux dessins pour le même
## raccord : l'un remplit son carré d'un trottoir, l'autre n'est que la bande
## de chaussée. En ville le trottoir est juste ; dans un champ il fait une
## place de village autour d'un virage.
const NUES := {
	"road-bend-sidewalk": "road-bend", "road-bend-square": "road-bend",
	"road-curve-pavement": "road-curve",
	"road-straight-half": "road-straight",
}

static func _variante_campagne(ville: Ville2, c: Vector2i, nom: String) -> String:
	if not NUES.has(nom): return nom
	if not ANGLES.a_la_campagne(ville, c): return nom
	return String(NUES[nom])

## La couleur du sol d'une case : le béton en ville, la matière du terrain
## dehors — c'est ce qui va sous une tuile ajourée.
static func _teinte_du_sol(ville: Ville2, c: Vector2i) -> Color:
	if not ANGLES.a_la_campagne(ville, c): return TEINTE_DALLE
	return TerrainV2.COULEURS.get(ville.matiere_de(c), TEINTE_DALLE)

## LES PASSAGES PIÉTONS (cahier § 5 : « feux tricolores aux carrefours
## d'avenues », § 8 : « piétons sur les passages »). Sur une avenue, un
## carrefour prend la variante à zébras du kit, et le tronçon droit qui y
## mène prend `road-crossing`. Les rues gardent le tirage de `CarteVille`.
static func _variante_avenue(ville: Ville2, c: Vector2i, nom: String) -> String:
	if ville.genre_de_route(c) != Ville2.R_AVENUE: return nom
	if nom.begins_with("road-crossroad"): return "road-crossroad-path"
	if nom.begins_with("road-intersection"): return "road-intersection-path"
	# ⚠ AUCUN PASSAGE PIÉTON À CÔTÉ D'UN CARREFOUR : IL EN A DÉJÀ (demande du
	# client, 12/09). Les tuiles `-path` du kit — celles qu'on pose sur les
	# carrefours et les T d'avenue — portent leurs propres passages sur chacun
	# de leurs bras. En ajouter un sur la case d'à côté, c'était traverser deux
	# fois la même rue à deux mètres d'intervalle.
	return nom

## Quelle dalle sous une case pavée sans rue : le trottoir du kit. Les cases
## de terrain ne passent pas par ici (voir `_poser_terrain`).
static func _dalle_de(_ville: Ville2, _c: Vector2i) -> String:
	return "tile-low"

# ------------------------------------------------------------------ le terrain

## LE TERRAIN CONTINU ET LA MER, en deux maillages par morceau (voir
## `TerrainV2`). Un morceau entièrement pavé n'en produit aucun.
static func _poser_terrain(racine: Node3D, ville: Ville2, zone: Rect2i) -> void:
	var sol := TerrainV2.maillage(ville, zone)
	if sol != null:
		var n := MeshInstance3D.new()
		n.mesh = sol
		n.material_override = TerrainV2.matiere()
		n.set_meta("modele", "terrain")
		racine.add_child(n)
	var mer := TerrainV2.maillage_eau(ville, zone)
	if mer != null:
		var n := MeshInstance3D.new()
		n.mesh = mer
		n.material_override = MatieresCarnage.eau()
		n.set_meta("modele", "eau")
		racine.add_child(n)

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

# ------------------------------------------------------------------ les soutènements

## LES MURS DE SOUTÈNEMENT (cahier § 4 : « béton en ville, rochers hors
## ville »). Une case PLATE — une dalle, une rue, un lot — est un plateau : son
## bord donne sur le vide dès que la voisine est plus basse. Sans mur, on voit
## la tranche d'une dalle de deux centimètres flotter au-dessus du terrain, et
## le quai d'un port a l'air posé sur l'eau.
##
## ⚠ LE MUR DESCEND JUSQU'À LA VOISINE, PAS D'UNE HAUTEUR FIXE. Contre un
## terrain il s'arrête au sol ; contre la mer il plonge sous la nappe, sinon on
## voit le dessous du quai à travers l'eau.
const TEINTE_BETON := Color("#b4b2ab")
const TEINTE_ROCHE := Color("#9b978e")
const EPAISSEUR_MUR := 1.2
## De combien une tuile déborde de sa case pour couvrir le biseau de sa voisine.
const RECOUVREMENT := 1.0
## ⚠ LE SEUIL DOIT ÊTRE PLUS GRAND QUE L'ÉPAISSEUR D'UNE TUILE. À 0,35 il était
## plus PETIT que les 0,4 d'une dalle du kit : sur un sol parfaitement plat,
## chaque case se trouvait « plus haute » que sa voisine et se bordait d'un
## muret de béton. Vu du ciel, la ville entière était quadrillée de liserés
## clairs — ce que le client a lu comme « aucune route n'est collée, on voit
## l'écart entre deux routes » (12/09). Un mur ne se justifie qu'à partir
## d'une vraie marche.
const MUR_MINI := 1.2

static func _poser_soutenements(racine: Node3D, ville: Ville2, zone: Rect2i) -> void:
	for j in range(zone.position.y, zone.end.y):
		for i in range(zone.position.x, zone.end.x):
			var c := Vector2i(i, j)
			if not ville.dedans(c) or not ville.plate(c): continue
			var haut := ville.sol(c) + EPAISSEUR_TUILE
			# ⚠ LE BÉTON SOUS CE QUI EST BÂTI, les rochers ailleurs (cahier
			# § 4) — et une terrasse en herbe reste de la ville : c'est la RUE
			# ou le LOT qui décide, pas la pelouse.
			var en_ville := ville.matiere_de(c) == Ville2.M_DALLE \
				or ville.carte.route(c) or ville.lot_sur(c) >= 0
			# ⚠ UNE RAMPE MONTE AU-DESSUS DE SA PROPRE CASE. `road-slant`
			# grimpe d'un palier entre l'entrée et la sortie de la case : un
			# mur arrêté à l'altitude de la case laissait, sur les DEUX CÔTÉS
			# du lacet, un triangle ouvert par lequel on voyait le dessous de
			# la colline. On monte donc le mur jusqu'au haut de la rampe, et
			# on le construit en DEUX DEMI-MURS pour épouser la pente au lieu
			# de faire une marche.
			var vers_le_haut := _sens_de_la_rampe(ville, c)
			# ⚠ UNE RAMPE SE BORDE TOUJOURS, MÊME POUR UN RIEN. Sa tuile monte
			# d'un palier au-dessus de sa propre case : sous la moitié haute, il
			# n'y a rien, et l'on voyait le ciel par deux triangles sombres de
			# part et d'autre de chaque lacet. Le seuil ordinaire (qui évite de
			# border chaque case d'un sol plat) ne s'applique donc pas à elle.
			var seuil: float = 0.05 if vers_le_haut != Vector2i.ZERO else MUR_MINI
			for d in CarteVille.COTES:
				var v: Vector2i = c + d
				var bas := _pied_du_mur(ville, v)
				if haut - bas < seuil: continue
				var teinte: Color = TEINTE_BETON if en_ville else TEINTE_ROCHE
				if vers_le_haut == Vector2i.ZERO or d == -vers_le_haut:
					_mur(racine, i, j, d, bas, haut, 1.0, 0.0, teinte)
				elif d == vers_le_haut:
					_mur(racine, i, j, d, bas, haut + PALIER, 1.0, 0.0, teinte)
				else:
					# Un côté qui longe la pente : deux demis, en escalier.
					_mur(racine, i, j, d, bas, haut + PALIER * 0.25, 0.5, -0.25, teinte)
					_mur(racine, i, j, d, bas, haut + PALIER * 0.75, 0.5, 0.25, teinte)

## Un pan de mur le long du côté `d` de la case (i, j), de `bas` à `haut`.
## `part` est la fraction de la case couverte, `glisse` le décalage du centre
## le long de ce côté (en fraction de case) : c'est ce qui permet de poser deux
## demi-murs à deux hauteurs pour suivre une rampe.
static func _mur(racine: Node3D, i: int, j: int, d: Vector2i, bas: float, haut: float,
		part: float, glisse: float, teinte: Color) -> void:
	if haut - bas < MUR_MINI: return
	var le_long := Vector3(float(d.y), 0.0, float(d.x)) * glisse * CASE
	var centre := Vector3((float(i) + 0.5 + float(d.x) * 0.5) * CASE, (haut + bas) * 0.5,
		(float(j) + 0.5 + float(d.y) * 0.5) * CASE) + le_long
	var dims := Vector3(CASE * part, haut - bas, EPAISSEUR_MUR) if d.x == 0 \
		else Vector3(EPAISSEUR_MUR, haut - bas, CASE * part)
	_boite(racine, dims, centre, teinte)

## Le sens dans lequel cette case de chaussée GRIMPE : la voisine en chaussée
## qui est un palier plus haut, ou zéro si la case est plate.
static func _sens_de_la_rampe(ville: Ville2, c: Vector2i) -> Vector2i:
	if not ville.carte.route(c): return Vector2i.ZERO
	var mien := ville.carte.palier(c)
	for d in CarteVille.COTES:
		var v: Vector2i = c + d
		if ville.dedans(v) and ville.carte.route(v) and ville.carte.palier(v) > mien:
			return d
	return Vector2i.ZERO

## Le pied d'un mur du côté de la case `v` : le sol si c'est de la terre, le
## fond sous la nappe si c'est de l'eau, et très bas hors carte (un bord de
## carte ne doit pas montrer sa tranche).
## ⚠ LE MUR DESCEND JUSQU'AU COIN LE PLUS BAS DE LA VOISINE, pas jusqu'à son
## altitude de case. Le terrain est un maillage LISSÉ : ses coins sont soudés
## à la moyenne des quatre cases, si bien que la nappe passe sous l'altitude
## nominale dès qu'elle plonge. Un mur arrêté à `sol(v)` laissait une fente
## ouverte sous le lacet — on voyait le DESSOUS de la colline, en bleu sombre,
## entre la chaussée et l'herbe.
static func _pied_du_mur(ville: Ville2, v: Vector2i) -> float:
	if not ville.dedans(v):
		return -6.0
	if not ville.terre(v):
		return minf(ville.sol(v), TerrainV2.NIVEAU_MER) - 0.6
	var bas := ville.sol(v)
	for dj in 2:
		for di in 2:
			bas = minf(bas, TerrainV2.hauteur_coin(ville, v.x + di, v.y + dj))
	# ⚠ PAS DE MARGE ICI. Les 0,25 unités que ce mur creusait « pour être sûr »
	# suffisaient, sur un sol plat, à déclencher un muret par case.
	return bas

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
		# ⚠ L'ALTITUDE VIENT DU SOL RÉEL. Sur une case plate c'est le palier de
		# la tuile ; sur du terrain c'est le maillage interpolé — sinon un arbre
		# planté sur une dune s'enfonce d'un côté et flotte de l'autre.
		# ⚠ TROIS SOLS POSSIBLES, ET PAS UN DE MOINS.
		#   • une CHAUSSÉE est une tuile du kit, posée au palier ARRONDI ;
		#   • une autre case plate (dalle, lot) suit son altitude EXACTE — la
		#     promenade du bord de mer descend par quarts de palier, et l'objet
		#     posé dessus au palier arrondi flottait d'une demi-marche : c'est
		#     le « certains cailloux volent » du client ;
		#   • le reste suit le maillage lissé.
		var y := 0.0
		if ville.carte.route(c):
			y = float(ville.carte.palier(c)) * PALIER + EPAISSEUR_TUILE
		elif ville.plate(c):
			y = ville.sol(c) + EPAISSEUR_TUILE
		else:
			y = TerrainV2.hauteur_en(ville, x, z)
		# `y_abs` : une altitude IMPOSÉE, pour ce qui n'est pas posé au sol —
		# le bar et les lampadaires d'une jetée sont sur son tablier.
		if o.has("y_abs"): y = float(o["y_abs"])
		poser_objet(racine, String(o["m"]), Vector3(x, y, z), float(o.get("r", 0.0)),
			float(o.get("h", 0.0)), String(o.get("c", "")), o)

## Pose un objet : `modele` est un nom du catalogue (`KitVille2.PROPS`), une
## voiture (`voitures/...`), ou un chemin `res://` posé à l'échelle du kit.
static func poser_objet(parent: Node3D, modele: String, ou: Vector3, tourne := 0.0,
		hauteur := 0.0, teinte := "", fiche_objet := {}) -> void:
	if modele == "pelouse":
		_pelouse(parent, ou, float(fiche_objet.get("w", CASE)), float(fiche_objet.get("d", CASE)))
		return
	if modele == "plateforme":
		# Le tablier se compte AU-DESSUS DE LA MER, pas au-dessus du fond :
		# une jetée est plate, le fond ne l'est pas.
		_plateforme(parent, ou, tourne, float(fiche_objet.get("w", CASE)),
			float(fiche_objet.get("d", CASE)),
			TerrainV2.NIVEAU_MER + float(fiche_objet.get("y", 2.5)) - ou.y)
		return
	if modele == "roue":
		_grande_roue(parent, ou, tourne, float(fiche_objet.get("w", 40.0)))
		return
	if modele.begins_with("bateau:"):
		_bateau(parent, modele.trim_prefix("bateau:"), ou, tourne)
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

# ------------------------------------------------------------------ le bord de mer

## UNE PLATEFORME SUR PILOTIS : le tablier d'une jetée ou d'un ponton. Le
## tablier est posé à `y` au-dessus du niveau de la mer, les pilotis
## descendent jusqu'au fond — c'est ce qui fait qu'une jetée a l'air POSÉE sur
## l'eau et non peinte dessus.
const TEINTE_TABLIER := Color("#c9c3b4")
const TEINTE_PILOTIS := Color("#6b5a44")

static func _plateforme(parent: Node3D, ou: Vector3, tourne: float, largeur: float,
		profondeur: float, y: float) -> void:
	var base := Basis(Vector3.UP, tourne)
	var haut := ou + Vector3(0, y, 0)
	_boite_tournee(parent, base, Vector3(largeur, 0.7, profondeur), haut, TEINTE_TABLIER)
	# Un pilotis tous les six unités le long de la jetée, par paires.
	var n := maxi(2, int(profondeur / 6.0))
	var fond := TerrainV2.NIVEAU_MER - 3.0
	var hauteur := (haut.y - 0.35) - fond
	for k in n:
		var t := (float(k) + 0.5) / float(n) - 0.5
		for s in [-1.0, 1.0]:
			var p := haut + base * Vector3(s * (largeur * 0.5 - 0.9), 0, t * profondeur)
			_boite_tournee(parent, base, Vector3(0.9, hauteur, 0.9),
				Vector3(p.x, fond + hauteur * 0.5, p.z), TEINTE_PILOTIS)

## LA GRANDE ROUE (cahier § 3 : « une jetée avec bar et grande roue »). Le kit
## n'en a pas : deux jantes, des rayons, des nacelles et deux jambes en A.
const TEINTE_ROUE := Color("#e8e4dc")
const NACELLES := [Color("#ff2f86"), Color("#ff9040"), Color("#2fe0d0"), Color("#ffe14d")]

static func _grande_roue(parent: Node3D, ou: Vector3, tourne: float, diametre: float) -> void:
	var base := Basis(Vector3.UP, tourne)
	var r := diametre * 0.5
	var moyeu := ou + Vector3(0, r + 3.0, 0)
	# Les deux jambes : un A de chaque côté du moyeu.
	for s in [-1.0, 1.0]:
		for t in [-1.0, 1.0]:
			var pied := ou + base * Vector3(t * r * 0.45, 0, s * 3.2)
			var haut := moyeu + base * Vector3(0, 0, s * 1.6)
			_poutre(parent, pied, haut, 1.2, TEINTE_PILOTIS)
	# Les deux jantes et leurs rayons.
	var pas := 16
	for s in [-1.0, 1.0]:
		var centre := moyeu + base * Vector3(0, 0, s * 1.6)
		for k in pas:
			var a := TAU * float(k) / float(pas)
			var b := TAU * float(k + 1) / float(pas)
			var pa := centre + base * Vector3(cos(a) * r, sin(a) * r, 0)
			var pb := centre + base * Vector3(cos(b) * r, sin(b) * r, 0)
			_poutre(parent, pa, pb, 0.6, TEINTE_ROUE)
			if k % 2 == 0:
				_poutre(parent, centre, pa, 0.4, TEINTE_ROUE)
	# Les nacelles, accrochées au bord.
	for k in pas:
		var a := TAU * float(k) / float(pas)
		var p := moyeu + base * Vector3(cos(a) * r, sin(a) * r, 0)
		_boite_tournee(parent, base, Vector3(2.4, 2.0, 3.4), p - Vector3(0, 1.6, 0),
			NACELLES[k % NACELLES.size()])

## Une poutre entre deux points : une boîte orientée le long du segment.
static func _poutre(parent: Node3D, a: Vector3, b: Vector3, section: float, teinte: Color) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.01: return
	var axe := d / l
	var cote := Vector3.UP.cross(axe)
	if cote.length_squared() < 1.0e-6: cote = Vector3.RIGHT
	cote = cote.normalized()
	var base := Basis(cote, axe, cote.cross(axe)).orthonormalized()
	_boite_tournee(parent, base, Vector3(section, l, section), a + d * 0.5, teinte)

static func _boite_tournee(parent: Node3D, base: Basis, dims: Vector3, ou: Vector3, teinte: Color) -> void:
	if _cube == null:
		_cube = BoxMesh.new()
		_cube.size = Vector3.ONE
	var n := MeshInstance3D.new()
	n.mesh = _cube
	n.material_override = _teinte_unie(teinte)
	# ⚠ L'ÉCHELLE AVANT LA ROTATION (voir `_panneau`) : `Basis.scaled()` met à
	# l'échelle dans le monde, et une poutre en biais sortait de travers.
	n.transform = Transform3D(base * Basis.from_scale(dims), ou)
	parent.add_child(n)

static var _unies: Dictionary = {}

static func _teinte_unie(teinte: Color) -> StandardMaterial3D:
	var cle := teinte.to_html()
	if _unies.has(cle): return _unies[cle]
	var m := StandardMaterial3D.new()
	m.albedo_color = teinte
	m.roughness = 0.9
	_unies[cle] = m
	return m

## UN BATEAU À FLOT : la coque posée à la ligne de flottaison, enfoncée de son
## tirant d'eau. Sans le tirant, une coque flottait deux mètres au-dessus de
## la mer, et un cargo avait l'air d'un jouet posé sur une vitre.
static func _bateau(parent: Node3D, nom: String, ou: Vector3, tourne: float) -> void:
	var fiche: Dictionary = KitVille2.BATEAUX.get(nom, {})
	if fiche.is_empty(): return
	var chemin := KitVille2.chemin(String(fiche["m"]))
	if not ResourceLoader.exists(chemin): return
	var n := MeshInstance3D.new()
	# Les coques sont longues selon Z : on demande la longueur sur cet axe.
	n.mesh = FormesCarnage.maillage_kenney(chemin, float(fiche["l"]), Vector3.AXIS_Z, 0.0)
	n.material_override = _matiere(chemin, Color.WHITE)
	n.transform = Transform3D(Basis(Vector3.UP, tourne),
		Vector3(ou.x, TerrainV2.NIVEAU_MER - float(fiche["tirant"]), ou.z))
	n.set_meta("modele", "bateau:" + nom)
	_noter(chemin)
	parent.add_child(n)

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
	# ⚠ LA TUILE DÉBORDE DE SA CASE, EXPRÈS. Une tuile Kenney mesure exactement
	# une case (mesuré : 1,0000 x 1,0000, centrée sur son origine) — donc deux
	# tuiles voisines se touchent pile. Mais leur dessus est BISEAUTÉ : le
	# chanfrein de l'une plus celui de l'autre font, vu du ciel, un LISERÉ CLAIR
	# à chaque joint, et toute la ville se lit comme un damier de dalles
	# séparées (« aucune route n'est collée, on voit l'écart entre deux
	# routes », client, 12/09). Un chouïa d'échelle en plus et le biseau d'une
	# tuile passe SOUS le dessus plat de sa voisine : le joint disparaît, sans
	# rien déplacer et sans z-fighting — le chanfrein est plus bas que la face
	# qui le couvre.
	n.transform = Transform3D(Basis(Vector3.UP, PI * 0.5 * float(quarts)).scaled(
		Vector3.ONE * CASE * RECOUVREMENT), ou)
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
