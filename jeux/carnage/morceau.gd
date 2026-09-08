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

## Les lampadaires éclairent le sol : la flaque, sa portée, sa couleur.
const LAMPES := {
	"lampadaire": {"d": 1.15, "r": 5.4, "c": Color(1.0, 0.72, 0.42), "a": 0.5},
	"lampadaire_parc": {"d": 0.8, "r": 4.2, "c": Color(0.95, 0.8, 0.55), "a": 0.42},
}

var cle := Vector2i.ZERO
var voitures: Dictionary = {}     ## id de voiture dormante -> [MultiMesh, indice]
var cabines: Array = []               ## nœuds de cabine posés dans ce morceau, {n, id}
var planques: Array = []              ## [{n: Node3D, id, prix}] — l'écriteau change quand on l'achète

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
var _immeubles: Dictionary = {}       ## id d'immeuble -> {"v": voxels}
var _groupes: Dictionary = {}         ## pâté -> {ids, noeud: MeshInstance3D, sale, tampons: id -> tableaux}
var _a_mailler: Array = []            ## les groupes qui attendent leur premier maillage
## Le budget de maillage par image, en microsecondes : au-delà, on reprend à
## l'image suivante. Un pâté entier faisait cinquante millisecondes dans le
## navigateur — une saccade à chaque morceau qui entre dans le champ.
const BUDGET_MAILLAGE_USEC := 6000
var _cellules := 0                    ## cellules pleines d'immeubles, pour le journal
var _props_kenney: Dictionary = {}    ## nom de prop -> [Transform3D] (une nappe par modèle)
var _bats_kenney: Dictionary = {}     ## chemin de modèle -> [{t, id}] : les immeubles intacts
## style -> dernier modèle posé : de quoi ne jamais mettre deux fois de suite
## le même immeuble. Les tuiles se parcourent dans le même ordre chez tous les
## joueurs, donc la ville reste la même des quatre côtés de la table.
var _dernier_bat: Dictionary = {}
var _bat_instance: Dictionary = {}    ## id d'immeuble -> [MultiMesh, rang] pour le faire disparaître
var _multi: MultiMesh
var _places: Dictionary = {}          ## modele -> Array[{t, c, id}]
var _lumineux: SurfaceTool
var _flaques: SurfaceTool
var _ombres: SurfaceTool
var _quelque_ombre := false
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
	_dernier_bat.clear()
	_etape = 0
	_lumineux = SurfaceTool.new()
	_lumineux.begin(Mesh.PRIMITIVE_TRIANGLES)
	_flaques = SurfaceTool.new()
	_flaques.begin(Mesh.PRIMITIVE_TRIANGLES)
	_ombres = SurfaceTool.new()
	_ombres.begin(Mesh.PRIMITIVE_TRIANGLES)

## Tout d'un coup, pour le départ.
func batir(plan: PlanVille, cle_du_morceau: Vector2i, reveillees: Dictionary, detruits: Dictionary = {}) -> void:
	commencer(plan, cle_du_morceau, reveillees, detruits)
	while not avancer():
		pass

## Un morceau libéré rend ses rectangles au compte du banc.
func _exit_tree() -> void:
	for groupe in _groupes:
		quads_total -= int(_groupes[groupe].get("quads", 0))
	_groupes.clear()

func fini() -> bool:
	return _etape >= 5 and _a_mailler.is_empty()

## Une étape de chantier. Renvoie vrai quand le morceau est complet. Les
## maillages d'immeubles viennent après tout le reste, UN PÂTÉ PAR IMAGE : un
## morceau en a seize, c'est un quart de seconde à soixante images — et les
## immeubles apparaissent pâté par pâté, au loin, au lieu d'un à-coup.
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
		_:
			# Les maillages : immeuble par immeuble, dans le budget de l'image ;
			# un pâté est posé quand tous ses immeubles sont prêts.
			_mailler_dans_le_budget(_a_mailler, BUDGET_MAILLAGE_USEC)
	_etape += 1
	return fini()

