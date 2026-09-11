class_name CarteVille
extends RefCounted
## LA CARTE DESSINÉE À LA MAIN.
##
## Le plan procédural (`PlanVille`) déduit la ville d'un code de manche : il
## remplit vite et il remplit partout, mais il ne saura jamais faire une ville
## qui a l'air d'avoir été VÉCUE. Cette classe-ci porte l'autre voie : une
## carte posée case par case dans l'éditeur (`scenes/editeur.gd`), sauvée en
## JSON, et relue telle quelle par le jeu.
##
## L'UNITÉ EST LA CASE : vingt unités 3D de côté, soit DEUX tuiles du jeu —
## exactement une tuile du City Kit: Roads mise à l'échelle uniforme. C'est le
## seul découpage qui laisse les marquages et les trottoirs du kit à leurs
## proportions ; tout ce qu'on a étiré jusqu'ici sortait bavé.
##
## LE RELIEF SE COMPTE EN PALIERS de cinq unités (un quart de tuile Kenney,
## la hauteur exacte dont `road-slant` grimpe en une case). Une case porte son
## palier ; deux cases voisines qui n'ont pas le même reçoivent une rampe si
## une rue les joint, un mur de soutènement sinon.

const CASE := 20.0                     ## côté d'une case, en unités 3D
const PALIER := 5.0                    ## un cran de relief (= 0,25 tuile Kenney)
const CHEMIN_ROUTES := "res://modeles/kenney/routes/"

## Les quatre voisines, dans l'ordre des bits du masque de raccord.
const N := Vector2i(0, -1)
const E := Vector2i(1, 0)
const S := Vector2i(0, 1)
const O := Vector2i(-1, 0)
const COTES := [N, E, S, O]

## Une case : `n` le palier, `r` vrai s'il y a de la chaussée. Rien d'autre —
## tout ce qui est posé dessus (immeubles, arbres, mobilier) vit dans
## `objets`, en coordonnées libres : un arbre n'a aucune raison de tenir dans
## une grille, et l'y forcer donnait des alignements de cimetière.
var cases: Dictionary = {}             ## Vector2i -> {"n": int, "r": bool}
## Les GROSSES PIÈCES du kit : rond-point (3 x 3), courbe large (2 x 2), rampe
## douce (2 x 1). Elles ne se déduisent pas d'un masque de raccord, on les pose
## exprès. `i`,`j` est leur coin nord-ouest, `w` x `h` leur emprise EN CASES ET
## DANS LE MONDE (déjà tournée), `q` ses quarts de tour.
## ⚠ `h` est facultatif dans le JSON : une carte enregistrée avant les pièces
## rectangulaires n'a que des carrés, et `h` vaut alors `w`.
var pieces: Array = []                 ## [{t, i, j, q, w, h, p}]
var objets: Array = []                 ## [{m, x, y, z, r, l, p, h, c}]
var nom := "sans-titre"

# ------------------------------------------------------------------ cases

func palier(c: Vector2i) -> int:
	var f = cases.get(c)
	return int(f["n"]) if f != null else -999

func terre(c: Vector2i) -> bool:
	return cases.has(c)

func route(c: Vector2i) -> bool:
	var f = cases.get(c)
	return f != null and bool(f["r"])

func hauteur(c: Vector2i) -> float:
	return float(palier(c)) * PALIER

## Le centre d'une case, en unités 3D. Le sol est en Y = palier x PALIER.
func centre(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * CASE, hauteur(c), (float(c.y) + 0.5) * CASE)

func poser_sol(c: Vector2i, niveau: int) -> void:
	if cases.has(c):
		cases[c]["n"] = niveau
	else:
		cases[c] = {"n": niveau, "r": false}

func effacer(c: Vector2i) -> void:
	cases.erase(c)
	_oter_pieces_sur(c)

func poser_route(c: Vector2i, oui: bool) -> void:
	if not cases.has(c):
		return
	cases[c]["r"] = oui
	if not oui:
		_oter_pieces_sur(c)

# --------------------------------------------------------- grosses pièces

static func taille_de(p: Dictionary) -> Vector2i:
	return Vector2i(int(p["w"]), int(p.get("h", p["w"])))

