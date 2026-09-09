class_name Quartiers
extends RefCounted
## LA VILLE DESSINÉE À LA MAIN, comme les intérieurs de repaire.
##
## Trois maquettes générées ont été refusées : le procédural sait remplir, il
## ne sait pas avoir du goût. On reprend donc ici EXACTEMENT le geste des
## intérieurs (`jeux/carnage/interieurs.gd`) : le plan est un DESSIN, un
## caractère par case, qu'on relit d'un coup d'œil et où déplacer une rue est
## un caractère dans le diff. Une photo suffit à vérifier
## (`outils/carte.sh <quartier>`).
##
## UNE CASE = VINGT UNITÉS = deux tuiles de jeu = une tuile du City Kit: Roads
## à l'échelle UNIFORME. Rien n'est jamais étiré : c'est ce qui bavait sur les
## marquages et les trottoirs des premières maquettes.
##
## LA VILLE EST FAITE DE QUARTIERS QUI N'ONT PAS LA MÊME TRAME. Chacun a son
## origine et son ANGLE ; entre deux quartiers il y a de l'eau, une falaise ou
## un parc — jamais un raccord de tuiles. C'est la seule chose qui casse
## vraiment le damier : une grille reste une grille, si irrégulière soit-elle.
##
## ─────────────────────────── LE DESSIN ───────────────────────────
##
##   .   l'eau (rien du tout)
##   ,   pelouse, terrain nu
##   ;   sable — le bord de mer
##   o   esplanade pavée, place, parvis
##   P   parking
##   #   rue — les tuiles se raccordent TOUTES SEULES (droite, virage, T,
##       carrefour, impasse) et grimpent en rampe là où le relief monte
##   =   pont
##   O   rond-point : posé sur son CENTRE, il mange 3 x 3 cases
##   ^   bosquet d'arbres        '   buissons et hautes herbes
##   ~   plan d'eau du port : pas de terre, mais un bateau amarré. LA LONGUEUR
##       DE LA FILE DE `~` CHOISIT LE BATEAU — cinq cases d'affilée valent un
##       cargo, deux un remorqueur, une un canot. On dessine un mouillage, pas
##       un bateau à la fois.
##   X   dépôt : conteneurs, cuves, palettes — le sol d'un port
##   %   chantier : barrières, cônes, palissade
##   P   parking : le sol est pavé et il y a des voitures dessus
##
##   T tour   B bureau   C commerce   M maison   V vieille ville   H hangar
##   Un BLOC de lettres identiques est UN SEUL bâtiment qui remplit exactement
##   ce rectangle : c'est ce qui donne des fronts de rue continus au lieu
##   d'immeubles semés sur une pelouse. Pour en mettre deux côte à côte sans
##   qu'ils fusionnent, alterner MAJUSCULE et minuscule : `TTtt` fait deux
##   immeubles, `TTTT` un seul.
##
## ─────────────────────────── LE RELIEF ───────────────────────────
##
## Une deuxième grille, même taille, un CHIFFRE par case : le palier, cinq
## unités par cran (c'est exactement ce dont `road-slant` grimpe en une case —
## d'où le choix du cran). Espace ou absence = palier zéro.

const CASE := CarteVille.CASE
const PALIER := CarteVille.PALIER
const ROUTES := CarteVille.CHEMIN_ROUTES

const CHAUSSEE := "#=O"
const PAVE := "oP"
const FAMILLES := {
	"T": PlanVille.F_TOUR, "B": PlanVille.F_BUREAUX, "C": PlanVille.F_COMMERCE,
	"M": PlanVille.F_MAISON, "V": PlanVille.F_VIEUX, "H": PlanVille.F_HANGAR,
}

const TEINTE_ROUTE := Color("#8e929c")
const TEINTE_PAVE := Color("#b9b6ac")
const TEINTE_SABLE := Color("#d9c9a2")


# ------------------------------------------------------------ LE CATALOGUE