## Avance le maillage des groupes de `file` (premier d'abord) tant qu'il reste
## du budget ; retire de la file ceux qui sont posés. Renvoie vrai s'il a
## travaillé.
func _mailler_dans_le_budget(file: Array, budget_usec: int) -> bool:
	var depart := Time.get_ticks_usec()
	var travaille := false
	while not file.is_empty():
		var groupe: Vector2i = file[0]
		var entree: Dictionary = _groupes[groupe]
		var tampons: Dictionary = entree["tampons"]
		var reste := false
		for id in entree["ids"]:
			if tampons.has(id):
				continue
			if _immeubles[id].has("kenney"):
				tampons[id] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray(),
					PackedVector2Array(), PackedInt32Array()]
				continue
			var t0 := Time.get_ticks_usec()
			tampons[id] = _mailler_immeuble(id)
			travaille = true
			maillage_max_ms = maxf(maillage_max_ms, float(Time.get_ticks_usec() - t0) / 1000.0)
			if Time.get_ticks_usec() - depart > budget_usec:
				reste = true
				break
		if reste:
			return true
		_poser_groupe(groupe)
		file.pop_front()
		travaille = true
		if Time.get_ticks_usec() - depart > budget_usec:
			break
	return travaille

## Les tableaux (sommets, normales, couleurs, UV, indices) d'UN immeuble.
func _mailler_immeuble(id: int) -> Array:
	var v: Dictionary = _immeubles[id]["v"]
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	var couleurs := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	VoxelsCarnage.mailler(v, sommets, normales, couleurs, uvs, indices)
	return [sommets, normales, couleurs, uvs, indices]

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
				# L'ombre de contact au pied des volumes posés au sol.
				if float(b["y"]) < 0.1 and float(b["h"]) >= 2.0:
					var demi := Vector2(float(b["w"]), float(b["d"])) * 0.5 * Decor.ECHELLE
					var centre_o := Decor.vers3d(b["p"], 0.03)
					var dx := Vector3(demi.x + 3.0, 0, 0)
					var dz := Vector3(0, 0, demi.y + 3.0)
					_quad(_ombres, [centre_o - dx - dz, centre_o + dx - dz, centre_o + dx + dz, centre_o - dx + dz],
						Color(demi.x / 100.0, demi.y / 100.0, 0.0, 1.0))
					_quelque_ombre = true
				if b.get("chapeau", false) or (int(b["style"]) == PlanVille.F_TOUR and float(b["h"]) >= 24.0):
					# La balise rouge d'une tour : ce qui dit la hauteur de nuit.
					_cube(Decor.vers3d(b["p"], float(b["y"]) + float(b["h"]) + 0.6), 0.7,
						Color(Palette.CRITIQUE.lightened(0.2), VoxelsCarnage.LUMIERE))
			var rang_p := 0
			for pr in fiche["props"]:
				var nom := String(pr["m"])
				var graine := hash(Vector3i(c, l, rang_p))
				rang_p += 1
				if FormesCarnage.prop_kenney(nom).is_empty():
					for cube in VoxelsCarnage.mobilier(nom, pr["p"], float(pr["a"]), float(pr.get("s", 1.0)), graine):
						_cube(cube[0], float(cube[1]), cube[2])
				else:
					# Un prop du kit : il rejoint la nappe de son modèle. Une
					# nappe par modèle et par morceau, comme les voitures
					# dormantes — sinon ce serait un nœud par lampadaire.
					if not _props_kenney.has(nom):
						_props_kenney[nom] = []
					var echelle: float = float(pr.get("s", 1.0))
					var base_p := Basis(Vector3.UP, -float(pr["a"])).scaled(Vector3.ONE * echelle)
					_props_kenney[nom].append(Transform3D(base_p, Decor.vers3d(pr["p"])))
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