## La grosse pièce qui couvre cette case, ou un dictionnaire vide.
func piece_sur(c: Vector2i) -> Dictionary:
	for p in pieces:
		var t := taille_de(p)
		if c.x >= int(p["i"]) and c.x < int(p["i"]) + t.x \
				and c.y >= int(p["j"]) and c.y < int(p["j"]) + t.y:
			return p
	return {}

## ⚠ LA CASE EST-ELLE DÉJÀ COUVERTE PAR SA PIÈCE ? Une pièce AJOURÉE ne remplit
## pas son emprise : ses cases sans chaussée gardent le sol du dessin. Une pièce
## PLEINE — la courbe large « -pavement », qui apporte son propre trottoir — la
## remplit : lui poser en plus la pelouse de la case, c'est deux surfaces au même
## niveau, et le rendu choisissait au hasard laquelle montrer. Vu de la rue, la
## bretelle sortait avec un carré d'herbe posé en travers de son trottoir.
func case_couverte(c: Vector2i) -> bool:
	var p := piece_sur(c)
	return not p.is_empty() and not AJOUREES.has(String(p["t"]))

func case_prise(c: Vector2i) -> bool:
	for p in pieces:
		var t := taille_de(p)
		if c.x >= int(p["i"]) and c.x < int(p["i"]) + t.x \
				and c.y >= int(p["j"]) and c.y < int(p["j"]) + t.y:
			return true
	return false

## Ôte la grosse pièce qui couvre cette case, s'il y en a une.
func oter_piece(c: Vector2i) -> void:
	_oter_pieces_sur(c)

func _oter_pieces_sur(c: Vector2i) -> void:
	var restantes: Array = []
	for p in pieces:
		var t := taille_de(p)
		var dedans := c.x >= int(p["i"]) and c.x < int(p["i"]) + t.x \
			and c.y >= int(p["j"]) and c.y < int(p["j"]) + t.y
		if not dedans:
			restantes.append(p)
	pieces = restantes

## Pose une grosse pièce si toutes ses cases sont de la terre au MÊME palier —
## un rond-point à cheval sur deux terrasses n'a aucun sens et le kit ne sait
## pas le dessiner.
## ⚠ `pente` : LE SEUL CAS OÙ LES CASES N'ONT PAS LE MÊME PALIER. Une rampe
## douce monte de deux crans sur ses deux cases ; lui imposer la règle du
## rond-point la rendait imposable. Le reste des pièces la garde : un
## rond-point à cheval sur deux terrasses n'a aucun sens et le kit ne sait pas
## le dessiner.
func poser_piece(nom_tuile: String, coin: Vector2i, taille: Vector2i, quarts: int,
		pente := false) -> bool:
	var niveau := palier(coin)
	for a in taille.x:
		for b in taille.y:
			var c := coin + Vector2i(a, b)
			if not terre(c) or case_prise(c):
				return false
			if not pente and palier(c) != niveau:
				return false
	for a in taille.x:
		for b in taille.y:
			var c := coin + Vector2i(a, b)
			# Les bras d'un rond-point sont de la chaussée ; ses quartiers ne
			# le sont pas. Une courbe large, elle, ne relie que DEUX cases en
			# diagonale — marquer tout le carré fausserait le raccord des rues
			# voisines, et les deux autres cases sont du décor.
			cases[c]["r"] = _piece_est_chaussee(nom_tuile, Vector2i(a, b), taille, quarts)
	pieces.append({"t": nom_tuile, "i": coin.x, "j": coin.y, "q": quarts,
		"w": taille.x, "h": taille.y})
	return true

## ⚠ LA CASE EST DONNÉE DANS LE MONDE, LA RÈGLE EST ÉCRITE DANS LE MODÈLE. On
## ramène donc la case au repère NON TOURNÉ de la pièce avant de décider. Un
## quart de tour envoie l'ouest au SUD (mesuré au banc, pas deviné) — c'est
## exactement ce que fait `(a, b) -> (h - 1 - b, a)`, et l'emprise s'échange à
## chaque quart : une pièce 2 x 1 tournée d'un quart occupe 1 x 2.
static func repere_modele(c: Vector2i, taille: Vector2i, quarts: int) -> Vector2i:
	var p := c
	var t := taille
	for _k in posmod(quarts, 4):
		p = Vector2i(t.y - 1 - p.y, p.x)
		t = Vector2i(t.y, t.x)
	return p

