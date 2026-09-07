class_name MorceauVille
extends Node3D
## Un MORCEAU de ville rendu : vingt tuiles sur vingt, bâti d'un coup à partir
## des fiches du plan, et libéré quand le joueur s'éloigne.
##
## Tout ce qu'un morceau contient tient en une douzaine d'appels de dessin :
## UN maillage de sol (quatre cents quadrilatères qui portent chacun leur type
## de sol), UNE nappe d'immeubles (des boîtes, le shader fait le reste), une
## nappe par modèle de mobilier et par modèle de voiture dormante, un maillage
## pour les enseignes et balises, un pour les flaques de lumière. L'ancienne
## ville posait un nœud par voiture garée et par passant : quatre cents
## voitures faisaient deux mille appels de dessin, et le navigateur tombait à
## dix images par seconde. Ici, neuf morceaux autour du joueur en font moins de
## deux cents pour une ville sans bord visible.
##
## Le morceau ne SIMULE rien : il peint des fiches. Une voiture dormante qui se
## réveille (volée, percutée) sort de sa nappe (`cacher_voiture`) et devient
## un nœud ordinaire de l'écran de jeu, comme les voitures de l'hôte.

const E := Decor.ECHELLE

## Les modèles du mobilier : le fichier, son échelle, et pour les lampadaires
## la tête qui éclaire. Les kits n'ont pas la même unité (KayKit ~1 = 5 m,
## Kenney banlieue 1 = 7,5 m, Kenney industrie 1 = 10 m), d'où des échelles
## qui n'ont rien à voir entre elles.
const MODELES := {
	"lampadaire": {"f": "res://modeles/mobilier/streetlight.gltf", "s": 4.8,
		"lampe": {"d": Vector2(-1.15, 0.0), "y": 4.4, "r": 5.4, "c": Color(1.0, 0.72, 0.42), "a": 0.5}},
	"lampadaire_parc": {"f": "res://modeles/mobilier/streetlight.gltf", "s": 3.4,
		"lampe": {"d": Vector2(-0.8, 0.0), "y": 3.1, "r": 4.2, "c": Color(0.95, 0.8, 0.55), "a": 0.42}},
	"feu": {"f": "res://modeles/mobilier/trafficlight_A.gltf", "s": 4.8},
	"borne": {"f": "res://modeles/mobilier/firehydrant.gltf", "s": 4.5},
	"poubelle": {"f": "res://modeles/mobilier/box_A.gltf", "s": 4.2},
	"banc": {"f": "res://modeles/mobilier/bench.gltf", "s": 6.0},
	"benne": {"f": "res://modeles/mobilier/dumpster.gltf", "s": 4.8},
	"buisson": {"f": "res://modeles/mobilier/bush.gltf", "s": 4.8},
	"arbre": {"f": "res://modeles/banlieue/tree-large.glb", "s": 7.5},
	"arbre_petit": {"f": "res://modeles/banlieue/tree-small.glb", "s": 7.5},
	"conteneur_a": {"f": "res://modeles/industrie/shipping-container-a.glb", "s": 6.0},
	"conteneur_b": {"f": "res://modeles/industrie/shipping-container-b.glb", "s": 6.0},
	"citerne": {"f": "res://modeles/industrie/detail-tank-large.glb", "s": 4.5},
	"cheminee": {"f": "res://modeles/industrie/chimney-large.glb", "s": 5.0},
	"chateau_eau": {"f": "res://modeles/industrie/water-tower.glb", "s": 5.0},
	"fontaine": {"f": "res://modeles/ville/pavement-fountain.glb", "s": 6.0},
}

var cle := Vector2i.ZERO
var voitures: Dictionary = {}     ## id de voiture dormante -> [MultiMesh, indice]
var cabines: Array = []           ## nœuds de cabine posés dans ce morceau, {n, id}

## Le chantier : le morceau se bâtit en ÉTAPES, une par image. Tout d'un coup,
## c'était soixante millisecondes dans le navigateur — quatre images perdues,
## une saccade à chaque rue quand on roule vite. Le sol d'abord, puis les
## immeubles, le mobilier, les voitures, les lumières : le morceau apparaît
## progressivement à quinze cents pixels, là où personne ne regarde encore.
var _plan: PlanVille
var _reveillees: Dictionary = {}
var _etape := 0
var _fiches: Array = []
var _batis: Array = []                 ## [Transform3D, Color]
var _props: Dictionary = {}            ## modele -> Array[Transform3D]
var _places: Dictionary = {}           ## modele -> Array[{t, c, id}]
var _lumineux: SurfaceTool
var _flaques: SurfaceTool
var _quelque_chose_de_lumineux := false
var _quelque_flaque := false