## Un immeuble : sa grille de voxels d'une unité, les cellules cassées de la
## manche retirées, rangé dans le GROUPE de son pâté — c'est par pâté qu'on
## fusionne les maillages (une dizaine d'immeubles, un seul appel de dessin) et
## qu'on les refait quand un cube part.
func _poser_immeuble(b: Dictionary, id: int) -> void:
	var v := VoxelsCarnage.immeuble(b, id)
	var nx := int(v["nx"])
	var nz := int(v["nz"])
	var ny := int(v["ny"])
	# Ce que la manche a déjà cassé dans cet immeuble.
	var casses: Array = _detruits.get(id, [])
	for locale in casses:
		var c := VoxelsCarnage.decoder_locale(int(locale))
		if c.x < nx and c.y < nz and c.z < ny:
			VoxelsCarnage._creuser(v, c.x, c.y, c.z)
	_immeubles[id] = {"v": v}
	var tuile := tuile_d_immeuble(id)
	var groupe := Vector2i(tuile.x / PlanVille.PERIODE, tuile.y / PlanVille.PERIODE)
	if not _groupes.has(groupe):
		_groupes[groupe] = {"ids": [], "noeud": null, "sale": true, "tampons": {}}
		_a_mailler.append(groupe)
	(_groupes[groupe]["ids"] as Array).append(id)
	_cellules += int(v["nx"]) * int(v["nz"]) * int(v["ny"]) - (v["trous"] as PackedInt32Array).size()

	# LE MODÈLE : tant que l'immeuble est INTACT, c'est un bâtiment des City
	# Kits qu'on voit — dessiné, avec ses fenêtres, ses auvents et son toit. La
	# grille de voxels existe quand même, invisible : elle attend le premier
	# cube arraché pour prendre le relais (voir `casser`). Un immeuble déjà
	# cassé quand le morceau se bâtit reste en voxels.
	var chemin := ""
	if not bool(v["plat"]):
		chemin = FormesCarnage.batiment_kenney(int(b["style"]),
			maxf(float(b["w"]), float(b["d"])) * Decor.ECHELLE, float(b["h"]), id,
			String(_dernier_bat.get(int(b["style"]), "")))
		_dernier_bat[int(b["style"])] = chemin
	if chemin != "" and casses.is_empty():
		if not _bats_kenney.has(chemin):
			_bats_kenney[chemin] = []
		var emprise := Vector3(float(b["w"]) * Decor.ECHELLE, float(b["h"]), float(b["d"]) * Decor.ECHELLE)
		# On tourne le modèle pour que deux voisins ne se ressemblent pas de
		# face. ⚠ Un quart de tour n'est permis que sur une emprise CARRÉE :
		# l'échelle est portée par la base, donc tourner une emprise de trois
		# tuiles sur une la faisait déborder en travers de la rue — d'où des
		# immeubles qui se chevauchaient et mordaient sur la chaussée.
		var quarts: int = posmod(FormesCarnage._melanger(id + 5), 4) \
			if absf(emprise.x - emprise.z) < 0.05 * emprise.x \
			else posmod(FormesCarnage._melanger(id + 5), 2) * 2
		var tourne := Basis(Vector3.UP, PI * 0.5 * float(quarts)).scaled(emprise)
		# La teinte du quartier passe en couleur d'instance : les modèles du kit
		# sont gris-bleu, la ville doit garder ses couleurs de quartier — c'est
		# ce qui fait qu'on sait où l'on est en regardant une rue.
		# ⚠ La teinte du quartier seule ne suffit pas : les modèles d'un même
		# kit partagent leur atlas, donc une rue de pavillons sortait toute
		# verte, la même façade répétée. On fait donc varier chaque immeuble
		# autour de la teinte du quartier — un peu plus clair ou plus sombre,
		# un rien plus chaud ou plus froid — d'après son identifiant. Assez
		# pour qu'on distingue deux voisins, pas assez pour perdre la couleur
		# qui dit dans quel quartier on est.
		var teinte_b: Color = (b["c"] as Color).lerp(Color.WHITE, 0.42)
		# ⚠ Brassé, comme le choix du modèle : l'identifiant progresse par pas
		# réguliers d'un immeuble à l'autre, et un simple reste redonnait la
		# même teinte tout le long de la rue.
		var brasse := FormesCarnage._melanger(id)
		var ecart := float(posmod(brasse, 9)) / 8.0 - 0.5
		teinte_b = teinte_b.lightened(ecart * 0.34) if ecart > 0.0 else teinte_b.darkened(-ecart * 0.4)
		teinte_b.h = fposmod(teinte_b.h + float(posmod(brasse / 9, 7) - 3) * 0.016, 1.0)
		_bats_kenney[chemin].append({"t": Transform3D(tourne, Decor.vers3d(b["p"], float(b["y"]))),
			"id": id, "c": teinte_b})
		_immeubles[id]["kenney"] = chemin
		return          # ni ornements ni maillage voxel : le modèle fait tout

	# Les ornements — corniches, balcons, stores, toits — hors de la grille :
	# ils ne se cassent pas, mais ils font la différence entre une boîte et
	# un immeuble. Eux restent des instances.
	for orn in VoxelsCarnage.ornements(v, id):
		_instance(orn[0], orn[1], Color((orn[2] as Color).r, (orn[2] as Color).g, (orn[2] as Color).b, VoxelsCarnage.MUR))