## L'emprise du MODÈLE (avant rotation) pour une emprise donnée dans le monde.
static func taille_modele(taille: Vector2i, quarts: int) -> Vector2i:
	return Vector2i(taille.y, taille.x) if posmod(quarts, 4) % 2 == 1 else taille

func _piece_est_chaussee(nom_tuile: String, c: Vector2i, taille: Vector2i,
		quarts: int) -> bool:
	var m := repere_modele(c, taille, quarts)
	if nom_tuile == "road-roundabout":
		return m.x == 1 or m.y == 1        # la croix des bras, pas les coins
	if nom_tuile.begins_with("road-curve"):
		# LA COURBE LARGE. Mesurée au banc : sans rotation elle entre par
		# l'OUEST de sa case nord-ouest et sort par le SUD de sa case sud-est.
		# Ses deux autres cases ne portent PAS de chaussée — l'une est le
		# dedans du virage, l'autre est vide (voir AJOUREES).
		return m == Vector2i(0, 0) or m == Vector2i(1, 1)
	# Rampe douce, fourche : toute l'emprise est de la chaussée.
	return true

# ------------------------------------------------------------ raccordement

## Le masque des voisines en chaussée : 1 nord, 2 est, 4 sud, 8 ouest.
func masque(c: Vector2i) -> int:
	var m := 0
	for k in 4:
		if route(c + COTES[k]):
			m |= 1 << k
	return m

## LA TABLE DE PAVAGE. Elle part des orientations MESURÉES au banc (voir
## `outils/raccords.gd`) : `road-straight` va selon X, `road-bend` raccorde
## OUEST et SUD sans rotation, `road-intersection` raccorde OUEST, EST et SUD,
## `road-end-round` s'ouvre à l'EST. Le reste s'en déduit par le fait qu'un
## quart de tour en Y envoie l'ouest au SUD — pas l'inverse ; l'avoir deviné
## à l'œil nous a valu une ville entière de virages qui raccordaient le vide.
const PAVAGE := {
	0: ["road-square", 0],
	1: ["road-end-round", 1], 2: ["road-end-round", 0],
	4: ["road-end-round", 3], 8: ["road-end-round", 2],
	# ⚠ `road-bend-sidewalk`, PAS `road-bend`. LES DEUX TOURNENT PAREIL — mesuré
	# au banc `outils/pavage.sh`, qui pose les tuiles AU-DESSUS DE L'EAU — mais
	# `road-bend` n'est QUE la bande de chaussée : ses deux coins, l'intérieur
	# du virage et l'extérieur, sont VIDES. Rien ne passe dessous : le joueur
	# voyait la mer dans le coin de certains virages. La variante `-sidewalk`
	# remplit le carré d'un trottoir, ce qu'un coin de rue a de toute façon en
	# ville. Le trou se voit sur la planche du banc, pas dans le code.
	3: ["road-bend-sidewalk", 2], 6: ["road-bend-sidewalk", 1],
	12: ["road-bend-sidewalk", 0], 9: ["road-bend-sidewalk", 3],
	5: ["road-straight", 1], 10: ["road-straight", 0],
	7: ["road-intersection", 1], 14: ["road-intersection", 0],
	13: ["road-intersection", 3], 11: ["road-intersection", 2],
	15: ["road-crossroad", 0],
}

## ⚠ LES TUILES QUI NE REMPLISSENT PAS LEUR CARRÉ. Le kit dessine certaines
## pièces comme la seule bande de chaussée : le reste de la case est un TROU,
## et comme rien n'est posé sous une case de rue, le trou donne sur la mer.
## Mesuré tuile par tuile au banc `outils/pavage.sh` (fond bleu = trou). Ces
## cases-là reçoivent une dalle `tile-low` avant leur chaussée ; les autres
## s'en passent, et une ville de soixante mille cases n'a pas à payer une
## dalle qu'on ne verra jamais.
const AJOUREES := {
	"road-end-round": true,      # les deux coins derrière la raquette
	"road-roundabout": true,     # les quatre coins hors de l'anneau
	# ⚠ PAS `road-curve-pavement` : celle-là remplit son carré d'un trottoir,
	# c'est même tout son intérêt. Lui poser une dalle par-dessous la faisait
	# batailler avec elle au pixel près — vu de haut, la bretelle sortait en
	# grand carré blanc au lieu d'une chaussée.
	"road-curve": true, "road-curve-intersection": true,
	"road-bend": true,           # plus au pavage, mais posable à la main
	"road-slant-curve": true, "road-slant-flat-curve": true,
	"road-straight-half": true,  # une demi-chaussée : l'autre moitié est vide
}

