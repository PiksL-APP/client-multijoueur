extends Node3D
## LA RÈGLE. Une planche de contrôle : des modèles posés EXACTEMENT comme la
## palette de l'éditeur les pose (sans hauteur voulue), alignés devant une
## voiture et une silhouette de joueur, sur un damier d'un mètre.
##
## ⚠ POURQUOI CET OUTIL EXISTE. Le kit nature a DEUX échelles : ses pièces de
## terrain pavent la case (20 unités), ses accessoires sont dessinés pour le
## petit bonhomme du kit. Posés à l'échelle du kit, une clôture faisait sept
## mètres et un champignon quatre — « toutes les fences et les fleurs
## champignon etc sont énormes comparé au personnage » (client, 12/09). Le
## défaut ne se voyait PAS d'en haut : il faut un repère à hauteur d'homme,
## d'où cette planche.
##
##   ./outils/echelle.sh /tmp/regle.png [--modeles=a,b,c] [--famille=nature]

const CASE := Ville2.CASE
## Le mètre : une unité de jeu (voiture 4,75 de long, joueur 1,75 de haut).
const METRE := 1.0
## La taille du joueur, telle que `jeux/carnage/interieurs.gd` la fixe.
const TAILLE_JOUEUR := 1.75

## La planche par défaut : ce que le client a montré du doigt, plus les repères
## dont on connaît la bonne taille.
const PLANCHE := [
	"nature/fence_simple", "nature/fence_planks", "nature/fence_gate",
	"nature/flower_redA", "nature/mushroom_red", "nature/mushroom_redGroup",
	"nature/grass_large", "nature/plant_bushDetailed", "nature/bench",
	"nature/stump_round", "nature/log", "nature/rock_largeA",
	"nature/stone_smallFlatA", "nature/pot_large", "nature/tent_smallClosed",
	"nature/campfire_stones", "nature/canoe", "nature/statue_head",
	"nature/cactus_tall", "nature/tree_default",
]

var _images := 0
var _attendre := 8
var _sortie := "/tmp/regle.png"

func _arg(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_args():
		if a.begins_with("--" + nom + "="):
			return a.trim_prefix("--" + nom + "=")
	return defaut

func _ready() -> void:
	_sortie = _arg("sortie", _sortie)
	var amb: Array = MatieresCarnage.ambiance()
	for n in amb: add_child(n)
	MatieresCarnage.regler_heure(amb[0], amb[1], amb[2], 0.08)
	MatieresCarnage.regler_nuit(0.08)
	var env: Environment = (amb[0] as WorldEnvironment).environment
	env.fog_density *= 0.02
	(amb[1] as DirectionalLight3D).directional_shadow_max_distance = 400.0

	var liste: Array = PLANCHE
	var demande := _arg("modeles", "")
	if demande != "":
		liste = Array(demande.split(","))
	elif _arg("famille", "") != "":
		liste = []
		var prefixe := _arg("famille", "") + "/"
		for m in KitVille2.catalogue():
			var nom := String(m).trim_prefix("res://modeles/").trim_suffix(".glb")
			if nom.begins_with(prefixe): liste.append(nom)
		liste = liste.slice(0, int(_arg("combien", "24")))

	# ⚠ EN RANGS COURTS. Vingt modèles sur une seule ligne, et la planche fait
	# quarante mètres de large : à ce recul un champignon vaut trois pixels et
	# on ne mesure plus rien. Dix par rang, et le damier reste lisible.
	var par_rang := int(_arg("rang", "7"))
	var rangs := int(ceil(float(liste.size() + 2) / float(par_rang)))
	_damier(par_rang, rangs)
	# Les deux repères, en tête du premier rang : la voiture et le joueur.
	RenduVille2.poser_objet(self, KitVille2.VOITURES[0], _ou(0, par_rang), 0.0)
	var joueur := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.45, TAILLE_JOUEUR, 0.3)
	joueur.mesh = b
	joueur.position = _ou(1, par_rang) + Vector3(0, b.size.y * 0.5, 0)
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color("#e8513f")
	joueur.material_override = mt
	add_child(joueur)

	# Puis la planche, un modèle tous les trois mètres, POSÉ SANS HAUTEUR — la
	# palette de l'éditeur ne fait rien d'autre.
	for k in liste.size():
		var m := String(liste[k])
		RenduVille2.poser_objet(self, m, _ou(k + 2, par_rang), 0.0)
		print("%-34s posé à l'échelle %.2f" % [m, KitVille2.echelle_libre(m)])

	var large := float(par_rang) * PAS
	var fond := float(rangs) * PAS
	var cam := Camera3D.new()
	cam.far = 2000.0
	cam.fov = 34.0
	add_child(cam)
	var vise := Vector3(large * 0.5 - PAS * 0.5, 1.4, fond * 0.5 - PAS * 0.5)
	var recul := maxf(large, fond) * 1.15
	cam.look_at_from_position(vise + Vector3(0, recul * 0.42, recul), vise, Vector3.UP)

## L'écart entre deux modèles de la planche, en mètres.
const PAS := 3.0

## Où se pose le n-ième modèle de la planche.
func _ou(n: int, par_rang: int) -> Vector3:
	return Vector3(float(n % par_rang) * PAS, 0.0, float(n / par_rang) * PAS)

## Un damier d'un mètre : sans lui on ne sait pas ce qu'on regarde. Les cases
## d'un mètre donnent l'échelle d'un coup d'œil — un champignon tient dans un
## quart de case, une clôture dans une.
func _damier(par_rang: int, rangs: int) -> void:
	var large := int(float(par_rang) * PAS) + 4
	var profond := int(float(rangs) * PAS) + 4
	var sommets := PackedVector3Array()
	var couleurs := PackedColorArray()
	var indices := PackedInt32Array()
	for j in profond:
		for i in large:
			var clair := (i + j) % 2 == 0
			var t := Color("#aab59c") if clair else Color("#8d9880")
			var k0 := sommets.size()
			for p in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				sommets.append(Vector3((float(i) - 2.0 + p.x) * METRE, 0.0,
					(float(j) - 2.0 + p.y) * METRE))
				couleurs.append(t)
			indices.append_array([k0, k0 + 1, k0 + 2, k0, k0 + 2, k0 + 3])
	var tab := []
	tab.resize(Mesh.ARRAY_MAX)
	tab[Mesh.ARRAY_VERTEX] = sommets
	tab[Mesh.ARRAY_COLOR] = couleurs
	tab[Mesh.ARRAY_INDEX] = indices
	var maillage := ArrayMesh.new()
	maillage.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tab)
	var n := MeshInstance3D.new()
	n.mesh = maillage
	var mt := StandardMaterial3D.new()
	mt.vertex_color_use_as_albedo = true
	mt.roughness = 1.0
	n.material_override = mt
	add_child(n)

func _process(_d: float) -> void:
	_images += 1
	if _images < _attendre: return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_sortie)
	print("planche ", _sortie)
	get_tree().quit()