## LES QUARTIERS. Chacun a son origine (en cases, dans le monde), son ANGLE,
## son dessin et son relief. C'est CE BLOC qu'on reprend à la main : déplacer
## une rue, c'est déplacer des `#` ; poser un immeuble, c'est écrire des
## lettres ; creuser un port, c'est écrire des points.
##
## ⚠ Les deux grilles d'un quartier doivent faire la MÊME taille, sinon le
## relief est lu à zéro là où il manque — ce qui se voit comme une falaise
## sans raison.
const CATALOGUE := {
	"centre": {
		"nom": "Le Centre", "origine": Vector2(0, 0), "angle": 0.0, "graine": 12,
		"herbe": Color("#7f9464"), "roche": Color("#8b8578"),
		"hauteurs": {"T": [46.0, 88.0], "B": [24.0, 42.0], "C": [15.0, 24.0], "M": [10.0, 15.0]},
		"plan": [
			"...B#BCCCC#C...........^,,C.....",
			"..,,#BCCCC#CC.....CCcm#^,,CC#.CC",
			".c,,#bcccc#cc^..#cCcc###BBbb#bmm",
			"######################O#########",
			"BBbb#CC,,B#TTBBt#BCC,###CCcC#BBC",
			"BBbb#^^,,B#T#BBt#BbbBm#CcCcC#BB^",
			"ccCC#^^,,B#t#Tbb#tbbBm#mccCc#cc^",
			"BBCC#ccccC#t#Tb###ccCB#mccCc#mCC",
			"################O###############",
			"CCBB#,,Ccc#B#oo###C#,'#BCCMM#BBm",
			"CCBB#,,Ccc#B#ooo#TC#c^#BCCMM#BBm",
			"^',,#^^######ooo#t^#cM#cCcCc#MMb",
			"cc,,#^^,,###TtBB#tB#bM#cCcCc#MMb",
			"#########O##################.###",
			"BBCC#BB#B##..CBB#^BBCM#CcCcC...'",
			"...C#BB#B......b#'BBC'#CcCcc....",
			"...b#cc#........#Bcc,'#b........",
			"...###............####..........",
			"...^............................",
			"................................",
		],
		"relief": [
			"00000000000000000022233344555555",
			"00000000000000000022233344555555",
			"00000000000000000022233344555555",
			"00000000000000000022233344555555",
			"00000000000000000022233344555555",
			"00000000000000000022233344555555",
			"00000000000000000022233344555555",
			"00000000000000000022233344555555",
			"00000000000000000022233344555555",
			"00000000000000000022233344555555",
			"00000000000000000022233344555555",
			"00000000000000000022233344555555",
			"00000000000000000022233344555555",
			"00000000000000000022233344555555",
			"00000000000000000022233344555555",
			"00000000000000000022233344555555",
			"00000000000000000022233344555555",
			"00000000000000000022233344555555",
			"00000000000000000022233344555555",
			"00000000000000000022233344555555",
		],
	},
	"vieille": {
		"nom": "La Vieille Ville", "origine": Vector2(-12.0, 12.0), "angle": -34.0, "graine": 7,
		"herbe": Color("#86935f"), "roche": Color("#9a8f7c"),
		"hauteurs": {"V": [12.0, 22.0], "M": [9.0, 14.0]},
		"plan": [
			".....V..'^......",
			"....#VM,^^M#M...",
			"...##########...",
			"..VM#^,#MM,#VV^.",
			"..Vm#Vv#MM^#VV'.",
			".mmM#Vv#mm'#vv^.",
			".,,,####,,,#,,,.",
			".vvV#Vv#^',#MM..",
			"VvvV#Vv#'^,#MMmm",
			"..#############.",
			"...'#M^,VV^#V...",
			"...^.mM,,,V#....",
			".....mM..,V.....",
		],
		"relief": [
			"0000222444666666",
			"0000222444666666",
			"0000222444666666",
			"0000222444666666",
			"0000222444666666",
			"0000222444666666",
			"0000222444666666",
			"0000222444666666",
			"0000222444666666",
			"0000222444666666",
			"0000222444666666",
			"0000222444666666",
			"0000222444666666",
		],
	},
	"port": {
		"nom": "Le Port", "origine": Vector2(26.0, 22.0), "angle": 21.0, "graine": 99,
		"herbe": Color("#8a9068"), "roche": Color("#8f8272"),
		"hauteurs": {"H": [11.0, 22.0], "C": [13.0, 20.0]},
		"plan": [
			"....XXXHC,'XXXX...",
			"....X#HHC,'^#PP...",
			"...XX#hhc,HH#PP...",
			"..################",
			".XXcc#Hhh#HH#HH^^^",
			"XXXcc#Phh#HH#HH^^.",
			".H,HH#P,H#hh#hh,H.",
			".H,HH#ccC#CC#hh,HH",
			".################.",
			"...%X#HH,,^'#HHH..",
			"...%X#hhXXXX#h....",
			"........XXXX......",
		],
		"relief": [
			"000000000000000000",
			"000000000000000000",
			"000000000000000000",
			"000000000000000000",
			"000000000000000000",
			"000000000000000000",
			"000000000000000000",
			"000000000000000000",
			"000000000000000000",
			"000000000000000000",
			"000000000000000000",
			"000000000000000000",
		],
	},
}

# ------------------------------------------------------------ lecture du dessin

static func _lettre(c: String) -> String:
	return c.to_upper() if FAMILLES.has(c.to_upper()) else ""

static func _car(dessin: Array, i: int, j: int) -> String:
	if j < 0 or j >= dessin.size(): return "."
	var ligne: String = dessin[j]
	if i < 0 or i >= ligne.length(): return "."
	return ligne[i]

static func _niveau(relief: Array, i: int, j: int) -> int:
	if j < 0 or j >= relief.size(): return 0
	var ligne: String = relief[j]
	if i < 0 or i >= ligne.length(): return 0
	var c := ligne[i]
	return int(c) if c >= "0" and c <= "9" else 0

