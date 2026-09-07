class_name MorceauVille
extends Node3D
## Un MORCEAU de ville rendu : vingt tuiles sur vingt, bâti à partir des fiches
## du plan, en VOXELS, et libéré quand le joueur s'éloigne.
##
## Un morceau tient en une poignée d'appels de dessin : UN maillage de sol
## (quatre cents quadrilatères qui portent chacun leur type de sol), UNE nappe
## de cubes pour tout ce qui est bâti ou posé — immeubles, arbres, lampadaires,
## bancs, conteneurs —, une nappe par modèle de voiture dormante, un maillage
## pour les enseignes, un pour les flaques de lumière. L'ancienne ville posait
## un nœud par voiture garée et par passant : deux mille appels de dessin, dix
## images par seconde dans le navigateur. Ici, six morceaux autour du joueur en
## font moins de cent pour une ville sans bord visible.
##
## La nappe de cubes se remplit par son TAMPON (`MultiMesh.buffer`) : seize
## nombres par cube, posés d'un bloc. Quinze mille appels à
## `set_instance_transform` prenaient deux images ; le tampon, une.
##
## Le morceau ne SIMULE rien : il peint des fiches. Une voiture dormante qui se
## réveille sort de sa nappe (`cacher_voiture`) ; un voxel d'immeuble que
## l'hôte a cassé disparaît (`casser`) et les cubes de l'intérieur qu'il cachait
## apparaissent. Le morceau garde pour cela l'occupation de chaque immeuble.

const E := Decor.ECHELLE
const RESERVE := 0.12          ## part d'instances gardées libres pour les intérieurs dévoilés

## Les lampadaires éclairent le sol : la flaque, sa portée, sa couleur.
const LAMPES := {
	"lampadaire": {"d": 1.15, "r": 5.4, "c": Color(1.0, 0.72, 0.42), "a": 0.5},
	"lampadaire_parc": {"d": 0.8, "r": 4.2, "c": Color(0.95, 0.8, 0.55), "a": 0.42},
}

var cle := Vector2i.ZERO
var voitures: Dictionary = {}     ## id de voiture dormante -> [MultiMesh, indice]
var cabines: Array = []           ## nœuds de cabine posés dans ce morceau, {n, id}

## Le chantier : le morceau se bâtit en ÉTAPES, une par image. Tout d'un coup,
## c'était soixante millisecondes dans le navigateur — quatre images perdues,
## une saccade à chaque rue quand on roule vite. Le sol d'abord, puis les
## cubes, les voitures, les lumières : le morceau apparaît progressivement à
## quinze cents pixels, là où personne ne regarde encore.
var _plan: PlanVille
var _reveillees: Dictionary = {}
var _detruits: Dictionary = {}
var _etape := 0
var _fiches: Array = []
var _tampon := PackedFloat32Array()
var _n := 0
var _immeubles: Dictionary = {}       ## id d'immeuble -> {"v": voxels, "inst": {clé locale -> instance}}
var _libres: Array = []               ## instances libres (cachées)
var _multi: MultiMesh
var _places: Dictionary = {}          ## modele -> Array[{t, c, id}]
var _lumineux: SurfaceTool
var _flaques: SurfaceTool
var _quelque_chose_de_lumineux := false
var _quelque_flaque := false

## Ouvre le chantier du morceau `cle` : ses tuiles vont de cle*MORCEAU à
## (cle+1)*MORCEAU. `reveillees` : les voitures dormantes que l'hôte a déjà
## réveillées, à ne pas peindre. `detruits` : les voxels déjà cassés dans la
## manche (id d'immeuble -> clés locales), à ne pas peindre non plus.
func commencer(plan: PlanVille, cle_du_morceau: Vector2i, reveillees: Dictionary, detruits: Dictionary = {}) -> void:
	cle = cle_du_morceau
	_plan = plan
	_reveillees = reveillees
	_detruits = detruits
	_etape = 0
	_lumineux = SurfaceTool.new()
	_lumineux.begin(Mesh.PRIMITIVE_TRIANGLES)
	_flaques = SurfaceTool.new()
	_flaques.begin(Mesh.PRIMITIVE_TRIANGLES)

## Tout d'un coup, pour le départ.
func batir(plan: PlanVille, cle_du_morceau: Vector2i, reveillees: Dictionary, detruits: Dictionary = {}) -> void:
	commencer(plan, cle_du_morceau, reveillees, detruits)
	while not avancer():
		pass

func fini() -> bool:
	return _etape >= 5