## Le nombre de cubes du morceau : les cellules pleines de ses immeubles plus
## les instances de mobilier — pour le journal du banc.
func cubes_poses() -> int:
	return _n + _cellules

## Le maillage le plus long de la session, en millisecondes (UN immeuble) : le
## banc l'affiche, c'est la saccade maximale qu'une casse ou un chantier peut
## causer par image.
static var maillage_max_ms := 0.0
static var quads_total := 0

## Pose le maillage fusionné d'un groupe (un pâté) à partir des tableaux de ses
## immeubles, cousus bout à bout (les indices décalés). Coudre est du C++ :
## quelques millisecondes pour un pâté, là où mailler en prenait cinquante.
func _poser_groupe(groupe: Vector2i) -> void:
	var entree: Dictionary = _groupes[groupe]
	var tampons: Dictionary = entree["tampons"]
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	var couleurs := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for id in entree["ids"]:
		var t: Array = tampons[id]
		var decalage := sommets.size()
		sommets.append_array(t[0])
		normales.append_array(t[1])
		couleurs.append_array(t[2])
		uvs.append_array(t[3])
		var ind: PackedInt32Array = t[4]
		if decalage == 0:
			indices.append_array(ind)
		else:
			var n0 := indices.size()
			indices.resize(n0 + ind.size())
			for q in ind.size():
				indices[n0 + q] = ind[q] + decalage
	entree["sale"] = false
	var maillage := VoxelsCarnage.maillage_depuis(sommets, normales, couleurs, uvs, indices)
	var noeud: MeshInstance3D = entree["noeud"]
	if noeud == null:
		noeud = MeshInstance3D.new()
		noeud.material_override = MatieresCarnage.voxel_fusionne()
		noeud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(noeud)
		entree["noeud"] = noeud
	noeud.mesh = maillage
	quads_total += sommets.size() / 4 - int(entree.get("quads", 0))
	entree["quads"] = sommets.size() / 4

## Refait les immeubles salis par une casse, dans le budget de l'image — le
## reste du pâté est recousu depuis ses tableaux gardés. Renvoie vrai s'il a
## travaillé.
var _a_rafraichir: Array = []

func rafraichir() -> bool:
	if _a_rafraichir.is_empty():
		for groupe in _groupes:
			if bool(_groupes[groupe]["sale"]) and _groupes[groupe]["noeud"] != null:
				_a_rafraichir.append(groupe)
	if _a_rafraichir.is_empty():
		return false
	return _mailler_dans_le_budget(_a_rafraichir, BUDGET_MAILLAGE_USEC)