## ⚠ LE QUART DE TOUR QUI MET LE HAUT D'UNE RAMPE DU CÔTÉ VOULU, indexé par le
## côté de COTES (0 nord, 1 est, 2 sud, 3 ouest). Une rampe du kit monte vers
## l'EST sans rotation, et un quart de tour envoie l'est au NORD — donc nord
## demande UN quart, sud en demande TROIS.
## ⚠ Ce tableau valait [3, 0, 1, 2] : l'est et l'ouest tombaient juste, le nord
## et le sud étaient INVERSÉS. Toute rue nord-sud qui grimpait descendait en
## fait dans le rendu — sa rampe plongeait là où le terrain montait, et la
## voiture escaladait une marche à l'autre bout. C'est la moitié de « j'ai du
## mal avec les hauteurs » ; ça ne se voyait pas sur une ville plate.
## Remesuré modèle en main : `Basis(UP, +90°)` envoie (+X) sur (-Z).
const VERS_LE_HAUT := [1, 0, 3, 2]

## La tuile d'une case de rue : son nom et ses quarts de tour. `pente` dit si
## la case grimpe (une voisine en chaussée est un palier plus haut) — la rampe
## du kit monte d'exactement un palier sur une case, ce qui est la raison
## d'être du palier.
## ⚠ UNE RAMPE NE SE POSE QUE SUR UN TRONÇON DROIT, ET DANS LE SENS DE LA RUE.
## La première version regardait les quatre voisines : une rue qui LONGEAIT un
## talus voyait la terrasse d'à côté plus haute et se mettait à grimper en
## travers. Le kit n'a d'ailleurs pas de carrefour en pente : un croisement
## doit être de plain-pied, et c'est au dessin de s'en assurer.
func tuile(c: Vector2i) -> Array:
	var m := masque(c)
	var n := palier(c)
	# L'axe de la rue : seulement est-ouest (donc aucun bit nord/sud), ou
	# seulement nord-sud. Ça couvre les tronçons droits ET les bouts de rue —
	# une rampe qui s'arrête au bord de l'eau est parfaitement lisible, alors
	# qu'un carrefour en pente n'existe pas dans le kit.
	if (m & 5) == 0 or (m & 10) == 0:
		var axes: Array = [1, 3] if (m & 5) == 0 else [2, 0]   # est/ouest ou sud/nord
		for k in axes:
			var v: Vector2i = c + COTES[k]
			if not route(v): continue
			var ecart := palier(v) - n
			# `road-slant` monte d'un palier vers l'EST sans rotation,
			# `road-slant-high` de deux (mesuré au banc, `outils/pente.gd`).
			if ecart == 1: return ["road-slant", VERS_LE_HAUT[k]]
			if ecart == 2: return ["road-slant-high", VERS_LE_HAUT[k]]
	var fiche: Array = PAVAGE.get(m, ["road-straight", 0])
	var nom := String(fiche[0])
	# ⚠ LES VARIANTES SE TIRENT SUR LA CASE, PAS AU HASARD. Le kit donne trois
	# carrefours (nu, marquages au sol, passages piétons) et trois T. N'en
	# poser qu'un seul donnait une ville où tous les croisements sont jumeaux ;
	# les tirer avec un dé donnerait un croisement qui change de dessin à
	# chaque reconstruction de morceau — et un morceau se rebâtit à chaque
	# coup de pinceau. Le tirage part donc de la CASE : il est stable.
	var choix: Array = VARIANTES.get(nom, [])
	if not choix.is_empty():
		nom = String(choix[_tirage(c) % choix.size()])
	return [nom, int(fiche[1])]

