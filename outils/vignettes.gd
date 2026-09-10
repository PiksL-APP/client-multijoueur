extends Node3D
## LES VIGNETTES DES PINCEAUX — une photo par caractère du dessin.
##
##     godot --headless --path . outils/vignettes.tscn      (ne marche PAS)
##     xvfb-run godot --path . outils/vignettes.tscn        (il faut un rendu)
##
## ⚠ CE QU'ON PHOTOGRAPHIE, C'EST CE QUE LE PINCEAU PRODUIT — pas une icône
## dessinée à côté. Chaque vignette est une PARCELLE bâtie par
## `Quartiers.batir_fiche`, la même fonction que le jeu et que l'éditeur. Une
## icône dessinée à la main serait une troisième vérité, à re-dessiner chaque
## fois qu'un modèle du kit change ; ici, on relance le banc et les dix-neuf
## vignettes disent de nouveau la vérité.
##
## C'est le geste de `outils/faces.gd` pour les meubles de repaire : sur ce
## projet, ce qu'on affirme d'un modèle se PHOTOGRAPHIE, ça ne se devine pas.

const COTE := 256                       ## pixels du rendu, avant recadrage
const FINI := 40                        ## pixels de la vignette écrite : la
                                        ## taille à laquelle elle est POSÉE dans
                                        ## le bouton. Écrite plus grande et
                                        ## réduite par le moteur, une image de
                                        ## kit bave ; écrite à sa taille, elle
                                        ## reste nette.
const DOSSIER := "res://images/pinceaux/"

## Le fond de la parcelle : de l'eau pour ce qui flotte, de la pelouse sinon.
const SUR_EAU := ".~="

var _reste: Array = []
var _vue: SubViewport
var _porte: Node3D
var _attente := 0
var _sortie := "res://images/pinceaux/"

## La parcelle de 7 × 7 qui met le pinceau en valeur. Une case isolée au milieu
## d'un pré ne dit rien d'une RUE : ce qu'on reconnaît d'une rue, c'est un
## carrefour ; d'un pont, ses deux rives ; d'un mouillage, la file qui choisit
## le bateau.
## ⚠ LA PARCELLE EST À LA TAILLE DU SUJET. Sept cases sur sept pour ce qui a
## besoin de contexte — une rue se reconnaît à son carrefour, un pont à ses
## deux rives — mais trois pour un sol ou un buisson : sur sept cases, le
## chantier et le sable se noyaient dans le pré, et le recadrage automatique ne
## pouvait rien puisque le pré, lui, est opaque jusqu'au bord du cadre.
static func cote_de(c: String) -> int:
	if c in "#=O~.":
		return 7
	if c.to_upper() in "TBCMVH":
		return 4
	return 3

static func parcelle(c: String) -> Array:
	var fond := "." if SUR_EAU.contains(c) else ","
	var n := cote_de(c)
	var g: Array = []
	for j in n:
		g.append(fond.repeat(n))
	var mettre := func(i: int, j: int, ch: String):
		var l: String = g[j]
		g[j] = l.substr(0, i) + ch + l.substr(i + 1)
	match c:
		"#":
			for k in n:
				mettre.call(k, 3, "#")
				mettre.call(3, k, "#")
		"O":
			for k in n:
				mettre.call(k, 3, "#")
				mettre.call(3, k, "#")
			mettre.call(3, 3, "O")
		"=":
			for k in n:
				mettre.call(k, 3, "=" if k > 1 and k < 5 else ",")
			for k in [0, 1, 5, 6]:
				for j in [2, 3, 4]:
					mettre.call(k, j, "," if j != 3 else "#")
		"~":
			for k in range(1, 6):
				mettre.call(k, 3, "~")
		".":
			pass                        # l'eau nue : la parcelle EST la vignette
		_:
			# Le reste occupe le cœur de la parcelle. Trois cases pour ce qui
			# s'étale (sol, verdure), deux pour les familles bâties — au-delà
			# de leur emprise, un bâtiment s'étire et ne se reconnaît plus.
			var m := 2 if c.to_upper() in "TBCMVH" else n
			var d := (n - m) / 2
			for j in range(d, d + m):
				for i in range(d, d + m):
					mettre.call(i, j, c)
	return g

func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--sortie="): _sortie = a.trim_prefix("--sortie=")
	for p in EditeurCarte.PINCEAUX:
		_reste.append(String(p[0]))

	_vue = SubViewport.new()
	_vue.size = Vector2i(COTE, COTE)
	# ⚠ FOND TRANSPARENT : une vignette sur fond bleu ciel dans un panneau noir
	# fait dix-neuf timbres-poste. Le pinceau doit se découper sur le panneau.
	_vue.transparent_bg = true
	_vue.own_world_3d = true
	_vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vue)

	var lumiere := DirectionalLight3D.new()
	lumiere.rotation_degrees = Vector3(-52, -38, 0)
	lumiere.light_energy = 1.55
	_vue.add_child(lumiere)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b9c6d6")
	env.ambient_light_energy = 1.15
	amb.environment = env
	_vue.add_child(amb)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 5.4 * Quartiers.CASE
	cam.far = 4000.0
	_vue.add_child(cam)
	_camera = cam
	set_process(true)