## Ouvre le chantier du morceau `cle` : ses tuiles vont de cle*MORCEAU à
## (cle+1)*MORCEAU. `reveillees` : les voitures dormantes que l'hôte a déjà
## réveillées, à ne pas peindre en dormantes — elles roulent ailleurs, comme
## nœuds de l'écran.
func commencer(plan: PlanVille, cle_du_morceau: Vector2i, reveillees: Dictionary) -> void:
	cle = cle_du_morceau
	_plan = plan
	_reveillees = reveillees
	_etape = 0
	_lumineux = SurfaceTool.new()
	_lumineux.begin(Mesh.PRIMITIVE_TRIANGLES)
	_flaques = SurfaceTool.new()
	_flaques.begin(Mesh.PRIMITIVE_TRIANGLES)

## Tout d'un coup, pour le départ.
func batir(plan: PlanVille, cle_du_morceau: Vector2i, reveillees: Dictionary) -> void:
	commencer(plan, cle_du_morceau, reveillees)
	while not avancer():
		pass

func fini() -> bool:
	return _etape >= 6

## Une étape de chantier. Renvoie vrai quand le morceau est complet.
func avancer() -> bool:
	match _etape:
		0: _lire_les_fiches()
		1: _poser_le_sol()
		2: _poser_les_immeubles()
		3: _poser_le_mobilier()
		4: _poser_les_voitures()
		5:
			_poser_les_lumieres()
			_poser_les_lieux(_plan, cle.x * PlanVille.MORCEAU, cle.y * PlanVille.MORCEAU)
			_fiches.clear()
			_batis.clear()
			_props.clear()
			_places.clear()
	_etape += 1
	return _etape >= 6

## Étape 0 : les fiches des quatre cents tuiles, et tout ce qu'on en tire qui
## n'est pas encore un nœud.
func _lire_les_fiches() -> void:
	var c0 := cle.x * PlanVille.MORCEAU
	var l0 := cle.y * PlanVille.MORCEAU
	var plan := _plan
	var reveillees := _reveillees
	var batis := _batis
	var props := _props
	var places := _places
	var lumineux := _lumineux
	var flaques := _flaques
	var quelque_chose_de_lumineux := false
	var quelque_flaque := false

	for l in range(l0, l0 + PlanVille.MORCEAU):
		for c in range(c0, c0 + PlanVille.MORCEAU):
			var fiche := plan.tuile(c, l)
			_fiches.append(fiche)
			for b in fiche["batis"]:
				batis.append(_transformation_de_bati(b))
				if b.get("chapeau", false) or (int(b["style"]) == PlanVille.F_TOUR and float(b["h"]) >= 24.0):
					# La balise rouge d'une tour : ce qui dit la hauteur de nuit.
					_cube(lumineux, Decor.vers3d(b["p"], float(b["y"]) + float(b["h"]) + 0.6), 0.45, Palette.CRITIQUE.lightened(0.2))
					quelque_chose_de_lumineux = true
			for pr in fiche["props"]:
				var nom := String(pr["m"])
				if not MODELES.has(nom):
					continue
				var fiche_m: Dictionary = MODELES[nom]
				var echelle: float = float(fiche_m["s"]) * float(pr.get("s", 1.0))
				var base := Basis(Vector3.UP, -float(pr["a"])).scaled(Vector3.ONE * echelle)
				if not props.has(nom):
					props[nom] = []
				props[nom].append(Transform3D(base, Decor.vers3d(pr["p"])))
				if fiche_m.has("lampe"):
					var lampe: Dictionary = fiche_m["lampe"]
					var decal: Vector2 = (lampe["d"] as Vector2).rotated(float(pr["a"])) * float(pr.get("s", 1.0))
					var tete := Decor.vers3d(pr["p"]) + Vector3(decal.x, float(lampe["y"]) * float(pr.get("s", 1.0)), decal.y)
					_cube(lumineux, tete, 0.42, Color(1.0, 0.9, 0.7))
					_flaque(flaques, Vector3(tete.x, 0.04, tete.z), float(lampe["r"]), Color(lampe["c"], float(lampe["a"])))
					quelque_chose_de_lumineux = true
					quelque_flaque = true
			for pl in fiche["places"]:
				var d := plan.decrire(fiche, pl)
				if reveillees.has(int(d["id"])):
					continue
				var modele := int(d["modele"])
				if not places.has(modele):
					places[modele] = []
				var couleur := Color.WHITE
				if int(d["gang"]) >= 0:
					couleur = plan.couleur_du_gang(int(d["gang"])).lerp(Color.WHITE, 0.45)
				var base_v := Basis(Vector3.UP, -float(d["a"]) + FormesCarnage.ROTATION_KIT).scaled(Vector3.ONE * FormesCarnage.ECHELLE_VOITURE)
				places[modele].append({"t": Transform3D(base_v, Decor.vers3d(d["p"])), "c": couleur, "id": int(d["id"])})
			for n in fiche["neons"]:
				_enseigne(lumineux, n)
				_flaque(flaques, Decor.vers3d(Vector2(n["p"]) + Vector2(n["n"]) * 14.0, 0.05), 3.4, Color(n["c"], 0.28))
				quelque_chose_de_lumineux = true
				quelque_flaque = true
	_quelque_chose_de_lumineux = quelque_chose_de_lumineux
	_quelque_flaque = quelque_flaque