func _centre_voxel(v: Dictionary, i: int, j: int, k: int) -> Vector3:
	var t := float(v["taille"])
	var h := float(v["hauteur"])
	return (v["origine"] as Vector3) + Vector3((i + 0.5) * t, (k + 0.5) * h, (j + 0.5) * t)

func _cube(centre: Vector3, cote: float, couleur: Color) -> void:
	_instance(centre, Vector3(cote, cote, cote), couleur)

## Seize nombres dans le tampon : la transformation (trois lignes de quatre) et
## la couleur.
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
		# Un modèle Kenney porte son atlas ; un modèle voxel, ses couleurs de
		# sommet. Poser la mauvaise matière donne une nappe blanche ou noire.
		noeud_v.material_override = FormesCarnage.matiere_kenney(FormesCarnage.modele_kenney_de(int(modele))) \
			if FormesCarnage.est_kenney(int(modele)) else MatieresCarnage.voxel()
		noeud_v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(noeud_v)

	_poser_les_props_kenney()
	_poser_les_batiments_kenney()

## Une nappe par modèle de prop : lampadaires, arbres, bancs, bennes. La
## matière vient du kit (son atlas), les ombres restent allumées — un arbre
## sans ombre flotte au-dessus du trottoir.
func _poser_les_batiments_kenney() -> void:
	for chemin in _bats_kenney:
		var poses: Array = _bats_kenney[chemin]
		if poses.is_empty():
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = FormesCarnage.maillage_batiment(String(chemin))
		multi.instance_count = poses.size()
		for i in poses.size():
			multi.set_instance_transform(i, poses[i]["t"])
			multi.set_instance_color(i, poses[i]["c"])
			_bat_instance[int(poses[i]["id"])] = [multi, i, poses[i]["t"]]
		var noeud := MultiMeshInstance3D.new()
		noeud.multimesh = multi
		noeud.material_override = FormesCarnage.matiere_kenney(String(chemin))
		noeud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(noeud)
	_bats_kenney.clear()

func _poser_les_props_kenney() -> void:
	for nom in _props_kenney:
		var poses: Array = _props_kenney[nom]
		if poses.is_empty():
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = FormesCarnage.maillage_prop(String(nom))
		multi.instance_count = poses.size()
		for i in poses.size():
			multi.set_instance_transform(i, poses[i])
		var noeud := MultiMeshInstance3D.new()
		noeud.multimesh = multi
		var fiche_p: Dictionary = FormesCarnage.prop_kenney(String(nom))
		var matiere: Material = FormesCarnage.matiere_kenney(String(fiche_p["m"]))
		if fiche_p.has("c"):
			# Un lampadaire blanc de six mètres se voit de trop loin : la teinte
			# du prop assombrit le modèle sans toucher au kit.
			matiere = matiere.duplicate()
			if matiere is ShaderMaterial:
				(matiere as ShaderMaterial).set_shader_parameter("teinte", fiche_p["c"])
			elif matiere is BaseMaterial3D:
				(matiere as BaseMaterial3D).albedo_color = fiche_p["c"]
		noeud.material_override = matiere
		noeud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(noeud)
	_props_kenney.clear()

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
	if _quelque_ombre:
		var noeud_o := MeshInstance3D.new()
		noeud_o.mesh = _ombres.commit()
		noeud_o.material_override = MatieresCarnage.ombre()
		noeud_o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(noeud_o)

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
		cabines.append({"n": poste, "id": int(c["id"]),
			"gang": _plan.territoire(Vector2(c["p"]))})
	for h in lieux["hopitaux"]:
		var coin_h := PlanVille.coin_pate(h["pate"])
		if not rect.has_point(PlanVille.centre_tuile(coin_h.x, coin_h.y)):
			continue
		var croix := FormesCarnage.dalle_hopital()
		croix.position = Decor.vers3d(h["p"])
		add_child(croix)
	for pl in lieux["planques"]:
		var coin_pl := PlanVille.coin_pate(pl["pate"])
		if not rect.has_point(PlanVille.centre_tuile(coin_pl.x, coin_pl.y)):
			continue
		var porte := FormesCarnage.porte_planque(int(pl["prix"]))
		porte.position = Decor.vers3d(pl["p"])
		add_child(porte)
		planques.append({"n": porte, "id": int(pl["id"]), "prix": int(pl["prix"])})
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