## Les variantes équivalentes d'une même tuile : même raccordement, même
## rotation, dessin différent.
const VARIANTES := {
	"road-crossroad": ["road-crossroad", "road-crossroad-line", "road-crossroad-path",
		"road-crossroad-line"],
	"road-intersection": ["road-intersection", "road-intersection-line",
		"road-intersection-path", "road-intersection-line"],
	"road-end-round": ["road-end-round", "road-end"],
	# Les trois virages du kit se raccordent pareil ; `road-bend` a ses coins
	# vides, mais il reçoit sa dalle (voir AJOUREES), donc il peut servir.
	"road-bend-sidewalk": ["road-bend-sidewalk", "road-bend-square", "road-bend-sidewalk",
		"road-bend"],
}

static func _tirage(c: Vector2i) -> int:
	return absi(hash(c.x * 73856093 + c.y * 19349663))

## LE PASSAGE PIÉTON. Il se met au PIED d'un carrefour, pas au milieu d'une rue
## — c'est là qu'on traverse. Une case sur deux seulement : une avenue dont
## chaque approche est zébrée ressemble à un circuit de karting.
static func passage_ici(carte: CarteVille, c: Vector2i) -> bool:
	if _tirage(c) % 2 == 0: return false
	for d in COTES:
		if carte.masque(c + d) == 15: return true
	return false

## LA GLISSIÈRE. Le kit dessine ses barrières SÉPARÉMENT de la chaussée : un
## `-barrier` n'est pas une tuile, c'est la paire de rails à poser dessus
## (mesuré au banc `outils/pavage.sh` : le modèle seul ne montre que deux
## traits). Ça tombe bien — on la pose exactement là où la route surplombe
## quelque chose, et c'est ce qui rend un dénivelé LISIBLE : on voit le vide
## parce qu'on voit la rambarde.
const BARRIERES := {
	"road-straight": "road-straight-barrier", "road-crossing": "road-straight-barrier",
	"road-bend": "road-bend-barrier", "road-bend-sidewalk": "road-bend-barrier",
	"road-bend-square": "road-bend-square-barrier",
	"road-crossroad": "road-crossroad-barrier",
	"road-crossroad-line": "road-crossroad-barrier",
	"road-crossroad-path": "road-crossroad-barrier",
	"road-intersection": "road-intersection-barrier",
	"road-intersection-line": "road-intersection-barrier",
	"road-intersection-path": "road-intersection-barrier",
	"road-end": "road-end-barrier", "road-end-round": "road-end-round-barrier",
	"road-slant": "road-slant-barrier", "road-slant-high": "road-slant-high-barrier",
	"road-square": "road-square-barrier", "road-split": "road-split-barrier",
	"road-roundabout": "road-roundabout-barrier",
	"road-bridge": "road-straight-barrier",
	"road-driveway-single": "road-driveway-single-barrier",
	"road-driveway-double": "road-driveway-double-barrier",
	"road-side": "road-side-barrier", "road-side-entry": "road-side-entry-barrier",
	"road-side-exit": "road-side-exit-barrier",
	"road-curve": "road-curve-barrier",
	"road-curve-pavement": "road-curve-barrier",
	"road-curve-intersection": "road-curve-intersection-barrier",
	"road-slant-curve": "road-slant-curve-barrier",
	"road-slant-flat-curve": "road-slant-curve-barrier",
	"road-straight-half": "road-straight-barrier-half",
}

## LA COURBE LARGE, quart de tour par quart de tour : la case d'ENTRÉE et le
## côté par où la rue arrive, puis la case de SORTIE et le côté par où elle
## repart — les deux cases sont données EN RELATIF du coin nord-ouest de la
## pièce. Déduit de `repere_modele` et vérifié au banc : le tableau est là pour
## qu'on n'ait pas à le redériver à chaque fois qu'on veut poser une courbe.
const COURBE_BOUTS := [
	[Vector2i(0, 0), O, Vector2i(1, 1), S],
	[Vector2i(0, 1), S, Vector2i(1, 0), E],
	[Vector2i(1, 1), E, Vector2i(0, 0), N],
	[Vector2i(1, 0), N, Vector2i(0, 1), O],
]