## Le dessin devient une carte : terre, paliers, chaussée. Le pavage des rues
## et les rampes se déduisent ensuite tout seuls (`CarteVille.tuile`).
static func carte_de(fiche: Dictionary) -> CarteVille:
	var dessin: Array = fiche["plan"]
	var relief: Array = fiche.get("relief", [])
	var carte := CarteVille.new()
	var large := 0
	for l in dessin:
		large = maxi(large, String(l).length())
	for j in dessin.size():
		for i in large:
			var c := _car(dessin, i, j)
			if c == "." or c == "~":
				continue
			carte.poser_sol(Vector2i(i, j), _niveau(relief, i, j))
			if c in CHAUSSEE:
				carte.poser_route(Vector2i(i, j), true)
	# Les ronds-points APRÈS : ils ont besoin que leurs neuf cases existent.
	for j in dessin.size():
		for i in large:
			if _car(dessin, i, j) == "O":
				if not carte.poser_piece("road-roundabout", Vector2i(i - 1, j - 1), 3, 0):
					push_warning("rond-point refusé en (%d,%d) : il lui faut 3x3 cases de terre au même palier" % [i, j])
	return carte

# ------------------------------------------------------------ les bâtiments

## Les rectangles de lettres. On balaye ; à la première case non vue, on étire
## vers l'est tant que c'est la même lettre, puis vers le sud tant que la
## rangée entière l'est aussi. Le dessinateur trace des rectangles : inutile
## d'aller chercher des formes en L qu'il ne dessinera jamais.
static func batiments(dessin: Array) -> Array:
	var vus: Dictionary = {}
	var sortie: Array = []
	var large := 0
	for l in dessin:
		large = maxi(large, String(l).length())
	for j in dessin.size():
		for i in large:
			var cle := Vector2i(i, j)
			if vus.has(cle): continue
			var c := _car(dessin, i, j)
			if _lettre(c) == "": continue
			var w := 1
			while _car(dessin, i + w, j) == c and not vus.has(Vector2i(i + w, j)):
				w += 1
			var h := 1
			while true:
				var entier := true
				for k in w:
					if _car(dessin, i + k, j + h) != c or vus.has(Vector2i(i + k, j + h)):
						entier = false
						break
				if not entier: break
				h += 1
			for a in w:
				for b in h:
					vus[Vector2i(i + a, j + b)] = true
			sortie.append({"lettre": _lettre(c), "i": i, "j": j, "w": w, "h": h})
	return sortie

# ------------------------------------------------------------ vérification

## LES FAUTES D'UN PLAN, en un seul endroit — le banc (`outils/verifier.gd`) et
## l'éditeur s'en servent tous les deux. Écrites deux fois, elles auraient
## divergé au premier ajout, et l'éditeur aurait laissé passer ce que le banc
## refuse.
## Trois fautes, qui ne se voient QUE sur la photo et trop tard :
##  1. une marche de relief au pied d'un carrefour, d'un virage ou d'un T : le
##     kit n'a pas de croisement en pente, la rue fait un ressaut ;
##  2. une marche de plus de deux paliers : la rampe la plus raide du kit
##     (`road-slant-high`) en monte deux, pas trois ;
##  3. un bâtiment à cheval sur deux paliers : il se pose sur le plus haut et
##     flotte au-dessus du plus bas.
## Plus un compte : un rond-point qui n'a pas trouvé ses 3 x 3 cases disparaît
## sans bruit.
static func fautes(fiche: Dictionary) -> Array:
	var dessin: Array = fiche["plan"]
	var carte := carte_de(fiche)
	var liste: Array = []
	for c in carte.cases.keys():
		if not carte.route(c) or carte.case_prise(c): continue
		var m := carte.masque(c)
		for k in 4:
			var v: Vector2i = c + CarteVille.COTES[k]
			if not carte.route(v): continue
			var ecart: int = carte.palier(v) - carte.palier(c)
			if ecart <= 0: continue
			var selon_axe := ((m & 5) == 0 and (k == 1 or k == 3)) \
				or ((m & 10) == 0 and (k == 0 or k == 2))
			if not selon_axe:
				liste.append({"i": c.x, "j": c.y,
					"texte": "marche de %d au pied d'un croisement" % ecart})
			elif ecart > 2:
				liste.append({"i": c.x, "j": c.y,
					"texte": "marche de %d : le kit monte de deux paliers au plus" % ecart})
	for b in batiments(dessin):
		var niv := -99
		var faute := false
		for a in int(b["w"]):
			for d in int(b["h"]):
				var cc := Vector2i(int(b["i"]) + a, int(b["j"]) + d)
				if not carte.terre(cc): continue
				if niv == -99: niv = carte.palier(cc)
				elif niv != carte.palier(cc): faute = true
		if faute:
			liste.append({"i": int(b["i"]), "j": int(b["j"]),
				"texte": "bâtiment %s à cheval sur deux paliers" % b["lettre"]})
	var demandes := 0
	for l in dessin:
		demandes += String(l).count("O")
	if demandes != carte.pieces.size():
		liste.append({"i": -1, "j": -1, "texte": "%d rond(s)-point(s) demandé(s), %d posé(s) : il leur faut 3x3 cases de terre au même palier" % [demandes, carte.pieces.size()]})
	return liste