## Une étape de chantier. Renvoie vrai quand le morceau est complet.
func avancer() -> bool:
	match _etape:
		0: _lire_les_fiches()
		1: _poser_le_sol()
		2: _poser_les_cubes()
		3: _poser_les_voitures()
		4:
			_poser_les_lumieres()
			_poser_les_lieux(_plan, cle.x * PlanVille.MORCEAU, cle.y * PlanVille.MORCEAU)
			_fiches.clear()
			_places.clear()
			_tampon = PackedFloat32Array()
	_etape += 1
	return _etape >= 5

# ------------------------------------------------------------ étape 0 : les fiches

## L'identifiant d'un immeuble : sa tuile d'ancrage et son rang dans la fiche.
## C'est lui qui voyage sur le réseau avec les voxels cassés.
static func id_immeuble(colonne: int, ligne: int, rang: int) -> int:
	return (colonne * PlanVille.LIGNES + ligne) * 8 + rang

static func tuile_d_immeuble(id: int) -> Vector2i:
	var tuile := id / 8
	return Vector2i(tuile / PlanVille.LIGNES, posmod(tuile, PlanVille.LIGNES))

## Les fiches des quatre cents tuiles, et tout ce qu'on en tire : les cubes des
## immeubles (avec leur occupation, pour la casse) et du mobilier, les places
## de voitures, les enseignes et les flaques.
func _lire_les_fiches() -> void:
	var c0 := cle.x * PlanVille.MORCEAU
	var l0 := cle.y * PlanVille.MORCEAU
	for l in range(l0, l0 + PlanVille.MORCEAU):
		for c in range(c0, c0 + PlanVille.MORCEAU):
			var fiche := _plan.tuile(c, l)
			_fiches.append(fiche)
			var rang := 0
			for b in fiche["batis"]:
				_poser_immeuble(b, id_immeuble(c, l, rang))
				rang += 1
				if b.get("chapeau", false) or (int(b["style"]) == PlanVille.F_TOUR and float(b["h"]) >= 24.0):
					# La balise rouge d'une tour : ce qui dit la hauteur de nuit.
					_cube(Decor.vers3d(b["p"], float(b["y"]) + float(b["h"]) + 0.6), 0.7,
						Color(Palette.CRITIQUE.lightened(0.2), VoxelsCarnage.LUMIERE))
			var rang_p := 0
			for pr in fiche["props"]:
				var nom := String(pr["m"])
				var graine := hash(Vector3i(c, l, rang_p))
				rang_p += 1
				for cube in VoxelsCarnage.mobilier(nom, pr["p"], float(pr["a"]), float(pr.get("s", 1.0)), graine):
					_cube(cube[0], float(cube[1]), cube[2])
				if LAMPES.has(nom):
					var lampe: Dictionary = LAMPES[nom]
					var decal: Vector2 = Vector2(-float(lampe["d"]), 0.0).rotated(float(pr["a"]))
					var tete := Decor.vers3d(pr["p"]) + Vector3(decal.x, 0.0, decal.y)
					_flaque(_flaques, Vector3(tete.x, 0.04, tete.z), float(lampe["r"]), Color(lampe["c"], float(lampe["a"])))
					_quelque_flaque = true
			for pl in fiche["places"]:
				var d := _plan.decrire(fiche, pl)
				if _reveillees.has(int(d["id"])):
					continue
				var modele := int(d["modele"])
				if not _places.has(modele):
					_places[modele] = []
				var couleur := VoxelsCarnage.peinture(modele, int(d["id"]))
				if int(d["gang"]) >= 0:
					couleur = _plan.couleur_du_gang(int(d["gang"])).lerp(Color.WHITE, 0.3)
				var base_v := Basis(Vector3.UP, -float(d["a"]))
				_places[modele].append({"t": Transform3D(base_v, Decor.vers3d(d["p"])), "c": couleur, "id": int(d["id"])})
			for n in fiche["neons"]:
				_enseigne(_lumineux, n)
				_flaque(_flaques, Decor.vers3d(Vector2(n["p"]) + Vector2(n["n"]) * 14.0, 0.05), 3.4, Color(n["c"], 0.28))
				_quelque_chose_de_lumineux = true
				_quelque_flaque = true

## Un immeuble : sa grille de voxels, les cubes cassés retirés, et seulement
## les cubes EXPOSÉS posés dans la nappe. L'intérieur attend qu'on l'ouvre.
func _poser_immeuble(b: Dictionary, id: int) -> void:
	var v := VoxelsCarnage.immeuble(b, id)
	var solide: PackedByteArray = v["solide"]
	var nx := int(v["nx"])
	var nz := int(v["nz"])
	var ny := int(v["ny"])
	# Ce que la manche a déjà cassé dans cet immeuble.
	var casses: Array = _detruits.get(id, [])
	for locale in casses:
		var i := int(locale) / 512
		var j := (int(locale) / 32) % 16
		var k := int(locale) % 32
		if i < nx and j < nz and k < ny:
			solide[(i * nz + j) * ny + k] = 0
	var inst: Dictionary = {}
	var couleurs: PackedColorArray = v["couleurs"]
	for i in nx:
		for j in nz:
			for k in ny:
				if solide[(i * nz + j) * ny + k] == 0:
					continue
				if not _expose(solide, nx, nz, ny, i, j, k):
					continue
				inst[(i * 16 + j) * 32 + k] = _n
				_poser_voxel(v, i, j, k, couleurs[(i * nz + j) * ny + k])
	_immeubles[id] = {"v": v, "inst": inst}