## Étape 1 : le sol, un seul maillage, une seule matière.
func _poser_le_sol() -> void:
	var sol := SurfaceTool.new()
	sol.begin(Mesh.PRIMITIVE_TRIANGLES)
	for fiche in _fiches:
		_dalle(sol, fiche)
	var noeud_sol := MeshInstance3D.new()
	noeud_sol.mesh = sol.commit()
	noeud_sol.material_override = MatieresCarnage.sol()
	noeud_sol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(noeud_sol)

## Étape 2 : les immeubles, des boîtes unitaires — le shader dessine les façades.
func _poser_les_immeubles() -> void:
	var batis := _batis
	if not batis.is_empty():
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		var boite := BoxMesh.new()
		boite.size = Vector3.ONE
		multi.mesh = boite
		multi.instance_count = batis.size()
		for i in batis.size():
			multi.set_instance_transform(i, batis[i][0])
			multi.set_instance_color(i, batis[i][1])
		var noeud := MultiMeshInstance3D.new()
		noeud.multimesh = multi
		noeud.material_override = MatieresCarnage.facade()
		noeud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(noeud)

## Étape 3 : le mobilier, une nappe par modèle.
func _poser_le_mobilier() -> void:
	var props := _props
	for nom in props:
		var liste: Array = props[nom]
		var multi_p := MultiMesh.new()
		multi_p.transform_format = MultiMesh.TRANSFORM_3D
		multi_p.mesh = FormesCarnage.maillage_fusionne(String(MODELES[nom]["f"]))
		multi_p.instance_count = liste.size()
		for i in liste.size():
			multi_p.set_instance_transform(i, liste[i])
		var noeud_p := MultiMeshInstance3D.new()
		noeud_p.multimesh = multi_p
		# Les buissons et les bancs ne projettent pas d'ombre : trop petits pour
		# qu'on la voie, assez nombreux pour qu'on la paie.
		noeud_p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if nom in ["buisson", "banc", "borne", "poubelle"] \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(noeud_p)

## Étape 4 : les voitures dormantes, une nappe par modèle, une couleur par instance.
func _poser_les_voitures() -> void:
	var places := _places
	for modele in places:
		var liste_v: Array = places[modele]
		var multi_v := MultiMesh.new()
		multi_v.transform_format = MultiMesh.TRANSFORM_3D
		multi_v.use_colors = true
		multi_v.mesh = FormesCarnage.maillage_voiture(int(modele))
		multi_v.instance_count = liste_v.size()
		for i in liste_v.size():
			multi_v.set_instance_transform(i, liste_v[i]["t"])
			multi_v.set_instance_color(i, liste_v[i]["c"])
			voitures[int(liste_v[i]["id"])] = [multi_v, i]
		var noeud_v := MultiMeshInstance3D.new()
		noeud_v.multimesh = multi_v
		noeud_v.material_override = FormesCarnage.matiere_voiture_teintee(int(modele))
		noeud_v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(noeud_v)