# ------------------------------------------------------------ construction

## Bâtit un quartier. Le nœud rendu porte déjà son origine et son ANGLE : on
## l'ajoute tel quel, et deux quartiers voisins n'ont aucune raison d'être
## d'accord sur la direction du nord.
static func batir(id: String) -> Node3D:
	var fiche: Dictionary = CATALOGUE.get(id, {})
	if fiche.is_empty():
		push_error("Quartier inconnu : " + id)
		return Node3D.new()
	return batir_fiche(fiche, id)

## ⚠ L'ÉDITEUR passe par ici, pas par une copie : une fiche qu'on vient de
## modifier à la souris doit se bâtir EXACTEMENT comme celle du catalogue,
## sinon l'éditeur montre une ville et le jeu en bâtit une autre.
static func batir_fiche(fiche: Dictionary, id: String = "atelier") -> Node3D:
	var racine := Node3D.new()
	racine.name = "Quartier_" + id
	var org: Vector2 = fiche.get("origine", Vector2.ZERO)
	racine.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(fiche.get("angle", 0.0)))),
		Vector3(org.x * CASE, 0, org.y * CASE))
	var carte := carte_de(fiche)
	var dessin: Array = fiche["plan"]
	var alea := RandomNumberGenerator.new()
	alea.seed = int(fiche.get("graine", 1))

	_poser_sols(racine, carte, dessin, fiche)
	_poser_chaussees(racine, carte)
	_poser_batiments(racine, carte, dessin, fiche, alea)
	_poser_verdure(racine, carte, dessin, alea)
	_poser_mobilier(racine, carte, dessin, alea)
	_poser_bateaux(racine, dessin, alea)
	return racine

static func _poser_sols(racine: Node3D, carte: CarteVille, dessin: Array, fiche: Dictionary) -> void:
	var herbe: Color = fiche.get("herbe", Color("#7f9464"))
	var roche: Color = fiche.get("roche", Color("#8b8578"))
	for c in carte.cases.keys():
		var y := carte.hauteur(c)
		var centre := Vector3((float(c.x) + 0.5) * CASE, y, (float(c.y) + 0.5) * CASE)
		var car := _car(dessin, c.x, c.y)
		if not carte.route(c):
			# TOUT CE QUI PORTE UN BÂTIMENT EST PAVÉ. C'était le défaut le plus
			# criant des maquettes : des immeubles posés sur une pelouse. Dans
			# une ville, l'herbe est l'exception, pas le fond.
			var teinte := herbe
			if car in PAVE or _lettre(car) != "": teinte = TEINTE_PAVE
			elif car == ";": teinte = TEINTE_SABLE
			_tuile(racine, "tile-low", centre, 0, teinte)
		# Le socle : un bloc jusqu'à la mer, seulement là où il se voit.
		var vu := false
		for d in CarteVille.COTES:
			if carte.palier(c + d) < carte.palier(c): vu = true
		if vu:
			_falaise(racine, centre, y, roche)

## LA FALAISE. Un seul bloc du sol jusqu'à la mer donnait un mur de plâtre de
## quarante unités : la ville avait l'air posée sur un socle de maquette. On la
## dessine en STRATES d'un palier, chacune rentrée d'un poil et un ton plus
## sombre que celle du dessus — c'est ce qui fait lire une falaise plutôt
## qu'une découpe, et ça ne coûte que quelques boîtes de plus par case de bord.
static func _falaise(racine: Node3D, centre: Vector3, y: float, roche: Color) -> void:
	var bas := -2.6
	var strates := maxi(1, ceili((y - bas) / PALIER))
	for k in strates:
		var haut: float = y - float(k) * PALIER
		var sous: float = maxf(bas, haut - PALIER)
		var n := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(CASE, 1.0, CASE)
		n.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = roche.darkened(0.06 + 0.055 * float(k))
		m.roughness = 1.0
		n.material_override = m
		var e := 1.0 - 0.028 * float(k)     # chaque strate rentre un peu
		n.transform = Transform3D(Basis().scaled(Vector3(e, haut - sous, e)),
			centre + Vector3(0, (haut + sous) * 0.5 - y, 0))
		racine.add_child(n)

static func _poser_chaussees(racine: Node3D, carte: CarteVille) -> void:
	for c in carte.cases.keys():
		if not carte.route(c) or carte.case_prise(c): continue
		var fiche: Array = carte.tuile(c)
		_tuile(racine, String(fiche[0]), carte.centre(c), int(fiche[1]), TEINTE_ROUTE)
	for p in carte.pieces:
		var cote := int(p["w"])
		var coin := Vector2i(int(p["i"]), int(p["j"]))
		_tuile(racine, String(p["t"]),
			Vector3((float(coin.x) + float(cote) * 0.5) * CASE, carte.hauteur(coin),
				(float(coin.y) + float(cote) * 0.5) * CASE), int(p["q"]), TEINTE_ROUTE)

