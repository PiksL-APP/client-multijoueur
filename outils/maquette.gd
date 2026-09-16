extends Node3D
## ⭐⭐⭐ LA MAQUETTE DU PAYS ENTIER — « j'aimerais voir la full map ».
##
##     ./outils/maquette.sh /tmp/aurones-3d.png
##     ./outils/maquette.sh /tmp/aurones-3d.png --pente=0.85 --oblique=20
##
## ⚠ POURQUOI CE N'EST PAS UNE FENÊTRE PLUS GRANDE. Une fenêtre de l'éditeur
## bâtit du DÉCOR : chaque maison est un maillage du kit, chaque arbre aussi. À
## mille lots pour cent cases de côté, la carte entière en ferait quatre-vingt
## mille — plusieurs minutes de calcul et des gigaoctets, pour une image où une
## maison fait deux pixels. C'est exactement ce que l'architecture du pays a été
## faite pour ne jamais avoir à faire.
##
## Une maquette ne montre pas les maisons : elle montre le PAYS. Le relief, le
## trait de côte, les rivières, et les six réseaux posés dessus. Tout se lit
## directement dans le plan et dans le terrain, sans bâtir une seule fenêtre —
## d'où quelques secondes au lieu de plusieurs minutes.
##
## ⚠ ET LE TERRAIN SE SOUS-ÉCHANTILLONNE. Un sommet par case, c'est un million de
## sommets et deux millions de triangles : le maillage se construit, mais il ne
## se regarde pas. Un sommet toutes les `PAS` cases suffit — à cette distance,
## une case fait moins d'un pixel.

const PLAN := preload("res://commun/ville2/plan_pays.gd")

const PAS := 2                       ## un sommet toutes les deux cases
const HAUT_ROUTE := 1.2              ## de combien un ruban flotte au-dessus du sol
## ⚠ LA MER SE COLORE ICI, PUISQU'IL N'Y A PAS DE NAPPE. Trois bandes plutôt
## qu'un dégradé continu : l'écume du rivage, les hauts-fonds, le large. C'est la
## palette de la carte plate (`outils/pays.gd`), pour que le client puisse poser
## les deux images côte à côte.
const C_ECUME := Color("#cfe8f4")
const C_HAUTS_FONDS := Color("#7fc0de")
const TEINTE_FOND := Color("#24628f")
const FOND_PROFOND := 10.0

## Chaque réseau a sa couleur et sa largeur, en cases. Les mêmes teintes que la
## carte plate (`outils/pays.gd`) : le client valide les deux images côte à côte,
## elles doivent parler la même langue.
const RUBANS := {
	"primaire": [Color("#d9822b"), 3.4],
	"secondaire": [Color("#e3c05a"), 2.2],
	"locale": [Color("#9a968c"), 1.5],
	"cotier": [Color("#b9a97e"), 1.5],
}
## Les six réseaux de transport, chacun à sa couleur et à sa largeur. Le ferry
## n'est pas un ruban posé sur le sol — il traverse la mer, on le trace au ras
## de la nappe. Un métro souterrain ne se dessine pas du tout.
const LIGNES := {
	"train": [Color("#cf3227"), 2.0],
	"train2": [Color("#e2761b"), 1.8],
	"metro": [Color("#2166b0"), 1.4],
	"tram": [Color("#2f8b57"), 1.2],
	"bus": [Color("#f2c230"), 0.9],
}

var _sortie := "/tmp/aurones-3d.png"
var _images := 0
const ATTENDRE := 3