## Étape 5 : les enseignes, balises et bulbes en un maillage, les flaques de
## lumière en un autre.
func _poser_les_lumieres() -> void:
	if _quelque_chose_de_lumineux:
		var noeud_l := MeshInstance3D.new()
		noeud_l.mesh = _lumineux.commit()
		noeud_l.material_override = MatieresCarnage.lumineux()
		noeud_l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(noeud_l)
	if _quelque_flaque:
		var noeud_f := MeshInstance3D.new()
		noeud_f.mesh = _flaques.commit()
		noeud_f.material_override = MatieresCarnage.flaque()
		noeud_f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(noeud_f)

## Les lieux dont le pâté tombe dans ce morceau : tag de repaire, dalle de
## garage, cabine, cercle d'arène. Ils vivent et meurent avec le morceau.
func _poser_les_lieux(plan: PlanVille, c0: int, l0: int) -> void:
	var rect := Rect2(Vector2(c0, l0) * PlanVille.PAS, Vector2(PlanVille.MORCEAU, PlanVille.MORCEAU) * PlanVille.PAS)
	var lieux := plan.lieux_autour(rect.get_center(), rect.size.length() * 0.5 + PlanVille.RAYON_REPAIRE)
	for r in lieux["repaires"]:
		var coin := PlanVille.coin_pate(r["pate"])
		if not rect.has_point(PlanVille.centre_tuile(coin.x, coin.y)):
			continue
		var tag := FormesCarnage.tag_de_gang(plan.couleur_du_gang(int(r["gang"])), plan.nom_du_gang(int(r["gang"])))
		tag.position = Decor.vers3d(r["p"])
		add_child(tag)
	for g in lieux["garages"]:
		var coin_g := PlanVille.coin_pate(g["pate"])
		if not rect.has_point(PlanVille.centre_tuile(coin_g.x, coin_g.y)):
			continue
		var dalle := FormesCarnage.dalle_garage()
		dalle.position = Decor.vers3d(g["p"])
		add_child(dalle)
	for c in lieux["cabines"]:
		var coin_c := PlanVille.coin_pate(c["pate"])
		if not rect.has_point(PlanVille.centre_tuile(coin_c.x, coin_c.y)):
			continue
		var poste := FormesCarnage.cabine(int(c["id"]))
		poste.position = Decor.vers3d(c["p"])
		add_child(poste)
		cabines.append({"n": poste, "id": int(c["id"])})
	for a in lieux["arenes"]:
		var coin_a := PlanVille.coin_pate(a["pate"])
		if not rect.has_point(PlanVille.centre_tuile(coin_a.x, coin_a.y)):
			continue
		var cercle := FormesCarnage.cercle_arene(int(a["id"]))
		cercle.position = Decor.vers3d(a["p"])
		add_child(cercle)

## Une voiture dormante se réveille : on l'efface de sa nappe (échelle nulle),
## le nœud de l'écran de jeu prend le relais.
func cacher_voiture(id: int) -> void:
	if not voitures.has(id):
		return
	var entree: Array = voitures[id]
	var multi: MultiMesh = entree[0]
	var t := multi.get_instance_transform(int(entree[1]))
	multi.set_instance_transform(int(entree[1]), Transform3D(Basis.from_scale(Vector3(0.001, 0.001, 0.001)), t.origin))
	voitures.erase(id)

# ------------------------------------------------------------ géométrie

func _transformation_de_bati(b: Dictionary) -> Array:
	var w := float(b["w"]) * E
	var d := float(b["d"]) * E
	var h := float(b["h"])
	var base := Basis.from_scale(Vector3(w, h, d))
	var origine := Decor.vers3d(b["p"], float(b["y"]) + h * 0.5)
	var c: Color = b["c"]
	return [Transform3D(base, origine), Color(c.r, c.g, c.b, (float(b["style"]) + 0.5) / 8.0)]