## ⚠ Une pièce du kit EST DÉJÀ à sa taille : `road-roundabout` mesure trois
## unités de côté. On multiplie par UNE case, jamais par son côté — le rond-
## point est sorti une fois à neuf cases de large, et ça s'est vu tout de suite.
static func _tuile(parent: Node3D, nom: String, ou: Vector3, quarts: int, teinte: Color) -> void:
	var chemin := ROUTES + nom + ".glb"
	if not ResourceLoader.exists(chemin): return
	var n := MeshInstance3D.new()
	n.mesh = FormesCarnage.maillage_kenney(chemin, 0.0, Vector3.AXIS_X, 0.0)
	n.material_override = _matiere(chemin, teinte)
	n.transform = Transform3D(Basis(Vector3.UP, PI * 0.5 * float(quarts)).scaled(Vector3.ONE * CASE), ou)
	parent.add_child(n)

static var _matieres: Dictionary = {}

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

## Un bâtiment remplit SON rectangle, moins un retrait. Le retrait est ce qui
## fait qu'on voit le jour entre deux immeubles ; sans lui le pâté n'est plus
## qu'un bloc, et avec trop, la ville redevient un lotissement.
const RETRAIT := 0.10

## ⚠ L'EMPRISE MAXIMALE D'UN MODÈLE, en cases. Un pavillon Kenney est dessiné
## pour tenir sur une case ; étiré sur quatre, il devient un bungalow de
## quarante mètres avec une porte de garage de dix — c'est exactement ce qui
## rendait la vieille ville risible. Au-delà de son emprise, un rectangle de
## lettres est DÉCOUPÉ en autant de bâtiments qu'il faut : `MMMM` sur deux
## rangées ne fait pas une maison géante, il fait huit maisons mitoyennes.
const EMPRISES := {"T": 3.0, "B": 3.0, "C": 2.0, "V": 1.0, "M": 1.0, "H": 4.0}

static func _poser_batiments(racine: Node3D, carte: CarteVille, dessin: Array,
		fiche: Dictionary, alea: RandomNumberGenerator) -> void:
	var etages: Dictionary = fiche.get("hauteurs", {})
	for b in batiments(dessin):
		var lettre := String(b["lettre"])
		var style: int = FAMILLES.get(lettre, PlanVille.F_COMMERCE)
		var coin := Vector2i(int(b["i"]), int(b["j"]))
		var w := float(b["w"])
		var h := float(b["h"])
		# À cheval sur deux paliers, on prend le PLUS HAUT : un immeuble à
		# moitié enterré vaut mieux qu'un immeuble sur pilotis invisibles.
		var niveau := 0
		var pose := true
		for a in int(w):
			for c in int(h):
				var cc := coin + Vector2i(a, c)
				if not carte.terre(cc) or carte.case_prise(cc): pose = false
				niveau = maxi(niveau, carte.palier(cc))
		if not pose: continue
		var bornes: Array = etages.get(lettre, [14.0, 26.0])
		var emax: float = float(EMPRISES.get(lettre, 3.0))
		var na := maxi(1, ceili(w / emax - 0.001))
		var nb := maxi(1, ceili(h / emax - 0.001))
		var pas_a := w / float(na)
		var pas_b := h / float(nb)
		var precedent := ""
		for a in na:
			for c in nb:
				var hauteur: float = alea.randf_range(float(bornes[0]), float(bornes[1]))
				var larg := (pas_a - RETRAIT * 2.0) * CASE
				var prof := (pas_b - RETRAIT * 2.0) * CASE
				if larg < 3.0 or prof < 3.0: continue
				var chemin := FormesCarnage.batiment_kenney(style, minf(larg, prof), hauteur,
					alea.randi(), precedent)
				if chemin == "": continue
				precedent = chemin
				var teintes: Array = PlanVille.TEINTES.get(style, [Color.WHITE])
				var teinte: Color = teintes[alea.randi() % teintes.size()]
				var n := MeshInstance3D.new()
				n.mesh = FormesCarnage.maillage_batiment(chemin)
				n.material_override = _matiere(chemin, teinte)
				n.transform = Transform3D(Basis().scaled(Vector3(larg, hauteur, prof)),
					Vector3((float(coin.x) + (float(a) + 0.5) * pas_a) * CASE,
						float(niveau) * PALIER,
						(float(coin.y) + (float(c) + 0.5) * pas_b) * CASE))
				racine.add_child(n)

const ARBRES := ["nature/tree_default", "nature/tree_oak", "nature/tree_fat",
	"nature/tree_detailed", "nature/tree_cone"]