static func _expose(solide: PackedByteArray, nx: int, nz: int, ny: int, i: int, j: int, k: int) -> bool:
	if i == 0 or j == 0 or k == 0 or i == nx - 1 or j == nz - 1 or k == ny - 1:
		return true
	return solide[((i - 1) * nz + j) * ny + k] == 0 or solide[((i + 1) * nz + j) * ny + k] == 0 \
		or solide[(i * nz + j - 1) * ny + k] == 0 or solide[(i * nz + j + 1) * ny + k] == 0 \
		or solide[(i * nz + j) * ny + k - 1] == 0 or solide[(i * nz + j) * ny + k + 1] == 0

func _centre_voxel(v: Dictionary, i: int, j: int, k: int) -> Vector3:
	var t := float(v["taille"])
	var h := float(v["hauteur"])
	return (v["origine"] as Vector3) + Vector3((i + 0.5) * t, (k + 0.5) * h, (j + 0.5) * t)

func _poser_voxel(v: Dictionary, i: int, j: int, k: int, couleur: Color) -> void:
	_instance(_centre_voxel(v, i, j, k), Vector3(float(v["taille"]), float(v["hauteur"]), float(v["taille"])), couleur)

func _cube(centre: Vector3, cote: float, couleur: Color) -> void:
	_instance(centre, Vector3(cote, cote, cote), couleur)

## Seize nombres dans le tampon : la transformation (trois lignes de quatre) et
## la couleur. C'est le format de `MultiMesh.buffer` avec les couleurs.
func _instance(centre: Vector3, taille: Vector3, couleur: Color) -> void:
	_tampon.append_array(PackedFloat32Array([
		taille.x, 0.0, 0.0, centre.x,
		0.0, taille.y, 0.0, centre.y,
		0.0, 0.0, taille.z, centre.z,
		couleur.r, couleur.g, couleur.b, couleur.a]))
	_n += 1

# ------------------------------------------------------------ étape 1 : le sol

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

# ------------------------------------------------------------ étape 2 : les cubes

static var _cube_unitaire: ArrayMesh

## Le maillage du cube unitaire, avec des UV de 0 à 1 par face : c'est ce que
## le shader lit pour biseauter les arêtes. `BoxMesh` étale ses UV en atlas,
## ça ne marche pas.
static func cube_unitaire() -> ArrayMesh:
	if _cube_unitaire == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		VoxelsCarnage._cube(st, Vector3.ZERO, 1.0, Color.WHITE)
		_cube_unitaire = st.commit()
	return _cube_unitaire

func _poser_les_cubes() -> void:
	if _n == 0:
		return
	var reserve := int(ceil(float(_n) * RESERVE)) + 16
	# Les instances de réserve : cachées sous la ville, en attendant qu'un
	# intérieur à dévoiler les réclame.
	for i in reserve:
		_libres.append(_n)
		_instance(Vector3(0, -80, 0), Vector3(0.001, 0.001, 0.001), Color.BLACK)
	_multi = MultiMesh.new()
	_multi.transform_format = MultiMesh.TRANSFORM_3D
	_multi.use_colors = true
	_multi.mesh = cube_unitaire()
	_multi.instance_count = _n
	_multi.buffer = _tampon
	var noeud := MultiMeshInstance3D.new()
	noeud.multimesh = _multi
	noeud.material_override = MatieresCarnage.voxel()
	noeud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(noeud)

# ------------------------------------------------------------ étape 3 : les voitures

func _poser_les_voitures() -> void:
	for modele in _places:
		var liste_v: Array = _places[modele]
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
		noeud_v.material_override = MatieresCarnage.voxel()
		noeud_v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(noeud_v)

# ------------------------------------------------------------ étape 4 : les lumières et les lieux

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

# ------------------------------------------------------------ la vie du morceau

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

## Ce morceau porte-t-il cet immeuble ?
func porte(id: int) -> bool:
	return _immeubles.has(id)