## Quel quart de tour donne à une courbe large posée en `coin` ses deux
## raccords ? On regarde les rues AUTOUR du carré : celles-là sont déjà
## posées, celles du carré ne le sont pas encore. -1 si aucune orientation ne
## raccorde des deux bouts ; `souple` accepte alors qu'un seul bout raccorde,
## ce qui arrive au bord de la carte et vaut mieux qu'une courbe refusée.
static func quarts_courbe(carte: CarteVille, coin: Vector2i, souple := false) -> int:
	var niveau := carte.palier(coin)
	var boiteux := -1
	for q in 4:
		var b: Array = COURBE_BOUTS[q]
		# ⚠ AU MÊME PALIER. Une rue qui passe à côté mais deux crans plus haut
		# n'est pas un raccord : la pièce serait refusée, et on aurait choisi
		# l'orientation qui la fait refuser plutôt que celle qui marche.
		var un := carte.route(coin + b[0] + b[1]) and carte.palier(coin + b[0] + b[1]) == niveau
		var deux := carte.route(coin + b[2] + b[3]) and carte.palier(coin + b[2] + b[3]) == niveau
		if un and deux: return q
		if (un or deux) and boiteux < 0: boiteux = q
	return boiteux if souple else -1

## Laquelle des trois courbes larges ? Toutes se raccordent pareil ; celle « à
## carrefour » ajoute un bras droit qui traverse la pièce, on ne la pose donc
## que là où ce bras a une rue à rejoindre. Entre les deux autres, `-pavement`
## remplit son carré et la nue laisse deux coins vides (voir AJOUREES) : en
## l'air, on veut le tablier plein.
static func modele_courbe(carte: CarteVille, coin: Vector2i, quarts: int) -> String:
	var b: Array = COURBE_BOUTS[posmod(quarts, 4)]
	# Le bras droit de la variante « intersection » PROLONGE L'ENTRÉE TOUT
	# DROIT : il traverse la case voisine de l'entrée et ressort de l'autre
	# côté de la pièce. La rue qu'il rejoint est donc deux cases plus loin
	# dans le sens de l'entrée.
	var traverse: Vector2i = coin + b[0] - b[1] * 2
	if carte.route(traverse) and not carte.case_prise(traverse):
		return "road-curve-intersection"
	return "road-curve-pavement" if _tirage(coin) % 3 > 0 else "road-curve"

# ------------------------------------------------------------------ JSON

func vers_json() -> String:
	var plates: Dictionary = {}
	for c in cases.keys():
		plates["%d,%d" % [c.x, c.y]] = [int(cases[c]["n"]), 1 if cases[c]["r"] else 0]
	return JSON.stringify({
		"version": 1, "nom": nom, "case": CASE, "palier": PALIER,
		"cases": plates, "pieces": pieces, "objets": objets,
	}, "\t")

static func depuis_json(texte: String) -> CarteVille:
	var brut = JSON.parse_string(texte)
	var carte := CarteVille.new()
	if typeof(brut) != TYPE_DICTIONARY:
		push_warning("carte illisible")
		return carte
	carte.nom = String(brut.get("nom", "sans-titre"))
	for cle in Dictionary(brut.get("cases", {})).keys():
		var xy := String(cle).split(",")
		if xy.size() != 2: continue
		var f: Array = brut["cases"][cle]
		carte.cases[Vector2i(int(xy[0]), int(xy[1]))] = {"n": int(f[0]), "r": int(f[1]) != 0}
	carte.pieces = Array(brut.get("pieces", []))
	carte.objets = Array(brut.get("objets", []))
	return carte

## L'emprise de la carte, en cases. Sert à cadrer la caméra à l'ouverture :
## rouvrir sa carte et ne rien voir parce qu'on est resté à l'origine, c'est
## le premier reproche qu'on fait à un éditeur.
func emprise() -> Rect2i:
	if cases.is_empty():
		return Rect2i(0, 0, 1, 1)
	var mn: Vector2i = cases.keys()[0]
	var mx := mn
	for c in cases.keys():
		mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
		mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
	return Rect2i(mn, mx - mn + Vector2i.ONE)