## Le décor de sol : ce qui n'est ni rue ni bâtiment mais qui empêche une case
## d'être un trou. Un pâté vide se lit comme un bogue, et un port sans
## conteneurs n'est qu'un lotissement au bord de l'eau.
## ⚠ Les proportions, pas les modèles : à l'échelle du jeu une voiture fait dix
## unités de long, donc une unité vaut à peu près un demi-mètre. Un conteneur
## de deux mètres soixante fait SIX unités, pas neuf ; et une cuve à dix mètres
## en fait vingt — d'où la règle de ne pas en semer partout, sinon le port
## n'est plus qu'un champ de citernes plus hautes que ses hangars.
const DEPOT := [
	["industriel/shipping-container-a", 6.0], ["industriel/shipping-container-b", 6.0],
	["industriel/shipping-container-c", 6.0], ["industriel/shipping-container-a", 6.0],
	["industriel/shipping-container-b", 6.0], ["industriel/shipping-container-c", 6.0],
	["industriel/shipping-container-a", 6.0], ["industriel/shipping-container-b", 6.0],
	["industriel/solar-panel-flat", 2.4],
]
const CHANTIER := [
	["routes/construction-barrier", 4.0], ["routes/construction-cone", 2.6],
	["routes/construction-fence", 6.0], ["routes/construction-light", 6.5],
	["routes/dumpster", 5.0],
]

## Une cuve n'a le droit de sortir que si aucune autre n'est à moins de trois
## cases, et pas plus d'une pour dix cases de dépôt. Trois cuves côte à côte,
## ça ne fait pas un port : ça fait une usine à gaz.
const ECART_CUVES := 3
const PART_CUVES := 0.10

static func _cuve_ici(c: Vector2i, cuves: Array, alea: RandomNumberGenerator) -> bool:
	for v in cuves:
		if absi((v as Vector2i).x - c.x) < ECART_CUVES and absi((v as Vector2i).y - c.y) < ECART_CUVES:
			return false
	return alea.randf() < 0.5

static func _poser_verdure(racine: Node3D, carte: CarteVille, dessin: Array,
		alea: RandomNumberGenerator) -> void:
	var cuves: Array = []
	var depots := 0
	for c in carte.cases.keys():
		if _car(dessin, c.x, c.y) == "X": depots += 1
	var plafond := maxi(1, int(float(depots) * PART_CUVES))
	for c in carte.cases.keys():
		var car := _car(dessin, c.x, c.y)
		var y := carte.hauteur(c)
		match car:
			"^":
				for k in 3:
					_objet(racine, ARBRES[alea.randi() % ARBRES.size()], _dans(c, y, alea),
						alea.randf_range(9.0, 15.0), alea.randf() * TAU)
			"\'":
				for k in 5:
					_objet(racine, "nature/plant_bushLarge", _dans(c, y, alea),
						alea.randf_range(2.2, 3.4), alea.randf() * TAU)
			"X":
				# Les conteneurs s'alignent sur la case, pas au hasard : un
				# dépôt, ça s'empile en rangées, sinon on dirait une décharge.
				if cuves.size() < plafond and _cuve_ici(c, cuves, alea):
					cuves.append(c)
					_objet(racine, "industriel/detail-tank-large",
						Vector3((float(c.x) + 0.5) * CASE, y, (float(c.y) + 0.5) * CASE), 19.0)
					continue
				for k in 3:
					for l in 2:
						if alea.randf() < 0.28: continue
						var f: Array = DEPOT[alea.randi() % DEPOT.size()]
						_objet(racine, String(f[0]),
							Vector3((float(c.x) + 0.2 + 0.3 * float(k)) * CASE, y,
								(float(c.y) + 0.28 + 0.44 * float(l)) * CASE),
							float(f[1]), 0.0)
			"%":
				for k in 4:
					var g: Array = CHANTIER[alea.randi() % CHANTIER.size()]
					_objet(racine, String(g[0]), _dans(c, y, alea), float(g[1]), alea.randf() * TAU)
			"P":
				# Un parking sans voitures n'est qu'une dalle grise.
				for k in 2:
					_voiture(racine, Vector3((float(c.x) + 0.3 + 0.4 * float(k)) * CASE, y,
						(float(c.y) + 0.5) * CASE), false, alea)

## Un point DANS la case, mais rentré des bords : semé jusqu'au bord, un arbre
## déborde de moitié sur la case d'à côté — souvent un immeuble.
static func _dans(c: Vector2i, y: float, alea: RandomNumberGenerator) -> Vector3:
	return Vector3((float(c.x) + 0.22 + alea.randf() * 0.56) * CASE, y,
		(float(c.y) + 0.22 + alea.randf() * 0.56) * CASE)

const VOITURES := ["sedan", "suv", "taxi", "van", "delivery", "hatchback-sports",
	"sedan-sports", "police", "truck", "garbage-truck"]