## Un voxel cassé : il disparaît, et les cubes pleins qu'il cachait apparaissent
## (en gris d'intérieur, ou dans leur couleur si c'était une autre façade).
## Renvoie le centre et la couleur du cube parti, pour les débris — ou vide.
func casser(id: int, locale: int) -> Dictionary:
	if not _immeubles.has(id) or _multi == null:
		return {}
	var entree: Dictionary = _immeubles[id]
	var v: Dictionary = entree["v"]
	var inst: Dictionary = entree["inst"]
	var solide: PackedByteArray = v["solide"]
	var nx := int(v["nx"])
	var nz := int(v["nz"])
	var ny := int(v["ny"])
	var i := locale / 512
	var j := (locale / 32) % 16
	var k := locale % 32
	if i >= nx or j >= nz or k >= ny:
		return {}
	var idx := (i * nz + j) * ny + k
	if solide[idx] == 0:
		return {}
	solide[idx] = 0
	var couleurs: PackedColorArray = v["couleurs"]
	var couleur: Color = couleurs[idx]
	var centre := _centre_voxel(v, i, j, k)
	if inst.has(locale):
		var indice := int(inst[locale])
		_multi.set_instance_transform(indice, Transform3D(Basis.from_scale(Vector3(0.001, 0.001, 0.001)), Vector3(0, -80, 0)))
		inst.erase(locale)
		_libres.append(indice)
	# Les voisins pleins qui n'étaient pas dessinés le deviennent.
	for voisin: Vector3i in [Vector3i(-1, 0, 0), Vector3i(1, 0, 0), Vector3i(0, -1, 0), Vector3i(0, 1, 0), Vector3i(0, 0, -1), Vector3i(0, 0, 1)]:
		var vi: int = i + voisin.x
		var vj: int = j + voisin.z
		var vk: int = k + voisin.y
		if vi < 0 or vj < 0 or vk < 0 or vi >= nx or vj >= nz or vk >= ny:
			continue
		var vidx := (vi * nz + vj) * ny + vk
		if solide[vidx] == 0:
			continue
		var vlocale := (vi * 16 + vj) * 32 + vk
		if inst.has(vlocale) or _libres.is_empty():
			continue
		var slot := int(_libres.pop_back())
		inst[vlocale] = slot
		_multi.set_instance_transform(slot, Transform3D(Basis.from_scale(Vector3(float(v["taille"]), float(v["hauteur"]), float(v["taille"]))),
			_centre_voxel(v, vi, vj, vk)))
		_multi.set_instance_color(slot, couleurs[vidx])
	return {"p": centre, "c": couleur, "taille": float(v["taille"])}

## Le voxel PLEIN d'un immeuble le plus proche d'un point 3D (en unités), pour
## savoir ce qu'une balle ou un pare-chocs a touché. Renvoie la clé locale ou -1.
func voxel_proche(id: int, point: Vector3) -> int:
	if not _immeubles.has(id):
		return -1
	var v: Dictionary = _immeubles[id]["v"]
	var solide: PackedByteArray = v["solide"]
	var nx := int(v["nx"])
	var nz := int(v["nz"])
	var ny := int(v["ny"])
	var meilleur := -1
	var distance := INF
	for i in nx:
		for j in nz:
			for k in ny:
				if solide[(i * nz + j) * ny + k] == 0:
					continue
				var d := _centre_voxel(v, i, j, k).distance_squared_to(point)
				if d < distance:
					distance = d
					meilleur = (i * 16 + j) * 32 + k
	return meilleur

## Les voxels pleins d'un immeuble à moins de `rayon` unités d'un point : la
## roquette, l'explosion.
func voxels_autour(id: int, point: Vector3, rayon: float) -> Array:
	if not _immeubles.has(id):
		return []
	var v: Dictionary = _immeubles[id]["v"]
	var solide: PackedByteArray = v["solide"]
	var nx := int(v["nx"])
	var nz := int(v["nz"])
	var ny := int(v["ny"])
	var liste: Array = []
	for i in nx:
		for j in nz:
			for k in ny:
				if solide[(i * nz + j) * ny + k] == 0:
					continue
				if _centre_voxel(v, i, j, k).distance_to(point) <= rayon:
					liste.append((i * 16 + j) * 32 + k)
	return liste

## Ce qui reste du rez-de-chaussée, de 0 à 1. En dessous d'un seuil, l'immeuble
## est éventré : on le traverse.
func rez_de_chaussee_restant(id: int) -> float:
	if not _immeubles.has(id):
		return 1.0
	var v: Dictionary = _immeubles[id]["v"]
	var solide: PackedByteArray = v["solide"]
	var nx := int(v["nx"])
	var nz := int(v["nz"])
	var ny := int(v["ny"])
	var pleins := 0
	for i in nx:
		for j in nz:
			if solide[(i * nz + j) * ny] == 1:
				pleins += 1
	return float(pleins) / float(max(1, nx * nz))

# ------------------------------------------------------------ géométrie

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