## Un voxel cassé : la cellule se vide, son pâté est marqué à remailler (voir
## `rafraichir`), et les faces des cellules qu'il cachait apparaîtront au
## prochain maillage — en gris d'intérieur, ou dans leur couleur si c'était une
## autre façade. Renvoie le centre et la couleur du cube parti, pour les
## débris — ou vide.
func casser(id: int, locale: int) -> Dictionary:
	if not _immeubles.has(id):
		return {}
	var v: Dictionary = _immeubles[id]["v"]
	var solide: PackedByteArray = v["solide"]
	var nx := int(v["nx"])
	var nz := int(v["nz"])
	var ny := int(v["ny"])
	var c := VoxelsCarnage.decoder_locale(locale)
	if c.x >= nx or c.y >= nz or c.z >= ny:
		return {}
	var idx := (c.x * nz + c.y) * ny + c.z
	if solide[idx] == 0:
		return {}
	# ⚠ LE MUR NE S'OUVRE PLUS. Jusqu'à la v12, le premier cube arraché
	# effaçait le modèle du kit et la grille de voxels prenait le relais : un
	# immeuble dessiné se changeait sous les yeux du joueur en tas de cubes,
	# et une rue mitraillée redevenait la ville d'avant. La façade encaisse
	# donc, et ne rend que de quoi jouer l'impact : la poussière, les éclats et
	# le choc partent, la pierre reste.
	return {"p": _centre_voxel(v, c.x, c.y, c.z),
		"c": VoxelsCarnage.couleur_cellule(v, c.x, c.y, c.z),
		"taille": float(v["taille"])}

## Le voxel PLEIN d'un immeuble le plus proche d'un point 3D (en unités), pour
## savoir ce qu'une balle ou un pare-chocs a touché. Renvoie la clé locale ou -1.
func voxel_proche(id: int, point: Vector3) -> int:
	var meilleur := -1
	var distance := INF
	var v: Dictionary = _immeubles[id]["v"] if _immeubles.has(id) else {}
	for locale in voxels_autour(id, point, 3.0):
		var c := VoxelsCarnage.decoder_locale(int(locale))
		var d := _centre_voxel(v, c.x, c.y, c.z).distance_squared_to(point)
		if d < distance:
			distance = d
			meilleur = int(locale)
	return meilleur

## Les voxels pleins d'un immeuble à moins de `rayon` unités d'un point : la
## roquette, l'explosion. On ne parcourt que la boîte du rayon.
func voxels_autour(id: int, point: Vector3, rayon: float) -> Array:
	if not _immeubles.has(id):
		return []
	var v: Dictionary = _immeubles[id]["v"]
	var solide: PackedByteArray = v["solide"]
	var nx := int(v["nx"])
	var nz := int(v["nz"])
	var ny := int(v["ny"])
	var o: Vector3 = v["origine"]
	var t := float(v["taille"])
	var h := float(v["hauteur"])
	var liste: Array = []
	for i in range(max(0, int(floor((point.x - rayon - o.x) / t))), min(nx - 1, int(floor((point.x + rayon - o.x) / t))) + 1):
		for j in range(max(0, int(floor((point.z - rayon - o.z) / t))), min(nz - 1, int(floor((point.z + rayon - o.z) / t))) + 1):
			for k in range(max(0, int(floor((point.y - rayon - o.y) / h))), min(ny - 1, int(floor((point.y + rayon - o.y) / h))) + 1):
				if solide[(i * nz + j) * ny + k] == 1 and _centre_voxel(v, i, j, k).distance_to(point) <= rayon:
					liste.append(VoxelsCarnage.cle_locale(i, j, k))
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