## Ce qui donne l'ÉCHELLE : lampadaires, feux, arbres d'alignement, voitures.
## Sans eux la ville est une maquette d'architecte — c'est le reproche qu'on
## s'est pris sur la toute première.
static func _poser_mobilier(racine: Node3D, carte: CarteVille, dessin: Array,
		alea: RandomNumberGenerator) -> void:
	for c in carte.cases.keys():
		if not carte.route(c) or carte.case_prise(c): continue
		var fiche: Array = carte.tuile(c)
		var nom := String(fiche[0])
		var y := carte.hauteur(c)
		var centre := carte.centre(c)
		var bord := CASE * 0.42
		if nom == "road-straight":
			var selon_x := int(fiche[1]) == 0
			var vers: Vector2i = CarteVille.S if selon_x else CarteVille.E
			var d := Vector3(0, 0, bord) if selon_x else Vector3(bord, 0, 0)
			var t := 0.0 if selon_x else PI * 0.5
			# Un lampadaire tient sur le trottoir ; un arbre, non : il ne se
			# plante que du côté où la case voisine est LIBRE.
			if alea.randf() < 0.30:
				_objet(racine, "routes/light-square", centre + d, 9.5, t, Color("#6e737c"))
				_objet(racine, "routes/light-square", centre - d, 9.5, t + PI, Color("#6e737c"))
			if alea.randf() < 0.30:
				var libres: Array = []
				if _lettre(_car(dessin, c.x + vers.x, c.y + vers.y)) == "": libres.append(d)
				if _lettre(_car(dessin, c.x - vers.x, c.y - vers.y)) == "": libres.append(-d)
				if not libres.is_empty():
					_objet(racine, ARBRES[alea.randi() % ARBRES.size()],
						centre + libres[alea.randi() % libres.size()] * 0.82,
						alea.randf_range(8.0, 12.0), alea.randf() * TAU)
			if alea.randf() < 0.28:
				_voiture(racine, centre, selon_x, alea)
		elif nom == "road-crossroad" and alea.randf() < 0.65:
			for k in 4:
				var a := PI * 0.5 * float(k)
				_objet(racine, "routes/traffic-light",
					centre + Vector3(cos(a), 0, sin(a)) * bord, 8.0, a)

static func _voiture(racine: Node3D, ou: Vector3, selon_x: bool, alea: RandomNumberGenerator) -> void:
	var chemin := "res://modeles/kenney/voitures/%s.glb" % VOITURES[alea.randi() % VOITURES.size()]
	if not ResourceLoader.exists(chemin): return
	var n := MeshInstance3D.new()
	# ⚠ Les carrosseries du Car Kit regardent +Z là où le reste du kit regarde
	# −Z : un quart de tour dans l'AUTRE sens, sinon la ville roule à reculons.
	n.mesh = FormesCarnage.maillage_kenney(chemin, 10.0, Vector3.AXIS_Z, PI * 0.5)
	n.material_override = FormesCarnage.matiere_kenney(chemin)
	var voie := CASE * 0.16 * (1.0 if alea.randf() < 0.5 else -1.0)
	var sens := 0.0 if voie > 0.0 else PI
	var decal := alea.randf_range(-6.0, 6.0)
	n.transform = Transform3D(Basis(Vector3.UP, sens + (0.0 if selon_x else PI * 0.5)),
		ou + (Vector3(decal, 0, voie) if selon_x else Vector3(voie, 0, decal)))
	racine.add_child(n)

static func _objet(parent: Node3D, sous_chemin: String, ou: Vector3, hauteur: float,
		tourne: float = 0.0, teinte := Color.WHITE) -> void:
	var chemin := "res://modeles/kenney/" + sous_chemin + ".glb"
	if not ResourceLoader.exists(chemin): return
	var n := MeshInstance3D.new()
	n.mesh = FormesCarnage.maillage_kenney(chemin, hauteur, Vector3.AXIS_Y, 0.0)
	n.material_override = _matiere(chemin, teinte)
	n.transform = Transform3D(Basis(Vector3.UP, tourne), ou)
	parent.add_child(n)

# ------------------------------------------------------------ les bateaux

## LE MOUILLAGE. Une file de `~` est une place d'amarrage : sa LONGUEUR dit
## quel bateau vient s'y mettre. Écrire un modèle par case aurait demandé un
## caractère par bateau ; là, on dessine l'eau du port et la flotte suit.
## ⚠ Les coques du Watercraft Pack sont toutes longues selon Z (mesuré,
## `outils/bateaux.gd`) : on les tourne pour les aligner sur la file.
const FLOTTE := [
	# longueur mini de la file (en cases), modèle, longueur en unités de jeu
	[6, ["bateaux/ship-ocean-liner-small", 220.0], ["bateaux/ship-cargo-a", 200.0],
		["bateaux/ship-cargo-b", 200.0], ["bateaux/ship-large", 180.0]],
	[4, ["bateaux/ship-small", 140.0], ["bateaux/ship-cargo-b", 200.0]],
	[2, ["bateaux/boat-tug-a", 50.0], ["bateaux/boat-tug-b", 46.0],
		["bateaux/boat-fishing-small", 28.0]],
	[1, ["bateaux/boat-speed-a", 16.0], ["bateaux/boat-speed-c", 16.0],
		["bateaux/boat-sail-a", 24.0], ["bateaux/boat-row-large", 12.0],
		["bateaux/buoy", 5.0], ["bateaux/buoy-flag", 6.0]],
]
const NIVEAU_MER := -2.4