var _camera: Camera3D

## Le cadrage se refait à chaque pinceau : la parcelle n'a pas toujours la même
## taille, et une caméra calée sur sept cases laisse une parcelle de trois au
## fond du cadre.
func _cadrer(n: int) -> void:
	var c := float(n) * 0.5 * Quartiers.CASE
	var centre := Vector3(c, 0.6 * Quartiers.PALIER, c)
	_camera.size = (float(n) - 1.2) * Quartiers.CASE
	_camera.look_at_from_position(centre + Vector3(1.0, 1.15, 1.0).normalized() * 900.0,
		centre, Vector3.UP)

func _process(_d: float) -> void:
	if _attente > 0:
		_attente -= 1
		if _attente == 0: _ecrire()
		return
	if _reste.is_empty():
		print("vignettes : terminé")
		get_tree().quit()
		return
	_poser(String(_reste[0]))

var _en_cours := ""

func _poser(c: String) -> void:
	_en_cours = c
	if _porte != null:
		_vue.remove_child(_porte)
		_porte.queue_free()
	var g := parcelle(c)
	var relief: Array = []
	for _j in g.size():
		relief.append("0".repeat(g.size()))
	var fiche := {
		"nom": "vignette", "origine": Vector2.ZERO, "angle": 0.0, "graine": 4,
		"herbe": Color("#7f9464"), "roche": Color("#8b8578"),
		"hauteurs": {"T": [52.0, 62.0], "B": [30.0, 36.0], "C": [18.0, 22.0],
			"M": [12.0, 15.0], "V": [14.0, 17.0], "H": [15.0, 18.0]},
		"plan": g, "relief": relief,
	}
	_cadrer(g.size())
	_porte = Quartiers.batir_fiche(fiche, "vignette")
	# ⚠ CE QUI FLOTTE A BESOIN DE SON EAU. Le pinceau « eau » ne pose RIEN —
	# c'est sa définition — et sa vignette sortait donc entièrement vide ; le
	# mouillage montrait un bateau suspendu dans le noir. La mer est le décor
	# de ces trois-là, elle fait partie de ce qu'ils veulent dire.
	if SUR_EAU.contains(c):
		var mer := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(24.0 * Quartiers.CASE, 24.0 * Quartiers.CASE)
		mer.mesh = pm
		var eau := StandardMaterial3D.new()
		eau.albedo_color = Color("#2b5f7a")
		eau.roughness = 0.15
		eau.metallic = 0.25
		mer.material_override = eau
		mer.position = Vector3(float(g.size()) * 0.5 * Quartiers.CASE, -2.4,
			float(g.size()) * 0.5 * Quartiers.CASE)
		_porte.add_child(mer)
	_vue.add_child(_porte)
	# Trois images : une pour bâtir, une pour que le rendu prenne, une de marge.
	_attente = 3

## ⚠ ON RECADRE SUR LE SUJET. Rendues à cadre fixe, les dix-neuf vignettes ont
## des sujets de tailles très différentes — un remorqueur tient tout le cadre,
## un buisson trois pour cent — et réduites à quarante pixels dans un bouton,
## les petits ne se voyaient plus du tout. On coupe donc sur la zone non
## transparente, on complète en carré pour ne pas déformer, et on réduit. La
## vignette montre alors le SUJET, pas la parcelle autour.
func _ecrire() -> void:
	var img := _vue.get_texture().get_image()
	var utile := img.get_used_rect()
	if utile.size.x > 2 and utile.size.y > 2:
		var sous := img.get_region(utile)
		var cote := maxi(utile.size.x, utile.size.y)
		var carre := Image.create(cote, cote, false, Image.FORMAT_RGBA8)
		carre.fill(Color(0, 0, 0, 0))
		carre.blit_rect(sous, Rect2i(Vector2i.ZERO, utile.size),
			Vector2i((cote - utile.size.x) / 2, (cote - utile.size.y) / 2))
		img = carre
	img.resize(FINI, FINI, Image.INTERPOLATE_LANCZOS)
	var nom := _nom(_en_cours)
	DirAccess.make_dir_recursive_absolute(_sortie)
	img.save_png(_sortie.path_join(nom + ".png"))
	print("  ", _en_cours, " -> ", nom, ".png")
	_reste.pop_front()

## ⚠ LE NOM DE FICHIER NE PEUT PAS ÊTRE LE CARACTÈRE. « # », « . », « ' » et
## « % » ne sont pas des noms de fichier portables, et « T » et « t » se
## confondent sur un système insensible à la casse — or le web l'est, lui, et
## le paquet d'export ne l'est pas. On nomme donc par le code du caractère.
static func _nom(c: String) -> String:
	return "p%d" % c.unicode_at(0)