func _arg(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_args():
		if a.begins_with("--" + nom + "="): return a.trim_prefix("--" + nom + "=")
	return defaut

func _ready() -> void:
	_sortie = _arg("sortie", _sortie)
	var t0 := Time.get_ticks_msec()
	var plan := PLAN.charger()
	if plan.is_empty():
		push_error("plan absent : " + PLAN.PLAN_CUIT)
		get_tree().quit()
		return
	var ctx := PLAN.contexte(plan)
	var v := Ville2.new(PLAN.TAILLE)
	PLAN.remplir_terrain(plan, ctx, v, Vector2i.ZERO)
	print("terrain %d x %d en %d ms" % [PLAN.TAILLE.x, PLAN.TAILLE.y,
		Time.get_ticks_msec() - t0])

	# ⚠ L'AMBIANCE NE S'ALLUME PAS TOUTE SEULE. `ambiance()` rend les nœuds ;
	# c'est `regler_heure` qui met le soleil quelque part. Sans elle la maquette
	# se rendait de nuit, et vingt kilomètres de mer noire ressemblent à un bug.
	MatieresCarnage.nuit_forcee = 0.0
	var amb: Array = MatieresCarnage.ambiance()
	for n in amb: add_child(n)
	MatieresCarnage.regler_heure(amb[0], amb[1], amb[2], 0.0)
	MatieresCarnage.regler_nuit(0.0)
	var env: Environment = (amb[0] as WorldEnvironment).environment
	env.fog_enabled = false
	# Le soleil doit porter son ombre sur vingt kilomètres, pas sur cent mètres.
	var soleil := amb[1] as DirectionalLight3D
	soleil.directional_shadow_max_distance = 30000.0
	soleil.light_energy = 1.6

	add_child(_le_relief(v))
	# ⚠⚠ PAS DE NAPPE D'EAU ICI, ET C'EST LE MÊME PIÈGE QUE DANS L'ÉDITEUR. La
	# matière de l'eau du jeu se dessine PAR-DESSUS ce qu'il y a derrière : sur
	# une carte de témoin elle donne un joli fond bleu, sur vingt kilomètres elle
	# repeint tout le pays en turquoise — ma première maquette était un
	# rectangle bleu uni, alors que le relief était bien là (mesuré : 55 232
	# sommets au-dessus du niveau de la mer). Le relief porte déjà sa propre
	# couleur sous l'eau, du sable côtier au fond sombre : il se suffit.
	var rubans := _les_reseaux(plan, v)
	add_child(rubans)
	print("maquette bâtie en %d ms" % (Time.get_ticks_msec() - t0))

	var cote := float(PLAN.TAILLE.x) * Ville2.CASE
	var vise := Vector3(cote * 0.5, 0, cote * 0.5)
	# ⚠ LE RECUL EST UN MULTIPLE DU CÔTÉ DU PAYS, ET 0,82 NE SUFFIT PAS. À
	# quarante degrés de champ, ce recul-là ne cadre que douze kilomètres sur
	# vingt : la première image ne montrait que la mer.
	var recul := float(_arg("recul", "1.08")) * cote
	var az := deg_to_rad(float(_arg("oblique", "28")))
	var pente := float(_arg("pente", "0.72"))
	var cam := Camera3D.new()
	cam.far = 200000.0
	cam.fov = 40.0
	add_child(cam)
	cam.look_at_from_position(
		vise + Vector3(sin(az) * recul, recul * pente, cos(az) * recul),
		vise, Vector3.UP)
	cam.make_current()
	get_tree().process_frame.connect(_declic)

## LE RELIEF — ⚠⚠ EN MORCEAUX, ET CE N'EST PAS UNE OPTIMISATION.
##
## Mon premier jet en faisait UN SEUL maillage : 251 001 sommets, un million et
## demi de sommets émis, une boîte englobante juste (mesurée : 20 000 × 20 000,
## sol de −11 à +70, 55 232 sommets au-dessus de la mer)… et RIEN À L'ÉCRAN. Le
## maillage existait, il était au bon endroit, il ne se dessinait pas. J'ai
## d'abord accusé la nappe d'eau — à tort, même si elle avait bien son propre
## défaut — puis la caméra. C'était la taille : passé une certaine masse, une
## surface unique ne s'affiche plus dans le rendu de compatibilité, sans une
## erreur ni un avertissement.
##
## Le relief se découpe donc en carrés de `MORCEAU` cases, comme le reste du
## moteur découpe déjà ses villes. ⚠ Chaque morceau DÉBORDE d'une rangée sur son
## voisin, sinon il reste une fente d'une case entre deux carrés — vingt
## kilomètres de terrain fendu en damier.
const MORCEAU := 100

func _le_relief(v: Ville2) -> Node3D:
	var racine := Node3D.new()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	# ⚠⚠ LES DEUX FACES, ET C'EST LA VRAIE CAUSE DE LA MAQUETTE VIDE.
	# Le moteur n'affiche qu'un côté d'un triangle, celui que son sens
	# d'enroulement désigne. Le mien tournait à l'envers : tout le relief
	# regardait VERS LE BAS. Le maillage était complet, à sa place, de la bonne
	# taille — et strictement invisible d'au-dessus, sans une erreur ni un
	# avertissement. J'ai accusé la nappe d'eau, puis la taille du maillage, puis
	# la caméra, avant de trouver. Afficher les deux faces ne coûte rien ici et
	# ne peut plus jamais rendre le pays invisible.
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sommets := 0
	var t := 0
	while t < PLAN.TAILLE.y:
		var u := 0
		while u < PLAN.TAILLE.x:
			var mi := _un_morceau(v, Vector2i(u, t), m)
			if mi != null:
				racine.add_child(mi)
				sommets += 1
			u += MORCEAU
		t += MORCEAU
	print("relief : %d morceaux de %d cases" % [sommets, MORCEAU])
	return racine

func _un_morceau(v: Ville2, coin: Vector2i, m: StandardMaterial3D) -> MeshInstance3D:
	var n := MORCEAU / PAS + 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hauts := PackedFloat32Array()
	var teintes: Array = []
	hauts.resize(n * n)
	teintes.resize(n * n)
	for j in n:
		for i in n:
			var c := Vector2i(mini(coin.x + i * PAS, PLAN.TAILLE.x - 1),
				mini(coin.y + j * PAS, PLAN.TAILLE.y - 1))
			var y := v.sol(c)
			var teinte: Color = TerrainV2.COULEURS.get(v.matiere_de(c),
				TerrainV2.COULEURS[Ville2.M_HERBE])
			if not v.terre(c):
				var prof := clampf((TerrainV2.NIVEAU_MER - y) / FOND_PROFOND, 0.0, 1.0)
				teinte = C_ECUME.lerp(C_HAUTS_FONDS, minf(prof * 3.0, 1.0)) \
					.lerp(TEINTE_FOND, prof)
			hauts[j * n + i] = y
			teintes[j * n + i] = teinte
	var pas := float(PAS) * Ville2.CASE
	var ox := float(coin.x) * Ville2.CASE
	var oz := float(coin.y) * Ville2.CASE
	for j in n - 1:
		for i in n - 1:
			var k00 := j * n + i
			var k10 := j * n + i + 1
			var k01 := (j + 1) * n + i
			var k11 := (j + 1) * n + i + 1
			var p00 := Vector3(ox + float(i) * pas, hauts[k00], oz + float(j) * pas)
			var p10 := Vector3(ox + float(i + 1) * pas, hauts[k10], oz + float(j) * pas)
			var p01 := Vector3(ox + float(i) * pas, hauts[k01], oz + float(j + 1) * pas)
			var p11 := Vector3(ox + float(i + 1) * pas, hauts[k11], oz + float(j + 1) * pas)
			_triangle(st, p00, teintes[k00], p01, teintes[k01], p11, teintes[k11])
			_triangle(st, p00, teintes[k00], p11, teintes[k11], p10, teintes[k10])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	return mi

func _triangle(st: SurfaceTool, a: Vector3, ca: Color, b: Vector3, cb: Color,
		c: Vector3, cc: Color) -> void:
	st.set_color(ca); st.add_vertex(a)
	st.set_color(cb); st.add_vertex(b)
	st.set_color(cc); st.add_vertex(c)

func _la_mer() -> MeshInstance3D:
	var cote := float(PLAN.TAILLE.x) * Ville2.CASE
	var pm := PlaneMesh.new()
	pm.size = Vector2(cote * 2.2, cote * 2.2)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = MatieresCarnage.eau()
	mi.position = Vector3(cote * 0.5, TerrainV2.NIVEAU_MER, cote * 0.5)
	return mi

## LES SIX RÉSEAUX, en rubans posés sur le relief. Un ruban suit le sol case par
## case : à plat il serait enterré dans la première colline.
func _les_reseaux(plan: Dictionary, v: Ville2) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in plan["routes"]:
		var d: Dictionary = r
		var fiche: Array = RUBANS.get(String(d.get("classe", "locale")), RUBANS["locale"])
		_ruban(st, v, d["points"], Color(fiche[0]), float(fiche[1]))
	for l in plan.get("lignes", []):
		var d2: Dictionary = l
		var reseau := String(d2.get("reseau", ""))
		if not LIGNES.has(reseau): continue
		if bool(d2.get("souterrain", false)): continue
		var f2: Array = LIGNES[reseau]
		_ruban(st, v, d2["points"], Color(f2[0]), float(f2[1]))
	st.generate_normals()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	return mi

## ⚠ LE RUBAN SE POSE PAR CASE, PAS PAR SEGMENT. Un quad unique d'un bout à
## l'autre d'une avenue de deux kilomètres traverserait trois collines.
func _ruban(st: SurfaceTool, v: Ville2, points: Array, teinte: Color, large: float) -> void:
	var demi := large * 0.5 * Ville2.CASE
	for k in range(1, points.size()):
		var a := PLAN.case_de(points[k - 1])
		var b := PLAN.case_de(points[k])
		var pas := (b - a).sign()
		if pas == Vector2i.ZERO: continue
		var c := a
		while true:
			var suivant := c + pas
			_segment(st, v, c, suivant, demi, teinte)
			if c == b: break
			c = suivant
			if c == b: break

func _segment(st: SurfaceTool, v: Ville2, a: Vector2i, b: Vector2i, demi: float,
		teinte: Color) -> void:
	var pa := _sur_le_sol(v, a)
	var pb := _sur_le_sol(v, b)
	var av := pb - pa
	if av.length() < 0.001: return
	var cote := av.normalized().cross(Vector3.UP).normalized() * demi
	_triangle(st, pa - cote, teinte, pa + cote, teinte, pb + cote, teinte)
	_triangle(st, pa - cote, teinte, pb + cote, teinte, pb - cote, teinte)

func _sur_le_sol(v: Ville2, c: Vector2i) -> Vector3:
	var d := Vector2i(clampi(c.x, 0, PLAN.TAILLE.x - 1), clampi(c.y, 0, PLAN.TAILLE.y - 1))
	return Vector3((float(c.x) + 0.5) * Ville2.CASE,
		maxf(v.sol(d), TerrainV2.NIVEAU_MER) + HAUT_ROUTE,
		(float(c.y) + 0.5) * Ville2.CASE)

func _declic() -> void:
	_images += 1
	if _images < ATTENDRE: return
	DirAccess.make_dir_recursive_absolute(_sortie.get_base_dir())
	get_viewport().get_texture().get_image().save_png(_sortie)
	print("maquette ", _sortie)
	get_tree().quit()