static func _poser_bateaux(racine: Node3D, dessin: Array, alea: RandomNumberGenerator) -> void:
	var vues: Dictionary = {}
	var large := 0
	for l in dessin:
		large = maxi(large, String(l).length())
	# Les files horizontales, puis les verticales : une place d'amarrage se lit
	# dans le sens du quai.
	for j in dessin.size():
		var i := 0
		while i < large:
			if _car(dessin, i, j) != "~" or vues.has(Vector2i(i, j)):
				i += 1
				continue
			var n := 0
			while _car(dessin, i + n, j) == "~" and not vues.has(Vector2i(i + n, j)):
				n += 1
			for k in n: vues[Vector2i(i + k, j)] = true
			_amarrer(racine, Vector2(float(i) + float(n) * 0.5, float(j) + 0.5), n, true, alea)
			i += n
	for i in large:
		var j := 0
		while j < dessin.size():
			if _car(dessin, i, j) != "~" or vues.has(Vector2i(i, j)):
				j += 1
				continue
			var n := 0
			while _car(dessin, i, j + n) == "~" and not vues.has(Vector2i(i, j + n)):
				n += 1
			for k in n: vues[Vector2i(i, j + k)] = true
			_amarrer(racine, Vector2(float(i) + 0.5, float(j) + float(n) * 0.5), n, false, alea)
			j += n

static func _amarrer(racine: Node3D, centre: Vector2, longueur: int, selon_x: bool,
		alea: RandomNumberGenerator) -> void:
	for fiche in FLOTTE:
		if longueur < int(fiche[0]): continue
		var choix: Array = fiche[1 + alea.randi() % (fiche.size() - 1)]
		var chemin := "res://modeles/kenney/" + String(choix[0]) + ".glb"
		if not ResourceLoader.exists(chemin): return
		var n := MeshInstance3D.new()
		n.mesh = FormesCarnage.maillage_kenney(chemin, float(choix[1]), Vector3.AXIS_Z, 0.0)
		n.material_override = FormesCarnage.matiere_kenney(chemin)
		var tour := (PI * 0.5 if selon_x else 0.0) + alea.randf_range(-0.03, 0.03)
		n.transform = Transform3D(Basis(Vector3.UP, tour),
			Vector3(centre.x * CASE, NIVEAU_MER, centre.y * CASE))
		racine.add_child(n)
		return

# ------------------------------------------------------------ la ville entière

## Les ponts sont posés en MONDE, hors des grilles : ils joignent deux
## quartiers qui n'ont pas le même angle, donc ils sont forcément en biais.
## C'est aussi ce qui autorisera des îles orientées n'importe comment.
const PONTS := [
	[Vector2(1.5, 14.6), Vector2(-1.4, 18.6), 0.0, 1.0],
	[Vector2(26.0, 15.4), Vector2(26.6, 21.4), 4.0, 0.0],
]

static func ville() -> Node3D:
	var racine := Node3D.new()
	racine.name = "Ville"
	var mer := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(600.0 * CASE, 600.0 * CASE)
	mer.mesh = plan
	var eau := StandardMaterial3D.new()
	eau.albedo_color = Color("#2b5f7a")
	eau.roughness = 0.15
	eau.metallic = 0.25
	mer.material_override = eau
	mer.position = Vector3(0, -2.4, 0)
	racine.add_child(mer)
	for id in CATALOGUE.keys():
		racine.add_child(batir(String(id)))
	for p in PONTS:
		_pont(racine, Vector3(p[0].x * CASE, float(p[2]) * PALIER, p[0].y * CASE),
			Vector3(p[1].x * CASE, float(p[3]) * PALIER, p[1].y * CASE))
	return racine

static func _pont(racine: Node3D, a: Vector3, b: Vector3) -> void:
	var pas := maxf(1.0, a.distance_to(b) / CASE)
	var dir := (b - a).normalized()
	var angle := atan2(-dir.z, dir.x)
	for k in int(pas) + 1:
		var p := a.lerp(b, float(k) / pas)
		var n := MeshInstance3D.new()
		var chemin := ROUTES + "road-bridge.glb"
		n.mesh = FormesCarnage.maillage_kenney(chemin, 0.0, Vector3.AXIS_X, 0.0)
		n.material_override = _matiere(chemin, Color("#9aa0aa"))
		# Le tablier suit la CORDE, pas la grille — et chaque pièce est
		# allongée d'un poil, sinon deux voisines laissent une fente en biais.
		n.transform = Transform3D(Basis(Vector3.UP, angle).scaled(Vector3(CASE * 1.08, CASE, CASE)), p)
		racine.add_child(n)