## Une tuile de sol : un quadrilatère à plat, UV tournées selon la fiche,
## UV2 = (type de sol, graine), couleur = teinte du territoire. L'eau est
## un peu plus basse : la marche d'ombre qui en résulte fait le quai.
func _dalle(st: SurfaceTool, fiche: Dictionary) -> void:
	var c := int(fiche["c"])
	var l := int(fiche["l"])
	var sol := int(fiche["sol"])
	var y := -0.3 if sol == PlanVille.S_EAU else 0.0
	var rot := int(fiche["rot"])
	var teinte: Color = fiche["teinte"]
	# La graine : du bruit pour le shader, et ≥ 0,5 sur une avenue (le shader y
	# trace la double ligne).
	var graine := float(posmod(hash(Vector2i(c, l)), 1000)) / 2000.0 + float(fiche.get("graine", 0.0))
	var coins := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var indices := [0, 1, 2, 0, 2, 3]
	for k in indices:
		var uv: Vector2 = coins[k]
		var p := Vector3((c + uv.x) * PlanVille.TUILE, y, (l + uv.y) * PlanVille.TUILE)
		st.set_color(teinte)
		st.set_uv(_uv_tournee(uv, rot))
		st.set_uv2(Vector2(float(sol), graine))
		st.set_normal(Vector3.UP)
		st.add_vertex(p)

## Les coordonnées de texture d'un coin de tuile dont le dessin a été tourné de
## `rot` quarts de tour dans le sens horaire : on défait la rotation.
static func _uv_tournee(uv: Vector2, rot: int) -> Vector2:
	var r := uv
	for i in posmod(rot, 4):
		r = Vector2(r.y, 1.0 - r.x)
	return r

## Un petit cube lumineux (bulbe de lampadaire, balise).
func _cube(st: SurfaceTool, centre: Vector3, cote: float, couleur: Color) -> void:
	var h := cote * 0.5
	var faces := [
		[Vector3(-h, -h, h), Vector3(h, -h, h), Vector3(h, h, h), Vector3(-h, h, h)],
		[Vector3(h, -h, -h), Vector3(-h, -h, -h), Vector3(-h, h, -h), Vector3(h, h, -h)],
		[Vector3(-h, h, -h), Vector3(-h, h, h), Vector3(h, h, h), Vector3(h, h, -h)],
		[Vector3(-h, -h, -h), Vector3(-h, -h, h), Vector3(-h, h, h), Vector3(-h, h, -h)],
		[Vector3(h, -h, h), Vector3(h, -h, -h), Vector3(h, h, -h), Vector3(h, h, h)],
	]
	for face in faces:
		_quad(st, [centre + face[0], centre + face[1], centre + face[2], centre + face[3]], couleur)

func _quad(st: SurfaceTool, p: Array, couleur: Color) -> void:
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_color(couleur)
		st.set_uv(uvs[k])
		st.set_normal(Vector3.UP)
		st.add_vertex(p[k])

## Une enseigne : un rectangle debout, collé à la façade, à double face.
func _enseigne(st: SurfaceTool, n: Dictionary) -> void:
	var centre := Decor.vers3d(n["p"], float(n["y"]))
	var normale: Vector2 = n["n"]
	var le_long := Vector3(-normale.y, 0.0, normale.x) * float(n["w"]) * 0.5 * E
	var haut := Vector3(0.0, float(n["h"]) * 0.5, 0.0)
	var c: Color = (n["c"] as Color).lerp(Color.WHITE, 0.25)
	_quad(st, [centre - le_long - haut, centre + le_long - haut, centre + le_long + haut, centre - le_long + haut], c)
	# Un cadre sombre derrière : c'est lui qui donne l'épaisseur du caisson.
	var recul := Vector3(normale.x, 0.0, normale.y) * -0.08
	var bordure := c.darkened(0.7)
	var marge := le_long * 1.08
	var hauteur := haut * 1.25
	_quad(st, [centre + recul - marge - hauteur, centre + recul + marge - hauteur,
		centre + recul + marge + hauteur, centre + recul - marge + hauteur], bordure)

## Une flaque de lumière : un quadrilatère à plat, la couleur au sommet.
func _flaque(st: SurfaceTool, centre: Vector3, rayon: float, couleur: Color) -> void:
	var dx := Vector3(rayon, 0, 0)
	var dz := Vector3(0, 0, rayon)
	_quad(st, [centre - dx - dz, centre + dx - dz, centre + dx + dz, centre - dx + dz], couleur)
